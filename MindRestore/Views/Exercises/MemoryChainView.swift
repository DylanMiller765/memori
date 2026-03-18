import SwiftUI
import SwiftData

// MARK: - Game Phase

enum MCPhase: Equatable {
    case intro
    case watching
    case recalling
    case gameOver
}

// MARK: - ViewModel

@MainActor @Observable
final class MemoryChainViewModel {
    var phase: MCPhase = .intro
    var startTime: Date?

    // Grid items: 16 unique icon+color combos on a 4x4 grid
    private(set) var gridItems: [(icon: String, color: Color)] = {
        [
            ("circle.fill", AppColors.coral),
            ("square.fill", AppColors.accent),
            ("triangle.fill", AppColors.teal),
            ("diamond.fill", AppColors.violet),
            ("star.fill", AppColors.amber),
            ("heart.fill", AppColors.rose),
            ("pentagon.fill", AppColors.sky),
            ("hexagon.fill", AppColors.indigo),
            ("circle.fill", AppColors.mint),
            ("square.fill", AppColors.coral.opacity(0.7)),
            ("triangle.fill", AppColors.accent.opacity(0.7)),
            ("diamond.fill", AppColors.teal.opacity(0.7)),
            ("star.fill", AppColors.violet.opacity(0.7)),
            ("heart.fill", AppColors.amber.opacity(0.7)),
            ("pentagon.fill", AppColors.rose.opacity(0.7)),
            ("hexagon.fill", AppColors.sky.opacity(0.7)),
        ]
    }()

    // The growing sequence of grid indices
    var sequence: [Int] = []
    // Which index in the sequence is currently lighting up (-1 = none)
    var highlightedIndex: Int = -1
    // Player's current tap position in the sequence
    var playerPosition: Int = 0
    // The last tapped cell index for feedback
    var lastTappedCell: Int? = nil
    // Whether last tap was correct (for border flash)
    var lastTapCorrect: Bool? = nil
    // Longest chain the player completed
    var longestChain: Int = 0
    // Current round number (1-based)
    var roundNumber: Int = 0
    // Is interaction disabled (during playback or feedback)
    var isPlaybackActive: Bool = false
    var showingChainComplete: Bool = false
    var chainCompleteText: String = ""
    var celebrationCellScales: [CGFloat] = Array(repeating: 1.0, count: 16)

    var challengeSeed: Int?
    private var rng: SeededGenerator?

    private var playbackTask: Task<Void, Never>?

    var normalizedScore: Double {
        min(1.0, max(0.0, Double(longestChain - 3) / 10.0))
    }

    var durationSeconds: Int {
        guard let start = startTime else { return 0 }
        return Int(Date.now.timeIntervalSince(start))
    }

    var ratingText: String {
        if longestChain >= 13 { return "Incredible Memory!" }
        if longestChain >= 10 { return "Amazing!" }
        if longestChain >= 7 { return "Great Job!" }
        if longestChain >= 5 { return "Good!" }
        if longestChain >= 4 { return "Not Bad!" }
        return "Keep Practicing!"
    }

    func startGame() {
        sequence = []
        playerPosition = 0
        longestChain = 0
        roundNumber = 0
        lastTappedCell = nil
        lastTapCorrect = nil
        startTime = Date.now
        if let seed = challengeSeed {
            rng = SeededGenerator(seed: UInt64(seed))
        } else {
            rng = nil
        }

        // Seed with initial sequence of 2 items
        for _ in 0..<2 {
            var newIndex: Int
            repeat {
                if var r = rng {
                    newIndex = Int.random(in: 0..<16, using: &r)
                    rng = r
                } else {
                    newIndex = Int.random(in: 0..<16)
                }
            } while newIndex == sequence.last
            sequence.append(newIndex)
        }

        startNextRound()
    }

    func startNextRound() {
        roundNumber += 1
        playerPosition = 0
        lastTappedCell = nil
        lastTapCorrect = nil

        // Add a new random index to the sequence (avoid repeating the last item)
        var newIndex: Int
        repeat {
            if var r = rng {
                newIndex = Int.random(in: 0..<16, using: &r)
                rng = r
            } else {
                newIndex = Int.random(in: 0..<16)
            }
        } while newIndex == sequence.last

        sequence.append(newIndex)

        // Play the sequence
        playSequence()
    }

    func playSequence() {
        phase = .watching
        isPlaybackActive = true
        highlightedIndex = -1

        playbackTask?.cancel()
        playbackTask = Task { @MainActor in
            // Brief pause before starting
            try? await Task.sleep(for: .milliseconds(400))

            for (i, seqIndex) in sequence.enumerated() {
                guard !Task.isCancelled else { return }

                highlightedIndex = seqIndex

                // Light up for 0.6s
                try? await Task.sleep(for: .milliseconds(600))

                guard !Task.isCancelled else { return }

                highlightedIndex = -1

                // Gap of 0.3s between items (except after last)
                if i < sequence.count - 1 {
                    try? await Task.sleep(for: .milliseconds(300))
                }
            }

            guard !Task.isCancelled else { return }

            // Switch to recall phase
            isPlaybackActive = false
            phase = .recalling
        }
    }

    func playerTapped(cellIndex: Int) {
        guard phase == .recalling, !isPlaybackActive else { return }

        lastTappedCell = cellIndex

        let expectedIndex = sequence[playerPosition]

        if cellIndex == expectedIndex {
            // Correct tap
            lastTapCorrect = true
            HapticService.correct()
            playerPosition += 1

            if playerPosition >= sequence.count {
                // Completed this chain
                longestChain = sequence.count
                showingChainComplete = true
                chainCompleteText = "Chain \(longestChain)!"
                SoundService.shared.playComplete()
                triggerCelebrationRipple(fromCell: sequence.last ?? 0)

                isPlaybackActive = true
                playbackTask?.cancel()
                playbackTask = Task { @MainActor in
                    try? await Task.sleep(for: .milliseconds(900))
                    guard !Task.isCancelled else { return }
                    showingChainComplete = false
                    isPlaybackActive = false
                    lastTappedCell = nil
                    lastTapCorrect = nil
                    startNextRound()
                }
            } else {
                // Reset feedback after brief flash
                playbackTask?.cancel()
                playbackTask = Task { @MainActor in
                    try? await Task.sleep(for: .milliseconds(200))
                    guard !Task.isCancelled else { return }
                    lastTappedCell = nil
                    lastTapCorrect = nil
                }
            }
        } else {
            // Wrong tap — game over
            lastTapCorrect = false
            HapticService.wrong()
            isPlaybackActive = true
            playbackTask?.cancel()
            playbackTask = Task { @MainActor in
                try? await Task.sleep(for: .milliseconds(800))
                guard !Task.isCancelled else { return }
                isPlaybackActive = false
                phase = .gameOver
            }
        }
    }

    func triggerCelebrationRipple(fromCell: Int) {
        let fromRow = fromCell / 4
        let fromCol = fromCell % 4

        for i in 0..<16 {
            let row = i / 4
            let col = i % 4
            let distance = abs(row - fromRow) + abs(col - fromCol)
            let delay = Double(distance) * 0.03
            let intensity: CGFloat = longestChain >= 10 ? 1.12 : (longestChain >= 7 ? 1.1 : 1.06)

            Task { @MainActor in
                try? await Task.sleep(for: .seconds(delay))
                withAnimation(.spring(response: 0.2, dampingFraction: 0.5)) {
                    celebrationCellScales[i] = intensity
                }
                try? await Task.sleep(for: .milliseconds(150))
                withAnimation(.spring(response: 0.2, dampingFraction: 0.7)) {
                    celebrationCellScales[i] = 1.0
                }
            }
        }
    }

    func reset() {
        playbackTask?.cancel()
        phase = .intro
        highlightedIndex = -1
        isPlaybackActive = false
        showingChainComplete = false
        celebrationCellScales = Array(repeating: 1.0, count: 16)
    }
}

// MARK: - View

struct MemoryChainView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @Environment(AchievementService.self) private var achievementService
    @Environment(TrainingSessionManager.self) private var trainingManager
    @Environment(PaywallTriggerService.self) private var paywallTrigger
    @Environment(StoreService.self) private var storeService
    @Environment(GameCenterService.self) private var gameCenterService
    @Query private var users: [User]

    @State private var viewModel = MemoryChainViewModel()
    @State private var showingPaywall = false
    @State private var isNewPersonalBest = false
    @State private var shareImage: UIImage?

    private var user: User? { users.first }
    private var isProUser: Bool { storeService.isProUser || (user?.isProUser ?? false) }

    var body: some View {
        VStack(spacing: 0) {
            switch viewModel.phase {
            case .intro:
                introView
            case .watching:
                gameView
            case .recalling:
                gameView
            case .gameOver:
                gameOverView
            }
        }
        .animation(.easeInOut(duration: 0.3), value: viewModel.phase)
        .sheet(isPresented: $showingPaywall) { PaywallView(isHighIntent: true) }
        .navigationTitle("Memory Chain")
        .navigationBarTitleDisplayMode(.inline)
        .onChange(of: viewModel.phase) { _, newPhase in
            if newPhase == .gameOver {
                isNewPersonalBest = PersonalBestTracker.shared.record(score: viewModel.longestChain, for: .memoryChain)
                AdaptiveDifficultyEngine.shared.recordBlock(domain: .memoryChain, correct: viewModel.longestChain, total: viewModel.longestChain + 1)
                let card = ExerciseShareCard(
                    exerciseName: "Memory Chain",
                    exerciseIcon: "link.circle.fill",
                    accentColor: AppColors.mint,
                    mainValue: "\(viewModel.longestChain)",
                    mainLabel: "Longest Chain",
                    ratingText: viewModel.ratingText,
                    stats: [
                        ("Rounds Survived", "\(viewModel.roundNumber)"),
                        ("Starting Length", "3")
                    ],
                    ctaText: "Beat my memory"
                )
                shareImage = card.renderAsImage(size: CGSize(width: 360, height: 640), scale: 3)
            }
        }
    }

    // MARK: - Intro

    private var introView: some View {
        VStack(spacing: 32) {
            Spacer()

            ZStack {
                Circle()
                    .fill(AppColors.cardBorder)
                    .frame(width: 120, height: 120)
                    .accessibilityHidden(true)
                Image(systemName: "link.circle.fill")
                    .font(.system(size: 52, weight: .medium))
                    .foregroundStyle(AppColors.mint)
            }

            VStack(spacing: 8) {
                Text("Memory Chain")
                    .font(.title.weight(.bold))
                Text("Remember growing sequences")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }

            VStack(alignment: .leading, spacing: 12) {
                infoRow(icon: "eye.fill", text: "Watch the sequence light up")
                infoRow(icon: "hand.tap.fill", text: "Tap items in the same order")
                infoRow(icon: "arrow.up.right", text: "Chain grows each round")
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
                .foregroundStyle(AppColors.mint)
                .frame(width: 24)
            Text(text)
                .font(.subheadline)
        }
    }

    // MARK: - Game View

    private var gameView: some View {
        VStack(spacing: 20) {
            // Header: chain length + phase indicator
            HStack {
                Label("Chain: \(viewModel.sequence.count)", systemImage: "link")
                    .font(.headline)
                    .foregroundStyle(AppColors.mint)

                Spacer()

                Text("Round \(viewModel.roundNumber)")
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(.secondary)
            }
            .padding(.horizontal)

            Text(viewModel.phase == .watching ? "Watch carefully..." : "Your turn! Tap the sequence")
                .font(.headline)
                .foregroundStyle(viewModel.phase == .watching ? AppColors.amber : AppColors.accent)
                .animation(.easeInOut, value: viewModel.phase)

            Spacer()

            // 4x4 Grid
            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 10), count: 4), spacing: 10) {
                ForEach(0..<16, id: \.self) { index in
                    gridCell(at: index)
                }
            }
            .padding(.horizontal, 20)
            .allowsHitTesting(viewModel.phase == .recalling && !viewModel.isPlaybackActive)

            // Chain complete celebration text
            if viewModel.showingChainComplete {
                Text(viewModel.chainCompleteText)
                    .font(.system(size: 28, weight: .bold, design: .rounded))
                    .foregroundStyle(AppColors.mint)
                    .transition(.scale(scale: 0.5).combined(with: .opacity))
                    .padding(.top, 8)
            }

            Spacer()

            // Sequence progress dots during recall
            if viewModel.phase == .recalling {
                HStack(spacing: 6) {
                    ForEach(0..<viewModel.sequence.count, id: \.self) { i in
                        Circle()
                            .fill(i < viewModel.playerPosition ? AppColors.mint : AppColors.accent.opacity(0.2))
                            .frame(width: 8, height: 8)
                    }
                }
                .padding(.bottom, 8)
            }

            if viewModel.phase == .watching {
                Text("Get ready...")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .padding(.bottom, 8)
            }
        }
        .padding(.vertical, 16)
        .animation(.spring(response: 0.3, dampingFraction: 0.7), value: viewModel.showingChainComplete)
    }

    @ViewBuilder
    private func gridCell(at index: Int) -> some View {
        let item = viewModel.gridItems[index]
        let isHighlighted = viewModel.highlightedIndex == index
        let isTapped = viewModel.lastTappedCell == index
        let tapCorrect = viewModel.lastTapCorrect

        Button {
            viewModel.playerTapped(cellIndex: index)
        } label: {
            RoundedRectangle(cornerRadius: 12)
                .fill(AppColors.cardSurface)
                .aspectRatio(1, contentMode: .fit)
                .overlay {
                    Image(systemName: item.icon)
                        .font(.system(size: 22, weight: .semibold))
                        .foregroundStyle(item.color)
                        .opacity(isHighlighted ? 1.0 : 0.6)
                }
                .overlay {
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(cellBorderColor(isTapped: isTapped, tapCorrect: tapCorrect, isHighlighted: isHighlighted, itemColor: item.color), lineWidth: isTapped || isHighlighted ? 3 : 1)
                }
                .scaleEffect(isHighlighted ? 1.15 : viewModel.celebrationCellScales[index])
                .shadow(color: isHighlighted ? item.color.opacity(0.4) : .clear, radius: isHighlighted ? 8 : 0)
                .animation(.easeInOut(duration: 0.2), value: isHighlighted)
                .animation(.easeInOut(duration: 0.15), value: isTapped)
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Grid cell \(index + 1)")
    }

    private func cellBorderColor(isTapped: Bool, tapCorrect: Bool?, isHighlighted: Bool, itemColor: Color) -> Color {
        if isTapped, let correct = tapCorrect {
            return correct ? AppColors.mint : AppColors.coral
        }
        if isHighlighted {
            return itemColor
        }
        return AppColors.cardBorder
    }

    // MARK: - Game Over

    private var gameOverView: some View {
        ScrollView(showsIndicators: false) {
            VStack(spacing: 16) {
                HStack(spacing: 12) {
                    Image(systemName: "link.circle.fill")
                        .font(.system(size: 24))
                        .foregroundStyle(.white)
                        .frame(width: 48, height: 48)
                        .background(AppColors.mint, in: RoundedRectangle(cornerRadius: 14))

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
                    resultRow(label: "Longest Chain", value: "\(viewModel.longestChain)")
                        .accessibilityElement(children: .combine)
                    resultRow(label: "Rounds Survived", value: "\(viewModel.roundNumber)")
                        .accessibilityElement(children: .combine)
                    Divider()
                    resultRow(label: "Time", value: viewModel.durationSeconds.durationString)
                        .accessibilityElement(children: .combine)
                }
                .glowingCard(color: AppColors.mint, intensity: 0.08)
                .padding(.horizontal)

                LeaderboardRankCard(
                    exerciseType: .memoryChain,
                    userScore: viewModel.longestChain,
                    isPro: isProUser,
                    onUpgradeTap: { showingPaywall = true }
                )
                .padding(.horizontal)

                VStack(spacing: 12) {
                    if let shareImage {
                        ShareLink(
                            item: Image(uiImage: shareImage),
                            preview: SharePreview("Memory Chain: \(viewModel.longestChain)", image: Image(uiImage: shareImage))
                        ) {
                            HStack(spacing: 8) {
                                Image(systemName: "square.and.arrow.up")
                                Text("Share Result")
                            }
                            .accentButton()
                        }
                    }

                    Button {
                        shareImage = nil
                        isNewPersonalBest = false
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
            type: .memoryChain,
            difficulty: viewModel.longestChain,
            score: viewModel.normalizedScore,
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
                score: viewModel.normalizedScore,
                difficulty: viewModel.longestChain,
                achievementService: achievementService,
                modelContext: modelContext,
                gameCenterService: gameCenterService,
                exerciseType: .memoryChain,
                gameScore: viewModel.longestChain
            )
        }
    }
}
