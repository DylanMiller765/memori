import SwiftUI
import SwiftData

struct ActiveRecallView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @Query private var users: [User]

    @State private var viewModel = ActiveRecallViewModel()
    @State private var challengeStarted = false

    private var user: User? { users.first }

    var body: some View {
        VStack(spacing: 0) {
            if !challengeStarted {
                startView
            } else {
                switch viewModel.phase {
                case .reading:
                    readingView
                case .answering:
                    answeringView
                case .results:
                    resultsView
                }
            }
        }
        .navigationTitle("Active Recall")
        .navigationBarTitleDisplayMode(.inline)
    }

    private var startView: some View {
        VStack(spacing: 32) {
            Spacer()

            Image(systemName: "brain.head.profile")
                .font(.system(size: 64))
                .foregroundStyle(AppColors.accent)

            VStack(spacing: 8) {
                Text("Active Recall")
                    .font(.title.weight(.bold))
                Text("Read carefully, then answer from memory")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            Button {
                challengeStarted = true
                viewModel.startChallenge()
            } label: {
                Text("Start Challenge")
                    .accentButton()
            }
            .padding(.horizontal, 32)
        }
        .padding(.vertical, 24)
    }

    private var readingView: some View {
        VStack(spacing: 24) {
            HStack {
                Text(viewModel.currentChallenge?.title ?? "")
                    .font(.headline)
                Spacer()
                Text("\(Int(viewModel.timeRemaining))s")
                    .font(.headline.monospacedDigit())
                    .foregroundStyle(viewModel.timeRemaining <= 5 ? AppColors.error : AppColors.accent)
            }
            .padding(.horizontal)

            ProgressView(value: max(0, viewModel.timeRemaining), total: viewModel.currentChallenge?.displayDuration ?? 30)
                .tint(AppColors.accent)
                .padding(.horizontal)

            ScrollView {
                Text(viewModel.currentChallenge?.displayContent ?? "")
                    .font(.body)
                    .lineSpacing(6)
                    .padding(24)
            }
            .appCard()
            .padding(.horizontal)

            Spacer()

            Button {
                viewModel.skipToAnswering()
            } label: {
                Text("I'm Ready")
                    .accentButton()
            }
            .padding(.horizontal, 32)
        }
        .padding(.vertical, 24)
    }

    private var answeringView: some View {
        VStack(spacing: 16) {
            Text("Answer from memory")
                .font(.headline)
                .padding(.top)

            ScrollView {
                VStack(spacing: 16) {
                    if let challenge = viewModel.currentChallenge {
                        ForEach(Array(challenge.questions.enumerated()), id: \.offset) { index, question in
                            VStack(alignment: .leading, spacing: 8) {
                                Text(question.question)
                                    .font(.subheadline.weight(.medium))

                                TextField("Your answer...", text: $viewModel.userAnswers[index])
                                    .textFieldStyle(.roundedBorder)
                            }
                            .padding()
                            .background(Color(UIColor.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 12))
                        }
                    }
                }
                .padding(.horizontal)
            }

            Button {
                UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                viewModel.submitAnswers()
            } label: {
                Text("Submit Answers")
                    .accentButton()
            }
            .padding(.horizontal, 32)
        }
        .padding(.vertical, 24)
    }

    private var resultsView: some View {
        ScrollView {
            VStack(spacing: 24) {
                Image(systemName: viewModel.score >= 0.7 ? "checkmark.circle.fill" : "exclamationmark.circle.fill")
                    .font(.system(size: 64))
                    .foregroundStyle(viewModel.score >= 0.7 ? AppColors.accent : AppColors.warning)
                    .padding(.top, 24)

                Text(viewModel.score >= 0.7 ? "Great Job!" : "Keep Practicing!")
                    .font(.title.weight(.bold))

                Text("Score: \(viewModel.score.percentString)")
                    .font(.title2)

                if let challenge = viewModel.currentChallenge {
                    VStack(alignment: .leading, spacing: 12) {
                        ForEach(Array(challenge.questions.enumerated()), id: \.offset) { index, question in
                            VStack(alignment: .leading, spacing: 4) {
                                Text(question.question)
                                    .font(.caption.weight(.medium))
                                HStack {
                                    Text("Your answer: ")
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                    Text(index < viewModel.userAnswers.count ? viewModel.userAnswers[index] : "—")
                                        .font(.caption.weight(.medium))
                                }
                                HStack {
                                    Text("Correct: ")
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                    Text(question.answer)
                                        .font(.caption.weight(.medium))
                                        .foregroundStyle(AppColors.accent)
                                }
                            }
                            if index < challenge.questions.count - 1 {
                                Divider()
                            }
                        }
                    }
                    .appCard()
                    .padding(.horizontal)
                }

                VStack(spacing: 12) {
                    Button {
                        challengeStarted = true
                        viewModel.startChallenge()
                    } label: {
                        Text("Next Challenge")
                            .accentButton()
                    }

                    Button {
                        saveExercise()
                        dismiss()
                    } label: {
                        Text("Done")
                            .font(.headline)
                            .foregroundStyle(.secondary)
                    }
                }
                .padding(.horizontal, 32)
                .padding(.bottom, 32)
            }
        }
    }

    private func saveExercise() {
        let exercise = Exercise(
            type: .activeRecall,
            difficulty: viewModel.currentChallenge?.difficulty ?? 1,
            score: viewModel.score,
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
