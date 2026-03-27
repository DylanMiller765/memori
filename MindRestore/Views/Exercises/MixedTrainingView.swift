import SwiftUI
import SwiftData

// MARK: - Mini-Exercise Types

enum MiniExerciseType: String, CaseIterable, Identifiable {
    case quickNumbers, quickWords, quickPattern, quickMath, quickFaceName
    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .quickNumbers: return "Quick Numbers"
        case .quickWords: return "Quick Words"
        case .quickPattern: return "Quick Pattern"
        case .quickMath: return "Quick Math"
        case .quickFaceName: return "Quick Face-Name"
        }
    }

    var icon: String {
        switch self {
        case .quickNumbers: return "number"
        case .quickWords: return "textformat.abc"
        case .quickPattern: return "square.grid.4x3.fill"
        case .quickMath: return "plus.forwardslash.minus"
        case .quickFaceName: return "person.text.rectangle"
        }
    }

    var color: Color {
        switch self {
        case .quickNumbers: return AppColors.teal
        case .quickWords: return AppColors.violet
        case .quickPattern: return AppColors.indigo
        case .quickMath: return AppColors.coral
        case .quickFaceName: return AppColors.sky
        }
    }
}

// MARK: - Round Data

struct MixedRound: Identifiable {
    let id = UUID()
    let type: MiniExerciseType
    var isCorrect: Bool = false
    var isCompleted: Bool = false
}

// MARK: - ViewModel

@MainActor @Observable
final class MixedTrainingViewModel {
    // Session config
    let totalRounds = 10
    var rounds: [MixedRound] = []
    var currentRoundIndex = 0
    var sessionPhase: SessionPhase = .intro
    var startTime: Date?
    var endTime: Date?

    enum SessionPhase {
        case intro, transition, playing, results
    }

    // Quick Numbers state
    var numberDigits: String = ""
    var numberInput: String = ""
    var numberPhase: MiniPhase = .memorize
    var numberTimeRemaining: Double = 3.0

    // Quick Words state
    var words: [String] = []
    var wordInput: String = ""
    var wordPhase: MiniPhase = .memorize
    var wordTimeRemaining: Double = 5.0

    // Quick Pattern state
    var patternGrid: [[Bool]] = Array(repeating: Array(repeating: false, count: 4), count: 4)
    var playerGrid: [[Bool]] = Array(repeating: Array(repeating: false, count: 4), count: 4)
    var patternPhase: MiniPhase = .memorize
    var patternTimeRemaining: Double = 2.0

    // Quick Math state
    var mathQuestion: String = ""
    var mathAnswer: Int = 0
    var mathInput: String = ""
    var mathPhase: MiniPhase = .recall

    // Quick Face-Name state
    var faceName: String = ""
    var faceDescription: String = ""
    var faceNameInput: String = ""
    var facePhase: MiniPhase = .memorize
    var faceTimeRemaining: Double = 4.0

    // Shared
    var roundResult: Bool? = nil

    enum MiniPhase {
        case memorize, recall, result
    }

    // MARK: - Computed

    var currentRound: MixedRound? {
        guard currentRoundIndex < rounds.count else { return nil }
        return rounds[currentRoundIndex]
    }

    var progress: Double {
        Double(currentRoundIndex) / Double(totalRounds)
    }

    var overallScore: Double {
        let completed = rounds.filter(\.isCompleted)
        guard !completed.isEmpty else { return 0 }
        return Double(completed.filter(\.isCorrect).count) / Double(completed.count)
    }

    var durationSeconds: Int {
        guard let start = startTime else { return 0 }
        let end = endTime ?? Date.now
        return Int(end.timeIntervalSince(start))
    }

    var scoresByType: [MiniExerciseType: (correct: Int, total: Int)] {
        var result: [MiniExerciseType: (correct: Int, total: Int)] = [:]
        for round in rounds where round.isCompleted {
            let current = result[round.type] ?? (0, 0)
            result[round.type] = (current.correct + (round.isCorrect ? 1 : 0), current.total + 1)
        }
        return result
    }

    // MARK: - Session Setup

    func generateSession() {
        var generated: [MiniExerciseType] = []
        let types = MiniExerciseType.allCases

        for _ in 0..<totalRounds {
            var candidates = types.filter { candidate in
                // No more than 2 of the same type in a row
                if generated.count >= 2 {
                    let last = generated.suffix(2)
                    if last.allSatisfy({ $0 == candidate }) {
                        return false
                    }
                }
                return true
            }
            if candidates.isEmpty { candidates = types }
            if let candidate = candidates.randomElement() {
                generated.append(candidate)
            }
        }

        rounds = generated.map { MixedRound(type: $0) }
    }

    func startSession() {
        startTime = Date.now
        sessionPhase = .transition
    }

    func beginRound() {
        roundResult = nil
        guard let round = currentRound else { return }
        sessionPhase = .playing

        switch round.type {
        case .quickNumbers:
            setupQuickNumbers()
        case .quickWords:
            setupQuickWords()
        case .quickPattern:
            setupQuickPattern()
        case .quickMath:
            setupQuickMath()
        case .quickFaceName:
            setupQuickFaceName()
        }
    }

    func completeRound(correct: Bool) {
        guard currentRoundIndex < rounds.count else { return }
        rounds[currentRoundIndex].isCorrect = correct
        rounds[currentRoundIndex].isCompleted = true
        roundResult = correct

        if correct {
            SoundService.shared.playCorrect()
        } else {
            UINotificationFeedbackGenerator().notificationOccurred(.error)
            SoundService.shared.playWrong()
        }
    }

    func advanceRound() {
        currentRoundIndex += 1
        if currentRoundIndex >= totalRounds {
            endTime = Date.now
            sessionPhase = .results
            SoundService.shared.playComplete()
        } else {
            sessionPhase = .transition
        }
    }

    // MARK: - Quick Numbers

    private func setupQuickNumbers() {
        let count = Int.random(in: 4...8)
        numberDigits = (0..<count).map { _ in String(Int.random(in: 0...9)) }.joined()
        numberInput = ""
        numberPhase = .memorize
        numberTimeRemaining = 3.0
    }

    func submitNumbers() {
        let correct = numberInput.filter(\.isNumber) == numberDigits
        completeRound(correct: correct)
        numberPhase = .result
    }

    // MARK: - Quick Words

    private static let wordBank = [
        "apple", "bridge", "castle", "dragon", "eagle", "forest", "guitar", "hammer",
        "island", "jungle", "kettle", "lantern", "marble", "needle", "ocean", "palace",
        "rabbit", "silver", "temple", "umbrella", "village", "window", "garden", "candle",
        "ribbon", "thunder", "velvet", "crystal", "beacon", "shadow", "copper", "feather",
        "harbor", "ivory", "jasmine", "kernel", "ladder", "meadow", "napkin", "orchid",
        "pillow", "quartz", "rocket", "saddle", "tablet", "anchor", "basket", "chimney"
    ]

    private func setupQuickWords() {
        words = Array(Self.wordBank.shuffled().prefix(5))
        wordInput = ""
        wordPhase = .memorize
        wordTimeRemaining = 5.0
    }

    func submitWords() {
        let inputWords = wordInput
            .lowercased()
            .split(separator: " ")
            .map(String.init)
            .filter { !$0.isEmpty }
        let matchCount = inputWords.filter { words.contains($0) }.count
        let correct = matchCount >= 3 // At least 3 out of 5
        completeRound(correct: correct)
        wordPhase = .result
    }

    var wordMatchCount: Int {
        let inputWords = wordInput
            .lowercased()
            .split(separator: " ")
            .map(String.init)
            .filter { !$0.isEmpty }
        return inputWords.filter { words.contains($0) }.count
    }

    // MARK: - Quick Pattern

    private func setupQuickPattern() {
        patternGrid = Array(repeating: Array(repeating: false, count: 4), count: 4)
        playerGrid = Array(repeating: Array(repeating: false, count: 4), count: 4)
        // Light up 5-7 cells
        let cellCount = Int.random(in: 5...7)
        var positions = Set<Int>()
        while positions.count < cellCount {
            positions.insert(Int.random(in: 0..<16))
        }
        for pos in positions {
            patternGrid[pos / 4][pos % 4] = true
        }
        patternPhase = .memorize
        patternTimeRemaining = 2.0
    }

    func submitPattern() {
        let correct = patternGrid == playerGrid
        completeRound(correct: correct)
        patternPhase = .result
    }

    var patternMatchCount: Int {
        var matches = 0
        for r in 0..<4 {
            for c in 0..<4 {
                if patternGrid[r][c] == playerGrid[r][c] { matches += 1 }
            }
        }
        return matches
    }

    // MARK: - Quick Math

    private func setupQuickMath() {
        let ops: [(String, (Int, Int) -> Int)] = [
            ("+", { $0 + $1 }),
            ("-", { $0 - $1 }),
            ("x", { $0 * $1 })
        ]
        let (symbol, op) = ops.randomElement() ?? ("+", { $0 + $1 })

        let a: Int
        let b: Int
        switch symbol {
        case "+":
            a = Int.random(in: 10...99)
            b = Int.random(in: 10...99)
        case "-":
            a = Int.random(in: 20...99)
            b = Int.random(in: 10...(a - 1))
        default: // multiply
            a = Int.random(in: 2...12)
            b = Int.random(in: 2...12)
        }

        mathAnswer = op(a, b)
        mathQuestion = "\(a) \(symbol) \(b) = ?"
        mathInput = ""
        mathPhase = .recall
    }

    func submitMath() {
        let correct = Int(mathInput) == mathAnswer
        completeRound(correct: correct)
        mathPhase = .result
    }

    // MARK: - Quick Face-Name

    private static let faceNamePairs: [(name: String, description: String)] = [
        ("Margaret", "the librarian with curly red hair"),
        ("James", "the tall mechanic who loves jazz"),
        ("Sofia", "the baker with a bright smile"),
        ("David", "the professor wearing round glasses"),
        ("Elena", "the architect who plays violin"),
        ("Marcus", "the firefighter with a mustache"),
        ("Ling", "the software engineer from Portland"),
        ("Amara", "the nurse who collects stamps"),
        ("Roberto", "the chef with a booming laugh"),
        ("Priya", "the teacher who runs marathons"),
        ("Thomas", "the pilot with the silver watch"),
        ("Yuki", "the artist who paints landscapes"),
        ("Carlos", "the dentist who loves gardening"),
        ("Olivia", "the journalist with freckles"),
        ("Raj", "the accountant who plays chess"),
        ("Hannah", "the vet who rescues animals")
    ]

    private func setupQuickFaceName() {
        guard let pair = Self.faceNamePairs.randomElement() else { return }
        faceName = pair.name
        faceDescription = pair.description
        faceNameInput = ""
        facePhase = .memorize
        faceTimeRemaining = 4.0
    }

    func submitFaceName() {
        let correct = faceNameInput.trimmingCharacters(in: .whitespacesAndNewlines)
            .lowercased() == faceName.lowercased()
        completeRound(correct: correct)
        facePhase = .result
    }

    // MARK: - Strategy Tip

    var strategyTip: String {
        let scores = scoresByType
        // Find worst category
        var worstType: MiniExerciseType?
        var worstRatio: Double = 2.0
        for (type, data) in scores {
            let ratio = data.total > 0 ? Double(data.correct) / Double(data.total) : 1.0
            if ratio < worstRatio {
                worstRatio = ratio
                worstType = type
            }
        }

        guard let worst = worstType, worstRatio < 1.0 else {
            return "Perfect session! Keep challenging yourself with higher difficulty exercises."
        }

        switch worst {
        case .quickNumbers:
            return "Try chunking numbers into groups of 2-3 digits. For example, 749382 becomes 749-382."
        case .quickWords:
            return "Create a vivid mental story linking the words together. The more absurd, the more memorable!"
        case .quickPattern:
            return "Look for shapes within the grid pattern — like letters or familiar objects."
        case .quickMath:
            return "Break complex math into simpler steps. For 47 + 38, think 47 + 40 - 2 = 85."
        case .quickFaceName:
            return "Associate the name with a distinctive feature. Picture Margaret's curly red hair shaped like an M."
        }
    }
}

// MARK: - Main View

struct MixedTrainingView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @Environment(AchievementService.self) private var achievementService
    @Environment(TrainingSessionManager.self) private var trainingManager
    @Environment(PaywallTriggerService.self) private var paywallTrigger
    @Environment(StoreService.self) private var storeService
    @Environment(GameCenterService.self) private var gameCenterService
    @Query private var users: [User]

    @State private var vm = MixedTrainingViewModel()
    @State private var timer: Timer?
    @State private var transitionOpacity: Double = 0
    @State private var showingPaywall = false

    private var user: User? { users.first }
    private var isProUser: Bool { storeService.isProUser }

    var body: some View {
        VStack(spacing: 0) {
            switch vm.sessionPhase {
            case .intro:
                introView
            case .transition:
                transitionView
            case .playing:
                playingView
            case .results:
                resultsView
            }
        }
        .navigationTitle("Mixed Training")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                if vm.sessionPhase == .playing || vm.sessionPhase == .transition {
                    Text("Round \(vm.currentRoundIndex + 1)/\(vm.totalRounds)")
                        .font(.caption.weight(.medium))
                        .foregroundStyle(.secondary)
                }
            }
        }
        .onAppear {
            vm.generateSession()
        }
        .onDisappear {
            timer?.invalidate()
        }
        .sheet(isPresented: $showingPaywall) {
            PaywallView(isHighIntent: true)
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
                Image(systemName: "shuffle")
                    .font(.system(size: 52, weight: .medium))
                    .foregroundStyle(AppColors.accent)
            }

            VStack(spacing: 8) {
                Text("Mixed Training")
                    .font(.title.weight(.bold))
                Text("Interleaved practice for stronger memory")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }

            VStack(alignment: .leading, spacing: 12) {
                ForEach(MiniExerciseType.allCases) { type in
                    HStack(spacing: 12) {
                        Image(systemName: type.icon)
                            .font(.body.weight(.semibold))
                            .foregroundStyle(type.color)
                            .frame(width: 28)
                        Text(type.displayName)
                            .font(.subheadline)
                    }
                }
            }
            .padding(20)
            .appCard()

            VStack(spacing: 4) {
                Text("\(vm.totalRounds) rounds, ~10 minutes")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Text("Exercises appear in random order")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Button {
                vm.startSession()
            } label: {
                Text("Start Session")
                    .gradientButton()
            }
            .accessibilityHint("Starts the exercise")
            .padding(.horizontal, 32)
            .padding(.top, 8)
        }
        .padding(.top, 24)
    }

    // MARK: - Transition

    private var transitionView: some View {
        VStack(spacing: 24) {
            Spacer()

            if let round = vm.currentRound {
                VStack(spacing: 16) {
                    ZStack {
                        Circle()
                            .fill(AppColors.cardBorder)
                            .frame(width: 80, height: 80)
                        Image(systemName: round.type.icon)
                            .font(.system(size: 38, weight: .medium))
                            .foregroundStyle(AppColors.accent)
                    }

                    Text("Next Up")
                        .font(.caption.weight(.bold))
                        .foregroundStyle(.secondary)
                        .tracking(1)

                    Text(round.type.displayName)
                        .font(.title2.weight(.bold))
                }
                .opacity(transitionOpacity)
            }

            Spacer()

            ProgressView(value: vm.progress)
                .tint(AppColors.accent)
                .padding(.horizontal, 32)
                .padding(.bottom, 24)
        }
        .onAppear {
            transitionOpacity = 0
            withAnimation(.easeIn(duration: 0.3)) {
                transitionOpacity = 1
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                vm.beginRound()
            }
        }
    }

    // MARK: - Playing View Router

    @ViewBuilder
    private var playingView: some View {
        VStack(spacing: 0) {
            ProgressView(value: vm.progress)
                .tint(AppColors.accent)
                .padding(.horizontal)
                .padding(.top, 8)

            if let round = vm.currentRound {
                switch round.type {
                case .quickNumbers:
                    quickNumbersView
                case .quickWords:
                    quickWordsView
                case .quickPattern:
                    quickPatternView
                case .quickMath:
                    quickMathView
                case .quickFaceName:
                    quickFaceNameView
                }
            }
        }
    }

    // MARK: - Quick Numbers

    private var quickNumbersView: some View {
        VStack(spacing: 24) {
            Spacer()

            switch vm.numberPhase {
            case .memorize:
                VStack(spacing: 20) {
                    miniHeader(type: .quickNumbers)

                    timerBar(remaining: vm.numberTimeRemaining, total: 3.0)

                    Text(vm.numberDigits)
                        .font(.system(size: 40, weight: .bold, design: .monospaced))
                        .tracking(8)
                        .foregroundStyle(.primary)
                }
                .onAppear { startCountdown(duration: 3.0) { vm.numberTimeRemaining = $0 } onComplete: { vm.numberPhase = .recall } }

            case .recall:
                VStack(spacing: 20) {
                    Text("What were the numbers?")
                        .font(.title3.weight(.semibold))

                    Text("\(vm.numberDigits.count) digits in order")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)

                    TextField("Type the numbers...", text: $vm.numberInput)
                        .keyboardType(.numberPad)
                        .font(.system(size: 32, weight: .bold, design: .monospaced))
                        .multilineTextAlignment(.center)
                        .padding()
                        .background(AppColors.cardSurface, in: RoundedRectangle(cornerRadius: 12))
                        .padding(.horizontal, 40)

                    Button {
                        vm.submitNumbers()
                    } label: {
                        Text("Submit")
                            .gradientButton()
                    }
                    .padding(.horizontal, 32)
                }

            case .result:
                roundResultView {
                    VStack(spacing: 8) {
                        HStack {
                            Text("Correct:")
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                            Spacer()
                            Text(vm.numberDigits)
                                .font(.system(.title3, design: .monospaced).weight(.semibold))
                                .foregroundStyle(AppColors.accent)
                        }
                        if vm.roundResult != true {
                            HStack {
                                Text("Yours:")
                                    .font(.subheadline)
                                    .foregroundStyle(.secondary)
                                Spacer()
                                Text(vm.numberInput.isEmpty ? "--" : vm.numberInput)
                                    .font(.system(.title3, design: .monospaced).weight(.semibold))
                                    .foregroundStyle(AppColors.coral)
                            }
                        }
                    }
                }
            }

            Spacer()
        }
        .padding(.vertical, 24)
    }

    // MARK: - Quick Words

    private var quickWordsView: some View {
        VStack(spacing: 24) {
            Spacer()

            switch vm.wordPhase {
            case .memorize:
                VStack(spacing: 20) {
                    miniHeader(type: .quickWords)

                    timerBar(remaining: vm.wordTimeRemaining, total: 5.0)

                    VStack(spacing: 8) {
                        ForEach(vm.words, id: \.self) { word in
                            Text(word)
                                .font(.title3.weight(.semibold))
                        }
                    }
                }
                .onAppear { startCountdown(duration: 5.0) { vm.wordTimeRemaining = $0 } onComplete: { vm.wordPhase = .recall } }

            case .recall:
                VStack(spacing: 20) {
                    Text("Type the words you remember")
                        .font(.title3.weight(.semibold))

                    Text("Separate with spaces")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)

                    TextField("word1 word2 word3...", text: $vm.wordInput)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                        .font(.system(.body).weight(.medium))
                        .padding()
                        .background(AppColors.cardSurface, in: RoundedRectangle(cornerRadius: 12))
                        .padding(.horizontal, 32)

                    Button {
                        vm.submitWords()
                    } label: {
                        Text("Submit")
                            .gradientButton()
                    }
                    .padding(.horizontal, 32)
                }

            case .result:
                roundResultView {
                    VStack(spacing: 8) {
                        Text("Words: \(vm.words.joined(separator: ", "))")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                        Text("You got \(vm.wordMatchCount)/\(vm.words.count) correct")
                            .font(.subheadline.weight(.medium))
                            .foregroundStyle(vm.roundResult == true ? AppColors.accent : AppColors.coral)
                    }
                }
            }

            Spacer()
        }
        .padding(.vertical, 24)
    }

    // MARK: - Quick Pattern

    private var quickPatternView: some View {
        VStack(spacing: 24) {
            Spacer()

            switch vm.patternPhase {
            case .memorize:
                VStack(spacing: 20) {
                    miniHeader(type: .quickPattern)

                    timerBar(remaining: vm.patternTimeRemaining, total: 2.0)

                    patternGridView(grid: vm.patternGrid, interactive: false)
                }
                .onAppear { startCountdown(duration: 2.0) { vm.patternTimeRemaining = $0 } onComplete: { vm.patternPhase = .recall } }

            case .recall:
                VStack(spacing: 20) {
                    Text("Reproduce the pattern")
                        .font(.title3.weight(.semibold))

                    Text("Tap cells to toggle them")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)

                    patternGridView(grid: vm.playerGrid, interactive: true)

                    Button {
                        vm.submitPattern()
                    } label: {
                        Text("Submit")
                            .gradientButton()
                    }
                    .padding(.horizontal, 32)
                }

            case .result:
                roundResultView {
                    VStack(spacing: 12) {
                        Text("\(vm.patternMatchCount)/16 cells correct")
                            .font(.subheadline.weight(.medium))
                            .foregroundStyle(vm.roundResult == true ? AppColors.accent : AppColors.coral)

                        HStack(spacing: 24) {
                            VStack(spacing: 4) {
                                Text("Target")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                                patternGridView(grid: vm.patternGrid, interactive: false, cellSize: 20)
                            }
                            VStack(spacing: 4) {
                                Text("Yours")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                                patternGridView(grid: vm.playerGrid, interactive: false, cellSize: 20)
                            }
                        }
                    }
                }
            }

            Spacer()
        }
        .padding(.vertical, 24)
    }

    private func patternGridView(grid: [[Bool]], interactive: Bool, cellSize: CGFloat = 44) -> some View {
        VStack(spacing: 4) {
            ForEach(0..<4, id: \.self) { row in
                HStack(spacing: 4) {
                    ForEach(0..<4, id: \.self) { col in
                        let isOn = grid[row][col]
                        RoundedRectangle(cornerRadius: cellSize * 0.2)
                            .fill(isOn ? AnyShapeStyle(LinearGradient(colors: [AppColors.indigo, AppColors.violet], startPoint: .topLeading, endPoint: .bottomTrailing)) : AnyShapeStyle(AppColors.cardSurface))
                            .frame(width: cellSize, height: cellSize)
                            .onTapGesture {
                                if interactive {
                                    UIImpactFeedbackGenerator(style: .light).impactOccurred()
                                    vm.playerGrid[row][col].toggle()
                                }
                            }
                    }
                }
            }
        }
    }

    // MARK: - Quick Math

    private var quickMathView: some View {
        VStack(spacing: 24) {
            Spacer()

            switch vm.mathPhase {
            case .memorize:
                EmptyView() // Math skips memorize phase

            case .recall:
                VStack(spacing: 20) {
                    miniHeader(type: .quickMath)

                    Text(vm.mathQuestion)
                        .font(.system(size: 36, weight: .bold, design: .monospaced))

                    TextField("Answer", text: $vm.mathInput)
                        .keyboardType(.numberPad)
                        .font(.system(size: 32, weight: .bold, design: .monospaced))
                        .multilineTextAlignment(.center)
                        .padding()
                        .background(AppColors.cardSurface, in: RoundedRectangle(cornerRadius: 12))
                        .padding(.horizontal, 40)

                    Button {
                        vm.submitMath()
                    } label: {
                        Text("Submit")
                            .gradientButton()
                    }
                    .padding(.horizontal, 32)
                }

            case .result:
                roundResultView {
                    VStack(spacing: 8) {
                        Text("Answer: \(vm.mathAnswer)")
                            .font(.subheadline.weight(.medium))
                            .foregroundStyle(AppColors.accent)
                        if vm.roundResult != true {
                            Text("Yours: \(vm.mathInput.isEmpty ? "--" : vm.mathInput)")
                                .font(.subheadline)
                                .foregroundStyle(AppColors.coral)
                        }
                    }
                }
            }

            Spacer()
        }
        .padding(.vertical, 24)
    }

    // MARK: - Quick Face-Name

    private var quickFaceNameView: some View {
        VStack(spacing: 24) {
            Spacer()

            switch vm.facePhase {
            case .memorize:
                VStack(spacing: 20) {
                    miniHeader(type: .quickFaceName)

                    timerBar(remaining: vm.faceTimeRemaining, total: 4.0)

                    VStack(spacing: 12) {
                        Image(systemName: "person.circle.fill")
                            .font(.system(size: 56))
                            .foregroundStyle(AppColors.accent)

                        Text(vm.faceName)
                            .font(.title2.weight(.bold))

                        Text(vm.faceDescription)
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, 32)
                    }
                    .padding(20)
                    .appCard()
                    .padding(.horizontal, 24)
                }
                .onAppear { startCountdown(duration: 4.0) { vm.faceTimeRemaining = $0 } onComplete: { vm.facePhase = .recall } }

            case .recall:
                VStack(spacing: 20) {
                    Text("What was the name of...")
                        .font(.title3.weight(.semibold))

                    Text(vm.faceDescription)
                        .font(.body)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 32)

                    TextField("Name...", text: $vm.faceNameInput)
                        .textInputAutocapitalization(.words)
                        .font(.system(size: 24, weight: .bold))
                        .multilineTextAlignment(.center)
                        .padding()
                        .background(AppColors.cardSurface, in: RoundedRectangle(cornerRadius: 12))
                        .padding(.horizontal, 40)

                    Button {
                        vm.submitFaceName()
                    } label: {
                        Text("Submit")
                            .gradientButton()
                    }
                    .padding(.horizontal, 32)
                }

            case .result:
                roundResultView {
                    VStack(spacing: 8) {
                        Text("Name: \(vm.faceName)")
                            .font(.subheadline.weight(.medium))
                            .foregroundStyle(AppColors.accent)
                        if vm.roundResult != true {
                            Text("Yours: \(vm.faceNameInput.isEmpty ? "--" : vm.faceNameInput)")
                                .font(.subheadline)
                                .foregroundStyle(AppColors.coral)
                        }
                    }
                }
            }

            Spacer()
        }
        .padding(.vertical, 24)
    }

    // MARK: - Shared Components

    private func miniHeader(type: MiniExerciseType) -> some View {
        HStack {
            Image(systemName: type.icon)
                .foregroundStyle(type.color)
            Text(type.displayName.uppercased())
                .font(.caption.weight(.bold))
                .foregroundStyle(type.color)
                .tracking(1)
            Spacer()
        }
        .padding(.horizontal, 32)
    }

    private func timerBar(remaining: Double, total: Double) -> some View {
        VStack(spacing: 4) {
            HStack {
                Text("MEMORIZE")
                    .font(.caption.weight(.bold))
                    .foregroundStyle(AppColors.accent)
                    .tracking(1)
                Spacer()
                Text(String(format: "%.0fs", max(0, remaining)))
                    .font(.headline.monospacedDigit())
                    .foregroundStyle(remaining <= 1 ? AppColors.coral : AppColors.accent)
            }
            ProgressView(value: max(0, remaining), total: total)
                .tint(AppColors.accent)
        }
        .padding(.horizontal, 32)
    }

    private func roundResultView<Detail: View>(@ViewBuilder detail: () -> Detail) -> some View {
        VStack(spacing: 20) {
            let isCorrect = vm.roundResult ?? false

            ZStack {
                Circle()
                    .fill(AppColors.cardBorder)
                    .frame(width: 80, height: 80)
                Image(systemName: isCorrect ? "checkmark.circle.fill" : "xmark.circle.fill")
                    .font(.system(size: 48))
                    .foregroundStyle(isCorrect ? AppColors.accent : AppColors.coral)
            }

            Text(isCorrect ? "Correct!" : "Not quite")
                .font(.title2.weight(.bold))

            detail()
                .padding(16)
                .background(
                    RoundedRectangle(cornerRadius: 12)
                        .fill(AppColors.cardSurface)
                )
                .padding(.horizontal, 32)

            Button {
                vm.advanceRound()
            } label: {
                Text(vm.currentRoundIndex + 1 >= vm.totalRounds ? "See Results" : "Next")
                    .gradientButton()
            }
            .padding(.horizontal, 32)
        }
    }

    // MARK: - Timer Utility

    private func startCountdown(duration: Double, update: @escaping (Double) -> Void, onComplete: @escaping () -> Void) {
        timer?.invalidate()
        update(duration)
        // Use a single async delay pattern
        let startDate = Date.now
        timer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { t in
            Task { @MainActor in
                let elapsed = Date.now.timeIntervalSince(startDate)
                let remaining = duration - elapsed
                update(max(0, remaining))
                if remaining <= 0 {
                    t.invalidate()
                    onComplete()
                }
            }
        }
    }

    // MARK: - Results View

    private var resultsView: some View {
        ScrollView {
            VStack(spacing: 24) {
                Spacer().frame(height: 16)

                ZStack {
                    Circle()
                        .fill(AppColors.cardBorder)
                        .frame(width: 100, height: 100)
                    Image(systemName: "chart.bar.fill")
                        .font(.system(size: 48, weight: .medium))
                        .foregroundStyle(AppColors.accent)
                }

                Text("Session Complete!")
                    .font(.title.weight(.bold))

                VStack(spacing: 8) {
                    Text("Score: \(vm.overallScore.percentString)")
                        .font(.title2.weight(.semibold))
                        .foregroundStyle(AppColors.accent)
                        .accessibilityLabel("Score: \(vm.overallScore.percentString)")
                    Text("\(vm.totalRounds) rounds completed")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                    Text("Time: \(vm.durationSeconds.durationString)")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }

                // Breakdown by type
                VStack(spacing: 12) {
                    Text("Breakdown by Type")
                        .font(.headline)
                        .frame(maxWidth: .infinity, alignment: .leading)

                    ForEach(MiniExerciseType.allCases) { type in
                        if let data = vm.scoresByType[type] {
                            HStack(spacing: 12) {
                                Image(systemName: type.icon)
                                    .font(.body.weight(.semibold))
                                    .foregroundStyle(type.color)
                                    .frame(width: 28)

                                Text(type.displayName)
                                    .font(.subheadline)

                                Spacer()

                                Text("\(data.correct)/\(data.total)")
                                    .font(.subheadline.weight(.semibold).monospacedDigit())
                                    .foregroundStyle(data.correct == data.total ? AppColors.accent : AppColors.coral)

                                // Mini progress bar
                                let ratio = data.total > 0 ? Double(data.correct) / Double(data.total) : 0
                                ProgressView(value: ratio)
                                    .tint(type.color)
                                    .frame(width: 60)
                            }
                        }
                    }
                }
                .padding(16)
                .glowingCard(color: AppColors.accent, intensity: 0.08)
                .padding(.horizontal, 16)

                // Strategy tip
                VStack(spacing: 8) {
                    HStack {
                        Image(systemName: "lightbulb.fill")
                            .foregroundStyle(AppColors.warning)
                        Text("Strategy Tip")
                            .font(.subheadline.weight(.bold))
                        Spacer()
                    }
                    Text(vm.strategyTip)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
                .padding(16)
                .appCard()
                .padding(.horizontal, 16)

                // Research note
                VStack(spacing: 4) {
                    Text("Based on interleaving research by Rohrer & Taylor (2007)")
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                    Text("Mixed practice improves learning 20-50% vs blocked practice")
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                }
                .multilineTextAlignment(.center)
                .padding(.top, 8)

                LeaderboardRankCard(
                    exerciseType: .activeRecall,
                    userScore: Int(vm.overallScore * 100),
                )
                .padding(.horizontal)

                Button {
                    saveExercise()
                    dismiss()
                } label: {
                    Text("Done")
                        .gradientButton()
                }
                .padding(.horizontal, 32)

                Spacer().frame(height: 24)
            }
        }
    }

    // MARK: - Save

    private func saveExercise() {
        paywallTrigger.recordExerciseCompleted()
        trainingManager.addTrainingTime(vm.durationSeconds)

        let exercise = Exercise(
            type: .activeRecall,
            difficulty: 2,
            score: vm.overallScore,
            durationSeconds: vm.durationSeconds
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
                score: vm.overallScore,
                difficulty: 2,
                achievementService: achievementService,
                modelContext: modelContext,
                gameCenterService: gameCenterService
            )
        }
    }
}
