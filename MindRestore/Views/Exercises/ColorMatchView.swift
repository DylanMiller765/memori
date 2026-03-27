import SwiftUI
import SwiftData
import GameKit

// MARK: - ViewModel

@MainActor @Observable
final class ColorMatchViewModel {
    enum Phase { case setup, playing, finished }

    var phase: Phase = .setup
    var startTime: Date?
    var currentRound = 0
    let totalRounds = 20
    var correctCount = 0
    var responseTimes: [Double] = []
    var roundStartTime: Date?

    // Current round state
    var displayWord: String = ""
    var displayColor: Color = .white
    var correctAnswer: String = ""
    var feedbackColor: Color? = nil
    var showFeedback = false
    var lastWrongCorrectAnswer: String? = nil
    private var roundTimer: Timer?

    var challengeSeed: Int?
    private var rng: SeededGenerator?

    let colorOptions: [(name: String, color: Color)] = [
        ("Red", Color(red: 0.98, green: 0.42, blue: 0.35)),
        ("Blue", Color(red: 0.30, green: 0.55, blue: 1.0)),
        ("Green", Color(red: 0, green: 0.82, blue: 0.62)),
        ("Yellow", Color(red: 1.0, green: 0.76, blue: 0.28)),
        ("Purple", Color(red: 0.58, green: 0.34, blue: 0.92)),
    ]

    /// Time limit for current round in seconds (gets shorter as rounds progress)
    var timeLimit: Double {
        let base = 4.0
        let minimum = 1.5
        let reduction = Double(currentRound) * 0.12
        return max(minimum, base - reduction)
    }

    var accuracy: Double {
        guard currentRound > 0 else { return 0 }
        return Double(correctCount) / Double(currentRound)
    }

    var averageResponseMs: Int {
        guard !responseTimes.isEmpty else { return 0 }
        return Int(responseTimes.reduce(0, +) / Double(responseTimes.count) * 1000)
    }

    var score: Double {
        let accuracyComponent = accuracy * 0.6
        // Speed component: 500ms or less = 1.0, 2000ms+ = 0.0
        let avgMs = Double(averageResponseMs)
        let speedComponent: Double
        if avgMs <= 0 {
            speedComponent = 0
        } else {
            speedComponent = max(0, min(1, (2000 - avgMs) / 1500)) * 0.4
        }
        return min(1.0, accuracyComponent + speedComponent)
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
        if accuracy >= 0.95 { return "Stroop Master!" }
        if accuracy >= 0.85 { return "Excellent Focus!" }
        if accuracy >= 0.70 { return "Great Job!" }
        if accuracy >= 0.50 { return "Good Effort!" }
        return "Keep Practicing!"
    }

    // MARK: - Game Logic

    func startGame() {
        phase = .playing
        currentRound = 0
        correctCount = 0
        responseTimes = []
        startTime = Date.now
        feedbackColor = nil
        showFeedback = false
        if let seed = challengeSeed {
            rng = SeededGenerator(seed: UInt64(seed))
        } else {
            rng = nil
        }
        generateRound()
    }

    func generateRound() {
        guard currentRound < totalRounds else {
            phase = .finished
            return
        }

        // Pick a random word (color name)
        let wordIndex: Int
        if var r = rng {
            wordIndex = Int.random(in: 0..<colorOptions.count, using: &r)
            rng = r
        } else {
            wordIndex = Int.random(in: 0..<colorOptions.count)
        }
        displayWord = colorOptions[wordIndex].name.uppercased()

        // Pick a DIFFERENT color for the ink
        var inkIndex: Int
        repeat {
            if var r = rng {
                inkIndex = Int.random(in: 0..<colorOptions.count, using: &r)
                rng = r
            } else {
                inkIndex = Int.random(in: 0..<colorOptions.count)
            }
        } while inkIndex == wordIndex
        displayColor = colorOptions[inkIndex].color
        correctAnswer = colorOptions[inkIndex].name

        lastWrongCorrectAnswer = nil
        showFeedback = false
        feedbackColor = nil
        roundStartTime = Date.now
        startRoundTimer()
    }

    private func startRoundTimer() {
        roundTimer?.invalidate()
        let limit = timeLimit
        roundTimer = Timer.scheduledTimer(withTimeInterval: limit, repeats: false) { [weak self] _ in
            Task { @MainActor in
                guard let self, !self.showFeedback else { return }
                self.timeExpired()
            }
        }
    }

    private func timeExpired() {
        guard !showFeedback else { return }
        // Count as wrong — no response time recorded for timeout
        responseTimes.append(timeLimit)
        feedbackColor = Color(red: 0.98, green: 0.42, blue: 0.35)
        HapticService.wrong()
        lastWrongCorrectAnswer = correctAnswer
        showFeedback = true
        currentRound += 1

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.8) { [weak self] in
            guard let self else { return }
            if self.currentRound >= self.totalRounds {
                self.phase = .finished
                SoundService.shared.playComplete()
                HapticService.complete()
            } else {
                self.generateRound()
            }
        }
    }

    func submitAnswer(_ answer: String) {
        guard !showFeedback else { return }
        roundTimer?.invalidate()

        let responseTime = Date.now.timeIntervalSince(roundStartTime ?? Date.now)
        responseTimes.append(responseTime)

        let isCorrect = answer == correctAnswer
        if isCorrect {
            correctCount += 1
            feedbackColor = Color(red: 0, green: 0.82, blue: 0.62)
            SoundService.shared.playTap()
            HapticService.correct()
        } else {
            feedbackColor = Color(red: 0.98, green: 0.42, blue: 0.35)
            HapticService.wrong()
            lastWrongCorrectAnswer = correctAnswer
        }

        showFeedback = true
        currentRound += 1

        // Brief feedback flash then advance
        let delay: Double = isCorrect ? 0.45 : 0.8
        DispatchQueue.main.asyncAfter(deadline: .now() + delay) { [weak self] in
            guard let self else { return }
            if self.currentRound >= self.totalRounds {
                self.phase = .finished
                SoundService.shared.playComplete()
                HapticService.complete()
            } else {
                self.generateRound()
            }
        }
    }

    func reset() {
        roundTimer?.invalidate()
        phase = .setup
        currentRound = 0
        correctCount = 0
        responseTimes = []
        startTime = nil
        feedbackColor = nil
        showFeedback = false
    }
}

// MARK: - View

struct ColorMatchView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @Environment(AchievementService.self) private var achievementService
    @Environment(TrainingSessionManager.self) private var trainingManager
    @Environment(PaywallTriggerService.self) private var paywallTrigger
    @Environment(StoreService.self) private var storeService
    @Environment(GameCenterService.self) private var gameCenterService
    @Environment(DeepLinkRouter.self) private var deepLinkRouter
    @Query private var users: [User]

    @State private var viewModel = ColorMatchViewModel()
    @State private var showingPaywall = false
    @State private var shareImage: UIImage?
    @State private var activeChallenge: ChallengeLink?
    // @State private var showingChallengeResult = false

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
                    .transition(.opacity)
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
        .navigationTitle("Color Match")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            if let challenge = deepLinkRouter.pendingChallenge {
                viewModel.challengeSeed = challenge.seed
                activeChallenge = challenge
            }
        }
        .onChange(of: viewModel.phase) { _, newPhase in
            if newPhase == .finished {
                let card = ExerciseShareCard(
                    exerciseName: "Color Match",
                    exerciseIcon: "paintpalette.fill",
                    accentColor: AppColors.violet,
                    mainValue: viewModel.accuracy.percentString,
                    mainLabel: "Accuracy",
                    ratingText: viewModel.ratingText,
                    stats: [
                        ("Correct", "\(viewModel.correctCount) / \(viewModel.totalRounds)"),
                        ("Avg Response", "\(viewModel.averageResponseMs) ms"),
                        ("Score", viewModel.score.percentString)
                    ],
                    ctaText: "Think you're faster?"
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
                    .accessibilityHidden(true)
                Image(systemName: "paintpalette.fill")
                    .font(.system(size: 52, weight: .medium))
                    .foregroundStyle(AppColors.accent)
            }

            VStack(spacing: 8) {
                Text("Color Match")
                    .font(.title.weight(.bold))
                Text("Tap the color of the ink, not the word")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }

            VStack(alignment: .leading, spacing: 12) {
                infoRow(icon: "eye.fill", text: "A color word appears in a different ink color")
                infoRow(icon: "hand.tap.fill", text: "Tap the button matching the INK color")
                infoRow(icon: "brain.head.profile", text: "Based on the Stroop Effect — your brain wants to read the word, not see the color")
                infoRow(icon: "timer", text: "20 rounds, gets faster as you progress")
            }
            .appCard()
            .padding(.horizontal)

            Spacer()

            Button {
                Analytics.exerciseStarted(game: ExerciseType.colorMatch.rawValue)
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
                .foregroundStyle(AppColors.violet)
                .frame(width: 24)
            Text(text)
                .font(.subheadline)
        }
    }

    // MARK: - Playing

    private var playingView: some View {
        VStack(spacing: 24) {
            // Round counter + progress
            HStack {
                Text("Round \(viewModel.currentRound + 1)")
                    .font(.headline)
                    .foregroundStyle(AppColors.accent)
                Spacer()
                Text("\(viewModel.currentRound) / \(viewModel.totalRounds)")
                    .font(.caption.weight(.medium))
                    .foregroundStyle(.secondary)
            }
            .padding(.horizontal)

            ProgressView(value: Double(viewModel.currentRound), total: Double(viewModel.totalRounds))
                .tint(AppColors.accent)
                .padding(.horizontal)

            Spacer()

            // The Stroop word
            ZStack {
                // Feedback flash background
                if viewModel.showFeedback, let fbColor = viewModel.feedbackColor {
                    RoundedRectangle(cornerRadius: 24)
                        .fill(fbColor.opacity(0.15))
                        .frame(width: 280, height: 160)
                        .transition(.opacity)
                }

                Text(viewModel.displayWord)
                    .font(.system(size: 64, weight: .bold))
                    .foregroundStyle(viewModel.displayColor)
                    .accessibilityLabel("The word \(viewModel.displayWord) displayed in \(viewModel.correctAnswer) ink")

                // Show correct answer when wrong
                if viewModel.showFeedback, let correctColor = viewModel.lastWrongCorrectAnswer {
                    Text("Correct: \(correctColor)")
                        .font(.system(size: 18, weight: .bold))
                        .foregroundStyle(viewModel.colorOptions.first(where: { $0.name == correctColor })?.color ?? .white)
                        .transition(.opacity.combined(with: .move(edge: .bottom)))
                        .offset(y: 50)
                }
            }
            .frame(height: 160)
            .animation(.easeInOut(duration: 0.15), value: viewModel.displayWord)

            // Correct/incorrect count
            HStack(spacing: 16) {
                Label("\(viewModel.correctCount)", systemImage: "checkmark.circle.fill")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(AppColors.mint)
                Label("\(viewModel.currentRound - viewModel.correctCount)", systemImage: "xmark.circle.fill")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(AppColors.coral)
            }

            Spacer()

            // Color buttons
            VStack(spacing: 10) {
                HStack(spacing: 10) {
                    ForEach(0..<3, id: \.self) { index in
                        colorButton(for: viewModel.colorOptions[index])
                    }
                }
                HStack(spacing: 10) {
                    ForEach(3..<5, id: \.self) { index in
                        colorButton(for: viewModel.colorOptions[index])
                    }
                }
            }
            .padding(.horizontal, 16)
            .padding(.bottom, 8)
        }
        .padding(.vertical, 24)
    }

    private func colorButton(for option: (name: String, color: Color)) -> some View {
        Button {
            viewModel.submitAnswer(option.name)
        } label: {
            Text(option.name)
                .font(.headline.weight(.bold))
                .frame(maxWidth: .infinity)
                .padding(.vertical, 16)
                .background(
                    ZStack {
                        RoundedRectangle(cornerRadius: 12)
                            .fill(option.color.opacity(0.18))
                        RoundedRectangle(cornerRadius: 12)
                            .fill(
                                LinearGradient(
                                    colors: [option.color.opacity(0.12), .clear],
                                    startPoint: .top,
                                    endPoint: .bottom
                                )
                            )
                    }
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(option.color.opacity(0.3), lineWidth: 1)
                )
                .foregroundStyle(option.color)
        }
        .disabled(viewModel.showFeedback)
        .accessibilityLabel("Answer \(option.name)")
    }

    // MARK: - Results

    private var resultsView: some View {
        ScrollView(showsIndicators: false) {
            VStack(spacing: 16) {
                HStack(spacing: 12) {
                    Image(systemName: "paintpalette.fill")
                        .font(.system(size: 24))
                        .foregroundStyle(.white)
                        .frame(width: 48, height: 48)
                        .background(AppColors.violet, in: RoundedRectangle(cornerRadius: 14))
                    Text(viewModel.ratingText)
                        .font(.title2.weight(.bold))
                }
                .padding(.top, 20)

                VStack(spacing: 12) {
                    resultRow(label: "Accuracy", value: viewModel.accuracy.percentString)
                        .accessibilityElement(children: .combine)
                    resultRow(label: "Correct", value: "\(viewModel.correctCount) / \(viewModel.totalRounds)")
                        .accessibilityElement(children: .combine)
                    resultRow(label: "Avg Response", value: "\(viewModel.averageResponseMs) ms")
                        .accessibilityElement(children: .combine)
                    Divider()
                    resultRow(label: "Score", value: viewModel.score.percentString)
                        .accessibilityElement(children: .combine)
                    resultRow(label: "Time", value: viewModel.durationSeconds.durationString)
                        .accessibilityElement(children: .combine)
                }
                .glowingCard(color: AppColors.violet, intensity: 0.08)
                .padding(.horizontal)

                // Per-round breakdown
                VStack(alignment: .leading, spacing: 8) {
                    Text("The Stroop Effect")
                        .font(.subheadline.weight(.bold))
                    Text("Your brain automatically reads words faster than it processes colors. This exercise strengthens your cognitive flexibility and selective attention.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .appCard()
                .padding(.horizontal, 20)

                LeaderboardRankCard(
                    exerciseType: .colorMatch,
                    userScore: viewModel.leaderboardScore,
                )
                .padding(.horizontal)

                VStack(spacing: 12) {
                    if let shareImage {
                        ShareLink(
                            item: Image(uiImage: shareImage),
                            preview: SharePreview("Color Match: \(viewModel.accuracy.percentString)", image: Image(uiImage: shareImage))
                        ) {
                            HStack(spacing: 8) {
                                Image(systemName: "square.and.arrow.up")
                                Text("Share Result")
                            }
                            .accentButton()
                        }
                        .simultaneousGesture(TapGesture().onEnded { Analytics.shareTapped(game: ExerciseType.colorMatch.rawValue) })
                    }

                    /*
                    if let challengeURL = ChallengeLink(
                        game: .colorMatch,
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
                    */

                    /*
                    if let challenge = activeChallenge {
                        Button {
                            showingChallengeResult = true
                        } label: {
                            HStack(spacing: 8) {
                                Image(systemName: "person.2.fill")
                                Text("See Challenge Result")
                            }
                            .accentButton()
                        }
                    }
                    */

                    Button {
                        saveExercise()
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

        AdaptiveDifficultyEngine.shared.recordBlock(domain: .colorMatch, correct: viewModel.correctCount, total: viewModel.totalRounds)
        if PersonalBestTracker.shared.record(score: viewModel.correctCount, for: .colorMatch) {
            Analytics.personalBest(game: ExerciseType.colorMatch.rawValue, score: viewModel.correctCount)
        }

        let exercise = Exercise(
            type: .colorMatch,
            difficulty: 3,
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
                difficulty: 3,
                achievementService: achievementService,
                modelContext: modelContext,
                gameCenterService: gameCenterService,
                exerciseType: .colorMatch,
                gameScore: viewModel.leaderboardScore
            )
        }
    }
}
