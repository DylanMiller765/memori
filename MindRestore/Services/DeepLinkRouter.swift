import SwiftUI

extension Notification.Name {
    static let memoHandleDeepLink = Notification.Name("memoHandleDeepLink")
}

/// Bridge for deep links arriving from the AppDelegate (notification taps).
/// AppDelegate can't reach ContentView's router directly, and round-tripping
/// our own URL scheme through `UIApplication.shared.open` is unreliable —
/// it silently drops the link and the app just lands on home. Instead we
/// post to NotificationCenter for warm taps and stash the URL so a cold
/// launch can drain it once the listener exists.
enum PendingDeepLink {
    static var url: URL?

    static func route(_ url: URL) {
        self.url = url
        NotificationCenter.default.post(name: .memoHandleDeepLink, object: url)
    }
}

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
