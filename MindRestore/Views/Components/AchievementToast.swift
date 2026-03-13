import SwiftUI

struct AchievementToast: View {
    let achievementType: AchievementType
    let onDismiss: () -> Void

    @State private var isShowing = false
    @State private var iconScale: CGFloat = 0.3
    @State private var achievementShareImage: UIImage?

    var body: some View {
        VStack {
            HStack(spacing: 14) {
                ZStack {
                    Circle()
                        .fill(achievementType.gradientColors[0])
                        .frame(width: 48, height: 48)

                    Image(systemName: achievementType.icon)
                        .font(.system(size: 22, weight: .bold))
                        .foregroundStyle(.white)
                        .scaleEffect(iconScale)
                }

                VStack(alignment: .leading, spacing: 2) {
                    Text("Achievement Unlocked!")
                        .font(.caption.weight(.bold))
                        .foregroundStyle(.secondary)
                        .tracking(0.5)

                    Text(achievementType.displayName)
                        .font(.headline)
                        .foregroundStyle(.primary)

                    Text(achievementType.description)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }

                Spacer()

                if let shareImage = achievementShareImage {
                    ShareLink(
                        item: Image(uiImage: shareImage),
                        preview: SharePreview(
                            achievementType.displayName,
                            image: Image(uiImage: shareImage)
                        )
                    ) {
                        Image(systemName: "square.and.arrow.up")
                            .font(.body.weight(.semibold))
                            .foregroundStyle(achievementType.gradientColors[0])
                    }
                }

                Button {
                    withAnimation(.spring(response: 0.3)) {
                        isShowing = false
                    }
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                        onDismiss()
                    }
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.title3)
                        .foregroundStyle(.tertiary)
                }
                .accessibilityLabel("Dismiss")
            }
            .padding(16)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(AppColors.cardSurface)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(
                        achievementType.gradientColors[0].opacity(0.3),
                        lineWidth: 1
                    )
            )
            .padding(.horizontal, 16)
            .offset(y: isShowing ? 0 : -150)
            .accessibilityLabel("Achievement unlocked: \(achievementType.displayName)")

            Spacer()
        }
        .padding(.top, 8)
        .onAppear {
            withAnimation(.spring(response: 0.5, dampingFraction: 0.7)) {
                isShowing = true
            }
            withAnimation(.spring(response: 0.6, dampingFraction: 0.4).delay(0.2)) {
                iconScale = 1.0
            }
            renderAchievementShareImage()
            // Auto-dismiss after 6 seconds (longer to allow sharing)
            DispatchQueue.main.asyncAfter(deadline: .now() + 6) {
                withAnimation(.spring(response: 0.3)) {
                    isShowing = false
                }
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                    onDismiss()
                }
            }
        }
    }

    @MainActor
    private func renderAchievementShareImage() {
        let card = AchievementShareCard(achievementType: achievementType)
        achievementShareImage = card.renderAsImage(size: CGSize(width: 300, height: 400))
    }
}

// MARK: - XP Gained Toast

struct XPGainedToast: View {
    let amount: Int
    let levelUp: Bool
    let newLevel: Int?

    @State private var isShowing = false
    @State private var xpScale: CGFloat = 0.5
    @State private var levelUpShareImage: UIImage?

    var body: some View {
        VStack {
            HStack(spacing: 12) {
                ZStack {
                    Circle()
                        .fill(levelUp ? AppColors.violet : AppColors.accent)
                        .frame(width: 40, height: 40)

                    Image(systemName: levelUp ? "arrow.up.circle.fill" : "bolt.fill")
                        .font(.system(size: 18, weight: .bold))
                        .foregroundStyle(.white)
                        .scaleEffect(xpScale)
                }

                VStack(alignment: .leading, spacing: 1) {
                    if levelUp, let lvl = newLevel {
                        Text("Level Up!")
                            .font(.subheadline.weight(.bold))
                            .foregroundStyle(AppColors.violet)
                        Text("Level \(lvl) — \(UserLevel.name(for: lvl))")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    } else {
                        Text("+\(amount) XP")
                            .font(.subheadline.weight(.bold))
                            .foregroundStyle(AppColors.accent)
                    }
                }

                Spacer()

                if levelUp, let lvl = newLevel, let shareImage = levelUpShareImage {
                    ShareLink(
                        item: Image(uiImage: shareImage),
                        preview: SharePreview(
                            "Level \(lvl) on Memori!",
                            image: Image(uiImage: shareImage)
                        )
                    ) {
                        Image(systemName: "square.and.arrow.up")
                            .font(.body.weight(.semibold))
                            .foregroundStyle(AppColors.violet)
                    }
                }
            }
            .padding(12)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(AppColors.cardSurface)
            )
            .padding(.horizontal, 16)
            .offset(y: isShowing ? 0 : -100)

            Spacer()
        }
        .padding(.top, 8)
        .onAppear {
            withAnimation(.spring(response: 0.4, dampingFraction: 0.7)) {
                isShowing = true
            }
            withAnimation(.spring(response: 0.5, dampingFraction: 0.3).delay(0.1)) {
                xpScale = 1.0
            }
            if levelUp, let lvl = newLevel {
                renderLevelUpShareImage(level: lvl)
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + (levelUp ? 5.0 : 2.5)) {
                withAnimation(.spring(response: 0.3)) {
                    isShowing = false
                }
            }
        }
    }

    @MainActor
    private func renderLevelUpShareImage(level: Int) {
        let card = LevelUpShareCard(
            level: level,
            levelName: UserLevel.name(for: level),
            totalXP: 0
        )
        levelUpShareImage = card.renderAsImage(size: CGSize(width: 300, height: 400))
    }
}

// MARK: - Streak Freeze Toast

struct StreakFreezeToast: View {
    let message: String

    @State private var isShowing = false
    @State private var iconScale: CGFloat = 0.3

    var body: some View {
        VStack {
            HStack(spacing: 12) {
                ZStack {
                    Circle()
                        .fill(AppColors.sky)
                        .frame(width: 40, height: 40)

                    Image(systemName: "shield.fill")
                        .font(.system(size: 18, weight: .bold))
                        .foregroundStyle(.white)
                        .scaleEffect(iconScale)
                }

                VStack(alignment: .leading, spacing: 2) {
                    Text("Streak Freeze")
                        .font(.caption.weight(.bold))
                        .foregroundStyle(.secondary)
                        .tracking(0.5)

                    Text(message)
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.primary)
                        .lineLimit(2)
                }

                Spacer()
            }
            .padding(12)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(AppColors.cardSurface)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(
                        AppColors.sky.opacity(0.3),
                        lineWidth: 1
                    )
            )
            .padding(.horizontal, 16)
            .offset(y: isShowing ? 0 : -120)

            Spacer()
        }
        .padding(.top, 8)
        .onAppear {
            UINotificationFeedbackGenerator().notificationOccurred(.warning)
            withAnimation(.spring(response: 0.5, dampingFraction: 0.7)) {
                isShowing = true
            }
            withAnimation(.spring(response: 0.6, dampingFraction: 0.4).delay(0.2)) {
                iconScale = 1.0
            }
        }
    }
}
