import SwiftUI
import UIKit

// MARK: - Quick Assessment Phase

enum QuickAssessmentPhase: Equatable {
    case reactionInstructions
    case reactionWait
    case reactionGo
    case reactionTooEarly
    case reactionResult
    case visualInstructions
    case visualShow
    case visualInput
    case calculating
    case done
}

// MARK: - Quick Assessment ViewModel

@MainActor @Observable
final class QuickAssessmentViewModel {
    var phase: QuickAssessmentPhase = .reactionInstructions

    // Reaction Time
    var reactionRound: Int = 0
    var reactionTimes: [Int] = []
    var reactionStartTime: Date?
    var lastReactionMs: Int = 0
    private var reactionTimer: Timer?

    // Visual Memory (3x3 grid)
    let gridSize: Int = 4
    var highlightedCells: Set<Int> = []
    var selectedCells: Set<Int> = []
    var visualRound: Int = 0
    var visualCorrectRounds: Int = 0
    private var visualTimer: Timer?

    let totalReactionRounds = 3
    let totalVisualRounds = 3

    // MARK: - Reaction Time

    func startReaction() {
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

    private var autoAdvanceTimer: Timer?

    func tapReaction() {
        if phase == .reactionWait {
            reactionTimer?.invalidate()
            phase = .reactionTooEarly
            UINotificationFeedbackGenerator().notificationOccurred(.error)
            return
        }

        guard phase == .reactionGo, let start = reactionStartTime else { return }
        let ms = Int(Date.now.timeIntervalSince(start) * 1000)
        lastReactionMs = ms
        reactionTimes.append(ms)
        reactionRound += 1
        phase = .reactionResult

        // Auto-advance after 1.5 seconds
        autoAdvanceTimer?.invalidate()
        autoAdvanceTimer = Timer.scheduledTimer(withTimeInterval: 1.5, repeats: false) { [weak self] _ in
            Task { @MainActor in
                guard self?.phase == .reactionResult else { return }
                self?.tapReactionResult()
            }
        }
    }

    func tapReactionResult() {
        autoAdvanceTimer?.invalidate()
        autoAdvanceTimer = nil
        if reactionRound < totalReactionRounds {
            nextReactionRound()
        } else {
            finishReaction()
        }
    }

    func retryAfterTooEarly() {
        nextReactionRound()
    }

    private func finishReaction() {
        reactionTimer?.invalidate()
        phase = .visualInstructions
    }

    // MARK: - Visual Memory

    func startVisual() {
        visualRound = 0
        visualCorrectRounds = 0
        nextVisualRound()
    }

    private func nextVisualRound() {
        let count = 4 + (visualRound * 2) // Round 0 = 4 cells, Round 1 = 6, Round 2 = 8
        selectedCells = []
        highlightedCells = Set((0..<(gridSize * gridSize)).shuffled().prefix(count))
        phase = .visualShow

        visualTimer?.invalidate()
        visualTimer = Timer.scheduledTimer(withTimeInterval: 1.5, repeats: false) { [weak self] _ in
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
        if selectedCells == highlightedCells {
            visualCorrectRounds += 1
        }
        visualRound += 1

        if visualRound < totalVisualRounds {
            nextVisualRound()
        } else {
            finishVisual()
        }
    }

    private func finishVisual() {
        visualTimer?.invalidate()
        phase = .calculating
        scheduleTransition(after: 2.0) { [weak self] in
            self?.phase = .done
        }
    }

    // MARK: - Result Calculation

    func createResult() -> BrainScoreResult {
        let avgMs = reactionTimes.isEmpty ? 500 : reactionTimes.reduce(0, +) / reactionTimes.count

        // Reaction score: max(0, min(100, (500 - avgMs) / 4.0))
        let reactionScore = max(0.0, min(100.0, Double(500 - avgMs) / 4.0))

        // Visual score: correctRounds / totalRounds * 100
        let visualScore = Double(visualCorrectRounds) / Double(totalVisualRounds) * 100.0

        // Digit defaults to 50.0 (median, not tested)
        let digitScore = 50.0

        let brainScore = BrainScoring.compositeBrainScore(digit: digitScore, reaction: reactionScore, visual: visualScore)
        let brainAge = BrainScoring.brainAge(from: brainScore)
        let brainType = BrainScoring.determineBrainType(digit: digitScore, reaction: reactionScore, visual: visualScore)
        let percentile = BrainScoring.percentile(score: brainScore)

        let result = BrainScoreResult()
        result.brainScore = brainScore
        result.brainAge = brainAge
        result.brainType = brainType
        result.reactionTimeScore = reactionScore
        result.visualMemoryScore = visualScore
        result.digitSpanScore = digitScore
        result.reactionTimeAvgMs = avgMs
        result.visualMemoryMax = visualCorrectRounds
        result.percentile = percentile
        result.sourceRaw = "onboarding"
        return result
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

// MARK: - Quick Assessment View

struct QuickAssessmentView: View {
    @Binding var backgroundColor: Color
    let onComplete: (BrainScoreResult) -> Void

    @State private var viewModel = QuickAssessmentViewModel()

    private var isReactionFullscreen: Bool {
        switch viewModel.phase {
        case .reactionWait, .reactionGo, .reactionTooEarly: return true
        default: return false
        }
    }

    private var phaseBgColor: Color {
        switch viewModel.phase {
        case .reactionWait: return AppColors.reactionWait
        case .reactionGo: return AppColors.reactionGo
        case .reactionTooEarly: return AppColors.reactionTooEarly
        default: return AppColors.pageBg
        }
    }

    private var assessmentProgress: Double {
        switch viewModel.phase {
        case .reactionInstructions: return 0
        case .reactionWait, .reactionGo, .reactionTooEarly, .reactionResult:
            return 0.1 + Double(viewModel.reactionRound) * 0.13
        case .visualInstructions: return 0.5
        case .visualShow, .visualInput:
            return 0.55 + Double(viewModel.visualRound) * 0.13
        case .calculating, .done: return 1.0
        }
    }

    var body: some View {
        ZStack {
            phaseBgColor.ignoresSafeArea()

            switch viewModel.phase {
            case .reactionInstructions:
                reactionInstructionCard
            case .reactionWait:
                reactionWaitView
            case .reactionGo:
                reactionGoView
            case .reactionTooEarly:
                reactionTooEarlyView
            case .reactionResult:
                reactionResultView
            case .visualInstructions:
                visualInstructionCard
            case .visualShow:
                visualGridView(interactive: false)
            case .visualInput:
                visualGridView(interactive: true)
            case .calculating:
                calculatingView
            case .done:
                Color.clear
                    .onAppear {
                        let result = viewModel.createResult()
                        onComplete(result)
                    }
            }
        }
        .safeAreaInset(edge: .top) {
            if !isReactionFullscreen && viewModel.phase != .calculating && viewModel.phase != .done {
                VStack(spacing: 4) {
                    HStack(spacing: 16) {
                        assessmentStepLabel("SPD", active: assessmentProgress < 0.5)
                        assessmentStepLabel("VIS", active: assessmentProgress >= 0.5 && assessmentProgress < 1.0)
                    }
                    .font(.caption2.weight(.bold))

                    ProgressView(value: assessmentProgress)
                        .tint(AppColors.accent)
                }
                .padding(.horizontal)
                .padding(.bottom, 8)
                .background(phaseBgColor)
            }
        }
        .animation(.easeInOut(duration: 0.3), value: viewModel.phase)
        .onChange(of: viewModel.phase) { _, newPhase in
            backgroundColor = phaseBackgroundColor(for: newPhase)
        }
    }

    private func phaseBackgroundColor(for phase: QuickAssessmentPhase) -> Color {
        switch phase {
        case .reactionWait: return AppColors.reactionWait
        case .reactionGo: return AppColors.reactionGo
        case .reactionTooEarly: return AppColors.reactionTooEarly
        default: return AppColors.pageBg
        }
    }

    private func assessmentStepLabel(_ text: String, active: Bool) -> some View {
        Text(text)
            .foregroundStyle(active ? AppColors.accent : .secondary)
            .frame(maxWidth: .infinity)
    }

    // MARK: - Reaction Instructions

    private var reactionInstructionCard: some View {
        VStack(spacing: 24) {
            Spacer()

            Image(systemName: "bolt.fill")
                .font(.system(size: 64))
                .foregroundStyle(.yellow)

            Text("Reaction Time")
                .font(.title.bold())

            Text("Tap as fast as you can when the screen turns green")
                .font(.body)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)

            Spacer()

            Button {
                viewModel.startReaction()
            } label: {
                Text("Start")
                    .gradientButton()
            }
            .padding(.horizontal, 32)
            .padding(.bottom, 16)
        }
        .transition(.opacity)
    }

    // MARK: - Reaction Wait

    private var reactionWaitView: some View {
        AppColors.reactionWait
            .ignoresSafeArea()
            .overlay(
                VStack(spacing: 24) {
                    Text("Round \(viewModel.reactionRound + 1) of \(viewModel.totalReactionRounds)")
                        .font(.caption.weight(.medium))
                        .foregroundStyle(.white.opacity(0.5))
                    Text("Wait for green...")
                        .font(.title.weight(.bold))
                        .foregroundStyle(.white)
                }
            )
            .onTapGesture { viewModel.tapReaction() }
    }

    // MARK: - Reaction Go

    private var reactionGoView: some View {
        AppColors.reactionGo
            .ignoresSafeArea()
            .overlay(
                VStack(spacing: 16) {
                    Text("TAP!")
                        .font(.system(size: 64, weight: .bold))
                        .foregroundStyle(.white)
                    Text("Round \(viewModel.reactionRound + 1) of \(viewModel.totalReactionRounds)")
                        .font(.caption.weight(.medium))
                        .foregroundStyle(.white.opacity(0.5))
                }
            )
            .onTapGesture { viewModel.tapReaction() }
    }

    // MARK: - Reaction Too Early

    private var reactionTooEarlyView: some View {
        AppColors.reactionTooEarly
            .ignoresSafeArea()
            .overlay(
                VStack(spacing: 16) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .font(.system(size: 48))
                        .foregroundStyle(.white)
                    Text("Too early!")
                        .font(.title.bold())
                        .foregroundStyle(.white)
                    Text("Wait for green")
                        .font(.subheadline)
                        .foregroundStyle(.white.opacity(0.8))
                }
            )
            .onTapGesture { viewModel.retryAfterTooEarly() }
    }

    // MARK: - Reaction Result

    private var reactionResultView: some View {
        VStack(spacing: 16) {
            Spacer()

            Text("\(viewModel.lastReactionMs)")
                .font(.system(size: 72, weight: .bold, design: .rounded))
                .foregroundStyle(reactionMsColor)
                .contentTransition(.numericText(value: Double(viewModel.lastReactionMs)))

            Text("ms")
                .font(.title2.weight(.bold))
                .foregroundStyle(reactionMsColor.opacity(0.7))

            Text(reactionMsLabel)
                .font(.headline)
                .foregroundStyle(.secondary)
                .padding(.top, 4)

            Text("Round \(viewModel.reactionRound) of \(viewModel.totalReactionRounds)")
                .font(.caption)
                .foregroundStyle(.secondary)
                .padding(.top, 8)

            Spacer()
        }
        .contentShape(Rectangle())
        .onTapGesture { viewModel.tapReactionResult() }
    }

    private var reactionMsColor: Color {
        let ms = viewModel.lastReactionMs
        if ms < 200 { return .green }
        if ms < 300 { return AppColors.accent }
        if ms < 400 { return .yellow }
        return AppColors.coral
    }

    private var reactionMsLabel: String {
        let ms = viewModel.lastReactionMs
        if ms < 150 { return "Insane!" }
        if ms < 200 { return "Lightning fast!" }
        if ms < 250 { return "Great reflexes!" }
        if ms < 300 { return "Nice!" }
        if ms < 400 { return "Good" }
        return "Keep trying!"
    }

    // MARK: - Visual Instructions

    private var visualInstructionCard: some View {
        VStack(spacing: 24) {
            Spacer()

            Image(systemName: "square.grid.4x3.fill")
                .font(.system(size: 64))
                .foregroundStyle(.purple)

            Text("Visual Memory")
                .font(.title.bold())

            Text("Remember which squares light up")
                .font(.body)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)

            Spacer()

            Button {
                viewModel.startVisual()
            } label: {
                Text("Start")
                    .gradientButton()
            }
            .padding(.horizontal, 32)
            .padding(.bottom, 16)
        }
        .transition(.opacity)
    }

    // MARK: - Visual Grid

    private func visualGridView(interactive: Bool) -> some View {
        VStack(spacing: 24) {
            Spacer()

            Text(interactive ? "Tap the squares that were highlighted" : "Remember this pattern")
                .font(.headline)

            Text(interactive ? "Select \(viewModel.highlightedCells.count) squares" : "Round \(viewModel.visualRound + 1) \u{00B7} \(viewModel.highlightedCells.count) squares")
                .font(.subheadline)
                .foregroundStyle(.secondary)

            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 8), count: viewModel.gridSize), spacing: 8) {
                ForEach(0..<(viewModel.gridSize * viewModel.gridSize), id: \.self) { index in
                    let isHighlighted = viewModel.highlightedCells.contains(index)
                    let isSelected = viewModel.selectedCells.contains(index)

                    RoundedRectangle(cornerRadius: 10)
                        .fill(cellColor(isHighlighted: isHighlighted, isSelected: isSelected, interactive: interactive))
                        .aspectRatio(1, contentMode: .fit)
                        .onTapGesture {
                            if interactive {
                                viewModel.toggleCell(index)
                            }
                        }
                        .animation(.easeInOut(duration: 0.15), value: isSelected)
                }
            }
            .padding(.horizontal, 32)

            Spacer()

            Button {
                viewModel.submitVisualAnswer()
            } label: {
                Text("Submit")
                    .gradientButton()
            }
            .padding(.horizontal, 32)
            .disabled(!interactive || viewModel.selectedCells.count != viewModel.highlightedCells.count)
            .opacity(interactive && viewModel.selectedCells.count == viewModel.highlightedCells.count ? 1 : interactive ? 0.4 : 0)
        }
        .padding(.bottom, 16)
    }

    private func cellColor(isHighlighted: Bool, isSelected: Bool, interactive: Bool) -> Color {
        if !interactive && isHighlighted {
            return AppColors.accent
        }
        if interactive && isSelected {
            return AppColors.accent
        }
        return Color.gray.opacity(0.12)
    }

    // MARK: - Calculating

    private var calculatingView: some View {
        VStack(spacing: 24) {
            Spacer()

            ProgressView()
                .tint(AppColors.accent)
                .scaleEffect(1.5)

            Text("Calculating your Brain Age...")
                .font(.title3.weight(.semibold))

            Spacer()
        }
    }
}
