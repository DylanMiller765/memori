import SwiftUI
import SwiftData

// MARK: - Game Phase

enum SMPhase {
    case setup
    case showing
    case input
    case roundResult
    case finished
}

// MARK: - ViewModel

@MainActor @Observable
final class SequentialMemoryViewModel {
    var phase: SMPhase = .setup
    var currentDigits: [Int] = []
    var displayDigitIndex: Int = -1
    var userInput: String = ""
    var startLength: Int = 4
    var currentLength: Int = 4
    let adaptiveLevel = AdaptiveDifficultyEngine.shared.currentLevel(for: .sequentialMemory)
    var round: Int = 0
    var maxRounds: Int = 8
    var maxCorrectLength: Int = 0
    var roundResults: [(length: Int, correct: Bool)] = []
    var startTime: Date?
    var challengeSeed: Int?
    private var rng: SeededGenerator?
    private var digitTimer: Timer?

    var score: Double {
        // maxCorrectLength of 4 = baseline (0.5), 10+ = perfect
        let normalized = Double(maxCorrectLength - 3) / 7.0
        return max(0, min(1, normalized))
    }

    var durationSeconds: Int {
        guard let start = startTime else { return 0 }
        return Int(Date.now.timeIntervalSince(start))
    }

    var currentDisplayDigit: String {
        guard displayDigitIndex >= 0, displayDigitIndex < currentDigits.count else { return "" }
        return "\(currentDigits[displayDigitIndex])"
    }

    var isShowingDigit: Bool {
        displayDigitIndex >= 0 && displayDigitIndex < currentDigits.count
    }

    func startGame() {
        currentLength = max(4, 3 + adaptiveLevel)
        round = 0
        maxCorrectLength = 0
        roundResults = []
        startTime = Date.now
        if let seed = challengeSeed {
            rng = SeededGenerator(seed: UInt64(seed))
        } else {
            rng = nil
        }
        nextRound()
    }

    func nextRound() {
        if var r = rng {
            currentDigits = (0..<currentLength).map { _ in Int.random(in: 0...9, using: &r) }
            rng = r
        } else {
            currentDigits = (0..<currentLength).map { _ in Int.random(in: 0...9) }
        }
        displayDigitIndex = -1
        userInput = ""
        phase = .showing
        showNextDigit()
    }

    private func showNextDigit() {
        digitTimer?.invalidate()
        displayDigitIndex += 1

        if displayDigitIndex >= currentDigits.count {
            digitTimer = Timer.scheduledTimer(withTimeInterval: 0.4, repeats: false) { [weak self] _ in
                Task { @MainActor in
                    self?.displayDigitIndex = -1
                    self?.phase = .input
                }
            }
            return
        }

        let interval: TimeInterval = currentLength <= 5 ? 0.8 : 0.65
        digitTimer = Timer.scheduledTimer(withTimeInterval: interval, repeats: false) { [weak self] _ in
            Task { @MainActor in
                self?.showNextDigit()
            }
        }
    }

    func submitAnswer() {
        let correct = currentDigits.map(String.init).joined()
        let isCorrect = userInput == correct

        roundResults.append((length: currentLength, correct: isCorrect))
        round += 1

        if isCorrect {
            maxCorrectLength = max(maxCorrectLength, currentLength)
            currentLength += 1
            HapticService.correct()
            SoundService.shared.playCorrect()
        } else {
            HapticService.wrong()
            SoundService.shared.playWrong()
        }

        phase = .roundResult
    }

    func continueOrFinish() {
        let lastCorrect = roundResults.last?.correct ?? false

        if !lastCorrect || round >= maxRounds {
            HapticService.complete()
            phase = .finished
        } else {
            HapticService.levelUp()
            nextRound()
        }
    }

    var correctRounds: Int {
        roundResults.filter(\.correct).count
    }

    func reset() {
        digitTimer?.invalidate()
        phase = .setup
    }
}

// MARK: - View

struct SequentialMemoryView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @Environment(AchievementService.self) private var achievementService
    @Environment(TrainingSessionManager.self) private var trainingManager
    @Environment(PaywallTriggerService.self) private var paywallTrigger
    @Environment(StoreService.self) private var storeService
    @Environment(GameCenterService.self) private var gameCenterService
    @Query private var users: [User]

    @State private var viewModel = SequentialMemoryViewModel()
    @State private var showingPaywall = false
    @State private var isNewPersonalBest = false
    @State private var shareImage: UIImage?
    @FocusState private var inputFocused: Bool

    private var user: User? { users.first }
    private var isProUser: Bool { storeService.isProUser || (user?.isProUser ?? false) }

    var body: some View {
        VStack(spacing: 0) {
            switch viewModel.phase {
            case .setup:
                setupView
            case .showing:
                showingView
            case .input:
                inputView
            case .roundResult:
                roundResultView
            case .finished:
                resultsView
            }
        }
        .sheet(isPresented: $showingPaywall) { PaywallView(isHighIntent: true) }
        .navigationTitle("Number Memory")
        .navigationBarTitleDisplayMode(.inline)
        .onChange(of: viewModel.phase) { _, newPhase in
            if newPhase == .finished {
                SoundService.shared.playComplete()
                isNewPersonalBest = PersonalBestTracker.shared.record(score: viewModel.maxCorrectLength, for: .sequentialMemory)
                AdaptiveDifficultyEngine.shared.recordBlock(domain: .sequentialMemory, correct: viewModel.correctRounds, total: viewModel.roundResults.count)
                let card = ExerciseShareCard(
                    exerciseName: "Number Memory",
                    exerciseIcon: "number.circle.fill",
                    accentColor: AppColors.teal,
                    mainValue: "\(viewModel.maxCorrectLength)",
                    mainLabel: "Digit Span",
                    ratingText: viewModel.maxCorrectLength >= 9 ? "Genius" : viewModel.maxCorrectLength >= 7 ? "Excellent" : viewModel.maxCorrectLength >= 5 ? "Good" : "Keep Training",
                    stats: [
                        ("Rounds Passed", "\(viewModel.roundResults.filter(\.correct).count)"),
                        ("Score", viewModel.score.percentString)
                    ],
                    ctaText: "Beat my memory"
                )
                shareImage = card.renderAsImage(size: CGSize(width: 360, height: 640), scale: 3)
            }
        }
    }

    // MARK: - Setup

    private var setupView: some View {
        VStack(spacing: 32) {
            Spacer()

            ZStack {
                Circle()
                    .fill(AppColors.cardBorder)
                    .frame(width: 120, height: 120)
                Image(systemName: "number.circle.fill")
                    .font(.system(size: 52, weight: .medium))
                    .foregroundStyle(AppColors.accent)
            }

            VStack(spacing: 8) {
                Text("Number Memory")
                    .font(.title.weight(.bold))
                Text("Remember the digits shown one at a time")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }

            VStack(alignment: .leading, spacing: 12) {
                infoRow(icon: "eye", text: "Watch each digit appear one by one")
                infoRow(icon: "keyboard", text: "Type the full sequence from memory")
                infoRow(icon: "arrow.up.right", text: "Sequence gets longer each round you pass")
            }
            .appCard()
            .padding(.horizontal)

            Spacer()

            Button {
                viewModel.startGame()
            } label: {
                Text("Start")
                    .accentButton()
            }
            .accessibilityHint("Starts the exercise")
            .padding(.horizontal, 32)
        }
        .padding(.vertical, 24)
    }

    private func infoRow(icon: String, text: String) -> some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.body.weight(.semibold))
                .foregroundStyle(AppColors.teal)
                .frame(width: 24)
            Text(text)
                .font(.subheadline)
        }
    }

    // MARK: - Showing Digits

    private var showingView: some View {
        VStack(spacing: 24) {
            HStack {
                Text("Level \(viewModel.currentLength)")
                    .font(.headline)
                    .foregroundStyle(AppColors.teal)
                Spacer()
                Text("Round \(viewModel.round + 1)")
                    .font(.caption.weight(.medium))
                    .foregroundStyle(.secondary)
            }
            .padding(.horizontal)

            ProgressView(value: Double(viewModel.displayDigitIndex + 1), total: Double(viewModel.currentDigits.count))
                .tint(AppColors.teal)
                .padding(.horizontal)

            Spacer()

            if viewModel.isShowingDigit {
                Text(viewModel.currentDisplayDigit)
                    .font(.system(size: 96, weight: .bold, design: .monospaced))
                    .foregroundStyle(AppColors.accent)
                    .transition(.opacity.combined(with: .scale(scale: 0.8)))
                    .animation(.easeOut(duration: 0.15), value: viewModel.displayDigitIndex)
                    .accessibilityLabel("Remember this number: \(viewModel.currentDisplayDigit)")
            } else {
                Text("...")
                    .font(.system(size: 48, weight: .bold))
                    .foregroundStyle(.secondary)
            }

            Spacer()

            Text("Watch carefully")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .padding(.bottom, 32)
        }
        .padding(.vertical, 24)
    }

    // MARK: - Input

    private var inputView: some View {
        VStack(spacing: 24) {
            Text("Level \(viewModel.currentLength)")
                .font(.headline)
                .foregroundStyle(AppColors.teal)

            Spacer()

            VStack(spacing: 16) {
                Text("Enter the sequence")
                    .font(.title3.weight(.semibold))

                TextField("", text: $viewModel.userInput)
                    .keyboardType(.numberPad)
                    .font(.system(size: 36, weight: .bold, design: .monospaced))
                    .multilineTextAlignment(.center)
                    .focused($inputFocused)
                    .padding(.vertical, 16)
                    .padding(.horizontal, 24)
                    .background(
                        RoundedRectangle(cornerRadius: 12)
                            .fill(AppColors.cardSurface)
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(AppColors.teal.opacity(0.3), lineWidth: 1.5)
                    )
                    .padding(.horizontal, 40)

                Text("\(viewModel.userInput.count) / \(viewModel.currentLength) digits")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            Button {
                viewModel.submitAnswer()
            } label: {
                Text("Submit")
                    .accentButton()
            }
            .padding(.horizontal, 32)
            .disabled(viewModel.userInput.isEmpty)
            .opacity(viewModel.userInput.isEmpty ? 0.5 : 1)
        }
        .padding(.vertical, 24)
        .onAppear { inputFocused = true }
    }

    // MARK: - Round Result

    private var roundResultView: some View {
        let lastResult = viewModel.roundResults.last
        let isCorrect = lastResult?.correct ?? false

        return VStack(spacing: 24) {
            Spacer()

            ZStack {
                Circle()
                    .fill(AppColors.cardBorder)
                    .frame(width: 80, height: 80)
                Image(systemName: isCorrect ? "checkmark.circle.fill" : "xmark.circle.fill")
                    .font(.system(size: 56))
                    .foregroundStyle(isCorrect ? AppColors.accent : AppColors.coral)
            }

            Text(isCorrect ? "Correct!" : "Wrong")
                .font(.title.weight(.bold))

            if !isCorrect {
                VStack(spacing: 8) {
                    Text("The sequence was:")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                    Text(viewModel.currentDigits.map(String.init).joined())
                        .font(.system(size: 28, weight: .bold, design: .monospaced))
                        .foregroundStyle(AppColors.teal)
                    Text("You entered: \(viewModel.userInput)")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
            }

            Text("Level \(lastResult?.length ?? 0)")
                .font(.headline)
                .foregroundStyle(.secondary)

            Spacer()

            Button {
                viewModel.continueOrFinish()
            } label: {
                Text(isCorrect && viewModel.round < viewModel.maxRounds ? "Next Level" : "See Results")
                    .accentButton()
            }
            .padding(.horizontal, 32)
        }
        .padding(.vertical, 24)
    }

    // MARK: - Final Results

    private var resultsView: some View {
        ScrollView(showsIndicators: false) {
            VStack(spacing: 16) {
                HStack(spacing: 12) {
                    Image(systemName: "number.circle.fill")
                        .font(.system(size: 24))
                        .foregroundStyle(.white)
                        .frame(width: 48, height: 48)
                        .background(AppColors.teal, in: RoundedRectangle(cornerRadius: 14))
                    Text("Session Complete!")
                        .font(.title2.weight(.bold))
                }
                .padding(.top, 20)

                if isNewPersonalBest {
                    Label("New Personal Best!", systemImage: "trophy.fill")
                        .font(.subheadline.weight(.bold))
                        .foregroundStyle(AppColors.amber)
                        .padding(.vertical, 8)
                        .padding(.horizontal, 16)
                        .background(AppColors.amber.opacity(0.12), in: Capsule())
                }

                VStack(spacing: 12) {
                    resultRow(label: "Max Digit Span", value: "\(viewModel.maxCorrectLength)")
                        .accessibilityElement(children: .combine)
                    resultRow(label: "Rounds Passed", value: "\(viewModel.roundResults.filter(\.correct).count)")
                        .accessibilityElement(children: .combine)
                    Divider()
                    resultRow(label: "Score", value: viewModel.score.percentString)
                        .accessibilityElement(children: .combine)

                    HStack(spacing: 4) {
                        ForEach(Array(viewModel.roundResults.enumerated()), id: \.offset) { index, result in
                            VStack(spacing: 4) {
                                Text("L\(result.length)")
                                    .font(.caption2)
                                    .foregroundStyle(.secondary)
                                Image(systemName: result.correct ? "checkmark.circle.fill" : "xmark.circle.fill")
                                    .font(.caption)
                                    .foregroundStyle(result.correct ? AppColors.teal : AppColors.coral)
                            }
                            .frame(maxWidth: .infinity)
                        }
                    }
                    .padding(.top, 4)
                }
                .glowingCard(color: AppColors.teal, intensity: 0.08)
                .padding(.horizontal)

                LeaderboardRankCard(
                    exerciseType: .sequentialMemory,
                    userScore: viewModel.maxCorrectLength,
                    isPro: isProUser,
                    onUpgradeTap: { showingPaywall = true }
                )
                .padding(.horizontal)

                VStack(spacing: 12) {
                    if let shareImage {
                        ShareLink(
                            item: Image(uiImage: shareImage),
                            preview: SharePreview("Number Memory: \(viewModel.maxCorrectLength) digits", image: Image(uiImage: shareImage))
                        ) {
                            HStack(spacing: 8) {
                                Image(systemName: "square.and.arrow.up")
                                Text("Share Result")
                            }
                            .accentButton()
                        }
                    }

                    Button {
                        viewModel.startGame()
                    } label: {
                        Text("Play Again")
                            .gradientButton()
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

    private func resultRow(label: String, value: String) -> some View {
        HStack {
            Text(label)
                .font(.subheadline)
                .foregroundStyle(.secondary)
            Spacer()
            Text(value)
                .font(.subheadline.weight(.semibold))
        }
    }

    // MARK: - Save

    private func saveExercise() {
        paywallTrigger.recordExerciseCompleted()
        trainingManager.addTrainingTime(viewModel.durationSeconds)

        let exercise = Exercise(
            type: .sequentialMemory,
            difficulty: viewModel.maxCorrectLength,
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
                difficulty: viewModel.maxCorrectLength,
                achievementService: achievementService,
                modelContext: modelContext,
                gameCenterService: gameCenterService,
                exerciseType: .sequentialMemory,
                gameScore: viewModel.maxCorrectLength
            )
        }
    }
}
