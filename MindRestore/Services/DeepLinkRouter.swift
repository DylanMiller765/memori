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
}

@MainActor @Observable
final class DeepLinkRouter {
    var pendingDestination: DeepLinkDestination?
    var pendingChallenge: ChallengeLink?

    func handle(_ url: URL) {
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
        default:
            pendingDestination = .home
        }
    }
}
