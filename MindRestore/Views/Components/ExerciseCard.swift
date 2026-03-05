import SwiftUI

struct ExerciseCard: View {
    let title: String
    let subtitle: String
    let icon: String
    let isLocked: Bool

    init(type: ExerciseType, isLocked: Bool) {
        self.title = type.displayName
        self.subtitle = type.description
        self.icon = type.icon
        self.isLocked = isLocked
    }

    init(title: String, subtitle: String, icon: String, isLocked: Bool) {
        self.title = title
        self.subtitle = subtitle
        self.icon = icon
        self.isLocked = isLocked
    }

    var body: some View {
        HStack(spacing: 14) {
            Image(systemName: icon)
                .font(.title2)
                .foregroundStyle(isLocked ? .secondary : AppColors.accent)
                .frame(width: 44, height: 44)
                .background(
                    (isLocked ? Color.gray : AppColors.accent).opacity(0.1),
                    in: RoundedRectangle(cornerRadius: 12)
                )

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.headline)
                    .foregroundStyle(.primary)
                Text(subtitle)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            if isLocked {
                Image(systemName: "lock.fill")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            } else {
                Image(systemName: "chevron.right")
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(Color.gray.opacity(0.4))
            }
        }
        .appCard()
    }
}
