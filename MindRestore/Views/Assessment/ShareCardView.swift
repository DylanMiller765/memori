import SwiftUI

struct ShareCardView: View {
    let brainScore: Int
    let brainAge: Int
    let brainType: BrainType
    let percentile: Int
    let digitScore: Double
    let reactionScore: Double
    let visualScore: Double

    var body: some View {
        ZStack {
            // Warm cream background
            Color(red: 0.969, green: 0.961, blue: 0.941)

            VStack(spacing: 0) {
                Spacer().frame(height: 32)

                // Header branding
                HStack(spacing: 6) {
                    Image(systemName: "brain.fill")
                        .font(.system(size: 13, weight: .bold))
                        .foregroundStyle(AppColors.accent)
                    Text("MEMO")
                        .font(.system(size: 13, weight: .heavy))
                        .tracking(3)
                        .foregroundStyle(Color.black.opacity(0.4))
                }

                Spacer().frame(height: 24)

                // Brain Score Ring
                ZStack {
                    Circle()
                        .stroke(Color.black.opacity(0.06), lineWidth: 14)

                    Circle()
                        .trim(from: 0, to: min(CGFloat(brainScore) / 1000.0, 1.0))
                        .stroke(
                            scoreColor,
                            style: StrokeStyle(lineWidth: 14, lineCap: .round)
                        )
                        .rotationEffect(.degrees(-90))

                    VStack(spacing: 2) {
                        Text("\(brainScore)")
                            .font(.system(size: 52, weight: .bold, design: .rounded))
                            .foregroundStyle(Color.black)
                        Text("BRAIN SCORE")
                            .font(.system(size: 9, weight: .bold))
                            .tracking(1.5)
                            .foregroundStyle(Color.black.opacity(0.35))
                    }
                }
                .frame(width: 170, height: 170)

                Spacer().frame(height: 20)

                // Brain Age + Percentile
                HStack(spacing: 0) {
                    VStack(spacing: 3) {
                        Text("\(brainAge)")
                            .font(.system(size: 32, weight: .bold, design: .rounded))
                            .foregroundStyle(Color.black)
                        Text("Brain Age")
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundStyle(Color.black.opacity(0.4))
                    }
                    .frame(maxWidth: .infinity)

                    RoundedRectangle(cornerRadius: 1)
                        .fill(Color.black.opacity(0.1))
                        .frame(width: 1, height: 32)

                    VStack(spacing: 3) {
                        Text("Top \(100 - percentile)%")
                            .font(.system(size: 32, weight: .bold, design: .rounded))
                            .foregroundStyle(Color.black)
                        Text("Percentile")
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundStyle(Color.black.opacity(0.4))
                    }
                    .frame(maxWidth: .infinity)
                }
                .padding(.horizontal, 20)

                Spacer().frame(height: 16)

                // Brain type badge
                HStack(spacing: 6) {
                    Image(systemName: brainType.icon)
                        .font(.system(size: 12, weight: .bold))
                    Text(brainType.displayName)
                        .font(.system(size: 13, weight: .bold))
                }
                .foregroundStyle(typeColor)
                .padding(.horizontal, 14)
                .padding(.vertical, 7)
                .background(
                    Capsule()
                        .fill(typeColor.opacity(0.1))
                )

                Spacer().frame(height: 20)

                // Score breakdown bars
                HStack(spacing: 10) {
                    miniBar(label: "MEM", score: digitScore, color: AppColors.violet)
                    miniBar(label: "SPD", score: reactionScore, color: AppColors.coral)
                    miniBar(label: "VIS", score: visualScore, color: AppColors.sky)
                }
                .padding(.horizontal, 32)

                Spacer().frame(height: 20)

                // Percentile pill
                HStack(spacing: 6) {
                    Image(systemName: "chart.bar.fill")
                        .font(.system(size: 11, weight: .bold))
                    Text("Better than \(percentile)% of players")
                        .font(.system(size: 12, weight: .bold))
                }
                .foregroundStyle(scoreColor)
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
                .background(
                    Capsule()
                        .fill(scoreColor.opacity(0.1))
                )

                Spacer()

                // CTA
                Text("Can you beat my score?")
                    .font(.system(size: 17, weight: .bold))
                    .foregroundStyle(Color.black.opacity(0.8))

                Spacer().frame(height: 8)

                Text("Test yours free — Memo")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(Color.black.opacity(0.3))

                Spacer().frame(height: 28)
            }
        }
        .frame(width: 360, height: 640)
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }

    private func miniBar(label: String, score: Double, color: Color) -> some View {
        VStack(spacing: 6) {
            ZStack(alignment: .bottom) {
                RoundedRectangle(cornerRadius: 6)
                    .fill(color.opacity(0.12))
                    .frame(height: 52)
                RoundedRectangle(cornerRadius: 6)
                    .fill(color)
                    .frame(height: 52 * score / 100)
            }
            .frame(maxWidth: .infinity)

            Text(label)
                .font(.system(size: 9, weight: .bold))
                .foregroundStyle(Color.black.opacity(0.35))

            Text("\(Int(score))")
                .font(.caption2.weight(.bold).monospacedDigit())
                .foregroundStyle(Color.black.opacity(0.7))
        }
    }

    private var scoreColor: Color {
        let progress = CGFloat(brainScore) / 1000.0
        if progress >= 0.7 { return AppColors.accent }
        if progress >= 0.4 { return AppColors.sky }
        return AppColors.coral
    }

    private var typeColor: Color {
        switch brainType {
        case .lightningReflex: return AppColors.coral
        case .numberCruncher: return AppColors.sky
        case .patternMaster: return AppColors.violet
        case .balancedBrain: return AppColors.mint
        }
    }

    @MainActor
    func renderImage() -> UIImage? {
        let renderer = ImageRenderer(content: self)
        renderer.scale = 3.0
        return renderer.uiImage
    }
}
