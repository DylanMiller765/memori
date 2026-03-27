import SwiftUI
import SwiftData

// MARK: - PM Phase

enum PMPhase {
    case instruction
    case filler
    case results
}

// MARK: - Trigger Type

enum PMTriggerType {
    case eventBased
    case timeBased
}

// MARK: - PM Scenario

struct PMScenario: Identifiable {
    let id = UUID()
    let instruction: String
    let triggerType: PMTriggerType
    let triggerIcon: String          // SF Symbol for the trigger button
    let triggerDescription: String   // What should happen
    let targetTimes: [TimeInterval]  // For time-based: when to tap (seconds from start)
    let fillerTaskType: FillerTask

    enum FillerTask: CaseIterable {
        case livingNonLiving
        case oddEven
        case positiveNegative
    }
}

// MARK: - Filler Item

struct FillerItem: Identifiable {
    let id = UUID()
    let text: String
    let correctAnswer: Bool // true = left button, false = right button
    let isRed: Bool         // For the "red word" trigger
    let isNumber7: Bool     // For the "number 7" trigger
}

// MARK: - ProspectiveMemoryViewModel

@MainActor @Observable
final class ProspectiveMemoryViewModel {
    // State
    var phase: PMPhase = .instruction
    var currentScenario: PMScenario?

    // Filler task
    var fillerItems: [FillerItem] = []
    var currentFillerIndex: Int = 0
    var fillerCorrect: Int = 0
    var fillerTotal: Int = 0

    // PM tracking
    var pmTriggered: Bool = false
    var pmResponded: Bool = false
    var pmReactionTime: TimeInterval? = nil
    var pmTimeTaps: [TimeInterval] = []

    // Timer
    var fillerTimeRemaining: TimeInterval = 0
    var fillerDuration: TimeInterval = 60

    // Event trigger
    var showEventTrigger: Bool = false
    var eventTriggerAppearTime: Date? = nil

    // Time-based
    var fillerElapsed: TimeInterval = 0
    var showClockButton: Bool = false

    // Results
    var pmScore: Double = 0
    var fillerScore: Double = 0
    var overallScore: Double = 0
    var durationSeconds: Int = 0
    var difficulty: Int = 1
    var strategyTip: StrategyTip?
    var roundsCompleted: Int = 0

    // Internal
    private var timer: Timer?
    private var startTime: Date?
    private var triggerScheduled: Bool = false
    private var eventTriggerTimer: Timer?
    private var randomTriggerIndex: Int = -1

    // MARK: - Scenarios (10+)

    private let scenarios: [PMScenario] = [
        // Event-based (1-5)
        PMScenario(
            instruction: "While doing the task below, tap the STAR button the moment it appears.",
            triggerType: .eventBased,
            triggerIcon: "star.fill",
            triggerDescription: "A star will briefly appear in the corner",
            targetTimes: [],
            fillerTaskType: .livingNonLiving
        ),
        PMScenario(
            instruction: "While categorizing words, tap ALERT when you see a word in RED.",
            triggerType: .eventBased,
            triggerIcon: "exclamationmark.triangle.fill",
            triggerDescription: "One word will turn red during the task",
            targetTimes: [],
            fillerTaskType: .livingNonLiving
        ),
        PMScenario(
            instruction: "While sorting numbers, tap the BELL when the number 7 appears.",
            triggerType: .eventBased,
            triggerIcon: "bell.fill",
            triggerDescription: "The number 7 will appear among the items",
            targetTimes: [],
            fillerTaskType: .oddEven
        ),
        PMScenario(
            instruction: "While doing the task, tap the BOLT when you feel a vibration.",
            triggerType: .eventBased,
            triggerIcon: "bolt.fill",
            triggerDescription: "A haptic pulse will occur during the task",
            targetTimes: [],
            fillerTaskType: .positiveNegative
        ),
        PMScenario(
            instruction: "While categorizing words, tap the DIAMOND when a word about ANIMALS appears.",
            triggerType: .eventBased,
            triggerIcon: "diamond.fill",
            triggerDescription: "An animal word will appear during categorization",
            targetTimes: [],
            fillerTaskType: .livingNonLiving
        ),
        // Time-based (6-10)
        PMScenario(
            instruction: "While doing the task, tap the CLOCK button after exactly 30 seconds.",
            triggerType: .timeBased,
            triggerIcon: "clock.fill",
            triggerDescription: "Tap at 30 seconds — no timer visible",
            targetTimes: [30],
            fillerTaskType: .oddEven
        ),
        PMScenario(
            instruction: "While doing the task, tap the CLOCK button after exactly 45 seconds.",
            triggerType: .timeBased,
            triggerIcon: "clock.fill",
            triggerDescription: "Tap at 45 seconds — no timer visible",
            targetTimes: [45],
            fillerTaskType: .livingNonLiving
        ),
        PMScenario(
            instruction: "While doing the task, tap the CLOCK button after exactly 60 seconds.",
            triggerType: .timeBased,
            triggerIcon: "clock.fill",
            triggerDescription: "Tap at 60 seconds — no timer visible",
            targetTimes: [60],
            fillerTaskType: .positiveNegative
        ),
        PMScenario(
            instruction: "Tap the CLOCK at 20 seconds, then again at 40 seconds.",
            triggerType: .timeBased,
            triggerIcon: "clock.fill",
            triggerDescription: "Tap at both 20s and 40s — no timer visible",
            targetTimes: [20, 40],
            fillerTaskType: .oddEven
        ),
        PMScenario(
            instruction: "Tap the CLOCK every 15 seconds during the task.",
            triggerType: .timeBased,
            triggerIcon: "clock.fill",
            triggerDescription: "Tap at 15s, 30s, 45s, 60s — no timer visible",
            targetTimes: [15, 30, 45, 60],
            fillerTaskType: .livingNonLiving
        )
    ]

    // MARK: - Word pools

    private let livingWords = [
        "cat", "tree", "dog", "flower", "bird", "fish", "horse", "rose",
        "frog", "mushroom", "eagle", "daisy", "whale", "grass", "tiger",
        "oak", "snake", "tulip", "bear", "moss", "rabbit", "vine", "bee",
        "coral", "wolf", "fern", "deer", "lily", "ant", "cedar"
    ]

    private let nonLivingWords = [
        "rock", "chair", "table", "phone", "glass", "brick", "car", "lamp",
        "book", "clock", "spoon", "bridge", "hammer", "mirror", "ring",
        "cup", "wheel", "gate", "coin", "rope", "bell", "pipe", "nail",
        "tile", "drum", "bolt", "frame", "badge", "knob", "chain"
    ]

    private let positiveWords = [
        "joy", "love", "peace", "hope", "smile", "kind", "brave", "calm",
        "trust", "warm", "bright", "happy", "gentle", "grace", "free",
        "dream", "shine", "proud", "sweet", "pure", "safe", "heal", "gift"
    ]

    private let negativeWords = [
        "fear", "hate", "anger", "grief", "loss", "pain", "cold", "dark",
        "harsh", "tense", "bleak", "grim", "dread", "gloom", "doubt",
        "bitter", "cruel", "ruin", "scorn", "storm", "wrath", "torn", "void"
    ]

    // MARK: - Public API

    func startRound() {
        guard let scenario = scenarios.randomElement() else { return }
        currentScenario = scenario
        difficulty = AdaptiveDifficultyEngine.shared.currentLevel(for: .digits)

        // Adjust filler duration by difficulty (harder = longer distraction)
        fillerDuration = Double(55 + min(difficulty * 5, 35)) // 60-90s

        resetRoundState()
        generateFillerItems(for: scenario)

        phase = .instruction
    }

    func beginFillerTask() {
        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
        phase = .filler
        startTime = Date.now
        fillerTimeRemaining = fillerDuration
        fillerElapsed = 0
        showClockButton = true
        scheduleEventTrigger()
        startTimer()
    }

    func answerFiller(isLeftButton: Bool) {
        guard currentFillerIndex < fillerItems.count else { return }
        let item = fillerItems[currentFillerIndex]
        let correct = item.correctAnswer == isLeftButton
        if correct { fillerCorrect += 1 }
        fillerTotal += 1

        // Check if this is the number 7 scenario trigger
        if let scenario = currentScenario, scenario.triggerType == .eventBased,
           scenario.triggerIcon == "bell.fill", item.isNumber7 {
            // The trigger number appeared — mark as triggered
            if !pmTriggered {
                pmTriggered = true
                eventTriggerAppearTime = Date.now
                showEventTrigger = true
                // Auto-hide after 5 seconds if not tapped
                DispatchQueue.main.asyncAfter(deadline: .now() + 5) { [weak self] in
                    self?.showEventTrigger = false
                }
            }
        }

        // Check if this is the red word scenario trigger
        if let scenario = currentScenario, scenario.triggerType == .eventBased,
           scenario.triggerIcon == "exclamationmark.triangle.fill", item.isRed {
            if !pmTriggered {
                pmTriggered = true
                eventTriggerAppearTime = Date.now
                showEventTrigger = true
                DispatchQueue.main.asyncAfter(deadline: .now() + 5) { [weak self] in
                    self?.showEventTrigger = false
                }
            }
        }

        currentFillerIndex += 1
        if currentFillerIndex >= fillerItems.count {
            // Regenerate more items to keep going
            if let scenario = currentScenario {
                let moreItems = buildFillerBatch(for: scenario, count: 20, offset: fillerTotal)
                fillerItems.append(contentsOf: moreItems)
            }
        }
    }

    func tapPMTrigger() {
        UIImpactFeedbackGenerator(style: .heavy).impactOccurred()

        guard let scenario = currentScenario else { return }

        if scenario.triggerType == .eventBased {
            if pmTriggered, let appearTime = eventTriggerAppearTime, !pmResponded {
                pmResponded = true
                pmReactionTime = Date.now.timeIntervalSince(appearTime)
                showEventTrigger = false
                HapticService.correct()
            }
        } else {
            // Time-based: record the tap time
            pmTimeTaps.append(fillerElapsed)
        }
    }

    func finishRound() {
        stopTimer()
        eventTriggerTimer?.invalidate()
        eventTriggerTimer = nil

        guard let scenario = currentScenario else { return }

        // Calculate PM score
        if scenario.triggerType == .eventBased {
            pmScore = pmResponded ? 1.0 : 0.0
        } else {
            // Time-based scoring: how close were taps to target times?
            let targets = scenario.targetTimes
            if targets.isEmpty {
                pmScore = 0
            } else {
                var totalAccuracy: Double = 0
                for target in targets {
                    // Find the closest tap to this target
                    let closest = pmTimeTaps.min(by: { abs($0 - target) < abs($1 - target) })
                    if let tap = closest {
                        let error = abs(tap - target)
                        // Full credit within 3s, partial up to 10s, zero beyond
                        if error <= 3 {
                            totalAccuracy += 1.0
                        } else if error <= 10 {
                            totalAccuracy += max(0, 1.0 - (error - 3) / 7.0)
                        }
                    }
                    // If no tap at all, 0 for this target
                }
                pmScore = totalAccuracy / Double(targets.count)
            }
        }

        // Filler score
        fillerScore = fillerTotal > 0 ? Double(fillerCorrect) / Double(fillerTotal) : 0

        // Overall: PM task is primary (70%), filler is secondary (30%)
        overallScore = pmScore * 0.7 + fillerScore * 0.3

        if let start = startTime {
            durationSeconds = max(1, Int(Date.now.timeIntervalSince(start)))
        }

        // Record with adaptive engine
        AdaptiveDifficultyEngine.shared.recordBlock(
            domain: .digits,
            correct: Int(pmScore * 10),
            total: 10
        )

        strategyTip = StrategyTipService.shared.freshTip(for: .digits)
        roundsCompleted += 1
        phase = .results

        if pmScore >= 0.7 {
            SoundService.shared.playCorrect()
            HapticService.correct()
        } else {
            SoundService.shared.playWrong()
            HapticService.wrong()
        }
        SoundService.shared.playComplete()
        HapticService.complete()
    }

    // MARK: - Private

    private func resetRoundState() {
        fillerItems = []
        currentFillerIndex = 0
        fillerCorrect = 0
        fillerTotal = 0
        pmTriggered = false
        pmResponded = false
        pmReactionTime = nil
        pmTimeTaps = []
        showEventTrigger = false
        eventTriggerAppearTime = nil
        fillerTimeRemaining = 0
        fillerElapsed = 0
        showClockButton = false
        triggerScheduled = false
        randomTriggerIndex = -1
    }

    private func generateFillerItems(for scenario: PMScenario) {
        // Pick a random trigger index for event-based scenarios embedded in filler items
        randomTriggerIndex = Int.random(in: 8...28)
        fillerItems = buildFillerBatch(for: scenario, count: 40, offset: 0)
    }

    private func buildFillerBatch(for scenario: PMScenario, count: Int, offset: Int) -> [FillerItem] {
        var items: [FillerItem] = []

        switch scenario.fillerTaskType {
        case .livingNonLiving:
            for i in 0..<count {
                let isLiving = Bool.random()
                let pool = isLiving ? livingWords : nonLivingWords
                let word = pool.randomElement() ?? "item"
                // "Red word" trigger: appear at a random index
                let isRed = (!triggerScheduled &&
                             scenario.triggerIcon == "exclamationmark.triangle.fill" && offset + i == randomTriggerIndex)
                // "Animal word" trigger for diamond scenario at random index
                let isAnimal = (scenario.triggerIcon == "diamond.fill" && isLiving &&
                                !triggerScheduled && offset + i == randomTriggerIndex)
                items.append(FillerItem(
                    text: word,
                    correctAnswer: isLiving,
                    isRed: isRed || isAnimal,
                    isNumber7: false
                ))
                if isRed || isAnimal { triggerScheduled = true }
            }

        case .oddEven:
            for i in 0..<count {
                var number = Int.random(in: 1...99)
                // "Number 7" trigger at random index
                let shouldBe7 = (scenario.triggerIcon == "bell.fill" &&
                                 !triggerScheduled && offset + i == randomTriggerIndex)
                if shouldBe7 {
                    number = 7
                    triggerScheduled = true
                }
                let isOdd = number % 2 != 0
                items.append(FillerItem(
                    text: "\(number)",
                    correctAnswer: isOdd,
                    isRed: false,
                    isNumber7: number == 7 && shouldBe7
                ))
            }

        case .positiveNegative:
            for _ in 0..<count {
                let isPositive = Bool.random()
                let pool = isPositive ? positiveWords : negativeWords
                let word = pool.randomElement() ?? "word"
                items.append(FillerItem(
                    text: word,
                    correctAnswer: isPositive,
                    isRed: false,
                    isNumber7: false
                ))
            }
        }

        return items
    }

    private func scheduleEventTrigger() {
        guard let scenario = currentScenario, scenario.triggerType == .eventBased else { return }

        // For star and bolt triggers, schedule appearance at a random time
        if scenario.triggerIcon == "star.fill" || scenario.triggerIcon == "bolt.fill" {
            let delay = Double.random(in: 15...max(20, fillerDuration - 15))
            eventTriggerTimer = Timer.scheduledTimer(withTimeInterval: delay, repeats: false) { [weak self] _ in
                guard let self, self.phase == .filler else { return }
                self.pmTriggered = true
                self.eventTriggerAppearTime = Date.now

                if scenario.triggerIcon == "bolt.fill" {
                    // Haptic pulse as the "beep"
                    UIImpactFeedbackGenerator(style: .heavy).impactOccurred()
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                        UIImpactFeedbackGenerator(style: .heavy).impactOccurred()
                    }
                }

                self.showEventTrigger = true
                // Auto-hide after 5s
                DispatchQueue.main.asyncAfter(deadline: .now() + 5) { [weak self] in
                    self?.showEventTrigger = false
                }
            }
        }
        // For red word, number 7, and diamond triggers, they're embedded in filler items
    }

    private func startTimer() {
        stopTimer()
        timer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { [weak self] _ in
            guard let self, self.phase == .filler else { return }
            self.fillerTimeRemaining -= 0.1
            self.fillerElapsed += 0.1
            if self.fillerTimeRemaining <= 0 {
                self.fillerTimeRemaining = 0
                self.finishRound()
            }
        }
    }

    private func stopTimer() {
        timer?.invalidate()
        timer = nil
    }
}

// MARK: - ProspectiveMemoryView

struct ProspectiveMemoryView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @Environment(AchievementService.self) private var achievementService
    @Environment(TrainingSessionManager.self) private var trainingManager
    @Environment(PaywallTriggerService.self) private var paywallTrigger
    @Environment(StoreService.self) private var storeService
    @Environment(GameCenterService.self) private var gameCenterService
    @Query private var users: [User]

    @State private var viewModel = ProspectiveMemoryViewModel()
    @State private var hasStarted = false
    @State private var showingPaywall = false

    private var user: User? { users.first }
    private var isProUser: Bool { storeService.isProUser }

    var body: some View {
        VStack(spacing: 0) {
            if !hasStarted {
                startView
            } else {
                switch viewModel.phase {
                case .instruction:
                    instructionView
                case .filler:
                    fillerView
                case .results:
                    resultsView
                }
            }
        }
        .navigationTitle("Prospective Memory")
        .navigationBarTitleDisplayMode(.inline)
        .sheet(isPresented: $showingPaywall) {
            PaywallView(isHighIntent: true)
        }
    }

    // MARK: - Start

    private var startView: some View {
        VStack(spacing: 28) {
            Spacer()

            ZStack {
                Circle()
                    .fill(AppColors.cardBorder)
                    .frame(width: 120, height: 120)
                Image(systemName: "clock.badge.checkmark")
                    .font(.system(size: 52, weight: .medium))
                    .foregroundStyle(AppColors.accent)
            }

            VStack(spacing: 12) {
                Text("Prospective Memory")
                    .font(.title.weight(.bold))

                Text("Remember To Do Things Later")
                    .font(.headline)
                    .foregroundStyle(AppColors.violet)
            }

            VStack(alignment: .leading, spacing: 12) {
                tipRow(
                    icon: "brain.head.profile",
                    text: "The #1 real-world memory complaint: \"I forgot to...\""
                )
                tipRow(
                    icon: "target",
                    text: "Hold an intention in mind while staying busy with another task."
                )
                tipRow(
                    icon: "chart.line.uptrend.xyaxis",
                    text: "Research shows prospective memory is trainable (Hering et al. 2014)."
                )
            }
            .appCard()
            .padding(.horizontal)

            Spacer()

            Button {
                UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                hasStarted = true
                viewModel.startRound()
            } label: {
                Text("Start Training")
                    .accentButton(color: AppColors.violet)
            }
            .accessibilityHint("Starts the exercise")
            .padding(.horizontal, 32)
        }
        .padding(.vertical, 24)
    }

    private func tipRow(icon: String, text: String) -> some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: icon)
                .font(.body.weight(.semibold))
                .foregroundStyle(AppColors.violet)
                .frame(width: 24)
            Text(text)
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
    }

    // MARK: - Instruction

    private var instructionView: some View {
        VStack(spacing: 32) {
            Spacer()

            ZStack {
                Circle()
                    .fill(AppColors.cardBorder)
                    .frame(width: 100, height: 100)
                Image(systemName: viewModel.currentScenario?.triggerIcon ?? "star.fill")
                    .font(.system(size: 44, weight: .medium))
                    .foregroundStyle(AppColors.accent)
            }

            VStack(spacing: 16) {
                Text("Remember This")
                    .font(.title2.weight(.bold))

                Text(viewModel.currentScenario?.instruction ?? "")
                    .font(.body)
                    .multilineTextAlignment(.center)
                    .foregroundStyle(.primary)
                    .padding(.horizontal)

                Text(viewModel.currentScenario?.triggerDescription ?? "")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal)
            }
            .appCard()
            .padding(.horizontal)

            VStack(spacing: 4) {
                Text("You'll also do a simple sorting task.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Text("Don't forget your main mission!")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(AppColors.violet)
            }

            Spacer()

            Button {
                viewModel.beginFillerTask()
            } label: {
                Text("I'll Remember - Start")
                    .accentButton(color: AppColors.violet)
            }
            .padding(.horizontal, 32)
        }
        .padding(.vertical, 24)
    }

    // MARK: - Filler Task

    private var fillerView: some View {
        ZStack {
            VStack(spacing: 20) {
                // Progress bar (no time label for time-based to prevent cheating)
                HStack {
                    Text(fillerTaskLabel)
                        .font(.caption.weight(.medium))
                        .foregroundStyle(.secondary)
                    Spacer()
                    if viewModel.currentScenario?.triggerType == .eventBased {
                        Text("\(Int(viewModel.fillerTimeRemaining))s")
                            .font(.caption.monospacedDigit())
                            .foregroundStyle(.secondary)
                            .accessibilityLabel("Time remaining: \(Int(viewModel.fillerTimeRemaining)) seconds")
                    }
                }
                .padding(.horizontal)

                ProgressView(value: max(0, viewModel.fillerDuration - viewModel.fillerTimeRemaining),
                             total: viewModel.fillerDuration)
                    .tint(AppColors.violet.opacity(0.5))
                    .padding(.horizontal)

                Spacer()

                // Current filler item
                if viewModel.currentFillerIndex < viewModel.fillerItems.count {
                    let item = viewModel.fillerItems[viewModel.currentFillerIndex]
                    Text(item.text)
                        .font(.system(size: 40, weight: .bold))
                        .foregroundStyle(item.isRed ? AppColors.error : .primary)
                        .transition(.opacity.combined(with: .scale))
                        .id(viewModel.currentFillerIndex)
                }

                Spacer()

                // Filler answer buttons
                fillerButtons

                // PM trigger button (time-based: clock always visible; event-based: only when triggered)
                if viewModel.currentScenario?.triggerType == .timeBased && viewModel.showClockButton {
                    pmTriggerButton
                        .padding(.top, 8)
                }

                // Score display
                HStack {
                    Text("Correct: \(viewModel.fillerCorrect)/\(viewModel.fillerTotal)")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Spacer()
                }
                .padding(.horizontal)
            }
            .padding(.vertical, 24)

            // Event-based trigger overlay
            if viewModel.showEventTrigger && viewModel.currentScenario?.triggerType == .eventBased {
                VStack {
                    HStack {
                        Spacer()
                        pmTriggerButton
                            .transition(.scale.combined(with: .opacity))
                    }
                    Spacer()
                }
                .padding()
                .animation(.spring(response: 0.4, dampingFraction: 0.7), value: viewModel.showEventTrigger)
            }
        }
    }

    private var fillerTaskLabel: String {
        guard let scenario = viewModel.currentScenario else { return "Categorize" }
        switch scenario.fillerTaskType {
        case .livingNonLiving: return "Living or Non-living?"
        case .oddEven: return "Odd or Even?"
        case .positiveNegative: return "Positive or Negative?"
        }
    }

    private var fillerButtons: some View {
        HStack(spacing: 16) {
            let labels = fillerButtonLabels
            Button {
                UIImpactFeedbackGenerator(style: .light).impactOccurred()
                viewModel.answerFiller(isLeftButton: true)
            } label: {
                Text(labels.0)
                    .font(.headline)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .background(AppColors.teal.opacity(0.15), in: RoundedRectangle(cornerRadius: 12))
                    .foregroundStyle(AppColors.teal)
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(AppColors.teal.opacity(0.3), lineWidth: 1)
                    )
            }

            Button {
                UIImpactFeedbackGenerator(style: .light).impactOccurred()
                viewModel.answerFiller(isLeftButton: false)
            } label: {
                Text(labels.1)
                    .font(.headline)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .background(AppColors.coral.opacity(0.15), in: RoundedRectangle(cornerRadius: 12))
                    .foregroundStyle(AppColors.coral)
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(AppColors.coral.opacity(0.3), lineWidth: 1)
                    )
            }
        }
        .padding(.horizontal)
    }

    private var fillerButtonLabels: (String, String) {
        guard let scenario = viewModel.currentScenario else { return ("Yes", "No") }
        switch scenario.fillerTaskType {
        case .livingNonLiving: return ("Living", "Non-living")
        case .oddEven: return ("Odd", "Even")
        case .positiveNegative: return ("Positive", "Negative")
        }
    }

    private var pmTriggerButton: some View {
        Button {
            viewModel.tapPMTrigger()
        } label: {
            HStack(spacing: 6) {
                Image(systemName: viewModel.currentScenario?.triggerIcon ?? "star.fill")
                    .font(.title2)
                if viewModel.currentScenario?.triggerType == .timeBased {
                    Text("Clock")
                        .font(.caption.weight(.semibold))
                }
            }
            .padding(12)
            .background(
                AppColors.accent,
                in: RoundedRectangle(cornerRadius: 12)
            )
            .foregroundStyle(.white)
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(AppColors.cardBorder, lineWidth: 1)
            )
        }
    }

    // MARK: - Results

    private var resultsView: some View {
        ScrollView {
            VStack(spacing: 24) {
                ZStack {
                    Circle()
                        .fill(AppColors.cardBorder)
                        .frame(width: 100, height: 100)
                    Image(systemName: viewModel.pmScore >= 0.7 ? "checkmark.circle.fill" : "exclamationmark.circle.fill")
                        .font(.system(size: 64))
                        .foregroundStyle(viewModel.pmScore >= 0.7 ? AppColors.accent : AppColors.warning)
                }
                .padding(.top, 24)

                Text(viewModel.pmScore >= 0.7 ? "You Remembered!" : "You Forgot!")
                    .font(.title.weight(.bold))

                // Primary result: PM task
                VStack(spacing: 12) {
                    resultRow(
                        label: "Prospective Task",
                        value: viewModel.pmScore >= 0.7 ? "Remembered" : "Forgot",
                        color: viewModel.pmScore >= 0.7 ? AppColors.violet : AppColors.error
                    )

                    if let rt = viewModel.pmReactionTime {
                        resultRow(
                            label: "Reaction Time",
                            value: String(format: "%.1fs", rt),
                            color: rt < 2 ? AppColors.violet : AppColors.warning
                        )
                    }

                    if viewModel.currentScenario?.triggerType == .timeBased {
                        let targets = viewModel.currentScenario?.targetTimes ?? []
                        resultRow(
                            label: "Taps Made",
                            value: "\(viewModel.pmTimeTaps.count) / \(targets.count) needed",
                            color: .primary
                        )
                    }

                    Divider()

                    resultRow(label: "Filler Task", value: viewModel.fillerScore.percentString, color: .primary)
                    resultRow(label: "Overall Score", value: viewModel.overallScore.percentString, color: .primary)
                    resultRow(label: "Time", value: viewModel.durationSeconds.durationString, color: .primary)
                }
                .glowingCard(color: AppColors.violet, intensity: 0.08)
                .padding(.horizontal)

                // Real-world connection
                VStack(alignment: .leading, spacing: 8) {
                    HStack(spacing: 6) {
                        Image(systemName: "globe")
                            .foregroundStyle(AppColors.sky)
                        Text("Real-World Connection")
                            .font(.subheadline.weight(.semibold))
                    }
                    Text("In daily life, this is like remembering to take medicine, call someone back, pick up groceries on the way home, or send that email after a meeting.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .appCard()
                .padding(.horizontal)

                // Strategy tip
                VStack(alignment: .leading, spacing: 8) {
                    HStack(spacing: 6) {
                        Image(systemName: "lightbulb.fill")
                            .foregroundStyle(AppColors.warning)
                        Text("Implementation Intentions")
                            .font(.subheadline.weight(.semibold))
                    }
                    Text("Research shows that forming \"if-then\" plans dramatically improves prospective memory: \"IF I see the pharmacy, THEN I will buy vitamins.\" This simple reframing can double your success rate (Gollwitzer, 1999).")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .appCard()
                .padding(.horizontal)

                // Strategy tip from service
                if let tip = viewModel.strategyTip {
                    VStack(alignment: .leading, spacing: 8) {
                        HStack(spacing: 6) {
                            Image(systemName: "brain")
                                .foregroundStyle(AppColors.teal)
                            Text(tip.title)
                                .font(.subheadline.weight(.semibold))
                        }
                        Text(tip.body)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    .appCard()
                    .padding(.horizontal)
                }

                LeaderboardRankCard(
                    exerciseType: .prospectiveMemory,
                    userScore: Int(viewModel.overallScore * 100),
                )
                .padding(.horizontal)

                VStack(spacing: 12) {
                    Button {
                        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                        viewModel.startRound()
                    } label: {
                        Text("Next Challenge")
                            .accentButton(color: AppColors.violet)
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
                .padding(.bottom, 32)
            }
        }
    }

    private func resultRow(label: String, value: String, color: Color) -> some View {
        HStack {
            Text(label)
                .font(.subheadline)
                .foregroundStyle(.secondary)
            Spacer()
            Text(value)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(color)
        }
    }

    // MARK: - Save

    private func saveExercise() {
        paywallTrigger.recordExerciseCompleted()
        trainingManager.addTrainingTime(viewModel.durationSeconds)

        let exercise = Exercise(
            type: .prospectiveMemory,
            difficulty: viewModel.difficulty,
            score: viewModel.overallScore,
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

        PersonalBestTracker.shared.record(score: Int(viewModel.overallScore * 100), for: .prospectiveMemory)

        if let user {
            _ = ContentView.awardXP(
                user: user,
                score: viewModel.overallScore,
                difficulty: viewModel.difficulty,
                achievementService: achievementService,
                modelContext: modelContext,
                gameCenterService: gameCenterService,
                exerciseType: .prospectiveMemory
            )
        }
    }
}
