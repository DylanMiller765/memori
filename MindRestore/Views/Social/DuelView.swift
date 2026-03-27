import SwiftUI

// MARK: - Duel Exercise Type

enum DuelExerciseType: String, CaseIterable, Identifiable {
    case reactionTime
    case digitSpan
    case patternRecall

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .reactionTime: return "Reaction Time"
        case .digitSpan: return "Digit Span"
        case .patternRecall: return "Pattern Recall"
        }
    }

    var icon: String {
        switch self {
        case .reactionTime: return "bolt.fill"
        case .digitSpan: return "textformat.123"
        case .patternRecall: return "square.grid.3x3.fill"
        }
    }

    var description: String {
        switch self {
        case .reactionTime: return "Tap as fast as you can when the screen turns green"
        case .digitSpan: return "Remember and recall sequences of digits"
        case .patternRecall: return "Memorize and reproduce grid patterns"
        }
    }

    var color: Color {
        switch self {
        case .reactionTime: return AppColors.coral
        case .digitSpan: return AppColors.indigo
        case .patternRecall: return AppColors.teal
        }
    }
}

// MARK: - Duel Phase

enum DuelPhase: Equatable {
    case selection
    case matchmaking
    case countdown
    case playing
    case opponentTurn
    case results
}

// MARK: - Duel View Model

@MainActor @Observable
final class DuelViewModel {

    // MARK: State

    var phase: DuelPhase = .selection
    var selectedType: DuelExerciseType = .reactionTime
    var opponentName: String = ""
    var opponentEmoji: String = ""
    var playerScore: Int = 0
    var opponentScore: Int = 0
    var countdownValue: Int = 3

    // Reaction time state
    var reactionRound: Int = 0
    var reactionWaiting: Bool = true
    var reactionReady: Bool = false
    var reactionTappedEarly: Bool = false
    var reactionStartTime: Date?
    var reactionTimes: [Double] = []

    // Digit span state
    var digitSpanRound: Int = 0
    var currentDigits: [Int] = []
    var digitSpanShowingDigits: Bool = false
    var digitSpanCurrentIndex: Int = 0
    var digitSpanUserInput: String = ""
    var digitSpanMaxRecalled: Int = 0
    var digitSpanWaitingForInput: Bool = false
    var digitSpanLength: Int = 5

    // Pattern recall state
    var patternRound: Int = 0
    var patternCells: Set<Int> = []
    var patternUserCells: Set<Int> = []
    var patternShowing: Bool = false
    var patternSelecting: Bool = false
    var patternTotalCorrect: Int = 0
    var patternCellCount: Int = 4

    // Matchmaking animation
    var opponentRevealed: Bool = false
    var searchDots: Int = 0

    // Results
    var showConfetti: Bool = false

    // MARK: Opponent Data

    private static let opponentNames = [
        "BrainiacSam", "MemoryQueen", "NeuronNinja", "SynapseStorm", "CortexKing",
        "MindMelder", "RecallRanger", "ThinkTankTom", "FocusFury", "DendriteDave",
        "AxonAce", "HippoCamper", "PrefrontalPat", "SynapticSue", "BrainWaveBen",
        "CognitoCarl", "MnemonicMax", "LogicLuna", "NeuralNova", "ThoughtThief",
        "MindMapper", "BrainBlitz", "CerebralCece", "QuickRecall", "MemoryMaven",
        "NeuroPulse", "BrainStorm99", "CortexCrush", "SynapseSnap", "MindSprint"
    ]

    private static let opponentEmojis = [
        "🧠", "⚡", "🔥", "🎯", "💪", "🏆", "🌟", "💥", "🚀", "🎮",
        "👾", "🦾", "🧬", "⭐", "💎"
    ]

    // MARK: Timer references

    private var activeTimer: Timer?

    // MARK: Actions

    func startMatchmaking() {
        phase = .matchmaking
        opponentRevealed = false
        searchDots = 0
        opponentName = Self.opponentNames.randomElement() ?? "BrainiacSam"
        opponentEmoji = Self.opponentEmojis.randomElement() ?? "🧠"

        let dotTimer = Timer.scheduledTimer(withTimeInterval: 0.4, repeats: true) { [weak self] timer in
            guard let self else { timer.invalidate(); return }
            Task { @MainActor in
                self.searchDots = (self.searchDots + 1) % 4
            }
        }

        let delay = Double.random(in: 1.2...2.0)
        activeTimer = Timer.scheduledTimer(withTimeInterval: delay, repeats: false) { [weak self] _ in
            guard let self else { return }
            dotTimer.invalidate()
            Task { @MainActor in
                self.opponentRevealed = true
                let impact = UIImpactFeedbackGenerator(style: .medium)
                impact.impactOccurred()

                try? await Task.sleep(for: .seconds(0.8))
                self.startCountdown()
            }
        }
    }

    func startCountdown() {
        phase = .countdown
        countdownValue = 3

        activeTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] timer in
            guard let self else { timer.invalidate(); return }
            Task { @MainActor in
                let impact = UIImpactFeedbackGenerator(style: .heavy)
                impact.impactOccurred()

                if self.countdownValue > 1 {
                    self.countdownValue -= 1
                } else {
                    timer.invalidate()
                    self.startPlaying()
                }
            }
        }
    }

    func startPlaying() {
        phase = .playing
        resetExerciseState()

        switch selectedType {
        case .reactionTime:
            startReactionRound()
        case .digitSpan:
            startDigitSpanRound()
        case .patternRecall:
            startPatternRound()
        }
    }

    private func resetExerciseState() {
        reactionRound = 0
        reactionTimes = []
        reactionWaiting = true
        reactionReady = false
        reactionTappedEarly = false

        digitSpanRound = 0
        digitSpanMaxRecalled = 0
        digitSpanUserInput = ""
        digitSpanLength = 5

        patternRound = 0
        patternTotalCorrect = 0
        patternCellCount = 4
    }

    // MARK: - Reaction Time

    func startReactionRound() {
        reactionRound += 1
        reactionWaiting = true
        reactionReady = false
        reactionTappedEarly = false
        reactionStartTime = nil

        let delay = Double.random(in: 1.5...4.0)
        activeTimer = Timer.scheduledTimer(withTimeInterval: delay, repeats: false) { [weak self] _ in
            guard let self else { return }
            Task { @MainActor in
                if self.reactionWaiting {
                    self.reactionWaiting = false
                    self.reactionReady = true
                    self.reactionStartTime = Date.now
                    let impact = UIImpactFeedbackGenerator(style: .heavy)
                    impact.impactOccurred()
                }
            }
        }
    }

    func reactionTapped() {
        if reactionWaiting {
            reactionTappedEarly = true
            reactionWaiting = false
            activeTimer?.invalidate()
            let impact = UIImpactFeedbackGenerator(style: .rigid)
            impact.impactOccurred()

            Task { @MainActor in
                try? await Task.sleep(for: .seconds(1.0))
                if reactionRound < 5 {
                    startReactionRound()
                } else {
                    finishExercise()
                }
            }
        } else if reactionReady, let start = reactionStartTime {
            let elapsed = Date.now.timeIntervalSince(start) * 1000
            reactionTimes.append(elapsed)
            reactionReady = false
            let impact = UIImpactFeedbackGenerator(style: .light)
            impact.impactOccurred()

            Task { @MainActor in
                try? await Task.sleep(for: .seconds(0.8))
                if reactionRound < 5 {
                    startReactionRound()
                } else {
                    finishExercise()
                }
            }
        }
    }

    // MARK: - Digit Span

    func startDigitSpanRound() {
        digitSpanRound += 1
        digitSpanUserInput = ""
        digitSpanWaitingForInput = false
        digitSpanShowingDigits = true
        digitSpanCurrentIndex = 0
        currentDigits = (0..<digitSpanLength).map { _ in Int.random(in: 0...9) }

        showNextDigit()
    }

    private func showNextDigit() {
        if digitSpanCurrentIndex < currentDigits.count {
            activeTimer = Timer.scheduledTimer(withTimeInterval: 0.6, repeats: false) { [weak self] _ in
                guard let self else { return }
                Task { @MainActor in
                    self.digitSpanCurrentIndex += 1
                    self.showNextDigit()
                }
            }
        } else {
            Task { @MainActor in
                digitSpanShowingDigits = false
                digitSpanWaitingForInput = true
            }
        }
    }

    func submitDigitSpan() {
        let correct = currentDigits.map { String($0) }.joined()
        if digitSpanUserInput == correct {
            digitSpanMaxRecalled = max(digitSpanMaxRecalled, digitSpanLength)
            digitSpanLength += 1
        }
        let impact = UIImpactFeedbackGenerator(style: .medium)
        impact.impactOccurred()

        if digitSpanRound < 3 {
            Task { @MainActor in
                try? await Task.sleep(for: .seconds(0.5))
                startDigitSpanRound()
            }
        } else {
            if digitSpanUserInput == currentDigits.map({ String($0) }).joined() {
                digitSpanMaxRecalled = max(digitSpanMaxRecalled, digitSpanLength - 1)
            }
            finishExercise()
        }
    }

    // MARK: - Pattern Recall

    func startPatternRound() {
        patternRound += 1
        patternUserCells = []
        patternSelecting = false
        patternShowing = true

        var cells = Set<Int>()
        while cells.count < patternCellCount {
            cells.insert(Int.random(in: 0..<16))
        }
        patternCells = cells

        activeTimer = Timer.scheduledTimer(withTimeInterval: 2.0, repeats: false) { [weak self] _ in
            guard let self else { return }
            Task { @MainActor in
                self.patternShowing = false
                self.patternSelecting = true
                let impact = UIImpactFeedbackGenerator(style: .medium)
                impact.impactOccurred()
            }
        }
    }

    func togglePatternCell(_ index: Int) {
        guard patternSelecting else { return }
        if patternUserCells.contains(index) {
            patternUserCells.remove(index)
        } else if patternUserCells.count < patternCellCount {
            patternUserCells.insert(index)
            let impact = UIImpactFeedbackGenerator(style: .light)
            impact.impactOccurred()
        }
    }

    func submitPattern() {
        let correct = patternCells.intersection(patternUserCells).count
        patternTotalCorrect += correct
        let impact = UIImpactFeedbackGenerator(style: .medium)
        impact.impactOccurred()

        if patternRound < 2 {
            patternCellCount = 5
            Task { @MainActor in
                try? await Task.sleep(for: .seconds(0.5))
                startPatternRound()
            }
        } else {
            finishExercise()
        }
    }

    // MARK: - Finish

    func finishExercise() {
        switch selectedType {
        case .reactionTime:
            if reactionTimes.isEmpty {
                playerScore = 999
            } else {
                playerScore = Int(reactionTimes.reduce(0, +) / Double(reactionTimes.count))
            }
        case .digitSpan:
            playerScore = max(digitSpanMaxRecalled, digitSpanLength - 1)
        case .patternRecall:
            playerScore = patternTotalCorrect
        }

        phase = .opponentTurn
        generateOpponentScore()

        let delay = Double.random(in: 2.0...4.0)
        activeTimer = Timer.scheduledTimer(withTimeInterval: delay, repeats: false) { [weak self] _ in
            guard let self else { return }
            Task { @MainActor in
                self.showResults()
            }
        }
    }

    private func generateOpponentScore() {
        let u1 = max(Double.random(in: 0.0...1.0), 1e-10)
        let u2 = Double.random(in: 0.0...1.0)
        let z = sqrt(-2 * log(u1)) * cos(2 * .pi * u2)

        switch selectedType {
        case .reactionTime:
            let raw = z * 60 + 280
            opponentScore = Int(max(200, min(380, raw)))
        case .digitSpan:
            let raw = z * 1.5 + 6
            opponentScore = Int(max(4, min(9, raw)))
        case .patternRecall:
            let raw = z * 1.5 + 7
            opponentScore = Int(max(4, min(9, raw)))
        }
    }

    func showResults() {
        phase = .results
        showConfetti = playerWon
        if playerWon {
            let impact = UIImpactFeedbackGenerator(style: .heavy)
            impact.impactOccurred()
        }
        recordResult()
    }

    var playerWon: Bool {
        if selectedType == .reactionTime {
            return playerScore < opponentScore
        }
        return playerScore > opponentScore
    }

    var isTie: Bool {
        playerScore == opponentScore
    }

    var resultText: String {
        if isTie { return "TIE!" }
        return playerWon ? "YOU WIN!" : "YOU LOSE"
    }

    var scoreUnit: String {
        selectedType == .reactionTime ? "ms" : "pts"
    }

    private func recordResult() {
        let wins = UserDefaults.standard.integer(forKey: "duel_wins")
        let losses = UserDefaults.standard.integer(forKey: "duel_losses")
        if isTie { return }
        if playerWon {
            UserDefaults.standard.set(wins + 1, forKey: "duel_wins")
        } else {
            UserDefaults.standard.set(losses + 1, forKey: "duel_losses")
        }
    }

    var totalWins: Int { UserDefaults.standard.integer(forKey: "duel_wins") }
    var totalLosses: Int { UserDefaults.standard.integer(forKey: "duel_losses") }

    func rematch() {
        activeTimer?.invalidate()
        phase = .selection
        playerScore = 0
        opponentScore = 0
        showConfetti = false
    }

    func cleanup() {
        activeTimer?.invalidate()
    }
}

// MARK: - Duel View

struct DuelView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var viewModel = DuelViewModel()

    var body: some View {
        ZStack {
            AppColors.pageBg
                .ignoresSafeArea()

            switch viewModel.phase {
            case .selection:
                selectionScreen
            case .matchmaking:
                matchmakingScreen
            case .countdown:
                countdownScreen
            case .playing:
                playingScreen
            case .opponentTurn:
                opponentTurnScreen
            case .results:
                resultsScreen
            }
        }
        .navigationBarBackButtonHidden(true)
        .toolbar {
            ToolbarItem(placement: .topBarLeading) {
                Button {
                    viewModel.cleanup()
                    dismiss()
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.title3)
                        .foregroundStyle(.secondary)
                }
                .accessibilityLabel("Close")
            }
        }
        .onDisappear {
            viewModel.cleanup()
        }
    }

    // MARK: - Selection Screen

    private var selectionScreen: some View {
        ScrollView {
            VStack(spacing: 28) {
                // Header
                VStack(spacing: 8) {
                    HStack(spacing: 8) {
                        Image(systemName: "bolt.fill")
                            .font(.system(size: 28, weight: .bold))
                            .foregroundStyle(AppColors.coral)
                        Text("1v1 DUEL")
                            .font(.system(size: 32, weight: .bold, design: .monospaced))
                    }

                    Text("Challenge an opponent in a quick brain battle")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                }
                .padding(.top, 16)

                // Record
                if viewModel.totalWins + viewModel.totalLosses > 0 {
                    HStack(spacing: 16) {
                        Label("\(viewModel.totalWins)W", systemImage: "trophy.fill")
                            .foregroundStyle(AppColors.accent)
                        Label("\(viewModel.totalLosses)L", systemImage: "xmark.circle.fill")
                            .foregroundStyle(AppColors.coral)
                    }
                    .font(.subheadline.weight(.semibold))
                    .padding(.horizontal, 20)
                    .padding(.vertical, 10)
                    .background(AppColors.cardSurface, in: Capsule())
                }

                // Exercise cards
                VStack(spacing: 12) {
                    ForEach(DuelExerciseType.allCases) { type in
                        Button {
                            withAnimation(.spring(response: 0.3)) {
                                viewModel.selectedType = type
                            }
                            let impact = UIImpactFeedbackGenerator(style: .light)
                            impact.impactOccurred()
                        } label: {
                            exerciseTypeCard(type)
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.horizontal)

                // Find Opponent button
                Button {
                    viewModel.startMatchmaking()
                } label: {
                    HStack(spacing: 8) {
                        Image(systemName: "magnifyingglass")
                        Text("Find Opponent")
                            .fontWeight(.bold)
                    }
                    .gradientButton(AppColors.warmGradient)
                }
                .padding(.horizontal)

                Spacer(minLength: 40)
            }
        }
    }

    private func exerciseTypeCard(_ type: DuelExerciseType) -> some View {
        let isSelected = viewModel.selectedType == type
        return HStack(spacing: 14) {
            ColoredIconBadge(icon: type.icon, color: type.color, size: 48)

            VStack(alignment: .leading, spacing: 4) {
                Text(type.displayName)
                    .font(.headline)
                    .foregroundStyle(.primary)
                Text(type.description)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
            }

            Spacer()

            if isSelected {
                Image(systemName: "checkmark.circle.fill")
                    .font(.title2)
                    .foregroundStyle(type.color)
            }
        }
        .glowingCard(color: isSelected ? type.color : .clear, intensity: isSelected ? 0.25 : 0.0)
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(isSelected ? type.color.opacity(0.4) : .clear, lineWidth: 2)
        )
    }

    // MARK: - Matchmaking Screen

    private var matchmakingScreen: some View {
        VStack(spacing: 40) {
            Spacer()

            Text("FINDING OPPONENT" + String(repeating: ".", count: viewModel.searchDots))
                .font(.system(size: 18, weight: .bold, design: .monospaced))
                .foregroundStyle(.secondary)
                .animation(.none, value: viewModel.searchDots)

            HStack(spacing: 40) {
                // Player avatar
                VStack(spacing: 10) {
                    ZStack {
                        Circle()
                            .fill(AppColors.accent.opacity(0.15))
                            .frame(width: 90, height: 90)
                        Text("🧠")
                            .font(.system(size: 40))
                    }
                    Text("You")
                        .font(.headline)
                }

                // VS
                Text("VS")
                    .font(.system(size: 24, weight: .bold, design: .monospaced))
                    .foregroundStyle(AppColors.coral)

                // Opponent avatar
                VStack(spacing: 10) {
                    ZStack {
                        Circle()
                            .fill(AppColors.violet.opacity(0.15))
                            .frame(width: 90, height: 90)

                        if viewModel.opponentRevealed {
                            Text(viewModel.opponentEmoji)
                                .font(.system(size: 40))
                                .transition(.scale.combined(with: .opacity))
                        } else {
                            Text("?")
                                .font(.system(size: 36, weight: .bold, design: .monospaced))
                                .foregroundStyle(AppColors.violet)
                                .rotationEffect(.degrees(viewModel.searchDots % 2 == 0 ? -10 : 10))
                                .animation(.easeInOut(duration: 0.4), value: viewModel.searchDots)
                        }
                    }

                    if viewModel.opponentRevealed {
                        Text(viewModel.opponentName)
                            .font(.headline)
                            .transition(.move(edge: .bottom).combined(with: .opacity))
                    } else {
                        Text("???")
                            .font(.headline)
                            .foregroundStyle(.secondary)
                    }
                }
            }
            .animation(.spring(response: 0.5, dampingFraction: 0.7), value: viewModel.opponentRevealed)

            // Exercise type indicator
            HStack(spacing: 8) {
                Image(systemName: viewModel.selectedType.icon)
                Text(viewModel.selectedType.displayName)
            }
            .font(.subheadline.weight(.semibold))
            .foregroundStyle(viewModel.selectedType.color)
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
            .background(viewModel.selectedType.color.opacity(0.20), in: Capsule())

            Spacer()
        }
    }

    // MARK: - Countdown Screen

    private var countdownScreen: some View {
        ZStack {
            viewModel.selectedType.color.opacity(0.15)
                .ignoresSafeArea()

            Text("\(viewModel.countdownValue)")
                .font(.system(size: 120, weight: .bold, design: .monospaced))
                .foregroundStyle(viewModel.selectedType.color)
                .scaleEffect(viewModel.countdownValue == 3 ? 1.2 : (viewModel.countdownValue == 2 ? 1.0 : 0.9))
                .opacity(1.0)
                .animation(.spring(response: 0.3, dampingFraction: 0.5), value: viewModel.countdownValue)
        }
    }

    // MARK: - Playing Screen

    private var playingScreen: some View {
        VStack {
            switch viewModel.selectedType {
            case .reactionTime:
                reactionTimeExercise
            case .digitSpan:
                digitSpanExercise
            case .patternRecall:
                patternRecallExercise
            }
        }
    }

    // MARK: Reaction Time Exercise

    private var reactionTimeExercise: some View {
        ZStack {
            if viewModel.reactionTappedEarly {
                Color.orange.ignoresSafeArea()
                VStack(spacing: 16) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .font(.system(size: 48))
                    Text("Too early!")
                        .font(.title.weight(.bold))
                    Text("Wait for green")
                        .font(.headline)
                }
                .foregroundStyle(.white)
            } else if viewModel.reactionReady {
                Color.green.ignoresSafeArea()
                    .onTapGesture {
                        viewModel.reactionTapped()
                    }
                VStack(spacing: 16) {
                    Image(systemName: "hand.tap.fill")
                        .font(.system(size: 48))
                    Text("TAP NOW!")
                        .font(.title.weight(.bold))
                    if let last = viewModel.reactionTimes.last {
                        Text("\(Int(last)) ms")
                            .font(.system(size: 28, weight: .bold, design: .monospaced))
                    }
                }
                .foregroundStyle(.white)
                .allowsHitTesting(false)
            } else {
                Color(red: 0.85, green: 0.15, blue: 0.15).ignoresSafeArea()
                    .onTapGesture {
                        viewModel.reactionTapped()
                    }
                VStack(spacing: 16) {
                    Image(systemName: "eye.fill")
                        .font(.system(size: 48))
                    Text("Wait for green...")
                        .font(.title2.weight(.bold))
                }
                .foregroundStyle(.white)
                .allowsHitTesting(false)
            }

            // Round indicator
            VStack {
                HStack {
                    Spacer()
                    Text("Round \(viewModel.reactionRound)/5")
                        .font(.subheadline.weight(.bold))
                        .foregroundStyle(.white.opacity(0.8))
                        .padding(.horizontal, 14)
                        .padding(.vertical, 6)
                        .background(.black.opacity(0.3), in: Capsule())
                }
                .padding()
                Spacer()

                // Progress bar
                progressBar(current: viewModel.reactionRound, total: 5)
                    .padding()
            }
        }
    }

    // MARK: Digit Span Exercise

    private var digitSpanExercise: some View {
        VStack(spacing: 24) {
            // Round indicator
            HStack {
                Text("Round \(viewModel.digitSpanRound)/3")
                    .font(.subheadline.weight(.bold))
                    .foregroundStyle(.secondary)
                Spacer()
                Text("\(viewModel.digitSpanLength) digits")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(AppColors.indigo)
            }
            .padding(.horizontal)

            progressBar(current: viewModel.digitSpanRound, total: 3)
                .padding(.horizontal)

            Spacer()

            if viewModel.digitSpanShowingDigits {
                // Show digits one at a time
                VStack(spacing: 16) {
                    Text("Memorize")
                        .font(.headline)
                        .foregroundStyle(.secondary)

                    if viewModel.digitSpanCurrentIndex < viewModel.currentDigits.count {
                        Text("\(viewModel.currentDigits[viewModel.digitSpanCurrentIndex])")
                            .font(.system(size: 80, weight: .bold, design: .monospaced))
                            .foregroundStyle(AppColors.indigo)
                            .transition(.scale.combined(with: .opacity))
                            .id("digit-\(viewModel.digitSpanCurrentIndex)")
                    }
                }
                .animation(.easeInOut(duration: 0.2), value: viewModel.digitSpanCurrentIndex)
            } else if viewModel.digitSpanWaitingForInput {
                VStack(spacing: 20) {
                    Text("Enter the digits")
                        .font(.headline)
                        .foregroundStyle(.secondary)

                    TextField("Type digits...", text: Binding(
                        get: { viewModel.digitSpanUserInput },
                        set: { viewModel.digitSpanUserInput = $0 }
                    ))
                    .keyboardType(.numberPad)
                    .font(.system(size: 36, weight: .bold, design: .monospaced))
                    .multilineTextAlignment(.center)
                    .padding()
                    .background(
                        RoundedRectangle(cornerRadius: 12)
                            .fill(AppColors.cardSurface)
                    )
                    .padding(.horizontal, 40)

                    Button {
                        viewModel.submitDigitSpan()
                    } label: {
                        Text("Submit")
                            .accentButton(color: AppColors.indigo)
                    }
                    .padding(.horizontal, 40)
                }
            }

            Spacer()
        }
        .padding(.top)
    }

    // MARK: Pattern Recall Exercise

    private var patternRecallExercise: some View {
        VStack(spacing: 24) {
            HStack {
                Text("Round \(viewModel.patternRound)/2")
                    .font(.subheadline.weight(.bold))
                    .foregroundStyle(.secondary)
                Spacer()
                Text("\(viewModel.patternCellCount) cells")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(AppColors.teal)
            }
            .padding(.horizontal)

            progressBar(current: viewModel.patternRound, total: 2)
                .padding(.horizontal)

            Spacer()

            if viewModel.patternShowing {
                Text("Memorize the pattern")
                    .font(.headline)
                    .foregroundStyle(.secondary)
            } else if viewModel.patternSelecting {
                Text("Tap the cells you remember")
                    .font(.headline)
                    .foregroundStyle(.secondary)
            }

            // 4x4 Grid
            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 8), count: 4), spacing: 8) {
                ForEach(0..<16, id: \.self) { index in
                    patternCell(index)
                }
            }
            .padding(.horizontal, 40)

            if viewModel.patternSelecting {
                Button {
                    viewModel.submitPattern()
                } label: {
                    HStack {
                        Image(systemName: "checkmark")
                        Text("Submit (\(viewModel.patternUserCells.count)/\(viewModel.patternCellCount))")
                    }
                    .accentButton(color: AppColors.teal)
                }
                .padding(.horizontal, 40)
                .disabled(viewModel.patternUserCells.count != viewModel.patternCellCount)
                .opacity(viewModel.patternUserCells.count == viewModel.patternCellCount ? 1.0 : 0.5)
            }

            Spacer()
        }
        .padding(.top)
    }

    private func patternCell(_ index: Int) -> some View {
        let isTarget = viewModel.patternCells.contains(index)
        let isSelected = viewModel.patternUserCells.contains(index)
        let showHighlight = (viewModel.patternShowing && isTarget) || (viewModel.patternSelecting && isSelected)

        return Rectangle()
            .fill(showHighlight ? AppColors.teal : Color.white.opacity(0.08))
            .aspectRatio(1, contentMode: .fit)
            .clipShape(RoundedRectangle(cornerRadius: 10))
            .overlay(
                RoundedRectangle(cornerRadius: 10)
                    .stroke(isSelected ? AppColors.teal.opacity(0.5) : .clear, lineWidth: 2)
            )
            .onTapGesture {
                if viewModel.patternSelecting {
                    viewModel.togglePatternCell(index)
                }
            }
            .animation(.easeInOut(duration: 0.2), value: showHighlight)
    }

    // MARK: - Progress Bar

    private func progressBar(current: Int, total: Int) -> some View {
        GeometryReader { geo in
            ZStack(alignment: .leading) {
                RoundedRectangle(cornerRadius: 4)
                    .fill(Color.white.opacity(0.12))
                    .frame(height: 6)

                RoundedRectangle(cornerRadius: 4)
                    .fill(viewModel.selectedType.color)
                    .frame(width: geo.size.width * CGFloat(current) / CGFloat(total), height: 6)
                    .animation(.easeInOut, value: current)
            }
        }
        .frame(height: 6)
    }

    // MARK: - Opponent Turn Screen

    private var opponentTurnScreen: some View {
        VStack(spacing: 32) {
            Spacer()

            // Pulsing brain icon
            ZStack {
                Circle()
                    .fill(AppColors.violet.opacity(0.1))
                    .frame(width: 120, height: 120)
                    .scaleEffect(pulseAnimation ? 1.15 : 1.0)

                Circle()
                    .fill(AppColors.violet.opacity(0.15))
                    .frame(width: 90, height: 90)

                Text(viewModel.opponentEmoji)
                    .font(.system(size: 44))
            }
            .animation(.easeInOut(duration: 1.0).repeatForever(autoreverses: true), value: pulseAnimation)
            .onAppear { pulseAnimation = true }

            VStack(spacing: 8) {
                Text("\(viewModel.opponentName) is playing...")
                    .font(.title3.weight(.bold))

                Text(viewModel.selectedType.displayName)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }

            // Animated dots
            HStack(spacing: 6) {
                ForEach(0..<3, id: \.self) { i in
                    Circle()
                        .fill(AppColors.violet)
                        .frame(width: 10, height: 10)
                        .scaleEffect(opponentDotIndex == i ? 1.4 : 0.8)
                        .opacity(opponentDotIndex == i ? 1.0 : 0.4)
                }
            }
            .animation(.easeInOut(duration: 0.4), value: opponentDotIndex)
            .onAppear { startOpponentDots() }

            Spacer()
        }
    }

    @State private var pulseAnimation = false
    @State private var opponentDotIndex = 0
    @State private var dotTimer: Timer?

    private func startOpponentDots() {
        dotTimer?.invalidate()
        dotTimer = Timer.scheduledTimer(withTimeInterval: 0.5, repeats: true) { _ in
            Task { @MainActor in
                opponentDotIndex = (opponentDotIndex + 1) % 3
            }
        }
    }

    // MARK: - Results Screen

    private var resultsScreen: some View {
        ScrollView {
            VStack(spacing: 28) {
                // Result text
                VStack(spacing: 8) {
                    if viewModel.playerWon && !viewModel.isTie {
                        Image(systemName: "crown.fill")
                            .font(.system(size: 44))
                            .foregroundStyle(.yellow)
                    }

                    Text(viewModel.resultText)
                        .font(.system(size: 40, weight: .bold, design: .monospaced))
                        .foregroundStyle(
                            viewModel.isTie ? .primary :
                            (viewModel.playerWon ? AppColors.accent : AppColors.coral)
                        )
                }
                .padding(.top, 20)

                // Score comparison
                HStack(spacing: 0) {
                    // Player side
                    VStack(spacing: 12) {
                        if viewModel.playerWon && !viewModel.isTie {
                            Image(systemName: "crown.fill")
                                .font(.caption)
                                .foregroundStyle(.yellow)
                        }

                        ZStack {
                            Circle()
                                .fill(AppColors.accent.opacity(0.15))
                                .frame(width: 70, height: 70)
                            Text("🧠")
                                .font(.system(size: 32))
                        }

                        Text("You")
                            .font(.subheadline.weight(.semibold))

                        Text("\(viewModel.playerScore)")
                            .font(.system(size: 36, weight: .bold, design: .monospaced))
                            .foregroundStyle(viewModel.playerWon && !viewModel.isTie ? AppColors.accent : .primary)

                        Text(viewModel.scoreUnit)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    .frame(maxWidth: .infinity)
                    .glowingCard(
                        color: viewModel.playerWon && !viewModel.isTie ? AppColors.accent : .clear,
                        intensity: viewModel.playerWon && !viewModel.isTie ? 0.3 : 0.0
                    )

                    // VS divider
                    Text("VS")
                        .font(.system(size: 16, weight: .bold, design: .monospaced))
                        .foregroundStyle(.secondary)
                        .padding(.horizontal, 4)

                    // Opponent side
                    VStack(spacing: 12) {
                        if !viewModel.playerWon && !viewModel.isTie {
                            Image(systemName: "crown.fill")
                                .font(.caption)
                                .foregroundStyle(.yellow)
                        }

                        ZStack {
                            Circle()
                                .fill(AppColors.violet.opacity(0.15))
                                .frame(width: 70, height: 70)
                            Text(viewModel.opponentEmoji)
                                .font(.system(size: 32))
                        }

                        Text(viewModel.opponentName)
                            .font(.subheadline.weight(.semibold))
                            .lineLimit(1)
                            .minimumScaleFactor(0.7)

                        Text("\(viewModel.opponentScore)")
                            .font(.system(size: 36, weight: .bold, design: .monospaced))
                            .foregroundStyle(!viewModel.playerWon && !viewModel.isTie ? AppColors.violet : .primary)

                        Text(viewModel.scoreUnit)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    .frame(maxWidth: .infinity)
                    .glowingCard(
                        color: !viewModel.playerWon && !viewModel.isTie ? AppColors.violet : .clear,
                        intensity: !viewModel.playerWon && !viewModel.isTie ? 0.3 : 0.0
                    )
                }
                .padding(.horizontal)

                // Win/Loss record
                HStack(spacing: 24) {
                    HStack(spacing: 6) {
                        Image(systemName: "trophy.fill")
                            .foregroundStyle(AppColors.accent)
                        Text("\(viewModel.totalWins) Wins")
                            .font(.subheadline.weight(.semibold))
                    }
                    HStack(spacing: 6) {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundStyle(AppColors.coral)
                        Text("\(viewModel.totalLosses) Losses")
                            .font(.subheadline.weight(.semibold))
                    }
                }
                .padding(.vertical, 12)
                .padding(.horizontal, 24)
                .background(AppColors.cardSurface, in: Capsule())

                // Exercise info
                HStack(spacing: 8) {
                    Image(systemName: viewModel.selectedType.icon)
                    Text(viewModel.selectedType.displayName)
                }
                .font(.subheadline.weight(.medium))
                .foregroundStyle(.secondary)

                // Action buttons
                VStack(spacing: 12) {
                    Button {
                        shareDuelResult()
                    } label: {
                        HStack(spacing: 8) {
                            Image(systemName: "square.and.arrow.up")
                            Text("Share Result")
                        }
                        .accentButton(color: AppColors.sky)
                    }

                    Button {
                        withAnimation(.spring(response: 0.4)) {
                            dotTimer?.invalidate()
                            pulseAnimation = false
                            viewModel.rematch()
                        }
                    } label: {
                        HStack(spacing: 8) {
                            Image(systemName: "arrow.counterclockwise")
                            Text("Rematch")
                        }
                        .gradientButton(AppColors.warmGradient)
                    }

                    Button {
                        viewModel.cleanup()
                        dotTimer?.invalidate()
                        dismiss()
                    } label: {
                        Text("Done")
                            .font(.headline)
                            .foregroundStyle(.secondary)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 14)
                    }
                }
                .padding(.horizontal)

                Spacer(minLength: 30)
            }
        }
    }

    // MARK: - Share

    private func shareDuelResult() {
        let result = viewModel.playerWon ? "Won" : (viewModel.isTie ? "Tied" : "Lost")
        let text = """
        Memori 1v1 Duel
        \(result) vs \(viewModel.opponentName) \(viewModel.opponentEmoji)
        \(viewModel.selectedType.displayName): \(viewModel.playerScore)\(viewModel.scoreUnit) vs \(viewModel.opponentScore)\(viewModel.scoreUnit)
        Record: \(viewModel.totalWins)W - \(viewModel.totalLosses)L
        """

        let activityVC = UIActivityViewController(activityItems: [text], applicationActivities: nil)

        if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
           let root = windowScene.windows.first?.rootViewController {
            var topVC = root
            while let presented = topVC.presentedViewController {
                topVC = presented
            }
            activityVC.popoverPresentationController?.sourceView = topVC.view
            topVC.present(activityVC, animated: true)
        }
    }
}

// MARK: - Preview

#Preview {
    NavigationStack {
        DuelView()
    }
}
