import SwiftUI

struct AchievementDetailView: View {
    let type: AchievementType
    let achievement: Achievement?
    let user: User?

    @Environment(\.dismiss) private var dismiss

    private var isUnlocked: Bool { achievement != nil }

    private static let motivationalMessages: [AchievementCategory: [String]] = [
        .streaks: [
            "Consistency is the mother of mastery.",
            "Every day you show up, your brain gets stronger.",
            "Small daily improvements lead to stunning results.",
        ],
        .exercises: [
            "Practice makes permanent. Keep going!",
            "Each exercise builds new neural pathways.",
            "You are investing in your future self.",
        ],
        .scores: [
            "Perfection is not the goal — but it sure feels good!",
            "Your accuracy shows real cognitive growth.",
            "Sharp mind, sharp scores.",
        ],
        .brainScore: [
            "Your brain score reflects real cognitive improvement.",
            "Intelligence is not fixed — you are proving it.",
            "Every point earned is a step toward mastery.",
        ],
        .exerciseTypes: [
            "Different reps make Memo harder to beat.",
            "Different exercises build different strengths.",
            "A well-rounded brain is a powerful brain.",
        ],
        .speed: [
            "Fast reflexes, fast thinking.",
            "Speed and accuracy — the ultimate combo.",
            "Your reaction time sets you apart.",
        ],
        .social: [
            "Sharing your journey inspires others!",
            "Growth is better when shared.",
            "You are part of a community of learners.",
        ],
        .dedication: [
            "Dedication separates good from great.",
            "Training at any hour shows true commitment.",
            "Your discipline is your superpower.",
        ],
        .mastery: [
            "Mastery is the journey, not the destination.",
            "You are becoming a true cognitive athlete.",
            "The best never stop learning.",
        ],
    ]

    private var motivationalMessage: String {
        let messages = Self.motivationalMessages[type.category] ?? ["Keep pushing forward!"]
        let index = abs(type.rawValue.hashValue) % messages.count
        return messages[index]
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                // Large icon with gradient background
                iconSection

                // Name and description
                infoSection

                // Date unlocked or progress
                if isUnlocked {
                    unlockedSection
                } else {
                    progressSection
                }

                // Motivational message
                motivationalSection

                // Dismiss button
                Button {
                    dismiss()
                } label: {
                    Text("Close")
                        .font(.subheadline.weight(.semibold))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                        .background(Color.white.opacity(0.08), in: RoundedRectangle(cornerRadius: 12))
                }
                .padding(.top, 8)
            }
            .padding(24)
            .padding(.top, 8)
        }
        .pageBackground()
    }

    // MARK: - Icon Section

    private var iconSection: some View {
        ZStack {
            Circle()
                .fill(
                    isUnlocked
                        ? AnyShapeStyle(
                            LinearGradient(
                                colors: type.gradientColors,
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        : AnyShapeStyle(Color.white.opacity(0.08))
                )
                .frame(width: 120, height: 120)

            if isUnlocked {
                Image(systemName: type.icon)
                    .font(.system(size: 52, weight: .semibold))
                    .foregroundStyle(.white)
            } else {
                ZStack {
                    Image(systemName: type.icon)
                        .font(.system(size: 52, weight: .semibold))
                        .foregroundStyle(.secondary.opacity(0.4))

                    Image(systemName: "lock.fill")
                        .font(.system(size: 28, weight: .bold))
                        .foregroundStyle(.secondary)
                        .offset(y: 2)
                }
            }
        }
    }

    // MARK: - Info Section

    private var infoSection: some View {
        VStack(spacing: 8) {
            Text(type.displayName)
                .font(.title2.weight(.bold))
                .multilineTextAlignment(.center)

            Text(type.category.rawValue)
                .font(.caption.weight(.semibold))
                .foregroundStyle(type.color)
                .padding(.horizontal, 12)
                .padding(.vertical, 4)
                .background(type.color.opacity(0.12), in: Capsule())

            Text(isUnlocked ? type.description : type.requirementDescription)
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.top, 4)
        }
    }

    // MARK: - Unlocked Section

    private var unlockedSection: some View {
        VStack(spacing: 8) {
            HStack(spacing: 8) {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundStyle(type.color)
                Text("Unlocked")
                    .font(.subheadline.weight(.bold))
                    .foregroundStyle(type.color)
            }

            if let achievement {
                Text(achievement.unlockedAt.formatted(.dateTime.year().month(.wide).day()))
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .frame(maxWidth: .infinity)
        .glowingCard(color: type.color, intensity: 0.18)
    }

    // MARK: - Progress Section

    private var progressSection: some View {
        VStack(spacing: 12) {
            let current = min(type.currentProgress(user: user), type.targetValue)
            let target = type.targetValue
            let fraction = target > 0 ? Double(current) / Double(target) : 0

            Text("\(current)/\(target) \(type.progressLabel)")
                .font(.subheadline.weight(.bold))

            GeometryReader { geometry in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 6)
                        .fill(Color.white.opacity(0.08))
                        .frame(height: 12)

                    RoundedRectangle(cornerRadius: 6)
                        .fill(
                            LinearGradient(
                                colors: type.gradientColors,
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .frame(width: max(0, geometry.size.width * fraction), height: 12)
                }
            }
            .frame(height: 12)

            Text("\(Int(fraction * 100))% complete")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .glowingCard(color: type.color, intensity: 0.05)
    }

    // MARK: - Motivational Section

    private var motivationalSection: some View {
        HStack(spacing: 12) {
            Image(systemName: "quote.opening")
                .font(.title3)
                .foregroundStyle(type.color.opacity(0.6))

            Text(motivationalMessage)
                .font(.subheadline)
                .italic()
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.leading)

            Spacer()
        }
        .frame(maxWidth: .infinity)
        .glowingCard(color: type.color, intensity: 0.05)
    }
}
