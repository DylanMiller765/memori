import SwiftUI

// MARK: - Segmented Score Ring

struct SegmentedScoreRing: View {
    let score: Int
    var color: Color = AppColors.accent
    var size: CGFloat = 80
    var lineWidth: CGFloat = 12

    @State private var animatedProgress: CGFloat = 0

    private var progress: CGFloat {
        min(CGFloat(score) / 1000.0, 1.0)
    }

    var body: some View {
        ZStack {
            // Soft glow
            Circle()
                .fill(
                    RadialGradient(
                        colors: [color.opacity(0.10), .clear],
                        center: .center,
                        startRadius: size * 0.2,
                        endRadius: size * 0.55
                    )
                )
                .frame(width: size * 1.1, height: size * 1.1)

            // Track
            Circle()
                .stroke(AppColors.cardBorder.opacity(0.5), lineWidth: lineWidth)

            // Progress arc
            Circle()
                .trim(from: 0, to: progress * animatedProgress)
                .stroke(
                    color,
                    style: StrokeStyle(lineWidth: lineWidth, lineCap: .round)
                )
                .rotationEffect(.degrees(-90))
                .shadow(color: color.opacity(0.35), radius: 3, y: 1)

            // Score number
            Text("\(score)")
                .font(.system(size: size * 0.32, weight: .black, design: .rounded))
                .foregroundStyle(AppColors.textPrimary)
        }
        .frame(width: size, height: size)
        .onAppear {
            withAnimation(.spring(response: 0.9, dampingFraction: 0.7)) {
                animatedProgress = 1.0
            }
        }
    }
}

// MARK: - Brain Score Card

struct BrainScoreCard: View {
    let score: BrainScoreResult
    var compact: Bool = false
    @State private var showingExplainer = false

    var body: some View {
        if compact {
            compactLayout
        } else {
            fullLayout
        }
    }

    // MARK: - Full Layout (Home & Insights)

    private var fullLayout: some View {
        VStack(spacing: 0) {
            // Personalized insight
            VStack(spacing: 4) {
                Text(personalInsight)
                    .font(.system(size: 17, weight: .bold, design: .rounded))
                    .foregroundStyle(brainTypeColor)

                Text(encouragement)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(AppColors.textTertiary)
            }
            .multilineTextAlignment(.center)
            .padding(.top, 18)
            .padding(.horizontal, 20)

            // Ring — compact size
            SegmentedScoreRing(
                score: score.brainScore,
                color: brainTypeColor,
                size: 80,
                lineWidth: 12
            )
            .padding(.vertical, 10)

            // Brain type badge
            HStack(spacing: 6) {
                Image(systemName: score.brainType.icon)
                    .font(.system(size: 12, weight: .bold))
                Text(score.brainType.displayName)
                    .font(.system(size: 12, weight: .bold))
            }
            .foregroundStyle(.white)
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background(
                Capsule()
                    .fill(brainTypeColor.gradient)
                    .shadow(color: brainTypeColor.opacity(0.3), radius: 6, y: 2)
            )
            .padding(.bottom, 14)

            // Stats row
            HStack(spacing: 0) {
                statBlock(topText: "\(score.brainAge)", bottomText: "Brain Age", color: brainAgeColor)

                Rectangle()
                    .fill(AppColors.cardBorder)
                    .frame(width: 1, height: 36)

                statBlock(topText: "Top \(100 - score.percentile)%", bottomText: "Percentile", color: AppColors.accent)
            }
            .padding(.horizontal, 16)
            .padding(.bottom, 14)

            // Divider
            Rectangle()
                .fill(AppColors.cardBorder)
                .frame(height: 1)

            // Domain chips
            HStack(spacing: 8) {
                domainChip(label: "MEM", value: Int(score.digitSpanScore), color: AppColors.violet)
                domainChip(label: "SPD", value: Int(score.reactionTimeScore), color: AppColors.coral)
                domainChip(label: "VIS", value: Int(score.visualMemoryScore), color: AppColors.sky)
            }
            .padding(.vertical, 10)
            .padding(.horizontal, 14)
        }
        .frame(maxWidth: .infinity)
        .background(
            VStack {
                brainTypeColor.opacity(0.04)
                    .frame(height: 100)
                    .blur(radius: 30)
                Spacer()
            }
        )
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Brain Score \(score.brainScore) out of 1000, \(score.brainType.displayName), brain age \(score.brainAge), top \(100 - score.percentile) percent")
        .overlay(alignment: .topTrailing) {
            Button {
                showingExplainer = true
            } label: {
                Image(systemName: "info.circle")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(AppColors.textTertiary)
                    .padding(12)
            }
            .accessibilityLabel("How brain score works")
        }
        .sheet(isPresented: $showingExplainer) {
            BrainScoreExplainerSheet()
        }
    }

    // MARK: - Compact Layout (Profile)

    private var compactLayout: some View {
        HStack(spacing: 14) {
            SegmentedScoreRing(
                score: score.brainScore,
                color: brainTypeColor,
                size: 58,
                lineWidth: 8
            )

            VStack(alignment: .leading, spacing: 6) {
                HStack(spacing: 4) {
                    Image(systemName: score.brainType.icon)
                        .font(.system(size: 9, weight: .bold))
                    Text(score.brainType.displayName)
                        .font(.system(size: 10, weight: .bold))
                }
                .foregroundStyle(.white)
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(
                    Capsule()
                        .fill(brainTypeColor.gradient)
                )

                HStack(spacing: 10) {
                    VStack(alignment: .leading, spacing: 1) {
                        Text("Brain Age")
                            .font(.system(size: 9, weight: .bold))
                            .foregroundStyle(AppColors.textTertiary)
                            .tracking(0.5)
                        Text("\(score.brainAge)")
                            .font(.system(size: 24, weight: .black, design: .rounded))
                            .foregroundStyle(brainAgeColor)
                    }

                    VStack(alignment: .leading, spacing: 1) {
                        Text("Percentile")
                            .font(.system(size: 9, weight: .bold))
                            .foregroundStyle(AppColors.textTertiary)
                            .tracking(0.5)
                        Text("Top \(100 - score.percentile)%")
                            .font(.system(size: 14, weight: .bold, design: .rounded))
                            .foregroundStyle(AppColors.accent)
                    }
                }
            }

            Spacer(minLength: 0)
        }
        .overlay(alignment: .topTrailing) {
            Button {
                showingExplainer = true
            } label: {
                Image(systemName: "info.circle")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(AppColors.textTertiary)
                    .padding(8)
            }
            .accessibilityLabel("How brain score works")
        }
        .sheet(isPresented: $showingExplainer) {
            BrainScoreExplainerSheet()
        }
    }

    // MARK: - Subviews

    private func statBlock(topText: String, bottomText: String, color: Color) -> some View {
        VStack(spacing: 2) {
            Text(topText)
                .font(.system(size: 22, weight: .black, design: .rounded))
                .foregroundStyle(color)
            Text(bottomText)
                .font(.system(size: 9, weight: .bold))
                .foregroundStyle(AppColors.textTertiary)
                .tracking(0.5)
        }
        .frame(maxWidth: .infinity)
    }

    private func domainChip(label: String, value: Int, color: Color) -> some View {
        HStack(spacing: 4) {
            Circle()
                .fill(color)
                .frame(width: 7, height: 7)
            Text(label)
                .font(.system(size: 10, weight: .bold))
                .foregroundStyle(color)
            Text("\(value)")
                .font(.system(size: 13, weight: .black, design: .rounded))
                .foregroundStyle(AppColors.textPrimary)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 5)
        .frame(maxWidth: .infinity)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(color.opacity(0.08))
        )
    }

    // MARK: - Personalization

    private var personalInsight: String {
        let mem = score.digitSpanScore
        let spd = score.reactionTimeScore
        let vis = score.visualMemoryScore
        let maxScore = max(mem, spd, vis)
        let total = score.brainScore

        if total <= 50 {
            return "Your brain journey starts here"
        }

        if maxScore == mem && mem > spd + 10 && mem > vis + 10 {
            return "Your memory is your superpower"
        } else if maxScore == spd && spd > mem + 10 && spd > vis + 10 {
            return "Lightning-fast reflexes"
        } else if maxScore == vis && vis > mem + 10 && vis > spd + 10 {
            return "You see what others miss"
        }

        if total >= 700 {
            return "You're in elite territory"
        } else if total >= 400 {
            return "Strong across the board"
        } else if total >= 200 {
            return "Building momentum"
        }

        return "Every session sharpens your mind"
    }

    private var encouragement: String {
        let total = score.brainScore
        let percentile = score.percentile

        if total <= 50 {
            return "Retake to see what you're really made of"
        } else if percentile <= 10 {
            return "Outperforming \(100 - percentile)% of players"
        } else if total >= 500 {
            return "Keep pushing into the top tier"
        } else if total >= 200 {
            return "Consistency is your secret weapon"
        }

        return "Train daily to unlock your potential"
    }

    private var brainTypeColor: Color {
        switch score.brainType {
        case .lightningReflex: return AppColors.coral
        case .numberCruncher: return AppColors.sky
        case .patternMaster: return AppColors.violet
        case .balancedBrain: return AppColors.accent
        }
    }

    private var brainAgeColor: Color {
        switch score.brainAge {
        case ...25: return Color(red: 0.18, green: 0.75, blue: 0.50)
        case 26...40: return AppColors.accent
        case 41...55: return AppColors.amber
        default: return AppColors.coral
        }
    }
}
