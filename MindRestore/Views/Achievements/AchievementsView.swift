import SwiftUI
import SwiftData

struct AchievementsView: View {
    @Query private var achievements: [Achievement]
    @Query private var users: [User]
    @State private var selectedCategory: AchievementCategory?

    private var user: User? { users.first }
    private var unlockedTypes: Set<AchievementType> {
        Set(achievements.compactMap { $0.type })
    }

    private var filteredTypes: [AchievementType] {
        let types: [AchievementType]
        if let category = selectedCategory {
            types = AchievementType.allCases.filter { $0.category == category }
        } else {
            types = Array(AchievementType.allCases)
        }
        // Unlocked first, then locked
        return types.sorted { a, b in
            let aUnlocked = unlockedTypes.contains(a)
            let bUnlocked = unlockedTypes.contains(b)
            if aUnlocked != bUnlocked { return aUnlocked }
            return false
        }
    }

    private var unlockedCount: Int { achievements.count }
    private var totalCount: Int { AchievementType.allCases.count }

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                // Header count
                Text("ACHIEVEMENTS · \(unlockedCount) / \(totalCount)")
                    .font(.system(size: 11, weight: .bold))
                    .tracking(2)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .leading)

                // Category filter
                categoryFilter

                // Achievement rows
                VStack(spacing: 0) {
                    ForEach(Array(filteredTypes.enumerated()), id: \.element.rawValue) { index, type in
                        let isUnlocked = unlockedTypes.contains(type)
                        achievementRow(
                            index: index + 1,
                            type: type,
                            isUnlocked: isUnlocked
                        )

                        if index < filteredTypes.count - 1 {
                            Divider()
                                .padding(.leading, 36)
                        }
                    }
                }
            }
            .padding(.horizontal)
            .padding(.top, 8)
            .padding(.bottom, 32)
        }
        .pageBackground()
        .navigationTitle("Achievements")
        .navigationBarTitleDisplayMode(.inline)
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
            let isSelected = selectedCategory == category
            HStack(spacing: 4) {
                Text(title)
                    .font(.system(size: 12, weight: .semibold))
                Text("\(unlocked)/\(count)")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(isSelected ? AppColors.accent.opacity(0.8) : .secondary)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background(
                isSelected
                    ? AnyShapeStyle(AppColors.accent.opacity(0.18))
                    : AnyShapeStyle(AppColors.cardSurface),
                in: Capsule()
            )
            .overlay(
                Capsule()
                    .stroke(
                        isSelected ? AppColors.accent : AppColors.cardBorder,
                        lineWidth: 1
                    )
            )
            .foregroundStyle(isSelected ? AppColors.accent : .secondary)
        }
    }

    // MARK: - Achievement Row

    private func achievementRow(index: Int, type: AchievementType, isUnlocked: Bool) -> some View {
        HStack(spacing: 12) {
            // Number
            Text(String(format: "%02d", index))
                .font(.system(size: 14, weight: .medium, design: .monospaced))
                .foregroundStyle(isUnlocked ? .secondary : .quaternary)
                .frame(width: 24)

            // Name + description
            VStack(alignment: .leading, spacing: 2) {
                Text(type.displayName)
                    .font(.system(size: 15, weight: .bold))
                    .foregroundStyle(isUnlocked ? .primary : .secondary)
                Text(type.requirementDescription)
                    .font(.system(size: 12, design: .monospaced))
                    .foregroundStyle(isUnlocked ? .secondary : .quaternary)
                    .lineLimit(1)
            }

            Spacer()

            // Status
            if isUnlocked {
                VStack(alignment: .trailing, spacing: 3) {
                    Text("UNLOCKED")
                        .font(.system(size: 9, weight: .black))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(AppColors.mint, in: Capsule())

                    if let achievement = achievements.first(where: { $0.typeRaw == type.rawValue }) {
                        Text(achievement.unlockedAt.formatted(.dateTime.month(.abbreviated).day()))
                            .font(.system(size: 10, weight: .medium, design: .monospaced))
                            .foregroundStyle(.tertiary)
                    }
                }
            } else if type.targetValue > 1 {
                let current = min(type.currentProgress(user: user), type.targetValue)
                VStack(alignment: .trailing, spacing: 3) {
                    Text("\(current)/\(type.targetValue)")
                        .font(.system(size: 12, weight: .bold, design: .rounded))
                        .foregroundStyle(.tertiary)

                    ProgressView(value: Double(current), total: Double(type.targetValue))
                        .tint(AppColors.accent.opacity(0.5))
                        .frame(width: 60)
                }
            } else {
                Image(systemName: "lock.fill")
                    .font(.system(size: 12))
                    .foregroundStyle(.quaternary)
            }
        }
        .padding(.vertical, 10)
        .opacity(isUnlocked ? 1 : 0.6)
    }
}
