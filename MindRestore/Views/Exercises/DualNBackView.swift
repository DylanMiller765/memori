import SwiftUI
import SwiftData
import GameKit

struct DualNBackView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @Environment(StoreService.self) private var storeService
    @Environment(AchievementService.self) private var achievementService
    @Environment(TrainingSessionManager.self) private var trainingManager
    @Environment(PaywallTriggerService.self) private var paywallTrigger
    @Environment(GameCenterService.self) private var gameCenterService
    @Environment(DeepLinkRouter.self) private var deepLinkRouter
    @Query private var users: [User]

    @State private var viewModel = DualNBackViewModel()
    @State private var selectedN: Int = 1
    @State private var gameStarted = false
    @State private var strategyTip: StrategyTip?
    @State private var showingPaywall = false
    @State private var shareImage: UIImage?
    @State private var exerciseSaved = false
    @State private var activeChallenge: ChallengeLink?
    @State private var resultsAppeared = false
    @State private var showingInfo = false
    // @State private var showingChallengeResult = false

    private var user: User? { users.first }
    private var isProUser: Bool { storeService.isProUser }

    var body: some View {
        VStack(spacing: 0) {
            if viewModel.showResults {
                resultsView
                    .transition(.scale(scale: 0.95).combined(with: .opacity))
            } else if gameStarted {
                gameView
                    .transition(.opacity)
            } else {
                setupView
                    .transition(.scale(scale: 0.95).combined(with: .opacity))
            }
        }
        .animation(.easeInOut(duration: 0.3), value: viewModel.showResults)
        .animation(.easeInOut(duration: 0.3), value: gameStarted)
        .sheet(isPresented: $showingPaywall) { PaywallView(isHighIntent: true) }
        /*
        .sheet(isPresented: $showingChallengeResult) {
            if let challenge = activeChallenge {
                FriendChallengeResultView(
                    challenge: challenge,
                    playerScore: viewModel.currentN,
                    onShareResult: { showingChallengeResult = false },
                    onChallengeAnother: { showingChallengeResult = false },
                    onDone: {
                        showingChallengeResult = false
                        deepLinkRouter.pendingChallenge = nil
                    }
                )
            }
        }
        */
        .navigationTitle("Dual N-Back")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            if let challenge = deepLinkRouter.pendingChallenge {
                viewModel.challengeSeed = challenge.seed
                activeChallenge = challenge
            }
        }
        .onDisappear {
            viewModel.cleanup()
        }
        .onChange(of: viewModel.showResults) { _, showingResults in
            if showingResults {
                let correctCount = Int(round(viewModel.overallScore * Double(viewModel.totalTrials)))
                AdaptiveDifficultyEngine.shared.recordBlock(domain: .nBack, correct: correctCount, total: viewModel.totalTrials)
                if PersonalBestTracker.shared.record(score: viewModel.currentN, for: .dualNBack) {
                    Analytics.personalBest(game: ExerciseType.dualNBack.rawValue, score: viewModel.currentN)
                }
                // Auto-save so GC gets the score even if user doesn't tap Done
                saveExercise()
                strategyTip = StrategyTipService.shared.freshTip(for: .nBack)
                SoundService.shared.playComplete()
                HapticService.complete()
                let card = ExerciseShareCard(
                    exerciseName: "Dual N-Back",
                    exerciseIcon: "square.grid.3x3",
                    accentColor: AppColors.sky,
                    mainValue: "N=\(viewModel.currentN)",
                    mainLabel: "Level",
                    ratingText: viewModel.overallScore >= 0.9 ? "Master" : viewModel.overallScore >= 0.7 ? "Great" : "Keep Going",
                    stats: [
                        ("Position", viewModel.positionScore.percentString),
                        ("Overall", viewModel.overallScore.percentString),
                        ("Trials", "\(viewModel.totalTrials)")
                    ],
                    ctaText: "Think you can beat this?"
                )
                shareImage = card.renderAsImage(size: CGSize(width: 360, height: 640), scale: 3)
                if viewModel.nextN > viewModel.currentN {
                    HapticService.levelUp()
                }
            }
        }
    }

    private var setupView: some View {
        ScrollView {
        VStack(spacing: 24) {
            // Icon with radial glow
            TrainingTileMiniPreview(type: .dualNBack, color: AppColors.sky, scale: 2.0)
                .frame(width: 200, height: 140)

            VStack(spacing: 8) {
                Text("Dual N-Back")
                    .font(.title.weight(.bold))
                Text("Train your working memory")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }

            // How to play
            VStack(alignment: .leading, spacing: 10) {
                Text("HOW TO PLAY")
                    .font(.caption.weight(.bold))
                    .foregroundStyle(.secondary)
                    .tracking(1)

                instructionRow(icon: "square.grid.3x3", color: AppColors.accent,
                    text: "Each round: a square lights up + a letter appears")
                instructionRow(icon: "square.grid.3x3", color: AppColors.teal,
                    text: "Tap **Position** if the square is in the **same spot** as the previous round")
                instructionRow(icon: "textformat", color: AppColors.indigo,
                    text: "Tap **Letter** if the letter is the **same** as the previous round")
                instructionRow(icon: "brain.head.profile", color: AppColors.violet,
                    text: "Track both at once! That's what makes it the #1 brain exercise")
            }
            .appCard()
            .padding(.horizontal)

            VStack(spacing: 12) {
                Text("N Level: \(selectedN)")
                    .font(.headline)

                HStack(spacing: 10) {
                    ForEach(1...5, id: \.self) { n in
                        Button {
                            selectedN = n
                        } label: {
                            Text("\(n)")
                                .font(.headline.weight(.bold))
                                .frame(width: 50, height: 50)
                                .background(
                                    ZStack {
                                        if selectedN == n {
                                            RoundedRectangle(cornerRadius: 12)
                                                .fill(AppColors.accentGradient)
                                        } else {
                                            RoundedRectangle(cornerRadius: 12)
                                                .fill(AppColors.cardSurface)
                                        }
                                    }
                                )
                                .foregroundStyle(selectedN == n ? .white : .primary)
                                .overlay(
                                    RoundedRectangle(cornerRadius: 12)
                                        .stroke(
                                            selectedN == n ? Color.clear : Color(.separator).opacity(0.3),
                                            lineWidth: 1
                                        )
                                )
                        }
                    }
                }
            }
            .appCard()
            .padding(.horizontal)

            Button {
                Analytics.exerciseStarted(game: ExerciseType.dualNBack.rawValue)
                gameStarted = true
                viewModel.startGame(n: selectedN, dual: true)
            } label: {
                Text("Start")
                    .accentButton()
            }
            .pulsingWhenIdle()
            .accessibilityHint("Starts the exercise")
            .padding(.horizontal, 32)
        }
        .padding(.vertical, 24)
        }
        .overlay(alignment: .topTrailing) {
            Button { showingInfo = true } label: {
                Image(systemName: "questionmark.circle.fill")
                    .font(.title3)
                    .foregroundStyle(.white.opacity(0.3))
            }
            .padding(16)
        }
        .sheet(isPresented: $showingInfo) {
            ExerciseInfoSheet(type: .dualNBack)
                .presentationDetents([.medium])
        }
    }

    private var gameView: some View {
        VStack(spacing: 24) {
            HStack {
                Text("N = \(viewModel.currentN)")
                    .font(.headline)
                    .foregroundStyle(AppColors.accent)
                    .contentTransition(.numericText())
                Spacer()
                Text("Trial \(viewModel.trialIndex + 1) / \(viewModel.totalTrials)")
                    .font(.caption.weight(.medium))
                    .foregroundStyle(.secondary)
                    .contentTransition(.numericText())
            }
            .padding(.horizontal)

            ProgressView(value: Double(viewModel.trialIndex), total: Double(viewModel.totalTrials))
                .tint(AppColors.accent)
                .padding(.horizontal)

            Spacer()

            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 8), count: 3), spacing: 8) {
                ForEach(0..<9, id: \.self) { index in
                    RoundedRectangle(cornerRadius: 12)
                        .fill(index == viewModel.currentPosition
                            ? LinearGradient(colors: [AppColors.accent, AppColors.indigo], startPoint: .topLeading, endPoint: .bottomTrailing)
                            : LinearGradient(colors: [Color.gray.opacity(0.08), Color.gray.opacity(0.05)], startPoint: .top, endPoint: .bottom)
                        )
                        .aspectRatio(1, contentMode: .fit)
                        .scaleEffect(viewModel.trialFlash && index == viewModel.currentPosition ? 0.85 : 1.0)
                        .opacity(viewModel.trialFlash && index == viewModel.currentPosition ? 0.4 : 1.0)
                        .animation(.easeInOut(duration: 0.15), value: viewModel.currentPosition)
                        .animation(.spring(response: 0.2, dampingFraction: 0.5), value: viewModel.trialFlash)
                        .accessibilityLabel("Grid cell \(index + 1)\(index == viewModel.currentPosition ? ", active" : "")")
                }
            }
            .padding(.horizontal, 40)

            if viewModel.isDual && !viewModel.currentLetter.isEmpty {
                Text(viewModel.currentLetter)
                    .font(.system(size: 36, weight: .bold))
                    .foregroundStyle(.secondary)
                    .scaleEffect(viewModel.trialFlash ? 0.7 : 1.0)
                    .opacity(viewModel.trialFlash ? 0.3 : 1.0)
                    .animation(.spring(response: 0.2, dampingFraction: 0.5), value: viewModel.trialFlash)
            }

            Spacer()

            HStack(spacing: 14) {
                Button {
                    viewModel.tapPosition()
                } label: {
                    VStack(spacing: 6) {
                        Image(systemName: "square.grid.3x3")
                            .font(.title3)
                        Text("Position")
                            .font(.caption.weight(.semibold))
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 18)
                    .background(
                        ZStack {
                            RoundedRectangle(cornerRadius: 12)
                                .fill(AppColors.accent.opacity(0.20))
                            RoundedRectangle(cornerRadius: 12)
                                .fill(
                                    LinearGradient(
                                        colors: [AppColors.accent.opacity(0.15), .clear],
                                        startPoint: .top,
                                        endPoint: .bottom
                                    )
                                )
                        }
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(AppColors.accent.opacity(0.25), lineWidth: 1)
                    )
                    .foregroundStyle(AppColors.accent)
                }

                if viewModel.isDual {
                    Button {
                        viewModel.tapSound()
                    } label: {
                        VStack(spacing: 6) {
                            Image(systemName: "textformat")
                                .font(.title3)
                            Text("Letter")
                                .font(.caption.weight(.semibold))
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 18)
                        .background(
                            ZStack {
                                RoundedRectangle(cornerRadius: 12)
                                    .fill(AppColors.indigo.opacity(0.20))
                                RoundedRectangle(cornerRadius: 12)
                                    .fill(
                                        LinearGradient(
                                            colors: [AppColors.indigo.opacity(0.15), .clear],
                                            startPoint: .top,
                                            endPoint: .bottom
                                        )
                                    )
                            }
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: 12)
                                .stroke(AppColors.indigo.opacity(0.25), lineWidth: 1)
                        )
                        .foregroundStyle(AppColors.indigo)
                    }
                }
            }
            .font(.headline)
            .padding(.horizontal)

            // Wrong answer N-back hint
            if viewModel.wrongPositionNBack != nil || viewModel.wrongLetterNBack != nil {
                HStack(spacing: 16) {
                    if let pos = viewModel.wrongPositionNBack {
                        HStack(spacing: 6) {
                            Image(systemName: "square.grid.3x3")
                                .font(.caption)
                                .foregroundStyle(AppColors.coral)
                            Text("N-back was cell \(pos + 1)")
                                .font(.caption.weight(.semibold))
                                .foregroundStyle(AppColors.coral)
                        }
                    }
                    if let letter = viewModel.wrongLetterNBack {
                        HStack(spacing: 6) {
                            Image(systemName: "textformat")
                                .font(.caption)
                                .foregroundStyle(AppColors.coral)
                            Text("N-back was \"\(letter)\"")
                                .font(.caption.weight(.semibold))
                                .foregroundStyle(AppColors.coral)
                        }
                    }
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
                .background(AppColors.coral.opacity(0.08), in: Capsule())
                .transition(.opacity.combined(with: .move(edge: .bottom)))
                .animation(.easeInOut(duration: 0.2), value: viewModel.wrongPositionNBack)
            }
        }
        .padding(.vertical, 24)
    }

    private var resultsView: some View {
        ScrollView(showsIndicators: false) {
            VStack(spacing: 16) {
                HStack(spacing: 12) {
                    Image(systemName: "square.grid.3x3")
                        .font(.system(size: 24))
                        .foregroundStyle(.white)
                        .frame(width: 48, height: 48)
                        .background(AppColors.sky, in: RoundedRectangle(cornerRadius: 14))
                    Text("Round Complete!")
                        .font(.title2.weight(.bold))
                }
                .padding(.top, 20)
                .opacity(resultsAppeared ? 1 : 0).offset(y: resultsAppeared ? 0 : 20)
                .animation(.spring(response: 0.5, dampingFraction: 0.8).delay(0.1), value: resultsAppeared)

                VStack(spacing: 12) {
                    resultRow(label: "Position Accuracy", value: viewModel.positionScore.percentString)
                        .accessibilityElement(children: .combine)
                    if viewModel.isDual {
                        resultRow(label: "Letter Accuracy", value: viewModel.soundScore.percentString)
                            .accessibilityElement(children: .combine)
                    }
                    resultRow(label: "Overall Score", value: viewModel.overallScore.percentString)
                        .accessibilityElement(children: .combine)
                    resultRow(label: "Time", value: viewModel.durationSeconds.durationString)
                        .accessibilityElement(children: .combine)

                    Divider()

                    HStack {
                        Text("Next recommended N:")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                        Spacer()
                        Text("\(viewModel.nextN)")
                            .font(.title3.weight(.bold).monospacedDigit())
                            .foregroundStyle(AppColors.accent)
                            .contentTransition(.numericText())
                    }
                }
                .glowingCard(color: AppColors.accent, intensity: 0.08)
                .padding(.horizontal)
                .opacity(resultsAppeared ? 1 : 0).offset(y: resultsAppeared ? 0 : 20)
                .animation(.spring(response: 0.5, dampingFraction: 0.8).delay(0.2), value: resultsAppeared)

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
                    exerciseType: .dualNBack,
                    userScore: viewModel.currentN,
                )
                .padding(.horizontal)
                .opacity(resultsAppeared ? 1 : 0).offset(y: resultsAppeared ? 0 : 20)
                .animation(.spring(response: 0.5, dampingFraction: 0.8).delay(0.3), value: resultsAppeared)

                VStack(spacing: 12) {
                    if let shareImage {
                        ShareLink(
                            item: Image(uiImage: shareImage),
                            preview: SharePreview("Dual N-Back: N=\(viewModel.currentN)", image: Image(uiImage: shareImage))
                        ) {
                            HStack(spacing: 8) {
                                Image(systemName: "square.and.arrow.up")
                                Text("Share Result")
                            }
                            .accentButton()
                        }
                        .simultaneousGesture(TapGesture().onEnded { Analytics.shareTapped(game: ExerciseType.dualNBack.rawValue) })
                    }

                    /*
                    if let challengeURL = ChallengeLink(
                        game: .dualNBack,
                        seed: viewModel.challengeSeed ?? ChallengeLink.randomSeed(),
                        score: viewModel.currentN,
                        challengerName: GKLocalPlayer.local.displayName
                    ).url {
                        ShareLink(item: challengeURL) {
                            HStack(spacing: 8) {
                                Image(systemName: "person.2.fill")
                                Text("Challenge a Friend")
                            }
                            .gradientButton()
                        }
                    }
                    */

                    /*
                    if let challenge = activeChallenge {
                        Button {
                            showingChallengeResult = true
                        } label: {
                            HStack(spacing: 8) {
                                Image(systemName: "person.2.fill")
                                Text("See Challenge Result")
                            }
                            .accentButton()
                        }
                    }
                    */

                    Button {
                        resultsAppeared = false
                        exerciseSaved = false
                        selectedN = viewModel.nextN
                        gameStarted = true
                        viewModel.startGame(n: selectedN, dual: true)
                    } label: {
                        Text("Play Again (N=\(viewModel.nextN))")
                            .gradientButton()
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
                .padding(.top, 8)
                .padding(.bottom, 24)
                .opacity(resultsAppeared ? 1 : 0).offset(y: resultsAppeared ? 0 : 20)
                .animation(.spring(response: 0.5, dampingFraction: 0.8).delay(0.4), value: resultsAppeared)
            }
        }
        .onAppear { resultsAppeared = false; DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) { resultsAppeared = true } }
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

    private func instructionRow(icon: String, color: Color, text: LocalizedStringKey) -> some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: icon)
                .font(.subheadline)
                .foregroundStyle(color)
                .frame(width: 22)
            Text(text)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }

    private func saveExercise() {
        guard !exerciseSaved else { return }
        exerciseSaved = true
        paywallTrigger.recordExerciseCompleted()
        trainingManager.addTrainingTime(viewModel.durationSeconds)

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

        if let user {
            _ = ContentView.awardXP(
                user: user,
                score: viewModel.overallScore,
                difficulty: viewModel.currentN,
                achievementService: achievementService,
                modelContext: modelContext,
                gameCenterService: gameCenterService,
                exerciseType: .dualNBack,
                gameScore: viewModel.currentN
            )
        }
    }
}
