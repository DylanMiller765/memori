import ManagedSettings
import Foundation

class ShieldActionExtension: ShieldActionDelegate {
    private let sharedDefaults = UserDefaults(suiteName: "group.com.memori.shared")!

    override func handle(action: ShieldAction, for application: Application, completionHandler: @escaping (ShieldActionResponse) -> Void) {
        handleAction(action, completionHandler: completionHandler)
    }

    override func handle(action: ShieldAction, for category: ActivityCategory, completionHandler: @escaping (ShieldActionResponse) -> Void) {
        handleAction(action, completionHandler: completionHandler)
    }

    override func handle(action: ShieldAction, for webDomain: WebDomain, completionHandler: @escaping (ShieldActionResponse) -> Void) {
        handleAction(action, completionHandler: completionHandler)
    }

    private func handleAction(_ action: ShieldAction, completionHandler: @escaping (ShieldActionResponse) -> Void) {
        switch action {
        case .primaryButtonPressed:
            // Increment attempt count
            let count = dailyAttemptCount
            sharedDefaults.set(count + 1, forKey: "focus_daily_attempt_count")
            sharedDefaults.set(Date(), forKey: "focus_daily_attempt_date")

            // Open Memori app to quick game via URL scheme
            completionHandler(.defer)

        case .secondaryButtonPressed:
            // Stay focused — just dismiss
            completionHandler(.close)

        @unknown default:
            completionHandler(.close)
        }
    }

    private var dailyAttemptCount: Int {
        let savedDate = sharedDefaults.object(forKey: "focus_daily_attempt_date") as? Date
        if let savedDate, Calendar.current.isDateInToday(savedDate) {
            return sharedDefaults.integer(forKey: "focus_daily_attempt_count")
        }
        return 0
    }
}
