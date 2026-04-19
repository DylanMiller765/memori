import SwiftUI
import SwiftData

extension Notification.Name {
    static let streakMilestoneCelebration = Notification.Name("streakMilestoneCelebration")
    static let brainScoreMilestoneCelebration = Notification.Name("brainScoreMilestoneCelebration")
    static let workoutGameCompleted = Notification.Name("workoutGameCompleted")
    static let brainScoreImproved = Notification.Name("brainScoreImproved")
}

struct ContentView: View {
    @Environment(\.modelContext) private var modelContext
    @Query private var users: [User]
    @Query private var sessions: [DailySession]
    @Query(sort: \BrainScoreResult.date, order: .reverse) private var brainScoreResults: [BrainScoreResult]
    @State private var showOnboarding = false
    @State private var selectedTab = 0
    @State private var storeService = StoreService()
    @State private var achievementService = AchievementService()
    @State private var paywallTrigger = PaywallTriggerService()
    @State private var trainingManager = TrainingSessionManager()
    @State private var gameCenterService = GameCenterService()
    @State private var deepLinkRouter = DeepLinkRouter()
    @State private var workoutEngine = WorkoutEngine()
    @State private var referralService = ReferralService()

    // Challenge accept flow
    @State private var showingChallengeAccept = false
    @State private var showReferralWelcome = false

    // Toast state
    @State private var showingXPToast = false
    @State private var lastXPGained = 0
    @State private var lastLevelUp = false
    @State private var lastNewLevel: Int?

    // Streak freeze toast state
    @State private var showingStreakFreezeToast = false
    @State private var freezeToastMessage = ""

    // Streak milestone celebration
    @State private var showingStreakCelebration = false
    @State private var celebrationStreak = 0

    // Brain Score milestone celebration
    @State private var showingBrainScoreMilestone = false
    @State private var milestoneBrainScore = 0

    // Score decay warning
    @State private var decayPointsLost: Int = 0

    private var user: User? { users.first }

    var body: some View {
        Group {
            if user?.hasCompletedOnboarding == true {
                mainTabView
            } else {
                OnboardingView {
                    withAnimation {
                        showOnboarding = false
                    }
                }
            }
        }
        .environment(storeService)
        .environment(achievementService)
        .environment(paywallTrigger)
        .environment(trainingManager)
        .environment(gameCenterService)
        .environment(deepLinkRouter)
        .environment(workoutEngine)
        .environment(referralService)
        .onOpenURL { url in
            deepLinkRouter.handle(url)
        }
        .onAppear {
            if users.isEmpty {
                let newUser = User()
                modelContext.insert(newUser)
            }
            // Identify user for PostHog analytics
            if let user {
                let latestBrainAge = brainScoreResults.first?.brainAge
                let totalGames = (try? modelContext.fetchCount(FetchDescriptor<Exercise>())) ?? 0
                Analytics.identify(
                    userId: user.id.uuidString,
                    isProUser: storeService.isProUser,
                    brainAge: latestBrainAge,
                    streak: user.currentStreak,
                    gamesPlayed: totalGames
                )
            }
            // Track app open
            if let user {
                let daysSince = user.lastSessionDate.map {
                    Calendar.current.dateComponents([.day], from: $0, to: Date()).day ?? 0
                } ?? -1
                Analytics.appOpened(
                    daysSinceLastOpen: daysSince,
                    currentStreak: user.currentStreak,
                    isProUser: storeService.isProUser
                )
            }
            gameCenterService.authenticate()
            scheduleStreakRiskIfNeeded()
            scheduleComebackIfNeeded()
            scheduleWeeklyReportIfNeeded()
            // Daily notifications
            if user?.notificationsEnabled == true {
                NotificationService.shared.scheduleDailyBrainFact()
                NotificationService.shared.scheduleSocialProof()
                NotificationService.shared.scheduleDecayPreview()
            }
            // Brain score decay — mascot ages if you don't train
            let decayed = BrainScoreDecayService.applyDecayIfNeeded(modelContext: modelContext)
            if decayed > 0 {
                decayPointsLost = decayed
                NotificationService.shared.scheduleDecayWarning(pointsLost: decayed)
                Analytics.brainScoreDecayed(pointsLost: decayed, newScore: brainScoreResults.first?.brainScore ?? 0)
            }
            // Sync widget data on app launch (off the main thread)
            Task { syncWidgetData() }
        }
    }

    private var mainTabView: some View {
        ZStack {
            TabView(selection: $selectedTab) {
                HomeView(selectedTab: $selectedTab, decayPointsLost: $decayPointsLost)
                    .tabItem {
                        Label("Home", systemImage: "brain.head.profile")
                    }
                    .tag(0)
                    .accessibilityLabel("Home tab")

                TrainingView()
                    .tabItem {
                        Label("Train", systemImage: "dumbbell.fill")
                    }
                    .tag(1)
                    .accessibilityLabel("Train tab")

                LeaderboardView()
                    .tabItem {
                        Label("Compete", systemImage: "trophy.fill")
                    }
                    .tag(2)
                    .accessibilityLabel("Compete tab")

                ProgressDashboardView()
                    .tabItem {
                        Label("Insights", systemImage: "chart.bar.xaxis.ascending")
                    }
                    .tag(3)
                    .accessibilityLabel("Insights tab")

                SettingsView()
                    .tabItem {
                        Label("Profile", systemImage: "person.circle.fill")
                    }
                    .tag(4)
                    .accessibilityLabel("Profile tab")
            }
            .tint(AppColors.accent)
            .symbolRenderingMode(.hierarchical)
            .onChange(of: selectedTab) { _, newTab in
                let tabNames = ["Home", "Train", "Compete", "Insights", "Profile"]
                if newTab >= 0 && newTab < tabNames.count {
                    Analytics.tabViewed(tab: tabNames[newTab])
                }
            }

            // Achievement toast overlay
            if let firstUnlocked = achievementService.newlyUnlocked.first {
                AchievementToast(achievementType: firstUnlocked) {
                    achievementService.dismissAchievement(firstUnlocked)
                }
                .transition(.move(edge: .top).combined(with: .opacity))
                .zIndex(100)
            }

            // XP toast overlay
            if showingXPToast {
                XPGainedToast(
                    amount: lastXPGained,
                    levelUp: lastLevelUp,
                    newLevel: lastNewLevel
                )
                .transition(.move(edge: .top).combined(with: .opacity))
                .zIndex(99)
                .onAppear {
                    DispatchQueue.main.asyncAfter(deadline: .now() + 3) {
                        withAnimation {
                            showingXPToast = false
                        }
                    }
                }
            }

            // Streak freeze toast overlay
            if showingStreakFreezeToast {
                StreakFreezeToast(message: freezeToastMessage)
                    .transition(.move(edge: .top).combined(with: .opacity))
                    .zIndex(98)
                    .onAppear {
                        DispatchQueue.main.asyncAfter(deadline: .now() + 4) {
                            withAnimation {
                                showingStreakFreezeToast = false
                            }
                        }
                    }
            }
        }
        .sheet(isPresented: $paywallTrigger.shouldShowPaywall) {
            PaywallView(triggerSource: paywallTrigger.triggerContext.rawValue)
        }
        .fullScreenCover(isPresented: $showingStreakCelebration) {
            StreakCelebrationView(streak: celebrationStreak) {
                showingStreakCelebration = false
            }
        }
        .fullScreenCover(isPresented: $showingBrainScoreMilestone) {
            BrainScoreMilestoneView(milestone: milestoneBrainScore) {
                showingBrainScoreMilestone = false
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: .streakMilestoneCelebration)) { notification in
            if let streak = notification.userInfo?["streak"] as? Int {
                celebrationStreak = streak
                withAnimation { showingStreakCelebration = true }
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: .brainScoreMilestoneCelebration)) { notification in
            if let milestone = notification.userInfo?["milestone"] as? Int {
                milestoneBrainScore = milestone
                // Delay slightly if streak celebration is showing
                let delay: Double = showingStreakCelebration ? 2.0 : 0.0
                DispatchQueue.main.asyncAfter(deadline: .now() + delay) {
                    withAnimation { showingBrainScoreMilestone = true }
                }
            }
        }
        .onChange(of: deepLinkRouter.pendingDestination) { _, destination in
            guard let destination else { return }
            switch destination {
            case .home:
                selectedTab = 0
                deepLinkRouter.pendingDestination = nil
            case .train, .dailyChallenge:
                selectedTab = 1
                deepLinkRouter.pendingDestination = nil
            case .game(_):
                selectedTab = 1
                // Leave pendingDestination so TrainingView can handle it
            case .challenge:
                selectedTab = 1
                showingChallengeAccept = true
                deepLinkRouter.pendingDestination = nil
            case .compete:
                selectedTab = 2
                deepLinkRouter.pendingDestination = nil
            case .insights:
                selectedTab = 3
                deepLinkRouter.pendingDestination = nil
            case .profile:
                selectedTab = 4
                deepLinkRouter.pendingDestination = nil
            case .referral(let code):
                // Don't process self-referrals
                if let myCode = referralService.getReferralCode(modelContext: modelContext),
                   code == myCode {
                    deepLinkRouter.pendingDestination = nil
                    break
                }
                // Record referrer and grant trial to new user
                if !referralService.wasReferred {
                    referralService.recordReferrer(code: code)
                    referralService.grantReferralTrial()
                    showReferralWelcome = true
                    // Notify referrer via CloudKit so they get their trial too
                    referralService.notifyReferrer(referrerCode: code)
                    // Refresh Pro status
                    Task { await storeService.updateSubscriptionStatus() }
                    Analytics.trackReferralRedeemed()
                    Analytics.trackReferralTrialStarted()
                }
                deepLinkRouter.pendingDestination = nil
            }
        }
        .fullScreenCover(isPresented: $showingChallengeAccept) {
            if let challenge = deepLinkRouter.pendingChallenge {
                ChallengeAcceptView(
                    challenge: challenge,
                    onAccept: {
                        showingChallengeAccept = false
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                            deepLinkRouter.pendingDestination = .game(challenge.game)
                        }
                    },
                    onDismiss: {
                        showingChallengeAccept = false
                        deepLinkRouter.pendingChallenge = nil
                    }
                )
            }
        }
        .alert("Welcome to Memori!", isPresented: $showReferralWelcome) {
            Button("Let's go!") {}
        } message: {
            Text("Your friend referred you! Enjoy 1 week of Memori Pro — all games unlocked.")
        }
        .task {
            // Check for pending referral rewards from CloudKit (only after onboarding)
            guard user?.hasCompletedOnboarding == true else { return }
            if let myCode = referralService.getReferralCode(modelContext: modelContext) {
                referralService.checkForPendingRewards(myCode: myCode)
            }
            // Register short referral code in CloudKit (not yet implemented)
            // Task { _ = await referralService.getOrCreateShortCode(modelContext: modelContext) }
        }
    }

    private func scheduleStreakRiskIfNeeded() {
        guard let user, user.notificationsEnabled, user.currentStreak > 0 else { return }
        let trainedToday = user.lastSessionDate.map { Calendar.current.isDateInToday($0) } ?? false
        if !trainedToday {
            NotificationService.shared.scheduleStreakRisk(streak: user.currentStreak)
        }
    }

    private func scheduleComebackIfNeeded() {
        guard let user, user.notificationsEnabled else { return }
        guard let lastSession = user.lastSessionDate else { return }
        let daysAgo = Calendar.current.dateComponents([.day], from: lastSession, to: .now).day ?? 0
        if daysAgo >= 2 {
            NotificationService.shared.scheduleComebackNotification(lastTrainedDaysAgo: daysAgo)
        }
    }

    private func syncWidgetData() {
        guard let user else { return }
        let trainedToday = user.lastSessionDate.map { Calendar.current.isDateInToday($0) } ?? false
        let todaySession = sessions.first { Calendar.current.isDateInToday($0.date) }
        let exercisesToday = todaySession?.exercisesCompleted.count ?? 0

        let latestBrainScore = brainScoreResults.first?.brainScore ?? 0

        WidgetDataService.updateWidgetData(
            streak: user.currentStreak,
            level: user.level,
            levelName: user.levelName,
            xp: user.totalXP,
            xpForNextLevel: user.xpForNextLevel,
            exercisesToday: exercisesToday,
            dailyGoal: user.dailyGoal,
            brainScore: latestBrainScore,
            trainedToday: trainedToday
        )
    }

    private func scheduleWeeklyReportIfNeeded() {
        guard let user, user.notificationsEnabled else { return }

        let currentScore = brainScoreResults.first?.brainScore ?? 0

        // Find a brain score from 7+ days ago for comparison
        let weekAgo = Calendar.current.date(byAdding: .day, value: -7, to: .now) ?? .now
        let previousScore = brainScoreResults.first(where: { $0.date <= weekAgo })?.brainScore ?? currentScore

        NotificationService.shared.scheduleWeeklyReport(
            brainScore: currentScore,
            previousBrainScore: previousScore
        )
    }
}

// MARK: - XP Helper

extension ContentView {
    static func awardXP(user: User, score: Double, difficulty: Int, achievementService: AchievementService, modelContext: ModelContext, gameCenterService: GameCenterService? = nil, exerciseType: ExerciseType? = nil, gameScore: Int? = nil) -> (xp: Int, leveledUp: Bool) {
        let xp = user.xpForExercise(score: score, difficulty: difficulty)
        let leveledUp = user.addXP(xp)
        user.totalExercises += 1
        if score >= 0.95 { user.totalPerfectScores += 1 }

        // Cancel decay warning since user is playing
        NotificationService.shared.cancelDecayWarning()

        achievementService.checkAchievements(context: modelContext, user: user)

        if leveledUp {
            NotificationService.shared.scheduleLevelUpNotification(
                level: user.level,
                levelName: user.levelName
            )
        }

        // Update widget data centrally after every exercise completion
        let exercisesToday: Int = {
            let startOfDay = Calendar.current.startOfDay(for: Date())
            var descriptor = FetchDescriptor<DailySession>(predicate: #Predicate { $0.date >= startOfDay })
            descriptor.fetchLimit = 1
            let todaySession = (try? modelContext.fetch(descriptor))?.first
            return todaySession?.exercisesCompleted.count ?? 0
        }()

        let latestBrainScore: Int = {
            var descriptor = FetchDescriptor<BrainScoreResult>(sortBy: [SortDescriptor(\.date, order: .reverse)])
            descriptor.fetchLimit = 1
            return (try? modelContext.fetch(descriptor))?.first?.brainScore ?? 0
        }()

        // Rolling Brain Score: update domain if game improved it
        if let exerciseType, let rawScore = gameScore,
           let (domain, newDomainScore) = BrainScoring.domainScore(for: exerciseType, gameScore: rawScore, score: score) {

            var bsDescriptor = FetchDescriptor<BrainScoreResult>(sortBy: [SortDescriptor(\.date, order: .reverse)])
            bsDescriptor.fetchLimit = 1
            let latestResult = (try? modelContext.fetch(bsDescriptor))?.first

            let currentMemory = latestResult?.digitSpanScore ?? 0
            let currentSpeed = latestResult?.reactionTimeScore ?? 0
            let currentVisual = latestResult?.visualMemoryScore ?? 0

            var updatedMemory = currentMemory
            var updatedSpeed = currentSpeed
            var updatedVisual = currentVisual

            var improved = false
            switch domain {
            case "memory":
                if newDomainScore > currentMemory {
                    updatedMemory = newDomainScore
                    improved = true
                }
            case "speed":
                if newDomainScore > currentSpeed {
                    updatedSpeed = newDomainScore
                    improved = true
                }
            case "visual":
                if newDomainScore > currentVisual {
                    updatedVisual = newDomainScore
                    improved = true
                }
            default: break
            }

            if improved, latestResult != nil {
                let newBrainScore = BrainScoring.compositeBrainScore(
                    digit: updatedMemory,
                    reaction: updatedSpeed,
                    visual: updatedVisual
                )
                let newAge = BrainScoring.brainAge(from: newBrainScore)

                let result = BrainScoreResult()
                result.date = Date()
                result.brainScore = newBrainScore
                result.brainAge = newAge
                result.digitSpanScore = updatedMemory
                result.reactionTimeScore = updatedSpeed
                result.visualMemoryScore = updatedVisual
                result.digitSpanMax = latestResult?.digitSpanMax ?? 0
                result.reactionTimeAvgMs = latestResult?.reactionTimeAvgMs ?? 0
                result.visualMemoryMax = latestResult?.visualMemoryMax ?? 0
                result.percentile = BrainScoring.percentile(score: newBrainScore)
                result.brainType = BrainScoring.determineBrainType(
                    digit: updatedMemory,
                    reaction: updatedSpeed,
                    visual: updatedVisual
                )
                result.source = .workout

                if domain == "memory", exerciseType == .sequentialMemory {
                    result.digitSpanMax = rawScore
                } else if domain == "speed", exerciseType == .reactionTime {
                    result.reactionTimeAvgMs = rawScore
                } else if domain == "visual", exerciseType == .visualMemory {
                    result.visualMemoryMax = rawScore
                }

                modelContext.insert(result)
                try? modelContext.save()

                let delta = newBrainScore - (latestResult?.brainScore ?? 0)
                if delta > 0 {
                    NotificationCenter.default.post(
                        name: .brainScoreImproved,
                        object: nil,
                        userInfo: ["delta": delta, "newScore": newBrainScore]
                    )
                    NotificationService.shared.scheduleBrainScoreFollowUp(currentScore: newBrainScore)
                    // Report improved brain score to Game Center leaderboard
                    gameCenterService?.reportScore(newBrainScore, leaderboardID: GameCenterService.brainScoreLeaderboard)
                }
            }
        }

        WidgetDataService.updateWidgetData(
            streak: user.currentStreak,
            level: user.level,
            levelName: user.levelName,
            xp: user.totalXP,
            xpForNextLevel: user.xpForNextLevel,
            exercisesToday: exercisesToday,
            dailyGoal: user.dailyGoal,
            brainScore: latestBrainScore,
            trainedToday: true
        )

        // Report to Game Center (reportScore handles auth guard internally)
        if let gc = gameCenterService {
            // Prompt sign-in after first exercise if not authenticated
            if !gc.isAuthenticated, user.totalExercises == 1 {
                gc.authenticate()
            }

            // Always attempt to report — reportScore checks isAuthenticated internally
            gc.reportScore(user.longestStreak, leaderboardID: GameCenterService.longestStreakLeaderboard)
            gc.reportScore(user.totalXP, leaderboardID: GameCenterService.xpLeaderboard)

            // Report individual exercise score to its leaderboard
            if let type = exerciseType, let rawScore = gameScore, rawScore > 0 {
                let leaderboardID: String? = switch type {
                case .reactionTime: GameCenterService.reactionTimeLeaderboard
                case .colorMatch: GameCenterService.colorMatchLeaderboard
                case .speedMatch: GameCenterService.speedMatchLeaderboard
                case .visualMemory: GameCenterService.visualMemoryLeaderboard
                case .sequentialMemory: GameCenterService.numberMemoryLeaderboard
                case .mathSpeed: GameCenterService.mathSpeedLeaderboard
                case .dualNBack: GameCenterService.dualNBackLeaderboard
                case .wordScramble: GameCenterService.wordScrambleLeaderboard
                case .memoryChain: GameCenterService.memoryChainLeaderboard
                case .chimpTest: GameCenterService.chimpTestLeaderboard
                case .verbalMemory: GameCenterService.verbalMemoryLeaderboard
                default: nil
                }
                if let leaderboardID {
                    gc.reportScore(rawScore, leaderboardID: leaderboardID)
                }
            }

            // Sync any newly unlocked achievements
            for achievementType in achievementService.newlyUnlocked {
                gc.reportAchievement(for: achievementType)
            }
        }

        // Track exercise completion
        if let exerciseType {
            Analytics.exerciseCompleted(game: exerciseType.rawValue, score: score, difficulty: difficulty)
        }

        // Record workout game completion if applicable
        if let exerciseType {
            // Post notification so HomeView can check workout completion
            NotificationCenter.default.post(
                name: .workoutGameCompleted,
                object: nil,
                userInfo: ["exerciseType": exerciseType.rawValue, "score": score]
            )
        }

        // Prompt for App Store review at natural moment
        ReviewPromptService.requestIfAppropriate(totalExercises: user.totalExercises, streak: user.currentStreak)

        // Streak milestone celebration
        let milestonesForCelebration = [7, 14, 30, 60, 100]
        if milestonesForCelebration.contains(user.currentStreak) {
            let lastCelebrated = UserDefaults.standard.integer(forKey: "lastCelebratedStreak")
            if lastCelebrated < user.currentStreak {
                UserDefaults.standard.set(user.currentStreak, forKey: "lastCelebratedStreak")
                Analytics.streakMilestone(streak: user.currentStreak)
                NotificationCenter.default.post(
                    name: .streakMilestoneCelebration,
                    object: nil,
                    userInfo: ["streak": user.currentStreak]
                )
            }
        }

        // Brain Score milestone celebration
        let brainScoreMilestones = [500, 600, 700, 800, 900, 1000]
        let latestBrainScoreValue = latestBrainScore
        let highestCelebrated = UserDefaults.standard.integer(forKey: "highestBrainScoreMilestone")
        for milestone in brainScoreMilestones.sorted(by: >) {
            if latestBrainScoreValue >= milestone && highestCelebrated < milestone {
                UserDefaults.standard.set(milestone, forKey: "highestBrainScoreMilestone")
                NotificationCenter.default.post(
                    name: .brainScoreMilestoneCelebration,
                    object: nil,
                    userInfo: ["milestone": milestone]
                )
                break  // Only celebrate highest new milestone
            }
        }

        return (xp, leveledUp)
    }
}

// MARK: - Training View

struct TrainingView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(StoreService.self) private var storeService
    @Environment(PaywallTriggerService.self) private var paywallTrigger
    @Environment(DeepLinkRouter.self) private var deepLinkRouter
    @Query private var users: [User]
    @Query(sort: \Exercise.completedAt, order: .reverse) private var allExercises: [Exercise]
    private var exercises: [Exercise] { Array(allExercises.prefix(20)) }

    @State private var showingPaywall = false
    @State private var selectedExercise: ExerciseType?
    @State private var navigateToDailyChallenge = false
    @AppStorage("daily_challenge_completed_date") private var dailyChallengeCompletedDate: String = ""
    @AppStorage("has_seen_free_play_popup") private var hasSeenFreePlayPopup = false
    @State private var showFreePlayPopup = false

    private static let dayFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd"
        return f
    }()

    private var hasDoneDailyChallenge: Bool {
        dailyChallengeCompletedDate == Self.dayFormatter.string(from: Date.now)
    }

    private var user: User? { users.first }
    private var isProUser: Bool { storeService.isProUser }

    private func lastPlayedText(for type: ExerciseType) -> String? {
        guard let lastExercise = exercises.first(where: { $0.type == type }) else { return nil }
        let days = Calendar.current.dateComponents([.day], from: lastExercise.completedAt, to: .now).day ?? 0
        if days == 0 { return "Today" }
        if days == 1 { return "Yesterday" }
        if days < 7 { return "\(days)d ago" }
        return "\(days / 7)w ago"
    }

    private struct GameCategory {
        let name: String
        let icon: String
        let color: Color
        let subtitle: String
        let games: [(type: ExerciseType, title: String, icon: String, color: Color)]
    }

    private static let gameCategories: [GameCategory] = [
        GameCategory(
            name: "Memory",
            icon: "brain.head.profile",
            color: AppColors.violet,
            subtitle: "Train your recall",
            games: [
                (.sequentialMemory, "Number Memory", "number.circle.fill", AppColors.teal),
                (.visualMemory, "Visual Memory", "square.grid.3x3.fill", AppColors.indigo),
                (.chunkingTraining, "Chunking", "rectangle.split.3x1.fill", AppColors.rose),
                (.verbalMemory, "Verbal Memory", "text.book.closed.fill", AppColors.violet),
            ]
        ),
        GameCategory(
            name: "Speed",
            icon: "bolt.fill",
            color: AppColors.coral,
            subtitle: "Sharpen your reflexes",
            games: [
                (.reactionTime, "Reaction Time", "bolt.fill", AppColors.coral),
                (.mathSpeed, "Math Speed", "multiply.circle.fill", AppColors.amber),
                (.speedMatch, "Speed Match", "bolt.square.fill", AppColors.sky),
                (.colorMatch, "Color Match", "paintpalette.fill", AppColors.violet),
            ]
        ),
        GameCategory(
            name: "Focus",
            icon: "eye.fill",
            color: AppColors.sky,
            subtitle: "Build concentration",
            games: [
                (.dualNBack, "Dual N-Back", "square.grid.3x3", AppColors.sky),
                (.chimpTest, "Chimp Test", "pawprint.fill", AppColors.amber),
            ]
        ),
    ]

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    // Daily limit pill for free users
                    if !isProUser {
                        dailyLimitBanner
                    }

                    // Daily Challenge — always accessible, once per day
                    Button {
                        if !hasDoneDailyChallenge {
                            navigateToDailyChallenge = true
                        }
                    } label: {
                        HStack(alignment: .center, spacing: 16) {
                            VStack(alignment: .leading, spacing: 6) {
                                Text("DAILY CHALLENGE")
                                    .font(.system(size: 10, weight: .bold))
                                    .foregroundStyle(.white.opacity(0.7))
                                    .tracking(1.5)
                                Text(hasDoneDailyChallenge ? "Completed!" : "Today's Challenge")
                                    .font(.title3.weight(.bold))
                                    .foregroundStyle(.white)
                                Text(hasDoneDailyChallenge ? "Come back tomorrow" : "Compete for the daily high score")
                                    .font(.caption)
                                    .foregroundStyle(.white.opacity(0.75))
                            }

                            Spacer()

                            Image(systemName: hasDoneDailyChallenge ? "checkmark.circle.fill" : "star.fill")
                                .font(.title3.weight(.semibold))
                                .foregroundStyle(.white)
                                .frame(width: 44, height: 44)
                                .background(.white.opacity(0.2), in: Circle())
                        }
                        .padding(16)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(
                            LinearGradient(
                                colors: hasDoneDailyChallenge ? [AppColors.teal, AppColors.teal.opacity(0.8)] : [AppColors.amber, AppColors.coral],
                                startPoint: .leading,
                                endPoint: .trailing
                            ),
                            in: RoundedRectangle(cornerRadius: 12)
                        )
                    }
                    .buttonStyle(.plain)
                    .padding(.horizontal)

                    // Referral banner — always show so users can keep inviting
                    ReferralBannerView()
                        .padding(.horizontal)

                    // Game Categories
                    ForEach(Array(Self.gameCategories.enumerated()), id: \.offset) { index, category in
                        VStack(alignment: .leading, spacing: 10) {
                            // Section header
                            HStack(spacing: 8) {
                                Image(systemName: category.icon)
                                    .font(.system(size: 14, weight: .bold))
                                    .foregroundStyle(.white)
                                    .frame(width: 28, height: 28)
                                    .background(category.color, in: RoundedRectangle(cornerRadius: 8))

                                VStack(alignment: .leading, spacing: 1) {
                                    Text(category.name)
                                        .font(.system(size: 18, weight: .heavy, design: .rounded))
                                        .foregroundStyle(AppColors.textPrimary)
                                    Text(category.subtitle)
                                        .font(.system(size: 12, weight: .medium, design: .rounded))
                                        .foregroundStyle(AppColors.textSecondary)
                                }
                            }
                            .padding(.horizontal, 16)

                            // Horizontal scroll of game cards
                            ScrollView(.horizontal, showsIndicators: false) {
                                HStack(spacing: 12) {
                                    ForEach(Array(category.games.enumerated()), id: \.element.type) { offset, game in
                                        Button {
                                            if hasReachedLimit && !paywallTrigger.isFirstTimeGame(game.type) {
                                                showingPaywall = true
                                            } else {
                                                selectedExercise = game.type
                                            }
                                        } label: {
                                            GameCard(
                                                title: game.title,
                                                type: game.type,
                                                color: game.color,
                                                isLocked: hasReachedLimit && !paywallTrigger.isFirstTimeGame(game.type),
                                                lastPlayedText: lastPlayedText(for: game.type)
                                            )
                                        }
                                        .buttonStyle(GameCardButtonStyle())
                                    }
                                }
                                .padding(.horizontal, 16)
                            }
                        }
                        .staggeredEntrance(index: index)
                    }
                }
                .navigationDestination(item: $selectedExercise) { type in
                    exerciseDestination(for: type)
                }
                .navigationDestination(isPresented: $navigateToDailyChallenge) {
                    DailyChallengeView()
                }
                .padding(.top, 8)
                .padding(.bottom, 32)
                .responsiveContent()
                .frame(maxWidth: .infinity)
            }
            .pageBackground()
            .navigationTitle("Train")
            .sheet(isPresented: $showingPaywall) {
                PaywallView(
                    isHighIntent: true,
                    currentStreak: user?.currentStreak ?? 0,
                    gamesPlayedToday: paywallTrigger.exercisesToday
                )
            }
            .sheet(isPresented: $showFreePlayPopup) {
                FreePlayPopup {
                    showFreePlayPopup = false
                }
                .presentationDetents([.medium])
                .presentationDragIndicator(.visible)
                .presentationBackground(.clear)
            }
            .onAppear {
                if !isProUser && !hasSeenFreePlayPopup {
                    hasSeenFreePlayPopup = true
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                        showFreePlayPopup = true
                    }
                }
            }
            .onChange(of: deepLinkRouter.pendingDestination) { _, destination in
                if case .game(let type) = destination {
                    selectedExercise = type
                    deepLinkRouter.pendingDestination = nil
                }
            }
        }
    }

    private var hasReachedLimit: Bool {
        !isProUser && paywallTrigger.hasReachedDailyLimit
    }

    private var dailyLimitBanner: some View {
        let remaining = paywallTrigger.freeExercisesRemaining
        let total = Constants.Defaults.freeExercisesPerDay

        return HStack(spacing: 12) {
            // Dot indicators — filled = remaining, unfilled = used
            HStack(spacing: 6) {
                ForEach(0..<total, id: \.self) { i in
                    Circle()
                        .fill(i < remaining ? AppColors.accent : AppColors.accent.opacity(0.2))
                        .frame(width: 10, height: 10)
                }
            }

            VStack(alignment: .leading, spacing: 1) {
                if remaining == 0 {
                    Text("Daily limit reached")
                        .font(.caption.weight(.semibold))
                } else {
                    Text("\(remaining) free game\(remaining == 1 ? "" : "s") left today")
                        .font(.caption.weight(.semibold))
                }
                Text("Go Pro for unlimited")
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
                .fill(remaining == 0 ? AppColors.coral.opacity(0.08) : AppColors.accent.opacity(0.06))
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(remaining == 0 ? AppColors.coral.opacity(0.2) : AppColors.accent.opacity(0.15), lineWidth: 1)
                )
        )
        .padding(.horizontal)

    }

    @ViewBuilder
    private func exerciseDestination(for type: ExerciseType) -> some View {
        switch type {
        case .spacedRepetition:
            SpacedRepetitionView(category: .numbers)
        case .dualNBack:
            DualNBackView()
        case .activeRecall:
            ActiveRecallView()
        case .chunkingTraining:
            ChunkingTrainingView()
        case .prospectiveMemory:
            ProspectiveMemoryView()
        case .memoryPalace:
            MemoryPalaceView()
        case .reactionTime:
            ReactionTimeView()
        case .sequentialMemory:
            SequentialMemoryView()
        case .mathSpeed:
            MathSpeedView()
        case .colorMatch:
            ColorMatchView()
        case .speedMatch:
            SpeedMatchView()
        case .visualMemory:
            VisualMemoryView()
        case .wordScramble:
            WordScrambleView()
        case .memoryChain:
            MemoryChainView()
        case .chimpTest:
            ChimpTestView()
        case .verbalMemory:
            VerbalMemoryView()
        }
    }

}

// MARK: - Training Tile (Game-style grid card)

struct LockPulse: View {
    let color: Color
    @State private var pulse = false

    var body: some View {
        Image(systemName: "lock.fill")
            .font(.system(size: 18, weight: .semibold))
            .foregroundStyle(color.opacity(0.7))
            .padding(8)
            .background(color.opacity(pulse ? 0.22 : 0.12), in: Circle())
            .scaleEffect(pulse ? 1.08 : 1.0)
            .animation(.easeInOut(duration: 1.8).repeatForever(autoreverses: true), value: pulse)
            .onAppear { pulse = true }
    }
}

struct TrainingTile: View {
    let title: String
    let type: ExerciseType
    let color: Color
    let isLocked: Bool
    var lastPlayedText: String? = nil

    var body: some View {
        VStack(spacing: 0) {
            // Mini game preview
            miniPreview
                .frame(maxWidth: .infinity)
                .frame(height: 72)
                .clipped()

            // Title bar + last played
            VStack(spacing: 2) {
                Text(title)
                    .font(.system(size: 12, weight: .bold))
                    .foregroundStyle(isLocked ? color.opacity(0.5) : .primary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)

                if !isLocked {
                    if let lastPlayed = lastPlayedText {
                        Text(lastPlayed)
                            .font(.system(size: 9, weight: .medium))
                            .foregroundStyle(AppColors.textTertiary)
                    } else {
                        Text("New")
                            .font(.system(size: 9, weight: .semibold))
                            .foregroundStyle(AppColors.accent.opacity(0.7))
                    }
                }
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 10)
            .frame(maxWidth: .infinity)
        }
        .background {
            RoundedRectangle(cornerRadius: 14)
                .fill(AppColors.cardSurface)
        }
        .overlay(
            RoundedRectangle(cornerRadius: 14)
                .stroke(color.opacity(0.2), lineWidth: 1)
        )
        .overlay {
            if isLocked {
                ZStack {
                    RoundedRectangle(cornerRadius: 14)
                        .fill(Color.black.opacity(0.55))
                    LockPulse(color: color)
                }
            }
        }
        .clipShape(RoundedRectangle(cornerRadius: 14))
        .accessibilityLabel("\(title)\(isLocked ? ", locked" : "")")
    }

    private var miniPreview: some View {
        TrainingTileMiniPreview(type: type, color: color)
    }
}

// MARK: - Shared Mini Preview (used by TrainingTile and GameCard)

struct TrainingTileMiniPreview: View {
    let type: ExerciseType
    let color: Color
    var scale: CGFloat = 1.0

    private var bgOpacity: Double { scale > 1.0 ? 0.0 : 1.0 }

    var body: some View {
        ZStack {
            previewContent
                .scaleEffect(scale)
        }
    }

    @ViewBuilder
    private var previewContent: some View {
        ZStack {
            switch type {
            case .reactionTime:
                // Lightning bolt target
                ZStack {
                    color.opacity(0.08 * bgOpacity)
                    Circle()
                        .stroke(color.opacity(0.3), lineWidth: 2)
                        .frame(width: 44, height: 44)
                    Circle()
                        .fill(color.opacity(0.15))
                        .frame(width: 32, height: 32)
                    Image(systemName: "bolt.fill")
                        .font(.system(size: 18, weight: .bold))
                        .foregroundStyle(color)
                }

            case .colorMatch:
                // Stroop color words
                ZStack {
                    color.opacity(0.06 * bgOpacity)
                    VStack(spacing: 3) {
                        Text("RED")
                            .font(.system(size: 11, weight: .black, design: .rounded))
                            .foregroundStyle(AppColors.sky)
                        Text("BLUE")
                            .font(.system(size: 15, weight: .black, design: .rounded))
                            .foregroundStyle(AppColors.coral)
                        Text("GREEN")
                            .font(.system(size: 11, weight: .black, design: .rounded))
                            .foregroundStyle(AppColors.amber)
                    }
                }

            case .speedMatch:
                // Two cards matching
                ZStack {
                    color.opacity(0.06 * bgOpacity)
                    HStack(spacing: 6) {
                        RoundedRectangle(cornerRadius: 6)
                            .fill(color.opacity(0.15))
                            .frame(width: 30, height: 36)
                            .overlay(
                                Image(systemName: "star.fill")
                                    .font(.system(size: 12))
                                    .foregroundStyle(color)
                            )
                        RoundedRectangle(cornerRadius: 6)
                            .fill(color.opacity(0.15))
                            .frame(width: 30, height: 36)
                            .overlay(
                                Image(systemName: "star.fill")
                                    .font(.system(size: 12))
                                    .foregroundStyle(color)
                            )
                    }
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 14))
                        .foregroundStyle(.green)
                        .offset(x: 22, y: -14)
                }

            case .visualMemory:
                // Mini grid with highlighted cells
                ZStack {
                    color.opacity(0.06 * bgOpacity)
                    LazyVGrid(columns: Array(repeating: GridItem(.fixed(14), spacing: 3), count: 4), spacing: 3) {
                        ForEach(0..<16, id: \.self) { i in
                            RoundedRectangle(cornerRadius: 2)
                                .fill([2, 5, 7, 10, 13].contains(i) ? color : color.opacity(0.12))
                                .frame(height: 14)
                        }
                    }
                }

            case .sequentialMemory:
                // Number sequence
                ZStack {
                    color.opacity(0.06 * bgOpacity)
                    HStack(spacing: 4) {
                        ForEach(["3", "8", "1", "5"], id: \.self) { digit in
                            Text(digit)
                                .font(.system(size: 16, weight: .bold, design: .monospaced))
                                .foregroundStyle(color)
                                .frame(width: 24, height: 28)
                                .background(color.opacity(0.12), in: RoundedRectangle(cornerRadius: 5))
                        }
                    }
                }

            case .mathSpeed:
                // Math equation
                ZStack {
                    color.opacity(0.06 * bgOpacity)
                    VStack(spacing: 4) {
                        Text("7 × 8")
                            .font(.system(size: 18, weight: .bold, design: .rounded))
                            .foregroundStyle(color)
                        HStack(spacing: 6) {
                            ForEach(["54", "56", "58"], id: \.self) { ans in
                                Text(ans)
                                    .font(.system(size: 10, weight: .bold, design: .rounded))
                                    .foregroundStyle(ans == "56" ? .white : color.opacity(0.6))
                                    .frame(width: 28, height: 20)
                                    .background(
                                        (ans == "56" ? color : color.opacity(0.12)),
                                        in: RoundedRectangle(cornerRadius: 4)
                                    )
                            }
                        }
                    }
                }

            case .dualNBack:
                // 3x3 grid with highlighted cell
                ZStack {
                    color.opacity(0.06 * bgOpacity)
                    LazyVGrid(columns: Array(repeating: GridItem(.fixed(18), spacing: 3), count: 3), spacing: 3) {
                        ForEach(0..<9, id: \.self) { i in
                            RoundedRectangle(cornerRadius: 3)
                                .fill(i == 4 ? color : color.opacity(0.12))
                                .frame(height: 18)
                        }
                    }
                    Text("2")
                        .font(.system(size: 9, weight: .black, design: .rounded))
                        .foregroundStyle(color)
                        .offset(x: 22, y: -22)
                        .padding(3)
                        .background(color.opacity(0.15), in: Circle())
                }

            case .chunkingTraining:
                // Grouped number chunks
                ZStack {
                    color.opacity(0.06 * bgOpacity)
                    HStack(spacing: 8) {
                        ForEach(["482", "917", "35"], id: \.self) { chunk in
                            Text(chunk)
                                .font(.system(size: 13, weight: .bold, design: .monospaced))
                                .foregroundStyle(color)
                                .padding(.horizontal, 6)
                                .padding(.vertical, 4)
                                .background(color.opacity(0.12), in: RoundedRectangle(cornerRadius: 5))
                        }
                    }
                }

            case .wordScramble:
                ZStack {
                    color.opacity(0.06 * bgOpacity)
                    HStack(spacing: 3) {
                        ForEach(["B", "R", "A", "I", "N"], id: \.self) { letter in
                            Text(letter)
                                .font(.system(size: 12, weight: .bold, design: .rounded))
                                .foregroundStyle(color)
                                .frame(width: 18, height: 22)
                                .background(color.opacity(0.12), in: RoundedRectangle(cornerRadius: 4))
                        }
                    }
                }

            case .memoryChain:
                // Mini 4x4 grid with shapes — one cell glowing to show sequence
                ZStack {
                    color.opacity(0.06 * bgOpacity)
                    let icons = ["circle.fill", "square.fill", "triangle.fill", "diamond.fill",
                                 "star.fill", "heart.fill", "pentagon.fill", "hexagon.fill",
                                 "circle.fill", "square.fill", "triangle.fill", "diamond.fill",
                                 "star.fill", "heart.fill", "pentagon.fill", "hexagon.fill"]
                    let glowing = [2, 5, 10] // cells that are "highlighted" in sequence
                    LazyVGrid(columns: Array(repeating: GridItem(.fixed(14), spacing: 3), count: 4), spacing: 3) {
                        ForEach(0..<16, id: \.self) { i in
                            Image(systemName: icons[i])
                                .font(.system(size: 7, weight: .bold))
                                .foregroundStyle(glowing.contains(i) ? .white : color.opacity(0.5))
                                .frame(width: 14, height: 14)
                                .background(
                                    RoundedRectangle(cornerRadius: 2)
                                        .fill(glowing.contains(i) ? color : color.opacity(0.1))
                                )
                        }
                    }
                }

            case .chimpTest:
                // Mini chimp test grid: numbered cells + hidden cells
                let s: CGFloat = 14
                let sp: CGFloat = 3
                let fs: CGFloat = 8
                ZStack {
                    VStack(spacing: sp) {
                        HStack(spacing: sp) {
                            Color.clear.frame(width: s, height: s)
                            Text("1").font(.system(size: fs, weight: .heavy, design: .rounded))
                                .foregroundStyle(.white).frame(width: s, height: s)
                                .background(color, in: RoundedRectangle(cornerRadius: 4))
                            Color.clear.frame(width: s, height: s)
                            RoundedRectangle(cornerRadius: 4).fill(color.opacity(0.35)).frame(width: s, height: s)
                        }
                        HStack(spacing: sp) {
                            RoundedRectangle(cornerRadius: 4).fill(color.opacity(0.35)).frame(width: s, height: s)
                            Color.clear.frame(width: s, height: s)
                            Text("2").font(.system(size: fs, weight: .heavy, design: .rounded))
                                .foregroundStyle(.white).frame(width: s, height: s)
                                .background(color, in: RoundedRectangle(cornerRadius: 4))
                            Color.clear.frame(width: s, height: s)
                        }
                        HStack(spacing: sp) {
                            Color.clear.frame(width: s, height: s)
                            RoundedRectangle(cornerRadius: 4).fill(color.opacity(0.35)).frame(width: s, height: s)
                            Color.clear.frame(width: s, height: s)
                            Text("3").font(.system(size: fs, weight: .heavy, design: .rounded))
                                .foregroundStyle(.white).frame(width: s, height: s)
                                .background(color, in: RoundedRectangle(cornerRadius: 4))
                        }
                        HStack(spacing: sp) {
                            Text("4").font(.system(size: fs, weight: .heavy, design: .rounded))
                                .foregroundStyle(.white).frame(width: s, height: s)
                                .background(color, in: RoundedRectangle(cornerRadius: 4))
                            Color.clear.frame(width: s, height: s)
                            RoundedRectangle(cornerRadius: 4).fill(color.opacity(0.35)).frame(width: s, height: s)
                            Color.clear.frame(width: s, height: s)
                        }
                    }
                }

            case .verbalMemory:
                ZStack {
                    color.opacity(0.06 * bgOpacity)
                    VStack(spacing: 2) {
                        Text("seen?")
                            .font(.system(size: 11, weight: .bold, design: .rounded))
                            .foregroundStyle(color)
                        Text("apple")
                            .font(.system(size: 13, weight: .semibold, design: .rounded))
                            .foregroundStyle(color.opacity(0.6))
                    }
                }

            default:
                ZStack {
                    color.opacity(0.08 * bgOpacity)
                    Image(systemName: "brain.fill")
                        .font(.system(size: 24))
                        .foregroundStyle(color)
                }
            }

        }
    }
}

// MARK: - Game Card (horizontal scroll card)

struct GameCardButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.95 : 1.0)
            .offset(y: configuration.isPressed ? 3 : 0)
            .animation(.spring(response: 0.3, dampingFraction: 0.7), value: configuration.isPressed)
    }
}

struct GameCard: View {
    let title: String
    let type: ExerciseType
    let color: Color
    let isLocked: Bool
    var lastPlayedText: String? = nil

    // Darker shade for 3D shadow effect (Duolingo signature)
    private var shadowColor: Color {
        color.opacity(0.5)
    }

    var body: some View {
        VStack(spacing: 0) {
            // Top: dark surface with colorful preview elements (matches old TrainingTile)
            TrainingTileMiniPreview(type: type, color: color)
                .frame(maxWidth: .infinity)
                .frame(height: 88)
                .clipped()

            // Bottom: title area
            VStack(spacing: 2) {
                Text(title)
                    .font(.system(size: 13, weight: .bold, design: .rounded))
                    .foregroundStyle(AppColors.textPrimary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)

                if let lastPlayed = lastPlayedText {
                    Text(lastPlayed)
                        .font(.system(size: 10, weight: .medium, design: .rounded))
                        .foregroundStyle(AppColors.textSecondary)
                } else {
                    Text("NEW")
                        .font(.system(size: 9, weight: .heavy, design: .rounded))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(Color(red: 0.35, green: 0.80, blue: 0.01), in: Capsule())
                }
            }
            .padding(.vertical, 10)
            .frame(width: 130)
        }
        .background {
            // 3D raised card effect
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(AppColors.cardSurface)
                .shadow(color: shadowColor, radius: 0, x: 0, y: 4)
        }
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(color.opacity(0.2), lineWidth: 1)
        )
        .overlay {
            if isLocked {
                ZStack {
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .fill(Color.black.opacity(0.5))
                    LockPulse(color: color)
                }
            }
        }
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
    }
}

// MARK: - Exercise Info Sheet

struct ExerciseInfoSheet: View {
    let type: ExerciseType
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            VStack(alignment: .leading, spacing: 20) {
                Text(title)
                    .font(.title2.bold())

                VStack(alignment: .leading, spacing: 12) {
                    ForEach(benefits, id: \.self) { benefit in
                        HStack(alignment: .top, spacing: 12) {
                            Image(systemName: "brain.fill")
                                .foregroundStyle(color)
                                .frame(width: 24)
                            Text(benefit)
                                .font(.body)
                        }
                    }
                }

                Spacer()
            }
            .padding(24)
            .navigationTitle("What This Trains")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button { dismiss() } label: {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundStyle(.secondary)
                    }
                }
            }
        }
    }

    private var title: String {
        type.displayName
    }

    private var color: Color {
        switch type {
        case .reactionTime: return AppColors.coral
        case .colorMatch: return AppColors.violet
        case .speedMatch: return AppColors.sky
        case .visualMemory: return AppColors.indigo
        case .sequentialMemory: return AppColors.teal
        case .mathSpeed: return AppColors.amber
        case .dualNBack: return AppColors.sky
        case .chunkingTraining: return AppColors.rose
        case .chimpTest: return AppColors.amber
        case .verbalMemory: return AppColors.violet
        default: return AppColors.accent
        }
    }

    private var benefits: [String] {
        switch type {
        case .reactionTime:
            return [
                "Processing speed — how fast your brain responds to stimuli",
                "Visual reflexes and motor response time",
                "Alertness and sustained attention"
            ]
        case .colorMatch:
            return [
                "Cognitive flexibility — the Stroop effect tests your ability to override automatic responses",
                "Selective attention and impulse control",
                "Processing speed under conflicting information"
            ]
        case .speedMatch:
            return [
                "Processing speed and rapid visual comparison",
                "Short-term visual memory for symbol patterns",
                "Decision-making speed under time pressure"
            ]
        case .visualMemory:
            return [
                "Visuospatial working memory — remembering patterns in space",
                "Spatial recall and mental imagery",
                "Attention to detail and pattern recognition"
            ]
        case .sequentialMemory:
            return [
                "Digit span — a core measure of working memory capacity",
                "Sequential processing and number recall",
                "Concentration and mental rehearsal"
            ]
        case .mathSpeed:
            return [
                "Mental arithmetic and numerical fluency",
                "Processing speed with mathematical operations",
                "Working memory for holding numbers while calculating"
            ]
        case .dualNBack:
            return [
                "Working memory — the gold standard training task backed by research",
                "Dual-task processing (tracking two things simultaneously)",
                "Fluid intelligence and cognitive control"
            ]
        case .chunkingTraining:
            return [
                "Memory chunking — grouping information into meaningful units",
                "Working memory capacity expansion",
                "Pattern recognition in number sequences"
            ]
        case .chimpTest:
            return [
                "Spatial working memory — remembering positions after brief exposure",
                "Based on research with chimpanzee Ayumu at Kyoto University",
                "Visual processing speed and positional recall"
            ]
        case .verbalMemory:
            return [
                "Verbal recognition memory — distinguishing new from familiar words",
                "Long-term encoding and retrieval",
                "Sustained attention over growing word pools"
            ]
        default:
            return ["General cognitive training"]
        }
    }
}
