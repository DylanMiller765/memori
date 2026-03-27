import SwiftUI
import SwiftData

struct DailyChallengeView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @Environment(AchievementService.self) private var achievementService
    @Environment(PaywallTriggerService.self) private var paywallTrigger
    @Environment(StoreService.self) private var storeService
    @Environment(TrainingSessionManager.self) private var trainingManager
    @Environment(GameCenterService.self) private var gameCenterService
    @Query private var users: [User]
    @State private var viewModel = DailyChallengeViewModel()
    // @State private var showChallenge = false
    @State private var showLeaderboard = false
    @State private var strategyTip: StrategyTip?
    @State private var shareImage: UIImage?
    @State private var dailyRank: Int?
    @AppStorage("daily_challenge_completed_date") private var completedDateString: String = ""

    private var user: User? { users.first }

    var body: some View {
        ZStack {
            AppColors.pageBg.ignoresSafeArea()

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
        .onChange(of: viewModel.phase) { _, newPhase in
            if newPhase == .results {
                if viewModel.isCorrect {
                    SoundService.shared.playCorrect()
                } else {
                    SoundService.shared.playWrong()
                }
                SoundService.shared.playComplete()
                strategyTip = StrategyTipService.shared.freshTip(for: .dailyChallenge)

                // Mark daily challenge as completed for today
                let formatter = DateFormatter()
                formatter.dateFormat = "yyyy-MM-dd"
                completedDateString = formatter.string(from: Date.now)

                let ratingText: String
                if viewModel.score >= 900 { ratingText = "Exceptional" }
                else if viewModel.score >= 700 { ratingText = "Great" }
                else if viewModel.score >= 500 { ratingText = "Good" }
                else { ratingText = "Keep Practicing" }

                let card = ExerciseShareCard(
                    exerciseName: "Daily Challenge",
                    exerciseIcon: "trophy.fill",
                    accentColor: AppColors.amber,
                    mainValue: "\(viewModel.score)",
                    mainLabel: "out of 1000",
                    ratingText: ratingText,
                    stats: [
                        (label: "Percentile", value: "Top \(100 - viewModel.percentile)%"),
                        (label: "Type", value: viewModel.challengeType.displayName),
                        (label: "Accuracy", value: viewModel.isCorrect ? "100%" : "\(viewModel.score / 10)%")
                    ],
                    ctaText: "Think you can beat this?"
                )
                shareImage = card.renderAsImage(size: CGSize(width: 360, height: 640))

                // Submit score to Game Center
                gameCenterService.reportScore(viewModel.score, leaderboardID: GameCenterService.dailyChallengeLeaderboard)

                // Fetch today's rank
                Task {
                    if gameCenterService.isAuthenticated {
                        let result = await gameCenterService.loadLeaderboardEntries(
                            category: .dailyChallenge,
                            timeFilter: .today
                        )
                        if let entry = result.entries.first(where: { $0.isCurrentUser }) {
                            dailyRank = entry.rank
                        }
                    }
                }
            }
        }
        /*
        .sheet(isPresented: $showChallenge) {
            ChallengeView(
                challengeType: .dailyChallenge(challengeName: viewModel.challengeType.displayName),
                playerScore: viewModel.score,
                playerName: "Me",
                percentile: viewModel.percentile
            )
        }
        */
        .sheet(isPresented: $showLeaderboard) {
            LeaderboardView()
        }
    }

    // MARK: - Preview

    private var previewView: some View {
        VStack(spacing: 32) {
            Spacer()

            ZStack {
                Circle()
                    .fill(AppColors.accent.opacity(0.15))
                    .frame(width: 120, height: 120)
                Image(systemName: viewModel.challengeType.icon)
                    .font(.system(size: 52))
                    .foregroundStyle(AppColors.accent)
            }

            VStack(spacing: 8) {
                Text("Today's Challenge")
                    .font(.title.bold())
                Text(viewModel.challengeType.displayName)
                    .font(.title3.weight(.semibold))
                    .foregroundStyle(AppColors.accent)
                Text(viewModel.challengeType.instruction)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 40)
            }

            HStack(spacing: 20) {
                VStack(spacing: 4) {
                    Image(systemName: "globe")
                        .font(.body)
                        .foregroundStyle(AppColors.teal)
                    Text("Same for all")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
                VStack(spacing: 4) {
                    Image(systemName: "timer")
                        .font(.body)
                        .foregroundStyle(AppColors.amber)
                    Text("10s + 30s")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
            }

            Spacer()

            Button {
                viewModel.startCountdown()
            } label: {
                Text("Start Challenge")
                    .gradientButton()
            }
            .accessibilityHint("Starts the daily challenge")
            .padding(.horizontal, 32)
            .padding(.bottom, 16)
        }
    }

    // MARK: - Countdown

    private var countdownView: some View {
        VStack {
            Spacer()
            Text("\(viewModel.countdownValue)")
                .font(.system(size: 120, weight: .bold, design: .monospaced))
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
                    .foregroundStyle(viewModel.timeRemaining <= 3 ? AppColors.error : AppColors.accent)
                    .accessibilityLabel("\(Int(max(0, viewModel.timeRemaining))) seconds remaining")
            }
            .padding(.horizontal)

            ProgressView(value: max(0, viewModel.timeRemaining), total: 10)
                .tint(AppColors.accent)
                .padding(.horizontal)

            Spacer()

            if viewModel.challengeType == .speedPattern {
                patternGrid(interactive: false, showHighlights: true)
            } else if viewModel.challengeType == .faceNamePairs {
                faceNameMemorizeContent
            } else {
                Text(viewModel.displayContent)
                    .font(viewModel.challengeType == .speedNumbers
                        ? .system(size: 40, weight: .bold, design: .monospaced)
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
                    .foregroundStyle(AppColors.amber)
                Spacer()
                Text(String(format: "%.0fs", max(0, viewModel.recallTimeRemaining)))
                    .font(.headline.monospacedDigit())
                    .foregroundStyle(viewModel.recallTimeRemaining <= 5 ? AppColors.error : AppColors.amber)
                    .accessibilityLabel("\(Int(max(0, viewModel.recallTimeRemaining))) seconds remaining")
            }
            .padding(.horizontal)

            ProgressView(value: max(0, viewModel.recallTimeRemaining), total: 30)
                .tint(AppColors.amber)
                .padding(.horizontal)

            if viewModel.challengeType == .speedPattern {
                patternGrid(interactive: true, showHighlights: false)
            } else if viewModel.challengeType == .faceNamePairs {
                faceNameRecallContent
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
                            .font(.system(size: 28, weight: .bold, design: .monospaced))
                            .multilineTextAlignment(.center)
                            .padding()
                            .background(AppColors.cardSurface, in: RoundedRectangle(cornerRadius: 12))
                    } else {
                        TextEditor(text: $viewModel.textInput)
                            .font(.body)
                            .frame(height: 120)
                            .padding(8)
                            .background(AppColors.cardSurface, in: RoundedRectangle(cornerRadius: 12))
                    }
                }
                .padding(.horizontal, 24)
            }

            Spacer()

            Button {
                viewModel.submit()
            } label: {
                Text("Submit")
                    .gradientButton()
            }
            .padding(.horizontal, 32)
        }
        .padding(.vertical, 24)
    }

    // MARK: - Face-Name Pairs

    private var faceNameMemorizeContent: some View {
        VStack(spacing: 16) {
            ForEach(Array(viewModel.faceNamePairs.enumerated()), id: \.offset) { _, pair in
                HStack(spacing: 14) {
                    Image(systemName: "person.circle.fill")
                        .font(.system(size: 36))
                        .foregroundStyle(AppColors.sky.opacity(0.7))

                    VStack(alignment: .leading, spacing: 2) {
                        Text(pair.name)
                            .font(.headline.weight(.bold))
                        Text(pair.description)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }

                    Spacer()
                }
                .padding(12)
                .background(
                    RoundedRectangle(cornerRadius: 12)
                        .fill(AppColors.cardSurface)
                )
            }
        }
        .padding(.horizontal, 24)
    }

    private var faceNameRecallContent: some View {
        VStack(spacing: 16) {
            Text("Who was each person?")
                .font(.subheadline)
                .foregroundStyle(.secondary)

            ForEach(Array(viewModel.faceNamePairs.enumerated()), id: \.offset) { index, pair in
                HStack(spacing: 12) {
                    Image(systemName: "person.circle.fill")
                        .font(.system(size: 28))
                        .foregroundStyle(AppColors.sky.opacity(0.7))

                    VStack(alignment: .leading, spacing: 2) {
                        Text(pair.description)
                            .font(.caption)
                            .foregroundStyle(.secondary)

                        TextField("Name...", text: Binding(
                            get: { index < viewModel.faceNameInputs.count ? viewModel.faceNameInputs[index] : "" },
                            set: { if index < viewModel.faceNameInputs.count { viewModel.faceNameInputs[index] = $0 } }
                        ))
                        .textInputAutocapitalization(.words)
                        .font(.subheadline.weight(.semibold))
                        .padding(8)
                        .background(AppColors.cardSurface, in: RoundedRectangle(cornerRadius: 10))
                    }
                }
            }
        }
        .padding(.horizontal, 24)
    }

    // MARK: - Pattern Grid

    private func patternGrid(interactive: Bool, showHighlights: Bool) -> some View {
        LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 8), count: viewModel.gridSize), spacing: 8) {
            ForEach(0..<(viewModel.gridSize * viewModel.gridSize), id: \.self) { index in
                let isHighlighted = showHighlights && viewModel.patternCells.contains(index)
                let isSelected = interactive && viewModel.selectedCells.contains(index)

                RoundedRectangle(cornerRadius: 10)
                    .fill(isHighlighted || isSelected ? AppColors.accent : AppColors.cardBorder.opacity(0.4))
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
        ScrollView {
            VStack(spacing: 24) {
                Spacer(minLength: 20)

                ZStack {
                    Circle()
                        .fill(viewModel.score >= 800 ? Color.yellow.opacity(0.1) : AppColors.accent.opacity(0.15))
                        .frame(width: 100, height: 100)
                    Image(systemName: viewModel.score >= 800 ? "star.circle.fill" : "checkmark.circle.fill")
                        .font(.system(size: 48))
                        .foregroundStyle(viewModel.score >= 800 ? .yellow : AppColors.accent)
                }

                VStack(spacing: 8) {
                    Text("\(viewModel.score)")
                        .font(.system(size: 48, weight: .bold, design: .monospaced))
                        .foregroundStyle(AppColors.accent)

                    Text("out of 1000")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                .accessibilityElement(children: .combine)
                .accessibilityLabel("Score: \(viewModel.score) out of 1000")

                Text("Better than \(viewModel.percentile)% of players")
                    .font(.headline)
                    .foregroundStyle(AppColors.accent)
                    .padding(.horizontal, 20)
                    .padding(.vertical, 10)
                    .background(AppColors.accent.opacity(0.18), in: Capsule())
                    .accessibilityLabel("Better than \(viewModel.percentile) percent of players")

                if let rank = dailyRank {
                    Text("You placed #\(rank) today")
                        .font(.headline)
                        .foregroundStyle(AppColors.accent)
                }

                if viewModel.isCorrect {
                    Label("Perfect!", systemImage: "sparkles")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.yellow)
                }

                // Answer breakdown
                if !viewModel.isCorrect {
                    answerBreakdownView
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

                VStack(spacing: 12) {
                    /*
                    Button {
                        showChallenge = true
                    } label: {
                        HStack {
                            Image(systemName: "person.2.fill")
                            Text("Challenge a Friend")
                        }
                        .gradientButton()
                    }
                    */

                    Button {
                        showLeaderboard = true
                    } label: {
                        HStack {
                            Image(systemName: "star.circle.fill")
                            Text("View Leaderboard")
                        }
                        .font(.headline)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                        .background(
                            RoundedRectangle(cornerRadius: 12)
                                .stroke(AppColors.accent.opacity(0.4), lineWidth: 1.5)
                                .fill(AppColors.cardSurface)
                        )
                        .foregroundStyle(AppColors.accent)
                    }

                    if let shareImg = shareImage {
                        ShareLink(
                            item: Image(uiImage: shareImg),
                            preview: SharePreview(
                                "Daily Challenge: \(viewModel.score)/1000",
                                image: Image(uiImage: shareImg)
                            )
                        ) {
                            HStack {
                                Image(systemName: "square.and.arrow.up")
                                Text("Share Result")
                            }
                            .font(.headline)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 16)
                            .background(
                                RoundedRectangle(cornerRadius: 12)
                                    .stroke(AppColors.accent.opacity(0.4), lineWidth: 1.5)
                                    .fill(AppColors.cardSurface)
                            )
                            .foregroundStyle(AppColors.accent)
                        }
                        .simultaneousGesture(TapGesture().onEnded { Analytics.shareTapped(game: "dailyChallenge") })
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
            .responsiveContent()
            .frame(maxWidth: .infinity)
        }
    }

    // MARK: - Answer Breakdown

    @ViewBuilder
    private var answerBreakdownView: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("YOUR ANSWER")
                .font(.caption.weight(.bold))
                .foregroundStyle(.secondary)
                .tracking(0.5)

            if viewModel.challengeType == .speedPattern {
                patternComparisonGrid
            } else {
                VStack(spacing: 10) {
                    HStack {
                        Text("Correct")
                            .font(.caption.weight(.medium))
                            .foregroundStyle(.secondary)
                        Spacer()
                        Text(viewModel.correctAnswer)
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(AppColors.accent)
                    }

                    Divider()

                    HStack {
                        Text("Yours")
                            .font(.caption.weight(.medium))
                            .foregroundStyle(.secondary)
                        Spacer()
                        if viewModel.userAnswer.isEmpty {
                            Text("(no answer)")
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                        } else {
                            dailyChallengeComparisonText
                        }
                    }
                }
            }
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(AppColors.cardSurface)
        )
        .padding(.horizontal, 24)
    }

    @ViewBuilder
    private var dailyChallengeComparisonText: some View {
        if viewModel.challengeType == .speedNumbers {
            let correctDigits = Array(viewModel.correctAnswer.filter(\.isNumber))
            let inputDigits = Array(viewModel.userAnswer.filter(\.isNumber))
            HStack(spacing: 4) {
                ForEach(0..<max(correctDigits.count, inputDigits.count), id: \.self) { i in
                    if i < inputDigits.count {
                        let isRight = i < correctDigits.count && inputDigits[i] == correctDigits[i]
                        Text(String(inputDigits[i]))
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(isRight ? AppColors.accent : AppColors.coral)
                    } else {
                        Text("_")
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(AppColors.coral)
                    }
                }
            }
        } else {
            // Words — highlight which ones were correct, with wrapping text
            let correctWords = Set(viewModel.correctAnswer.lowercased().components(separatedBy: ", "))
            let inputWords = viewModel.userAnswer.lowercased()
                .components(separatedBy: CharacterSet(charactersIn: ", "))
                .filter { !$0.isEmpty }
            let formatted = inputWords.map { word -> AttributedString in
                var attr = AttributedString(word)
                let isRight = correctWords.contains(word.trimmingCharacters(in: .whitespaces))
                attr.foregroundColor = isRight ? UIColor(AppColors.accent) : UIColor(AppColors.coral)
                attr.font = .subheadline.weight(.semibold)
                return attr
            }
            let joined = formatted.reduce(AttributedString()) { result, next in
                if result.characters.isEmpty { return next }
                var separator = AttributedString(", ")
                separator.foregroundColor = .secondaryLabel
                separator.font = .subheadline
                return result + separator + next
            }
            Text(joined)
                .lineLimit(nil)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private var patternComparisonGrid: some View {
        VStack(spacing: 12) {
            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 6), count: viewModel.gridSize), spacing: 6) {
                ForEach(0..<(viewModel.gridSize * viewModel.gridSize), id: \.self) { index in
                    let wasCorrect = viewModel.correctCells.contains(index)
                    let wasSelected = viewModel.selectedCells.contains(index)

                    RoundedRectangle(cornerRadius: 8)
                        .fill(patternResultColor(wasCorrect: wasCorrect, wasSelected: wasSelected))
                        .aspectRatio(1, contentMode: .fit)
                        .overlay {
                            if wasCorrect && !wasSelected {
                                Image(systemName: "xmark")
                                    .font(.caption2.weight(.bold))
                                    .foregroundStyle(.white.opacity(0.7))
                            } else if !wasCorrect && wasSelected {
                                Image(systemName: "xmark")
                                    .font(.caption2.weight(.bold))
                                    .foregroundStyle(.white.opacity(0.7))
                            }
                        }
                }
            }
            .padding(.horizontal, 20)

            HStack(spacing: 16) {
                HStack(spacing: 4) {
                    Circle().fill(AppColors.accent).frame(width: 8, height: 8)
                    Text("Correct").font(.caption2).foregroundStyle(.secondary)
                }
                HStack(spacing: 4) {
                    Circle().fill(AppColors.coral).frame(width: 8, height: 8)
                    Text("Wrong/Missed").font(.caption2).foregroundStyle(.secondary)
                }
            }
        }
    }

    private func patternResultColor(wasCorrect: Bool, wasSelected: Bool) -> Color {
        if wasCorrect && wasSelected { return AppColors.accent } // Got it right
        if wasCorrect && !wasSelected { return AppColors.coral.opacity(0.6) } // Missed
        if !wasCorrect && wasSelected { return AppColors.coral } // Wrong pick
        return AppColors.cardBorder.opacity(0.4)
    }

    private func saveExercise() {
        trainingManager.addTrainingTime(40)

        let exerciseType: ExerciseType = {
            switch viewModel.challengeType {
            case .speedNumbers: return .sequentialMemory
            case .speedWords: return .activeRecall
            case .speedPattern: return .visualMemory
            case .faceNamePairs: return .activeRecall
            }
        }()
        let exercise = Exercise(
            type: exerciseType,
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

        if let user {
            _ = ContentView.awardXP(
                user: user,
                score: Double(viewModel.score) / 1000.0,
                difficulty: 2,
                achievementService: achievementService,
                modelContext: modelContext,
                gameCenterService: gameCenterService
            )
        }

        // Smart paywall trigger after daily challenge
        let isProUser = storeService.isProUser
        paywallTrigger.triggerAfterDailyChallenge(isProUser: isProUser)
    }
}

