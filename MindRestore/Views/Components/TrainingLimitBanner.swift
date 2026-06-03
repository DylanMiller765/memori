import SwiftUI

/// A banner that nudges users about optimal training duration.
///
/// - At 15-19 min: encouraging "sweet spot" message (Lampit 2014).
/// - At 20+ min: rest prompt explaining diminishing returns, with a dismiss action.
struct TrainingPaceBanner: View {
    let trainingMinutes: Double
    var onDoneForToday: (() -> Void)?

    @State private var appeared = false

    var body: some View {
        Group {
            if trainingMinutes >= 20 {
                restBanner
            } else if trainingMinutes >= 15 {
                sweetSpotBanner
            }
        }
    }

    // MARK: - Sweet Spot Banner (15-19 min)

    private var sweetSpotBanner: some View {
        HStack(spacing: 14) {
            Image(systemName: "brain.fill")
                .font(.title2)
                .foregroundStyle(AppColors.accent)
                .symbolEffect(.pulse, options: .repeating)

            VStack(alignment: .leading, spacing: 4) {
                Text("You're in the sweet spot!")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.primary)

                Text("Science says 15-20 min is optimal for memory training.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Spacer(minLength: 0)
        }
        .appCard()
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(AppColors.accent.opacity(0.15), lineWidth: 1)
        )
        .opacity(appeared ? 1 : 0)
        .offset(y: appeared ? 0 : 12)
        .onAppear {
            withAnimation(.spring(response: 0.5, dampingFraction: 0.8)) {
                appeared = true
            }
        }
    }

    // MARK: - Rest Banner (20+ min)

    private var restBanner: some View {
        VStack(spacing: 14) {
            HStack(spacing: 14) {
                Image(systemName: "moon.zzz.fill")
                    .font(.title2)
                    .foregroundStyle(AppColors.teal)

                VStack(alignment: .leading, spacing: 4) {
                    Text("Great session!")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.primary)

                    Text("Research shows diminishing returns beyond 20 minutes. Your brain needs rest to consolidate what you learned.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }

                Spacer(minLength: 0)
            }

            if let onDoneForToday {
                Button(action: onDoneForToday) {
                    Text("Done for Today")
                        .font(.subheadline.weight(.semibold))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                        .background(
                            AppColors.teal,
                            in: RoundedRectangle(cornerRadius: 12)
                        )
                        .foregroundStyle(.white)
                }
            }
        }
        .appCard()
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(AppColors.teal.opacity(0.15), lineWidth: 1)
        )
        .opacity(appeared ? 1 : 0)
        .offset(y: appeared ? 0 : 12)
        .onAppear {
            withAnimation(.spring(response: 0.5, dampingFraction: 0.8)) {
                appeared = true
            }
        }
    }
}

// MARK: - Preview

#Preview("Sweet Spot") {
    TrainingPaceBanner(trainingMinutes: 16)
        .padding()
        .pageBackground()
}

#Preview("Training Target") {
    TrainingPaceBanner(trainingMinutes: 22) {
        print("Done tapped")
    }
    .padding()
    .pageBackground()
}
