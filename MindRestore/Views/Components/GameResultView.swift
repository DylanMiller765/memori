import SwiftUI
import ConfettiSwiftUI

struct GameResultView: View {
    // Required
    let gameTitle: String
    let gameIcon: String
    let accentColor: Color
    let mainScore: Int
    let scoreLabel: String  // e.g. "NUMBERS REMEMBERED", "MILLISECONDS", "% ACCURACY"
    let ratingText: String  // e.g. "Good Job!", "Lightning Fast!"
    let stats: [(label: String, value: String)]

    // Optional
    var isNewPersonalBest: Bool = false
    var personalBest: Int = 0
    var exerciseType: ExerciseType? = nil
    var leaderboardScore: Int = 0
    var confettiColors: [Color] = [.blue, .white, .yellow, .purple, .pink]
    var emoji: String? = nil  // Use emoji instead of SF Symbol icon
    var subtitleText: String? = nil  // e.g. "You beat the chimp!"

    // Callbacks
    var onPlayAgain: () -> Void
    var onDone: () -> Void

    // Animation state
    @State private var displayedScore: Int = 0
    @State private var phase: RevealPhase = .initial
    @State private var confettiCounter = 0
    @State private var statsVisible = false

    private enum RevealPhase {
        case initial, counting, ratingVisible, complete
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                Spacer().frame(height: 20)

                // Hero Score Zone
                heroSection

                // Personal Best Banner
                if isNewPersonalBest {
                    personalBestBanner
                }

                // Stats Card
                statsCard

                // Leaderboard
                if let type = exerciseType {
                    LeaderboardRankCard(
                        exerciseType: type,
                        userScore: leaderboardScore
                    )
                    .padding(.horizontal)
                    .opacity(phase == .complete ? 1 : 0)
                    .offset(y: phase == .complete ? 0 : 20)
                    .animation(.spring(response: 0.5, dampingFraction: 0.8).delay(0.2), value: phase)
                }

                // CTAs
                ctaButtons
            }
            .padding(.bottom, 32)
        }
        .background(resultsBackground)
        .confettiCannon(counter: $confettiCounter, num: 60, colors: confettiColors, rainHeight: 600, radius: 400)
        .onAppear { startRevealSequence() }
    }

    // MARK: - Hero Section

    private var heroSection: some View {
        VStack(spacing: 12) {
            // Game icon or emoji
            Group {
                if let emoji {
                    Text(emoji)
                        .font(.system(size: 56))
                } else {
                    Image(systemName: gameIcon)
                        .font(.system(size: 36, weight: .bold))
                        .foregroundStyle(accentColor)
                        .frame(width: 72, height: 72)
                        .background(accentColor.opacity(0.12), in: RoundedRectangle(cornerRadius: 20))
                }
            }
            .opacity(phase != .initial ? 1 : 0)
            .scaleEffect(phase != .initial ? 1 : 0.5)
            .animation(.spring(response: 0.4, dampingFraction: 0.6), value: phase)

            // Subtitle (e.g. "You beat the chimp!")
            if let subtitleText {
                Text(subtitleText)
                    .font(.title3.weight(.bold))
                    .opacity(phase != .initial ? 1 : 0)
                    .animation(.easeOut(duration: 0.4).delay(0.1), value: phase)
            }

            // Main score - counts up
            Text("\(displayedScore)")
                .font(.system(size: 72, weight: .bold, design: .rounded))
                .foregroundStyle(.white)
                .contentTransition(.numericText())

            // Score label
            Text(scoreLabel)
                .font(.system(size: 12, weight: .heavy))
                .tracking(3)
                .foregroundStyle(.secondary)
                .opacity(phase != .initial ? 1 : 0)
                .animation(.easeOut(duration: 0.3).delay(0.3), value: phase)

            // Rating badge
            if phase == .ratingVisible || phase == .complete {
                Text(ratingText)
                    .font(.system(size: 16, weight: .bold, design: .rounded))
                    .foregroundStyle(accentColor)
                    .padding(.horizontal, 20)
                    .padding(.vertical, 8)
                    .background(accentColor.opacity(0.12), in: Capsule())
                    .transition(.scale.combined(with: .opacity))
            }
        }
    }

    // MARK: - Personal Best Banner

    private var personalBestBanner: some View {
        HStack(spacing: 8) {
            Image(systemName: "trophy.fill")
                .foregroundStyle(AppColors.amber)
            Text("New Personal Best!")
                .font(.subheadline.weight(.bold))
                .foregroundStyle(AppColors.amber)
        }
        .padding(.vertical, 12)
        .padding(.horizontal, 24)
        .background(AppColors.amber.opacity(0.12), in: Capsule())
        .transition(.scale(scale: 0.8).combined(with: .opacity))
        .animation(.spring(response: 0.4, dampingFraction: 0.6), value: isNewPersonalBest)
    }

    // MARK: - Stats Card

    private var statsCard: some View {
        VStack(spacing: 0) {
            ForEach(Array(stats.enumerated()), id: \.offset) { index, stat in
                HStack {
                    Text(stat.label)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                    Spacer()
                    Text(stat.value)
                        .font(.subheadline.weight(.semibold))
                }
                .padding(.vertical, 10)
                .padding(.horizontal, 16)
                .opacity(statsVisible ? 1 : 0)
                .offset(y: statsVisible ? 0 : 15)
                .animation(
                    .spring(response: 0.4, dampingFraction: 0.8)
                    .delay(Double(index) * 0.1),
                    value: statsVisible
                )

                if index < stats.count - 1 {
                    Divider().padding(.horizontal, 16)
                }
            }

            // Personal best comparison (when not a PB)
            if !isNewPersonalBest && personalBest > 0 {
                Divider().padding(.horizontal, 16)
                HStack {
                    Text("Personal Best")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                    Spacer()
                    Text("\(personalBest)")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(accentColor)
                }
                .padding(.vertical, 10)
                .padding(.horizontal, 16)
                .opacity(statsVisible ? 1 : 0)
                .animation(.easeOut.delay(Double(stats.count) * 0.1), value: statsVisible)
            }
        }
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 16))
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(accentColor.opacity(0.15), lineWidth: 1)
        )
        .padding(.horizontal, 20)
    }

    // MARK: - CTAs

    private var ctaButtons: some View {
        VStack(spacing: 12) {
            Button(action: onPlayAgain) {
                Text("Play Again")
                    .accentButton()
            }

            Button(action: onDone) {
                Text("Done")
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.horizontal, 24)
        .opacity(phase == .complete ? 1 : 0)
        .offset(y: phase == .complete ? 0 : 20)
        .animation(.spring(response: 0.5, dampingFraction: 0.8).delay(0.3), value: phase)
    }

    // MARK: - Background

    private var resultsBackground: some View {
        ZStack {
            AppColors.pageBg.ignoresSafeArea()

            // Radial glow behind score
            RadialGradient(
                colors: [accentColor.opacity(0.12), .clear],
                center: .init(x: 0.5, y: 0.25),
                startRadius: 0,
                endRadius: 250
            )
            .ignoresSafeArea()
            .opacity(phase != .initial ? 1 : 0)
            .animation(.easeOut(duration: 0.8), value: phase)
        }
    }

    // MARK: - Reveal Sequence

    private func startRevealSequence() {
        // 0.1s - Start counting + show icon
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            withAnimation { phase = .counting }
            animateScore()
        }

        // 0.7s - Show rating
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.7) {
            withAnimation(.spring(response: 0.4, dampingFraction: 0.6)) {
                phase = .ratingVisible
            }
            HapticService.correct()
        }

        // 0.85s - Show stats + PB + confetti
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.85) {
            statsVisible = true
            if isNewPersonalBest {
                confettiCounter += 1
                HapticService.complete()
            }
        }

        // 1.1s - Show CTAs + leaderboard
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.1) {
            withAnimation { phase = .complete }
        }
    }

    private func animateScore() {
        let duration = 0.5
        let steps = min(mainScore, 60)
        guard steps > 0 else {
            displayedScore = mainScore
            return
        }
        let stepDuration = duration / Double(steps)

        for i in 1...steps {
            DispatchQueue.main.asyncAfter(deadline: .now() + stepDuration * Double(i)) {
                withAnimation(.easeOut(duration: 0.05)) {
                    displayedScore = Int(Double(mainScore) * Double(i) / Double(steps))
                }
                // Subtle tick haptic every 5 steps
                if i % 5 == 0 {
                    UIImpactFeedbackGenerator(style: .light).impactOccurred(intensity: 0.2)
                }
            }
        }
        // Ensure exact final value
        DispatchQueue.main.asyncAfter(deadline: .now() + duration + 0.05) {
            withAnimation { displayedScore = mainScore }
        }
    }
}
