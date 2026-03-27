import SwiftUI
import SwiftData

struct AchievementsView: View {
    @Query private var achievements: [Achievement]
    @Query private var users: [User]
    @State private var selectedCategory: AchievementCategory?
    @State private var selectedAchievementType: AchievementType?

    private var user: User? { users.first }
    private var unlockedTypes: Set<AchievementType> {
        Set(achievements.compactMap { $0.type })
    }

    private var filteredTypes: [AchievementType] {
        if let category = selectedCategory {
            return AchievementType.allCases.filter { $0.category == category }
        }
        return AchievementType.allCases
    }

    private var unlockedCount: Int { achievements.count }
    private var totalCount: Int { AchievementType.allCases.count }

    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                // Progress header
                progressHeader

                // Category filter
                categoryFilter

                // Achievement grid
                achievementGrid
            }
            .padding(.horizontal)
            .padding(.top, 8)
            .padding(.bottom, 32)
        }
        .pageBackground()
        .navigationTitle("Achievements")
        .navigationBarTitleDisplayMode(.inline)
        .sheet(item: $selectedAchievementType) { type in
            AchievementDetailView(
                type: type,
                achievement: achievements.first(where: { $0.typeRaw == type.rawValue }),
                user: user
            )
            .presentationDetents([.medium, .large])
            .presentationDragIndicator(.visible)
        }
    }

    // MARK: - Progress Header

    private var progressHeader: some View {
        VStack(spacing: 14) {
            ZStack {
                Circle()
                    .fill(AppColors.accent.opacity(0.08))
                    .frame(width: 112, height: 112)

                Circle()
                    .stroke(AppColors.accent.opacity(0.20), lineWidth: 8)
                    .frame(width: 84, height: 84)

                Circle()
                    .trim(from: 0, to: totalCount > 0 ? CGFloat(unlockedCount) / CGFloat(totalCount) : 0)
                    .stroke(
                        AngularGradient(
                            colors: [AppColors.accent, AppColors.teal, AppColors.violet, AppColors.accent],
                            center: .center
                        ),
                        style: StrokeStyle(lineWidth: 8, lineCap: .round)
                    )
                    .frame(width: 84, height: 84)
                    .rotationEffect(.degrees(-90))

                VStack(spacing: 0) {
                    Text("\(unlockedCount)")
                        .font(.system(size: 26, weight: .bold, design: .monospaced))
                        .foregroundStyle(AppColors.accent)
                    Text("/\(totalCount)")
                        .font(.caption2.weight(.medium))
                        .foregroundStyle(.secondary)
                }
            }

            Text("\(unlockedCount) of \(totalCount) Unlocked")
                .font(.subheadline.weight(.semibold))

            if let user {
                HStack(spacing: 16) {
                    Label("Level \(user.level)", systemImage: "star.fill")
                        .font(.caption.weight(.medium))
                        .foregroundStyle(AppColors.violet)
                    Label("\(user.totalXP) XP", systemImage: "bolt.fill")
                        .font(.caption.weight(.medium))
                        .foregroundStyle(AppColors.teal)
                }
            }
        }
        .frame(maxWidth: .infinity)
        .heroCard(color: AppColors.accent)
    }

    // MARK: - Category Filter

    private var categoryFilter: some View {
        ScrollView(.horizontal) {
            HStack(spacing: 8) {
                filterPill(title: "All", category: nil, count: totalCount, unlocked: unlockedCount)

                ForEach(AchievementCategory.allCases, id: \.rawValue) { category in
                    let catTypes = AchievementType.allCases.filter { $0.category == category }
                    let catUnlocked = catTypes.filter { unlockedTypes.contains($0) }.count
                    filterPill(title: category.rawValue, category: category, count: catTypes.count, unlocked: catUnlocked)
                }
            }
        }
        .scrollIndicators(.hidden)
    }

    private func filterPill(title: String, category: AchievementCategory?, count: Int, unlocked: Int) -> some View {
        Button {
            withAnimation(.spring(response: 0.3)) {
                selectedCategory = category
            }
        } label: {
            HStack(spacing: 4) {
                Text(title)
                    .font(.caption.weight(.semibold))
                Text("\(unlocked)/\(count)")
                    .font(.caption2.weight(.medium))
                    .foregroundStyle(selectedCategory == category ? .white.opacity(0.7) : .secondary)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background(
                selectedCategory == category
                    ? AnyShapeStyle(category?.gradient ?? AppColors.accentGradient)
                    : AnyShapeStyle(Color.white.opacity(0.08)),
                in: Capsule()
            )
            .foregroundStyle(selectedCategory == category ? .white : .primary)
        }
    }

    // MARK: - Achievement Grid

    private var achievementGrid: some View {
        LazyVGrid(columns: [GridItem(.flexible(), spacing: 12), GridItem(.flexible(), spacing: 12)], spacing: 12) {
            ForEach(filteredTypes, id: \.rawValue) { type in
                let isUnlocked = unlockedTypes.contains(type)
                Button {
                    selectedAchievementType = type
                } label: {
                    achievementCard(type: type, isUnlocked: isUnlocked)
                }
                .buttonStyle(.plain)
            }
        }
    }

    private func achievementCard(type: AchievementType, isUnlocked: Bool) -> some View {
        VStack(spacing: 10) {
            ZStack {
                if isUnlocked {
                    Circle()
                        .fill(type.color.opacity(0.10))
                        .frame(width: 72, height: 72)
                }

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
                    .frame(width: 52, height: 52)

                Image(systemName: isUnlocked ? type.icon : "lock.fill")
                    .font(.system(size: 24, weight: .semibold))
                    .foregroundStyle(isUnlocked ? .white : .secondary)
            }

            Text(type.displayName)
                .font(.caption.weight(.bold))
                .multilineTextAlignment(.center)
                .lineLimit(2)
                .foregroundStyle(isUnlocked ? .primary : .secondary)

            Text(isUnlocked ? type.description : type.requirementDescription)
                .font(.caption2)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .lineLimit(3)

            if isUnlocked, let achievement = achievements.first(where: { $0.typeRaw == type.rawValue }) {
                Text(achievement.unlockedAt.formatted(.dateTime.month(.abbreviated).day()))
                    .font(.caption2.weight(.medium))
                    .foregroundStyle(type.color)
            } else if !isUnlocked && type.targetValue > 1 {
                let current = min(type.currentProgress(user: user), type.targetValue)
                let progress = Double(current) / Double(type.targetValue)
                VStack(spacing: 3) {
                    ProgressView(value: progress)
                        .tint(type.color)
                    Text("\(current) / \(type.targetValue)")
                        .font(.system(size: 9, weight: .medium, design: .rounded))
                        .foregroundStyle(.tertiary)
                }
            }
        }
        .padding(12)
        .frame(maxWidth: .infinity)
        .background(
            ZStack {
                RoundedRectangle(cornerRadius: 12)
                    .fill(AppColors.cardSurface)
                if isUnlocked {
                    RoundedRectangle(cornerRadius: 12)
                        .fill(
                            LinearGradient(
                                colors: [type.color.opacity(0.06), .clear],
                                startPoint: .top,
                                endPoint: .bottom
                            )
                        )
                }
            }
        )
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(
                    isUnlocked
                        ? LinearGradient(
                            colors: [type.color.opacity(0.35), type.color.opacity(0.1)],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                        : LinearGradient(colors: [Color.clear, Color.clear], startPoint: .top, endPoint: .bottom),
                    lineWidth: 1
                )
        )
        .opacity(isUnlocked ? 1 : 0.55)
        .accessibilityElement(children: .combine)
        .accessibilityLabel({
            if isUnlocked, let achievement = achievements.first(where: { $0.typeRaw == type.rawValue }) {
                return "\(type.displayName), unlocked on \(achievement.unlockedAt.formatted(.dateTime.month(.abbreviated).day()))"
            } else {
                return "\(type.displayName), locked"
            }
        }())
    }
}
