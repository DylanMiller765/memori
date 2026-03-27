import SwiftUI

struct WorkoutShareCard: View {
    let brainScore: Int
    let scoreDelta: Int
    let brainAge: Int
    let streak: Int
    var userAge: Int = 0

    private let cardWidth: CGFloat = 360

    private var darkBg: LinearGradient {
        LinearGradient(
            colors: [
                Color(red: 0.08, green: 0.08, blue: 0.14),
                Color(red: 0.12, green: 0.10, blue: 0.22)
            ],
            startPoint: .top,
            endPoint: .bottom
        )
    }

    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                HStack(spacing: 6) {
                    Image(systemName: "brain.fill")
                        .font(.system(size: 14, weight: .bold))
                        .foregroundStyle(AppColors.accent)
                    Text("Memori")
                        .font(.system(size: 15, weight: .bold))
                        .foregroundStyle(.white)
                }

                Spacer()

                Text("Daily Workout")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(.white.opacity(0.6))
            }

            Spacer().frame(height: 40)

            // Big score
            Text("\(brainScore)")
                .font(.system(size: 64, weight: .black, design: .rounded))
                .foregroundStyle(.white)

            Spacer().frame(height: 4)

            Text("BRAIN SCORE")
                .font(.system(size: 12, weight: .bold))
                .tracking(4)
                .foregroundStyle(.white.opacity(0.5))

            Spacer().frame(height: 12)

            // Delta
            HStack(spacing: 4) {
                if scoreDelta >= 0 {
                    Image(systemName: "arrow.up")
                        .font(.system(size: 13, weight: .bold))
                    Text("+\(scoreDelta) points")
                        .font(.system(size: 16, weight: .bold, design: .rounded))
                } else {
                    Image(systemName: "arrow.down")
                        .font(.system(size: 13, weight: .bold))
                    Text("\(scoreDelta) points")
                        .font(.system(size: 16, weight: .bold, design: .rounded))
                }
            }
            .foregroundStyle(scoreDelta >= 0 ? AppColors.teal : AppColors.coral)

            Spacer().frame(height: 32)

            // Stats row
            HStack(spacing: 0) {
                // Brain Age
                VStack(spacing: 6) {
                    Image(systemName: "brain.head.profile")
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundStyle(AppColors.accent)

                    Text("Brain Age")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(.white.opacity(0.5))

                    Text("\(brainAge)")
                        .font(.system(size: 24, weight: .bold, design: .rounded))
                        .foregroundStyle(.white)

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
                }
                .frame(maxWidth: .infinity)

                // Divider
                Rectangle()
                    .fill(.white.opacity(0.15))
                    .frame(width: 1, height: 50)

                // Streak
                VStack(spacing: 6) {
                    Image(systemName: "flame.fill")
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundStyle(AppColors.coral)

                    Text("Day Streak")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(.white.opacity(0.5))

                    Text("\(streak)")
                        .font(.system(size: 24, weight: .bold, design: .rounded))
                        .foregroundStyle(.white)
                }
                .frame(maxWidth: .infinity)
            }

            Spacer().frame(height: 32)

            // CTA
            Text("Train your brain free \u{2014} Memori")
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(.white.opacity(0.4))
        }
        .padding(28)
        .frame(width: cardWidth)
        .background(
            RoundedRectangle(cornerRadius: 24)
                .fill(darkBg)
        )
    }
}

#Preview {
    WorkoutShareCard(
        brainScore: 71,
        scoreDelta: 9,
        brainAge: 26,
        streak: 5
    )
    .padding()
    .background(Color.gray.opacity(0.3))
}

#Preview("Negative Delta") {
    WorkoutShareCard(
        brainScore: 58,
        scoreDelta: -4,
        brainAge: 31,
        streak: 2
    )
    .padding()
    .background(Color.gray.opacity(0.3))
}
