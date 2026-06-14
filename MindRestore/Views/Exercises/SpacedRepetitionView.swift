import SwiftUI
import SwiftData

struct SpacedRepetitionView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @Environment(AchievementService.self) private var achievementService
    @Environment(TrainingSessionManager.self) private var trainingManager
    @Environment(StoreService.self) private var storeService
    @Environment(PaywallTriggerService.self) private var paywallTrigger
    @Environment(GameCenterService.self) private var gameCenterService
    @Query private var users: [User]
    @Query private var allCards: [SpacedRepetitionCard]

    let category: CardCategory
    @State private var viewModel = SpacedRepetitionViewModel()
    @State private var hasInitialized = false
    @State private var showingSetup = true
    @State private var strategyTip: StrategyTip?

    private let difficulty = AdaptiveDifficultyEngine.shared

    // Number memorize-recall state
    @State private var numberPhase: NumberPhase = .memorize
    @State private var numberInput: String = ""
    @State private var numberTimeRemaining: Double = 3
    @State private var numberTimer: Timer?
    @State private var numberResult: NumberResult?

    enum NumberPhase {
        case memorize, recall, result
    }

    struct NumberResult {
        let correct: String
        let input: String
        let isCorrect: Bool
    }

    private var user: User? { users.first }
    private var isProUser: Bool { storeService.isProUser }
    private var categoryCards: [SpacedRepetitionCard] {
        allCards.filter { $0.category == category }
    }

    private var isNumberCategory: Bool { category == .numbers }

    private var dueCardCount: Int {
        if isNumberCategory { return 10 }
        if categoryCards.isEmpty { return 0 }
        return categoryCards.filter { $0.nextReviewDate <= Date() }.count
    }

    private var exerciseDomain: ExerciseDomain {
        switch category {
        case .numbers: return .digits
        case .words: return .words
        case .faces: return .faces
        case .locations: return .locations
        case .sequences: return .activeRecall
        }
    }

    var body: some View {
        if category.isPro && !isProUser {
            VStack(spacing: 20) {
                Spacer()
                Image(systemName: "lock.fill")
                    .font(.system(size: 48))
                    .foregroundStyle(.secondary)
                Text("Full access feature")
                    .font(.title2.weight(.bold))
                Text("Upgrade to unlock \(category.displayName) training.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 32)
                Button {
                    paywallTrigger.triggerLockedCategory(isProUser: false)
                } label: {
                    Text("Unlock Memo")
                        .gradientButton()
                }
                .padding(.horizontal, 32)
                Spacer()
            }
            .navigationTitle(category.displayName)
            .navigationBarTitleDisplayMode(.inline)
        } else {
            VStack(spacing: 0) {
                if showingSetup {
                    setupView
                        .transition(.opacity)
                } else if viewModel.isSessionComplete {
                    sessionCompleteView
                } else if let card = viewModel.currentCard {
                    if isNumberCategory {
                        numberCardView(card)
                    } else {
                        cardView(card)
                    }
                } else {
                    emptyStateView
                }
            }
            .animation(.easeInOut(duration: 0.3), value: showingSetup)
            .navigationTitle(category.displayName)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    if !showingSetup && !viewModel.isSessionComplete && !viewModel.sessionCards.isEmpty {
                        Text("\(viewModel.currentCardIndex + 1)/\(viewModel.sessionCards.count)")
                            .font(.caption.weight(.medium))
                            .foregroundStyle(.secondary)
                    }
                }
            }
            .onChange(of: viewModel.isSessionComplete) { _, isComplete in
                if isComplete {
                    SoundService.shared.playComplete()
                    strategyTip = StrategyTipService.shared.freshTip(for: exerciseDomain)
                }
            }
        }
    }

    // MARK: - Setup View

    private var setupView: some View {
        VStack(spacing: 32) {
            Spacer()

            ZStack {
                Circle()
                    .fill(AppColors.cardBorder)
                    .frame(width: 120, height: 120)
                Image(systemName: "clock.arrow.circlepath")
                    .font(.system(size: 52, weight: .medium))
                    .foregroundStyle(AppColors.accent)
            }

            VStack(spacing: 8) {
                Text("Spaced Repetition")
                    .font(.title.weight(.bold))
                Text("Review cards at optimal intervals to strengthen your memory")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 32)
            }

            VStack(spacing: 6) {
                Text(category.displayName)
                    .font(.headline)
                    .foregroundStyle(AppColors.accent)
                if dueCardCount > 0 {
                    Text("\(dueCardCount) cards due for review")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                } else if !isNumberCategory && categoryCards.isEmpty {
                    Text("New deck — cards will be created")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
            }

            Spacer()

            Button {
                let cards = initializeCards()
                viewModel.startSession(cards: cards)
                hasInitialized = true
                showingSetup = false
            } label: {
                Text("Start Review")
                    .gradientButton()
            }
            .accessibilityHint("Starts the exercise")
            .padding(.horizontal, 32)
        }
        .padding(.vertical, 24)
    }

    // MARK: - Number Card (Memorize → Recall → Result)

    private func numberCardView(_ card: SpacedRepetitionCard) -> some View {
        VStack(spacing: 24) {
            ProgressView(value: viewModel.progress)
                .tint(AppColors.accent)
                .padding(.horizontal)

            Spacer()

            switch numberPhase {
            case .memorize:
                numberMemorizeView(card)
            case .recall:
                numberRecallView(card)
            case .result:
                numberResultView(card)
            }

            Spacer()
        }
        .padding(.vertical, 24)
        .onAppear { startNumberMemorize(card) }
        .onChange(of: viewModel.currentCardIndex) {
            startNumberMemorize(viewModel.currentCard)
        }
    }

    private func numberMemorizeView(_ card: SpacedRepetitionCard) -> some View {
        VStack(spacing: 20) {
            HStack {
                Text("MEMORIZE")
                    .font(.caption.weight(.bold))
                    .foregroundStyle(AppColors.accent)
                    .tracking(1)
                Spacer()
                Text(String(format: "%.0fs", max(0, numberTimeRemaining)))
                    .font(.headline.monospacedDigit())
                    .foregroundStyle(numberTimeRemaining <= 2 ? AppColors.coral : AppColors.accent)
                    .accessibilityLabel("Time remaining: \(Int(max(0, numberTimeRemaining))) seconds")
            }
            .padding(.horizontal, 32)

            ProgressView(value: max(0, numberTimeRemaining), total: difficulty.displayTime(for: .digits))
                .tint(AppColors.accent)
                .padding(.horizontal, 32)

            Text(card.answer)
                .font(.system(size: 40, weight: .bold, design: .monospaced))
                .tracking(8)
                .foregroundStyle(.primary)
                .padding(.top, 20)
                .accessibilityLabel("Remember this number: \(card.answer)")
        }
    }

    private func numberRecallView(_ card: SpacedRepetitionCard) -> some View {
        VStack(spacing: 20) {
            Text("What were the numbers?")
                .font(.title3.weight(.semibold))

            Text("\(card.answer.filter(\.isNumber).count) digits in order")
                .font(.subheadline)
                .foregroundStyle(.secondary)

            TextField("Type the numbers...", text: $numberInput)
                .keyboardType(.numberPad)
                .font(.system(size: 32, weight: .bold, design: .monospaced))
                .multilineTextAlignment(.center)
                .padding()
                .background(AppColors.cardSurface, in: RoundedRectangle(cornerRadius: 12))
                .padding(.horizontal, 40)

            Button {
                submitNumberAnswer(card)
            } label: {
                Text("Submit")
                    .gradientButton()
            }
            .padding(.horizontal, 32)
        }
    }

    private func numberResultView(_ card: SpacedRepetitionCard) -> some View {
        VStack(spacing: 20) {
            if let result = numberResult {
                ZStack {
                    Circle()
                        .fill(AppColors.cardBorder)
                        .frame(width: 80, height: 80)
                    Image(systemName: result.isCorrect ? "checkmark.circle.fill" : "xmark.circle.fill")
                        .font(.system(size: 48))
                        .foregroundStyle(result.isCorrect ? AppColors.accent : AppColors.coral)
                }

                Text(result.isCorrect ? "Correct!" : "Not quite")
                    .font(.title2.weight(.bold))

                VStack(spacing: 12) {
                    HStack {
                        Text("Correct:")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                        Spacer()
                        Text(result.correct)
                            .font(.system(.title3, design: .monospaced).weight(.semibold))
                            .foregroundStyle(AppColors.accent)
                    }

                    if !result.isCorrect {
                        HStack {
                            Text("Yours:")
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                            Spacer()
                            numberComparisonText(correct: result.correct, input: result.input)
                        }
                    }
                }
                .padding(16)
                .background(
                    RoundedRectangle(cornerRadius: 12)
                        .fill(AppColors.cardSurface)
                )
                .padding(.horizontal, 32)
            }

            Button {
                let isCorrect = numberResult?.isCorrect ?? false
                viewModel.rate(isCorrect ? .good : .again)
                numberPhase = .memorize
                numberResult = nil
                numberInput = ""
            } label: {
                Text("Next")
                    .gradientButton()
            }
            .padding(.horizontal, 32)
        }
    }

    private func numberComparisonText(correct: String, input: String) -> some View {
        let correctDigits = Array(correct.filter(\.isNumber))
        let inputDigits = Array(input.filter(\.isNumber))

        return HStack(spacing: 2) {
            ForEach(0..<max(correctDigits.count, inputDigits.count), id: \.self) { i in
                if i < inputDigits.count {
                    let isRight = i < correctDigits.count && inputDigits[i] == correctDigits[i]
                    Text(String(inputDigits[i]))
                        .font(.system(.title3, design: .monospaced).weight(.semibold))
                        .foregroundStyle(isRight ? AppColors.accent : AppColors.coral)
                } else {
                    Text("_")
                        .font(.system(.title3, design: .monospaced).weight(.semibold))
                        .foregroundStyle(AppColors.coral)
                }
            }
        }
    }

    private func startNumberMemorize(_ card: SpacedRepetitionCard?) {
        guard card != nil else { return }
        numberPhase = .memorize
        numberInput = ""
        numberResult = nil
        let displayDuration = difficulty.displayTime(for: .digits)
        numberTimeRemaining = displayDuration
        numberTimer?.invalidate()
        numberTimer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { [self] _ in
            Task { @MainActor in
                numberTimeRemaining -= 0.1
                if numberTimeRemaining <= 0 {
                    numberTimer?.invalidate()
                    numberPhase = .recall
                }
            }
        }
    }

    private func submitNumberAnswer(_ card: SpacedRepetitionCard) {
        numberTimer?.invalidate()
        let correct = card.answer.filter(\.isNumber)
        let input = numberInput.filter(\.isNumber)
        let isCorrect = correct == input
        numberResult = NumberResult(correct: card.answer, input: numberInput, isCorrect: isCorrect)
        numberPhase = .result
        difficulty.recordAttempt(domain: .digits, correct: isCorrect)
        if isCorrect {
            SoundService.shared.playCorrect()
        } else {
            SoundService.shared.playWrong()
        }
    }

    // MARK: - Regular Flashcard View

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
                                if rating.rawValue >= 2 {
                                    SoundService.shared.playCorrect()
                                } else {
                                    SoundService.shared.playWrong()
                                }
                                difficulty.recordAttempt(domain: exerciseDomain, correct: rating.rawValue >= 2)
                                viewModel.rate(rating)
                            } label: {
                                Text(rating.displayName)
                                    .font(.subheadline.weight(.semibold))
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, 14)
                                    .background(ratingColor(rating).opacity(0.15), in: RoundedRectangle(cornerRadius: 12))
                                    .foregroundStyle(ratingColor(rating))
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 12)
                                            .stroke(ratingColor(rating).opacity(0.3), lineWidth: 1)
                                    )
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
                        .gradientButton()
                }
                .padding(.horizontal)
            }
        }
        .padding(.vertical, 24)
    }

    private var sessionCompleteView: some View {
        VStack(spacing: 24) {
            Spacer()

            ZStack {
                Circle()
                    .fill(AppColors.cardBorder)
                    .frame(width: 100, height: 100)
                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 64))
                    .foregroundStyle(AppColors.accent)
            }

            Text("Session Complete!")
                .font(.title.weight(.bold))

            VStack(spacing: 8) {
                Text("Score: \(viewModel.sessionScore.percentString)")
                    .font(.title2)
                    .foregroundStyle(AppColors.accent)
                    .accessibilityLabel("Score: \(viewModel.sessionScore.percentString)")
                Text("\(viewModel.sessionCards.count) cards reviewed")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                Text("Time: \(viewModel.durationSeconds.durationString)")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
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
                .glowingCard(color: AppColors.accent, intensity: 0.08)
                .padding(.horizontal, 20)
            }

            Spacer()

            Button {
                saveExercise()
                dismiss()
            } label: {
                Text("Done")
                    .gradientButton()
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
            Text("You're all caught up!")
                .font(.headline)
            Text("Come back tomorrow — your cards are\nscheduled for optimal memory retention.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
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

    @discardableResult
    private func initializeCards() -> [SpacedRepetitionCard] {
        if isNumberCategory {
            // Dynamically generate digit sequences based on adaptive difficulty
            let digitCount = difficulty.parameters(for: .digits).digitCount
            let sessionSize = 10
            var cards: [SpacedRepetitionCard] = []
            for _ in 0..<sessionSize {
                let digits = (0..<digitCount).map { _ in String(Int.random(in: 0...9)) }
                let answer = digits.joined(separator: " ")
                let card = SpacedRepetitionCard(
                    category: .numbers,
                    prompt: "Remember: \(answer)",
                    answer: answer
                )
                modelContext.insert(card)
                cards.append(card)
            }
            return cards
        }
        if categoryCards.isEmpty {
            let newCards = SpacedRepetitionContent.createInitialCards(for: category)
            for card in newCards {
                modelContext.insert(card)
            }
            return newCards
        }
        return categoryCards
    }

    private func saveExercise() {
        paywallTrigger.recordExerciseCompleted()
        trainingManager.addTrainingTime(viewModel.durationSeconds)

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

        if let user {
            _ = ContentView.awardXP(
                user: user,
                score: viewModel.sessionScore,
                difficulty: 1,
                achievementService: achievementService,
                modelContext: modelContext,
                gameCenterService: gameCenterService,
                exerciseType: .spacedRepetition
            )
        }
    }
}
