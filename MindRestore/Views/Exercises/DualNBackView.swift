import SwiftUI
import SwiftData

struct DualNBackView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @Environment(StoreService.self) private var storeService
    @Query private var users: [User]

    @State private var viewModel = DualNBackViewModel()
    @State private var selectedN: Int = 1
    @State private var gameStarted = false

    private var user: User? { users.first }
    private var isProUser: Bool { storeService.isProUser || (user?.isProUser ?? false) }

    var body: some View {
        VStack(spacing: 0) {
            if viewModel.showResults {
                resultsView
            } else if gameStarted {
                gameView
            } else {
                setupView
            }
        }
        .navigationTitle("Dual N-Back")
        .navigationBarTitleDisplayMode(.inline)
    }

    private var setupView: some View {
        VStack(spacing: 32) {
            Spacer()

            Image(systemName: "square.grid.3x3")
                .font(.system(size: 64))
                .foregroundStyle(AppColors.accent)

            VStack(spacing: 8) {
                Text("Dual N-Back")
                    .font(.title.weight(.bold))
                Text("Train your working memory")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }

            VStack(spacing: 12) {
                Text("N Level: \(selectedN)")
                    .font(.headline)

                HStack(spacing: 12) {
                    ForEach(1...5, id: \.self) { n in
                        Button {
                            if n == 1 || isProUser {
                                selectedN = n
                            }
                        } label: {
                            Text("\(n)")
                                .font(.headline)
                                .frame(width: 48, height: 48)
                                .background(
                                    selectedN == n ? AppColors.accent : Color(UIColor.secondarySystemGroupedBackground),
                                    in: RoundedRectangle(cornerRadius: 12)
                                )
                                .foregroundStyle(selectedN == n ? .white : (n > 1 && !isProUser ? .secondary : .primary))
                                .overlay {
                                    if n > 1 && !isProUser {
                                        Image(systemName: "lock.fill")
                                            .font(.caption2)
                                            .foregroundStyle(.secondary)
                                            .offset(x: 14, y: -14)
                                    }
                                }
                        }
                    }
                }

                if !isProUser {
                    Text("Free: N=1 position only. Pro: Adaptive N=1-5 dual mode.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                }
            }
            .appCard()
            .padding(.horizontal)

            Spacer()

            Button {
                gameStarted = true
                viewModel.startGame(n: selectedN, dual: isProUser)
            } label: {
                Text("Start")
                    .accentButton()
            }
            .padding(.horizontal, 32)
        }
        .padding(.vertical, 24)
    }

    private var gameView: some View {
        VStack(spacing: 24) {
            HStack {
                Text("N = \(viewModel.currentN)")
                    .font(.headline)
                    .foregroundStyle(AppColors.accent)
                Spacer()
                Text("Trial \(viewModel.trialIndex + 1) / \(viewModel.totalTrials)")
                    .font(.caption.weight(.medium))
                    .foregroundStyle(.secondary)
            }
            .padding(.horizontal)

            ProgressView(value: Double(viewModel.trialIndex), total: Double(viewModel.totalTrials))
                .tint(AppColors.accent)
                .padding(.horizontal)

            Spacer()

            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 8), count: 3), spacing: 8) {
                ForEach(0..<9, id: \.self) { index in
                    RoundedRectangle(cornerRadius: 12)
                        .fill(index == viewModel.currentPosition ? AppColors.accent : Color(UIColor.tertiarySystemFill))
                        .aspectRatio(1, contentMode: .fit)
                        .animation(.easeInOut(duration: 0.15), value: viewModel.currentPosition)
                }
            }
            .padding(.horizontal, 40)

            if viewModel.isDual && !viewModel.currentLetter.isEmpty {
                Text(viewModel.currentLetter)
                    .font(.system(size: 36, weight: .bold, design: .rounded))
                    .foregroundStyle(.secondary)
            }

            Spacer()

            HStack(spacing: 16) {
                Button {
                    viewModel.tapPosition()
                } label: {
                    VStack(spacing: 4) {
                        Image(systemName: "square.grid.3x3")
                        Text("Position")
                            .font(.caption)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
                    .background(AppColors.accent.opacity(0.15), in: RoundedRectangle(cornerRadius: 14))
                    .foregroundStyle(AppColors.accent)
                }

                if viewModel.isDual {
                    Button {
                        viewModel.tapSound()
                    } label: {
                        VStack(spacing: 4) {
                            Image(systemName: "speaker.wave.2")
                            Text("Sound")
                                .font(.caption)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                        .background(Color.blue.opacity(0.15), in: RoundedRectangle(cornerRadius: 14))
                        .foregroundStyle(.blue)
                    }
                }
            }
            .font(.headline)
            .padding(.horizontal)
        }
        .padding(.vertical, 24)
    }

    private var resultsView: some View {
        VStack(spacing: 24) {
            Spacer()

            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 64))
                .foregroundStyle(AppColors.accent)

            Text("Round Complete!")
                .font(.title.weight(.bold))

            VStack(spacing: 12) {
                resultRow(label: "Position Accuracy", value: viewModel.positionScore.percentString)
                if viewModel.isDual {
                    resultRow(label: "Sound Accuracy", value: viewModel.soundScore.percentString)
                }
                resultRow(label: "Overall Score", value: viewModel.overallScore.percentString)
                resultRow(label: "Time", value: viewModel.durationSeconds.durationString)

                Divider()

                HStack {
                    Text("Next recommended N:")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                    Spacer()
                    Text("\(viewModel.nextN)")
                        .font(.headline)
                        .foregroundStyle(AppColors.accent)
                }
            }
            .appCard()
            .padding(.horizontal)

            Spacer()

            VStack(spacing: 12) {
                Button {
                    selectedN = viewModel.nextN
                    gameStarted = true
                    viewModel.startGame(n: selectedN, dual: isProUser)
                } label: {
                    Text("Play Again (N=\(viewModel.nextN))")
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
        }
        .padding(.vertical, 24)
    }

    private func resultRow(label: String, value: String) -> some View {
        HStack {
            Text(label)
                .font(.subheadline)
                .foregroundStyle(.secondary)
            Spacer()
            Text(value)
                .font(.subheadline.weight(.semibold))
        }
    }

    private func saveExercise() {
        let exercise = Exercise(
            type: .dualNBack,
            difficulty: viewModel.currentN,
            score: viewModel.overallScore,
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
