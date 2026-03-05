import SwiftUI

struct EducationDetailView: View {
    let card: PsychoEducationCard

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                // Header
                VStack(alignment: .leading, spacing: 8) {
                    HStack(spacing: 8) {
                        Image(systemName: card.category.icon)
                            .foregroundStyle(AppColors.accent)
                        Text(card.category.displayName)
                            .font(.subheadline)
                            .foregroundStyle(AppColors.accent)
                    }

                    Text(card.title)
                        .font(.title2.weight(.bold))
                }

                // Body
                Text(card.body)
                    .font(.body)
                    .lineSpacing(6)
                    .foregroundStyle(.primary)
            }
            .padding(24)
            .padding(.bottom, 32)
        }
        .pageBackground()
        .navigationBarTitleDisplayMode(.inline)
    }
}
