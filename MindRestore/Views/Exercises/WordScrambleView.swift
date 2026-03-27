import SwiftUI
import SwiftData
import GameKit

// MARK: - ViewModel

@MainActor @Observable
final class WordScrambleViewModel {
    enum Phase: Equatable { case setup, playing, finished }

    var phase: Phase = .setup
    var startTime: Date?
    var currentRound = 0
    let totalRounds = 10
    var wordsCorrect = 0
    var roundTimes: [Double] = []

    // Current round state
    var targetWord = ""
    var scrambledLetters: [LetterTile] = []
    var answerSlots: [LetterTile] = []
    var timeRemaining: Double = 15.0
    var totalTimeForRound: Double = 15.0
    var roundActive = false
    var roundResult: RoundResult? = nil

    var challengeSeed: Int?

    private var timer: Timer?
    private var usedWords: Set<String> = []
    private var rng: SeededGenerator?

    struct LetterTile: Identifiable, Equatable {
        let id = UUID()
        let letter: String
    }

    enum RoundResult: Equatable {
        case correct, timeout
    }

    // Word lists
    private static let easyWords = ["BRAIN", "THINK", "FOCUS", "SMART", "QUICK", "LEARN", "SHARP", "SPEED", "LOGIC", "SOLVE", "POWER", "ALERT", "STUDY", "TRAIN", "SKILL"]
    private static let mediumWords = ["MEMORY", "RECALL", "MENTAL", "CLEVER", "PUZZLE", "WISDOM", "BRIGHT", "NEURON", "REFLEX", "CORTEX", "MASTER", "GENIUS", "REASON", "GROWTH", "ACTIVE"]
    private static let hardWords = ["COGNITION", "ATTENTION", "INTELLECT", "CHALLENGE", "EXCELLENT", "BRILLIANT", "SYNAPSE", "DENDRITE", "COGNITIVE", "STRATEGY", "REMEMBER", "PRACTICE", "CREATIVE", "REACTION", "CAPACITY"]

    // MARK: - Computed Properties

    var score: Double {
        guard totalRounds > 0 else { return 0 }
        var total = 0.0
        for i in 0..<min(currentRound, roundScores.count) {
            total += roundScores[i]
        }
        return total / Double(totalRounds)
    }

    private var roundScores: [Double] = []

    var durationSeconds: Int {
        guard let start = startTime else { return 0 }
        return Int(Date.now.timeIntervalSince(start))
    }

    var averageTime: Double {
        guard !roundTimes.isEmpty else { return 0 }
        return roundTimes.reduce(0, +) / Double(roundTimes.count)
    }

    var longestWordSolved: String {
        // Track solved words
        return solvedWords.max(by: { $0.count < $1.count }) ?? "--"
    }

    private var solvedWords: [String] = []

    var ratingText: String {
        let pct = score
        if pct >= 0.9 { return "Word Wizard!" }
        if pct >= 0.75 { return "Excellent!" }
        if pct >= 0.55 { return "Great Job!" }
        if pct >= 0.35 { return "Good Effort!" }
        return "Keep Practicing!"
    }

    /// Composite leaderboard score: primary score × 1000 + time bonus (faster = higher)
    var leaderboardScore: Int {
        wordsCorrect * 1000 + max(0, 999 - durationSeconds)
    }

    var difficulty: Int {
        if score >= 0.8 { return 5 }
        if score >= 0.6 { return 4 }
        if score >= 0.4 { return 3 }
        if score >= 0.2 { return 2 }
        return 1
    }

    var timerProgress: Double {
        guard totalTimeForRound > 0 else { return 0 }
        return max(0, timeRemaining / totalTimeForRound)
    }

    // MARK: - Game Logic

    func startGame() {
        phase = .playing
        currentRound = 0
        wordsCorrect = 0
        roundTimes = []
        roundScores = []
        solvedWords = []
        usedWords = []
        startTime = Date.now
        if let seed = challengeSeed {
            rng = SeededGenerator(seed: UInt64(seed))
        } else {
            rng = nil
        }
        startRound()
    }

    func startRound() {
        guard currentRound < totalRounds else {
            finishGame()
            return
        }

        let word = pickWord(for: currentRound)
        targetWord = word
        usedWords.insert(word)

        // Scramble the letters (ensure it's different from original)
        var letters = word.map { String($0) }
        var attempts = 0
        repeat {
            if var r = rng {
                letters = letters.shuffled(using: &r)
                rng = r
            } else {
                letters.shuffle()
            }
            attempts += 1
        } while letters.joined() == word && attempts < 20

        scrambledLetters = letters.map { LetterTile(letter: $0) }
        answerSlots = []
        roundResult = nil

        // Timer: starts at 15s, decreases by 1s each round, min 8s
        totalTimeForRound = max(8.0, 15.0 - Double(currentRound))
        timeRemaining = totalTimeForRound
        roundActive = true

        startTimer()
    }

    func tapAvailableLetter(_ tile: LetterTile) {
        guard roundActive, roundResult == nil else { return }
        guard let index = scrambledLetters.firstIndex(where: { $0.id == tile.id }) else { return }

        scrambledLetters.remove(at: index)
        answerSlots.append(tile)
        SoundService.shared.playTap()

        // Check if answer is complete
        if answerSlots.count == targetWord.count {
            checkAnswer()
        }
    }

    func tapAnswerLetter(_ tile: LetterTile) {
        guard roundActive, roundResult == nil else { return }
        guard let index = answerSlots.firstIndex(where: { $0.id == tile.id }) else { return }

        answerSlots.remove(at: index)
        scrambledLetters.append(tile)
    }

    func clearAnswer() {
        guard roundActive, roundResult == nil else { return }
        scrambledLetters.append(contentsOf: answerSlots)
        answerSlots = []
    }

    private func checkAnswer() {
        let answer = answerSlots.map(\.letter).joined()
        stopTimer()

        let elapsed = totalTimeForRound - timeRemaining

        if answer == targetWord {
            roundTimes.append(elapsed)
            // Correct
            roundResult = .correct
            wordsCorrect += 1
            solvedWords.append(targetWord)
            let timeBonus = max(0, timeRemaining / totalTimeForRound)
            roundScores.append(0.5 + 0.5 * timeBonus)
            HapticService.correct()
            SoundService.shared.playComplete()

            DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) { [weak self] in
                self?.advanceRound()
            }
        } else {
            // Wrong - let them keep trying (don't end round on wrong answer)
            // Move all letters back
            HapticService.wrong()
            scrambledLetters.append(contentsOf: answerSlots)
            answerSlots = []
            // Restart timer for this attempt
            startTimer()
        }
    }

    private func timeExpired() {
        roundResult = .timeout
        roundActive = false
        roundTimes.append(totalTimeForRound)
        roundScores.append(0.0)
        HapticService.wrong()

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.25) { [weak self] in
            self?.advanceRound()
        }
    }

    private func advanceRound() {
        currentRound += 1
        if currentRound >= totalRounds {
            finishGame()
        } else {
            startRound()
        }
    }

    private func finishGame() {
        stopTimer()
        phase = .finished
        SoundService.shared.playComplete()
        HapticService.complete()
    }

    // MARK: - Timer

    private func startTimer() {
        stopTimer()
        timer = Timer.scheduledTimer(withTimeInterval: 0.05, repeats: true) { [weak self] _ in
            Task { @MainActor in
                guard let self, self.roundActive else { return }
                self.timeRemaining -= 0.05
                if self.timeRemaining <= 0 {
                    self.timeRemaining = 0
                    self.stopTimer()
                    self.timeExpired()
                }
            }
        }
    }

    private func stopTimer() {
        timer?.invalidate()
        timer = nil
    }

    // MARK: - Word Selection

    private func pickWord(for round: Int) -> String {
        let pool: [String]
        switch round {
        case 0...2:
            pool = Self.easyWords.filter { !usedWords.contains($0) }
        case 3...6:
            pool = Self.mediumWords.filter { !usedWords.contains($0) }
        default:
            pool = Self.hardWords.filter { !usedWords.contains($0) }
        }
        if var r = rng {
            let result = pool.randomElement(using: &r) ?? "BRAIN"
            rng = r
            return result
        }
        return pool.randomElement() ?? "BRAIN"
    }

    func reset() {
        stopTimer()
        phase = .setup
        currentRound = 0
        wordsCorrect = 0
        roundTimes = []
        roundScores = []
        solvedWords = []
        usedWords = []
        startTime = nil
        roundResult = nil
        roundActive = false
    }
}

// MARK: - View

struct WordScrambleView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @Environment(AchievementService.self) private var achievementService
    @Environment(TrainingSessionManager.self) private var trainingManager
    @Environment(PaywallTriggerService.self) private var paywallTrigger
    @Environment(StoreService.self) private var storeService
    @Environment(GameCenterService.self) private var gameCenterService
    @Environment(DeepLinkRouter.self) private var deepLinkRouter
    @Query private var users: [User]

    @State private var viewModel = WordScrambleViewModel()
    @State private var showingPaywall = false
    @State private var shareImage: UIImage?
    @State private var isNewPersonalBest = false
    @State private var activeChallenge: ChallengeLink?
    // @State private var showingChallengeResult = false
    @Namespace private var tileNamespace

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
                    .transition(.opacity)
            }
        }
        .animation(.easeInOut(duration: 0.15), value: viewModel.phase)
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
        .navigationTitle("Word Scramble")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            if let challenge = deepLinkRouter.pendingChallenge {
                viewModel.challengeSeed = challenge.seed
                activeChallenge = challenge
            }
        }
        .onChange(of: viewModel.phase) { _, newPhase in
            if newPhase == .finished {
                isNewPersonalBest = PersonalBestTracker.shared.record(score: viewModel.leaderboardScore, for: .wordScramble)
                AdaptiveDifficultyEngine.shared.recordBlock(domain: .wordScramble, correct: viewModel.wordsCorrect, total: viewModel.totalRounds)

                let avgTimeFormatted = String(format: "%.1f", viewModel.averageTime)
                let card = ExerciseShareCard(
                    exerciseName: "Word Scramble",
                    exerciseIcon: "textformat.abc.dottedunderline",
                    accentColor: AppColors.rose,
                    mainValue: "\(viewModel.wordsCorrect)/10",
                    mainLabel: "Words Solved",
                    ratingText: viewModel.ratingText,
                    stats: [
                        ("Avg Time", "\(avgTimeFormatted)s"),
                        ("Longest Word", viewModel.longestWordSolved),
                        ("Accuracy", "\(Int(viewModel.score * 100))%")
                    ],
                    ctaText: "Can you unscramble faster?"
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
                Image(systemName: "textformat.abc.dottedunderline")
                    .font(.system(size: 48, weight: .medium))
                    .foregroundStyle(AppColors.rose)
            }

            VStack(spacing: 8) {
                Text("Word Scramble")
                    .font(.title.weight(.bold))
                Text("Unscramble words against the clock")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }

            VStack(alignment: .leading, spacing: 12) {
                infoRow(icon: "textformat.abc", text: "Tap letters in order to spell the word")
                infoRow(icon: "timer", text: "Timer gets shorter each round")
                infoRow(icon: "arrow.up.right", text: "Words get longer and harder")
                infoRow(icon: "star.fill", text: "10 rounds — score based on speed")
            }
            .appCard()
            .padding(.horizontal)

            Spacer()

            Button {
                Analytics.exerciseStarted(game: ExerciseType.wordScramble.rawValue)
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
                .foregroundStyle(AppColors.rose)
                .frame(width: 24)
            Text(text)
                .font(.subheadline)
        }
    }

    // MARK: - Playing

    private var playingView: some View {
        VStack(spacing: 16) {
            // Round counter + progress
            HStack {
                Text("Round \(viewModel.currentRound + 1)")
                    .font(.headline)
                    .foregroundStyle(AppColors.rose)
                Spacer()
                Text("\(viewModel.currentRound) / \(viewModel.totalRounds)")
                    .font(.caption.weight(.medium))
                    .foregroundStyle(.secondary)
            }
            .padding(.horizontal)

            // Timer bar
            GeometryReader { geometry in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 3)
                        .fill(Color.primary.opacity(0.08))
                        .frame(height: 6)

                    RoundedRectangle(cornerRadius: 3)
                        .fill(timerColor)
                        .frame(width: geometry.size.width * viewModel.timerProgress, height: 6)
                        .animation(.linear(duration: 0.05), value: viewModel.timerProgress)
                }
            }
            .frame(height: 6)
            .padding(.horizontal)

            // Time remaining text
            Text(String(format: "%.1fs", max(0, viewModel.timeRemaining)))
                .font(.system(size: 14, weight: .bold, design: .monospaced))
                .foregroundStyle(timerColor)

            Spacer()

            // Round result feedback
            if let result = viewModel.roundResult {
                Group {
                    switch result {
                    case .correct:
                        HStack(spacing: 8) {
                            Image(systemName: "checkmark.circle.fill")
                            Text("Correct!")
                        }
                        .font(.title2.weight(.bold))
                        .foregroundStyle(AppColors.teal)
                    case .timeout:
                        VStack(spacing: 4) {
                            HStack(spacing: 8) {
                                Image(systemName: "clock.badge.xmark")
                                Text("Time's Up!")
                            }
                            .font(.title2.weight(.bold))
                            .foregroundStyle(AppColors.coral)
                            Text("The word was: \(viewModel.targetWord)")
                                .font(.subheadline.weight(.semibold))
                                .foregroundStyle(.secondary)
                        }
                    }
                }
                .transition(.scale.combined(with: .opacity))
            } else {
                // Answer row
                VStack(spacing: 8) {
                    Text("YOUR ANSWER")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundStyle(.secondary)
                        .tracking(1.5)

                    HStack(spacing: 6) {
                        ForEach(0..<viewModel.targetWord.count, id: \.self) { index in
                            if index < viewModel.answerSlots.count {
                                letterTile(viewModel.answerSlots[index], isAnswer: true)
                            } else {
                                // Empty slot
                                RoundedRectangle(cornerRadius: 8)
                                    .stroke(Color.primary.opacity(0.15), style: StrokeStyle(lineWidth: 2, dash: [5]))
                                    .frame(width: tileSize, height: tileSize)
                            }
                        }
                    }
                }
            }

            Spacer()

            // Scrambled letters row
            if viewModel.roundResult == nil {
                VStack(spacing: 12) {
                    Text("AVAILABLE LETTERS")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundStyle(.secondary)
                        .tracking(1.5)

                    // Wrap letters if needed
                    WrappingHStack(items: viewModel.scrambledLetters, spacing: 6) { tile in
                        letterTile(tile, isAnswer: false)
                    }
                    .padding(.horizontal, 8)
                }
            }

            Spacer()

            // Clear button
            if viewModel.roundResult == nil && !viewModel.answerSlots.isEmpty {
                Button {
                    withAnimation(.spring(response: 0.08, dampingFraction: 0.85)) {
                        viewModel.clearAnswer()
                    }
                } label: {
                    HStack(spacing: 6) {
                        Image(systemName: "arrow.counterclockwise")
                        Text("Clear")
                    }
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(AppColors.coral)
                    .padding(.horizontal, 20)
                    .padding(.vertical, 10)
                    .background(AppColors.coral.opacity(0.12), in: Capsule())
                }
            }

            // Score bar
            HStack(spacing: 16) {
                Label("\(viewModel.wordsCorrect)", systemImage: "checkmark.circle.fill")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(AppColors.teal)
                Label("\(viewModel.currentRound - viewModel.wordsCorrect)", systemImage: "xmark.circle.fill")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(AppColors.coral)
            }
            .padding(.bottom, 16)
        }
        .padding(.vertical, 16)
    }

    private var tileSize: CGFloat {
        let letterCount = viewModel.targetWord.count
        if letterCount <= 5 { return 48 }
        if letterCount <= 7 { return 42 }
        return 36
    }

    private var timerColor: Color {
        if viewModel.timerProgress > 0.5 { return AppColors.teal }
        if viewModel.timerProgress > 0.25 { return AppColors.amber }
        return AppColors.coral
    }

    @State private var tappedTileID: UUID?

    private func letterTile(_ tile: WordScrambleViewModel.LetterTile, isAnswer: Bool) -> some View {
        Button {
            tappedTileID = tile.id
            withAnimation(.spring(response: 0.08, dampingFraction: 0.85)) {
                if isAnswer {
                    viewModel.tapAnswerLetter(tile)
                } else {
                    viewModel.tapAvailableLetter(tile)
                }
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.08) {
                tappedTileID = nil
            }
        } label: {
            Text(tile.letter)
                .font(.system(size: tileSize * 0.45, weight: .bold, design: .rounded))
                .foregroundStyle(isAnswer ? .white : AppColors.accent)
                .frame(width: tileSize, height: tileSize)
                .background(
                    RoundedRectangle(cornerRadius: 10)
                        .fill(isAnswer ? AppColors.accent : AppColors.accent.opacity(0.12))
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 10)
                        .stroke(AppColors.accent.opacity(isAnswer ? 0.0 : 0.25), lineWidth: 1.5)
                )
                .scaleEffect(tappedTileID == tile.id ? 0.88 : 1.0)
                .animation(.spring(response: 0.06, dampingFraction: 0.6), value: tappedTileID)
        }
        .matchedGeometryEffect(id: tile.id, in: tileNamespace)
        .buttonStyle(.plain)
    }

    // MARK: - Results

    private var resultsView: some View {
        ScrollView(showsIndicators: false) {
            VStack(spacing: 16) {
                HStack(spacing: 12) {
                    Image(systemName: "textformat.abc.dottedunderline")
                        .font(.system(size: 24))
                        .foregroundStyle(.white)
                        .frame(width: 48, height: 48)
                        .background(AppColors.rose, in: RoundedRectangle(cornerRadius: 14))
                    VStack(alignment: .leading, spacing: 2) {
                        Text(viewModel.ratingText)
                            .font(.title2.weight(.bold))
                        if isNewPersonalBest {
                            Text("New Personal Best!")
                                .font(.caption.weight(.bold))
                                .foregroundStyle(AppColors.amber)
                        }
                    }
                }
                .padding(.top, 20)

                VStack(spacing: 12) {
                    resultRow(label: "Words Solved", value: "\(viewModel.wordsCorrect) / \(viewModel.totalRounds)")
                    resultRow(label: "Avg Time", value: String(format: "%.1fs", viewModel.averageTime))
                    if viewModel.longestWordSolved != "--" {
                        resultRow(label: "Longest Word", value: viewModel.longestWordSolved)
                    }
                    Divider()
                    resultRow(label: "Score", value: "\(Int(viewModel.score * 100))%")
                    resultRow(label: "Time", value: viewModel.durationSeconds.durationString)
                }
                .glowingCard(color: AppColors.rose, intensity: 0.08)
                .padding(.horizontal)

                VStack(alignment: .leading, spacing: 8) {
                    Text("Why Word Scramble?")
                        .font(.subheadline.weight(.bold))
                    Text("Unscrambling words exercises your verbal fluency and working memory. Speed pressure trains your brain to recognize letter patterns faster.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .appCard()
                .padding(.horizontal, 20)

                LeaderboardRankCard(
                    exerciseType: .wordScramble,
                    userScore: viewModel.wordsCorrect,
                )
                .padding(.horizontal)

                VStack(spacing: 12) {
                    if let shareImage {
                        ShareLink(
                            item: Image(uiImage: shareImage),
                            preview: SharePreview("Word Scramble: \(viewModel.wordsCorrect)/10", image: Image(uiImage: shareImage))
                        ) {
                            HStack(spacing: 8) {
                                Image(systemName: "square.and.arrow.up")
                                Text("Share Result")
                            }
                            .accentButton()
                        }
                    }

                    /*
                    if let challengeURL = ChallengeLink(
                        game: .wordScramble,
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
            type: .wordScramble,
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
                exerciseType: .wordScramble,
                gameScore: viewModel.leaderboardScore
            )
        }
    }
}

// MARK: - Wrapping HStack (for letter tiles)

private struct WrappingHStack<Item: Identifiable, Content: View>: View {
    let items: [Item]
    let spacing: CGFloat
    let content: (Item) -> Content

    var body: some View {
        HStack(spacing: spacing) {
            ForEach(items) { item in
                content(item)
            }
        }
    }
}
