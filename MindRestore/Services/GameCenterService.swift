import Foundation
import GameKit
import SwiftUI

@MainActor @Observable
final class GameCenterService {

    // MARK: - State

    var isAuthenticated = false

    /// When true, loadLeaderboardEntries returns mock data for screenshots (debug only)
    var useMockData = false

    // MARK: - Leaderboard IDs

    static let brainScoreLeaderboard = "com.dylanmiller.mindrestore.leaderboard.brainScore"
    static let weeklyXPLeaderboard = "com.dylanmiller.mindrestore.leaderboard.weeklyXP"
    static let longestStreakLeaderboard = "com.dylanmiller.mindrestore.leaderboard.longestStreak"
    static let reactionTimeLeaderboard = "com.dylanmiller.mindrestore.leaderboard.reactionTime"
    static let colorMatchLeaderboard = "com.dylanmiller.mindrestore.leaderboard.colorMatch"
    static let speedMatchLeaderboard = "com.dylanmiller.mindrestore.leaderboard.speedMatch"
    static let visualMemoryLeaderboard = "com.dylanmiller.mindrestore.leaderboard.visualMemory"
    static let numberMemoryLeaderboard = "com.dylanmiller.mindrestore.leaderboard.numberMemory"
    static let mathSpeedLeaderboard = "com.dylanmiller.mindrestore.leaderboard.mathSpeed"
    static let dualNBackLeaderboard = "com.dylanmiller.mindrestore.leaderboard.dualNBack"

    // MARK: - Achievement ID Mapping

    static func gameCenterAchievementID(for type: AchievementType) -> String {
        "com.dylanmiller.mindrestore.achievement.\(type.rawValue)"
    }

    // MARK: - Category → Leaderboard ID

    static func leaderboardID(for category: LeaderboardCategory) -> String {
        switch category {
        case .brainScore: return brainScoreLeaderboard
        case .weeklyXP: return weeklyXPLeaderboard
        case .streak: return longestStreakLeaderboard
        case .reactionTime: return reactionTimeLeaderboard
        case .colorMatch: return colorMatchLeaderboard
        case .speedMatch: return speedMatchLeaderboard
        case .visualMemory: return visualMemoryLeaderboard
        case .numberMemory: return numberMemoryLeaderboard
        case .mathSpeed: return mathSpeedLeaderboard
        case .dualNBack: return dualNBackLeaderboard
        }
    }

    // MARK: - Authentication

    func authenticate() {
        GKLocalPlayer.local.authenticateHandler = { [weak self] viewController, error in
            Task { @MainActor in
                if let viewController {
                    if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
                       let rootVC = windowScene.windows.first?.rootViewController {
                        rootVC.present(viewController, animated: true)
                    }
                    return
                }

                if let error {
                    print("[GameCenterService] Authentication error: \(error.localizedDescription)")
                }

                self?.isAuthenticated = GKLocalPlayer.local.isAuthenticated
            }
        }
    }

    // MARK: - Load Leaderboard Entries

    struct LeaderboardResult {
        let entries: [LeaderboardEntryData]
        let localPlayerEntry: LeaderboardEntryData?
        let totalPlayerCount: Int
    }

    func loadLeaderboardEntries(
        category: LeaderboardCategory,
        timeFilter: LeaderboardTimeFilter,
        range: NSRange = NSRange(location: 1, length: 50)
    ) async -> LeaderboardResult {
        if useMockData {
            return Self.mockLeaderboardResult(for: category)
        }

        guard isAuthenticated else {
            return LeaderboardResult(entries: [], localPlayerEntry: nil, totalPlayerCount: 0)
        }

        let leaderboardID = Self.leaderboardID(for: category)

        let timeScope: GKLeaderboard.TimeScope
        switch timeFilter {
        case .today: timeScope = .today
        case .thisWeek: timeScope = .week
        case .allTime: timeScope = .allTime
        }

        do {
            let leaderboards = try await GKLeaderboard.loadLeaderboards(IDs: [leaderboardID])
            guard let leaderboard = leaderboards.first else {
                return LeaderboardResult(entries: [], localPlayerEntry: nil, totalPlayerCount: 0)
            }

            let (localEntry, globalEntries, totalCount) = try await leaderboard.loadEntries(
                for: .global,
                timeScope: timeScope,
                range: range
            )

            var entries: [LeaderboardEntryData] = []
            let localPlayerID = GKLocalPlayer.local.teamPlayerID

            for (index, entry) in (globalEntries ?? []).enumerated() {
                entries.append(LeaderboardEntryData(
                    rank: entry.rank,
                    username: entry.player.displayName,
                    score: entry.score,
                    avatarEmoji: "",
                    level: 0,
                    isCurrentUser: entry.player.teamPlayerID == localPlayerID
                ))
            }

            var localPlayerData: LeaderboardEntryData?
            if let localEntry {
                localPlayerData = LeaderboardEntryData(
                    rank: localEntry.rank,
                    username: localEntry.player.displayName,
                    score: localEntry.score,
                    avatarEmoji: "",
                    level: 0,
                    isCurrentUser: true
                )
                // If local player isn't in the global list, add them
                if !entries.contains(where: { $0.isCurrentUser }) {
                    entries.append(localPlayerData!)
                    entries.sort { $0.rank < $1.rank }
                }
            }

            return LeaderboardResult(
                entries: entries,
                localPlayerEntry: localPlayerData,
                totalPlayerCount: totalCount
            )
        } catch {
            print("[GameCenterService] Failed to load leaderboard: \(error.localizedDescription)")
            return LeaderboardResult(entries: [], localPlayerEntry: nil, totalPlayerCount: 0)
        }
    }

    // MARK: - Score Reporting

    func reportScore(_ score: Int, leaderboardID: String) {
        guard isAuthenticated else { return }

        Task {
            do {
                print("[GameCenterService] Submitting score \(score) to leaderboard \(leaderboardID)")
                try await GKLeaderboard.submitScore(
                    score,
                    context: 0,
                    player: GKLocalPlayer.local,
                    leaderboardIDs: [leaderboardID]
                )
                print("[GameCenterService] Successfully submitted score \(score) to \(leaderboardID)")
            } catch {
                print("[GameCenterService] Failed to report score \(score) to \(leaderboardID): \(error.localizedDescription)")
            }
        }
    }

    // MARK: - Achievement Reporting

    func reportAchievement(_ id: String, percentComplete: Double) {
        guard isAuthenticated else { return }

        Task {
            let achievement = GKAchievement(identifier: id)
            achievement.percentComplete = percentComplete
            achievement.showsCompletionBanner = true

            do {
                try await GKAchievement.report([achievement])
            } catch {
                print("[GameCenterService] Failed to report achievement: \(error.localizedDescription)")
            }
        }
    }

    /// Report an app achievement as fully completed to Game Center.
    func reportAchievement(for type: AchievementType) {
        let gcID = Self.gameCenterAchievementID(for: type)
        reportAchievement(gcID, percentComplete: 100.0)
    }

    // MARK: - Show Game Center UI

    func showLeaderboard(leaderboardID: String = brainScoreLeaderboard) {
        guard isAuthenticated else { return }
        presentGameCenterVC(state: .leaderboards, leaderboardID: leaderboardID)
    }

    func showAchievements() {
        guard isAuthenticated else { return }
        presentGameCenterVC(state: .achievements)
    }

    // MARK: - Private

    // MARK: - Mock Data for Screenshots

    static func mockLeaderboardResult(for category: LeaderboardCategory) -> LeaderboardResult {
        let names = ["NeuroPilot", "MindMaster", "BrainWave99", "CognitoX", "MemoryKing",
                     "ThinkFast", "SynapseGod", "MentalAce", "QuickMind", "IronFocus",
                     "Dylan", "SharpEdge", "PuzzlePro", "FocusZone", "CortexMax"]

        // Generate scores appropriate for each category
        let (scores, isLowBetter) = mockScores(for: category)

        var entries: [LeaderboardEntryData] = []
        for i in 0..<min(names.count, scores.count) {
            entries.append(LeaderboardEntryData(
                rank: i + 1,
                username: names[i],
                score: scores[i],
                avatarEmoji: "",
                level: 0,
                isCurrentUser: names[i] == "Dylan"
            ))
        }

        // Sort appropriately
        if isLowBetter {
            entries.sort { $0.score < $1.score }
        } else {
            entries.sort { $0.score > $1.score }
        }

        // Re-rank
        entries = entries.enumerated().map { i, e in
            LeaderboardEntryData(rank: i + 1, username: e.username, score: e.score,
                                 avatarEmoji: e.avatarEmoji, level: e.level, isCurrentUser: e.isCurrentUser)
        }

        let localEntry = entries.first(where: { $0.isCurrentUser })

        return LeaderboardResult(
            entries: entries,
            localPlayerEntry: localEntry,
            totalPlayerCount: 847 // Fake total for percentile
        )
    }

    private static func mockScores(for category: LeaderboardCategory) -> (scores: [Int], isLowBetter: Bool) {
        switch category {
        case .brainScore:
            return ([892, 845, 810, 788, 765, 748, 730, 715, 698, 680, 665, 641, 620, 590, 550], false)
        case .reactionTime:
            // Lower is better; Dylan at 288ms
            return ([178, 195, 210, 222, 238, 245, 255, 268, 275, 288, 298, 315, 330, 355, 390], true)
        case .colorMatch:
            // Composite: accuracy% × 1000 + timeBonus
            return ([98974, 96960, 95945, 94930, 93920, 92905, 90890, 89870, 87850, 85830, 82800, 80780, 78750, 75720, 70680], false)
        case .speedMatch:
            // Composite: accuracy% × 1000 + timeBonus
            return ([96970, 94955, 93940, 91920, 90910, 88890, 87875, 85855, 83835, 80810, 78785, 75760, 72730, 68690, 65660], false)
        case .visualMemory:
            return ([12, 11, 10, 9, 9, 8, 8, 7, 7, 7, 6, 6, 6, 5, 5], false)
        case .numberMemory:
            return ([14, 13, 12, 11, 11, 10, 10, 9, 9, 9, 8, 8, 7, 7, 6], false)
        case .mathSpeed:
            // Composite: correctCount × 1000 + timeBonus
            return ([24970, 22955, 21940, 20930, 19920, 18905, 17890, 16880, 16860, 15850, 14835, 13820, 12800, 11780, 10760], false)
        case .dualNBack:
            return ([8, 7, 7, 6, 6, 5, 5, 5, 4, 4, 4, 3, 3, 3, 2], false)
        case .weeklyXP:
            return ([2400, 2100, 1850, 1700, 1550, 1420, 1300, 1180, 1050, 950, 850, 750, 650, 550, 450], false)
        case .streak:
            return ([180, 120, 95, 78, 65, 52, 45, 38, 30, 25, 21, 18, 14, 10, 7], false)
        }
    }

    // MARK: - Private

    private func presentGameCenterVC(
        state: GKGameCenterViewControllerState,
        leaderboardID: String? = nil
    ) {
        let gcVC: GKGameCenterViewController
        if let leaderboardID, state == .leaderboards {
            gcVC = GKGameCenterViewController(leaderboardID: leaderboardID, playerScope: .global, timeScope: .allTime)
        } else {
            gcVC = GKGameCenterViewController(state: state)
        }

        guard let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
              let rootVC = windowScene.windows.first?.rootViewController else {
            return
        }

        // Walk the presented VC chain to find the topmost one
        var topVC = rootVC
        while let presented = topVC.presentedViewController {
            topVC = presented
        }

        gcVC.gameCenterDelegate = GameCenterDismissHandler.shared
        topVC.present(gcVC, animated: true)
    }
}

// MARK: - Dismiss Handler

/// Singleton handler for dismissing the Game Center view controller.
private final class GameCenterDismissHandler: NSObject, GKGameCenterControllerDelegate {
    static let shared = GameCenterDismissHandler()

    func gameCenterViewControllerDidFinish(_ gameCenterViewController: GKGameCenterViewController) {
        gameCenterViewController.dismiss(animated: true)
    }
}
