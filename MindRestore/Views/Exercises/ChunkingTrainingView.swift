import SwiftUI
import SwiftData

// MARK: - Chunking Phase

enum ChunkingPhase {
    case intro
    case memorize
    case chunkHint
    case recall
    case results
}

// MARK: - Chunking Style

enum ChunkingStyle: String, CaseIterable {
    case phoneNumber   // "4729 1865 3041"
    case datePairs     // "47-29-18-65-30-41"
    case triplets      // "472 918 653 041"

    func chunk(_ digits: String) -> String {
        let chars = Array(digits)
        switch self {
        case .phoneNumber:
            return stride(from: 0, to: chars.count, by: 4)
                .map { start in
                    let end = min(start + 4, chars.count)
                    return String(chars[start..<end])
                }
                .joined(separator: " ")
        case .datePairs:
            return stride(from: 0, to: chars.count, by: 2)
                .map { start in
                    let end = min(start + 2, chars.count)
                    return String(chars[start..<end])
                }
                .joined(separator: "-")
        case .triplets:
            return stride(from: 0, to: chars.count, by: 3)
                .map { start in
                    let end = min(start + 3, chars.count)
                    return String(chars[start..<end])
                }
                .joined(separator: " ")
        }
    }

    var label: String {
        switch self {
        case .phoneNumber: return "Phone-number style (groups of 4)"
        case .datePairs: return "Date-pair style (groups of 2)"
        case .triplets: return "Triplet style (groups of 3)"
        }
    }
}

// MARK: - Chunking ViewModel

@MainActor @Observable
final class ChunkingViewModel {
    // State
    var phase: ChunkingPhase = .intro
    var digitString: String = ""
    var userInput: String = ""
    var score: Double = 0.0
    var correctDigits: Int = 0
    var totalDigits: Int = 0
    var showHint: Bool = true
    var chunkStyle: ChunkingStyle = .phoneNumber
    var timeRemaining: TimeInterval = 0
    var displayDuration: TimeInterval = 0
    var difficulty: Int = 1
    var durationSeconds: Int = 0
    var strategyTip: StrategyTip?
    var hasSeenIntro: Bool = false
    var roundsCompleted: Int = 0

    // Internal
    private var timer: Timer?
    private var startTime: Date?
    private let hasSeenIntroKey = "chunkingTraining_hasSeenIntro"

    init() {}

    func startFromIntro() {
        startChallenge()
    }

    func startChallenge() {
        let params = AdaptiveDifficultyEngine.shared.parameters(for: .digits)
        // Chunking exercises add 4 extra digits since the user has a strategy
        totalDigits = params.digitCount + 4
        difficulty = AdaptiveDifficultyEngine.shared.currentLevel(for: .digits)

        // Generate random digit string
        digitString = (0..<totalDigits).map { _ in String(Int.random(in: 0...9)) }.joined()
        userInput = ""
        score = 0.0
        correctDigits = 0
        chunkStyle = ChunkingStyle.allCases.randomElement() ?? .phoneNumber

        // Display time scales with difficulty — more digits, less time per digit
        let baseTime = AdaptiveDifficultyEngine.shared.displayTime(for: .digits, difficulty: difficulty)
        displayDuration = max(baseTime + 2.0, Double(totalDigits) * 0.5)
        timeRemaining = displayDuration

        startTime = Date.now
        phase = .memorize
        startTimer()
    }

    func skipToChunkHint() {
        stopTimer()
        phase = .chunkHint
    }

    func skipToRecall() {
        stopTimer()
        phase = .recall
    }

    func proceedFromHint() {
        phase = .recall
    }

    func submitRecall() {
        stopTimer()

        // Strip non-digit characters from input
        let cleanInput = userInput.filter(\.isNumber)

        // Score: count correct digits at correct positions
        var correct = 0
        let inputChars = Array(cleanInput)
        let targetChars = Array(digitString)
        for i in 0..<min(inputChars.count, targetChars.count) {
            if inputChars[i] == targetChars[i] {
                correct += 1
            }
        }
        correctDigits = correct
        score = totalDigits > 0 ? Double(correct) / Double(totalDigits) : 0

        // Duration
        if let start = startTime {
            durationSeconds = max(1, Int(Date.now.timeIntervalSince(start)))
        }

        // Record with adaptive engine
        AdaptiveDifficultyEngine.shared.recordBlock(
            domain: .digits,
            correct: correctDigits,
            total: totalDigits
        )

        // Get strategy tip
        strategyTip = StrategyTipService.shared.freshTip(for: .digits)

        roundsCompleted += 1
        phase = .results

        if score >= 0.7 {
            SoundService.shared.playCorrect()
            HapticService.correct()
        } else {
            SoundService.shared.playWrong()
            HapticService.wrong()
        }
        SoundService.shared.playComplete()
        HapticService.complete()
    }

    // MARK: - Comparison helpers

    func digitStatus(at index: Int) -> DigitStatus {
        let targetChars = Array(digitString)
        let cleanInput = userInput.filter(\.isNumber)
        let inputChars = Array(cleanInput)

        guard index < targetChars.count else { return .missing }
        guard index < inputChars.count else { return .missing }
        return inputChars[index] == targetChars[index] ? .correct : .wrong
    }

    enum DigitStatus {
        case correct, wrong, missing
    }

    // MARK: - Timer

    private func startTimer() {
        stopTimer()
        timer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { [weak self] _ in
            guard let self else { return }
            self.timeRemaining -= 0.1
            if self.timeRemaining <= 0 {
                self.timeRemaining = 0
                self.skipToRecall()
            }
        }
    }

    private func stopTimer() {
        timer?.invalidate()
        timer = nil
    }
}

// MARK: - ChunkingTrainingView

struct ChunkingTrainingView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @Environment(AchievementService.self) private var achievementService
    @Environment(TrainingSessionManager.self) private var trainingManager
    @Environment(PaywallTriggerService.self) private var paywallTrigger
    @Environment(StoreService.self) private var storeService
    @Environment(GameCenterService.self) private var gameCenterService
    @Query private var users: [User]

    @State private var viewModel = ChunkingViewModel()
    @State private var showingPaywall = false
    @State private var shareImage: UIImage?

    private var user: User? { users.first }
    private var isProUser: Bool { storeService.isProUser || (user?.isProUser ?? false) }

    var body: some View {
        VStack(spacing: 0) {
            switch viewModel.phase {
            case .intro:
                introView
            case .memorize:
                memorizeView
            case .chunkHint:
                // Skip chunk hint, go straight to recall
                recallView
            case .recall:
                recallView
            case .results:
                resultsView
            }
        }
        .sheet(isPresented: $showingPaywall) { PaywallView() }
        .navigationTitle("Chunking Training")
        .navigationBarTitleDisplayMode(.inline)
        .onChange(of: viewModel.phase) { _, newPhase in
            if newPhase == .results {
                let card = ExerciseShareCard(
                    exerciseName: "Chunking",
                    exerciseIcon: "square.grid.4x3.fill",
                    accentColor: AppColors.teal,
                    mainValue: viewModel.score.percentString,
                    mainLabel: "Score",
                    ratingText: viewModel.score >= 0.9 ? "Perfect Chunks" : viewModel.score >= 0.7 ? "Great Memory" : "Keep Chunking",
                    stats: [
                        ("Correct Digits", "\(viewModel.correctDigits) / \(viewModel.totalDigits)"),
                        ("Difficulty", "Level \(viewModel.difficulty)")
                    ],
                    ctaText: "Can you chunk better?"
                )
                shareImage = card.renderAsImage(size: CGSize(width: 360, height: 640), scale: 3)
            }
        }
    }

    // MARK: - Intro

    private var introView: some View {
        VStack(spacing: 24) {
            Spacer()

            ZStack {
                Circle()
                    .fill(AppColors.teal.opacity(0.12))
                    .frame(width: 100, height: 100)
                Image(systemName: "square.grid.4x3.fill")
                    .font(.system(size: 44, weight: .medium))
                    .foregroundStyle(AppColors.teal)
            }

            VStack(spacing: 8) {
                Text("Chunking Training")
                    .font(.title2.weight(.bold))

                Text("Group digits into chunks to remember more")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }

            VStack(alignment: .leading, spacing: 14) {
                introPoint(
                    icon: "1.circle.fill",
                    text: "You'll see a string of digits for a few seconds"
                )
                introPoint(
                    icon: "2.circle.fill",
                    text: "Try grouping them — like phone numbers or dates"
                )
                introPoint(
                    icon: "3.circle.fill",
                    text: "Type them back from memory"
                )
            }
            .appCard()
            .padding(.horizontal)

            // Strategy tip
            VStack(spacing: 8) {
                HStack(spacing: 6) {
                    Image(systemName: "lightbulb.fill")
                        .foregroundStyle(AppColors.amber)
                    Text("Pro Tip")
                        .font(.caption.weight(.bold))
                        .foregroundStyle(AppColors.amber)
                }
                Text("Break \"5329184\" into \"532-918-4\" — smaller groups are easier to hold in memory")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }
            .padding()
            .background(AppColors.amber.opacity(0.08), in: RoundedRectangle(cornerRadius: 12))
            .padding(.horizontal)

            Spacer()

            Button {
                UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                viewModel.startFromIntro()
            } label: {
                Text("I'm Ready")
                    .accentButton(color: AppColors.teal)
            }
            .padding(.horizontal, 32)
        }
        .padding(.vertical, 24)
    }

    private func introPoint(icon: String, text: String) -> some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: icon)
                .font(.body.weight(.semibold))
                .foregroundStyle(AppColors.teal)
                .frame(width: 24)
            Text(text)
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
    }

    // MARK: - Memorize

    private var memorizeView: some View {
        VStack(spacing: 24) {
            HStack {
                Text("Memorize these digits")
                    .font(.headline)
                Spacer()
                Text("\(Int(viewModel.timeRemaining))s")
                    .font(.headline.monospacedDigit())
                    .foregroundStyle(viewModel.timeRemaining <= 3 ? AppColors.error : AppColors.teal)
                    .accessibilityLabel("Time remaining: \(Int(viewModel.timeRemaining)) seconds")
            }
            .padding(.horizontal)

            ProgressView(value: max(0, viewModel.timeRemaining), total: viewModel.displayDuration)
                .tint(AppColors.teal)
                .padding(.horizontal)

            Spacer()

            VStack(spacing: 8) {
                Text("\(viewModel.totalDigits) digits")
                    .font(.caption)
                    .foregroundStyle(.secondary)

                Text(viewModel.digitString)
                    .font(.system(size: 32, weight: .bold, design: .monospaced))
                    .tracking(4)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal)
                    .accessibilityLabel("Remember this number: \(viewModel.digitString)")
            }

            Spacer()

            Text("Try to find patterns and group the digits mentally")
                .font(.caption)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)

            Button {
                UIImpactFeedbackGenerator(style: .light).impactOccurred()
                viewModel.skipToRecall()
            } label: {
                Text("I'm Ready")
                    .accentButton(color: AppColors.teal)
            }
            .padding(.horizontal, 32)
        }
        .padding(.vertical, 24)
    }

    // MARK: - Chunk Hint

    private var chunkHintView: some View {
        VStack(spacing: 24) {
            Text("Chunking Strategy")
                .font(.headline)
                .padding(.top)

            VStack(spacing: 16) {
                Text("Here's one way to chunk those digits:")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)

                Text(viewModel.chunkStyle.chunk(viewModel.digitString))
                    .font(.system(size: 24, weight: .semibold, design: .monospaced))
                    .tracking(2)
                    .multilineTextAlignment(.center)
                    .padding()
                    .background(AppColors.teal.opacity(0.1), in: RoundedRectangle(cornerRadius: 12))
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(AppColors.teal.opacity(0.3), lineWidth: 1)
                    )

                Text(viewModel.chunkStyle.label)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .appCard()
            .padding(.horizontal)

            Spacer()

            VStack(spacing: 12) {
                Button {
                    UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                    viewModel.proceedFromHint()
                } label: {
                    Text("Got It - Recall Now")
                        .accentButton(color: AppColors.teal)
                }

                Button {
                    viewModel.showHint = false
                    viewModel.proceedFromHint()
                } label: {
                    Text("I'll chunk it myself")
                        .font(.subheadline.weight(.medium))
                        .foregroundStyle(.secondary)
                }
            }
            .padding(.horizontal, 32)
        }
        .padding(.vertical, 24)
    }

    // MARK: - Recall

    private var recallView: some View {
        VStack(spacing: 24) {
            Text("Type the digits from memory")
                .font(.headline)
                .padding(.top)

            Text("\(viewModel.totalDigits) digits total")
                .font(.caption)
                .foregroundStyle(.secondary)

            Spacer()

            VStack(spacing: 12) {
                TextField("Enter digits...", text: $viewModel.userInput)
                    .font(.system(size: 28, weight: .semibold, design: .monospaced))
                    .tracking(3)
                    .keyboardType(.numberPad)
                    .multilineTextAlignment(.center)
                    .padding()
                    .background(
                        RoundedRectangle(cornerRadius: 12)
                            .fill(AppColors.cardSurface)
                    )
                    .padding(.horizontal, 24)

                let entered = viewModel.userInput.filter(\.isNumber).count
                Text("\(entered) / \(viewModel.totalDigits) digits entered")
                    .font(.caption)
                    .foregroundStyle(entered == viewModel.totalDigits ? AppColors.teal : .secondary)
            }

            Spacer()

            Button {
                UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                viewModel.submitRecall()
            } label: {
                Text("Submit")
                    .accentButton(color: AppColors.teal)
            }
            .padding(.horizontal, 32)
        }
        .padding(.vertical, 24)
    }

    // MARK: - Results

    private var resultsView: some View {
        ScrollView(showsIndicators: false) {
            VStack(spacing: 16) {
                HStack(spacing: 12) {
                    Image(systemName: "rectangle.split.3x1.fill")
                        .font(.system(size: 24))
                        .foregroundStyle(.white)
                        .frame(width: 48, height: 48)
                        .background(AppColors.rose, in: RoundedRectangle(cornerRadius: 14))
                    Text(viewModel.score >= 0.7 ? "Great Chunking!" : "Keep Practicing!")
                        .font(.title2.weight(.bold))
                }
                .padding(.top, 20)

                Text("Score: \(viewModel.score.percentString)")
                    .font(.title2)
                    .foregroundStyle(AppColors.accent)
                    .accessibilityLabel("Score: \(viewModel.score.percentString)")

                Text("\(viewModel.correctDigits) / \(viewModel.totalDigits) digits correct")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)

                // Color-coded digit comparison
                VStack(spacing: 12) {
                    Text("Your Answer vs Correct")
                        .font(.caption.weight(.medium))
                        .foregroundStyle(.secondary)

                    digitComparisonView

                    Divider()

                    VStack(alignment: .leading, spacing: 8) {
                        Text("Suggested Chunking:")
                            .font(.caption.weight(.medium))
                            .foregroundStyle(.secondary)

                        ForEach(ChunkingStyle.allCases, id: \.rawValue) { style in
                            HStack(spacing: 8) {
                                Text(style.chunk(viewModel.digitString))
                                    .font(.system(.caption, design: .monospaced))
                                    .fontWeight(.medium)
                                Spacer()
                                Text(style.label)
                                    .font(.caption2)
                                    .foregroundStyle(.tertiary)
                            }
                        }
                    }
                }
                .glowingCard(color: AppColors.teal, intensity: 0.08)
                .padding(.horizontal)

                // Strategy Tip
                if let tip = viewModel.strategyTip {
                    VStack(alignment: .leading, spacing: 8) {
                        HStack(spacing: 6) {
                            Image(systemName: "lightbulb.fill")
                                .foregroundStyle(AppColors.warning)
                            Text(tip.title)
                                .font(.subheadline.weight(.semibold))
                        }
                        Text(tip.body)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    .appCard()
                    .padding(.horizontal)
                }

                // Difficulty info
                if let adjustment = AdaptiveDifficultyEngine.shared.lastAdjustment[.digits] {
                    Text(adjustment.description)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .padding(.horizontal)
                }

                LeaderboardRankCard(
                    exerciseType: .chunkingTraining,
                    userScore: viewModel.correctDigits,
                    isPro: isProUser,
                    onUpgradeTap: { showingPaywall = true }
                )
                .padding(.horizontal)

                VStack(spacing: 12) {
                    if let shareImage {
                        ShareLink(
                            item: Image(uiImage: shareImage),
                            preview: SharePreview("Chunking: \(viewModel.score.percentString)", image: Image(uiImage: shareImage))
                        ) {
                            HStack(spacing: 8) {
                                Image(systemName: "square.and.arrow.up")
                                Text("Share Result")
                            }
                            .accentButton()
                        }
                    }

                    Button {
                        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                        saveExercise()
                        viewModel.startChallenge()
                    } label: {
                        Text("Next Challenge")
                            .accentButton(color: AppColors.teal)
                    }

                    Button {
                        saveExercise()
                        dismiss()
                    } label: {
                        Text("Done")
                            .font(.headline)
                            .foregroundStyle(.secondary)
                    }
                }
                .padding(.horizontal, 32)
                .padding(.top, 8)
                .padding(.bottom, 24)
            }
        }
    }

    private var digitComparisonView: some View {
        let target = Array(viewModel.digitString)
        let input = Array(viewModel.userInput.filter(\.isNumber))
        let maxLen = max(target.count, input.count)

        return VStack(spacing: 4) {
            // User's input colored
            HStack(spacing: 2) {
                ForEach(0..<maxLen, id: \.self) { i in
                    if i < input.count && i < target.count {
                        Text(String(input[i]))
                            .font(.system(.body, design: .monospaced))
                            .fontWeight(.bold)
                            .foregroundStyle(input[i] == target[i] ? AppColors.accent : AppColors.error)
                    } else if i < input.count {
                        Text(String(input[i]))
                            .font(.system(.body, design: .monospaced))
                            .fontWeight(.bold)
                            .foregroundStyle(AppColors.error)
                    } else {
                        Text("_")
                            .font(.system(.body, design: .monospaced))
                            .fontWeight(.bold)
                            .foregroundStyle(AppColors.error.opacity(0.5))
                    }
                }
            }

            // Correct answer
            HStack(spacing: 2) {
                ForEach(0..<target.count, id: \.self) { i in
                    Text(String(target[i]))
                        .font(.system(.caption, design: .monospaced))
                        .foregroundStyle(.secondary)
                }
            }
        }
    }

    // MARK: - Save

    private func saveExercise() {
        paywallTrigger.recordExerciseCompleted()
        trainingManager.addTrainingTime(viewModel.durationSeconds)

        PersonalBestTracker.shared.record(score: viewModel.correctDigits, for: .chunkingTraining)

        let exercise = Exercise(
            type: .chunkingTraining,
            difficulty: viewModel.difficulty,
            score: viewModel.score,
            durationSeconds: viewModel.durationSeconds
        )
        modelContext.insert(exercise)

        let descriptor = FetchDescriptor<DailySession>(
            sortBy: [SortDescriptor(\.date, order: .reverse)]
        )
        let allSessions = (try? modelContext.fetch(descriptor)) ?? []
        let session: DailySession
        if let existing = allSessions.first(where: { Calendar.current.isDateInToday($0.date) }) {
            session = existing
        } else {
            session = DailySession()
            modelContext.insert(session)
        }
        session.addExercise(exercise)
        user?.updateStreak()
        NotificationService.shared.cancelStreakRisk()
        if let streak = user?.currentStreak {
            NotificationService.shared.scheduleMilestone(streak: streak)
        }

        if let user {
            _ = ContentView.awardXP(
                user: user,
                score: viewModel.score,
                difficulty: viewModel.difficulty,
                achievementService: achievementService,
                modelContext: modelContext,
                gameCenterService: gameCenterService,
                exerciseType: .chunkingTraining,
                gameScore: viewModel.correctDigits
            )
        }
    }
}
