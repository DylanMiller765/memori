import Foundation

@MainActor
@Observable
final class PaywallTriggerService {
    var shouldShowPaywall = false
    var triggerContext: PaywallContext = .generic

    private let defaults = UserDefaults.standard
    private let paywallDismissCountKey = "paywall_dismiss_count"
    private let lastPaywallDateKey = "last_paywall_date"
    private let dailyExerciseCountKey = "daily_exercise_count"
    private let dailyExerciseDateKey = "daily_exercise_date"
    private let triedGameTypesKey = "tried_game_types"

    enum PaywallContext: String {
        case generic
        case afterAssessment
        case streakMilestone
        case dailyLimit
        case lockedCategory
        case progressAnalytics
        case brainScoreHistory
        case leaderboard
    }

    // MARK: - Try Each Game Once

    private var triedGameTypes: Set<String> {
        get { Set(defaults.stringArray(forKey: triedGameTypesKey) ?? []) }
        set { defaults.set(Array(newValue), forKey: triedGameTypesKey) }
    }

    func isFirstTimeGame(_ type: ExerciseType) -> Bool {
        !triedGameTypes.contains(type.rawValue)
    }

    // MARK: - Daily Exercise Limit (Free = 3/day)

    var exercisesToday: Int {
        guard let savedDate = defaults.object(forKey: dailyExerciseDateKey) as? Date,
              Calendar.current.isDateInToday(savedDate) else {
            return 0
        }
        return defaults.integer(forKey: dailyExerciseCountKey)
    }

    var freeExercisesRemaining: Int {
        max(0, Constants.Defaults.freeExercisesPerDay - exercisesToday)
    }

    var hasReachedDailyLimit: Bool {
        exercisesToday >= Constants.Defaults.freeExercisesPerDay
    }

    func recordExerciseCompleted(gameType: ExerciseType? = nil) {
        // First-time game types don't count toward the daily limit
        if let gameType, isFirstTimeGame(gameType) {
            var tried = triedGameTypes
            tried.insert(gameType.rawValue)
            triedGameTypes = tried
            return
        }

        let today = Date.now
        if let savedDate = defaults.object(forKey: dailyExerciseDateKey) as? Date,
           Calendar.current.isDateInToday(savedDate) {
            defaults.set(exercisesToday + 1, forKey: dailyExerciseCountKey)
        } else {
            defaults.set(today, forKey: dailyExerciseDateKey)
            defaults.set(1, forKey: dailyExerciseCountKey)
        }
    }

    // MARK: - Smart Trigger Logic

    /// Call when free user tries to start an exercise but has hit daily limit
    func triggerDailyLimit(isProUser: Bool) {
        guard !isProUser else { return }
        guard hasReachedDailyLimit else { return }
        Analytics.dailyLimitReached(exercisesToday: exercisesToday)
        triggerContext = .dailyLimit
        shouldShowPaywall = true
    }

    /// Call when user taps a locked category
    func triggerLockedCategory(isProUser: Bool) {
        guard !isProUser else { return }
        triggerContext = .lockedCategory
        shouldShowPaywall = true
    }

    /// Call after brain assessment results - highest conversion moment
    func triggerAfterAssessment(isProUser: Bool) {
        guard !isProUser else { return }
        guard canShowPaywall() else { return }
        triggerContext = .afterAssessment
        shouldShowPaywall = true
    }

    /// Call when user hits a streak milestone (3, 7, 14 days)
    func triggerStreakMilestone(streak: Int, isProUser: Bool) {
        guard !isProUser else { return }
        guard [3, 7, 14].contains(streak) else { return }
        guard canShowPaywall() else { return }
        triggerContext = .streakMilestone
        shouldShowPaywall = true
    }

    /// Call when user tries to access detailed analytics
    func triggerProgressAnalytics(isProUser: Bool) {
        guard !isProUser else { return }
        triggerContext = .progressAnalytics
        shouldShowPaywall = true
    }

    /// Call when user tries to see brain score history
    func triggerBrainScoreHistory(isProUser: Bool) {
        guard !isProUser else { return }
        triggerContext = .brainScoreHistory
        shouldShowPaywall = true
    }

    /// Call when free user tries to access leaderboards
    func triggerLeaderboard(isProUser: Bool) {
        guard !isProUser else { return }
        triggerContext = .leaderboard
        shouldShowPaywall = true
    }

    func dismiss() {
        shouldShowPaywall = false
        let count = defaults.integer(forKey: paywallDismissCountKey)
        defaults.set(count + 1, forKey: paywallDismissCountKey)
        defaults.set(Date.now, forKey: lastPaywallDateKey)
    }

    // MARK: - Rate Limiting

    /// Don't show paywall more than once per 12 hours or if dismissed 5+ times
    private func canShowPaywall() -> Bool {
        let dismissCount = defaults.integer(forKey: paywallDismissCountKey)
        if dismissCount >= 5 {
            if let lastDate = defaults.object(forKey: lastPaywallDateKey) as? Date {
                let hours = Date.now.timeIntervalSince(lastDate) / 3600
                return hours >= 72
            }
        }

        if let lastDate = defaults.object(forKey: lastPaywallDateKey) as? Date {
            let hours = Date.now.timeIntervalSince(lastDate) / 3600
            return hours >= 12
        }

        return true
    }
}
