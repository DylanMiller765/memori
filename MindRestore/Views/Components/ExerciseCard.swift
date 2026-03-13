import SwiftUI

struct ExerciseCard: View {
    let title: String
    let subtitle: String
    let icon: String
    let isLocked: Bool
    var color: Color = AppColors.accent

    init(type: ExerciseType, isLocked: Bool) {
        self.title = type.displayName
        self.subtitle = type.description
        self.icon = type.icon
        self.isLocked = isLocked
        self.color = Self.exerciseColor(for: type)
    }

    init(title: String, subtitle: String, icon: String, isLocked: Bool, color: Color = AppColors.accent) {
        self.title = title
        self.subtitle = subtitle
        self.icon = icon
        self.isLocked = isLocked
        self.color = color
    }

    static func exerciseColor(for type: ExerciseType) -> Color {
        switch type {
        case .reactionTime: return AppColors.coral
        case .colorMatch: return AppColors.violet
        case .speedMatch: return AppColors.sky
        case .visualMemory: return AppColors.indigo
        case .sequentialMemory: return AppColors.teal
        case .mathSpeed: return AppColors.amber
        case .dualNBack: return AppColors.sky
        case .spacedRepetition: return AppColors.violet
        case .activeRecall: return AppColors.amber
        case .chunkingTraining: return AppColors.teal
        case .prospectiveMemory: return AppColors.coral
        case .memoryPalace: return AppColors.indigo
        case .wordScramble: return AppColors.rose
        case .memoryChain: return AppColors.mint
        }
    }

    var body: some View {
        HStack(spacing: 14) {
            ZStack {
                RoundedRectangle(cornerRadius: 12)
                    .fill(isLocked ? .gray : color)
                    .frame(width: 48, height: 48)

                Image(systemName: isLocked ? "lock.fill" : icon)
                    .font(.system(size: 20, weight: .semibold))
                    .foregroundStyle(.white)
            }

            VStack(alignment: .leading, spacing: 3) {
                Text(title)
                    .font(.subheadline.weight(.bold))
                    .foregroundStyle(.primary)
                Text(subtitle)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }

            Spacer()

            if !isLocked {
                Image(systemName: "chevron.right")
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(color.opacity(0.5))
            }
        }
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(AppColors.cardSurface)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke((isLocked ? .gray : color).opacity(0.1), lineWidth: 1)
        )
        .accessibilityLabel("\(title), \(isLocked ? "locked" : "unlocked")")
    }
}
