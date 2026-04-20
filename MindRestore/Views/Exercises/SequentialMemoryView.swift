import SwiftUI
import SwiftData
import GameKit

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
    @Environment(DeepLinkRouter.self) private var deepLinkRouter
    @Query private var users: [User]

    @State private var viewModel = SequentialMemoryViewModel()
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
            case .showing:
                showingView
                    .transition(.opacity)
            case .input:
                inputView
                    .transition(.opacity)
            case .roundResult:
                roundResultView
                    .transition(.scale(scale: 0.95).combined(with: .opacity))
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
                    playerScore: viewModel.maxCorrectLength,
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
        .navigationTitle("Number Memory")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            if let challenge = deepLinkRouter.pendingChallenge {
                viewModel.challengeSeed = challenge.seed
                activeChallenge = challenge
            }
        }
        .onDisappear {
            if viewModel.phase != .setup && viewModel.phase != .finished {
                Analytics.exerciseAbandoned(game: ExerciseType.sequentialMemory.rawValue, roundReached: viewModel.round)
            }
        }
        .onChange(of: viewModel.phase) { _, newPhase in
            if newPhase == .roundResult {
                if let last = viewModel.roundResults.last {
                    if last.correct {
                        correctPulse = true
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) { correctPulse = false }
                    } else {
                        withAnimation(.default) { shakeAmount += 1 }
                    }
                }
            }
            if newPhase == .finished {
                SoundService.shared.playComplete()
                isNewPersonalBest = PersonalBestTracker.shared.record(score: viewModel.maxCorrectLength, for: .sequentialMemory)
                if isNewPersonalBest {
                    Analytics.personalBest(game: ExerciseType.sequentialMemory.rawValue, score: viewModel.maxCorrectLength)
                }
                AdaptiveDifficultyEngine.shared.recordBlock(domain: .sequentialMemory, correct: viewModel.correctRounds, total: viewModel.roundResults.count)
                // Auto-save so GC gets the score even if user doesn't tap Done
                saveExercise()
                let card = ExerciseShareCard(
                    exerciseName: "Number Memory",
                    exerciseIcon: "number.circle.fill",
                    accentColor: AppColors.teal,
                    mainValue: "\(viewModel.maxCorrectLength)",
                    mainLabel: "Digit Span",
                    ratingText: viewModel.maxCorrectLength >= 9 ? "Genius" : viewModel.maxCorrectLength >= 7 ? "Excellent" : viewModel.maxCorrectLength >= 5 ? "Good" : "Keep Training",
                    stats: [
                        ("Rounds Passed", "\(viewModel.roundResults.filter(\.correct).count)")
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

            TrainingTileMiniPreview(type: .sequentialMemory, color: AppColors.teal, scale: 2.0)
                .frame(width: 200, height: 140)

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
                Analytics.exerciseStarted(game: ExerciseType.sequentialMemory.rawValue)
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
            ExerciseInfoSheet(type: .sequentialMemory)
                .presentationDetents([.medium])
        }
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
                    .contentTransition(.numericText())
                Spacer()
                Text("Round \(viewModel.round + 1)")
                    .font(.caption.weight(.medium))
                    .foregroundStyle(.secondary)
                    .contentTransition(.numericText())
            }
            .padding(.horizontal)

            ProgressView(value: Double(viewModel.displayDigitIndex + 1), total: Double(viewModel.currentDigits.count))
                .tint(AppColors.teal)
                .padding(.horizontal)

            Spacer()

            if viewModel.isShowingDigit {
                VStack(spacing: 16) {
                    Text(viewModel.currentDisplayDigit)
                        .font(.system(size: 96, weight: .bold, design: .monospaced))
                        .foregroundStyle(AppColors.accent)
                        .id("digit-\(viewModel.displayDigitIndex)")
                        .transition(.scale(scale: 0.5).combined(with: .opacity))
                        .accessibilityLabel("Remember this number: \(viewModel.currentDisplayDigit)")

                    // Dot indicator showing position in sequence
                    HStack(spacing: 6) {
                        ForEach(0..<viewModel.currentDigits.count, id: \.self) { i in
                            Circle()
                                .fill(i == viewModel.displayDigitIndex ? AppColors.accent : AppColors.accent.opacity(0.2))
                                .frame(width: 8, height: 8)
                                .scaleEffect(i == viewModel.displayDigitIndex ? 1.2 : 1.0)
                                .animation(.easeInOut(duration: 0.15), value: viewModel.displayDigitIndex)
                        }
                    }
                }
                .animation(.spring(response: 0.3, dampingFraction: 0.6), value: viewModel.displayDigitIndex)
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
                .contentTransition(.numericText())

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
                    .onSubmit { viewModel.submitAnswer() }

                Text("\(viewModel.userInput.count) / \(viewModel.currentLength) digits")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .contentTransition(.numericText())

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

            Spacer()
        }
        .padding(.vertical, 24)
        .modifier(ShakeEffect(animatableData: shakeAmount))
        .scaleEffect(correctPulse ? 1.03 : 1.0)
        .animation(.spring(response: 0.2, dampingFraction: 0.5), value: correctPulse)
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
        let challengeLink = ChallengeLink(
            game: .sequentialMemory,
            seed: ChallengeLink.randomSeed(),
            score: viewModel.maxCorrectLength,
            challengerName: user?.username.isEmpty == false ? user!.username : "Someone"
        )
        return GameResultView(
            gameTitle: "Number Memory",
            gameIcon: "number.circle.fill",
            accentColor: AppColors.teal,
            mainScore: viewModel.maxCorrectLength,
            scoreLabel: "DIGITS",
            ratingText: viewModel.maxCorrectLength >= 9 ? "Genius!" : viewModel.maxCorrectLength >= 7 ? "Excellent!" : viewModel.maxCorrectLength >= 5 ? "Good!" : "Keep Training!",
            stats: [
                (label: "Max Digit Span", value: "\(viewModel.maxCorrectLength)"),
                (label: "Rounds Passed", value: "\(viewModel.roundResults.filter(\.correct).count)")
            ],
            isNewPersonalBest: isNewPersonalBest,
            personalBest: PersonalBestTracker.shared.best(for: .sequentialMemory),
            exerciseType: .sequentialMemory,
            leaderboardScore: viewModel.maxCorrectLength,
            activeChallenge: activeChallenge,
            challengeLink: challengeLink,
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
        paywallTrigger.recordExerciseCompleted(gameType: .sequentialMemory)
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
