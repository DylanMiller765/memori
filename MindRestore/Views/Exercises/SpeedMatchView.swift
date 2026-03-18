import SwiftUI
import SwiftData
import GameKit

// MARK: - ViewModel

@MainActor @Observable
final class SpeedMatchViewModel {
    enum Phase { case setup, showing, answering, feedback, finished }

    var phase: Phase = .setup
    var startTime: Date?
    var currentRound = 0
    let totalRounds = 30
    var correctCount = 0
    var currentSymbol: String = ""
    var previousSymbol: String = ""
    var isMatch: Bool = false
    var lastAnswerCorrect: Bool? = nil
    var responseTimes: [Double] = []
    var roundStartTime: Date?
    var falsePositives = 0
    var lastWrongPreviousSymbol: String = ""
    var lastWrongWasMatch: Bool = false
    var misses = 0
    var currentStreak = 0
    var bestStreak = 0
    var challengeSeed: Int?
    private var rng: SeededGenerator?
    var difficulty = 1 // 1-3, affects symbol count and speed

    // Difficulty 1: 6 symbols, Difficulty 2: 8, Difficulty 3: 10 + similar shapes
    var activeSymbols: [String] {
        switch difficulty {
        case 1: return ["star.fill", "heart.fill", "moon.fill", "bolt.fill", "flame.fill", "leaf.fill"]
        case 2: return ["star.fill", "heart.fill", "moon.fill", "bolt.fill", "flame.fill", "leaf.fill", "drop.fill", "snowflake"]
        default: return ["star.fill", "heart.fill", "moon.fill", "bolt.fill", "flame.fill", "leaf.fill", "drop.fill", "snowflake", "circle.fill", "diamond.fill"]
        }
    }

    var feedbackDelay: Double {
        switch difficulty {
        case 1: return 0.5
        case 2: return 0.35
        default: return 0.25
        }
    }

    var score: Double {
        guard totalRounds > 0 else { return 0 }
        return Double(correctCount) / Double(totalRounds)
    }

    var accuracy: Double { score }

    var averageResponseMs: Int {
        guard !responseTimes.isEmpty else { return 0 }
        return Int(responseTimes.reduce(0, +) / Double(responseTimes.count) * 1000)
    }

    var durationSeconds: Int {
        guard let start = startTime else { return 0 }
        return Int(Date.now.timeIntervalSince(start))
    }

    /// Composite leaderboard score: accuracy% × 1000 + time bonus (faster = higher)
    var leaderboardScore: Int {
        Int(accuracy * 100) * 1000 + max(0, 999 - durationSeconds)
    }

    var ratingText: String {
        let pct = accuracy
        if pct >= 0.95 { return "Lightning Fast!" }
        if pct >= 0.85 { return "Sharp Mind!" }
        if pct >= 0.70 { return "Quick Thinker!" }
        if pct >= 0.50 { return "Getting Faster!" }
        return "Keep Training!"
    }

    var speedRating: String {
        let avg = averageResponseMs
        if avg == 0 { return "—" }
        if avg < 500 { return "Elite" }
        if avg < 700 { return "Fast" }
        if avg < 1000 { return "Average" }
        return "Warming Up"
    }

    private func nextShouldMatch() -> Bool {
        if var r = rng {
            let result = Double.random(in: 0...1, using: &r) < 0.30
            rng = r
            return result
        }
        return Double.random(in: 0...1) < 0.30
    }

    func startGame() {
        phase = .setup
        currentRound = 0
        correctCount = 0
        falsePositives = 0
        misses = 0
        currentStreak = 0
        bestStreak = 0
        responseTimes = []
        lastAnswerCorrect = nil
        previousSymbol = ""
        currentSymbol = ""
        startTime = Date.now
        if let seed = challengeSeed {
            rng = SeededGenerator(seed: UInt64(seed))
        } else {
            rng = nil
        }
        showNextCard()
    }

    func showNextCard() {
        previousSymbol = currentSymbol
        lastWrongPreviousSymbol = ""
        currentRound += 1

        if currentRound == 1 {
            if var r = rng {
                currentSymbol = activeSymbols.randomElement(using: &r)!
                rng = r
            } else {
                currentSymbol = activeSymbols.randomElement()!
            }
            isMatch = false
        } else {
            let shouldMatch = nextShouldMatch()
            if shouldMatch {
                currentSymbol = previousSymbol
                isMatch = true
            } else {
                var next: String
                if var r = rng {
                    next = activeSymbols.randomElement(using: &r)!
                    while next == previousSymbol {
                        next = activeSymbols.randomElement(using: &r)!
                    }
                    rng = r
                } else {
                    next = activeSymbols.randomElement()!
                    while next == previousSymbol {
                        next = activeSymbols.randomElement()!
                    }
                }
                currentSymbol = next
                isMatch = false
            }
        }

        lastAnswerCorrect = nil
        phase = .answering
        roundStartTime = Date.now
    }

    func answer(yes: Bool) {
        guard phase == .answering else { return }

        let responseTime = Date.now.timeIntervalSince(roundStartTime ?? Date.now)
        responseTimes.append(responseTime)

        let correct = (yes == isMatch)
        lastAnswerCorrect = correct

        if correct {
            correctCount += 1
            currentStreak += 1
            bestStreak = max(bestStreak, currentStreak)
        } else {
            currentStreak = 0
            lastWrongPreviousSymbol = previousSymbol
            lastWrongWasMatch = isMatch
            if yes && !isMatch {
                falsePositives += 1
            } else if !yes && isMatch {
                misses += 1
            }
        }

        if correct {
            HapticService.correct()
        } else {
            HapticService.wrong()
        }

        phase = .feedback

        let delay = correct ? feedbackDelay : max(feedbackDelay, 0.7)
        DispatchQueue.main.asyncAfter(deadline: .now() + delay) { [weak self] in
            guard let self else { return }
            if self.currentRound >= self.totalRounds {
                self.phase = .finished
                SoundService.shared.playComplete()
                HapticService.complete()
            } else {
                self.showNextCard()
            }
        }
    }

    func reset() {
        phase = .setup
        currentRound = 0
        correctCount = 0
        falsePositives = 0
        misses = 0
        currentStreak = 0
        bestStreak = 0
        responseTimes = []
        lastAnswerCorrect = nil
        previousSymbol = ""
        currentSymbol = ""
    }
}

// MARK: - View

struct SpeedMatchView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @Environment(AchievementService.self) private var achievementService
    @Environment(TrainingSessionManager.self) private var trainingManager
    @Environment(PaywallTriggerService.self) private var paywallTrigger
    @Environment(StoreService.self) private var storeService
    @Environment(GameCenterService.self) private var gameCenterService
    @Query private var users: [User]

    @State private var viewModel = SpeedMatchViewModel()
    @State private var showingPaywall = false
    @State private var shareImage: UIImage?

    private var user: User? { users.first }
    private var isProUser: Bool { storeService.isProUser || (user?.isProUser ?? false) }

    var body: some View {
        VStack(spacing: 0) {
            switch viewModel.phase {
            case .setup:
                setupView
                    .transition(.opacity)
            case .answering, .showing, .feedback:
                gameView
                    .transition(.opacity)
            case .finished:
                resultsView
                    .transition(.opacity)
            }
        }
        .animation(.easeInOut(duration: 0.3), value: viewModel.phase == .finished)
        .animation(.easeInOut(duration: 0.3), value: viewModel.phase == .setup)
        .sheet(isPresented: $showingPaywall) { PaywallView(isHighIntent: true) }
        .navigationTitle("Speed Match")
        .navigationBarTitleDisplayMode(.inline)
        .onChange(of: viewModel.phase) { _, newPhase in
            if newPhase == .finished {
                let card = ExerciseShareCard(
                    exerciseName: "Speed Match",
                    exerciseIcon: "bolt.square.fill",
                    accentColor: AppColors.sky,
                    mainValue: "\(viewModel.averageResponseMs)ms",
                    mainLabel: "Avg Response",
                    ratingText: viewModel.ratingText,
                    stats: [
                        ("Accuracy", viewModel.accuracy.percentString),
                        ("Speed", viewModel.speedRating),
                        ("Best Streak", "\(viewModel.bestStreak)")
                    ],
                    ctaText: "Think you're faster?"
                )
                shareImage = card.renderAsImage(size: CGSize(width: 360, height: 640), scale: 3)
            }
        }
    }

    // MARK: - Setup

    private var setupView: some View {
        ScrollView {
        VStack(spacing: 24) {
            ZStack {
                Circle()
                    .fill(AppColors.cardBorder)
                    .frame(width: 120, height: 120)
                    .accessibilityHidden(true)
                Image(systemName: "bolt.square.fill")
                    .font(.system(size: 52, weight: .medium))
                    .foregroundStyle(AppColors.accent)
            }

            VStack(spacing: 8) {
                Text("Speed Match")
                    .font(.title.weight(.bold))
                Text("How fast can you spot patterns?")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }

            // What this trains
            VStack(alignment: .leading, spacing: 10) {
                Text("WHAT THIS TRAINS")
                    .font(.caption.weight(.bold))
                    .foregroundStyle(.secondary)
                    .tracking(1)

                infoRow(icon: "bolt.fill", text: "Processing speed — how fast your brain processes visual info")
                infoRow(icon: "eye.fill", text: "Pattern recognition — quickly identify same vs. different")
                infoRow(icon: "brain.head.profile", text: "Inhibitory control — resist impulsive wrong answers")
            }
            .appCard()
            .padding(.horizontal)

            // Difficulty picker
            VStack(spacing: 12) {
                Text("Difficulty")
                    .font(.headline)

                HStack(spacing: 10) {
                    ForEach(1...3, id: \.self) { level in
                        Button {
                            viewModel.difficulty = level
                        } label: {
                            VStack(spacing: 4) {
                                Text(level == 1 ? "Easy" : level == 2 ? "Medium" : "Hard")
                                    .font(.subheadline.weight(.bold))
                                Text(level == 1 ? "6 symbols" : level == 2 ? "8 symbols" : "10 symbols")
                                    .font(.caption2)
                                    .foregroundStyle(viewModel.difficulty == level ? .white.opacity(0.7) : .secondary)
                            }
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 12)
                            .background(
                                RoundedRectangle(cornerRadius: 12)
                                    .fill(viewModel.difficulty == level ? AppColors.accentGradient : LinearGradient(colors: [AppColors.cardSurface], startPoint: .top, endPoint: .bottom))
                            )
                            .foregroundStyle(viewModel.difficulty == level ? .white : .primary)
                            .overlay(
                                RoundedRectangle(cornerRadius: 12)
                                    .stroke(viewModel.difficulty == level ? Color.clear : Color(.separator).opacity(0.3), lineWidth: 1)
                            )
                        }
                    }
                }
            }
            .appCard()
            .padding(.horizontal)

            // How to play
            VStack(alignment: .leading, spacing: 10) {
                Text("HOW TO PLAY")
                    .font(.caption.weight(.bold))
                    .foregroundStyle(.secondary)
                    .tracking(1)

                infoRow(icon: "eye", text: "Symbols appear one at a time")
                infoRow(icon: "checkmark.circle", text: "Tap YES if it matches the previous symbol")
                infoRow(icon: "xmark.circle", text: "Tap NO if it's different")
                infoRow(icon: "timer", text: "30 rounds — be fast and accurate")
            }
            .appCard()
            .padding(.horizontal)

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
    }

    private func infoRow(icon: String, text: String) -> some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.body.weight(.semibold))
                .foregroundStyle(AppColors.sky)
                .frame(width: 24)
            Text(text)
                .font(.subheadline)
        }
    }

    // MARK: - Game

    private var gameView: some View {
        VStack(spacing: 24) {
            // Header: round counter + streak + progress
            HStack {
                Text("Round \(viewModel.currentRound)")
                    .font(.headline)
                    .foregroundStyle(AppColors.accent)
                Spacer()
                if viewModel.currentStreak >= 3 {
                    HStack(spacing: 4) {
                        Image(systemName: "flame.fill")
                            .foregroundStyle(AppColors.coral)
                        Text("\(viewModel.currentStreak)")
                            .font(.caption.weight(.bold))
                            .foregroundStyle(AppColors.coral)
                    }
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(AppColors.coral.opacity(0.12), in: Capsule())
                }
                Text("\(viewModel.currentRound) / \(viewModel.totalRounds)")
                    .font(.caption.weight(.medium))
                    .foregroundStyle(.secondary)
            }
            .padding(.horizontal)

            ProgressView(value: Double(viewModel.currentRound), total: Double(viewModel.totalRounds))
                .tint(AppColors.accent)
                .padding(.horizontal)

            Spacer()

            // Current symbol — large and prominent
            ZStack {
                Circle()
                    .fill(AppColors.cardBorder)
                    .frame(width: 180, height: 180)

                Image(systemName: viewModel.currentSymbol)
                    .font(.system(size: 80, weight: .medium))
                    .foregroundStyle(AppColors.accent)

                // Feedback overlay
                if viewModel.phase == .feedback, let correct = viewModel.lastAnswerCorrect {
                    if correct {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.system(size: 44))
                            .foregroundStyle(AppColors.teal)
                            .transition(.scale.combined(with: .opacity))
                            .offset(x: 50, y: -50)
                    } else {
                        // Wrong: show previous vs current comparison
                        VStack(spacing: 8) {
                            HStack(spacing: 24) {
                                VStack(spacing: 4) {
                                    Image(systemName: viewModel.lastWrongPreviousSymbol.isEmpty ? "questionmark" : viewModel.lastWrongPreviousSymbol)
                                        .font(.system(size: 28))
                                        .foregroundStyle(.secondary)
                                    Text("Previous")
                                        .font(.system(size: 10, weight: .bold))
                                        .foregroundStyle(AppColors.textTertiary)
                                }
                                VStack(spacing: 4) {
                                    Image(systemName: viewModel.currentSymbol)
                                        .font(.system(size: 28))
                                        .foregroundStyle(.secondary)
                                    Text("Current")
                                        .font(.system(size: 10, weight: .bold))
                                        .foregroundStyle(AppColors.textTertiary)
                                }
                            }
                            Text(viewModel.lastWrongWasMatch ? "They matched!" : "They're different")
                                .font(.caption.weight(.bold))
                                .foregroundStyle(AppColors.coral)
                        }
                        .padding(12)
                        .background(AppColors.cardSurface, in: RoundedRectangle(cornerRadius: 12))
                        .overlay(RoundedRectangle(cornerRadius: 12).stroke(AppColors.coral.opacity(0.3), lineWidth: 1))
                        .transition(.scale.combined(with: .opacity))
                        .offset(y: 80)
                    }
                }
            }
            .animation(.easeInOut(duration: 0.2), value: viewModel.lastAnswerCorrect)

            Spacer()

            // YES / NO buttons
            if viewModel.currentRound > 1 {
                HStack(spacing: 16) {
                    Button {
                        viewModel.answer(yes: false)
                    } label: {
                        HStack(spacing: 8) {
                            Image(systemName: "xmark")
                                .font(.title2.weight(.bold))
                            Text("NO")
                                .font(.headline.weight(.bold))
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 20)
                        .background(
                            ZStack {
                                RoundedRectangle(cornerRadius: 12)
                                    .fill(AppColors.coral.opacity(0.20))
                                RoundedRectangle(cornerRadius: 12)
                                    .fill(
                                        LinearGradient(
                                            colors: [AppColors.coral.opacity(0.15), .clear],
                                            startPoint: .top,
                                            endPoint: .bottom
                                        )
                                    )
                            }
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: 12)
                                .stroke(AppColors.coral.opacity(0.25), lineWidth: 1)
                        )
                        .foregroundStyle(AppColors.coral)
                    }
                    .disabled(viewModel.phase == .feedback)

                    Button {
                        viewModel.answer(yes: true)
                    } label: {
                        HStack(spacing: 8) {
                            Image(systemName: "checkmark")
                                .font(.title2.weight(.bold))
                            Text("YES")
                                .font(.headline.weight(.bold))
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 20)
                        .background(
                            ZStack {
                                RoundedRectangle(cornerRadius: 12)
                                    .fill(AppColors.teal.opacity(0.20))
                                RoundedRectangle(cornerRadius: 12)
                                    .fill(
                                        LinearGradient(
                                            colors: [AppColors.teal.opacity(0.15), .clear],
                                            startPoint: .top,
                                            endPoint: .bottom
                                        )
                                    )
                            }
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: 12)
                                .stroke(AppColors.teal.opacity(0.25), lineWidth: 1)
                        )
                        .foregroundStyle(AppColors.teal)
                    }
                    .disabled(viewModel.phase == .feedback)
                }
                .padding(.horizontal)
            } else {
                // First card — no answer needed, auto-advance
                Text("Remember this symbol")
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(.secondary)
                    .onAppear {
                        DispatchQueue.main.asyncAfter(deadline: .now() + 1.2) {
                            if viewModel.currentRound < viewModel.totalRounds {
                                viewModel.showNextCard()
                            }
                        }
                    }
            }

            Spacer().frame(height: 16)
        }
        .padding(.vertical, 24)
    }

    // MARK: - Results

    private var resultsView: some View {
        ScrollView(showsIndicators: false) {
            VStack(spacing: 16) {
                HStack(spacing: 12) {
                    Image(systemName: "bolt.square.fill")
                        .font(.system(size: 24))
                        .foregroundStyle(.white)
                        .frame(width: 48, height: 48)
                        .background(AppColors.sky, in: RoundedRectangle(cornerRadius: 14))
                    Text(viewModel.ratingText)
                        .font(.title2.weight(.bold))
                }
                .padding(.top, 20)

                VStack(spacing: 12) {
                    resultRow(label: "Accuracy", value: viewModel.accuracy.percentString)
                        .accessibilityElement(children: .combine)
                    resultRow(label: "Avg Response", value: "\(viewModel.averageResponseMs) ms")
                        .accessibilityElement(children: .combine)
                    resultRow(label: "Speed Rating", value: viewModel.speedRating)
                        .accessibilityElement(children: .combine)

                    Divider()

                    resultRow(label: "Best Streak", value: "\(viewModel.bestStreak)")
                        .accessibilityElement(children: .combine)
                    resultRow(label: "Correct", value: "\(viewModel.correctCount) / \(viewModel.totalRounds)")
                        .accessibilityElement(children: .combine)
                    resultRow(label: "Time", value: viewModel.durationSeconds.durationString)
                        .accessibilityElement(children: .combine)
                }
                .glowingCard(color: AppColors.accent, intensity: 0.08)
                .padding(.horizontal)

                LeaderboardRankCard(
                    exerciseType: .speedMatch,
                    userScore: Int(viewModel.accuracy * 100),
                    isPro: isProUser,
                    onUpgradeTap: { showingPaywall = true }
                )
                .padding(.horizontal)

                VStack(spacing: 12) {
                    if let shareImage {
                        ShareLink(
                            item: Image(uiImage: shareImage),
                            preview: SharePreview("Speed Match: \(viewModel.accuracy.percentString)", image: Image(uiImage: shareImage))
                        ) {
                            HStack(spacing: 8) {
                                Image(systemName: "square.and.arrow.up")
                                Text("Share Result")
                            }
                            .accentButton()
                        }
                    }

                    if let challengeURL = ChallengeLink(
                        game: .speedMatch,
                        seed: viewModel.challengeSeed ?? ChallengeLink.randomSeed(),
                        score: viewModel.leaderboardScore,
                        challengerName: GKLocalPlayer.local.displayName
                    ).url {
                        ShareLink(item: challengeURL) {
                            HStack(spacing: 8) {
                                Image(systemName: "person.2.fill")
                                Text("Challenge a Friend")
                            }
                            .gradientButton()
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

        AdaptiveDifficultyEngine.shared.recordBlock(domain: .speedMatch, correct: viewModel.correctCount, total: viewModel.totalRounds)
        PersonalBestTracker.shared.record(score: viewModel.leaderboardScore, for: .speedMatch)

        let exercise = Exercise(
            type: .speedMatch,
            difficulty: 1,
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
                difficulty: 1,
                achievementService: achievementService,
                modelContext: modelContext,
                gameCenterService: gameCenterService,
                exerciseType: .speedMatch,
                gameScore: viewModel.leaderboardScore
            )
        }
    }
}
