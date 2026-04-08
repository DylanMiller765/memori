import SwiftUI

// MARK: - Brain Type Color Helper

private func brainTypeSwiftColor(_ type: BrainType) -> Color {
    switch type {
    case .lightningReflex: return AppColors.coral
    case .numberCruncher: return AppColors.indigo
    case .patternMaster: return AppColors.violet
    case .balancedBrain: return AppColors.mint
    }
}

// MARK: - Shared Components (Warm Light Design)

/// Adaptive background — warm cream in light mode, deep purple-black in dark mode
private struct CardBackground: View {
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        if colorScheme == .dark {
            LinearGradient(
                colors: [
                    Color(red: 0.08, green: 0.06, blue: 0.14),
                    Color(red: 0.12, green: 0.08, blue: 0.20),
                    Color(red: 0.08, green: 0.06, blue: 0.14)
                ],
                startPoint: .top,
                endPoint: .bottom
            )
        } else {
            LinearGradient(
                colors: [
                    Color(red: 0.969, green: 0.961, blue: 0.941),
                    Color(red: 0.955, green: 0.945, blue: 0.925),
                    Color(red: 0.969, green: 0.961, blue: 0.941)
                ],
                startPoint: .top,
                endPoint: .bottom
            )
        }
    }
}

private struct BrandingHeader: View {
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        HStack(spacing: 6) {
            Image(systemName: "brain.fill")
                .font(.system(size: 12, weight: .bold))
                .foregroundStyle(AppColors.accent)
            Text("MEMORI")
                .font(.system(size: 12, weight: .heavy))
                .tracking(3)
                .foregroundStyle(colorScheme == .dark ? Color.white.opacity(0.6) : Color(red: 0.45, green: 0.43, blue: 0.40))
        }
    }
}

private struct BrandingFooter: View {
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        Text("Test yours free \u{2014} Memori")
            .font(.system(size: 11, weight: .semibold))
            .foregroundStyle(colorScheme == .dark ? Color.white.opacity(0.4) : Color(red: 0.62, green: 0.60, blue: 0.58))
    }
}

/// Pill badge with soft colored background
private struct RatingPill<Content: View>: View {
    let color: Color
    @ViewBuilder var content: () -> Content

    var body: some View {
        content()
            .font(.system(size: 14, weight: .bold))
            .foregroundStyle(color)
            .padding(.horizontal, 20)
            .padding(.vertical, 10)
            .background(
                Capsule()
                    .fill(color.opacity(0.12))
            )
    }
}

// MARK: - Score Bar (Light)

private struct ScoreBar: View {
    let label: String
    let value: Double
    let maxValue: Double
    let color: Color

    private var fraction: CGFloat {
        guard maxValue > 0 else { return 0 }
        return min(CGFloat(value / maxValue), 1.0)
    }

    var body: some View {
        HStack(spacing: 10) {
            Text(label)
                .font(.system(size: 13, weight: .heavy))
                .foregroundStyle(color)
                .frame(width: 36, alignment: .leading)

            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 6)
                        .fill(color.opacity(0.12))

                    RoundedRectangle(cornerRadius: 6)
                        .fill(color)
                        .frame(width: geo.size.width * fraction)
                }
            }
            .frame(height: 14)

            Text(String(format: "%.0f", value))
                .font(.system(size: 13, weight: .bold, design: .monospaced))
                .foregroundStyle(color)
                .frame(width: 30, alignment: .trailing)
        }
    }
}

/// Inner card surface — white on cream in light, subtle dark surface in dark mode
private struct ShareCardSurface<Content: View>: View {
    @Environment(\.colorScheme) private var colorScheme
    @ViewBuilder var content: () -> Content

    var body: some View {
        content()
            .padding(20)
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(colorScheme == .dark ? Color.white.opacity(0.08) : Color.white)
                    .shadow(color: .black.opacity(colorScheme == .dark ? 0.3 : 0.06), radius: 12, y: 4)
            )
    }
}

// MARK: - 1. BrainScoreShareCard

struct TikTokBrainScoreCard: View {
    let brainScore: Int
    let brainAge: Int
    let brainType: BrainType
    let percentile: Int
    let digitScore: Double
    let reactionScore: Double
    let visualScore: Double
    var userAge: Int = 0

    var body: some View {
        ZStack {
            CardBackground()

            VStack(spacing: 0) {
                Spacer().frame(height: 32)
                BrandingHeader()
                Spacer().frame(height: 16)

                Image("mascot-cool")
                    .renderingMode(.original)
                    .resizable()
                    .scaledToFit()
                    .frame(height: 100)

                Spacer().frame(height: 12)

                ShareCardSurface {
                    VStack(spacing: 16) {
                        // Big brain score
                        Text("\(brainScore)")
                            .font(.system(size: 72, weight: .bold, design: .rounded))
                            .foregroundStyle(AppColors.accent)

                        Text("BRAIN SCORE")
                            .font(.system(size: 13, weight: .heavy))
                            .tracking(4)
                            .foregroundStyle(.secondary)

                        // Brain Age
                        Text("Brain Age: \(brainAge)")
                            .font(.system(size: 22, weight: .bold, design: .rounded))
                            .foregroundStyle(.primary)

                        if userAge > 0 {
                            let diff = userAge - brainAge
                            if diff > 0 {
                                Text("(\(diff) yrs younger than actual age!)")
                                    .font(.system(size: 14, weight: .bold))
                                    .foregroundStyle(Color(red: 0.34, green: 0.85, blue: 0.74))
                            } else if diff < 0 {
                                Text("(\(abs(diff)) yrs older than actual age)")
                                    .font(.system(size: 14, weight: .bold))
                                    .foregroundStyle(Color(red: 1, green: 0.45, blue: 0.45))
                            }
                        }

                        // Brain type badge
                        HStack(spacing: 6) {
                            Image(systemName: brainType.icon)
                                .font(.system(size: 14, weight: .bold))
                            Text(brainType.displayName)
                                .font(.system(size: 13, weight: .bold))
                        }
                        .foregroundStyle(brainTypeSwiftColor(brainType))
                        .padding(.horizontal, 14)
                        .padding(.vertical, 6)
                        .background(
                            Capsule().fill(brainTypeSwiftColor(brainType).opacity(0.12))
                        )

                        // Percentile
                        RatingPill(color: AppColors.accent) {
                            HStack(spacing: 6) {
                                Image(systemName: "chart.bar.fill")
                                    .font(.system(size: 12, weight: .bold))
                                Text("Better than \(percentile)% of players")
                            }
                        }

                        // Score breakdown
                        VStack(spacing: 8) {
                            Divider()
                            ScoreBar(label: "MEM", value: digitScore, maxValue: 100, color: AppColors.violet)
                            ScoreBar(label: "SPD", value: reactionScore, maxValue: 100, color: AppColors.coral)
                            ScoreBar(label: "VIS", value: visualScore, maxValue: 100, color: AppColors.sky)
                        }
                    }
                }
                .padding(.horizontal, 24)

                Spacer()

                Text("What's your Brain Age?")
                    .font(.system(size: 22, weight: .bold))
                    .foregroundStyle(.primary)

                Spacer().frame(height: 10)
                BrandingFooter()
                Spacer().frame(height: 28)
            }
        }
        .frame(width: 360, height: 640)
    }
}

// MARK: - 2. ChallengeShareCard

struct TikTokChallengeCard: View {
    let challengerName: String
    let challengerScore: Int
    let challengeType: String

    var body: some View {
        ZStack {
            CardBackground()

            VStack(spacing: 0) {
                Spacer().frame(height: 32)
                BrandingHeader()
                Spacer().frame(height: 28)

                ShareCardSurface {
                    VStack(spacing: 16) {
                        Text("CHALLENGE")
                            .font(.system(size: 36, weight: .bold))
                            .tracking(6)
                            .foregroundStyle(AppColors.coral)

                        Text(challengeType.uppercased())
                            .font(.system(size: 13, weight: .heavy))
                            .tracking(3)
                            .foregroundStyle(.secondary)

                        Divider()

                        VStack(spacing: 6) {
                            Text(challengerName)
                                .font(.system(size: 18, weight: .bold))

                            Text("\(challengerScore)")
                                .font(.system(size: 48, weight: .bold, design: .rounded))
                                .foregroundStyle(AppColors.accent)
                        }

                        // VS
                        ZStack {
                            Circle()
                                .fill(AppColors.coral)
                                .frame(width: 52, height: 52)
                            Image(systemName: "bolt.fill")
                                .font(.system(size: 22, weight: .bold))
                                .foregroundStyle(.white)
                        }

                        // Mystery slot
                        VStack(spacing: 6) {
                            Text("???")
                                .font(.system(size: 48, weight: .bold, design: .rounded))
                                .foregroundStyle(.secondary.opacity(0.3))

                            Text("YOUR SCORE")
                                .font(.system(size: 12, weight: .heavy))
                                .tracking(2)
                                .foregroundStyle(.secondary)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                        .background(
                            RoundedRectangle(cornerRadius: 12)
                                .strokeBorder(
                                    Color.secondary.opacity(0.2),
                                    style: StrokeStyle(lineWidth: 2, dash: [8, 6])
                                )
                        )
                    }
                }
                .padding(.horizontal, 24)

                Spacer()

                Text("Think you're faster?")
                    .font(.system(size: 18, weight: .bold))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 28)
                    .padding(.vertical, 14)
                    .background(AppColors.coral, in: Capsule())

                Spacer().frame(height: 12)
                BrandingFooter()
                Spacer().frame(height: 28)
            }
        }
        .frame(width: 360, height: 640)
    }
}

// MARK: - 3. DuelResultShareCard

struct TikTokDuelResultCard: View {
    let player1Name: String
    let player1Score: Int
    let player2Name: String
    let player2Score: Int
    let exerciseType: String

    private var player1Wins: Bool { player1Score >= player2Score }

    var body: some View {
        ZStack {
            CardBackground()

            VStack(spacing: 0) {
                Spacer().frame(height: 32)
                BrandingHeader()
                Spacer().frame(height: 24)

                ShareCardSurface {
                    VStack(spacing: 16) {
                        Text("1v1 DUEL")
                            .font(.system(size: 36, weight: .bold))
                            .tracking(4)
                            .foregroundStyle(AppColors.violet)

                        Text(exerciseType.uppercased())
                            .font(.system(size: 13, weight: .heavy))
                            .tracking(3)
                            .foregroundStyle(.secondary)

                        Divider()

                        // Side by side
                        HStack(spacing: 0) {
                            playerColumn(
                                name: player1Name,
                                score: player1Score,
                                isWinner: player1Wins,
                                color: AppColors.accent
                            )

                            VStack(spacing: 6) {
                                Rectangle()
                                    .fill(Color.secondary.opacity(0.15))
                                    .frame(width: 1, height: 30)
                                Text("VS")
                                    .font(.system(size: 12, weight: .bold))
                                    .foregroundStyle(.secondary)
                                Rectangle()
                                    .fill(Color.secondary.opacity(0.15))
                                    .frame(width: 1, height: 30)
                            }
                            .frame(width: 44)

                            playerColumn(
                                name: player2Name,
                                score: player2Score,
                                isWinner: !player1Wins,
                                color: AppColors.coral
                            )
                        }

                        // Winner
                        HStack(spacing: 6) {
                            Image(systemName: "crown.fill")
                                .font(.system(size: 16, weight: .bold))
                                .foregroundStyle(AppColors.amber)
                            Text("\(player1Wins ? player1Name : player2Name) wins!")
                                .font(.system(size: 18, weight: .bold))
                        }
                    }
                }
                .padding(.horizontal, 24)

                Spacer()

                Text("Who's next?")
                    .font(.system(size: 20, weight: .bold))
                    .foregroundStyle(.primary)

                Spacer().frame(height: 12)
                BrandingFooter()
                Spacer().frame(height: 28)
            }
        }
        .frame(width: 360, height: 640)
    }

    @ViewBuilder
    private func playerColumn(name: String, score: Int, isWinner: Bool, color: Color) -> some View {
        VStack(spacing: 8) {
            if isWinner {
                Image(systemName: "crown.fill")
                    .font(.system(size: 18, weight: .bold))
                    .foregroundStyle(AppColors.amber)
            } else {
                Spacer().frame(height: 18)
            }

            ZStack {
                Circle()
                    .fill(color.opacity(isWinner ? 0.15 : 0.06))
                    .frame(width: 56, height: 56)

                if isWinner {
                    Circle()
                        .stroke(color.opacity(0.4), lineWidth: 2)
                        .frame(width: 56, height: 56)
                }

                Text(String(name.prefix(1)).uppercased())
                    .font(.system(size: 22, weight: .bold))
                    .foregroundStyle(isWinner ? color : .secondary)
            }

            Text(name)
                .font(.system(size: 12, weight: .heavy))
                .foregroundStyle(isWinner ? .primary : .secondary)
                .lineLimit(1)

            Text("\(score)")
                .font(.system(size: 36, weight: .bold, design: .rounded))
                .foregroundStyle(isWinner ? color : .secondary.opacity(0.5))
        }
        .frame(maxWidth: .infinity)
    }
}

// MARK: - 4. ReactionTimeShareCard

struct ReactionTimeShareCard: View {
    let averageMs: Int
    let bestMs: Int
    let ratingText: String
    let roundTimes: [Int]

    private var ratingColor: Color {
        if averageMs < 200 { return Color.green }
        if averageMs < 250 { return AppColors.accent }
        if averageMs < 300 { return AppColors.sky }
        if averageMs < 350 { return AppColors.amber }
        return AppColors.coral
    }

    var body: some View {
        ZStack {
            CardBackground()

            VStack(spacing: 0) {
                Spacer().frame(height: 32)
                BrandingHeader()
                Spacer().frame(height: 28)

                ShareCardSurface {
                    VStack(spacing: 16) {
                        // Exercise header
                        HStack(spacing: 8) {
                            Image(systemName: "bolt.fill")
                                .font(.system(size: 16, weight: .bold))
                            Text("REACTION TIME")
                                .font(.system(size: 13, weight: .heavy))
                                .tracking(3)
                        }
                        .foregroundStyle(AppColors.coral)

                        // Big average
                        Text("\(averageMs)")
                            .font(.system(size: 72, weight: .bold, design: .rounded))
                            .foregroundStyle(ratingColor)

                        Text("MILLISECONDS")
                            .font(.system(size: 13, weight: .heavy))
                            .tracking(4)
                            .foregroundStyle(.secondary)

                        // Rating
                        RatingPill(color: ratingColor) {
                            Text(ratingText.uppercased())
                        }

                        Divider()

                        // Round breakdown
                        HStack(spacing: 0) {
                            ForEach(Array(roundTimes.enumerated()), id: \.offset) { index, ms in
                                VStack(spacing: 4) {
                                    Text("R\(index + 1)")
                                        .font(.system(size: 10, weight: .heavy))
                                        .foregroundStyle(.secondary)
                                    Text("\(ms)")
                                        .font(.system(size: 16, weight: .bold, design: .rounded))
                                        .foregroundStyle(ms == bestMs ? ratingColor : .primary.opacity(0.7))
                                }
                                .frame(maxWidth: .infinity)
                            }
                        }

                        // Best
                        HStack(spacing: 6) {
                            Image(systemName: "trophy.fill")
                                .font(.system(size: 11, weight: .bold))
                                .foregroundStyle(AppColors.amber)
                            Text("Best: \(bestMs)ms")
                                .font(.system(size: 13, weight: .bold, design: .rounded))
                                .foregroundStyle(.secondary)
                        }
                    }
                }
                .padding(.horizontal, 24)

                Spacer()

                Text("Think you're faster?")
                    .font(.system(size: 22, weight: .bold))
                    .foregroundStyle(.primary)

                Spacer().frame(height: 10)
                BrandingFooter()
                Spacer().frame(height: 28)
            }
        }
        .frame(width: 360, height: 640)
    }
}

// MARK: - 5. Generic ExerciseShareCard

struct ExerciseShareCard: View {
    let exerciseName: String
    let exerciseIcon: String
    let accentColor: Color
    let mainValue: String
    let mainLabel: String
    let ratingText: String
    let stats: [(label: String, value: String)]
    let ctaText: String

    var body: some View {
        ZStack {
            CardBackground()

            VStack(spacing: 0) {
                Spacer().frame(height: 32)
                BrandingHeader()
                Spacer().frame(height: 28)

                ShareCardSurface {
                    VStack(spacing: 16) {
                        // Exercise header
                        HStack(spacing: 8) {
                            Image(systemName: exerciseIcon)
                                .font(.system(size: 16, weight: .bold))
                            Text(exerciseName.uppercased())
                                .font(.system(size: 13, weight: .heavy))
                                .tracking(3)
                        }
                        .foregroundStyle(accentColor)

                        // Big stat
                        Text(mainValue)
                            .font(.system(size: 64, weight: .bold, design: .rounded))
                            .foregroundStyle(accentColor)
                            .lineLimit(1)
                            .minimumScaleFactor(0.5)

                        Text(mainLabel.uppercased())
                            .font(.system(size: 13, weight: .heavy))
                            .tracking(4)
                            .foregroundStyle(.secondary)

                        // Rating
                        RatingPill(color: accentColor) {
                            Text(ratingText.uppercased())
                        }

                        Divider()

                        // Stats
                        VStack(spacing: 10) {
                            ForEach(Array(stats.enumerated()), id: \.offset) { _, stat in
                                HStack {
                                    Text(stat.label)
                                        .font(.system(size: 13, weight: .semibold))
                                        .foregroundStyle(.secondary)
                                    Spacer()
                                    Text(stat.value)
                                        .font(.system(size: 15, weight: .bold, design: .rounded))
                                        .foregroundStyle(.primary)
                                }
                            }
                        }
                    }
                }
                .padding(.horizontal, 24)

                Spacer()

                Text(ctaText)
                    .font(.system(size: 22, weight: .bold))
                    .foregroundStyle(.primary)

                Spacer().frame(height: 10)
                BrandingFooter()
                Spacer().frame(height: 28)
            }
        }
        .frame(width: 360, height: 640)
    }
}

// MARK: - Previews

#Preview("Brain Score Card") {
    TikTokBrainScoreCard(
        brainScore: 87,
        brainAge: 23,
        brainType: .lightningReflex,
        percentile: 94,
        digitScore: 82,
        reactionScore: 95,
        visualScore: 78
    )
}

#Preview("Challenge Card") {
    TikTokChallengeCard(
        challengerName: "Dylan",
        challengerScore: 92,
        challengeType: "Speed Round"
    )
}

#Preview("Duel Result Card") {
    TikTokDuelResultCard(
        player1Name: "Dylan",
        player1Score: 87,
        player2Name: "Alex",
        player2Score: 72,
        exerciseType: "Dual N-Back"
    )
}

#Preview("Exercise Card") {
    ExerciseShareCard(
        exerciseName: "Color Match",
        exerciseIcon: "paintpalette.fill",
        accentColor: AppColors.violet,
        mainValue: "95%",
        mainLabel: "Accuracy",
        ratingText: "Stroop Master",
        stats: [
            ("Correct", "19 / 20"),
            ("Avg Response", "842 ms"),
            ("Score", "92%")
        ],
        ctaText: "Think you're faster?"
    )
}
