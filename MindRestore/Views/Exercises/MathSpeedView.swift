import SwiftUI
import SwiftData
import GameKit

// MARK: - Difficulty

enum MathDifficulty: String, CaseIterable, Identifiable {
    case easy = "Easy"
    case medium = "Medium"
    case hard = "Hard"

    var id: String { rawValue }

    var description: String {
        switch self {
        case .easy: return "1-9 × 1-9"
        case .medium: return "2-12 × 2-12"
        case .hard: return "5-20 × 5-20"
        }
    }

    var range: ClosedRange<Int> {
        switch self {
        case .easy: return 1...9
        case .medium: return 2...12
        case .hard: return 5...20
        }
    }

    var difficultyValue: Int {
        switch self {
        case .easy: return 1
        case .medium: return 2
        case .hard: return 3
        }
    }
}

// MARK: - Game Phase

enum MSPhase {
    case setup
    case playing
    case finished
}

// MARK: - Problem

struct MathProblem {
    let a: Int
    let b: Int
    var answer: Int { a * b }
}

// MARK: - ViewModel

@MainActor @Observable
final class MathSpeedViewModel {
    var phase: MSPhase = .setup
    var difficulty: MathDifficulty = .medium
    var totalProblems: Int = 20
    var currentProblemIndex: Int = 0
    var problems: [MathProblem] = []
    var userAnswer: String = ""
    var correctCount: Int = 0
    var wrongCount: Int = 0
    var results: [(problem: MathProblem, userAnswer: Int?, correct: Bool)] = []
    var challengeSeed: Int?
    var startTime: Date?
    var elapsedSeconds: Double = 0
    private var timer: Timer?

    var currentProblem: MathProblem? {
        guard currentProblemIndex < problems.count else { return nil }
        return problems[currentProblemIndex]
    }

    var progress: Double {
        guard totalProblems > 0 else { return 0 }
        return Double(currentProblemIndex) / Double(totalProblems)
    }

    var averageTimePerProblem: Double {
        guard correctCount + wrongCount > 0 else { return 0 }
        return elapsedSeconds / Double(correctCount + wrongCount)
    }

    var score: Double {
        guard totalProblems > 0 else { return 0 }
        let accuracy = Double(correctCount) / Double(totalProblems)
        let speedBonus: Double
        if averageTimePerProblem <= 2.0 {
            speedBonus = 1.0
        } else if averageTimePerProblem >= 8.0 {
            speedBonus = 0.0
        } else {
            speedBonus = (8.0 - averageTimePerProblem) / 6.0
        }
        return accuracy * 0.7 + speedBonus * 0.3
    }

    var durationSeconds: Int {
        Int(elapsedSeconds)
    }

    /// Composite leaderboard score: correct × 1000 + speed bonus (faster avg = higher)
    /// Speed bonus: 999 at ≤1s avg, 0 at ≥10s avg, linear between
    var leaderboardScore: Int {
        let speedBonus: Int
        if averageTimePerProblem <= 1.0 {
            speedBonus = 999
        } else if averageTimePerProblem >= 10.0 {
            speedBonus = 0
        } else {
            speedBonus = Int((10.0 - averageTimePerProblem) / 9.0 * 999.0)
        }
        return correctCount * 1000 + speedBonus
    }

    func startGame() {
        let range = difficulty.range
        if let seed = challengeSeed {
            var rng = SeededGenerator(seed: UInt64(seed))
            problems = (0..<totalProblems).map { _ in
                MathProblem(
                    a: Int.random(in: range, using: &rng),
                    b: Int.random(in: range, using: &rng)
                )
            }
        } else {
            problems = (0..<totalProblems).map { _ in
                MathProblem(
                    a: Int.random(in: range),
                    b: Int.random(in: range)
                )
            }
        }
        currentProblemIndex = 0
        correctCount = 0
        wrongCount = 0
        results = []
        userAnswer = ""
        startTime = Date.now
        elapsedSeconds = 0
        phase = .playing
        startTimer()
    }

    func submitAnswer() {
        guard let problem = currentProblem else { return }
        let parsed = Int(userAnswer)
        let isCorrect = parsed == problem.answer

        if isCorrect {
            correctCount += 1
            HapticService.correct()
        } else {
            wrongCount += 1
            HapticService.wrong()
        }

        results.append((problem: problem, userAnswer: parsed, correct: isCorrect))
        userAnswer = ""
        currentProblemIndex += 1

        if currentProblemIndex >= totalProblems {
            finishGame()
        }
    }

    func skipProblem() {
        guard let problem = currentProblem else { return }
        wrongCount += 1
        results.append((problem: problem, userAnswer: nil, correct: false))
        userAnswer = ""
        currentProblemIndex += 1

        if currentProblemIndex >= totalProblems {
            finishGame()
        }
    }

    private func finishGame() {
        stopTimer()
        HapticService.complete()
        phase = .finished
    }

    private func startTimer() {
        timer?.invalidate()
        timer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { [weak self] _ in
            Task { @MainActor in
                guard let self, let start = self.startTime else { return }
                self.elapsedSeconds = Date.now.timeIntervalSince(start)
            }
        }
    }

    private func stopTimer() {
        timer?.invalidate()
        timer = nil
    }

    func reset() {
        stopTimer()
        phase = .setup
    }
}

// MARK: - View

struct MathSpeedView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @Environment(AchievementService.self) private var achievementService
    @Environment(TrainingSessionManager.self) private var trainingManager
    @Environment(PaywallTriggerService.self) private var paywallTrigger
    @Environment(StoreService.self) private var storeService
    @Environment(GameCenterService.self) private var gameCenterService
    @Environment(DeepLinkRouter.self) private var deepLinkRouter
    @Query private var users: [User]

    @State private var viewModel = MathSpeedViewModel()
    @State private var showingPaywall = false
    @State private var isNewPersonalBest = false
    @State private var shareImage: UIImage?
    @State private var exerciseSaved = false
    @State private var activeChallenge: ChallengeLink?
    @State private var shakeAmount: CGFloat = 0
    @State private var correctPulse = false
    @State private var showingInfo = false
    // @State private var showingChallengeResult = false
    @FocusState private var inputFocused: Bool

    private var user: User? { users.first }
    private var isProUser: Bool { storeService.isProUser }

    var body: some View {
        VStack(spacing: 0) {
            switch viewModel.phase {
            case .setup:
                setupView
                    .transition(.opacity)
            case .playing:
                playingView
                    .transition(.opacity)
            case .finished:
                resultsView
                    .transition(.scale(scale: 0.95).combined(with: .opacity))
            }
        }
        .animation(.easeInOut(duration: 0.3), value: viewModel.phase)
        .sheet(isPresented: $showingPaywall) { PaywallView(isHighIntent: true) }
        /*
        .sheet(isPresented: $showingChallengeResult) {
            if let challenge = activeChallenge {
                FriendChallengeResultView(
                    challenge: challenge,
                    playerScore: viewModel.leaderboardScore,
                    onShareResult: { showingChallengeResult = false },
                    onChallengeAnother: { showingChallengeResult = false },
                    onDone: {
                        showingChallengeResult = false
                        deepLinkRouter.pendingChallenge = nil
                    }
                )
            }
        }
        */
        .navigationTitle("Math Speed")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            if let challenge = deepLinkRouter.pendingChallenge {
                viewModel.challengeSeed = challenge.seed
                activeChallenge = challenge
            }
        }
        .onChange(of: viewModel.phase) { _, newPhase in
            if newPhase == .finished {
                SoundService.shared.playComplete()
                isNewPersonalBest = PersonalBestTracker.shared.record(score: viewModel.correctCount, for: .mathSpeed)
                if isNewPersonalBest {
                    Analytics.personalBest(game: ExerciseType.mathSpeed.rawValue, score: viewModel.correctCount)
                }
                AdaptiveDifficultyEngine.shared.recordBlock(domain: .mathSpeed, correct: viewModel.correctCount, total: viewModel.totalProblems)
                // Auto-save so GC gets the score even if user doesn't tap Done
                saveExercise()
                let card = ExerciseShareCard(
                    exerciseName: "Math Speed",
                    exerciseIcon: "function",
                    accentColor: AppColors.amber,
                    mainValue: "\(viewModel.correctCount)",
                    mainLabel: "Correct",
                    ratingText: viewModel.score >= 0.9 ? "Math Genius" : viewModel.score >= 0.7 ? "Quick Thinker" : "Keep Practicing",
                    stats: [
                        ("Time", String(format: "%.1fs", viewModel.elapsedSeconds)),
                        ("Avg/Problem", String(format: "%.1fs", viewModel.averageTimePerProblem))
                    ],
                    ctaText: "Think you're faster?"
                )
                shareImage = card.renderAsImage(size: CGSize(width: 360, height: 640), scale: 3)
            }
        }
        .onDisappear {
            if viewModel.phase == .playing {
                Analytics.exerciseAbandoned(game: ExerciseType.mathSpeed.rawValue, roundReached: viewModel.currentProblemIndex)
            }
        }
        .onAppear {
            let level = AdaptiveDifficultyEngine.shared.currentLevel(for: .mathSpeed)
            switch level {
            case 1: viewModel.difficulty = .easy
            case 2...3: viewModel.difficulty = .medium
            default: viewModel.difficulty = .medium
            }
        }
    }

    // MARK: - Setup

    private var setupView: some View {
        VStack(spacing: 32) {
            Spacer()

            TrainingTileMiniPreview(type: .mathSpeed, color: AppColors.amber, scale: 2.0)
                .frame(width: 200, height: 140)

            VStack(spacing: 8) {
                Text("Math Speed")
                    .font(.title.weight(.bold))
                Text("Solve multiplication problems as fast as you can")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }

            // Difficulty picker
            VStack(spacing: 12) {
                Text("Difficulty")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.secondary)

                HStack(spacing: 10) {
                    ForEach(MathDifficulty.allCases) { diff in
                        Button {
                            withAnimation(.easeInOut(duration: 0.2)) {
                                viewModel.difficulty = diff
                            }
                        } label: {
                            VStack(spacing: 4) {
                                Text(diff.rawValue)
                                    .font(.subheadline.weight(.bold))
                                Text(diff.description)
                                    .font(.caption2)
                                    .foregroundStyle(.secondary)
                            }
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 12)
                            .background(
                                RoundedRectangle(cornerRadius: 12)
                                    .fill(viewModel.difficulty == diff
                                        ? AnyShapeStyle(LinearGradient(
                                            colors: [AppColors.amber.opacity(0.15), AppColors.amber.opacity(0.05)],
                                            startPoint: .top, endPoint: .bottom))
                                        : AnyShapeStyle(Color.gray.opacity(0.12)))
                            )
                            .overlay(
                                RoundedRectangle(cornerRadius: 12)
                                    .stroke(viewModel.difficulty == diff
                                        ? AppColors.amber.opacity(0.4)
                                        : Color.clear, lineWidth: 1.5)
                            )
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
            .appCard()
            .padding(.horizontal)

            Spacer()

            Button {
                Analytics.exerciseStarted(game: ExerciseType.mathSpeed.rawValue)
                viewModel.startGame()
            } label: {
                Text("Start")
                    .accentButton()
            }
            .pulsingWhenIdle()
            .accessibilityHint("Starts the exercise")
            .padding(.horizontal, 32)
        }
        .padding(.vertical, 24)
        .overlay(alignment: .topTrailing) {
            Button { showingInfo = true } label: {
                Image(systemName: "questionmark.circle.fill")
                    .font(.title3)
                    .foregroundStyle(.white.opacity(0.3))
            }
            .padding(16)
        }
        .sheet(isPresented: $showingInfo) {
            ExerciseInfoSheet(type: .mathSpeed)
                .presentationDetents([.medium])
        }
    }

    // MARK: - Playing

    private var playingView: some View {
        VStack(spacing: 16) {
            // Header
            HStack {
                Text("\(viewModel.currentProblemIndex + 1) / \(viewModel.totalProblems)")
                    .font(.headline.weight(.bold).monospacedDigit())
                    .foregroundStyle(AppColors.amber)
                    .contentTransition(.numericText())
                Spacer()
                Text(String(format: "%.1fs", viewModel.elapsedSeconds))
                    .font(.caption.weight(.medium).monospacedDigit())
                    .foregroundStyle(.secondary)
                    .contentTransition(.numericText())
                    .accessibilityLabel("Elapsed time: \(Int(viewModel.elapsedSeconds)) seconds")
            }
            .padding(.horizontal)

            ProgressView(value: viewModel.progress)
                .tint(AppColors.amber)
                .padding(.horizontal)

            // Score indicator
            HStack(spacing: 16) {
                Label("\(viewModel.correctCount)", systemImage: "checkmark.circle.fill")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(AppColors.teal)
                    .contentTransition(.numericText())
                Label("\(viewModel.wrongCount)", systemImage: "xmark.circle.fill")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(AppColors.coral)
                    .contentTransition(.numericText())
            }

            Spacer()

            // Problem display
            if let problem = viewModel.currentProblem {
                VStack(spacing: 12) {
                    Text("\(problem.a) × \(problem.b)")
                        .font(.system(size: 56, weight: .bold, design: .monospaced))
                        .accessibilityLabel("\(problem.a) times \(problem.b)")
                        .foregroundStyle(AppColors.accent)

                    Text("= ?")
                        .font(.system(size: 32, weight: .bold, design: .monospaced))
                        .foregroundStyle(.secondary)
                }
            }

            Spacer()

            // Input
            VStack(spacing: 12) {
                TextField("", text: $viewModel.userAnswer)
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
                            .stroke(AppColors.amber.opacity(0.3), lineWidth: 1.5)
                    )
                    .padding(.horizontal, 40)
                    .onSubmit {
                        if !viewModel.userAnswer.isEmpty {
                            viewModel.submitAnswer()
                        }
                    }

                HStack(spacing: 16) {
                    Button {
                        viewModel.skipProblem()
                    } label: {
                        Text("Skip")
                            .font(.subheadline.weight(.medium))
                            .foregroundStyle(.secondary)
                            .padding(.horizontal, 24)
                            .padding(.vertical, 12)
                            .background(Color.gray.opacity(0.12), in: Capsule())
                    }

                    Button {
                        viewModel.submitAnswer()
                    } label: {
                        Text("Submit")
                            .accentButton()
                    }
                    .disabled(viewModel.userAnswer.isEmpty)
                    .opacity(viewModel.userAnswer.isEmpty ? 0.5 : 1)
                }
                .padding(.horizontal, 32)
            }
            .padding(.bottom, 24)
        }
        .padding(.vertical, 16)
        .modifier(ShakeEffect(animatableData: shakeAmount))
        .scaleEffect(correctPulse ? 1.03 : 1.0)
        .animation(.spring(response: 0.2, dampingFraction: 0.5), value: correctPulse)
        .onChange(of: viewModel.currentProblemIndex) { _, _ in
            if let last = viewModel.results.last {
                if last.correct {
                    correctPulse = true
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) { correctPulse = false }
                } else {
                    withAnimation(.default) { shakeAmount += 1 }
                }
            }
        }
        .onAppear { inputFocused = true }
    }

    // MARK: - Results

    private var resultsView: some View {
        GameResultView(
            gameTitle: "Math Speed",
            gameIcon: "multiply.circle.fill",
            accentColor: AppColors.amber,
            mainScore: viewModel.correctCount,
            scoreLabel: "CORRECT",
            ratingText: viewModel.score >= 0.9 ? "Math Genius!" : viewModel.score >= 0.7 ? "Quick Thinker!" : "Keep Practicing!",
            stats: [
                (label: "Correct", value: "\(viewModel.correctCount) / \(viewModel.totalProblems)"),
                (label: "Time", value: String(format: "%.1fs", viewModel.elapsedSeconds)),
                (label: "Avg per Problem", value: String(format: "%.1fs", viewModel.averageTimePerProblem))
            ],
            isNewPersonalBest: isNewPersonalBest,
            personalBest: PersonalBestTracker.shared.best(for: .mathSpeed),
            exerciseType: .mathSpeed,
            leaderboardScore: viewModel.leaderboardScore,
            onPlayAgain: {
                exerciseSaved = false
                viewModel.reset()
                viewModel.startGame()
            },
            onDone: {
                saveExercise()
                dismiss()
            }
        )
    }

    private func generateShareCard() {
        guard let image = shareImage else { return }
        let activityVC = UIActivityViewController(activityItems: [image], applicationActivities: nil)
        if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
           let root = windowScene.windows.first?.rootViewController {
            root.present(activityVC, animated: true)
        }
    }

    // MARK: - Save

    private func saveExercise() {
        guard !exerciseSaved else { return }
        exerciseSaved = true
        paywallTrigger.recordExerciseCompleted(gameType: .mathSpeed)
        trainingManager.addTrainingTime(viewModel.durationSeconds)

        let exercise = Exercise(
            type: .mathSpeed,
            difficulty: viewModel.difficulty.difficultyValue,
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
                difficulty: viewModel.difficulty.difficultyValue,
                achievementService: achievementService,
                modelContext: modelContext,
                gameCenterService: gameCenterService,
                exerciseType: .mathSpeed,
                gameScore: viewModel.leaderboardScore
            )
        }
    }
}
