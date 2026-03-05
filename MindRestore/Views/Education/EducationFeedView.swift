import SwiftUI

struct EducationFeedView: View {
    @State private var readCardIDs: Set<UUID> = []

    private var cards: [PsychoEducationCard] {
        EducationContent.cards.sorted { card1, card2 in
            let read1 = readCardIDs.contains(card1.id)
            let read2 = readCardIDs.contains(card2.id)
            if read1 != read2 { return !read1 }
            return card1.sortOrder < card2.sortOrder
        }
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                LazyVStack(spacing: 12) {
                    ForEach(cards) { card in
                        NavigationLink {
                            EducationDetailView(card: card)
                                .onAppear { readCardIDs.insert(card.id) }
                        } label: {
                            HStack(spacing: 14) {
                                Image(systemName: card.category.icon)
                                    .font(.title3)
                                    .foregroundStyle(AppColors.accent)
                                    .frame(width: 40, height: 40)
                                    .background(AppColors.accent.opacity(0.1), in: RoundedRectangle(cornerRadius: 10))

                                VStack(alignment: .leading, spacing: 2) {
                                    Text(card.title)
                                        .font(.subheadline.weight(.semibold))
                                        .foregroundStyle(.primary)
                                        .lineLimit(2)
                                        .multilineTextAlignment(.leading)
                                    Text(card.category.displayName)
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }

                                Spacer()

                                if readCardIDs.contains(card.id) {
                                    Image(systemName: "checkmark.circle.fill")
                                        .foregroundStyle(AppColors.accent)
                                        .font(.caption)
                                } else {
                                    Image(systemName: "chevron.right")
                                        .font(.caption2.weight(.semibold))
                                        .foregroundStyle(Color.gray.opacity(0.4))
                                }
                            }
                            .appCard()
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.horizontal)
                .padding(.top, 8)
                .padding(.bottom, 32)
            }
            .pageBackground()
            .navigationTitle("Learn")
        }
    }
}
