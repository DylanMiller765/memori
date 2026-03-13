import SwiftUI
import SwiftData

struct HomeView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(StoreService.self) private var storeService
    @Environment(TrainingSessionManager.self) private var trainingManager
    @Environment(PaywallTriggerService.self) private var paywallTrigger
    @Query private var users: [User]
    @Query(sort: \DailySession.date, order: .reverse) private var sessions: [DailySession]
    @Query(sort: \BrainScoreResult.date, order: .reverse) private var brainScores: [BrainScoreResult]
    @Query private var achievements: [Achievement]
    @Query(sort: \Exercise.completedAt, order: .reverse) private var exercises: [Exercise]

    @Environment(WorkoutEngine.self) private var workoutEngine

    @Binding var selectedTab: Int
    @State private var viewModel = HomeViewModel()
    @State private var showingPaywall = false
    @State private var showingAssessment = false
    @State private var brainScoreShareImage: UIImage?
    @State private var showingFreezeInfo = false
    @State private var showingWorkoutComplete = false
    @State private var workoutOldBrainScore: Int = 0
    @State private var workoutOldBrainAge: Int = 50
    @State private var workoutNewBrainScore: Int = 0
    @State private var workoutNewBrainAge: Int = 50
    @State private var workoutNewResult: WorkoutEngine.RollingScoreResult?
    @State private var workoutScoreSaved = false
    @State private var workoutGameToPlay: ExerciseType?
    @State private var isInWorkoutMode = false
    @State private var workoutGameJustCompleted = false
    @AppStorage("daily_challenge_completed_date") private var dailyChallengeCompletedDate: String = ""
    @AppStorage("lastWeeklyReportDismissed") private var lastWeeklyReportDismissed: String = ""
    @State private var weeklyReportShareImage: UIImage?

    private var hasDoneDailyChallenge: Bool {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        return dailyChallengeCompletedDate == formatter.string(from: Date.now)
    }

    private var user: User? { users.first }
    private var latestBrainScore: BrainScoreResult? { brainScores.first }
    private var isNewUser: Bool { sessions.count <= 1 && (user?.totalXP ?? 0) < 100 }

    private func lastPlayedText(for type: ExerciseType) -> String? {
        guard let lastExercise = exercises.first(where: { $0.type == type }) else { return nil }
        let days = Calendar.current.dateComponents([.day], from: lastExercise.completedAt, to: .now).day ?? 0
        if days == 0 { return "Today" }
        if days == 1 { return "Yesterday" }
        if days < 7 { return "\(days)d ago" }
        return "\(days / 7)w ago"
    }

    private func lastPlayedTextForDestination(_ dest: ExerciseDestination) -> String? {
        switch dest {
        case .dualNBack: return lastPlayedText(for: .dualNBack)
        case .spacedRepetition(_): return lastPlayedText(for: .spacedRepetition)
        case .activeRecall: return lastPlayedText(for: .activeRecall)
        case .exercise(let type): return lastPlayedText(for: type)
        case .mixedTraining, .dailyChallenge, .brainAssessment: return nil
        }
    }

    // MARK: - Weekly Report Helpers

    private var thisMondayString: String {
        let cal = Calendar.current
        let today = cal.startOfDay(for: .now)
        let weekday = cal.component(.weekday, from: today)
        // weekday: 1=Sun, 2=Mon, ...
        let daysFromMonday = (weekday + 5) % 7 // Mon=0, Tue=1, ..., Sun=6
        let monday = cal.date(byAdding: .day, value: -daysFromMonday, to: today) ?? today
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter.string(from: monday)
    }

    private var shouldShowWeeklyReport: Bool {
        // Show all week until dismissed (report generated each Monday)
        guard !brainScores.isEmpty || !exercises.isEmpty else { return false }
        if lastWeeklyReportDismissed != thisMondayString {
            return true
        }
        return false
    }

    private var weeklyReportData: (weekStart: Date, weekEnd: Date, currentScore: Int, previousScore: Int, currentAge: Int, previousAge: Int, streak: Int, bestGame: String, gamesPlayed: Int) {
        let cal = Calendar.current
        let now = Date.now
        let weekAgo = cal.date(byAdding: .day, value: -7, to: now) ?? now

        let currentScore = brainScores.first?.brainScore ?? 0
        let currentAge = brainScores.first?.brainAge ?? 0
        let previousResult = brainScores.first(where: { $0.date <= weekAgo })
        let previousScore = previousResult?.brainScore ?? currentScore
        let previousAge = previousResult?.brainAge ?? currentAge

        let weekExercises = exercises.filter { $0.completedAt >= weekAgo }
        let gamesPlayed = weekExercises.count

        // Best game = exercise with highest score this week
        let bestExercise = weekExercises.max(by: { $0.score < $1.score })
        let bestGame = bestExercise?.type.displayName ?? ""

        let streak = user?.currentStreak ?? 0

        return (weekAgo, now, currentScore, previousScore, currentAge, previousAge, streak, bestGame, gamesPlayed)
    }

    private var greeting: String {
        let hour = Calendar.current.component(.hour, from: Date.now)
        let timeGreeting: String
        if hour < 12 { timeGreeting = "Good morning" }
        else if hour < 17 { timeGreeting = "Good afternoon" }
        else { timeGreeting = "Good evening" }

        if let name = user?.username, !name.isEmpty {
            return "\(timeGreeting), \(name)"
        }
        return timeGreeting
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    // Personalized greeting header
                    HStack(alignment: .center) {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(greeting)
                                .font(.title2.weight(.bold))
                            if let user {
                                Text("Level \(user.level) \u{00B7} \(user.levelName)")
                                    .font(.subheadline)
                                    .foregroundStyle(.secondary)
                            }
                        }
                        Spacer()
                        if let user {
                            Text("Lv\(user.level)")
                                .font(.system(size: 13, weight: .bold, design: .rounded))
                                .foregroundStyle(AppColors.accent)
                                .frame(width: 44, height: 44)
                                .background(AppColors.accent.opacity(0.1), in: Circle())
                        }
                    }
                    .staggeredEntrance(index: 0)

                    // Weekly Brain Report card (shows on Mondays until dismissed)
                    if shouldShowWeeklyReport {
                        weeklyReportCard
                            .staggeredEntrance(index: 1)
                    }

                    // Smart Daily Workout — primary daily action, top of page
                    if let workout = workoutEngine.todaysWorkout {
                        WorkoutCard(
                            workout: workout,
                            onStartGame: { exerciseType in
                                isInWorkoutMode = true
                                workoutGameToPlay = exerciseType
                            },
                            onSeeResults: {
                                if workoutScoreSaved {
                                    // Already saved — show saved values without recomputing
                                    showingWorkoutComplete = true
                                    return
                                }
                                // Use workoutEngine.todaysWorkout directly (not captured struct)
                                let games = workoutEngine.todaysWorkout?.games ?? []
                                let result = workoutEngine.computeRollingBrainScore(
                                    oldScore: latestBrainScore,
                                    workoutGames: games
                                )
                                workoutOldBrainScore = latestBrainScore?.brainScore ?? 0
                                workoutOldBrainAge = latestBrainScore?.brainAge ?? 50
                                workoutNewBrainScore = result.brainScore
                                workoutNewBrainAge = result.brainAge
                                workoutNewResult = result
                                showingWorkoutComplete = true
                            }
                        )
                        .staggeredEntrance(index: 1)
                    }

                    // Brain Score Ring + Stats
                    brainScoreCard
                        .staggeredEntrance(index: 2)

                    // Streak Week Calendar
                    streakWeekCard
                        .staggeredEntrance(index: 3)

                    // Daily Challenge — high priority, brings users back
                    dailyChallengeCard
                        .staggeredEntrance(index: 4)

                    if isNewUser {
                        getStartedCard
                            .staggeredEntrance(index: 5)
                    } else {
                        // Brain Score History Chart
                        if brainScores.count >= 2 {
                            BrainScoreChart(scores: brainScores, height: 150, showHeader: true)
                                .glowingCard(color: AppColors.accent, intensity: 0.15)
                                .staggeredEntrance(index: 5)
                        }

                        TrainingLimitBanner(trainingMinutes: trainingManager.todayTrainingMinutes)
                    }

                }
                .padding(.horizontal)
                .padding(.top, 8)
                .padding(.bottom, 32)
                .responsiveContent()
                .frame(maxWidth: .infinity)
            }
            .pageBackground()
            .navigationTitle("Memori")
            .navigationDestination(item: $workoutGameToPlay) { type in
                exerciseView(for: type)
            }
            .sheet(isPresented: $showingPaywall) {
                PaywallView()
            }
            .fullScreenCover(isPresented: $showingAssessment) {
                NavigationStack {
                    BrainAssessmentView()
                        .toolbar {
                            ToolbarItem(placement: .topBarLeading) {
                                Button {
                                    showingAssessment = false
                                } label: {
                                    Image(systemName: "xmark.circle.fill")
                                        .font(.title3)
                                        .foregroundStyle(.secondary)
                                }
                                .accessibilityLabel("Close")
                            }
                        }
                }
            }
            .fullScreenCover(isPresented: $showingWorkoutComplete) {
                WorkoutCompleteView(
                    oldBrainScore: workoutOldBrainScore,
                    newBrainScore: workoutNewBrainScore,
                    oldBrainAge: workoutOldBrainAge,
                    newBrainAge: workoutNewBrainAge,
                    streak: user?.currentStreak ?? 0,
                    userAge: user?.userAge ?? 0,
                    onDone: {
                        // Save the new brain score only once
                        if !workoutScoreSaved, let result = workoutNewResult {
                            let score = BrainScoreResult()
                            score.brainScore = result.brainScore
                            score.brainAge = result.brainAge
                            score.percentile = result.percentile
                            score.brainType = result.brainType
                            score.digitSpanScore = result.digitSpanScore
                            score.reactionTimeScore = result.reactionTimeScore
                            score.visualMemoryScore = result.visualMemoryScore
                            score.sourceRaw = BrainScoreSource.workout.rawValue
                            modelContext.insert(score)
                            workoutScoreSaved = true
                        }
                        showingWorkoutComplete = false
                    }
                )
            }
            .onAppear {
                viewModel.refresh(user: user, sessions: sessions)
                renderBrainScoreShareImage()
                // Generate today's workout
                workoutEngine.generateWorkout(
                    exercises: exercises,
                    userGoals: user?.focusGoals ?? []
                )
            }
            .onReceive(NotificationCenter.default.publisher(for: .workoutGameCompleted)) { notification in
                guard let typeRaw = notification.userInfo?["exerciseType"] as? String,
                      let type = ExerciseType(rawValue: typeRaw),
                      let score = notification.userInfo?["score"] as? Double else { return }
                workoutGameJustCompleted = true
                let allDone = workoutEngine.recordGameCompletion(exerciseType: type, score: score)

                // If all 3 games done and we're in workout mode, show celebration
                if allDone && isInWorkoutMode {
                    isInWorkoutMode = false
                    let games = workoutEngine.todaysWorkout?.games ?? []
                    let result = workoutEngine.computeRollingBrainScore(
                        oldScore: latestBrainScore,
                        workoutGames: games
                    )
                    workoutOldBrainScore = latestBrainScore?.brainScore ?? 0
                    workoutOldBrainAge = latestBrainScore?.brainAge ?? 50
                    workoutNewBrainScore = result.brainScore
                    workoutNewBrainAge = result.brainAge
                    workoutNewResult = result
                    workoutScoreSaved = false
                    // Small delay to let game view dismiss first
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                        showingWorkoutComplete = true
                    }
                }
            }
            .onChange(of: workoutGameToPlay) { oldValue, newValue in
                // User came back from a game — chain to next if game was completed
                guard oldValue != nil, newValue == nil, isInWorkoutMode else { return }

                // If user hit back manually (no game completed), stop the workout
                guard workoutGameJustCompleted else {
                    isInWorkoutMode = false
                    return
                }
                workoutGameJustCompleted = false

                guard let workout = workoutEngine.todaysWorkout,
                      !workout.isComplete,
                      let next = workout.nextGame else { return }
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                    workoutGameToPlay = next.exerciseType
                }
            }
        }
    }

    // MARK: - Free Exercise Counter

    private var freeExerciseCounter: some View {
        let remaining = paywallTrigger.freeExercisesRemaining
        let total = Constants.Defaults.freeExercisesPerDay
        let used = paywallTrigger.exercisesToday

        return HStack(spacing: 12) {
            // Dot indicators
            HStack(spacing: 6) {
                ForEach(0..<total, id: \.self) { i in
                    Circle()
                        .fill(i < used ? AppColors.accent : AppColors.accent.opacity(0.2))
                        .frame(width: 10, height: 10)
                }
            }

            VStack(alignment: .leading, spacing: 1) {
                Text("\(remaining) of \(total) free exercises left")
                    .font(.caption.weight(.semibold))
                Text("Upgrade for unlimited training")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            Button {
                showingPaywall = true
            } label: {
                Text("Go Pro")
                    .font(.caption.weight(.bold))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(AppColors.accent, in: Capsule())
            }
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(AppColors.accent.opacity(0.06))
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(AppColors.accent.opacity(0.15), lineWidth: 1)
                )
        )
    }

    // MARK: - Level Bar

    private func levelBar(_ user: User) -> some View {
        HStack(spacing: 12) {
            ZStack {
                Circle()
                    .fill(AppColors.accent.opacity(0.20))
                    .frame(width: 44, height: 44)
                Text("\(user.level)")
                    .font(.system(size: 18, weight: .bold, design: .rounded))
                    .foregroundStyle(AppColors.accent)
            }

            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text(user.levelName)
                        .font(.subheadline.weight(.bold))

                    Spacer()

                    Text("\(user.totalXP) XP")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(AppColors.accent)
                }

                // XP Progress bar
                GeometryReader { geo in
                    ZStack(alignment: .leading) {
                        RoundedRectangle(cornerRadius: 4)
                            .fill(AppColors.accent.opacity(0.20))
                            .frame(height: 6)

                        RoundedRectangle(cornerRadius: 4)
                            .fill(AppColors.accent)
                            .frame(width: max(4, geo.size.width * user.xpProgress), height: 6)
                            .animation(.spring(response: 0.5), value: user.xpProgress)
                    }
                }
                .frame(height: 6)
            }
        }
        .glowingCard(color: AppColors.accent, intensity: 0.15)
    }

    // MARK: - Weekly Report Card

    private var weeklyReportCard: some View {
        let data = weeklyReportData
        let scoreDelta = data.currentScore - data.previousScore

        return VStack(spacing: 0) {
            // Header with dismiss
            HStack {
                HStack(spacing: 8) {
                    Image(systemName: "chart.line.uptrend.xyaxis")
                        .font(.system(size: 14, weight: .bold))
                        .foregroundStyle(AppColors.accent)
                    Text("Weekly Brain Report")
                        .font(.system(size: 15, weight: .bold))
                }
                Spacer()
                Button {
                    withAnimation(.easeOut(duration: 0.25)) {
                        lastWeeklyReportDismissed = thisMondayString
                    }
                } label: {
                    Image(systemName: "xmark")
                        .font(.system(size: 12, weight: .bold))
                        .foregroundStyle(.secondary)
                        .frame(width: 28, height: 28)
                        .background(AppColors.cardSurface, in: Circle())
                }
                .accessibilityLabel("Dismiss")
            }
            .padding(.horizontal, 16)
            .padding(.top, 14)
            .padding(.bottom, 10)

            Divider()
                .padding(.horizontal, 16)

            // Content
            VStack(spacing: 14) {
                // Brain Score change
                if data.currentScore > 0 {
                    HStack(spacing: 12) {
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Brain Score")
                                .font(.caption.weight(.semibold))
                                .foregroundStyle(.secondary)
                            HStack(spacing: 6) {
                                if data.previousScore > 0 && data.previousScore != data.currentScore {
                                    Text("\(data.previousScore)")
                                        .font(.system(size: 18, weight: .bold, design: .rounded))
                                        .foregroundStyle(.secondary)
                                    Image(systemName: "arrow.right")
                                        .font(.system(size: 12, weight: .bold))
                                        .foregroundStyle(.secondary)
                                }
                                Text("\(data.currentScore)")
                                    .font(.system(size: 22, weight: .bold, design: .rounded))
                                    .foregroundStyle(AppColors.accent)
                            }
                        }
                        Spacer()
                        if data.previousScore > 0 && scoreDelta != 0 {
                            HStack(spacing: 3) {
                                Image(systemName: scoreDelta > 0 ? "arrow.up.right" : "arrow.down.right")
                                    .font(.system(size: 12, weight: .bold))
                                Text(scoreDelta > 0 ? "+\(scoreDelta)" : "\(scoreDelta)")
                                    .font(.system(size: 16, weight: .bold, design: .rounded))
                            }
                            .foregroundStyle(scoreDelta > 0 ? Color(red: 0.34, green: 0.85, blue: 0.74) : AppColors.coral)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 6)
                            .background(
                                (scoreDelta > 0 ? Color(red: 0.34, green: 0.85, blue: 0.74) : AppColors.coral).opacity(0.12),
                                in: Capsule()
                            )
                        }
                    }
                }

                // Brain Age trend
                if data.currentAge > 0 {
                    let ageDelta = data.currentAge - data.previousAge
                    HStack {
                        HStack(spacing: 6) {
                            Image(systemName: "brain.head.profile")
                                .font(.system(size: 13, weight: .bold))
                                .foregroundStyle(AppColors.violet)
                            Text("Brain Age")
                                .font(.system(size: 13, weight: .semibold))
                                .foregroundStyle(.secondary)
                        }
                        Spacer()
                        if ageDelta != 0 && data.previousAge > 0 {
                            Text("Brain Age \(ageDelta < 0 ? "dropped" : "rose") \(abs(ageDelta)) year\(abs(ageDelta) == 1 ? "" : "s")")
                                .font(.system(size: 13, weight: .semibold))
                                .foregroundStyle(ageDelta < 0 ? Color(red: 0.34, green: 0.85, blue: 0.74) : AppColors.coral)
                        } else {
                            Text("Age \(data.currentAge)")
                                .font(.system(size: 13, weight: .semibold))
                        }
                    }
                }

                // Stats row
                HStack(spacing: 0) {
                    // Streak
                    VStack(spacing: 4) {
                        HStack(spacing: 4) {
                            Image(systemName: "flame.fill")
                                .font(.system(size: 11, weight: .bold))
                                .foregroundStyle(AppColors.coral)
                            Text("\(data.streak)")
                                .font(.system(size: 16, weight: .bold, design: .rounded))
                        }
                        Text("Streak")
                            .font(.system(size: 10, weight: .semibold))
                            .foregroundStyle(.secondary)
                    }
                    .frame(maxWidth: .infinity)

                    // Games Played
                    VStack(spacing: 4) {
                        HStack(spacing: 4) {
                            Image(systemName: "gamecontroller.fill")
                                .font(.system(size: 11, weight: .bold))
                                .foregroundStyle(AppColors.teal)
                            Text("\(data.gamesPlayed)")
                                .font(.system(size: 16, weight: .bold, design: .rounded))
                        }
                        Text("Games")
                            .font(.system(size: 10, weight: .semibold))
                            .foregroundStyle(.secondary)
                    }
                    .frame(maxWidth: .infinity)

                    // Best Game
                    if !data.bestGame.isEmpty {
                        VStack(spacing: 4) {
                            HStack(spacing: 4) {
                                Image(systemName: "trophy.fill")
                                    .font(.system(size: 11, weight: .bold))
                                    .foregroundStyle(AppColors.amber)
                                Text(data.bestGame)
                                    .font(.system(size: 12, weight: .bold))
                                    .lineLimit(1)
                                    .minimumScaleFactor(0.7)
                            }
                            Text("Best Game")
                                .font(.system(size: 10, weight: .semibold))
                                .foregroundStyle(.secondary)
                        }
                        .frame(maxWidth: .infinity)
                    }
                }

                // Share button
                if let shareImg = weeklyReportShareImage {
                    ShareLink(
                        item: Image(uiImage: shareImg),
                        preview: SharePreview(
                            "Weekly Brain Report",
                            image: Image(uiImage: shareImg)
                        )
                    ) {
                        HStack(spacing: 6) {
                            Image(systemName: "square.and.arrow.up")
                                .font(.system(size: 12, weight: .bold))
                            Text("Share Report")
                                .font(.system(size: 13, weight: .bold))
                        }
                        .foregroundStyle(AppColors.accent)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 10)
                        .background(AppColors.accent.opacity(0.1), in: RoundedRectangle(cornerRadius: 10))
                    }
                }
            }
            .padding(16)
        }
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(AppColors.cardSurface)
                .overlay(
                    RoundedRectangle(cornerRadius: 16)
                        .stroke(AppColors.accent.opacity(0.15), lineWidth: 1)
                )
        )
        .onAppear {
            renderWeeklyReportShareImage()
        }
    }

    private func renderWeeklyReportShareImage() {
        let data = weeklyReportData
        let card = WeeklyReportShareCard(
            weekStart: data.weekStart,
            weekEnd: data.weekEnd,
            brainScore: data.currentScore,
            previousBrainScore: data.previousScore,
            brainAge: data.currentAge,
            previousBrainAge: data.previousAge,
            streakLength: data.streak,
            bestGameName: data.bestGame,
            gamesPlayed: data.gamesPlayed
        )
        weeklyReportShareImage = card.renderAsImage(
            size: CGSize(width: 360, height: 640),
            scale: 3
        )
    }

    // MARK: - Brain Score Card

    private var brainScoreCard: some View {
        Group {
            if let score = latestBrainScore {
                VStack(spacing: 0) {
                    BrainScoreCard(score: score, compact: false, userAge: user?.userAge ?? 0)

                    // Divider
                    Rectangle()
                        .fill(AppColors.cardBorder)
                        .frame(height: 1)

                    // Actions row
                    HStack {
                        Button {
                            if storeService.isProUser {
                                showingAssessment = true
                            } else {
                                showingPaywall = true
                            }
                        } label: {
                            HStack(spacing: 5) {
                                Image(systemName: storeService.isProUser ? "arrow.counterclockwise" : "lock.fill")
                                    .font(.system(size: 11, weight: .bold))
                                Text("Retake")
                                    .font(.system(size: 13, weight: .semibold))
                            }
                            .foregroundStyle(AppColors.accent)
                        }

                        Spacer()

                        if let shareImg = brainScoreShareImage {
                            ShareLink(
                                item: Image(uiImage: shareImg),
                                preview: SharePreview(
                                    "Brain Score: \(score.brainScore)",
                                    image: Image(uiImage: shareImg)
                                )
                            ) {
                                HStack(spacing: 5) {
                                    Image(systemName: "square.and.arrow.up")
                                        .font(.system(size: 11, weight: .bold))
                                    Text("Share")
                                        .font(.system(size: 13, weight: .semibold))
                                }
                                .foregroundStyle(AppColors.textTertiary)
                            }
                        } else {
                            ShareLink(item: "My Brain Score is \(score.brainScore)/1000 (Brain Age: \(score.brainAge)) — \(score.brainType.displayName)\nTest yours with Memori") {
                                HStack(spacing: 5) {
                                    Image(systemName: "square.and.arrow.up")
                                        .font(.system(size: 11, weight: .bold))
                                    Text("Share")
                                        .font(.system(size: 13, weight: .semibold))
                                }
                                .foregroundStyle(AppColors.textTertiary)
                            }
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 12)
                }
                .background {
                    RoundedRectangle(cornerRadius: 16)
                        .fill(AppColors.cardSurface)
                        .shadow(color: .black.opacity(0.06), radius: 12, y: 4)
                }
                .clipShape(RoundedRectangle(cornerRadius: 16))
            } else {
                Button {
                    showingAssessment = true
                } label: {
                    VStack(spacing: 20) {
                        Image(systemName: "brain.head.profile")
                            .font(.system(size: 48, weight: .medium))
                            .foregroundStyle(AppColors.accent)

                        VStack(spacing: 6) {
                            Text("Discover Your\nBrain Score")
                                .font(.title2.weight(.bold))
                                .multilineTextAlignment(.center)
                            Text("2-minute assessment across 3 cognitive domains")
                                .font(.subheadline)
                                .foregroundStyle(AppColors.textSecondary)
                                .multilineTextAlignment(.center)
                        }

                        HStack(spacing: 8) {
                            ForEach(["Memory", "Speed", "Visual"], id: \.self) { name in
                                Text(name)
                                    .font(.caption2.weight(.bold))
                                    .foregroundStyle(AppColors.accent)
                                    .padding(.horizontal, 10)
                                    .padding(.vertical, 5)
                                    .background(AppColors.accent.opacity(0.1), in: Capsule())
                            }
                        }

                        Text("Start Assessment")
                            .font(.headline.weight(.bold))
                            .foregroundStyle(.white)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 14)
                            .background(AppColors.accent, in: RoundedRectangle(cornerRadius: 12))
                    }
                    .padding(.vertical, 28)
                    .padding(.horizontal, 24)
                    .frame(maxWidth: .infinity)
                    .appCard(padding: 0)
                }
                .buttonStyle(.plain)
            }
        }
    }

    @MainActor
    private func renderBrainScoreShareImage() {
        guard let score = latestBrainScore else { return }
        let card = ShareCardView(
            brainScore: score.brainScore,
            brainAge: score.brainAge,
            brainType: score.brainType,
            percentile: score.percentile,
            digitScore: score.digitSpanScore,
            reactionScore: score.reactionTimeScore,
            visualScore: score.visualMemoryScore
        )
        brainScoreShareImage = card.renderImage()
    }

    // MARK: - Streak Week Calendar Card

    private var streakWeekCard: some View {
        VStack(spacing: 12) {
            HStack {
                HStack(spacing: 8) {
                    Image(systemName: "flame.fill")
                        .foregroundStyle(viewModel.currentStreak > 0 ? AppColors.coral : .secondary)
                    Text("\(viewModel.currentStreak) day streak")
                        .font(.headline.weight(.bold))
                }
                .accessibilityElement(children: .combine)
                .accessibilityLabel("\(viewModel.currentStreak) day streak")

                Spacer()

                if viewModel.longestStreak > 0 {
                    Text("Best: \(viewModel.longestStreak)")
                        .font(.caption.weight(.medium))
                        .foregroundStyle(.secondary)
                }
            }

            StreakWeekView(
                sessions: sessions.map(\.date),
                currentStreak: viewModel.currentStreak
            )

            if user?.isStreakActive != true {
                Text("Complete an exercise today to keep your streak")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 14)
                .fill(viewModel.currentStreak > 0 ? AppColors.coral.opacity(0.06) : AppColors.cardSurface)
                .shadow(color: .black.opacity(0.06), radius: 8, y: 2)
        )
    }

    // MARK: - Today's Session Card (Curated Workout)

    private var todaysSessionCard: some View {
        VStack(spacing: 16) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("TODAY'S SESSION")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundStyle(.secondary)
                        .tracking(1.2)
                    Text("\(viewModel.todaySessionCount) of \(viewModel.dailyGoal) complete")
                        .font(.subheadline.weight(.medium))
                }
                .accessibilityElement(children: .combine)

                Spacer()

                // Circular progress ring
                ZStack {
                    Circle()
                        .stroke(AppColors.accent.opacity(0.18), lineWidth: 5)
                    Circle()
                        .trim(from: 0, to: viewModel.dailyGoal > 0 ? min(Double(viewModel.todaySessionCount) / Double(viewModel.dailyGoal), 1.0) : 0)
                        .stroke(
                            AppColors.accent,
                            style: StrokeStyle(lineWidth: 5, lineCap: .round)
                        )
                        .rotationEffect(.degrees(-90))
                    Text("\(viewModel.todaySessionCount)")
                        .font(.system(size: 14, weight: .bold, design: .rounded))
                }
                .frame(width: 44, height: 44)
            }

            // Recommended exercise tiles
            let goals = user?.focusGoals ?? []
            let recs = Array(trainingManager.recommendedExercises(for: goals).prefix(3))
            if !recs.isEmpty {
                HStack(spacing: 10) {
                    ForEach(recs) { rec in
                        NavigationLink {
                            destination(for: rec.destination)
                        } label: {
                            VStack(spacing: 0) {
                                sessionTileMiniPreview(for: rec)
                                    .frame(maxWidth: .infinity)
                                    .frame(height: 56)
                                    .clipped()

                                VStack(spacing: 2) {
                                    Text(rec.title)
                                        .font(.system(size: 10, weight: .bold))
                                        .foregroundStyle(.primary)
                                        .lineLimit(1)
                                        .minimumScaleFactor(0.8)

                                    if let lastPlayed = lastPlayedTextForDestination(rec.destination) {
                                        Text(lastPlayed)
                                            .font(.system(size: 9, weight: .medium))
                                            .foregroundStyle(AppColors.textTertiary)
                                    } else {
                                        Text("New")
                                            .font(.system(size: 9, weight: .semibold))
                                            .foregroundStyle(AppColors.accent.opacity(0.7))
                                    }
                                }
                                .padding(.horizontal, 4)
                                .padding(.vertical, 7)
                                .frame(maxWidth: .infinity)
                            }
                            .background {
                                RoundedRectangle(cornerRadius: 12)
                                    .fill(AppColors.cardSurface)
                            }
                            .overlay(
                                RoundedRectangle(cornerRadius: 12)
                                    .stroke(rec.color.opacity(0.2), lineWidth: 1)
                            )
                            .clipShape(RoundedRectangle(cornerRadius: 12))
                        }
                        .buttonStyle(.plain)
                    }
                }
            }

            Button {
                selectedTab = 1
            } label: {
                Text("Start Training")
                    .gradientButton()
            }
            .accessibilityHint("Begins today's training session")
        }
        .glowingCard(color: AppColors.accent, intensity: 0.20)
    }

    // MARK: - Session Tile Mini Preview

    @ViewBuilder
    private func sessionTileMiniPreview(for rec: ExerciseRecommendation) -> some View {
        let color = rec.color
        switch rec.destination {
        case .dualNBack:
            // 3x3 grid with highlighted cell
            ZStack {
                color.opacity(0.06)
                LazyVGrid(columns: Array(repeating: GridItem(.fixed(14), spacing: 2), count: 3), spacing: 2) {
                    ForEach(0..<9, id: \.self) { i in
                        RoundedRectangle(cornerRadius: 2)
                            .fill(i == 4 ? color : color.opacity(0.12))
                            .frame(height: 14)
                    }
                }
                Text("2")
                    .font(.system(size: 8, weight: .black, design: .rounded))
                    .foregroundStyle(color)
                    .offset(x: 18, y: -18)
                    .padding(2)
                    .background(color.opacity(0.15), in: Circle())
            }

        case .spacedRepetition(_):
            // Flashcard stack
            ZStack {
                color.opacity(0.06)
                ZStack {
                    RoundedRectangle(cornerRadius: 4)
                        .fill(color.opacity(0.10))
                        .frame(width: 34, height: 26)
                        .offset(x: 3, y: -3)
                    RoundedRectangle(cornerRadius: 4)
                        .fill(color.opacity(0.20))
                        .frame(width: 34, height: 26)
                    Text("?")
                        .font(.system(size: 14, weight: .black, design: .rounded))
                        .foregroundStyle(color)
                }
            }

        case .activeRecall:
            // Quiz-style multiple choice dots
            ZStack {
                color.opacity(0.06)
                VStack(spacing: 4) {
                    RoundedRectangle(cornerRadius: 3)
                        .fill(color.opacity(0.15))
                        .frame(width: 48, height: 10)
                    HStack(spacing: 4) {
                        ForEach(0..<3, id: \.self) { i in
                            Circle()
                                .fill(i == 1 ? color : color.opacity(0.15))
                                .frame(width: 14, height: 14)
                                .overlay(
                                    i == 1 ?
                                    Image(systemName: "checkmark")
                                        .font(.system(size: 7, weight: .bold))
                                        .foregroundStyle(.white)
                                    : nil
                                )
                        }
                    }
                }
            }

        case .mixedTraining:
            // Mixed icons collage
            ZStack {
                color.opacity(0.06)
                HStack(spacing: 5) {
                    ForEach(["brain.fill", "bolt.fill", "number"], id: \.self) { icon in
                        Image(systemName: icon)
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundStyle(color)
                            .frame(width: 22, height: 22)
                            .background(color.opacity(0.12), in: RoundedRectangle(cornerRadius: 5))
                    }
                }
            }

        case .dailyChallenge:
            // Calendar day with star
            ZStack {
                color.opacity(0.06)
                VStack(spacing: 2) {
                    Image(systemName: "star.fill")
                        .font(.system(size: 10))
                        .foregroundStyle(AppColors.amber)
                    RoundedRectangle(cornerRadius: 4)
                        .fill(color.opacity(0.15))
                        .frame(width: 30, height: 24)
                        .overlay(
                            Text("\(Calendar.current.component(.day, from: Date()))")
                                .font(.system(size: 12, weight: .bold, design: .rounded))
                                .foregroundStyle(color)
                        )
                }
            }

        case .brainAssessment:
            // Brain scan rings
            ZStack {
                color.opacity(0.06)
                ZStack {
                    Circle()
                        .stroke(color.opacity(0.15), lineWidth: 2)
                        .frame(width: 36, height: 36)
                    Circle()
                        .trim(from: 0, to: 0.7)
                        .stroke(color, style: StrokeStyle(lineWidth: 2.5, lineCap: .round))
                        .frame(width: 36, height: 36)
                        .rotationEffect(.degrees(-90))
                    Image(systemName: "brain")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(color)
                }
            }

        case .exercise(let type):
            switch type {
            case .reactionTime:
                ZStack {
                    color.opacity(0.06)
                    Circle()
                        .stroke(color.opacity(0.3), lineWidth: 2)
                        .frame(width: 34, height: 34)
                    Circle()
                        .fill(color.opacity(0.15))
                        .frame(width: 24, height: 24)
                    Image(systemName: "bolt.fill")
                        .font(.system(size: 13, weight: .bold))
                        .foregroundStyle(color)
                }
            case .colorMatch:
                ZStack {
                    color.opacity(0.06)
                    VStack(spacing: 2) {
                        Text("RED")
                            .font(.system(size: 9, weight: .black, design: .rounded))
                            .foregroundStyle(AppColors.sky)
                        Text("BLUE")
                            .font(.system(size: 11, weight: .black, design: .rounded))
                            .foregroundStyle(AppColors.coral)
                    }
                }
            case .speedMatch:
                ZStack {
                    color.opacity(0.06)
                    HStack(spacing: 4) {
                        RoundedRectangle(cornerRadius: 4)
                            .fill(color.opacity(0.15))
                            .frame(width: 22, height: 26)
                            .overlay(
                                Image(systemName: "star.fill")
                                    .font(.system(size: 9))
                                    .foregroundStyle(color)
                            )
                        RoundedRectangle(cornerRadius: 4)
                            .fill(color.opacity(0.15))
                            .frame(width: 22, height: 26)
                            .overlay(
                                Image(systemName: "star.fill")
                                    .font(.system(size: 9))
                                    .foregroundStyle(color)
                            )
                    }
                }
            case .visualMemory:
                ZStack {
                    color.opacity(0.06)
                    LazyVGrid(columns: Array(repeating: GridItem(.fixed(12), spacing: 2), count: 4), spacing: 2) {
                        ForEach(0..<16, id: \.self) { i in
                            RoundedRectangle(cornerRadius: 2)
                                .fill([2, 5, 10, 13].contains(i) ? color : color.opacity(0.12))
                                .frame(height: 12)
                        }
                    }
                }
            case .sequentialMemory:
                ZStack {
                    color.opacity(0.06)
                    HStack(spacing: 3) {
                        ForEach(["3", "8", "1"], id: \.self) { d in
                            Text(d)
                                .font(.system(size: 12, weight: .bold, design: .monospaced))
                                .foregroundStyle(color)
                                .frame(width: 18, height: 22)
                                .background(color.opacity(0.12), in: RoundedRectangle(cornerRadius: 4))
                        }
                    }
                }
            case .mathSpeed:
                ZStack {
                    color.opacity(0.06)
                    VStack(spacing: 3) {
                        Text("7 × 8")
                            .font(.system(size: 14, weight: .bold, design: .rounded))
                            .foregroundStyle(color)
                        HStack(spacing: 4) {
                            ForEach(["54", "56", "58"], id: \.self) { a in
                                Text(a)
                                    .font(.system(size: 8, weight: .bold, design: .rounded))
                                    .foregroundStyle(a == "56" ? .white : color.opacity(0.6))
                                    .frame(width: 22, height: 16)
                                    .background(
                                        (a == "56" ? color : color.opacity(0.12)),
                                        in: RoundedRectangle(cornerRadius: 3)
                                    )
                            }
                        }
                    }
                }
            case .chunkingTraining:
                ZStack {
                    color.opacity(0.06)
                    HStack(spacing: 5) {
                        ForEach(["48", "91", "35"], id: \.self) { chunk in
                            Text(chunk)
                                .font(.system(size: 10, weight: .bold, design: .monospaced))
                                .foregroundStyle(color)
                                .padding(.horizontal, 4)
                                .padding(.vertical, 3)
                                .background(color.opacity(0.12), in: RoundedRectangle(cornerRadius: 4))
                        }
                    }
                }
            default:
                ZStack {
                    color.opacity(0.06)
                    Image(systemName: rec.icon)
                        .font(.system(size: 20, weight: .semibold))
                        .foregroundStyle(color)
                }
            }
        }
    }

    // MARK: - Get Started Card (New Users)

    private var getStartedCard: some View {
        VStack(spacing: 16) {
            HStack(spacing: 12) {
                Image(systemName: "sparkles")
                    .font(.title2)
                    .foregroundStyle(AppColors.accent)
                VStack(alignment: .leading, spacing: 2) {
                    Text("Start Training")
                        .font(.headline.weight(.bold))
                    Text("Complete your first exercise to begin tracking progress")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer()
            }

            Button {
                selectedTab = 1
            } label: {
                Text("Go to Exercises")
                    .gradientButton()
            }
        }
        .padding(20)
        .glowingCard(color: AppColors.accent, intensity: 0.15)
    }

    // MARK: - Daily Challenge Card

    private var dailyChallengeCard: some View {
        Group {
            if hasDoneDailyChallenge {
                HStack(spacing: 14) {
                    ColoredIconBadge(icon: "checkmark.circle.fill", color: AppColors.teal)

                    VStack(alignment: .leading, spacing: 2) {
                        Text("Daily Challenge")
                            .font(.subheadline.weight(.semibold))
                        Text("Completed! Come back tomorrow")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }

                    Spacer()
                }
                .padding(16)
                .background(
                    RoundedRectangle(cornerRadius: 14)
                        .fill(AppColors.teal.opacity(0.08))
                        .shadow(color: .black.opacity(0.04), radius: 6, y: 2)
                )
            } else {
                NavigationLink {
                    DailyChallengeView()
                } label: {
                    HStack(spacing: 14) {
                        ColoredIconBadge(icon: "trophy.fill", color: .orange)

                        VStack(alignment: .leading, spacing: 2) {
                            Text("Daily Challenge")
                                .font(.subheadline.weight(.semibold))
                            Text("Same challenge for everyone \u{2014} Compete!")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }

                        Spacer()

                        Image(systemName: "chevron.right")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(.tertiary)
                    }
                    .padding(16)
                    .background(
                        RoundedRectangle(cornerRadius: 14)
                            .fill(Color.orange.opacity(0.08))
                            .shadow(color: .black.opacity(0.04), radius: 6, y: 2)
                    )
                }
                .buttonStyle(.plain)
            }
        }
    }

    @ViewBuilder
    private func destination(for dest: ExerciseDestination) -> some View {
        switch dest {
        case .spacedRepetition(let cat): SpacedRepetitionView(category: cat)
        case .dualNBack: DualNBackView()
        case .activeRecall: ActiveRecallView()
        case .mixedTraining: MixedTrainingView()
        case .dailyChallenge: DailyChallengeView()
        case .brainAssessment: BrainAssessmentView()
        case .exercise(let type): exerciseView(for: type)
        }
    }

    @ViewBuilder
    private func exerciseView(for type: ExerciseType) -> some View {
        switch type {
        case .reactionTime: ReactionTimeView()
        case .colorMatch: ColorMatchView()
        case .speedMatch: SpeedMatchView()
        case .visualMemory: VisualMemoryView()
        case .sequentialMemory: SequentialMemoryView()
        case .mathSpeed: MathSpeedView()
        case .chunkingTraining: ChunkingTrainingView()
        case .dualNBack: DualNBackView()
        default: MixedTrainingView()
        }
    }

    // MARK: - Learn Section

    private var learnSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                SectionHeader(title: "Learn")
                Spacer()
                NavigationLink {
                    EducationFeedView()
                } label: {
                    Text("See All")
                        .font(.subheadline.weight(.medium))
                        .foregroundStyle(AppColors.accent)
                }
            }

            ScrollView(.horizontal) {
                HStack(spacing: 12) {
                    ForEach(EducationContent.cards.prefix(5)) { card in
                        NavigationLink {
                            EducationDetailView(card: card)
                        } label: {
                            EducationCardView(card: card)
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
            .scrollIndicators(.hidden)
        }
    }
}

// MARK: - Education Card View (Horizontal)

struct EducationCardView: View {
    let card: PsychoEducationCard

    private var cardColor: Color {
        switch card.category {
        case .socialMedia: return AppColors.coral
        case .cannabis: return AppColors.mint
        case .sleep: return AppColors.indigo
        case .neuroplasticity: return AppColors.violet
        case .techniques: return AppColors.teal
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            ColoredIconBadge(icon: card.category.icon, color: cardColor, size: 36)

            Text(card.title)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.primary)
                .lineLimit(2)
                .multilineTextAlignment(.leading)

            Text(card.category.displayName)
                .font(.caption)
                .foregroundStyle(cardColor)
        }
        .frame(width: 160, alignment: .leading)
        .glowingCard(color: cardColor, intensity: 0.15)
    }
}
