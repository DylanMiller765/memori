import SwiftUI
import UIKit

struct TrainingGame: Identifiable {
    let type: ExerciseType
    let title: String
    let icon: String
    let color: Color

    var id: ExerciseType { type }
}

enum TrainingGameCatalog {
    static let memoryGames: [TrainingGame] = [
        TrainingGame(type: .sequentialMemory, title: "Number Memory", icon: "number.circle.fill", color: AppColors.teal),
        TrainingGame(type: .visualMemory, title: "Visual Memory", icon: "square.grid.3x3.fill", color: AppColors.indigo),
        TrainingGame(type: .chunkingTraining, title: "Chunking", icon: "rectangle.split.3x1.fill", color: AppColors.rose),
        TrainingGame(type: .verbalMemory, title: "Verbal Memory", icon: "text.book.closed.fill", color: AppColors.violet),
    ]

    static let speedGames: [TrainingGame] = [
        TrainingGame(type: .reactionTime, title: "Reaction Time", icon: "bolt.fill", color: AppColors.coral),
        TrainingGame(type: .mathSpeed, title: "Math Speed", icon: "multiply.circle.fill", color: AppColors.amber),
        TrainingGame(type: .speedMatch, title: "Speed Match", icon: "bolt.square.fill", color: AppColors.sky),
        TrainingGame(type: .colorMatch, title: "Color Match", icon: "paintpalette.fill", color: AppColors.violet),
    ]

    static let focusGames: [TrainingGame] = [
        TrainingGame(type: .dualNBack, title: "Dual N-Back", icon: "square.grid.3x3", color: AppColors.sky),
        TrainingGame(type: .chimpTest, title: "Chimp Test", icon: "pawprint.fill", color: AppColors.amber),
    ]

    static let focusUnlockGames: [TrainingGame] = memoryGames + speedGames + focusGames
}

enum FocusUnlockCompletionGate {
    static func shouldGrant(completedGameRawValue: String?, expectedGame: ExerciseType?) -> Bool {
        guard
            let expectedGame,
            let completedGameRawValue,
            let completedGame = ExerciseType(rawValue: completedGameRawValue)
        else {
            return false
        }

        return completedGame == expectedGame
    }
}

enum FocusUnlockSlotCopy {
    static let eyebrow = "BLOCKED APP TRIED IT"
    static let headline = "NO FEED TIL YOU TRAIN"
    static let subhead = "spin for your brain game."
    static let idleStatus = "tap when you're ready"
    static let spinningStatus = "MEMO'S PICKING"
    static let footer = "one spin. one game. back in."

    static func landedStatus(for game: TrainingGame?) -> String {
        guard let title = game?.title.uppercased() else {
            return "LOCKED IN"
        }

        return "\(title). YOU'RE COOKED."
    }
}

struct FocusUnlockSlotView: View {
    let games: [TrainingGame]
    let onGameSelected: (TrainingGame) -> Void

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var phase: SlotPhase = .idle
    @State private var reelItems: [TrainingGame] = []
    @State private var reelOffset: CGFloat = 0
    @State private var selectedGame: TrainingGame?
    @State private var idlePulse = false
    @State private var spinIntensity: CGFloat = 0
    @State private var reelKick: CGFloat = 0
    @State private var launchTask: Task<Void, Never>?

    private let reelHeight: CGFloat = 328
    private let tileHeight: CGFloat = 112
    private let tileSpacing: CGFloat = -4

    private enum SlotPhase {
        case idle
        case spinning
        case landed
    }

    private var rowStride: CGFloat { tileHeight + tileSpacing }
    private var centerOffset: CGFloat { (reelHeight - tileHeight) / 2 }
    private var canSpin: Bool { phase == .idle && !games.isEmpty }
    private var statusText: String {
        switch phase {
        case .idle: FocusUnlockSlotCopy.idleStatus
        case .spinning: FocusUnlockSlotCopy.spinningStatus
        case .landed: FocusUnlockSlotCopy.landedStatus(for: selectedGame)
        }
    }

    var body: some View {
        ZStack {
            slotBackdrop

            GeometryReader { geometry in
                let contentWidth = min(max(geometry.size.width - 64, 286), 336)

                VStack(spacing: 18) {
                    Spacer(minLength: 44)

                    header

                    machine
                        .scaleEffect(idlePulse && phase == .idle && !reduceMotion ? 1.010 : 1.0)

                    Spacer(minLength: 20)
                }
                .padding(.horizontal, 14)
                .frame(width: contentWidth)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .preferredColorScheme(.dark)
        .interactiveDismissDisabled(true)
        .onAppear {
            if reelItems.isEmpty {
                var transaction = Transaction()
                transaction.disablesAnimations = true
                withTransaction(transaction) {
                    setIdleReel()
                }
            }
            DispatchQueue.main.async {
                idlePulse = true
            }
        }
        .onDisappear {
            launchTask?.cancel()
        }
        .accessibilityElement(children: .contain)
    }

    private var slotBackdrop: some View {
        AppColors.focusSlotBackground
            .ignoresSafeArea()
        .accessibilityHidden(true)
    }

    private var header: some View {
        VStack(alignment: .center, spacing: 9) {
            Text(FocusUnlockSlotCopy.eyebrow)
                .font(.system(size: 9.5, weight: .semibold, design: .monospaced))
                .tracking(1.6)
                .foregroundStyle(AppColors.focusSlotSuccess.opacity(0.88))

            Text(FocusUnlockSlotCopy.headline)
                .font(.custom("AvenirNextCondensed-Heavy", size: 34))
                .foregroundStyle(.white)
                .multilineTextAlignment(.center)
                .lineLimit(2)
                .minimumScaleFactor(0.78)
                .accessibilityAddTraits(.isHeader)

            Text(FocusUnlockSlotCopy.subhead)
                .font(.custom("AvenirNext-Medium", size: 13))
                .foregroundStyle(.white.opacity(0.62))
                .lineLimit(1)
        }
        .frame(maxWidth: .infinity, alignment: .center)
    }

    private var machine: some View {
        VStack(spacing: 18) {
            reelWindow
                .overlay(alignment: .bottomLeading) {
                    if phase != .idle {
                        statusLine
                            .padding(.leading, 18)
                            .padding(.bottom, 14)
                    }
                }
                .overlay(alignment: .bottomTrailing) {
                    reelPulseDot
                        .padding(.trailing, 22)
                        .padding(.bottom, 18)
                }

            spinButton
        }
        .padding(.top, 8)
        .rotation3DEffect(.degrees(idlePulse && phase == .idle && !reduceMotion ? -4.5 : -3.0), axis: (x: 1, y: 0, z: 0), perspective: 0.72)
        .animation(.easeInOut(duration: 1.8).repeatForever(autoreverses: true), value: idlePulse)
    }

    private var reelNeonStroke: some View {
        UnevenRoundedRectangle(
            topLeadingRadius: 28,
            bottomLeadingRadius: 28,
            bottomTrailingRadius: 28,
            topTrailingRadius: 28,
            style: .continuous
        )
        .stroke(
            LinearGradient(
                colors: [
                    .white.opacity(phase == .idle ? 0.42 : 0.56),
                    AppColors.accent.opacity(phase == .spinning ? 1.0 : 0.78),
                    AppColors.focusSlotSuccess.opacity(phase == .landed ? 0.92 : 0.42),
                    .white.opacity(0.24),
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            ,
            lineWidth: phase == .spinning ? 4.0 : phase == .landed ? 3.2 : 2.6
        )
    }

    private var reelWindow: some View {
        ZStack {
            UnevenRoundedRectangle(
                topLeadingRadius: 24,
                bottomLeadingRadius: 24,
                bottomTrailingRadius: 24,
                topTrailingRadius: 24,
                style: .continuous
            )
                .fill(
                    LinearGradient(
                        colors: [
                            .black.opacity(0.96),
                            AppColors.focusSlotReelSurface,
                            .black.opacity(0.92),
                        ],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
                .overlay(
                    UnevenRoundedRectangle(
                        topLeadingRadius: 24,
                        bottomLeadingRadius: 24,
                        bottomTrailingRadius: 24,
                        topTrailingRadius: 24,
                        style: .continuous
                    )
                        .stroke(.black.opacity(0.86), lineWidth: 12)
                )
                .overlay(reelNeonStroke)
                .overlay(reelCylinderShading)
                .overlay(reelGlass)
                .shadow(color: .black.opacity(0.95), radius: 30, y: 18)
                .shadow(color: AppColors.accent.opacity(phase == .spinning ? 0.92 : 0.72), radius: phase == .spinning ? 42 : 32)
                .shadow(color: AppColors.focusSlotSuccess.opacity(phase == .landed ? 0.96 : 0.26), radius: phase == .landed ? 58 : 22)

            GeometryReader { geometry in
                ZStack(alignment: .top) {
                    VStack(spacing: tileSpacing) {
                        ForEach(Array(reelItems.enumerated()), id: \.offset) { index, game in
                            let distance = rowDistance(for: index)

                            FocusUnlockReelTile(
                                game: game,
                                isSelected: selectedGame?.type == game.type && phase == .landed,
                                isLanded: phase == .landed,
                                isSpinning: phase == .spinning,
                                distanceFromCenter: distance,
                                spinIntensity: spinIntensity
                            )
                            .frame(height: tileHeight)
                            .padding(.horizontal, 7)
                            .zIndex(Double(100 - abs(distance)))
                        }
                    }
                    .frame(width: geometry.size.width, alignment: .top)
                    .offset(y: reelOffset + reelKick)
                    .blur(radius: reduceMotion ? 0 : spinIntensity * 2.4)
                }
            }

            reelEdgeMask

            winnerPayWindow
        }
        .frame(height: reelHeight)
        .clipShape(
            UnevenRoundedRectangle(
                topLeadingRadius: 24,
                bottomLeadingRadius: 24,
                bottomTrailingRadius: 24,
                topTrailingRadius: 24,
                style: .continuous
            )
        )
        .accessibilityLabel("Brain game picker")
        .accessibilityValue(selectedGame?.title ?? "Ready to spin")
    }

    private var reelGlass: some View {
        ZStack {
            LinearGradient(
                colors: [
                    .white.opacity(0.32),
                    .clear,
                    .black.opacity(0.18),
                    .clear,
                    .white.opacity(0.14),
                ],
                startPoint: .top,
                endPoint: .bottom
            )

            LinearGradient(
                colors: [
                    .clear,
                    .white.opacity(phase == .spinning ? 0.22 : 0.13),
                    .clear,
                ],
                startPoint: .leading,
                endPoint: .trailing
            )
            .frame(height: 52)
            .offset(y: idlePulse && phase == .idle && !reduceMotion ? -88 : -98)
            .animation(.easeInOut(duration: 1.8).repeatForever(autoreverses: true), value: idlePulse)
        }
        .allowsHitTesting(false)
    }

    private var reelCylinderShading: some View {
        VStack(spacing: 0) {
            LinearGradient(
                colors: [
                    .black.opacity(0.82),
                    .black.opacity(0.18),
                    .clear,
                ],
                startPoint: .top,
                endPoint: .bottom
            )
            .frame(height: 92)

            Spacer(minLength: 0)

            LinearGradient(
                colors: [
                    .clear,
                    .black.opacity(0.22),
                    .black.opacity(0.88),
                ],
                startPoint: .top,
                endPoint: .bottom
            )
            .frame(height: 104)
        }
        .overlay {
            HStack {
                LinearGradient(
                    colors: [
                        .white.opacity(0.20),
                        AppColors.accent.opacity(0.22),
                        .clear,
                    ],
                    startPoint: .leading,
                    endPoint: .trailing
                )
                .frame(width: 66)

                Spacer()

                LinearGradient(
                    colors: [
                        .clear,
                        AppColors.accent.opacity(0.18),
                        .white.opacity(0.26),
                    ],
                    startPoint: .leading,
                    endPoint: .trailing
                )
                .frame(width: 66)
            }
        }
        .allowsHitTesting(false)
    }

    private var reelEdgeMask: some View {
        VStack {
            LinearGradient(
                colors: [
                    AppColors.focusSlotReelSurface,
                    AppColors.focusSlotReelSurface.opacity(0.18),
                    AppColors.focusSlotReelSurface.opacity(0),
                ],
                startPoint: .top,
                endPoint: .bottom
            )
            .frame(height: 52)

            Spacer()

            LinearGradient(
                colors: [
                    AppColors.focusSlotReelSurface.opacity(0),
                    AppColors.focusSlotReelSurface.opacity(0.20),
                    AppColors.focusSlotReelSurface,
                ],
                startPoint: .top,
                endPoint: .bottom
            )
            .frame(height: 60)
        }
        .allowsHitTesting(false)
    }

    private var winnerPayWindow: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 30, style: .continuous)
                .fill(
                    RadialGradient(
                        colors: [
                            winnerPayColor.opacity(phase == .landed ? 0.06 : phase == .spinning ? 0.12 : 0.07),
                            AppColors.accent.opacity(phase == .landed ? 0.04 : phase == .spinning ? 0.12 : 0.07),
                            .clear,
                        ],
                        center: .center,
                        startRadius: 18,
                        endRadius: 190
                    )
                )
                .frame(height: tileHeight + 34)
                .padding(.horizontal, -4)

            RoundedRectangle(cornerRadius: 28, style: .continuous)
                .stroke(
                    LinearGradient(
                        colors: [
                            .white.opacity(phase == .landed ? 0.50 : 0.22),
                            winnerPayColor.opacity(phase == .landed ? 1.0 : 0.46),
                            AppColors.accent.opacity(phase == .landed ? 0.84 : 0.50),
                            .white.opacity(phase == .landed ? 0.24 : 0.16),
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    lineWidth: phase == .landed ? 2.8 : 1.4
                )
                .frame(height: tileHeight + 22)
                .padding(.horizontal, 10)
                .shadow(color: winnerPayColor.opacity(phase == .landed ? 0.92 : 0.30), radius: phase == .landed ? 30 : 12)

            HStack {
                jackpotSideRail
                Spacer(minLength: 0)
                jackpotSideRail
                    .scaleEffect(x: -1, y: 1)
            }
            .padding(.horizontal, 11)

            if phase == .landed {
                jackpotBulbs
            }
        }
        .frame(height: tileHeight + 34)
        .allowsHitTesting(false)
    }

    private var winnerPayColor: Color {
        phase == .landed ? AppColors.focusSlotSuccess : AppColors.accent
    }

    private var jackpotSideRail: some View {
        RoundedRectangle(cornerRadius: 6, style: .continuous)
            .fill(
                LinearGradient(
                    colors: [
                        .white.opacity(0.28),
                        winnerPayColor.opacity(phase == .landed ? 0.94 : 0.50),
                        AppColors.accent.opacity(phase == .landed ? 0.72 : 0.38),
                    ],
                    startPoint: .top,
                    endPoint: .bottom
                )
            )
            .frame(width: phase == .landed ? 5 : 3, height: tileHeight + 8)
            .shadow(color: winnerPayColor.opacity(phase == .landed ? 0.88 : 0.38), radius: phase == .landed ? 18 : 9)
    }

    private var jackpotBulbs: some View {
        HStack {
            bulbColumn
            Spacer(minLength: 0)
            bulbColumn
        }
        .padding(.horizontal, 4)
    }

    private var bulbColumn: some View {
        VStack(spacing: 12) {
            ForEach(0..<5, id: \.self) { index in
                Circle()
                    .fill(index.isMultiple(of: 2) ? AppColors.focusSlotSuccess : AppColors.accent)
                    .frame(width: 5, height: 5)
                    .shadow(color: (index.isMultiple(of: 2) ? AppColors.focusSlotSuccess : AppColors.accent).opacity(0.92), radius: 10)
            }
        }
        .frame(height: tileHeight + 18)
    }

    private var statusLine: some View {
        Text(statusText)
            .font(.system(size: phase == .landed ? 12.5 : 10.5, weight: .semibold, design: .monospaced))
            .tracking(phase == .landed ? 0.2 : 0.9)
            .foregroundStyle(phase == .landed ? AppColors.focusSlotSuccess : .white.opacity(0.58))
            .lineLimit(1)
            .minimumScaleFactor(0.72)
            .contentTransition(.opacity)
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(.black.opacity(0.34), in: Capsule())
            .overlay(
                Capsule()
                    .stroke(.white.opacity(0.10), lineWidth: 1)
            )
            .animation(.easeInOut(duration: 0.22), value: statusText)
    }

    private var reelPulseDot: some View {
        Circle()
            .fill(phase == .landed ? AppColors.focusSlotSuccess : AppColors.accent)
            .frame(width: 7, height: 7)
            .shadow(color: (phase == .landed ? AppColors.focusSlotSuccess : AppColors.accent).opacity(0.74), radius: phase == .idle ? 8 : 14)
            .scaleEffect(phase == .spinning ? 1.35 : idlePulse && !reduceMotion ? 1.14 : 1.0)
            .opacity(phase == .idle ? 0.74 : 1.0)
    }

    private var spinButton: some View {
        Button {
            spin()
        } label: {
            HStack(spacing: 10) {
                Image(systemName: "arrow.triangle.2.circlepath")
                    .font(.system(size: 19, weight: .heavy))
                Text(phase == .spinning ? "SPINNING" : "SPIN")
                    .font(.custom("AvenirNext-Heavy", size: 21))
                    .tracking(0.4)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 20)
            .foregroundStyle(.white)
            .background(
                LinearGradient(
                    colors: [
                        .white.opacity(0.32),
                        AppColors.accent,
                        AppColors.accent.opacity(0.94),
                    ],
                    startPoint: .top,
                    endPoint: .bottom
                ),
                in: RoundedRectangle(cornerRadius: 20, style: .continuous)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .fill(
                        LinearGradient(
                            colors: [.white.opacity(0.16), .clear],
                            startPoint: .top,
                            endPoint: .center
                        )
                )
            )
            .overlay(alignment: .bottom) {
                Capsule()
                    .fill(.white.opacity(0.24))
                    .frame(height: 2)
                    .padding(.horizontal, 30)
                    .padding(.bottom, 5)
            }
            .overlay(
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .stroke(.white.opacity(0.48), lineWidth: 1.2)
            )
            .shadow(color: AppColors.accent.opacity(phase == .spinning ? 0.92 : 0.72), radius: phase == .spinning ? 36 : 26, y: 12)
            .shadow(color: AppColors.accent.opacity(0.34), radius: 12, y: 0)
        }
        .disabled(!canSpin)
        .opacity(canSpin ? 1 : 0.62)
        .scaleEffect(phase == .spinning ? 0.965 : 1)
        .buttonStyle(.plain)
        .accessibilityLabel("Spin")
        .accessibilityHint("Chooses a random brain game to unlock the blocked app")
    }

    private func rowDistance(for index: Int) -> CGFloat {
        let tileCenter = reelOffset + reelKick + CGFloat(index) * rowStride + tileHeight / 2
        let viewportCenter = reelHeight / 2
        return (tileCenter - viewportCenter) / rowStride
    }

    private func setIdleReel() {
        reelItems = Array(repeating: games, count: 3).flatMap { $0 }
        let middleIndex = max(games.count, 0)
        reelOffset = centerOffset - CGFloat(middleIndex) * rowStride
    }

    private func spin() {
        guard canSpin, let winner = games.randomElement() else { return }
        Analytics.focusUnlockSpinStarted()
        UIImpactFeedbackGenerator(style: .light).impactOccurred()

        selectedGame = nil
        phase = .spinning

        if reduceMotion {
            reelItems = games
            if let winnerIndex = games.firstIndex(where: { $0.type == winner.type }) {
                withAnimation(.easeOut(duration: 0.5)) {
                    reelOffset = centerOffset - CGFloat(winnerIndex) * rowStride
                }
            }
            land(on: winner, after: 0.5)
            return
        }

        let loops = Int.random(in: 7...10)
        let winnerIndex = games.firstIndex(where: { $0.type == winner.type }) ?? 0
        let spinItems = Array(repeating: games, count: loops).flatMap { $0 } + Array(games.prefix(winnerIndex + 1))
        reelItems = spinItems
        reelOffset = centerOffset
        spinIntensity = 0
        reelKick = 0

        let finalOffset = centerOffset - CGFloat(spinItems.count - 1) * rowStride

        DispatchQueue.main.async {
            runSpinAnimation(finalOffset: finalOffset)
        }

        playTickHaptics()
        land(on: winner, after: 2.55)
    }

    private func runSpinAnimation(finalOffset: CGFloat) {
        withAnimation(.easeOut(duration: 0.12)) {
            reelKick = 18
            spinIntensity = 0.35
        }

        withAnimation(.timingCurve(0.08, 0.02, 0.16, 1.0, duration: 1.55)) {
            reelOffset = finalOffset - 36
            spinIntensity = 1
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + 1.55) {
            withAnimation(.timingCurve(0.15, 0.84, 0.24, 1.0, duration: 0.58)) {
                reelOffset = finalOffset + 13
                reelKick = 0
                spinIntensity = 0.18
            }
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + 2.13) {
            withAnimation(.spring(response: 0.26, dampingFraction: 0.58)) {
                reelOffset = finalOffset
                spinIntensity = 0
            }
        }
    }

    private func playTickHaptics() {
        let tickTimes: [Double] = [1.62, 1.78, 1.92, 2.05, 2.18]
        for tickTime in tickTimes {
            DispatchQueue.main.asyncAfter(deadline: .now() + tickTime) {
                guard phase == .spinning else { return }
                UIImpactFeedbackGenerator(style: .rigid).impactOccurred(intensity: 0.55)
            }
        }
    }

    private func land(on winner: TrainingGame, after delay: Double) {
        launchTask?.cancel()
        launchTask = Task { @MainActor in
            try? await Task.sleep(for: .seconds(delay))
            guard !Task.isCancelled else { return }

            selectedGame = winner
            phase = .landed
            Analytics.focusUnlockSpinLanded(gameType: winner.type.rawValue)
            UINotificationFeedbackGenerator().notificationOccurred(.success)

            try? await Task.sleep(for: .seconds(0.8))
            guard !Task.isCancelled else { return }
            onGameSelected(winner)
        }
    }
}

private struct FocusUnlockReelTile: View {
    let game: TrainingGame
    let isSelected: Bool
    let isLanded: Bool
    let isSpinning: Bool
    let distanceFromCenter: CGFloat
    let spinIntensity: CGFloat

    private var tileAccent: Color {
        game.color
    }

    private var normalizedDistance: CGFloat {
        min(abs(distanceFromCenter), 2.4)
    }

    private var depthScale: CGFloat {
        if isLanded && !isSelected {
            return max(0.66, 1 - normalizedDistance * 0.17)
        }

        return max(0.78, 1 - normalizedDistance * 0.11)
    }

    private var depthOpacity: Double {
        if isLanded && !isSelected {
            return max(0.22, 0.54 - Double(normalizedDistance) * 0.20)
        }

        return max(0.48, 1 - Double(normalizedDistance) * 0.20)
    }

    private var depthBlur: CGFloat {
        if isLanded && !isSelected {
            return min(5.4, normalizedDistance * 0.72 + 1.7)
        }

        return min(3.0, normalizedDistance * 0.34 + spinIntensity * 1.15)
    }

    private var depthRotation: Double {
        Double(distanceFromCenter) * -14
    }

    private var cylinderYOffset: CGFloat {
        let clamped = max(-2.2, min(2.2, distanceFromCenter))
        return CGFloat(sin(Double(clamped) * 0.62)) * 5
    }

    private var cylinderBrightness: Double {
        if isSelected {
            return 0.24
        }

        if isLanded {
            return max(-0.42, -0.12 - Double(normalizedDistance) * 0.14)
        }

        return max(-0.24, 0.08 - Double(normalizedDistance) * 0.14)
    }

    var body: some View {
        HStack(spacing: 13) {
            TrainingTileMiniPreview(type: game.type, color: game.color)
                .frame(width: 104, height: 86)
                .background(game.color.opacity(isSelected ? 0.52 : 0.44), in: RoundedRectangle(cornerRadius: 20, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 20, style: .continuous)
                        .stroke(game.color.opacity(isSelected ? 1.0 : 0.82), lineWidth: isSelected ? 2.0 : 1.3)
                )
                .shadow(color: game.color.opacity(isSelected ? 0.92 : 0.38), radius: isSelected ? 22 : 10)

            VStack(alignment: .leading, spacing: 10) {
                Text(game.title)
                    .font(.custom("AvenirNext-DemiBold", size: 22))
                    .foregroundStyle(.white)
                    .lineLimit(1)
                    .minimumScaleFactor(0.60)

                Image(systemName: game.icon)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(tileAccent)
                    .frame(width: 22, height: 18, alignment: .leading)
            }

            Spacer(minLength: 0)
        }
        .padding(.horizontal, 12)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [
                            .white.opacity(isSelected ? 0.18 : 0.15),
                            AppColors.focusSlotTileSurface.opacity(isSelected ? 1.0 : 0.96),
                            tileAccent.opacity(isSelected ? 0.24 : 0.12),
                            .black.opacity(0.12),
                        ],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
                .overlay(
                    LinearGradient(
                        colors: [
                            tileAccent.opacity(isSelected ? 1.0 : 0.58),
                            .white.opacity(isSelected ? 0.28 : 0.12),
                            .clear,
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
        )
        .overlay(
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .stroke(isSelected ? .white.opacity(0.86) : tileAccent.opacity(0.86), lineWidth: isSelected ? 1.8 : 1.6)
        )
        .overlay {
            if isSelected {
                RoundedRectangle(cornerRadius: 24, style: .continuous)
                    .stroke(
                        LinearGradient(
                            colors: [
                                .white.opacity(0.74),
                                AppColors.focusSlotSuccess,
                                tileAccent.opacity(0.92),
                                .white.opacity(0.34),
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        lineWidth: 2.2
                    )
                    .shadow(color: AppColors.focusSlotSuccess.opacity(0.96), radius: 24)
                    .shadow(color: tileAccent.opacity(0.88), radius: 28)
            }
        }
        .background {
            if isSelected {
                RoundedRectangle(cornerRadius: 28, style: .continuous)
                    .fill(
                        RadialGradient(
                            colors: [
                                AppColors.focusSlotSuccess.opacity(0.22),
                                AppColors.accent.opacity(0.12),
                                tileAccent.opacity(0.18),
                                .clear,
                            ],
                            center: .center,
                            startRadius: 12,
                            endRadius: 250
                        )
                    )
                    .padding(-26)
                    .scaleEffect(isSelected ? 1.15 : 0.92)
                    .opacity(isSelected ? 1 : 0)
            }
        }
        .overlay(alignment: .top) {
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                .fill(.white.opacity(isSelected ? 0.06 : 0.12))
                .frame(height: isSelected ? 10 : 18)
                .padding(.horizontal, isSelected ? 18 : 7)
                .padding(.top, isSelected ? 6 : 4)
        }
        .overlay(alignment: .leading) {
            Capsule()
                .fill(tileAccent)
                .frame(width: isSelected ? 5 : 4)
                .padding(.vertical, 12)
                .opacity(1)
                .shadow(color: tileAccent.opacity(0.74), radius: 8)
        }
        .scaleEffect(isSelected ? 1.095 : depthScale)
        .opacity(isSelected ? 1 : depthOpacity)
        .brightness(cylinderBrightness)
        .blur(radius: isSelected ? 0 : depthBlur)
        .offset(y: isSelected ? cylinderYOffset - 4 : cylinderYOffset)
        .rotation3DEffect(.degrees(depthRotation), axis: (x: 1, y: 0, z: 0), perspective: 0.82)
        .shadow(color: isSelected ? AppColors.focusSlotSuccess.opacity(1.0) : tileAccent.opacity(isLanded ? 0.18 : 0.52), radius: isSelected ? 46 : 14, y: isSelected ? 12 : 3)
        .shadow(color: tileAccent.opacity(isSelected ? 0.88 : isLanded ? 0.10 : 0.22), radius: isSelected ? 24 : 8)
        .padding(.horizontal, isSelected ? 0 : 3)
        .saturation(isLanded && !isSelected ? 0.58 : 1.0)
        .animation(.spring(response: 0.34, dampingFraction: 0.50), value: isSelected)
        .animation(.easeInOut(duration: 0.18), value: isLanded)
    }
}

#Preview("Focus Unlock Slot") {
    FocusUnlockSlotView(games: TrainingGameCatalog.focusUnlockGames) { _ in }
}
