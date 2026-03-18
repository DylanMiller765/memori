import SwiftUI
import SwiftData
import GameKit

// MARK: - Game Phase

enum RTPhase {
    case setup
    case waiting
    case ready
    case tooEarly
    case result
    case finished
}

// MARK: - ViewModel

@MainActor @Observable
final class ReactionTimeViewModel {
    var phase: RTPhase = .setup
    var rounds: Int = 5
    var currentRound: Int = 0
    var reactionTimes: [Int] = []
    var lastReactionMs: Int = 0
    var reactionStartTime: Date?
    var startTime: Date?
    var challengeSeed: Int?
    private var rng: SeededGenerator?
    private var waitTimer: Timer?

    var averageMs: Int {
        guard !reactionTimes.isEmpty else { return 0 }
        return reactionTimes.reduce(0, +) / reactionTimes.count
    }

    var bestMs: Int {
        reactionTimes.min() ?? 0
    }

    var score: Double {
        let avg = Double(averageMs)
        if avg <= 0 { return 0 }
        // 200ms or less = 1.0, 500ms+ = 0.0
        return max(0, min(1, (500 - avg) / 300))
    }

    var durationSeconds: Int {
        guard let start = startTime else { return 0 }
        return Int(Date.now.timeIntervalSince(start))
    }

    var ratingText: String {
        let avg = averageMs
        if avg < 200 { return "Lightning Fast!" }
        if avg < 250 { return "Excellent!" }
        if avg < 300 { return "Great Reflexes!" }
        if avg < 350 { return "Good!" }
        if avg < 400 { return "Average" }
        return "Keep Practicing!"
    }

    func startGame() {
        reactionTimes = []
        currentRound = 0
        startTime = Date.now
        if let seed = challengeSeed {
            rng = SeededGenerator(seed: UInt64(seed))
        } else {
            rng = nil
        }
        startRound()
    }

    func startRound() {
        phase = .waiting
        let delay: Double
        if var r = rng {
            delay = Double.random(in: 1.5...4.0, using: &r)
            rng = r
        } else {
            delay = Double.random(in: 1.5...4.0)
        }
        waitTimer?.invalidate()
        waitTimer = Timer.scheduledTimer(withTimeInterval: delay, repeats: false) { [weak self] _ in
            Task { @MainActor in
                self?.phase = .ready
                self?.reactionStartTime = Date.now
            }
        }
    }

    func tappedDuringWait() {
        waitTimer?.invalidate()
        HapticService.wrong()
        phase = .tooEarly
    }

    func tappedOnGreen() {
        guard let start = reactionStartTime else { return }
        let ms = Int(Date.now.timeIntervalSince(start) * 1000)
        lastReactionMs = ms
        reactionTimes.append(ms)
        currentRound += 1
        HapticService.tap()
        phase = .result
    }

    func nextOrFinish() {
        if currentRound >= rounds {
            HapticService.complete()
            phase = .finished
        } else {
            startRound()
        }
    }

    func reset() {
        waitTimer?.invalidate()
        phase = .setup
    }
}

// MARK: - View

struct ReactionTimeView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @Environment(AchievementService.self) private var achievementService
    @Environment(TrainingSessionManager.self) private var trainingManager
    @Environment(PaywallTriggerService.self) private var paywallTrigger
    @Environment(StoreService.self) private var storeService
    @Environment(GameCenterService.self) private var gameCenterService
    @Query private var users: [User]

    @State private var viewModel = ReactionTimeViewModel()
    @State private var showingPaywall = false
    @State private var isNewPersonalBest = false
    @State private var shareImage: UIImage?

    private var user: User? { users.first }
    private var isProUser: Bool { storeService.isProUser || (user?.isProUser ?? false) }

    var body: some View {
        VStack(spacing: 0) {
            switch viewModel.phase {
            case .setup:
                setupView
            case .waiting:
                waitingView
            case .ready:
                goView
            case .tooEarly:
                tooEarlyView
            case .result:
                roundResultView
            case .finished:
                resultsView
            }
        }
        .sheet(isPresented: $showingPaywall) { PaywallView(isHighIntent: true) }
        .navigationTitle("Reaction Time")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar(viewModel.phase == .waiting || viewModel.phase == .ready || viewModel.phase == .tooEarly ? .hidden : .automatic, for: .tabBar)
        .toolbar(viewModel.phase == .waiting || viewModel.phase == .ready || viewModel.phase == .tooEarly ? .hidden : .automatic, for: .navigationBar)
        .onChange(of: viewModel.phase) { _, newPhase in
            if newPhase == .finished {
                SoundService.shared.playComplete()
                let invertedScore = viewModel.averageMs > 0 ? (1000 - viewModel.averageMs) : 0
                isNewPersonalBest = PersonalBestTracker.shared.record(score: invertedScore, for: .reactionTime)
                // Generate share card image
                let card = ReactionTimeShareCard(
                    averageMs: viewModel.averageMs,
                    bestMs: viewModel.bestMs,
                    ratingText: viewModel.ratingText,
                    roundTimes: viewModel.reactionTimes
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
                Image(systemName: "bolt.fill")
                    .font(.system(size: 52, weight: .medium))
                    .foregroundStyle(AppColors.accent)
            }

            VStack(spacing: 8) {
                Text("Reaction Time")
                    .font(.title.weight(.bold))
                Text("Tap as fast as you can when the screen turns green")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }

            VStack(alignment: .leading, spacing: 12) {
                infoRow(icon: "hand.tap", text: "Wait for the green screen, then tap immediately")
                infoRow(icon: "exclamationmark.triangle", text: "Don't tap too early or it won't count")
                infoRow(icon: "chart.line.downtrend.xyaxis", text: "Lower times = faster reactions")
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
                .foregroundStyle(AppColors.coral)
                .frame(width: 24)
            Text(text)
                .font(.subheadline)
        }
    }

    // MARK: - Waiting (Red/Dark)

    private var waitingView: some View {
        Color(red: 0.8, green: 0.15, blue: 0.15)
            .ignoresSafeArea()
            .overlay(
                VStack(spacing: 24) {
                    Text("Round \(viewModel.currentRound + 1) of \(viewModel.rounds)")
                        .font(.caption.weight(.medium))
                        .foregroundStyle(.white.opacity(0.5))

                    Text("Wait for green...")
                        .font(.title.weight(.bold))
                        .foregroundStyle(.white)
                }
            )
            .onTapGesture {
                viewModel.tappedDuringWait()
            }
    }

    // MARK: - Go (Green)

    private var goView: some View {
        Color(red: 0.15, green: 0.75, blue: 0.3)
            .ignoresSafeArea()
            .overlay(
                VStack(spacing: 24) {
                    Image(systemName: "hand.tap.fill")
                        .font(.system(size: 48))
                        .foregroundStyle(.white)

                    Text("TAP!")
                        .font(.system(size: 48, weight: .bold))
                        .foregroundStyle(.white)
                }
            )
            .onTapGesture {
                viewModel.tappedOnGreen()
            }
    }

    // MARK: - Too Early

    private var tooEarlyView: some View {
        Color(red: 0.85, green: 0.55, blue: 0.1)
            .ignoresSafeArea()
            .overlay(
                VStack(spacing: 20) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .font(.system(size: 48))
                        .foregroundStyle(.white)

                    Text("Too Early!")
                        .font(.title.weight(.bold))
                        .foregroundStyle(.white)
                    Text("Wait for the green screen before tapping")
                        .font(.subheadline)
                        .foregroundStyle(.white.opacity(0.7))

                    Button {
                        viewModel.startRound()
                    } label: {
                        Text("Try Again")
                            .font(.headline.weight(.bold))
                            .foregroundStyle(.white)
                            .padding(.horizontal, 32)
                            .padding(.vertical, 14)
                            .background(.white.opacity(0.25), in: Capsule())
                    }
                    .padding(.top, 8)
                }
            )
    }

    // MARK: - Round Result

    private var roundResultView: some View {
        VStack(spacing: 24) {
            Spacer()

            Text("\(viewModel.lastReactionMs)")
                .font(.system(size: 72, weight: .bold, design: .monospaced))
                .foregroundStyle(AppColors.accent)
                .accessibilityLabel("Reaction time: \(viewModel.lastReactionMs) milliseconds")

            Text("milliseconds")
                .font(.title3.weight(.medium))
                .foregroundStyle(.secondary)
                .accessibilityHidden(true)

            Text("Round \(viewModel.currentRound) of \(viewModel.rounds)")
                .font(.caption.weight(.medium))
                .foregroundStyle(.secondary)

            Spacer()

            Button {
                viewModel.nextOrFinish()
            } label: {
                Text(viewModel.currentRound >= viewModel.rounds ? "See Results" : "Next Round")
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
                    Image(systemName: "bolt.fill")
                        .font(.system(size: 24))
                        .foregroundStyle(.white)
                        .frame(width: 48, height: 48)
                        .background(AppColors.coral, in: RoundedRectangle(cornerRadius: 14))
                    Text(viewModel.ratingText)
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
                    resultRow(label: "Average", value: "\(viewModel.averageMs) ms")
                        .accessibilityElement(children: .combine)
                    resultRow(label: "Best", value: "\(viewModel.bestMs) ms")
                        .accessibilityElement(children: .combine)
                    Divider()
                    resultRow(label: "Score", value: viewModel.score.percentString)
                        .accessibilityElement(children: .combine)

                    HStack(spacing: 4) {
                        ForEach(Array(viewModel.reactionTimes.enumerated()), id: \.offset) { index, ms in
                            VStack(spacing: 4) {
                                Text("R\(index + 1)")
                                    .font(.caption2)
                                    .foregroundStyle(.secondary)
                                Text("\(ms)")
                                    .font(.caption.weight(.bold).monospacedDigit())
                                    .foregroundStyle(ms == viewModel.bestMs ? AppColors.accent : .primary)
                            }
                            .frame(maxWidth: .infinity)
                        }
                    }
                    .padding(.top, 4)
                }
                .glowingCard(color: AppColors.coral, intensity: 0.08)
                .padding(.horizontal)

                LeaderboardRankCard(
                    exerciseType: .reactionTime,
                    userScore: viewModel.averageMs,
                    isPro: isProUser,
                    onUpgradeTap: { showingPaywall = true }
                )
                .padding(.horizontal)

                VStack(spacing: 12) {
                    if let shareImage {
                        ShareLink(
                            item: Image(uiImage: shareImage),
                            preview: SharePreview("Reaction Time: \(viewModel.averageMs)ms", image: Image(uiImage: shareImage))
                        ) {
                            HStack(spacing: 8) {
                                Image(systemName: "square.and.arrow.up")
                                Text("Share Result")
                            }
                            .accentButton()
                        }
                    } else {
                        ShareLink(item: "My reaction time is \(viewModel.averageMs)ms — \(viewModel.ratingText)\n\nTest yours with Memori") {
                            HStack(spacing: 8) {
                                Image(systemName: "square.and.arrow.up")
                                Text("Share Result")
                            }
                            .accentButton()
                        }
                    }

                    if let challengeURL = ChallengeLink(
                        game: .reactionTime,
                        seed: viewModel.challengeSeed ?? ChallengeLink.randomSeed(),
                        score: viewModel.averageMs,
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

        let exercise = Exercise(
            type: .reactionTime,
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
                exerciseType: .reactionTime,
                gameScore: viewModel.averageMs
            )
        }
    }
}
