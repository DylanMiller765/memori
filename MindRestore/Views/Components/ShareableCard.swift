import SwiftUI

// MARK: - Level Up Share Card

struct LevelUpShareCard: View {
    let level: Int
    let levelName: String
    let totalXP: Int

    var body: some View {
        VStack(spacing: 20) {
            Text("LEVEL UP")
                .font(.caption.weight(.bold))
                .tracking(3)
                .foregroundStyle(Color(red: 0.45, green: 0.43, blue: 0.40))

            ZStack {
                ForEach(0..<3) { i in
                    Circle()
                        .stroke(AppColors.violet.opacity(0.15 - Double(i) * 0.04), lineWidth: 2)
                        .frame(width: CGFloat(80 + i * 30), height: CGFloat(80 + i * 30))
                }

                Text("\(level)")
                    .font(.system(size: 56, weight: .bold, design: .monospaced))
                    .foregroundStyle(AppColors.violet)
            }

            VStack(spacing: 4) {
                Text(levelName)
                    .font(.title2.weight(.bold))
                    .foregroundStyle(.primary)

                Text("\(totalXP) XP earned")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }

            Text("Memori")
                .font(.caption.weight(.medium))
                .foregroundStyle(Color(red: 0.45, green: 0.43, blue: 0.40).opacity(0.6))
        }
        .padding(32)
        .frame(width: 300)
        .background(
            LinearGradient(
                colors: [
                    Color(red: 0.969, green: 0.961, blue: 0.941),
                    Color(red: 0.955, green: 0.945, blue: 0.925),
                    Color(red: 0.969, green: 0.961, blue: 0.941)
                ],
                startPoint: .top,
                endPoint: .bottom
            ),
            in: RoundedRectangle(cornerRadius: 24)
        )
    }
}

// MARK: - Achievement Share Card

struct AchievementShareCard: View {
    let achievementType: AchievementType

    private var accentColor: Color {
        achievementType.gradientColors.first ?? AppColors.violet
    }

    var body: some View {
        VStack(spacing: 20) {
            Text("ACHIEVEMENT UNLOCKED")
                .font(.caption.weight(.bold))
                .tracking(2)
                .foregroundStyle(Color(red: 0.45, green: 0.43, blue: 0.40))

            ZStack {
                Circle()
                    .fill(accentColor.opacity(0.12))
                    .frame(width: 80, height: 80)

                Image(systemName: achievementType.icon)
                    .font(.system(size: 36, weight: .bold))
                    .foregroundStyle(accentColor)
            }

            VStack(spacing: 4) {
                Text(achievementType.displayName)
                    .font(.title3.weight(.bold))
                    .foregroundStyle(.primary)

                Text(achievementType.description)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 8)
            }

            Text("Memori")
                .font(.caption.weight(.medium))
                .foregroundStyle(Color(red: 0.45, green: 0.43, blue: 0.40).opacity(0.6))
        }
        .padding(32)
        .frame(width: 300)
        .background(
            LinearGradient(
                colors: [
                    Color(red: 0.969, green: 0.961, blue: 0.941),
                    Color(red: 0.955, green: 0.945, blue: 0.925),
                    Color(red: 0.969, green: 0.961, blue: 0.941)
                ],
                startPoint: .top,
                endPoint: .bottom
            ),
            in: RoundedRectangle(cornerRadius: 24)
        )
    }
}

// MARK: - Profile Share Card

struct ProfileShareCard: View {
    let username: String
    let level: Int
    let levelName: String
    let brainScore: Int
    let streak: Int
    let achievements: Int
    let avatarEmoji: String

    var body: some View {
        VStack(spacing: 20) {
            Text(avatarEmoji)
                .font(.system(size: 48))

            VStack(spacing: 4) {
                Text(username.isEmpty ? "Brain Trainer" : username)
                    .font(.title2.weight(.bold))
                    .foregroundStyle(.primary)

                Text("Level \(level) — \(levelName)")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }

            HStack(spacing: 24) {
                profileStat(value: "\(brainScore)", label: "Brain Score", color: AppColors.accent)
                profileStat(value: "\(streak)d", label: "Streak", color: AppColors.coral)
                profileStat(value: "\(achievements)", label: "Badges", color: AppColors.violet)
            }

            Text("Memori")
                .font(.caption.weight(.medium))
                .foregroundStyle(Color(red: 0.45, green: 0.43, blue: 0.40).opacity(0.6))
        }
        .padding(32)
        .frame(width: 300)
        .background(
            LinearGradient(
                colors: [
                    Color(red: 0.969, green: 0.961, blue: 0.941),
                    Color(red: 0.955, green: 0.945, blue: 0.925),
                    Color(red: 0.969, green: 0.961, blue: 0.941)
                ],
                startPoint: .top,
                endPoint: .bottom
            ),
            in: RoundedRectangle(cornerRadius: 24)
        )
    }

    private func profileStat(value: String, label: String, color: Color) -> some View {
        VStack(spacing: 2) {
            Text(value)
                .font(.headline.weight(.bold))
                .foregroundStyle(color)
            Text(label)
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
    }
}

// MARK: - Render to Image

extension View {
    @MainActor
    func renderAsImage(size: CGSize = CGSize(width: 300, height: 400), scale: CGFloat? = nil) -> UIImage {
        // Detect current color scheme and pass it to the renderer
        let isDark = UITraitCollection.current.userInterfaceStyle == .dark
        let content = self.environment(\.colorScheme, isDark ? .dark : .light)
        let renderer = ImageRenderer(content: content)
        renderer.proposedSize = .init(size)
        renderer.scale = scale ?? UIScreen.main.scale
        return renderer.uiImage ?? UIImage()
    }
}
