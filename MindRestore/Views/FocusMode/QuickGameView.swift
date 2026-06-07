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
    static let eyebrow = "APP BLOCKED"
    static let headline = "SPIN TO TRAIN"
    static let subhead = "beat the pick. unlock the app."
    static let idleStatus = "tap spin"
    static let spinningStatus = "rolling"
    static let footer = "one spin. one game. back in."

    static func landedStatus(for game: TrainingGame?) -> String {
        game?.title ?? "Locked in"
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

    private let reelHeight: CGFloat = 446
    private let tileHeight: CGFloat = 108
    private let tileSpacing: CGFloat = 10

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
            AppColors.focusSlotBackground.ignoresSafeArea()

            VStack(spacing: 14) {
                Spacer(minLength: 14)

                header

                machine
                    .scaleEffect(idlePulse && phase == .idle && !reduceMotion ? 1.010 : 1.0)

                Spacer(minLength: 18)
            }
            .padding(.horizontal, 16)
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

    private var header: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(FocusUnlockSlotCopy.eyebrow)
                .font(.system(size: 11, weight: .black))
                .tracking(1.2)
                .foregroundStyle(.white.opacity(0.48))

            Text(FocusUnlockSlotCopy.headline)
                .font(.system(size: 34, weight: .black))
                .foregroundStyle(.white)
                .lineLimit(1)
                .minimumScaleFactor(0.76)
                .accessibilityAddTraits(.isHeader)

            Text(FocusUnlockSlotCopy.subhead)
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(.white.opacity(0.58))
                .lineLimit(1)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 4)
    }

    private var machine: some View {
        VStack(spacing: 12) {
            reelWindow
            controlDeck
            spinButton
        }
        .padding(10)
        .background(
            RoundedRectangle(cornerRadius: 34, style: .continuous)
                .fill(AppColors.focusSlotSurface)
                .overlay(
                    RoundedRectangle(cornerRadius: 34, style: .continuous)
                        .stroke(.white.opacity(0.12), lineWidth: 1)
                )
                .shadow(color: AppColors.accent.opacity(phase == .spinning ? 0.28 : 0.12), radius: 30, y: 18)
        )
        .animation(.easeInOut(duration: 1.8).repeatForever(autoreverses: true), value: idlePulse)
    }

    private var reelWindow: some View {
        ZStack {
            UnevenRoundedRectangle(
                topLeadingRadius: 28,
                bottomLeadingRadius: 28,
                bottomTrailingRadius: 28,
                topTrailingRadius: 28,
                style: .continuous
            )
                .fill(AppColors.focusSlotReelSurface)
                .overlay(
                    UnevenRoundedRectangle(
                        topLeadingRadius: 28,
                        bottomLeadingRadius: 28,
                        bottomTrailingRadius: 28,
                        topTrailingRadius: 28,
                        style: .continuous
                    )
                        .stroke(.white.opacity(0.18), lineWidth: 1)
                )
                .overlay(reelGlass)

            arcadeRails

            GeometryReader { geometry in
                ZStack(alignment: .top) {
                    VStack(spacing: tileSpacing) {
                        ForEach(Array(reelItems.enumerated()), id: \.offset) { index, game in
                            let distance = rowDistance(for: index)

                            FocusUnlockReelTile(
                                game: game,
                                isSelected: selectedGame?.type == game.type && phase == .landed,
                                isSpinning: phase == .spinning,
                                arcadeIndex: index,
                                distanceFromCenter: distance,
                                spinIntensity: spinIntensity
                            )
                            .frame(height: tileHeight)
                            .zIndex(Double(100 - abs(distance)))
                        }
                    }
                    .frame(width: geometry.size.width, alignment: .top)
                    .offset(y: reelOffset + reelKick)
                    .blur(radius: reduceMotion ? 0 : spinIntensity * 2.4)
                }
            }

            reelEdgeMask

            centerScanner
        }
        .frame(height: reelHeight)
        .clipShape(
            UnevenRoundedRectangle(
                topLeadingRadius: 28,
                bottomLeadingRadius: 28,
                bottomTrailingRadius: 28,
                topTrailingRadius: 28,
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
                    .white.opacity(0.16),
                    .white.opacity(0.04),
                    .clear,
                    .black.opacity(0.10),
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )

            HStack {
                Capsule()
                    .fill(AppColors.accent.opacity(0.62))
                    .frame(width: 5)
                    .blur(radius: 1.4)
                Spacer()
                Capsule()
                    .fill(AppColors.rose.opacity(0.56))
                    .frame(width: 5)
                    .blur(radius: 1.4)
            }
            .padding(.horizontal, 7)
            .padding(.vertical, 18)
        }
    }

    private var arcadeRails: some View {
        HStack {
            railStack(colors: [AppColors.amber, AppColors.rose, AppColors.accent])
            Spacer()
            railStack(colors: [AppColors.accent, AppColors.violet, AppColors.focusSlotSuccess])
        }
        .padding(.horizontal, 9)
        .padding(.vertical, 26)
        .allowsHitTesting(false)
    }

    private func railStack(colors: [Color]) -> some View {
        VStack(spacing: 8) {
            ForEach(0..<9, id: \.self) { index in
                Capsule()
                    .fill(colors[index % colors.count].opacity(index == 4 ? 1 : 0.68))
                    .frame(width: index == 4 ? 6 : 4, height: index == 4 ? 30 : 19)
                    .shadow(color: colors[index % colors.count].opacity(0.48), radius: index == 4 ? 10 : 4)
            }
        }
    }

    private var reelEdgeMask: some View {
        VStack {
            LinearGradient(
                colors: [
                    AppColors.focusSlotReelSurface,
                    AppColors.focusSlotReelSurface.opacity(0.50),
                    AppColors.focusSlotReelSurface.opacity(0),
                ],
                startPoint: .top,
                endPoint: .bottom
            )
            .frame(height: 112)

            Spacer()

            LinearGradient(
                colors: [
                    AppColors.focusSlotReelSurface.opacity(0),
                    AppColors.focusSlotReelSurface.opacity(0.56),
                    AppColors.focusSlotReelSurface,
                ],
                startPoint: .top,
                endPoint: .bottom
            )
            .frame(height: 128)
        }
        .allowsHitTesting(false)
    }

    private var centerScanner: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .fill(AppColors.focusSlotSuccess.opacity(phase == .landed ? 0.13 : 0.075))
                .frame(height: tileHeight + 18)
                .padding(.horizontal, 2)

            Rectangle()
                .fill(
                    LinearGradient(
                        colors: [
                            .clear,
                            AppColors.focusSlotSuccess.opacity(phase == .landed ? 0.70 : 0.32),
                            .clear,
                        ],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                )
                .frame(height: 3)
                .shadow(color: AppColors.focusSlotSuccess.opacity(phase == .landed ? 0.55 : 0.22), radius: 10)

            HStack {
                scannerBracket
                Spacer()
                scannerBracket
                    .scaleEffect(x: -1, y: 1)
            }
            .padding(.horizontal, 3)
        }
        .frame(height: tileHeight + 18)
    }

    private var scannerBracket: some View {
        VStack(spacing: 0) {
            Rectangle()
                .frame(width: 22, height: 3)
            Rectangle()
                .frame(width: 3, height: tileHeight + 12)
            Rectangle()
                .frame(width: 22, height: 3)
        }
        .foregroundStyle(AppColors.focusSlotSuccess.opacity(phase == .landed ? 0.95 : 0.58))
        .shadow(color: AppColors.focusSlotSuccess.opacity(phase == .landed ? 0.42 : 0.16), radius: 8)
    }

    private var controlDeck: some View {
        HStack(spacing: 10) {
            ForEach(0..<3, id: \.self) { index in
                Circle()
                    .fill(controlLightColor(index: index))
                    .frame(width: index == 1 ? 9 : 7, height: index == 1 ? 9 : 7)
                    .shadow(color: controlLightColor(index: index).opacity(0.42), radius: phase == .idle ? 4 : 8)
                    .opacity(phase == .spinning && index == 1 ? 1 : 0.74)
            }

            Text(statusText)
                .font(.system(size: phase == .landed ? 15 : 12, weight: .bold))
                .foregroundStyle(phase == .landed ? AppColors.focusSlotSuccess : .white.opacity(0.50))
                .lineLimit(1)
                .minimumScaleFactor(0.72)
                .contentTransition(.opacity)

            Spacer(minLength: 0)

            RoundedRectangle(cornerRadius: 4, style: .continuous)
                .fill(AppColors.focusSlotSuccess.opacity(phase == .spinning ? 0.45 : 0.18))
                .frame(width: 34, height: 3)
                .overlay(alignment: .trailing) {
                    Circle()
                        .fill(AppColors.focusSlotSuccess.opacity(phase == .spinning ? 0.95 : 0.36))
                        .frame(width: 6, height: 6)
                }
        }
        .frame(height: 24)
        .padding(.horizontal, 14)
        .animation(.easeInOut(duration: 0.22), value: statusText)
    }

    private func controlLightColor(index: Int) -> Color {
        if phase == .landed {
            return AppColors.focusSlotSuccess
        }

        let colors = [AppColors.rose, AppColors.accent, AppColors.amber]
        return colors[index % colors.count]
    }

    private var spinButton: some View {
        Button {
            spin()
        } label: {
            HStack(spacing: 10) {
                Image(systemName: "arrow.triangle.2.circlepath")
                    .font(.system(size: 17, weight: .black))
                Text(phase == .spinning ? "SPINNING" : "SPIN")
                    .font(.system(size: 19, weight: .black))
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 18)
            .foregroundStyle(.white)
            .background(AppColors.accent, in: RoundedRectangle(cornerRadius: 22, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 22, style: .continuous)
                    .fill(
                        LinearGradient(
                            colors: [.white.opacity(0.18), .clear],
                            startPoint: .top,
                            endPoint: .center
                        )
                )
            )
            .overlay(
                RoundedRectangle(cornerRadius: 22, style: .continuous)
                    .stroke(.white.opacity(0.22), lineWidth: 1)
            )
            .shadow(color: AppColors.accent.opacity(0.42), radius: 18, y: 10)
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
    let isSpinning: Bool
    let arcadeIndex: Int
    let distanceFromCenter: CGFloat
    let spinIntensity: CGFloat

    private var arcadeAccent: Color {
        let colors = [
            AppColors.teal,
            AppColors.rose,
            AppColors.violet,
            AppColors.amber,
            AppColors.sky,
            AppColors.coral,
        ]
        return colors[arcadeIndex % colors.count]
    }

    private var normalizedDistance: CGFloat {
        min(abs(distanceFromCenter), 2.4)
    }

    private var depthScale: CGFloat {
        max(0.74, 1 - normalizedDistance * 0.105)
    }

    private var depthOpacity: Double {
        max(0.30, 1 - Double(normalizedDistance) * 0.24)
    }

    private var depthBlur: CGFloat {
        min(3.2, normalizedDistance * 0.40 + spinIntensity * 1.2)
    }

    private var depthRotation: Double {
        Double(distanceFromCenter) * -6
    }

    var body: some View {
        HStack(spacing: 13) {
            TrainingTileMiniPreview(type: game.type, color: game.color)
                .frame(width: 112, height: 82)
                .background(game.color.opacity(0.14), in: RoundedRectangle(cornerRadius: 18, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .stroke(game.color.opacity(0.34), lineWidth: 1)
                )

            VStack(alignment: .leading, spacing: 10) {
                Text(game.title)
                    .font(.system(size: 21, weight: .black))
                    .foregroundStyle(.white)
                    .lineLimit(1)
                    .minimumScaleFactor(0.72)

                Image(systemName: game.icon)
                    .font(.system(size: 12, weight: .black))
                    .foregroundStyle(arcadeAccent)
                    .frame(width: 22, height: 18, alignment: .leading)
            }

            Spacer(minLength: 0)
        }
        .padding(.horizontal, 12)
        .frame(maxWidth: .infinity)
        .background(
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .fill(AppColors.focusSlotTileSurface.opacity(isSelected ? 1.0 : 0.92))
                .overlay(
                    LinearGradient(
                        colors: [
                            arcadeAccent.opacity(isSelected ? 0.34 : 0.22),
                            .white.opacity(0.06),
                            .clear,
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
        )
        .overlay(
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .stroke(isSelected ? AppColors.focusSlotSuccess : arcadeAccent.opacity(0.32), lineWidth: isSelected ? 2 : 1)
        )
        .overlay(alignment: .leading) {
            Capsule()
                .fill(arcadeAccent)
                .frame(width: 4)
                .padding(.vertical, 12)
                .opacity(isSelected ? 1 : 0.75)
        }
        .scaleEffect(isSelected ? 1.04 : depthScale)
        .opacity(isSelected ? 1 : depthOpacity)
        .blur(radius: isSelected ? 0 : depthBlur)
        .rotation3DEffect(.degrees(depthRotation), axis: (x: 1, y: 0, z: 0), perspective: 0.64)
        .shadow(color: isSelected ? AppColors.focusSlotSuccess.opacity(0.42) : arcadeAccent.opacity(0.12), radius: isSelected ? 18 : 8, y: isSelected ? 8 : 3)
        .padding(.horizontal, isSelected ? 7 : 14)
        .animation(.spring(response: 0.32, dampingFraction: 0.58), value: isSelected)
    }
}

#Preview("Focus Unlock Slot") {
    FocusUnlockSlotView(games: TrainingGameCatalog.focusUnlockGames) { _ in }
}
