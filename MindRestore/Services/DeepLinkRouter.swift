import SwiftUI

enum DeepLinkDestination: Equatable {
    case home
    case train
    case game(ExerciseType)
    case compete
    case insights
    case profile
    case focusUnlock
}

@MainActor @Observable
final class DeepLinkRouter {
    var pendingDestination: DeepLinkDestination?

    func handle(_ url: URL) {
        guard url.scheme == "memo" || url.scheme == "memori" else { return }

        switch url.host {
        case "home": pendingDestination = .home
        case "train": pendingDestination = .train
        case "compete": pendingDestination = .compete
        case "insights": pendingDestination = .insights
        case "profile": pendingDestination = .profile
        case "game":
            if let typeName = url.pathComponents.dropFirst().first,
               let type = ExerciseType(rawValue: typeName) {
                pendingDestination = .game(type)
            } else {
                pendingDestination = .train
            }
        case "focus-unlock": pendingDestination = .focusUnlock
        default:
            pendingDestination = .home
        }
    }
}
