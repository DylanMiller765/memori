import SwiftUI
import SwiftData
import ConfettiSwiftUI

// MARK: - ViewModel

@MainActor @Observable
final class ChimpTestViewModel {
    enum Phase: Equatable { case setup, playing, finished }

    var phase: Phase = .setup
    var startTime: Date?

    // Grid: 8 columns x 6 rows = 48 cells
    let columns = 8
    let rows = 6

    // Game state
    var currentLevel = 4
    var bestLevel = 4
    var lives = 3
    var nextExpected = 1
    var numbersHidden = false

    // Grid data: nil = empty, Int = number at that position
    var grid: [Int?] = Array(repeating: nil, count: 48)
    // Track which cells have been correctly tapped
    var correctCells: Set<Int> = []
    // Track wrong cell (briefly flash)
    var wrongCell: Int?

    var challengeSeed: Int?
    private var rng: SeededGenerator?

    // MARK: - Computed Properties

    var score: Double {
        // Normalize: level 4 = 0, level 20+ = 1.0
        let normalized = Double(bestLevel - 4) / 16.0
        return min(1.0, max(0.0, normalized))
    }

    var durationSeconds: Int {
        guard let start = startTime else { return 0 }
        return Int(Date.now.timeIntervalSince(start))
    }

    var leaderboardScore: Int {
        bestLevel
    }

    var difficulty: Int {
        if bestLevel >= 14 { return 10 }
        if bestLevel >= 12 { return 8 }
        if bestLevel >= 10 { return 6 }
        if bestLevel >= 8 { return 5 }
        if bestLevel >= 6 { return 3 }
        return 1
    }

    var ratingText: String {
        if bestLevel >= 12 { return "Genius!" }
        if bestLevel >= 10 { return "Amazing!" }
        if bestLevel >= 8 { return "Great!" }
        if bestLevel >= 6 { return "Good Job!" }
        return "Keep Practicing!"
    }

    var totalNumbers: Int { currentLevel }

    // MARK: - Game Logic

    func startGame() {
        phase = .playing
        currentLevel = 4
        bestLevel = 4
        lives = 3
        startTime = Date.now
        if let seed = challengeSeed {
            rng = SeededGenerator(seed: UInt64(seed))
        } else {
            rng = nil
        }
        setupLevel()
    }

    func setupLevel() {
        nextExpected = 1
        numbersHidden = false
        correctCells = []
        wrongCell = nil
        grid = Array(repeating: nil, count: columns * rows)

        // Place numbers 1..currentLevel at random positions
        var positions = Array(0..<(columns * rows))
        if var r = rng {
            positions.shuffle(using: &r)
            rng = r
        } else {
            positions.shuffle()
        }

        for number in 1...currentLevel {
            let pos = positions[number - 1]
            grid[pos] = number
        }
    }

    func tapCell(at index: Int) {
        guard phase == .playing else { return }
        guard let number = grid[index] else { return }
        guard !correctCells.contains(index) else { return }

        if number == nextExpected {
            // Correct tap
            correctCells.insert(index)
            HapticService.tap()

            if nextExpected == 1 {
                // After tapping 1, hide all remaining numbers
                numbersHidden = true
            }

            nextExpected += 1

            // Check if level complete
            if nextExpected > currentLevel {
                // Level complete!
                HapticService.correct()
                SoundService.shared.playCorrect()
                bestLevel = max(bestLevel, currentLevel)
                currentLevel += 1

                DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { [weak self] in
                    self?.setupLevel()
                }
            }
        } else {
            // Wrong tap
            wrongCell = index
            HapticService.wrong()
            SoundService.shared.playWrong()
            lives -= 1

            if lives <= 0 {
                // Game over
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) { [weak self] in
                    self?.finishGame()
                }
            } else {
                // Lose a life, restart current level
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) { [weak self] in
                    self?.setupLevel()
                }
            }
        }
    }

    private func finishGame() {
        // bestLevel now tracks the highest level actually completed (set before currentLevel increments)
        phase = .finished
        SoundService.shared.playComplete()
        HapticService.complete()
    }

    func reset() {
        phase = .setup
        currentLevel = 4
        bestLevel = 4
        lives = 3
        startTime = nil
        numbersHidden = false
        nextExpected = 1
        correctCells = []
        wrongCell = nil
        grid = Array(repeating: nil, count: columns * rows)
    }
}

// MARK: - View

struct ChimpTestView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @Environment(AchievementService.self) private var achievementService
    @Environment(TrainingSessionManager.self) private var trainingManager
    @Environment(PaywallTriggerService.self) private var paywallTrigger
    @Environment(StoreService.self) private var storeService
    @Environment(GameCenterService.self) private var gameCenterService
    @Query private var users: [User]

    @State private var viewModel = ChimpTestViewModel()
    @State private var showingPaywall = false
    @State private var shareImage: UIImage?
    @State private var isNewPersonalBest = false
    @State private var exerciseSaved = false
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
        .background(AppColors.pageBg)
        .animation(.easeInOut(duration: 0.3), value: viewModel.phase)
        .sheet(isPresented: $showingPaywall) { PaywallView(isHighIntent: true) }
        .navigationTitle("Chimp Test")
        .navigationBarTitleDisplayMode(.inline)
        .navigationBarBackButtonHidden(viewModel.phase == .playing)
        .onDisappear {
            if viewModel.phase == .playing {
                Analytics.exerciseAbandoned(game: ExerciseType.chimpTest.rawValue, roundReached: viewModel.currentLevel)
            }
        }
        .onChange(of: viewModel.phase) { _, newPhase in
            if newPhase == .finished {
                isNewPersonalBest = PersonalBestTracker.shared.record(score: viewModel.leaderboardScore, for: .chimpTest)
                if isNewPersonalBest {
                    Analytics.personalBest(game: ExerciseType.chimpTest.rawValue, score: viewModel.leaderboardScore)
                }
                AdaptiveDifficultyEngine.shared.recordBlock(domain: .chimpTest, correct: viewModel.bestLevel - 4, total: viewModel.bestLevel)
                saveExercise()
                generateShareCard()
            }
        }
    }

    // MARK: - Setup

    private var setupView: some View {
        VStack(spacing: 20) {
            Spacer()

            TrainingTileMiniPreview(type: .chimpTest, color: AppColors.amber, scale: 2.0)
                .frame(width: 200, height: 140)

            VStack(spacing: 6) {
                Text("Chimp Test")
                    .font(.title.weight(.bold))
                Text("Can you beat a chimpanzee?")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }

            VStack(alignment: .leading, spacing: 10) {
                infoRow(icon: "number", text: "Numbers appear on a grid")
                infoRow(icon: "eye.slash", text: "Tap 1 first — then numbers hide")
                infoRow(icon: "arrow.up", text: "Tap remaining in order from memory")
                infoRow(icon: "heart.fill", text: "3 lives — wrong tap loses one")
                infoRow(icon: "star.fill", text: "Each level adds one more number")
                infoRow(icon: "pawprint.fill", text: "Chimps average level 7 — can you beat that?")
            }
            .appCard()
            .padding(.horizontal)

            Spacer()

            Button {
                Analytics.exerciseStarted(game: ExerciseType.chimpTest.rawValue)
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
            ExerciseInfoSheet(type: .chimpTest)
                .presentationDetents([.medium])
        }
    }

    private func infoRow(icon: String, text: String) -> some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.body.weight(.semibold))
                .foregroundStyle(AppColors.amber)
                .frame(width: 24)
            Text(text)
                .font(.subheadline)
        }
    }

    // MARK: - Playing

    private var playingView: some View {
        VStack(spacing: 12) {
            // Header: Level + Hearts
            HStack {
                Text("Level \(viewModel.currentLevel)")
                    .font(.headline)
                    .foregroundStyle(AppColors.amber)
                    .contentTransition(.numericText())
                Spacer()
                HStack(spacing: 4) {
                    ForEach(0..<3, id: \.self) { i in
                        Image(systemName: i < viewModel.lives ? "heart.fill" : "heart")
                            .font(.system(size: 18))
                            .foregroundStyle(i < viewModel.lives ? AppColors.coral : AppColors.coral.opacity(0.3))
                    }
                }
            }
            .padding(.horizontal)
            .padding(.top, 8)

            // 8x6 Grid
            let spacing: CGFloat = 4
            GeometryReader { geo in
                let totalHSpacing = spacing * CGFloat(viewModel.columns - 1)
                let totalVSpacing = spacing * CGFloat(viewModel.rows - 1)
                let cellWidth = (geo.size.width - totalHSpacing) / CGFloat(viewModel.columns)
                let cellHeight = (geo.size.height - totalVSpacing) / CGFloat(viewModel.rows)
                let cellSize = min(cellWidth, cellHeight)

                let gridWidth = cellSize * CGFloat(viewModel.columns) + totalHSpacing
                let gridHeight = cellSize * CGFloat(viewModel.rows) + totalVSpacing

                VStack(spacing: spacing) {
                    ForEach(0..<viewModel.rows, id: \.self) { row in
                        HStack(spacing: spacing) {
                            ForEach(0..<viewModel.columns, id: \.self) { col in
                                let index = row * viewModel.columns + col
                                cellView(at: index, size: cellSize)
                            }
                        }
                    }
                }
                .frame(width: gridWidth, height: gridHeight)
                .position(x: geo.size.width / 2, y: geo.size.height / 2)
            }
            .padding(.horizontal, 8)

            Spacer().frame(height: 16)
        }
    }

    @ViewBuilder
    private func cellView(at index: Int, size: CGFloat) -> some View {
        let number = viewModel.grid[index]
        let isCorrect = viewModel.correctCells.contains(index)
        let isWrong = viewModel.wrongCell == index

        Button {
            withAnimation(.easeInOut(duration: 0.15)) {
                viewModel.tapCell(at: index)
            }
        } label: {
            ZStack {
                if let num = number {
                    if isCorrect {
                        // Already tapped correctly
                        RoundedRectangle(cornerRadius: 6)
                            .fill(AppColors.teal.opacity(0.3))
                    } else if isWrong {
                        // Wrong tap flash
                        RoundedRectangle(cornerRadius: 6)
                            .fill(AppColors.coral)
                    } else if viewModel.numbersHidden {
                        // Hidden behind blank square
                        RoundedRectangle(cornerRadius: 6)
                            .fill(AppColors.accent)
                    } else {
                        // Showing number
                        RoundedRectangle(cornerRadius: 6)
                            .fill(AppColors.amber)
                        Text("\(num)")
                            .font(.system(size: size * 0.4, weight: .bold, design: .rounded))
                            .foregroundStyle(.white)
                    }
                } else {
                    // Empty cell
                    RoundedRectangle(cornerRadius: 6)
                        .fill(Color.secondary.opacity(0.08))
                }
            }
            .frame(width: size, height: size)
        }
        .buttonStyle(.plain)
        .disabled(number == nil || isCorrect)
    }

    // MARK: - Results

    private var resultsView: some View {
        GameResultView(
            gameTitle: "Chimp Test",
            gameIcon: "pawprint.fill",
            accentColor: AppColors.amber,
            mainScore: viewModel.bestLevel,
            scoreLabel: "NUMBERS REMEMBERED",
            ratingText: viewModel.ratingText,
            stats: [
                (label: "Best Level", value: "\(viewModel.bestLevel)"),
                (label: "Time", value: viewModel.durationSeconds.durationString)
            ],
            isNewPersonalBest: isNewPersonalBest,
            personalBest: PersonalBestTracker.shared.best(for: .chimpTest),
            exerciseType: .chimpTest,
            leaderboardScore: viewModel.bestLevel,
            emoji: "🐵",
            subtitleText: viewModel.bestLevel > 7 ? "You beat the chimp!" : viewModel.bestLevel == 7 ? "Tied with the chimp!" : "The chimp wins this time!",
            onShare: {
                generateShareCard()
                Analytics.shareTapped(game: ExerciseType.chimpTest.rawValue)
            },
            onPlayAgain: {
                exerciseSaved = false
                viewModel.reset()
            },
            onDone: { dismiss() }
        )
    }

    // MARK: - Share Card

    private func generateShareCard() {
        if shareImage == nil {
            let card = ExerciseShareCard(
                exerciseName: "Chimp Test",
                exerciseIcon: "pawprint.fill",
                accentColor: AppColors.amber,
                mainValue: "\(viewModel.bestLevel)",
                mainLabel: "NUMBERS REMEMBERED",
                ratingText: viewModel.ratingText,
                stats: [
                    ("Time", "\(viewModel.durationSeconds)s")
                ],
                ctaText: "Can you beat the chimp?"
            )
            shareImage = card.renderAsImage(size: CGSize(width: 360, height: 640), scale: 3)
        }
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
        paywallTrigger.recordExerciseCompleted()
        trainingManager.addTrainingTime(viewModel.durationSeconds)

        let exercise = Exercise(
            type: .chimpTest,
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

        if let user {
            _ = ContentView.awardXP(
                user: user,
                score: viewModel.score,
                difficulty: viewModel.difficulty,
                achievementService: achievementService,
                modelContext: modelContext,
                gameCenterService: gameCenterService,
                exerciseType: .chimpTest,
                gameScore: viewModel.bestLevel
            )
        }

        gameCenterService.reportScore(viewModel.leaderboardScore, leaderboardID: GameCenterService.chimpTestLeaderboard)
    }
}
