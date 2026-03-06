import SwiftUI
import SwiftData

struct DailyChallengeView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @Query private var users: [User]
    @State private var viewModel = DailyChallengeViewModel()

    private var user: User? { users.first }

    var body: some View {
        ZStack {
            Color(UIColor.systemBackground).ignoresSafeArea()

            switch viewModel.phase {
            case .preview:
                previewView
            case .countdown:
                countdownView
            case .memorize:
                memorizeView
            case .recall:
                recallView
            case .results:
                dailyResultsView
            }
        }
        .navigationTitle("Daily Challenge")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear { viewModel.setup() }
        .animation(.easeInOut(duration: 0.3), value: viewModel.phase)
    }

    // MARK: - Preview

    private var previewView: some View {
        VStack(spacing: 32) {
            Spacer()

            Image(systemName: viewModel.challengeType.icon)
                .font(.system(size: 64))
                .foregroundStyle(AppColors.accent)

            VStack(spacing: 8) {
                Text("Today's Challenge")
                    .font(.title.bold())
                Text(viewModel.challengeType.displayName)
                    .font(.title3)
                    .foregroundStyle(AppColors.accent)
                Text(viewModel.challengeType.instruction)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 40)
            }

            VStack(spacing: 4) {
                Text("Same challenge for everyone today")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Text("10s to memorize · 30s to recall")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            Button {
                viewModel.startCountdown()
            } label: {
                Text("Start")
                    .accentButton()
            }
            .padding(.horizontal, 32)
            .padding(.bottom, 16)
        }
    }

    // MARK: - Countdown

    private var countdownView: some View {
        VStack {
            Spacer()
            Text("\(viewModel.countdownValue)")
                .font(.system(size: 120, weight: .black, design: .rounded))
                .foregroundStyle(AppColors.accent)
                .contentTransition(.numericText())
                .animation(.spring(response: 0.3), value: viewModel.countdownValue)
            Spacer()
        }
    }

    // MARK: - Memorize

    private var memorizeView: some View {
        VStack(spacing: 24) {
            HStack {
                Text("MEMORIZE")
                    .font(.caption.weight(.bold))
                    .foregroundStyle(AppColors.accent)
                Spacer()
                Text(String(format: "%.0fs", max(0, viewModel.timeRemaining)))
                    .font(.headline.monospacedDigit())
                    .foregroundStyle(viewModel.timeRemaining <= 3 ? .red : AppColors.accent)
            }
            .padding(.horizontal)

            ProgressView(value: max(0, viewModel.timeRemaining), total: 10)
                .tint(AppColors.accent)
                .padding(.horizontal)

            Spacer()

            if viewModel.challengeType == .speedPattern {
                patternGrid(interactive: false, showHighlights: true)
            } else {
                Text(viewModel.displayContent)
                    .font(viewModel.challengeType == .speedNumbers
                        ? .system(size: 40, weight: .bold, design: .rounded)
                        : .title2.weight(.semibold))
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 24)
            }

            Spacer()
        }
        .padding(.vertical, 24)
    }

    // MARK: - Recall

    private var recallView: some View {
        VStack(spacing: 16) {
            HStack {
                Text("RECALL")
                    .font(.caption.weight(.bold))
                    .foregroundStyle(.orange)
                Spacer()
                Text(String(format: "%.0fs", max(0, viewModel.recallTimeRemaining)))
                    .font(.headline.monospacedDigit())
                    .foregroundStyle(viewModel.recallTimeRemaining <= 5 ? .red : .orange)
            }
            .padding(.horizontal)

            ProgressView(value: max(0, viewModel.recallTimeRemaining), total: 30)
                .tint(.orange)
                .padding(.horizontal)

            if viewModel.challengeType == .speedPattern {
                patternGrid(interactive: true, showHighlights: false)
            } else {
                VStack(spacing: 12) {
                    Text(viewModel.challengeType == .speedNumbers
                        ? "Type the numbers in order"
                        : "Type the words separated by spaces")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)

                    if viewModel.challengeType == .speedNumbers {
                        TextField("Numbers...", text: $viewModel.textInput)
                            .keyboardType(.numberPad)
                            .font(.system(size: 28, weight: .bold, design: .rounded))
                            .multilineTextAlignment(.center)
                            .padding()
                            .background(Color(UIColor.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 16))
                    } else {
                        TextEditor(text: $viewModel.textInput)
                            .font(.body)
                            .frame(height: 120)
                            .padding(8)
                            .background(Color(UIColor.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 16))
                    }
                }
                .padding(.horizontal, 24)
            }

            Spacer()

            Button {
                viewModel.submit()
            } label: {
                Text("Submit")
                    .accentButton()
            }
            .padding(.horizontal, 32)
        }
        .padding(.vertical, 24)
    }

    // MARK: - Pattern Grid

    private func patternGrid(interactive: Bool, showHighlights: Bool) -> some View {
        LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 8), count: viewModel.gridSize), spacing: 8) {
            ForEach(0..<(viewModel.gridSize * viewModel.gridSize), id: \.self) { index in
                let isHighlighted = showHighlights && viewModel.patternCells.contains(index)
                let isSelected = interactive && viewModel.selectedCells.contains(index)

                RoundedRectangle(cornerRadius: 10)
                    .fill(isHighlighted || isSelected ? AppColors.accent : Color(UIColor.tertiarySystemFill))
                    .aspectRatio(1, contentMode: .fit)
                    .onTapGesture {
                        if interactive { viewModel.togglePatternCell(index) }
                    }
                    .animation(.easeInOut(duration: 0.15), value: isSelected)
            }
        }
        .padding(.horizontal, 40)
    }

    // MARK: - Results

    private var dailyResultsView: some View {
        VStack(spacing: 24) {
            Spacer()

            Image(systemName: viewModel.score >= 800 ? "star.circle.fill" : "checkmark.circle.fill")
                .font(.system(size: 64))
                .foregroundStyle(viewModel.score >= 800 ? .yellow : AppColors.accent)

            VStack(spacing: 8) {
                Text("\(viewModel.score)")
                    .font(.system(size: 56, weight: .black, design: .rounded))
                    .foregroundStyle(AppColors.accent)

                Text("out of 1000")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }

            Text("Better than \(viewModel.percentile)% of players")
                .font(.headline)
                .foregroundStyle(AppColors.accent)
                .padding(.horizontal, 20)
                .padding(.vertical, 10)
                .background(AppColors.accent.opacity(0.1), in: Capsule())

            if viewModel.isCorrect {
                Label("Perfect!", systemImage: "sparkles")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.yellow)
            }

            Spacer()

            VStack(spacing: 12) {
                let shareText = "Daily Challenge: \(viewModel.score)/1000 🧠\nBetter than \(viewModel.percentile)% of players!\n\nTest yours with MindRestore"

                ShareLink(item: shareText) {
                    HStack {
                        Image(systemName: "square.and.arrow.up")
                        Text("Share Result")
                    }
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
            .padding(.bottom, 16)
        }
    }

    private func saveExercise() {
        let exercise = Exercise(
            type: .activeRecall,
            difficulty: 2,
            score: Double(viewModel.score) / 1000.0,
            durationSeconds: 40
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

