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
    @Query(sort: \Exercise.completedAt, order: .reverse) private var allExercises: [Exercise]
    private var exercises: [Exercise] { Array(allExercises.prefix(50)) }

    @Binding var selectedTab: Int
    @Binding var decayPointsLost: Int
    @State private var viewModel = HomeViewModel()
    @State private var showingPaywall = false
    @State private var showingAssessment = false
    @State private var brainScoreShareImage: UIImage?
    @State private var showingFreezeInfo = false
    @AppStorage("lastWeeklyReportDismissed") private var lastWeeklyReportDismissed: String = ""
    @State private var weeklyReportShareImage: UIImage?
    @State private var streakAnimating = false
    @State private var streakBounce = false
    @State private var cachedTodayExerciseCount: Int = 0
    @State private var cachedWeeklyReport: (weekStart: Date, weekEnd: Date, currentScore: Int, previousScore: Int, currentAge: Int, previousAge: Int, streak: Int, bestGame: String, gamesPlayed: Int)?

    private static let dayFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd"
        return f
    }()

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

    // MARK: - Weekly Report Helpers

    private var thisMondayString: String {
        let cal = Calendar.current
        let today = cal.startOfDay(for: .now)
        let weekday = cal.component(.weekday, from: today)
        // weekday: 1=Sun, 2=Mon, ...
        let daysFromMonday = (weekday + 5) % 7 // Mon=0, Tue=1, ..., Sun=6
        let monday = cal.date(byAdding: .day, value: -daysFromMonday, to: today) ?? today
        return Self.dayFormatter.string(from: monday)
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
        cachedWeeklyReport ?? (.now, .now, 0, 0, 0, 0, 0, "", 0)
    }

    private func refreshWeeklyReport() {
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

        let bestExercise = weekExercises.max(by: { $0.score < $1.score })
        let bestGame = bestExercise?.type.displayName ?? ""

        let streak = user?.currentStreak ?? 0

        cachedWeeklyReport = (weekAgo, now, currentScore, previousScore, currentAge, previousAge, streak, bestGame, gamesPlayed)
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
                VStack(spacing: 16) {
                    // Compact header: greeting + streak + level
                    compactHeader
                        .staggeredEntrance(index: 0)

                    // Score decay warning (urgent, above mascot)
                    if decayPointsLost > 0 {
                        decayBanner
                    }

                    // Mascot Hero — dominates the screen
                    mascotHeroSection
                        .staggeredEntrance(index: 1)

                    // Focus Mode card
                    FocusModeCard()
                        .staggeredEntrance(index: 2)

                    // Brain Score + Brain Age compact stat pills
                    brainStatPills
                        .staggeredEntrance(index: 4)

                    // Weekly Brain Report (contextual)
                    if shouldShowWeeklyReport {
                        weeklyReportCard
                            .staggeredEntrance(index: 5)
                    }

                    // Streak Week Calendar
                    streakWeekCard
                        .staggeredEntrance(index: 6)

                    if isNewUser {
                        getStartedCard
                            .staggeredEntrance(index: 7)
                    } else {
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
            .toolbar(.hidden, for: .navigationBar)
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
            .task {
                renderBrainScoreShareImage()
            }
            .onAppear {
                viewModel.refresh(user: user, sessions: sessions)
                refreshTodayExerciseCount()
                refreshWeeklyReport()
            }
            .onChange(of: exercises.count) {
                refreshTodayExerciseCount()
                refreshWeeklyReport()
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
                    .contentTransition(.numericText())
            }

            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text(user.levelName)
                        .font(.subheadline.weight(.bold))

                    Spacer()

                    Text("\(user.totalXP) XP")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(AppColors.accent)
                        .contentTransition(.numericText())
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
                // Brain Score + Brain Age side by side
                HStack(spacing: 0) {
                    // Brain Score
                    if data.currentScore > 0 {
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Brain Score")
                                .font(.caption.weight(.semibold))
                                .foregroundStyle(.secondary)
                            HStack(spacing: 4) {
                                Text("\(data.currentScore)")
                                    .font(.system(size: 22, weight: .bold, design: .rounded))
                                    .foregroundStyle(AppColors.accent)
                                    .contentTransition(.numericText())
                                if data.previousScore > 0 && scoreDelta != 0 {
                                    Text(scoreDelta > 0 ? "+\(scoreDelta)" : "\(scoreDelta)")
                                        .font(.system(size: 12, weight: .bold, design: .rounded))
                                        .foregroundStyle(scoreDelta > 0 ? Color(red: 0.34, green: 0.85, blue: 0.74) : AppColors.coral)
                                }
                            }
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                    }

                    // Brain Age
                    if data.currentAge > 0 {
                        let ageDelta = data.currentAge - data.previousAge
                        VStack(alignment: .trailing, spacing: 2) {
                            Text("Brain Age")
                                .font(.caption.weight(.semibold))
                                .foregroundStyle(.secondary)
                            HStack(spacing: 4) {
                                Text("Age \(data.currentAge)")
                                    .font(.system(size: 22, weight: .bold, design: .rounded))
                                if ageDelta != 0 && data.previousAge > 0 {
                                    Text(ageDelta < 0 ? "\(ageDelta)yr" : "+\(ageDelta)yr")
                                        .font(.system(size: 12, weight: .bold, design: .rounded))
                                        .foregroundStyle(ageDelta < 0 ? Color(red: 0.34, green: 0.85, blue: 0.74) : AppColors.coral)
                                }
                            }
                        }
                        .frame(maxWidth: .infinity, alignment: .trailing)
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
                                .contentTransition(.numericText())
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
                                .contentTransition(.numericText())
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
        .task {
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

    // MARK: - Mascot Hero Section

    private var todayExerciseCount: Int { cachedTodayExerciseCount }

    private func refreshTodayExerciseCount() {
        let startOfDay = Calendar.current.startOfDay(for: Date())
        cachedTodayExerciseCount = exercises.filter { $0.completedAt >= startOfDay }.count
    }

    private var mascotMood: MascotRiveMood {
        // 3+ games today = happy
        if todayExerciseCount >= 3 {
            return .happy
        }
        // Haven't played recently = sad
        if let lastSession = user?.lastSessionDate,
           !Calendar.current.isDateInToday(lastSession),
           !Calendar.current.isDateInYesterday(lastSession) {
            return .sad
        }
        // Default: neutral (start of day, or <3 games)
        return .neutral
    }

    private var mascotMoodText: String {
        switch mascotMood {
        case .happy:
            return ["Memo is thriving rn", "Memo is locked in today", "Memo's neurons are on fire"][todayExerciseCount % 3]
        case .neutral:
            let remaining = 3 - todayExerciseCount
            if remaining == 1 {
                return "One more... don't leave Memo hanging"
            } else if remaining == 2 {
                return "Good start, Memo wants more"
            }
            return "Memo is bored... entertain it"
        case .sad:
            return ["Memo is losing brain cells", "Memo thinks you forgot about it", "Memo's neurons are collecting dust"][Calendar.current.component(.hour, from: .now) % 3]
        }
    }

    private var mascotMoodColor: Color {
        switch mascotMood {
        case .happy: return AppColors.teal
        case .neutral: return AppColors.amber
        case .sad: return AppColors.coral
        }
    }

    // MARK: - Compact Header

    private var compactHeader: some View {
        HStack(alignment: .center) {
            VStack(alignment: .leading, spacing: 2) {
                Text(greeting)
                    .font(.title3.weight(.bold))
                if let user {
                    Text("Level \(user.level) \u{00B7} \(user.levelName)")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            Spacer()

            // Streak flame badge
            HStack(spacing: 4) {
                Image(systemName: "flame.fill")
                    .font(.system(size: 14, weight: .bold))
                    .symbolEffect(.variableColor.iterative, options: .repeating, value: streakAnimating)
                    .foregroundStyle(viewModel.currentStreak > 0 ? streakGradient : AnyShapeStyle(.secondary))
                Text("\(viewModel.currentStreak)")
                    .font(.system(size: 15, weight: .black, design: .rounded))
                    .contentTransition(.numericText())
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(.ultraThinMaterial, in: Capsule())
            .onAppear { streakAnimating = true }
        }
    }

    // MARK: - Decay Banner

    private var decayBanner: some View {
        HStack(spacing: 8) {
            Image(systemName: "exclamationmark.triangle.fill")
                .foregroundStyle(AppColors.coral)
            VStack(alignment: .leading, spacing: 2) {
                Text("Your brain score dropped \(decayPointsLost) points")
                    .font(.subheadline.bold())
                    .foregroundStyle(AppColors.textPrimary)
                Text("Play today to stop the decline!")
                    .font(.caption)
                    .foregroundStyle(AppColors.textSecondary)
            }
            Spacer()
            Button {
                withAnimation { decayPointsLost = 0 }
            } label: {
                Image(systemName: "xmark")
                    .font(.caption)
                    .foregroundStyle(AppColors.textSecondary)
            }
        }
        .padding(12)
        .background(AppColors.coral.opacity(0.1), in: RoundedRectangle(cornerRadius: 12))
        .transition(.move(edge: .top).combined(with: .opacity))
    }

    // MARK: - Mascot Hero Section

    private var mascotHeroSection: some View {
        VStack(spacing: 8) {
            // Big animated mascot — the star of the show
            RiveMascotView(
                mood: mascotMood,
                size: 280
            )
            .frame(height: 250)

            // Mood text
            Text(mascotMoodText)
                .font(.system(size: 16, weight: .bold, design: .rounded))
                .foregroundStyle(mascotMoodColor)
                .multilineTextAlignment(.center)

            // Progress dots — 3 games to make mascot happy
            HStack(spacing: 8) {
                ForEach(0..<3, id: \.self) { i in
                    Circle()
                        .fill(i < todayExerciseCount ? AppColors.accent : AppColors.accent.opacity(0.2))
                        .frame(width: 10, height: 10)
                        .scaleEffect(i < todayExerciseCount ? 1.0 : 0.8)
                        .animation(.spring(response: 0.3, dampingFraction: 0.6), value: todayExerciseCount)
                }
            }
            .padding(.top, 2)
        }
        .padding(.vertical, 8)
        .frame(maxWidth: .infinity)
    }

    // MARK: - Brain Stat Pills

    private var brainStatPills: some View {
        Group {
            if let score = latestBrainScore {
                HStack(spacing: 12) {
                    // Brain Score pill
                    VStack(spacing: 4) {
                        Text("\(score.brainScore)")
                            .font(.system(size: 28, weight: .black, design: .rounded))
                            .foregroundStyle(AppColors.accent)
                            .contentTransition(.numericText(value: Double(score.brainScore)))
                        Text("Brain Score")
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundStyle(.secondary)

                        // Share button
                        if let shareImage = brainScoreShareImage {
                            ShareLink(item: Image(uiImage: shareImage), preview: SharePreview("Brain Score", image: Image(uiImage: shareImage))) {
                                Text("Share")
                                    .font(.system(size: 11, weight: .bold))
                                    .foregroundStyle(AppColors.accent)
                            }
                        }
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 16))
                    .overlay(
                        RoundedRectangle(cornerRadius: 16)
                            .stroke(AppColors.accent.opacity(0.15), lineWidth: 1)
                    )

                    // Brain Age pill
                    VStack(spacing: 4) {
                        Text("\(score.brainAge)")
                            .font(.system(size: 28, weight: .black, design: .rounded))
                            .foregroundStyle(score.brainAge <= (user?.userAge ?? 25) ? AppColors.teal : AppColors.coral)
                            .contentTransition(.numericText(value: Double(score.brainAge)))
                        Text("Brain Age")
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundStyle(.secondary)

                        // Retake button
                        Button {
                            if storeService.isProUser {
                                showingAssessment = true
                            } else {
                                showingPaywall = true
                            }
                        } label: {
                            HStack(spacing: 3) {
                                if !storeService.isProUser {
                                    Image(systemName: "lock.fill")
                                        .font(.system(size: 8))
                                }
                                Text("Retake")
                                    .font(.system(size: 11, weight: .bold))
                            }
                            .foregroundStyle(storeService.isProUser ? AppColors.accent : AppColors.amber)
                        }
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 16))
                    .overlay(
                        RoundedRectangle(cornerRadius: 16)
                            .stroke(AppColors.cardBorder, lineWidth: 1)
                    )
                }
            } else {
                // No brain score yet — CTA
                VStack(spacing: 16) {
                    Image("mascot-no-score")
                        .renderingMode(.original)
                        .resizable()
                        .scaledToFit()
                        .frame(height: 80)

                    VStack(spacing: 4) {
                        Text("Discover Your Brain Score")
                            .font(.headline)
                        Text("2-minute assessment")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }

                    Button {
                        showingAssessment = true
                    } label: {
                        Text("Start Assessment")
                            .accentButton()
                    }
                    .padding(.horizontal, 20)
                }
                .padding(.vertical, 20)
                .frame(maxWidth: .infinity)
                .appCard()
            }
        }
    }

    private func domainPill(label: String, score: Int, color: Color) -> some View {
        HStack(spacing: 4) {
            Circle()
                .fill(color)
                .frame(width: 6, height: 6)
            Text(label)
                .font(.system(size: 11, weight: .bold))
                .foregroundStyle(.secondary)
            Text("\(score)")
                .font(.system(size: 13, weight: .black, design: .rounded))
                .foregroundStyle(.primary)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
        .background(color.opacity(0.08), in: RoundedRectangle(cornerRadius: 8))
    }

    // MARK: - Streak Week Calendar Card

    private var streakGradient: AnyShapeStyle {
        let streak = viewModel.currentStreak
        if streak >= 30 {
            return AnyShapeStyle(LinearGradient(colors: [.blue, .white], startPoint: .bottom, endPoint: .top))
        } else if streak >= 14 {
            return AnyShapeStyle(LinearGradient(colors: [.red, .purple], startPoint: .bottom, endPoint: .top))
        } else if streak >= 7 {
            return AnyShapeStyle(LinearGradient(colors: [.orange, .red], startPoint: .bottom, endPoint: .top))
        } else {
            return AnyShapeStyle(.orange)
        }
    }

    private var streakWeekCard: some View {
        VStack(spacing: 12) {
            HStack {
                HStack(spacing: 8) {
                    Image(systemName: "flame.fill")
                        .symbolEffect(.variableColor.iterative, options: .repeating, value: streakAnimating)
                        .foregroundStyle(viewModel.currentStreak > 0 ? streakGradient : AnyShapeStyle(.secondary))
                    Text("\(viewModel.currentStreak) day streak")
                        .font(.headline.weight(.bold))
                        .contentTransition(.numericText())
                        .scaleEffect(streakBounce ? 1.15 : 1.0)
                        .animation(.spring(response: 0.35, dampingFraction: 0.5), value: streakBounce)
                }
                .onAppear {
                    streakAnimating = true
                    // Bounce if streak is active (user trained today)
                    if user?.isStreakActive == true {
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                            streakBounce = true
                            DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) {
                                streakBounce = false
                            }
                        }
                    }
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
