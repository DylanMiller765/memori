import Foundation
import UIKit

enum AssessmentPhase: Equatable {
    case intro
    case digitInstructions
    case digitShow
    case digitInput
    case reactionInstructions
    case reactionWait
    case reactionGo
    case reactionTooEarly
    case reactionResult
    case visualInstructions
    case visualShow
    case visualInput
    case calculating
    case results
}

@MainActor @Observable
final class BrainAssessmentViewModel {
    var phase: AssessmentPhase = .intro
    var startTime = Date()

    // Digit Span
    var currentDigits: [Int] = []
    var displayDigitIndex: Int = 0
    var digitInput: String = ""
    var digitRound: Int = 0
    var digitStartLength: Int = 4
    var digitMaxCorrect: Int = 3
    var digitUsedRetry: Bool = false
    private var digitTimer: Timer?

    // Reaction Time
    var reactionRound: Int = 0
    var reactionTimes: [Int] = []
    var reactionStartTime: Date?
    var lastReactionMs: Int = 0
    private var reactionTimer: Timer?

    // Visual Memory
    var gridSize: Int = 4
    var highlightedCells: Set<Int> = []
    var selectedCells: Set<Int> = []
    var visualRound: Int = 0
    var visualStartCount: Int = 3
    var visualMaxCorrect: Int = 2
    var visualUsedRetry: Bool = false
    private var visualTimer: Timer?

    // Retry feedback
    var showingRetryMessage: Bool = false

    // Results
    var digitScore: Double = 0
    var reactionScore: Double = 0
    var visualScore: Double = 0
    var brainScore: Int = 0
    var brainAge: Int = 25
    var brainType: BrainType = .balancedBrain
    var percentile: Int = 50
    var avgReactionMs: Int = 300

    // MARK: - Flow Control

    func start() {
        startTime = Date.now
        phase = .digitInstructions
        scheduleTransition(after: 2.5) { [weak self] in
            self?.startDigitSpan()
        }
    }

    // MARK: - Digit Span

    private func startDigitSpan() {
        digitRound = 0
        digitMaxCorrect = 0
        digitStartLength = 4
        digitUsedRetry = false
        nextDigitRound()
    }

    private func nextDigitRound() {
        let length = digitStartLength + digitRound
        currentDigits = (0..<length).map { _ in Int.random(in: 0...9) }
        displayDigitIndex = -1
        digitInput = ""
        phase = .digitShow
        showNextDigit()
    }

    // Counter that always increments — forces SwiftUI to re-animate even repeated digits
    var digitRevealCounter: Int = 0

    private func showNextDigit() {
        digitTimer?.invalidate()
        displayDigitIndex += 1
        digitRevealCounter += 1

        if displayDigitIndex >= currentDigits.count {
            digitTimer = Timer.scheduledTimer(withTimeInterval: 0.4, repeats: false) { [weak self] _ in
                Task { @MainActor in
                    self?.displayDigitIndex = -1
                    self?.phase = .digitInput
                }
            }
            return
        }

        let interval: TimeInterval = currentDigits.count <= 5 ? 0.8 : 0.65
        digitTimer = Timer.scheduledTimer(withTimeInterval: interval, repeats: false) { [weak self] _ in
            Task { @MainActor in
                self?.showNextDigit()
            }
        }
    }

    var isShowingDigit: Bool {
        displayDigitIndex >= 0 && displayDigitIndex < currentDigits.count
    }

    func submitDigitAnswer() {
        let correct = currentDigits.map(String.init).joined()
        if digitInput == correct {
            digitMaxCorrect = currentDigits.count
            digitRound += 1
            if digitRound < 6 {
                nextDigitRound()
            } else {
                finishDigitSpan()
            }
        } else if !digitUsedRetry {
            // Second chance — retry same difficulty with new numbers
            digitUsedRetry = true
            showingRetryMessage = true
            UINotificationFeedbackGenerator().notificationOccurred(.warning)
            scheduleTransition(after: 1.2) { [weak self] in
                self?.showingRetryMessage = false
                self?.nextDigitRound() // Same digitRound = same length
            }
        } else {
            // If they got none right, at least credit the previous round
            if digitMaxCorrect == 0 && digitRound == 0 {
                digitMaxCorrect = 3 // Below minimum — they couldn't do 4
            }
            finishDigitSpan()
        }
    }

    private func finishDigitSpan() {
        digitTimer?.invalidate()
        digitScore = BrainScoring.digitSpanScore(maxDigits: digitMaxCorrect)
        phase = .reactionInstructions
        scheduleTransition(after: 2.5) { [weak self] in
            self?.startReactionTime()
        }
    }

    // MARK: - Reaction Time

    private func startReactionTime() {
        reactionRound = 0
        reactionTimes = []
        nextReactionRound()
    }

    private func nextReactionRound() {
        phase = .reactionWait
        let delay = Double.random(in: 1.5...4.0)
        reactionTimer?.invalidate()
        reactionTimer = Timer.scheduledTimer(withTimeInterval: delay, repeats: false) { [weak self] _ in
            Task { @MainActor in
                self?.phase = .reactionGo
                self?.reactionStartTime = Date.now
                UIImpactFeedbackGenerator(style: .heavy).impactOccurred()
            }
        }
    }

    func tapReaction() {
        if phase == .reactionWait {
            reactionTimer?.invalidate()
            phase = .reactionTooEarly
            UINotificationFeedbackGenerator().notificationOccurred(.error)
            scheduleTransition(after: 1.0) { [weak self] in
                self?.nextReactionRound()
            }
            return
        }

        guard phase == .reactionGo, let start = reactionStartTime else { return }
        let ms = Int(Date.now.timeIntervalSince(start) * 1000)
        lastReactionMs = ms
        reactionTimes.append(ms)
        reactionRound += 1

        phase = .reactionResult

        scheduleTransition(after: 1.0) { [weak self] in
            guard let self else { return }
            if self.reactionRound < 5 {
                self.nextReactionRound()
            } else {
                self.finishReactionTime()
            }
        }
    }

    private func finishReactionTime() {
        reactionTimer?.invalidate()
        let avg = reactionTimes.isEmpty ? 500 : reactionTimes.reduce(0, +) / reactionTimes.count
        avgReactionMs = avg
        reactionScore = BrainScoring.reactionTimeScore(avgMs: avg)
        phase = .visualInstructions
        scheduleTransition(after: 2.5) { [weak self] in
            self?.startVisualMemory()
        }
    }

    // MARK: - Visual Memory

    private func startVisualMemory() {
        visualRound = 0
        visualMaxCorrect = 0
        visualUsedRetry = false
        nextVisualRound()
    }

    private func nextVisualRound() {
        let count = visualStartCount + visualRound
        selectedCells = []
        highlightedCells = Set((0..<(gridSize * gridSize)).shuffled().prefix(count))
        phase = .visualShow

        visualTimer?.invalidate()
        visualTimer = Timer.scheduledTimer(withTimeInterval: 2.0, repeats: false) { [weak self] _ in
            Task { @MainActor in
                self?.phase = .visualInput
            }
        }
    }

    func toggleCell(_ index: Int) {
        if selectedCells.contains(index) {
            selectedCells.remove(index)
        } else if selectedCells.count < highlightedCells.count {
            selectedCells.insert(index)
        }
    }

    func submitVisualAnswer() {
        let cellCount = visualStartCount + visualRound
        if selectedCells == highlightedCells {
            visualMaxCorrect = cellCount
            visualRound += 1
            if visualRound < 6 {
                nextVisualRound()
            } else {
                finishVisualMemory()
            }
        } else if !visualUsedRetry {
            // Second chance — retry same difficulty with new pattern
            visualUsedRetry = true
            showingRetryMessage = true
            UINotificationFeedbackGenerator().notificationOccurred(.warning)
            scheduleTransition(after: 1.2) { [weak self] in
                self?.showingRetryMessage = false
                self?.nextVisualRound() // Same visualRound = same cell count
            }
        } else {
            // Partial credit: if they got none right, credit previous round
            if visualMaxCorrect == 0 && visualRound == 0 {
                visualMaxCorrect = 2 // Below minimum
            }
            UINotificationFeedbackGenerator().notificationOccurred(.error)
            finishVisualMemory()
        }
    }

    private func finishVisualMemory() {
        visualTimer?.invalidate()
        visualScore = BrainScoring.visualMemoryScore(maxLevel: visualMaxCorrect)
        phase = .calculating
        calculateResults()
    }

    // MARK: - Results

    private func calculateResults() {
        brainScore = BrainScoring.compositeBrainScore(digit: digitScore, reaction: reactionScore, visual: visualScore)
        brainAge = BrainScoring.brainAge(from: brainScore)
        brainType = BrainScoring.determineBrainType(digit: digitScore, reaction: reactionScore, visual: visualScore)
        percentile = BrainScoring.percentile(score: brainScore)

        scheduleTransition(after: 2.0) { [weak self] in
            self?.phase = .results
        }
    }

    /// Update percentile using real leaderboard data if available (10+ players)
    func updatePercentileFromLeaderboard(rank: Int, totalPlayers: Int) {
        guard totalPlayers >= 10, rank > 0 else { return }
        // rank 1 of 100 = top 1% = better than 99%
        let realPercentile = max(1, min(99, Int((1.0 - Double(rank) / Double(totalPlayers)) * 100)))
        percentile = realPercentile
    }

    func createResult() -> BrainScoreResult {
        let result = BrainScoreResult()
        result.brainScore = brainScore
        result.brainAge = brainAge
        result.brainType = brainType
        result.digitSpanScore = digitScore
        result.reactionTimeScore = reactionScore
        result.visualMemoryScore = visualScore
        result.digitSpanMax = digitMaxCorrect
        result.reactionTimeAvgMs = avgReactionMs
        result.visualMemoryMax = visualMaxCorrect
        result.percentile = percentile
        return result
    }

    var currentDisplayDigit: String {
        guard displayDigitIndex >= 0, displayDigitIndex < currentDigits.count else { return "" }
        return "\(currentDigits[displayDigitIndex])"
    }

    var durationSeconds: Int {
        Int(Date.now.timeIntervalSince(startTime))
    }

    // MARK: - Helpers

    private func scheduleTransition(after seconds: TimeInterval, action: @escaping () -> Void) {
        Timer.scheduledTimer(withTimeInterval: seconds, repeats: false) { _ in
            Task { @MainActor in
                action()
            }
        }
    }
}
