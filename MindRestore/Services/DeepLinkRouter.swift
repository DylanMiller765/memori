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
}

@MainActor @Observable
final class DeepLinkRouter {
    var pendingDestination: DeepLinkDestination?
    var pendingChallenge: ChallengeLink?

    func handle(_ url: URL) {
        // Support both custom scheme (memori://) and Universal Links (https://getmemoriapp.com)
        if url.scheme == "https" {
            handleUniversalLink(url)
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

    private func handleUniversalLink(_ url: URL) {
        guard let components = URLComponents(url: url, resolvingAgainstBaseURL: false),
              components.host == "getmemoriapp.com" else { return }

        switch components.path {
        case "/refer":
            if let code = components.queryItems?.first(where: { $0.name == "code" })?.value {
                pendingDestination = .referral(code)
            } else {
                pendingDestination = .home
            }
        default:
            pendingDestination = .home
        }
    }
}
