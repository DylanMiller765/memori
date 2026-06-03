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
    case digitInstructions
    case digitShow
    case digitInput
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

    // Number Memory (digit span)
    // Three rounds, ramping length: 4 → 5 → 6 digits.
    // Wires real data into the digitScore field that was previously hardcoded
    // to 50.0 in createResult() — completes the Brain Score formula's three-way split.
    var digitRound: Int = 0
    var digitCurrentSequence: [Int] = []
    var digitDisplayIndex: Int = -1
    var digitUserInput: String = ""
    var digitCorrectRounds: Int = 0
    private var digitTimer: Timer?
    private let digitSequenceLengths: [Int] = [5, 6, 7]

    let totalReactionRounds = 3
    let totalVisualRounds = 3
    let totalDigitRounds = 3

    var digitCurrentLength: Int {
        guard digitRound < digitSequenceLengths.count else { return digitSequenceLengths.last ?? 4 }
        return digitSequenceLengths[digitRound]
    }

    var digitCurrentDisplayDigit: String {
        guard digitDisplayIndex >= 0, digitDisplayIndex < digitCurrentSequence.count else { return "" }
        return "\(digitCurrentSequence[digitDisplayIndex])"
    }

    var digitIsShowing: Bool {
        digitDisplayIndex >= 0 && digitDisplayIndex < digitCurrentSequence.count
    }

    // MARK: - Reaction Time

    func startReaction() {
        reactionRound = 0
        reactionTimes = []
        nextReactionRound()
    }

    private func nextReactionRound() {
        phase = .reactionWait
        let delay = Double.random(in: 1.0...3.0)
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

        // Auto-advance after 0.8 seconds
        autoAdvanceTimer?.invalidate()
        autoAdvanceTimer = Timer.scheduledTimer(withTimeInterval: 0.8, repeats: false) { [weak self] _ in
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
        let count = 5 + (visualRound * 2) // Round 0 = 5 cells, Round 1 = 7, Round 2 = 9
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
        phase = .digitInstructions
    }

    // MARK: - Number Memory (digit span)

    func startDigit() {
        digitRound = 0
        digitCorrectRounds = 0
        nextDigitRound()
    }

    private func nextDigitRound() {
        let length = digitCurrentLength
        digitCurrentSequence = (0..<length).map { _ in Int.random(in: 0...9) }
        digitDisplayIndex = -1
        digitUserInput = ""
        phase = .digitShow
        showNextDigit()
    }

    private func showNextDigit() {
        digitTimer?.invalidate()
        digitDisplayIndex += 1

        if digitDisplayIndex >= digitCurrentSequence.count {
            digitTimer = Timer.scheduledTimer(withTimeInterval: 0.4, repeats: false) { [weak self] _ in
                Task { @MainActor in
                    self?.digitDisplayIndex = -1
                    self?.phase = .digitInput
                }
            }
            return
        }

        // 0.7s feels right — long enough to read, short enough to keep momentum
        let interval: TimeInterval = 0.7
        digitTimer = Timer.scheduledTimer(withTimeInterval: interval, repeats: false) { [weak self] _ in
            Task { @MainActor in
                self?.showNextDigit()
            }
        }
    }

    func appendDigit(_ digit: Int) {
        guard digitUserInput.count < digitCurrentSequence.count else { return }
        digitUserInput.append(String(digit))
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
    }

    func deleteDigit() {
        guard !digitUserInput.isEmpty else { return }
        digitUserInput.removeLast()
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
    }

    func submitDigitAnswer() {
        let correct = digitCurrentSequence.map(String.init).joined()
        let isCorrect = digitUserInput == correct

        if isCorrect {
            digitCorrectRounds += 1
            UINotificationFeedbackGenerator().notificationOccurred(.success)
        } else {
            UINotificationFeedbackGenerator().notificationOccurred(.error)
        }
        digitRound += 1

        if digitRound < totalDigitRounds {
            nextDigitRound()
        } else {
            finishDigit()
        }
    }

    private func finishDigit() {
        digitTimer?.invalidate()
        phase = .calculating
        scheduleTransition(after: 1.2) { [weak self] in
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

        // Digit score: correctRounds / totalRounds * 100. Was previously hardcoded
        // to 50.0 — now wired to real Number Memory data.
        let digitScore = Double(digitCorrectRounds) / Double(totalDigitRounds) * 100.0

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
    @Binding var isInFullscreenPhase: Bool
    let onComplete: (BrainScoreResult) -> Void

    @State private var viewModel = QuickAssessmentViewModel()
    @State private var reactionIntroVisible = false
    @State private var reactionBoltPulsing = false

    private var isReactionFullscreen: Bool {
        switch viewModel.phase {
        case .reactionWait, .reactionGo, .reactionTooEarly: return true
        default: return false
        }
    }

    private var shouldShowAssessmentHeader: Bool {
        !isReactionFullscreen && viewModel.phase != .calculating && viewModel.phase != .done
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
            return 0.05 + Double(viewModel.reactionRound) * 0.09
        case .visualInstructions: return 0.34
        case .visualShow, .visualInput:
            return 0.34 + Double(viewModel.visualRound) * 0.09
        case .digitInstructions: return 0.67
        case .digitShow, .digitInput:
            return 0.67 + Double(viewModel.digitRound) * 0.09
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
            case .digitInstructions:
                digitInstructionCard
            case .digitShow:
                digitShowView
            case .digitInput:
                digitInputView
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
            if shouldShowAssessmentHeader {
                VStack(spacing: 4) {
                    HStack(spacing: 16) {
                        assessmentStepLabel("SPD", active: assessmentProgress < 0.34)
                        assessmentStepLabel("VIS", active: assessmentProgress >= 0.34 && assessmentProgress < 0.67)
                        assessmentStepLabel("NUM", active: assessmentProgress >= 0.67 && assessmentProgress < 1.0)
                    }
                    .font(.caption2.weight(.bold))

                    ProgressView(value: assessmentProgress)
                        .tint(AppColors.accent)
                }
                .padding(.horizontal)
                .padding(.bottom, 8)
                .background(phaseBgColor)
                .transition(.identity)
            }
        }
        .transaction { transaction in
            if isReactionFullscreen {
                transaction.animation = nil
            }
        }
        .onAppear {
            isInFullscreenPhase = isReactionFullscreen
        }
        .onChange(of: viewModel.phase) { _, newPhase in
            backgroundColor = phaseBackgroundColor(for: newPhase)
            isInFullscreenPhase = isReactionFullscreen
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
        VStack(spacing: 22) {
            Spacer()

            Text("SPEED TEST")
                .font(.caption.weight(.heavy))
                .tracking(2)
                .foregroundStyle(AppColors.accent)
                .opacity(reactionIntroVisible ? 1 : 0)
                .offset(y: reactionIntroVisible ? 0 : 8)

            ZStack {
                Circle()
                    .fill(AppColors.amber.opacity(0.13))
                    .frame(width: 132, height: 132)
                    .scaleEffect(reactionBoltPulsing ? 1.08 : 0.94)
                    .opacity(reactionBoltPulsing ? 0.35 : 0.85)

                Circle()
                    .stroke(AppColors.amber.opacity(0.24), lineWidth: 2)
                    .frame(width: 104, height: 104)
                    .scaleEffect(reactionBoltPulsing ? 1.04 : 0.98)

                Image(systemName: "bolt.fill")
                    .font(.system(size: 66, weight: .bold))
                    .foregroundStyle(AppColors.amber)
                    .shadow(color: AppColors.amber.opacity(0.45), radius: 18)
                    .scaleEffect(reactionBoltPulsing ? 1.05 : 0.98)
            }
            .opacity(reactionIntroVisible ? 1 : 0)
            .offset(y: reactionIntroVisible ? 0 : 16)

            Text("Reaction Time")
                .font(.title.bold())
                .opacity(reactionIntroVisible ? 1 : 0)
                .offset(y: reactionIntroVisible ? 0 : 10)

            Text("Tap the instant the screen turns green. Memo is checking how fast your attention snaps back.")
                .font(.body)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)
                .opacity(reactionIntroVisible ? 1 : 0)
                .offset(y: reactionIntroVisible ? 0 : 10)

            Spacer()

            Button {
                viewModel.startReaction()
            } label: {
                Text("Start reaction test")
                    .gradientButton()
            }
            .padding(.horizontal, 32)
            .padding(.bottom, 16)
            .opacity(reactionIntroVisible ? 1 : 0)
            .offset(y: reactionIntroVisible ? 0 : 18)
        }
        .transition(.opacity)
        .onAppear {
            withAnimation(.spring(response: 0.55, dampingFraction: 0.82)) {
                reactionIntroVisible = true
            }

            withAnimation(.easeInOut(duration: 1.45).repeatForever(autoreverses: true)) {
                reactionBoltPulsing = true
            }
        }
        .onDisappear {
            reactionBoltPulsing = false
        }
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
                Text("Start memory test")
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

    // MARK: - Digit Instructions

    private var digitInstructionCard: some View {
        VStack(spacing: 24) {
            Spacer()

            Image(systemName: "number")
                .font(.system(size: 64, weight: .heavy))
                .foregroundStyle(AppColors.accent)

            Text("Number Memory")
                .font(.title.bold())

            Text("Memorize the digits as they flash, then type them back in order.")
                .font(.body)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)

            Spacer()

            Button {
                viewModel.startDigit()
            } label: {
                Text("Start number test")
                    .gradientButton()
            }
            .padding(.horizontal, 32)
            .padding(.bottom, 16)
        }
        .transition(.opacity)
    }

    // MARK: - Digit Show (digits flash one at a time)

    private var digitShowView: some View {
        VStack(spacing: 24) {
            Spacer()

            Text("Round \(viewModel.digitRound + 1) of \(viewModel.totalDigitRounds)")
                .font(.caption.weight(.medium))
                .foregroundStyle(.secondary)

            Text("Watch carefully")
                .font(.headline)
                .foregroundStyle(.secondary)

            ZStack {
                Text(viewModel.digitCurrentDisplayDigit)
                    .font(.system(size: 144, weight: .heavy, design: .monospaced))
                    .foregroundStyle(AppColors.accent)
                    .id(viewModel.digitDisplayIndex)
                    .transition(.opacity.combined(with: .scale(scale: 0.92)))
            }
            .frame(height: 180)
            .frame(maxWidth: .infinity)
            .animation(.easeOut(duration: 0.16), value: viewModel.digitDisplayIndex)

            // Position pips so user knows how far through the sequence we are
            HStack(spacing: 8) {
                ForEach(0..<viewModel.digitCurrentSequence.count, id: \.self) { i in
                    Circle()
                        .fill(i <= viewModel.digitDisplayIndex ? AppColors.accent : AppColors.cardBorder)
                        .frame(width: 8, height: 8)
                }
            }

            Spacer()
        }
    }

    // MARK: - Digit Input (custom keypad)

    private var digitInputView: some View {
        VStack(spacing: 20) {
            Spacer().frame(height: 8)

            Text("Round \(viewModel.digitRound + 1) of \(viewModel.totalDigitRounds)")
                .font(.caption.weight(.medium))
                .foregroundStyle(.secondary)

            Text("Type the sequence")
                .font(.headline)
                .foregroundStyle(.primary)

            MonoKeypadSlots(
                input: viewModel.digitUserInput,
                length: viewModel.digitCurrentSequence.count
            )
            .padding(.vertical, 8)

            Spacer()

            MonoKeypad(
                input: Binding(
                    get: { viewModel.digitUserInput },
                    set: { viewModel.digitUserInput = $0 }
                ),
                maxLength: viewModel.digitCurrentSequence.count,
                onSubmit: { viewModel.submitDigitAnswer() }
            )
            .padding(.horizontal, 28)
            .padding(.bottom, 12)
        }
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

#if DEBUG
private struct QuickAssessmentPreviewHost: View {
    @State private var backgroundColor: Color = AppColors.pageBg
    @State private var isInFullscreenPhase = false

    var body: some View {
        QuickAssessmentView(
            backgroundColor: $backgroundColor,
            isInFullscreenPhase: $isInFullscreenPhase,
            onComplete: { _ in }
        )
    }
}

#Preview("Quick Assessment") {
    QuickAssessmentPreviewHost()
        .preferredColorScheme(.dark)
}
#endif
