import SwiftUI
import SwiftData

struct SpacedRepetitionView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @Query private var users: [User]
    @Query private var allCards: [SpacedRepetitionCard]

    let category: CardCategory
    @State private var viewModel = SpacedRepetitionViewModel()
    @State private var hasInitialized = false

    private var user: User? { users.first }
    private var categoryCards: [SpacedRepetitionCard] {
        allCards.filter { $0.category == category }
    }

    var body: some View {
        VStack(spacing: 0) {
            if viewModel.isSessionComplete {
                sessionCompleteView
            } else if let card = viewModel.currentCard {
                cardView(card)
            } else {
                emptyStateView
            }
        }
        .navigationTitle(category.displayName)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                if !viewModel.isSessionComplete && !viewModel.sessionCards.isEmpty {
                    Text("\(viewModel.currentCardIndex + 1)/\(viewModel.sessionCards.count)")
                        .font(.caption.weight(.medium))
                        .foregroundStyle(.secondary)
                }
            }
        }
        .onAppear {
            guard !hasInitialized else { return }
            hasInitialized = true
            initializeCards()
            viewModel.startSession(cards: categoryCards)
        }
    }

    private func cardView(_ card: SpacedRepetitionCard) -> some View {
        VStack(spacing: 24) {
            ProgressView(value: viewModel.progress)
                .tint(AppColors.accent)
                .padding(.horizontal)

            Spacer()

            VStack(spacing: 16) {
                Text("Remember this:")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)

                Text(card.prompt)
                    .font(.title2.weight(.semibold))
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 24)
            }

            Spacer()

            if viewModel.isRevealed {
                VStack(spacing: 12) {
                    Text("Answer:")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Text(card.answer)
                        .font(.title3.weight(.medium))
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 24)
                }

                Spacer()

                VStack(spacing: 8) {
                    Text("How well did you remember?")
                        .font(.caption)
                        .foregroundStyle(.secondary)

                    HStack(spacing: 12) {
                        ForEach(SelfRating.allCases, id: \.rawValue) { rating in
                            Button {
                                UIImpactFeedbackGenerator(style: rating.rawValue >= 2 ? .light : .medium).impactOccurred()
                                viewModel.rate(rating)
                            } label: {
                                Text(rating.displayName)
                                    .font(.subheadline.weight(.semibold))
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, 14)
                                    .background(ratingColor(rating).opacity(0.15), in: RoundedRectangle(cornerRadius: 12))
                                    .foregroundStyle(ratingColor(rating))
                            }
                        }
                    }
                }
                .padding(.horizontal)
            } else {
                Button {
                    withAnimation(.easeInOut(duration: 0.2)) {
                        viewModel.reveal()
                    }
                } label: {
                    Text("Show Answer")
                        .accentButton()
                }
                .padding(.horizontal)
            }
        }
        .padding(.vertical, 24)
    }

    private var sessionCompleteView: some View {
        VStack(spacing: 24) {
            Spacer()

            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 64))
                .foregroundStyle(AppColors.accent)

            Text("Session Complete!")
                .font(.title.weight(.bold))

            VStack(spacing: 8) {
                Text("Score: \(viewModel.sessionScore.percentString)")
                    .font(.title2)
                Text("\(viewModel.sessionCards.count) cards reviewed")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                Text("Time: \(viewModel.durationSeconds.durationString)")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            Button {
                saveExercise()
                dismiss()
            } label: {
                Text("Done")
                    .accentButton()
            }
            .padding(.horizontal, 32)
        }
        .padding(.vertical, 24)
    }

    private var emptyStateView: some View {
        VStack(spacing: 16) {
            Spacer()
            Image(systemName: "tray")
                .font(.system(size: 48))
                .foregroundStyle(.secondary)
            Text("No cards due for review")
                .font(.headline)
            Text("Check back later or try another category")
                .font(.subheadline)
                .foregroundStyle(.secondary)
            Spacer()
        }
    }

    private func ratingColor(_ rating: SelfRating) -> Color {
        switch rating {
        case .again: return AppColors.error
        case .hard: return AppColors.warning
        case .good: return AppColors.accent
        case .easy: return .blue
        }
    }

    private func initializeCards() {
        if categoryCards.isEmpty {
            let newCards = SpacedRepetitionContent.createInitialCards(for: category)
            for card in newCards {
                modelContext.insert(card)
            }
        }
    }

    private func saveExercise() {
        let exercise = Exercise(
            type: .spacedRepetition,
            difficulty: 1,
            score: viewModel.sessionScore,
            durationSeconds: viewModel.durationSeconds
        )
        modelContext.insert(exercise)

        let descriptor = FetchDescriptor<DailySession>(
            sortBy: [SortDescriptor(\.date, order: .reverse)]
        )
        let allSessions = (try? modelContext.fetch(descriptor)) ?? []
        let session: DailySession
        if let existing = allSessions.first(where: { Calendar.current.isDateInToday($0.date) }) {
            session = existing
        } else {
            session = DailySession()
            modelContext.insert(session)
        }
        session.addExercise(exercise)
        user?.updateStreak()
        NotificationService.shared.cancelStreakRisk()
        if let streak = user?.currentStreak {
            NotificationService.shared.scheduleMilestone(streak: streak)
        }
    }
}
