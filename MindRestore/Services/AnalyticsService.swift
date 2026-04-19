import Foundation
import PostHog

enum Analytics {
    static let apiKey = "phc_mAu7DCNXJbqro9iG6KzYbxhTqa4s442BAmS3tCt7vPJu"
    static let host = "https://us.i.posthog.com"

    static func configure() {
        let config = PostHogConfig(apiKey: apiKey, host: host)
        config.captureApplicationLifecycleEvents = true
        #if DEBUG
        config.debug = true
        #endif
        PostHogSDK.shared.setup(config)
    }

    // MARK: - User Identification

    /// Identify the current user and set their properties for segmentation
    static func identify(userId: String, isProUser: Bool, brainAge: Int?, streak: Int, gamesPlayed: Int) {
        var properties: [String: Any] = [
            "is_pro_user": isProUser,
            "streak": streak,
            "games_played": gamesPlayed
        ]
        if let brainAge {
            properties["brain_age"] = brainAge
        }
        PostHogSDK.shared.identify(userId, userProperties: properties)
    }

    /// Update user properties without re-identifying (call after subscription changes, brain score updates, etc.)
    static func updateUserProperties(isProUser: Bool? = nil, brainAge: Int? = nil, streak: Int? = nil) {
        var properties: [String: Any] = [:]
        if let isProUser { properties["is_pro_user"] = isProUser }
        if let brainAge { properties["brain_age"] = brainAge }
        if let streak { properties["streak"] = streak }
        guard !properties.isEmpty else { return }
        PostHogSDK.shared.capture("$set", userProperties: properties)
    }

    // MARK: - Session Tracking

    static func appOpened(daysSinceLastOpen: Int, currentStreak: Int, isProUser: Bool) {
        PostHogSDK.shared.capture("app.opened", properties: [
            "days_since_last_open": daysSinceLastOpen,
            "current_streak": currentStreak,
            "is_pro_user": isProUser
        ])
    }

    static func appOpenedFromNotification(notificationType: String) {
        PostHogSDK.shared.capture("app.opened_from_notification", properties: [
            "notification_type": notificationType
        ])
    }

    // MARK: - Onboarding

    static func onboardingDroppedOff(lastStep: String, totalSteps: Int) {
        PostHogSDK.shared.capture("onboarding.dropped_off", properties: [
            "last_step": lastStep,
            "steps_completed": totalSteps
        ])
    }

    static func onboardingCompleted(goals: [String]) {
        PostHogSDK.shared.capture("onboarding.completed", properties: [
            "goalCount": goals.count,
            "goals": goals.joined(separator: ",")
        ])
    }

    static func onboardingStep(step: String) {
        PostHogSDK.shared.capture("onboarding.step", properties: [
            "step": step
        ])
    }

    // MARK: - Navigation

    static func tabViewed(tab: String) {
        PostHogSDK.shared.capture("tab.viewed", properties: [
            "tab": tab
        ])
    }

    // MARK: - Exercises

    static func exerciseStarted(game: String) {
        PostHogSDK.shared.capture("exercise.started", properties: [
            "game": game
        ])
    }

    static func exerciseCompleted(game: String, score: Double, difficulty: Int) {
        PostHogSDK.shared.capture("exercise.completed", properties: [
            "game": game,
            "score": score,
            "difficulty": difficulty
        ])
    }

    static func personalBest(game: String, score: Int) {
        PostHogSDK.shared.capture("exercise.personalBest", properties: [
            "game": game,
            "score": score
        ])
    }

    static func exerciseAbandoned(game: String, roundReached: Int) {
        PostHogSDK.shared.capture("exercise.abandoned", properties: [
            "game": game,
            "round_reached": roundReached
        ])
    }

    // MARK: - Brain Score

    static func brainScoreCompleted(score: Int, brainAge: Int) {
        PostHogSDK.shared.capture("brainScore.completed", properties: [
            "score": score,
            "brainAge": brainAge
        ])
        // Also update the user property so we always have their latest brain age
        updateUserProperties(brainAge: brainAge)
    }

    static func brainScoreDecayed(pointsLost: Int, newScore: Int) {
        PostHogSDK.shared.capture("brainScore.decayed", properties: [
            "pointsLost": pointsLost,
            "newScore": newScore
        ])
    }

    // MARK: - Daily Limit

    static func dailyLimitReached(exercisesToday: Int) {
        PostHogSDK.shared.capture("dailyLimit.reached", properties: [
            "exercisesToday": exercisesToday
        ])
    }

    // MARK: - Paywall

    static func paywallShown(trigger: String = "unknown") {
        PostHogSDK.shared.capture("paywall.shown", properties: [
            "trigger": trigger
        ])
    }

    static func paywallConverted(plan: String, price: Double? = nil) {
        var properties: [String: Any] = ["plan": plan]
        if let price { properties["$revenue"] = price }
        PostHogSDK.shared.capture("paywall.converted", properties: properties)
        // Update pro status
        updateUserProperties(isProUser: true)
    }

    static func paywallDismissed(trigger: String = "unknown") {
        PostHogSDK.shared.capture("paywall.dismissed", properties: [
            "trigger": trigger
        ])
    }

    // MARK: - Sharing

    static func shareTapped(game: String) {
        PostHogSDK.shared.capture("share.tapped", properties: [
            "game": game
        ])
    }

    // MARK: - Engagement

    static func streakMilestone(streak: Int) {
        PostHogSDK.shared.capture("streak.milestone", properties: [
            "streak": streak
        ])
        updateUserProperties(streak: streak)
    }

    static func achievementUnlocked(achievement: String) {
        PostHogSDK.shared.capture("achievement.unlocked", properties: [
            "achievement": achievement
        ])
    }

    static func leaderboardViewed(category: String) {
        PostHogSDK.shared.capture("leaderboard.viewed", properties: [
            "category": category
        ])
    }

    // MARK: - Referrals

    static func trackReferralShared() {
        PostHogSDK.shared.capture("referral.shared")
    }

    static func trackReferralRedeemed() {
        PostHogSDK.shared.capture("referral.redeemed")
    }

    static func trackReferralTrialStarted() {
        PostHogSDK.shared.capture("referral.trial.started")
    }

    // MARK: - Focus Mode

    static func focusModeEnabled() {
        PostHogSDK.shared.capture("focus_mode_enabled")
    }

    static func focusModeDisabled() {
        PostHogSDK.shared.capture("focus_mode_disabled")
    }

    static func focusShieldShown(attemptCount: Int) {
        PostHogSDK.shared.capture("focus_shield_shown", properties: [
            "attempt_count": attemptCount
        ])
    }

    static func focusUnlockGameStarted(gameType: String) {
        PostHogSDK.shared.capture("focus_unlock_game_started", properties: [
            "game_type": gameType
        ])
    }

    static func focusUnlockGameCompleted(gameType: String, score: Int) {
        PostHogSDK.shared.capture("focus_unlock_game_completed", properties: [
            "game_type": gameType,
            "score": score
        ])
    }

    static func focusUnlockGranted(durationMinutes: Int) {
        PostHogSDK.shared.capture("focus_unlock_granted", properties: [
            "duration_minutes": durationMinutes
        ])
    }

    static func focusStayedFocused() {
        PostHogSDK.shared.capture("focus_stayed_focused")
    }

    static func focusSetupCompleted() {
        PostHogSDK.shared.capture("focus_setup_completed")
    }

    static func focusSetupSkipped() {
        PostHogSDK.shared.capture("focus_setup_skipped")
    }

    static func focusCooldownInitiated() {
        PostHogSDK.shared.capture("focus_cooldown_initiated")
    }
}
