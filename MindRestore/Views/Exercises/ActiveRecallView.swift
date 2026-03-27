import SwiftUI
import SwiftData

struct ActiveRecallView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @Environment(AchievementService.self) private var achievementService
    @Environment(TrainingSessionManager.self) private var trainingManager
    @Environment(PaywallTriggerService.self) private var paywallTrigger
    @Environment(StoreService.self) private var storeService
    @Environment(GameCenterService.self) private var gameCenterService
    @Query private var users: [User]

    @State private var viewModel = ActiveRecallViewModel()
    @State private var challengeStarted = false
    @State private var strategyTip: StrategyTip?
    @State private var showingPaywall = false

    private var user: User? { users.first }
    private var isProUser: Bool { storeService.isProUser }

    var body: some View {
        VStack(spacing: 0) {
            if !challengeStarted {
                startView
                    .transition(.opacity)
            } else {
                switch viewModel.phase {
                case .reading:
                    readingView
                        .transition(.opacity)
                case .answering:
                    answeringView
                        .transition(.opacity)
                case .results:
                    resultsView
                        .transition(.opacity)
                }
            }
        }
        .animation(.easeInOut(duration: 0.3), value: challengeStarted)
        .navigationTitle("Active Recall")
        .navigationBarTitleDisplayMode(.inline)
        .animation(.easeInOut(duration: 0.3), value: viewModel.phase)
        .onDisappear {
            viewModel.cancelTimer()
        }
        .sheet(isPresented: $showingPaywall) {
            PaywallView(isHighIntent: true)
        }
        .onChange(of: viewModel.phase) { _, newPhase in
            if newPhase == .results {
                if viewModel.score >= 0.7 {
                    SoundService.shared.playCorrect()
                } else {
                    SoundService.shared.playWrong()
                }
                SoundService.shared.playComplete()
                strategyTip = StrategyTipService.shared.freshTip(for: .activeRecall)
            }
        }
    }

    private var startView: some View {
        VStack(spacing: 32) {
            Spacer()

            ZStack {
                Circle()
                    .fill(AppColors.cardBorder)
                    .frame(width: 120, height: 120)
                    .accessibilityHidden(true)
                Image(systemName: "brain.head.profile")
                    .font(.system(size: 52, weight: .medium))
                    .foregroundStyle(AppColors.accent)
            }

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
            .accessibilityHint("Starts the exercise")
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
                    .accessibilityLabel("Time remaining: \(Int(viewModel.timeRemaining)) seconds")
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
                            .background(AppColors.cardSurface, in: RoundedRectangle(cornerRadius: 12))
                        }
                    }
                }
                .padding(.horizontal)
            }

            Button {
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
                ZStack {
                    Circle()
                        .fill(AppColors.cardBorder)
                        .frame(width: 100, height: 100)
                    Image(systemName: viewModel.score >= 0.7 ? "checkmark.circle.fill" : "exclamationmark.circle.fill")
                        .font(.system(size: 64))
                        .foregroundStyle(viewModel.score >= 0.7 ? AppColors.accent : AppColors.warning)
                }
                .padding(.top, 24)

                Text(viewModel.score >= 0.7 ? "Great Job!" : "Keep Practicing!")
                    .font(.title.weight(.bold))

                Text("Score: \(viewModel.score.percentString)")
                    .font(.title2)
                    .foregroundStyle(AppColors.accent)
                    .accessibilityLabel("Score: \(viewModel.score.percentString)")

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
                    .glowingCard(color: AppColors.accent, intensity: 0.08)
                    .padding(.horizontal)
                }

                if let tip = strategyTip {
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Image(systemName: "lightbulb.fill")
                                .foregroundStyle(.yellow)
                            Text(tip.title)
                                .font(.subheadline.weight(.bold))
                        }
                        Text(tip.body)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        Text(tip.researchNote)
                            .font(.caption2)
                            .foregroundStyle(.tertiary)
                            .italic()
                    }
                    .appCard()
                    .padding(.horizontal, 20)
                }

                LeaderboardRankCard(
                    exerciseType: .activeRecall,
                    userScore: Int(viewModel.score * 100),
                )
                .padding(.horizontal)

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
        paywallTrigger.recordExerciseCompleted()
        trainingManager.addTrainingTime(viewModel.durationSeconds)

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

        if let user {
            _ = ContentView.awardXP(
                user: user,
                score: viewModel.score,
                difficulty: viewModel.currentChallenge?.difficulty ?? 1,
                achievementService: achievementService,
                modelContext: modelContext,
                gameCenterService: gameCenterService,
                exerciseType: .activeRecall
            )
        }
    }
}
