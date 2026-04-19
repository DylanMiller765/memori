import SwiftUI

enum DeepLinkDestination: Equatable {
    case home
    case train
    case game(ExerciseType)
    case compete
    case insights
    case profile
    case dailyChallenge
    case challenge(ChallengeLink)
    case referral(String)
    case focusUnlock
}

@MainActor @Observable
final class DeepLinkRouter {
    var pendingDestination: DeepLinkDestination?
    var pendingChallenge: ChallengeLink?

    private static let universalLinkHost = "getmemoriapp.com"

    func handle(_ url: URL) {
        // Handle Universal Links from Vercel domain
        if url.host == Self.universalLinkHost && url.path == "/challenge" {
            if let link = ChallengeLink(url: url) {
                pendingChallenge = link
                pendingDestination = .challenge(link)
            }
            return
        }

        guard url.scheme == "memori" else { return }

        switch url.host {
        case "home": pendingDestination = .home
        case "train": pendingDestination = .train
        case "compete": pendingDestination = .compete
        case "insights": pendingDestination = .insights
        case "profile": pendingDestination = .profile
        case "challenge": pendingDestination = .dailyChallenge
        case "duel":
            if let link = ChallengeLink(url: url) {
                pendingChallenge = link
                pendingDestination = .challenge(link)
            } else {
                pendingDestination = .train
            }
        case "game":
            if let typeName = url.pathComponents.dropFirst().first,
               let type = ExerciseType(rawValue: typeName) {
                pendingDestination = .game(type)
            } else {
                pendingDestination = .train
            }
        case "focus-unlock": pendingDestination = .focusUnlock
        case "refer":
            if let components = URLComponents(url: url, resolvingAgainstBaseURL: false),
               let code = components.queryItems?.first(where: { $0.name == "code" })?.value {
                pendingDestination = .referral(code)
            } else {
                pendingDestination = .home
            }
        default:
            pendingDestination = .home
        }
    }
}
