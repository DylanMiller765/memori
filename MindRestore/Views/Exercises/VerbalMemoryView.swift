import SwiftUI
import SwiftData
import ConfettiSwiftUI

// MARK: - ViewModel

@MainActor @Observable
final class VerbalMemoryViewModel {
    enum Phase: Equatable { case setup, playing, finished }

    var phase: Phase = .setup
    var startTime: Date?
    var lives = 3
    var streak = 0
    var bestStreak = 0
    var totalSeen = 0
    var totalCorrect = 0
    var currentWord = ""

    var challengeSeed: Int?

    private var seenWords: Set<String> = []
    private var shownPool: [String] = []  // words shown so far (for re-showing)
    private var currentWordIsNew = true
    private var rng: SeededGenerator?

    // MARK: - Word Bank (~200 common 4-6 letter words)

    private let wordBank: [String] = [
        "apple", "brave", "chair", "dance", "eagle", "flame", "grape", "house",
        "ivory", "joker", "kneel", "lemon", "maple", "nerve", "ocean", "piano",
        "queen", "river", "stone", "tiger", "ultra", "vivid", "water", "youth",
        "amber", "beach", "cliff", "drift", "elite", "frost", "globe", "honey",
        "image", "judge", "knife", "labor", "magic", "night", "olive", "proud",
        "quiet", "robin", "solar", "trace", "unity", "vapor", "wheat", "badge",
        "candy", "delay", "event", "field", "grain", "horse", "input", "jewel",
        "knock", "lunar", "metal", "noble", "outer", "pearl", "quote", "radar",
        "shelf", "toast", "urban", "valve", "wound", "yield", "angel", "blank",
        "crane", "dream", "earth", "floor", "green", "heart", "inner", "jolly",
        "light", "march", "novel", "opera", "paint", "ranch", "scale", "thumb",
        "upper", "voice", "world", "bloom", "charm", "crown", "daisy", "ember",
        "fairy", "giant", "haven", "ideal", "joint", "kayak", "lotus", "mango",
        "nerve", "oasis", "pixel", "quilt", "reign", "spice", "thorn", "usher",
        "vault", "whirl", "blaze", "coral", "diver", "error", "flock", "ghost",
        "hover", "index", "jelly", "karma", "llama", "moose", "nylon", "orbit",
        "plume", "quest", "rumor", "shade", "trend", "union", "vigor", "wrist",
        "cabin", "depot", "exile", "forge", "glide", "humor", "irony", "jumbo",
        "kiosk", "llama", "mount", "nexus", "omega", "patch", "relay", "swirl",
        "trout", "venom", "wafer", "cargo", "dense", "elbow", "flush", "grasp",
        "haste", "ivory", "jumpy", "knack", "latch", "mocha", "notch", "oxide",
        "plaza", "ridge", "skill", "tulip", "uncle", "vibes", "wedge", "bonus",
        "clerk", "dough", "fable", "grill", "hiker", "inbox", "joust", "kebab",
        "lyric", "minor", "nasal", "onset", "prism", "react", "snowy", "token",
        "unzip", "vowel", "windy", "crisp", "dodge", "fetch", "guess", "hippo"
    ]

    // MARK: - Computed Properties

    var score: Double {
        min(1.0, max(0.0, Double(bestStreak) / 50.0))
    }

    var durationSeconds: Int {
        guard let start = startTime else { return 0 }
        return Int(Date.now.timeIntervalSince(start))
    }

    var leaderboardScore: Int {
        bestStreak
    }

    var accuracy: Double {
        guard totalSeen > 0 else { return 0 }
        return Double(totalCorrect) / Double(totalSeen)
    }

    var difficulty: Int {
        if score >= 0.8 { return 5 }
        if score >= 0.6 { return 4 }
        if score >= 0.4 { return 3 }
        if score >= 0.2 { return 2 }
        return 1
    }

    var ratingText: String {
        switch bestStreak {
        case 0...5: return "Getting Started"
        case 6...15: return "Not Bad"
        case 16...25: return "Average"
        case 26...40: return "Good"
        case 41...60: return "Great"
        case 61...80: return "Excellent"
        case 81...100: return "Outstanding"
        default: return "Legendary"
        }
    }

    // MARK: - Game Logic

    func startGame() {
        phase = .playing
        lives = 3
        streak = 0
        bestStreak = 0
        totalSeen = 0
        totalCorrect = 0
        seenWords = []
        shownPool = []
        startTime = Date.now

        if let seed = challengeSeed {
            rng = SeededGenerator(seed: UInt64(seed))
        } else {
            rng = nil
        }

        showNextWord()
    }

    func answerNew() {
        totalSeen += 1
        if currentWordIsNew {
            // Correct — this word IS new
            totalCorrect += 1
            streak += 1
            bestStreak = max(bestStreak, streak)
            HapticService.correct()
        } else {
            // Wrong — this word was seen before
            streak = 0
            lives -= 1
            HapticService.wrong()
            if lives <= 0 {
                finishGame()
                return
            }
        }
        showNextWord()
    }

    func answerSeen() {
        totalSeen += 1
        if !currentWordIsNew {
            // Correct — this word WAS seen before
            totalCorrect += 1
            streak += 1
            bestStreak = max(bestStreak, streak)
            HapticService.correct()
        } else {
            // Wrong — this word was actually new
            streak = 0
            lives -= 1
            HapticService.wrong()
            if lives <= 0 {
                finishGame()
                return
            }
        }
        showNextWord()
    }

    func reset() {
        phase = .setup
        lives = 3
        streak = 0
        bestStreak = 0
        totalSeen = 0
        totalCorrect = 0
        seenWords = []
        shownPool = []
        startTime = nil
        currentWord = ""
    }

    // MARK: - Private

    private func showNextWord() {
        // Probability of showing a seen word scales from 30% to 50% based on pool size
        let seenProbability: Double
        if shownPool.isEmpty {
            seenProbability = 0
        } else {
            // Scale from 0.3 to 0.5 as more words are seen
            seenProbability = min(0.5, 0.3 + Double(shownPool.count) * 0.005)
        }

        let roll = randomDouble()
        if roll < seenProbability, !shownPool.isEmpty {
            // Show a previously seen word
            let word = randomElement(from: shownPool)
            currentWord = word
            currentWordIsNew = false
        } else {
            // Show a new word
            let available = wordBank.filter { !seenWords.contains($0) }
            if available.isEmpty {
                // All words used, show a seen word
                let word = randomElement(from: shownPool)
                currentWord = word
                currentWordIsNew = false
            } else {
                let word = randomElement(from: available)
                currentWord = word
                currentWordIsNew = true
                seenWords.insert(word)
                shownPool.append(word)
            }
        }
    }

    private func finishGame() {
        phase = .finished
        SoundService.shared.playComplete()
        HapticService.complete()
    }

    private func randomDouble() -> Double {
        if var r = rng {
            let val = Double(r.next() % 1000) / 1000.0
            rng = r
            return val
        }
        return Double.random(in: 0..<1)
    }

    private func randomElement(from array: [String]) -> String {
        if var r = rng {
            let result = array.randomElement(using: &r) ?? array[0]
            rng = r
            return result
        }
        return array.randomElement() ?? array[0]
    }
}

// MARK: - View

struct VerbalMemoryView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @Environment(AchievementService.self) private var achievementService
    @Environment(TrainingSessionManager.self) private var trainingManager
    @Environment(PaywallTriggerService.self) private var paywallTrigger
    @Environment(StoreService.self) private var storeService
    @Environment(GameCenterService.self) private var gameCenterService
    @Environment(DeepLinkRouter.self) private var deepLinkRouter
    @Query private var users: [User]

    @State private var viewModel = VerbalMemoryViewModel()
    @State private var shareImage: UIImage?
    @State private var showingShareSheet = false
    @State private var showingPaywall = false
    @State private var isNewPersonalBest = false
    @State private var exerciseSaved = false
    @State private var activeChallenge: ChallengeLink?
    @State private var wordOffset: CGFloat = 0
    @State private var resultsAppeared = false
    @State private var showingInfo = false
    @State private var confettiCounter = 0

    private var user: User? { users.first }
    private var isProUser: Bool { storeService.isProUser || (user?.isProUser ?? false) }

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
        .navigationTitle("Verbal Memory")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            if let challenge = deepLinkRouter.pendingChallenge {
                viewModel.challengeSeed = challenge.seed
                activeChallenge = challenge
            }
        }
        .onDisappear {
            if viewModel.phase == .playing {
                Analytics.exerciseAbandoned(game: ExerciseType.verbalMemory.rawValue, roundReached: viewModel.totalSeen)
            }
        }
        .onChange(of: viewModel.phase) { _, newPhase in
            if newPhase == .finished {
                isNewPersonalBest = PersonalBestTracker.shared.record(score: viewModel.leaderboardScore, for: .verbalMemory)
                if isNewPersonalBest {
                    Analytics.personalBest(game: ExerciseType.verbalMemory.rawValue, score: viewModel.leaderboardScore)
                }
                saveExercise()
                generateShareCard()
            }
        }
    }

    // MARK: - Setup

    private var setupView: some View {
        VStack(spacing: 32) {
            Spacer()

            TrainingTileMiniPreview(type: .verbalMemory, color: AppColors.violet, scale: 2.0)
                .frame(width: 200, height: 140)

            VStack(spacing: 8) {
                Text("Verbal Memory")
                    .font(.title.weight(.bold))
                Text("How many words can you remember?")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }

            VStack(alignment: .leading, spacing: 12) {
                infoRow(icon: "eye", text: "Words appear one at a time")
                infoRow(icon: "hand.tap", text: "Tap NEW or SEEN for each word")
                infoRow(icon: "heart.fill", text: "3 lives — wrong answers cost a life")
                infoRow(icon: "flame.fill", text: "Build the longest streak you can")
            }
            .appCard()
            .padding(.horizontal)

            Spacer()

            Button {
                Analytics.exerciseStarted(game: ExerciseType.verbalMemory.rawValue)
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
            ExerciseInfoSheet(type: .verbalMemory)
                .presentationDetents([.medium])
        }
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
            // Header: streak (left) + hearts (right)
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Streak")
                        .font(.caption.weight(.medium))
                        .foregroundStyle(.secondary)
                    Text("\(viewModel.streak)")
                        .font(.system(size: 32, weight: .bold, design: .rounded))
                        .foregroundStyle(AppColors.violet)
                        .contentTransition(.numericText())
                        .animation(.spring(response: 0.3, dampingFraction: 0.7), value: viewModel.streak)
                }

                Spacer()

                HStack(spacing: 6) {
                    ForEach(0..<3, id: \.self) { index in
                        Image(systemName: index < viewModel.lives ? "heart.fill" : "heart")
                            .font(.title3)
                            .foregroundStyle(index < viewModel.lives ? AppColors.coral : AppColors.coral.opacity(0.3))
                            .animation(.spring(response: 0.3, dampingFraction: 0.6), value: viewModel.lives)
                    }
                }
            }
            .padding(.horizontal, 24)
            .padding(.top, 16)

            Spacer()

            // Word display
            Text(viewModel.currentWord)
                .font(.system(size: 42, weight: .bold, design: .rounded))
                .foregroundStyle(.primary)
                .offset(y: wordOffset)
                .animation(.spring(response: 0.35, dampingFraction: 0.6), value: wordOffset)
                .onChange(of: viewModel.currentWord) { _, _ in
                    wordOffset = 15
                    withAnimation(.spring(response: 0.35, dampingFraction: 0.6)) {
                        wordOffset = 0
                    }
                }

            Spacer()

            // NEW and SEEN buttons
            HStack(spacing: 16) {
                Button {
                    viewModel.answerNew()
                } label: {
                    Text("NEW")
                        .font(.headline.weight(.bold))
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 18)
                        .background(AppColors.accent, in: RoundedRectangle(cornerRadius: 16))
                }

                Button {
                    viewModel.answerSeen()
                } label: {
                    Text("SEEN")
                        .font(.headline.weight(.bold))
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 18)
                        .background(AppColors.violet, in: RoundedRectangle(cornerRadius: 16))
                }
            }
            .padding(.horizontal, 24)
            .padding(.bottom, 32)
        }
    }

    // MARK: - Results

    private var resultsView: some View {
        let challengeLink = ChallengeLink(
            game: .verbalMemory,
            seed: ChallengeLink.randomSeed(),
            score: viewModel.leaderboardScore,
            challengerName: user?.username.isEmpty == false ? user!.username : "Someone"
        )
        return GameResultView(
            gameTitle: "Verbal Memory",
            gameIcon: "text.book.closed.fill",
            accentColor: AppColors.violet,
            mainScore: viewModel.bestStreak,
            scoreLabel: "BEST STREAK",
            ratingText: viewModel.ratingText,
            stats: [
                (label: "Words Seen", value: "\(viewModel.totalSeen)"),
                (label: "Accuracy", value: String(format: "%.0f%%", viewModel.accuracy * 100)),
                (label: "Time", value: viewModel.durationSeconds.durationString)
            ],
            isNewPersonalBest: isNewPersonalBest,
            personalBest: PersonalBestTracker.shared.best(for: .verbalMemory),
            exerciseType: .verbalMemory,
            leaderboardScore: viewModel.bestStreak,
            activeChallenge: activeChallenge,
            challengeLink: challengeLink,
            onPlayAgain: {
                exerciseSaved = false
                viewModel.reset()
            },
            onDone: { dismiss() }
        )
    }

    // MARK: - Save

    private func saveExercise() {
        guard !exerciseSaved else { return }
        exerciseSaved = true
        paywallTrigger.recordExerciseCompleted(gameType: .verbalMemory)
        trainingManager.addTrainingTime(viewModel.durationSeconds)

        let exercise = Exercise(
            type: .verbalMemory,
            difficulty: viewModel.difficulty,
            score: viewModel.score,
            durationSeconds: viewModel.durationSeconds
        )
        modelContext.insert(exercise)

        let descriptor = FetchDescriptor<DailySession>(sortBy: [SortDescriptor(\.date, order: .reverse)])
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

        AdaptiveDifficultyEngine.shared.recordBlock(domain: .verbalMemory, correct: viewModel.totalCorrect, total: viewModel.totalSeen)

        if let user {
            _ = ContentView.awardXP(
                user: user,
                score: viewModel.score,
                difficulty: viewModel.difficulty,
                achievementService: achievementService,
                modelContext: modelContext,
                gameCenterService: gameCenterService,
                exerciseType: .verbalMemory,
                gameScore: viewModel.bestStreak
            )
        }

        gameCenterService.reportScore(viewModel.leaderboardScore, leaderboardID: GameCenterService.verbalMemoryLeaderboard)
    }

    // MARK: - Share Card

    private func prerenderShareCard() {
        let card = ExerciseShareCard(
            exerciseName: "Verbal Memory",
            exerciseIcon: "text.book.closed.fill",
            accentColor: AppColors.violet,
            mainValue: "\(viewModel.bestStreak)",
            mainLabel: "BEST STREAK",
            ratingText: viewModel.ratingText,
            stats: [
                ("Accuracy", String(format: "%.0f%%", viewModel.accuracy * 100)),
                ("Words", "\(viewModel.totalSeen)")
            ],
            ctaText: "How many words can you remember?"
        )
        shareImage = card.renderAsImage(size: CGSize(width: 360, height: 640), scale: 3)
    }

    private func generateShareCard() {
        if shareImage == nil { prerenderShareCard() }
        guard let image = shareImage else { return }
        let activityVC = UIActivityViewController(activityItems: [image], applicationActivities: nil)
        if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
           let root = windowScene.windows.first?.rootViewController {
            root.present(activityVC, animated: true)
        }
    }
}
