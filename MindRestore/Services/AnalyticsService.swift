import Foundation
import TelemetryDeck

enum Analytics {
    static let appID = "07CABBEB-051B-4AC3-937F-FD0A276D09C7"

    static func configure() {
        let config = TelemetryDeck.Config(appID: appID)
        TelemetryDeck.initialize(config: config)
    }

    // MARK: - Onboarding

    static func onboardingCompleted(goals: [String]) {
        TelemetryDeck.signal("onboarding.completed", parameters: [
            "goalCount": "\(goals.count)",
            "goals": goals.joined(separator: ",")
        ])
    }

    static func onboardingStep(step: String) {
        TelemetryDeck.signal("onboarding.step", parameters: [
            "step": step
        ])
    }

    // MARK: - Exercises

    static func exerciseStarted(game: String) {
        TelemetryDeck.signal("exercise.started", parameters: [
            "game": game
        ])
    }

    static func exerciseCompleted(game: String, score: Double, difficulty: Int) {
        TelemetryDeck.signal("exercise.completed", parameters: [
            "game": game,
            "score": String(format: "%.2f", score),
            "difficulty": "\(difficulty)"
        ])
    }

    static func personalBest(game: String, score: Int) {
        TelemetryDeck.signal("exercise.personalBest", parameters: [
            "game": game,
            "score": "\(score)"
        ])
    }

    // MARK: - Brain Score

    static func brainScoreCompleted(score: Int, brainAge: Int) {
        TelemetryDeck.signal("brainScore.completed", parameters: [
            "score": "\(score)",
            "brainAge": "\(brainAge)"
        ])
    }

    // MARK: - Paywall

    static func paywallShown(trigger: String = "unknown") {
        TelemetryDeck.signal("paywall.shown", parameters: [
            "trigger": trigger
        ])
    }

    static func paywallConverted(plan: String) {
        TelemetryDeck.signal("paywall.converted", parameters: [
            "plan": plan
        ])
    }

    static func paywallDismissed(trigger: String = "unknown") {
        TelemetryDeck.signal("paywall.dismissed", parameters: [
            "trigger": trigger
        ])
    }

    // MARK: - Sharing

    static func shareTapped(game: String) {
        TelemetryDeck.signal("share.tapped", parameters: [
            "game": game
        ])
    }

    // MARK: - Engagement

    static func streakMilestone(streak: Int) {
        TelemetryDeck.signal("streak.milestone", parameters: [
            "streak": "\(streak)"
        ])
    }

    static func achievementUnlocked(achievement: String) {
        TelemetryDeck.signal("achievement.unlocked", parameters: [
            "achievement": achievement
        ])
    }

    static func leaderboardViewed(category: String) {
        TelemetryDeck.signal("leaderboard.viewed", parameters: [
            "category": category
        ])
    }
}
