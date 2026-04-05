import Foundation
import GameKit
import SwiftUI

@MainActor @Observable
final class GameCenterService {

    // MARK: - State

    var isAuthenticated = false

    // MARK: - Leaderboard IDs

    static let brainScoreLeaderboard = "com.dylanmiller.mindrestore.leaderboard.brainScore"
    static let xpLeaderboard = "com.dylanmiller.mindrestore.leaderboard.xp"
    static let longestStreakLeaderboard = "com.dylanmiller.mindrestore.leaderboard.longestStreak"
    static let reactionTimeLeaderboard = "com.dylanmiller.mindrestore.leaderboard.reactionTime"
    static let colorMatchLeaderboard = "com.dylanmiller.mindrestore.leaderboard.colorMatch"
    static let speedMatchLeaderboard = "com.dylanmiller.mindrestore.leaderboard.speedMatch"
    static let visualMemoryLeaderboard = "com.dylanmiller.mindrestore.leaderboard.visualMemory"
    static let numberMemoryLeaderboard = "com.dylanmiller.mindrestore.leaderboard.numberMemory"
    static let mathSpeedLeaderboard = "com.dylanmiller.mindrestore.leaderboard.mathSpeed"
    static let dualNBackLeaderboard = "com.dylanmiller.mindrestore.leaderboard.dualNBack"
    static let wordScrambleLeaderboard = "com.dylanmiller.mindrestore.leaderboard.wordScramble"
    static let memoryChainLeaderboard = "com.dylanmiller.mindrestore.leaderboard.memoryChain"
    static let dailyChallengeLeaderboard = "com.dylanmiller.mindrestore.leaderboard.dailyChallengeScore"

    // MARK: - Achievement ID Mapping

    static func gameCenterAchievementID(for type: AchievementType) -> String {
        "com.dylanmiller.mindrestore.achievement.\(type.rawValue)"
    }

    // MARK: - Category → Leaderboard ID

    static func leaderboardID(for category: LeaderboardCategory) -> String {
        switch category {
        case .brainScore: return brainScoreLeaderboard
        case .xp: return xpLeaderboard
        case .streak: return longestStreakLeaderboard
        case .reactionTime: return reactionTimeLeaderboard
        case .colorMatch: return colorMatchLeaderboard
        case .speedMatch: return speedMatchLeaderboard
        case .visualMemory: return visualMemoryLeaderboard
        case .numberMemory: return numberMemoryLeaderboard
        case .mathSpeed: return mathSpeedLeaderboard
        case .dualNBack: return dualNBackLeaderboard
        case .wordScramble: return wordScrambleLeaderboard
        case .memoryChain: return memoryChainLeaderboard
        case .dailyChallenge: return dailyChallengeLeaderboard
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
        var error: Error? = nil
    }

    func loadLeaderboardEntries(
        category: LeaderboardCategory,
        timeFilter: LeaderboardTimeFilter,
        range: NSRange = NSRange(location: 1, length: 50)
    ) async -> LeaderboardResult {
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
                    rank: max(1, entry.rank),
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
                    rank: max(1, localEntry.rank),
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
            return LeaderboardResult(entries: [], localPlayerEntry: nil, totalPlayerCount: 0, error: error)
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
