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

    private var ageColor: Color {
        switch brainAge {
        case ...25: return Color(red: 0, green: 0.82, blue: 0.62)
        case 26...40: return Color(red: 0.25, green: 0.61, blue: 0.98)
        case 41...55: return Color(red: 1.0, green: 0.76, blue: 0.28)
        default: return Color(red: 0.98, green: 0.42, blue: 0.35)
        }
    }

    private var verdict: String {
        switch brainAge {
        case ...20: return "Built different"
        case 21...25: return "Sharp... for now"
        case 26...30: return "TikTok hasn't won yet"
        case 31...35: return "Attention span left the chat"
        case 36...45: return "More screen time than brain time"
        case 46...55: return "The doomscrolling is showing"
        default: return "Brain rot is real"
        }
    }

    private var gradient: LinearGradient {
        if brainAge <= 25 {
            return LinearGradient(colors: [Color(red: 0, green: 0.18, blue: 0.38), Color(red: 0, green: 0.28, blue: 0.48), Color(red: 0, green: 0.12, blue: 0.25)], startPoint: .topLeading, endPoint: .bottomTrailing)
        } else if brainAge <= 40 {
            return LinearGradient(colors: [Color(red: 0.15, green: 0.05, blue: 0.32), Color(red: 0.25, green: 0.10, blue: 0.45), Color(red: 0.10, green: 0.04, blue: 0.20)], startPoint: .topLeading, endPoint: .bottomTrailing)
        } else {
            return LinearGradient(colors: [Color(red: 0.32, green: 0.06, blue: 0.06), Color(red: 0.45, green: 0.12, blue: 0.08), Color(red: 0.18, green: 0.04, blue: 0.04)], startPoint: .topLeading, endPoint: .bottomTrailing)
        }
    }

    var body: some View {
        ZStack {
            // Wrapped-style gradient background
            gradient

            // Glow orb
            Circle()
                .fill(ageColor.opacity(0.15))
                .blur(radius: 80)
                .frame(width: 250, height: 250)
                .offset(y: -60)

            VStack(spacing: 0) {
                Spacer().frame(height: 40)

                // Mascot
                Image(brainAge <= 30 ? "mascot-crown" : brainAge >= 50 ? "mascot-low-score" : "mascot-celebrate")
                    .renderingMode(.original)
                    .resizable()
                    .scaledToFit()
                    .frame(height: 80)

                // Label
                Text("MY BRAIN AGE")
                    .font(.system(size: 10, weight: .heavy))
                    .foregroundStyle(.white.opacity(0.5))
                    .tracking(5)
                    .padding(.top, 8)

                // Big number
                Text("\(brainAge)")
                    .font(.system(size: 120, weight: .black, design: .rounded))
                    .foregroundStyle(.white)
                    .shadow(color: ageColor.opacity(0.6), radius: 30, y: 0)
                    .minimumScaleFactor(0.6)
                    .padding(.vertical, -12)

                // Verdict
                Text(verdict)
                    .font(.system(size: 20, weight: .black, design: .rounded))
                    .foregroundStyle(.white.opacity(0.9))
                    .multilineTextAlignment(.center)

                // Age comparison
                if userAge > 0 {
                    let diff = userAge - brainAge
                    if diff > 0 {
                        Text("\(diff) years younger than me!")
                            .font(.system(size: 15, weight: .bold, design: .rounded))
                            .foregroundStyle(ageColor)
                            .padding(.top, 6)
                    } else if diff < 0 {
                        Text("\(abs(diff)) years older than my real age")
                            .font(.system(size: 15, weight: .bold, design: .rounded))
                            .foregroundStyle(ageColor)
                            .padding(.top, 6)
                    }
                }

                Spacer()

                // Domain scores inline
                HStack(spacing: 16) {
                    Text("MEM \(Int(digitScore))").foregroundStyle(AppColors.violet)
                    Text("·").foregroundStyle(.white.opacity(0.2))
                    Text("SPD \(Int(reactionScore))").foregroundStyle(AppColors.coral)
                    Text("·").foregroundStyle(.white.opacity(0.2))
                    Text("VIS \(Int(visualScore))").foregroundStyle(AppColors.sky)
                }
                .font(.system(size: 13, weight: .heavy, design: .rounded))

                Text("Better than \(percentile)% of players")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(.white.opacity(0.4))
                    .padding(.top, 8)

                Spacer().frame(height: 16)

                // CTA
                Text("What's your Brain Age?")
                    .font(.system(size: 18, weight: .bold))
                    .foregroundStyle(.white.opacity(0.7))

                Spacer().frame(height: 8)

                // Branding
                HStack(spacing: 5) {
                    Text("🧠")
                        .font(.system(size: 10))
                    Text("MEMORI")
                        .font(.system(size: 9, weight: .heavy))
                        .foregroundStyle(.white.opacity(0.25))
                        .tracking(3)
                }

                Spacer().frame(height: 20)
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

// MARK: - 5. Generic ExerciseShareCard (Premium Redesign)

struct ExerciseShareCard: View {
    let exerciseName: String
    let exerciseIcon: String
    let accentColor: Color
    let mainValue: String
    let mainLabel: String
    let ratingText: String
    let stats: [(label: String, value: String)]
    let ctaText: String

    @Environment(\.colorScheme) private var colorScheme

    private var isDark: Bool { colorScheme == .dark }

    // Slightly desaturated accent for backgrounds
    private var glowColor: Color { accentColor.opacity(isDark ? 0.35 : 0.18) }

    var body: some View {
        ZStack {
            // -- Full-bleed background with accent radial glow --
            exerciseCardBackground

            VStack(spacing: 0) {
                Spacer().frame(height: 36)

                // -- Memori branding --
                exerciseCardBrandingHeader

                Spacer().frame(height: 32)

                // -- Game icon badge --
                ZStack {
                    Circle()
                        .fill(accentColor.opacity(isDark ? 0.18 : 0.12))
                        .frame(width: 56, height: 56)
                    Circle()
                        .stroke(accentColor.opacity(0.3), lineWidth: 1.5)
                        .frame(width: 56, height: 56)
                    Image(systemName: exerciseIcon)
                        .font(.system(size: 24, weight: .semibold))
                        .foregroundStyle(accentColor)
                }

                Spacer().frame(height: 8)

                // -- Game name --
                Text(exerciseName.uppercased())
                    .font(.system(size: 13, weight: .heavy))
                    .tracking(4)
                    .foregroundStyle(accentColor)

                Spacer().frame(height: 28)

                // -- Hero score with radial glow bloom --
                ZStack {
                    // Glow bloom behind the number
                    Circle()
                        .fill(
                            RadialGradient(
                                colors: [
                                    accentColor.opacity(isDark ? 0.30 : 0.15),
                                    accentColor.opacity(isDark ? 0.08 : 0.03),
                                    Color.clear
                                ],
                                center: .center,
                                startRadius: 20,
                                endRadius: 120
                            )
                        )
                        .frame(width: 240, height: 240)

                    VStack(spacing: 4) {
                        Text(mainValue)
                            .font(.system(size: 88, weight: .bold, design: .rounded))
                            .foregroundStyle(isDark ? .white : Color(red: 0.12, green: 0.12, blue: 0.15))
                            .lineLimit(1)
                            .minimumScaleFactor(0.4)

                        Text(mainLabel.uppercased())
                            .font(.system(size: 12, weight: .heavy))
                            .tracking(3)
                            .foregroundStyle(isDark ? Color.white.opacity(0.45) : Color(red: 0.45, green: 0.43, blue: 0.40))
                    }
                }
                .frame(height: 140)

                Spacer().frame(height: 16)

                // -- Rating pill --
                HStack(spacing: 6) {
                    Image(systemName: "star.fill")
                        .font(.system(size: 11, weight: .bold))
                    Text(ratingText.uppercased())
                        .font(.system(size: 13, weight: .bold))
                        .tracking(1)
                }
                .foregroundStyle(accentColor)
                .padding(.horizontal, 20)
                .padding(.vertical, 10)
                .background(
                    Capsule()
                        .fill(accentColor.opacity(isDark ? 0.15 : 0.10))
                )
                .overlay(
                    Capsule()
                        .stroke(accentColor.opacity(0.2), lineWidth: 1)
                )

                Spacer().frame(height: 28)

                // -- Stats row (horizontal, compact) --
                if !stats.isEmpty {
                    HStack(spacing: 0) {
                        ForEach(Array(stats.enumerated()), id: \.offset) { index, stat in
                            if index > 0 {
                                Rectangle()
                                    .fill(isDark ? Color.white.opacity(0.12) : Color.black.opacity(0.08))
                                    .frame(width: 1, height: 32)
                            }

                            VStack(spacing: 3) {
                                Text(stat.value)
                                    .font(.system(size: 16, weight: .bold, design: .rounded))
                                    .foregroundStyle(isDark ? .white : Color(red: 0.12, green: 0.12, blue: 0.15))
                                    .lineLimit(1)
                                    .minimumScaleFactor(0.7)
                                Text(stat.label.uppercased())
                                    .font(.system(size: 9, weight: .heavy))
                                    .tracking(1.5)
                                    .foregroundStyle(isDark ? Color.white.opacity(0.40) : Color(red: 0.50, green: 0.48, blue: 0.46))
                                    .lineLimit(1)
                            }
                            .frame(maxWidth: .infinity)
                        }
                    }
                    .padding(.horizontal, 28)
                    .padding(.vertical, 14)
                    .background(
                        RoundedRectangle(cornerRadius: 14)
                            .fill(isDark ? Color.white.opacity(0.06) : Color.black.opacity(0.03))
                    )
                    .padding(.horizontal, 24)
                }

                Spacer()

                // -- CTA button --
                Text(ctaText)
                    .font(.system(size: 16, weight: .bold))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 32)
                    .padding(.vertical, 13)
                    .background(
                        Capsule()
                            .fill(accentColor)
                    )
                    .shadow(color: accentColor.opacity(0.4), radius: 12, y: 4)

                Spacer().frame(height: 16)

                // -- Footer branding --
                exerciseCardBrandingFooter

                Spacer().frame(height: 28)
            }
        }
        .frame(width: 360, height: 640)
        .clipShape(RoundedRectangle(cornerRadius: 20))
    }

    // MARK: - Sub-views

    private var exerciseCardBackground: some View {
        ZStack {
            // Base gradient
            if isDark {
                LinearGradient(
                    colors: [
                        Color(red: 0.05, green: 0.05, blue: 0.08),
                        Color(red: 0.07, green: 0.06, blue: 0.12),
                        Color(red: 0.04, green: 0.04, blue: 0.06)
                    ],
                    startPoint: .top,
                    endPoint: .bottom
                )
            } else {
                LinearGradient(
                    colors: [
                        Color(red: 0.98, green: 0.98, blue: 0.99),
                        Color(red: 0.96, green: 0.96, blue: 0.97),
                        Color(red: 0.98, green: 0.98, blue: 0.99)
                    ],
                    startPoint: .top,
                    endPoint: .bottom
                )
            }

            // Accent color radial glow (upper-center bloom)
            RadialGradient(
                colors: [
                    accentColor.opacity(isDark ? 0.12 : 0.06),
                    accentColor.opacity(isDark ? 0.04 : 0.02),
                    Color.clear
                ],
                center: UnitPoint(x: 0.5, y: 0.35),
                startRadius: 40,
                endRadius: 260
            )

            // Subtle noise/texture via thin border lines
            VStack {
                Rectangle()
                    .fill(isDark ? Color.white.opacity(0.04) : Color.black.opacity(0.03))
                    .frame(height: 0.5)
                Spacer()
                Rectangle()
                    .fill(isDark ? Color.white.opacity(0.04) : Color.black.opacity(0.03))
                    .frame(height: 0.5)
            }
        }
    }

    private var exerciseCardBrandingHeader: some View {
        HStack(spacing: 6) {
            Image(systemName: "brain.fill")
                .font(.system(size: 13, weight: .bold))
                .foregroundStyle(accentColor)
            Text("MEMORI")
                .font(.system(size: 13, weight: .heavy))
                .tracking(4)
                .foregroundStyle(isDark ? Color.white.opacity(0.50) : Color(red: 0.40, green: 0.38, blue: 0.36))
        }
    }

    private var exerciseCardBrandingFooter: some View {
        HStack(spacing: 4) {
            Image(systemName: "arrow.down.app.fill")
                .font(.system(size: 10, weight: .semibold))
            Text("Free on the App Store")
                .font(.system(size: 11, weight: .semibold))
        }
        .foregroundStyle(isDark ? Color.white.opacity(0.30) : Color(red: 0.58, green: 0.56, blue: 0.54))
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

#Preview("Exercise Card — Dark") {
    ExerciseShareCard(
        exerciseName: "Color Match",
        exerciseIcon: "paintpalette.fill",
        accentColor: AppColors.violet,
        mainValue: "95%",
        mainLabel: "Accuracy",
        ratingText: "Stroop Master",
        stats: [
            ("Correct", "19/20"),
            ("Avg Time", "842ms"),
            ("Score", "92%")
        ],
        ctaText: "Can you beat this?"
    )
    .environment(\.colorScheme, .dark)
}

#Preview("Exercise Card — Light") {
    ExerciseShareCard(
        exerciseName: "Dual N-Back",
        exerciseIcon: "square.grid.3x3.fill",
        accentColor: AppColors.accent,
        mainValue: "87%",
        mainLabel: "Accuracy",
        ratingText: "Elite Focus",
        stats: [
            ("Level", "N-3"),
            ("Rounds", "20"),
            ("Best", "92%")
        ],
        ctaText: "Can you beat this?"
    )
    .environment(\.colorScheme, .light)
}
