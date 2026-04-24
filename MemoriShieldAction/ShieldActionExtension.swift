import ManagedSettings
import UserNotifications
import Foundation

class ShieldActionExtension: ShieldActionDelegate {
    private let sharedDefaults = UserDefaults(suiteName: "group.com.memori.shared")!

    override func handle(action: ShieldAction, for application: ApplicationToken, completionHandler: @escaping (ShieldActionResponse) -> Void) {
        handleAction(action, completionHandler: completionHandler)
    }

    override func handle(action: ShieldAction, for webDomain: WebDomainToken, completionHandler: @escaping (ShieldActionResponse) -> Void) {
        handleAction(action, completionHandler: completionHandler)
    }

    override func handle(action: ShieldAction, for category: ActivityCategoryToken, completionHandler: @escaping (ShieldActionResponse) -> Void) {
        handleAction(action, completionHandler: completionHandler)
    }

    private func handleAction(_ action: ShieldAction, completionHandler: @escaping (ShieldActionResponse) -> Void) {
        switch action {
        case .primaryButtonPressed:
            // Increment daily attempt count
            let count = dailyAttemptCount
            sharedDefaults.set(count + 1, forKey: "focus_daily_attempt_count")
            sharedDefaults.set(Date(), forKey: "focus_daily_attempt_date")

            // Send a local notification that deep-links into the app
            sendUnlockNotification()

            // Close the shield (sends user to home screen, notification appears immediately)
            completionHandler(.close)

        case .secondaryButtonPressed:
            completionHandler(.close)

        @unknown default:
            completionHandler(.close)
        }
    }

    private func sendUnlockNotification() {
        let content = UNMutableNotificationContent()
        content.title = "Ready to unlock?"
        content.body = "Tap to play a quick brain game and earn screen time."
        content.sound = .default
        content.userInfo = ["deepLink": "memori://focus-unlock"]

        // Fire immediately
        let request = UNNotificationRequest(
            identifier: "focus_unlock_\(UUID().uuidString)",
            content: content,
            trigger: UNTimeIntervalNotificationTrigger(timeInterval: 0.5, repeats: false)
        )

        UNUserNotificationCenter.current().add(request)
    }

    private var dailyAttemptCount: Int {
        let savedDate = sharedDefaults.object(forKey: "focus_daily_attempt_date") as? Date
        if let savedDate, Calendar.current.isDateInToday(savedDate) {
            return sharedDefaults.integer(forKey: "focus_daily_attempt_count")
        }
        return 0
    }
}
