import SwiftUI
import SwiftData

struct ProfileView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(StoreService.self) private var storeService
    @Environment(GameCenterService.self) private var gameCenterService
    @Query private var users: [User]
    @Query private var achievements: [Achievement]

    @State private var showingSettings = false
    @State private var globalRank: Int?

    private var user: User? { users.first }
    private var isProUser: Bool { storeService.isProUser }
    private var isUltraUser: Bool { storeService.isUltraUser }

    private var unlockedAchievements: [Achievement] {
        achievements.sorted { $0.unlockedAt < $1.unlockedAt }
    }

    private var profileMascotMood: MascotRiveMood {
        guard let lastSession = user?.lastSessionDate else { return .neutral }
        if Calendar.current.isDateInToday(lastSession) {
            return .happy
        } else if Calendar.current.isDateInYesterday(lastSession) {
            return .neutral
        } else {
            return .sad
        }
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    playerCard
                        .staggered(index: 0)

                    xpProgress
                        .staggered(index: 1)

                    achievementsSection
                        .staggered(index: 2)

                    settingsButton
                        .staggered(index: 3)
                }
                .padding(.horizontal)
                .padding(.top, 8)
                .padding(.bottom, 32)
                .responsiveContent()
                .frame(maxWidth: .infinity)
            }
            .pageBackground()
            .navigationTitle("Profile")
            .sheet(isPresented: $showingSettings) {
                SettingsView()
            }
            .task {
                await loadGlobalRank()
            }
        }
    }

    // MARK: - Data Loading

    private func loadGlobalRank() async {
        let result = await gameCenterService.loadLeaderboardEntries(
            category: .brainScore,
            timeFilter: .allTime,
            range: NSRange(location: 1, length: 1)
        )
        if let local = result.localPlayerEntry {
            globalRank = local.rank
        }
    }

    // MARK: - Player Card

    private var playerCard: some View {
        VStack(spacing: 0) {
            // Rive Mascot
            RiveMascotView(
                mood: profileMascotMood,
                size: 120
            )
            .frame(height: 110)
            .clipped()

            // Name + Join Date
            VStack(spacing: 6) {
                Text(user?.username.isEmpty == false ? user!.username : "Player")
                    .font(.system(size: 28, weight: .bold))

                if let user {
                    Text("joined \(user.createdAt.formatted(.dateTime.month(.twoDigits).day(.twoDigits).year()))")
                        .font(.system(size: 13, weight: .medium, design: .monospaced))
                        .foregroundStyle(.secondary)
                }
            }
            .padding(.bottom, 20)

            Divider()
                .padding(.horizontal, 20)

            // Stat Pills
            HStack(spacing: 0) {
                statPill(
                    value: "\(user?.level ?? 1)",
                    label: "LEVEL",
                    color: .primary
                )

                Divider()
                    .frame(height: 40)

                statPill(
                    value: "\(user?.currentStreak ?? 0)",
                    label: "STREAK",
                    color: AppColors.mint
                )

                Divider()
                    .frame(height: 40)

                statPill(
                    value: globalRank != nil ? "#\(globalRank!)" : "--",
                    label: "GLOBAL",
                    color: AppColors.accent
                )
            }
            .padding(.vertical, 16)
        }
    }

    private func statPill(value: String, label: String, color: Color) -> some View {
        VStack(spacing: 4) {
            Text(value)
                .font(.system(size: 28, weight: .bold, design: .rounded))
                .foregroundStyle(color)
                .minimumScaleFactor(0.7)
            Text(label)
                .font(.system(size: 11, weight: .bold))
                .tracking(2)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
    }

    // MARK: - XP Progress

    private var xpProgress: some View {
        HStack(spacing: 12) {
            RiveMascotView(
                mood: profileMascotMood,
                size: 36
            )
            .frame(width: 36, height: 36)
            .clipped()

            VStack(alignment: .leading, spacing: 6) {
                Text(user?.levelName ?? "Beginner Brain")
                    .font(.system(size: 15, weight: .bold))

                ProgressView(value: user?.xpProgress ?? 0)
                    .tint(AppColors.accent)
            }

            let currentLevelXP = UserLevel.xpRequired(for: user?.level ?? 1)
            let xpInLevel = max(0, (user?.totalXP ?? 0) - currentLevelXP)
            let nextLevel = (user?.level ?? 1) + 1
            let nextName = UserLevel.name(for: nextLevel)

            VStack(alignment: .trailing, spacing: 2) {
                Text("\(xpInLevel) XP")
                    .font(.system(size: 13, weight: .bold, design: .rounded))
                Text("→ \(nextName)")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
        }
        .padding(16)
    }

    // MARK: - Achievements

    private var achievementsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("ACHIEVEMENTS · \(achievements.count) / \(AchievementType.allCases.count)")
                    .font(.system(size: 11, weight: .bold))
                    .tracking(2)
                    .foregroundStyle(.secondary)

                Spacer()

                NavigationLink(destination: AchievementsView()) {
                    Text("All →")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(AppColors.accent)
                }
            }

            if unlockedAchievements.isEmpty {
                Text("Complete exercises to unlock achievements")
                    .font(.system(size: 13))
                    .foregroundStyle(.secondary)
                    .padding(.vertical, 8)
            } else {
                VStack(spacing: 0) {
                    ForEach(Array(unlockedAchievements.prefix(4).enumerated()), id: \.element.id) { index, achievement in
                        achievementRow(index: index + 1, achievement: achievement)

                        if index < min(3, unlockedAchievements.count - 1) {
                            Divider()
                                .padding(.leading, 36)
                        }
                    }
                }
            }
        }
    }

    private func achievementRow(index: Int, achievement: Achievement) -> some View {
        HStack(spacing: 12) {
            Text(String(format: "%02d", index))
                .font(.system(size: 14, weight: .medium, design: .monospaced))
                .foregroundStyle(.secondary)
                .frame(width: 24)

            VStack(alignment: .leading, spacing: 2) {
                Text(achievement.displayName)
                    .font(.system(size: 15, weight: .bold))
                Text(achievement.requirementDescription)
                    .font(.system(size: 12, design: .monospaced))
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }

            Spacer()

            Text("UNLOCKED")
                .font(.system(size: 9, weight: .black))
                .foregroundStyle(.white)
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(AppColors.mint, in: Capsule())
        }
        .padding(.vertical, 10)
    }

    // MARK: - Settings Button

    private var settingsButton: some View {
        Button {
            showingSettings = true
        } label: {
            HStack(spacing: 10) {
                Image(systemName: "gearshape.fill")
                    .font(.system(size: 16))
                    .foregroundStyle(.secondary)

                Text("Settings")
                    .font(.subheadline.weight(.medium))

                Spacer()

                Image(systemName: "chevron.right")
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(.tertiary)
            }
            .padding(.vertical, 12)
        }
        .buttonStyle(.plain)
    }
}
