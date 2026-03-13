import SwiftUI
import SwiftData

// MARK: - ViewModel

@MainActor @Observable
final class VisualMemoryViewModel {
    enum Phase { case setup, showing, input, correct, wrong, finished }

    var phase: Phase = .setup
    var startTime: Date?
    var level = 1
    var highlightedCells: Set<Int> = []
    var selectedCells: Set<Int> = []
    var gridSize: Int = 3
    var highlightCount: Int = 3
    private var showTimer: Timer?
    var firstTryLevels = 0
    private var totalAttempts = 0
    private var correctAttempts = 0
    var levelRetries = 0
    let maxRetries = 2

    let maxLevel = 10

    var score: Double {
        Double(firstTryLevels) / Double(maxLevel)
    }

    var maxLevelReached: Int {
        firstTryLevels
    }

    var accuracy: Double {
        guard totalAttempts > 0 else { return 0 }
        return Double(correctAttempts) / Double(totalAttempts)
    }

    var levelsCompleted: Int {
        level > maxLevel ? maxLevel : level - 1
    }

    var durationSeconds: Int {
        guard let start = startTime else { return 0 }
        return Int(Date.now.timeIntervalSince(start))
    }

    var totalCells: Int {
        gridSize * gridSize
    }

    /// Display time decreases at higher levels (1.5s at level 1, down to 0.6s at level 10)
    private var showDuration: TimeInterval {
        max(0.6, 1.5 - Double(level - 1) * 0.1)
    }

    // Grid grows: levels 1-3 = 3x3, levels 4-6 = 4x4, levels 7+ = 5x5
    private func updateGridForLevel() {
        switch level {
        case 1...3:
            gridSize = 3
        case 4...6:
            gridSize = 4
        default:
            gridSize = 5
        }
        // Highlight count increases each level: starts at 3, +1 per level
        highlightCount = min(2 + level, totalCells - 1)
    }

    func startGame() {
        level = max(1, AdaptiveDifficultyEngine.shared.currentLevel(for: .visualMemory))
        firstTryLevels = 0
        totalAttempts = 0
        correctAttempts = 0
        levelRetries = 0
        startTime = Date.now
        startLevel()
    }

    func startLevel() {
        updateGridForLevel()
        selectedCells = []

        // Pick random cells to highlight
        var cells = Set<Int>()
        while cells.count < highlightCount {
            cells.insert(Int.random(in: 0..<totalCells))
        }
        highlightedCells = cells

        // Show the pattern
        phase = .showing

        showTimer?.invalidate()
        showTimer = Timer.scheduledTimer(withTimeInterval: showDuration, repeats: false) { [weak self] _ in
            Task { @MainActor in
                self?.phase = .input
            }
        }
    }

    func toggleCell(_ index: Int) {
        guard phase == .input else { return }
        if selectedCells.contains(index) {
            selectedCells.remove(index)
        } else {
            selectedCells.insert(index)
        }

    }

    func submit() {
        guard phase == .input else { return }
        totalAttempts += 1

        if selectedCells == highlightedCells {
            // Correct
            correctAttempts += 1
            if levelRetries == 0 {
                firstTryLevels += 1
            }



            if level >= maxLevel {

                phase = .finished

            } else {
                phase = .correct
                showTimer?.invalidate()
                showTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: false) { [weak self] _ in
                    Task { @MainActor in

                        self?.levelRetries = 0
                        self?.level += 1
                        self?.startLevel()
                    }
                }
            }
        } else {
            // Wrong
            levelRetries += 1



            if levelRetries > maxRetries {
                // Max retries reached — skip to next level
                if level >= maxLevel {
    
                    phase = .finished
    
                } else {
                    phase = .wrong
                }
            } else {
                phase = .wrong
            }
        }
    }

    func retryAfterWrong() {
        if levelRetries > maxRetries {
            // Skip to next level
            levelRetries = 0
            level += 1
            startLevel()
        } else {
            startLevel()
        }
    }

    func reset() {
        showTimer?.invalidate()
        phase = .setup
    }

    var ratingText: String {
        let lvl = maxLevelReached
        if lvl >= 10 { return "Perfect Memory!" }
        if lvl >= 8 { return "Excellent!" }
        if lvl >= 6 { return "Great Job!" }
        if lvl >= 4 { return "Good!" }
        if lvl >= 2 { return "Not Bad!" }
        return "Keep Practicing!"
    }
}

// MARK: - View

struct VisualMemoryView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @Environment(AchievementService.self) private var achievementService
    @Environment(TrainingSessionManager.self) private var trainingManager
    @Environment(PaywallTriggerService.self) private var paywallTrigger
    @Environment(StoreService.self) private var storeService
    @Environment(GameCenterService.self) private var gameCenterService
    @Query private var users: [User]

    @State private var viewModel = VisualMemoryViewModel()
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
            case .showing:
                gameView(interactable: false)
            case .input:
                gameView(interactable: true)
            case .correct:
                correctView
            case .wrong:
                wrongView
            case .finished:
                resultsView
            }
        }
        .animation(.easeInOut(duration: 0.3), value: viewModel.phase == .finished)
        .animation(.easeInOut(duration: 0.3), value: viewModel.phase == .correct)
        .animation(.easeInOut(duration: 0.3), value: viewModel.phase == .wrong)
        .sheet(isPresented: $showingPaywall) { PaywallView(isHighIntent: true) }
        .navigationTitle("Visual Memory")
        .navigationBarTitleDisplayMode(.inline)
        .onChange(of: viewModel.phase) { _, newPhase in
            if newPhase == .finished {
                isNewPersonalBest = PersonalBestTracker.shared.record(score: viewModel.maxLevelReached, for: .visualMemory)
                AdaptiveDifficultyEngine.shared.recordBlock(domain: .visualMemory, correct: viewModel.maxLevelReached, total: viewModel.level)
                let card = ExerciseShareCard(
                    exerciseName: "Visual Memory",
                    exerciseIcon: "square.grid.3x3.fill",
                    accentColor: AppColors.indigo,
                    mainValue: "Level \(viewModel.maxLevelReached)",
                    mainLabel: "Max Level",
                    ratingText: viewModel.ratingText,
                    stats: [
                        ("Levels Aced", "\(viewModel.firstTryLevels) / \(viewModel.maxLevel)"),
                        ("Accuracy", viewModel.accuracy.percentString),
                        ("Score", viewModel.score.percentString)
                    ],
                    ctaText: "Think you can beat this?"
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
                Image(systemName: "square.grid.3x3.fill")
                    .font(.system(size: 52, weight: .medium))
                    .foregroundStyle(AppColors.accent)
            }

            VStack(spacing: 8) {
                Text("Visual Memory")
                    .font(.title.weight(.bold))
                Text("Remember the pattern")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }

            VStack(alignment: .leading, spacing: 12) {
                infoRow(icon: "eye.fill", text: "Memorize which squares light up")
                infoRow(icon: "hand.tap.fill", text: "Tap to recreate the pattern")
                infoRow(icon: "arrow.up.right", text: "10 levels — how many can you ace?")
            }
            .appCard()
            .padding(.horizontal)

            Spacer()

            Button {
                viewModel.startGame()
            } label: {
                Text("Start")
                    .gradientButton()
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

    // MARK: - Game View

    private func gameView(interactable: Bool) -> some View {
        VStack(spacing: 24) {
            // Header
            Text("Level \(viewModel.level) / \(viewModel.maxLevel)")
                .font(.headline)
                .foregroundStyle(AppColors.accent)
                .padding(.horizontal)

            Text(interactable ? "Tap the squares that were highlighted" : "Remember this pattern")
                .font(.headline)

            Text(interactable ? "Select \(viewModel.highlightCount) squares" : "\(viewModel.gridSize)x\(viewModel.gridSize) · \(viewModel.highlightCount) squares")
                .font(.subheadline)
                .foregroundStyle(.secondary)

            Spacer()

            // Grid — matches assessment style
            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 8), count: viewModel.gridSize), spacing: 8) {
                ForEach(0..<viewModel.totalCells, id: \.self) { index in
                    let isHighlighted = viewModel.highlightedCells.contains(index)
                    let isSelected = viewModel.selectedCells.contains(index)

                    RoundedRectangle(cornerRadius: 10)
                        .fill(cellColor(isHighlighted: isHighlighted, isSelected: isSelected, interactable: interactable))
                        .aspectRatio(1, contentMode: .fit)
                        .onTapGesture {
                            if interactable {
                                viewModel.toggleCell(index)
                            }
                        }
                        .animation(.easeInOut(duration: 0.15), value: isSelected)
                        .accessibilityLabel("Cell \(index + 1)\(isSelected ? ", selected" : "")")
                }
            }
            .padding(.horizontal, 32)

            Spacer()

            if interactable {
                Button {
                    viewModel.submit()
                } label: {
                    Text("Submit")
                        .gradientButton()
                }
                .disabled(viewModel.selectedCells.count != viewModel.highlightCount)
                .opacity(viewModel.selectedCells.count == viewModel.highlightCount ? 1.0 : 0.4)
                .padding(.horizontal, 32)
            }
        }
        .padding(.bottom, 16)
    }

    private func cellColor(isHighlighted: Bool, isSelected: Bool, interactable: Bool) -> Color {
        if !interactable && isHighlighted {
            return AppColors.accent
        }
        if interactable && isSelected {
            return AppColors.accent
        }
        return Color.gray.opacity(0.12)
    }

    // MARK: - Correct

    private var correctView: some View {
        VStack(spacing: 24) {
            Spacer()

            ZStack {
                Circle()
                    .fill(AppColors.cardBorder)
                    .frame(width: 120, height: 120)
                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 64))
                    .foregroundStyle(AppColors.mint)
            }

            Text("Level \(viewModel.level) Complete!")
                .font(.title2.weight(.bold))

            Spacer()
        }
        .padding(.vertical, 24)
    }

    // MARK: - Wrong

    private var wrongView: some View {
        VStack(spacing: 24) {
            Spacer()

            Text("Wrong!")
                .font(.title.weight(.bold))
                .foregroundStyle(AppColors.coral)

            Text("The correct pattern was:")
                .font(.subheadline)
                .foregroundStyle(.secondary)

            // Show grid with correct answers
            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 8), count: viewModel.gridSize), spacing: 8) {
                ForEach(0..<viewModel.totalCells, id: \.self) { index in
                    let isCorrect = viewModel.highlightedCells.contains(index)
                    let wasSelected = viewModel.selectedCells.contains(index)

                    RoundedRectangle(cornerRadius: 10)
                        .fill(wrongCellColor(isCorrect: isCorrect, wasSelected: wasSelected))
                        .aspectRatio(1, contentMode: .fit)
                        .overlay {
                            if wasSelected && !isCorrect {
                                Image(systemName: "xmark")
                                    .font(.caption.weight(.bold))
                                    .foregroundStyle(.white.opacity(0.8))
                            }
                        }
                }
            }
            .padding(.horizontal, 32)

            if viewModel.levelRetries <= viewModel.maxRetries {
                Text("Retries left: \(viewModel.maxRetries - viewModel.levelRetries + 1)")
                    .font(.caption.weight(.medium))
                    .foregroundStyle(.secondary)
            }

            Spacer()

            Button {
                viewModel.retryAfterWrong()
            } label: {
                Text(viewModel.levelRetries > viewModel.maxRetries ? "Next Level" : "Try Again")
                    .gradientButton()
            }
            .padding(.horizontal, 32)
        }
        .padding(.bottom, 16)
    }

    private func wrongCellColor(isCorrect: Bool, wasSelected: Bool) -> Color {
        if isCorrect {
            return AppColors.mint.opacity(0.7)
        } else if wasSelected {
            return AppColors.coral.opacity(0.7)
        } else {
            return Color.gray.opacity(0.12)
        }
    }

    // MARK: - Results

    private var resultsView: some View {
        ScrollView(showsIndicators: false) {
            VStack(spacing: 16) {
                HStack(spacing: 12) {
                    Image(systemName: "square.grid.3x3.fill")
                        .font(.system(size: 24))
                        .foregroundStyle(.white)
                        .frame(width: 48, height: 48)
                        .background(AppColors.indigo, in: RoundedRectangle(cornerRadius: 14))

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
                    resultRow(label: "Levels Aced", value: "\(viewModel.firstTryLevels) / \(viewModel.maxLevel)")
                        .accessibilityElement(children: .combine)
                    resultRow(label: "Accuracy", value: viewModel.accuracy.percentString)
                        .accessibilityElement(children: .combine)
                    Divider()
                    resultRow(label: "Score", value: viewModel.score.percentString)
                        .accessibilityElement(children: .combine)
                    resultRow(label: "Time", value: viewModel.durationSeconds.durationString)
                        .accessibilityElement(children: .combine)
                }
                .glowingCard(color: AppColors.violet, intensity: 0.08)
                .padding(.horizontal)

                LeaderboardRankCard(
                    exerciseType: .visualMemory,
                    userScore: viewModel.maxLevelReached,
                    isPro: isProUser,
                    onUpgradeTap: { showingPaywall = true }
                )
                .padding(.horizontal)

                VStack(spacing: 12) {
                    if let shareImage {
                        ShareLink(
                            item: Image(uiImage: shareImage),
                            preview: SharePreview("Visual Memory: Level \(viewModel.maxLevelReached)", image: Image(uiImage: shareImage))
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
            type: .visualMemory,
            difficulty: viewModel.maxLevelReached,
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
                difficulty: viewModel.maxLevelReached,
                achievementService: achievementService,
                modelContext: modelContext,
                gameCenterService: gameCenterService,
                exerciseType: .visualMemory,
                gameScore: viewModel.maxLevelReached
            )
        }
    }
}
