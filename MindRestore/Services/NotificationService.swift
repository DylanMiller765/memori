import Foundation
import UserNotifications

final class NotificationService: Sendable {
    static let shared = NotificationService()

    private init() {}

    func requestPermission() async -> Bool {
        do {
            return try await UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound, .badge])
        } catch {
            return false
        }
    }

    func scheduleDailyReminder(hour: Int, minute: Int, streak: Int) {
        let center = UNUserNotificationCenter.current()
        center.removePendingNotificationRequests(withIdentifiers: ["daily_reminder"])

        let content = UNMutableNotificationContent()
        content.title = "Time to train your memory"
        content.body = streak > 0
            ? "Your streak is at \(streak) days. Keep it going!"
            : "Start building your memory training habit today."
        content.sound = .default

        var dateComponents = DateComponents()
        dateComponents.hour = hour
        dateComponents.minute = minute

        let trigger = UNCalendarNotificationTrigger(dateMatching: dateComponents, repeats: true)
        let request = UNNotificationRequest(identifier: "daily_reminder", content: content, trigger: trigger)

        center.add(request)
    }

    func scheduleStreakRisk(streak: Int) {
        let center = UNUserNotificationCenter.current()
        center.removePendingNotificationRequests(withIdentifiers: ["streak_risk"])

        guard streak > 0 else { return }

        let content = UNMutableNotificationContent()
        content.title = "Don't break your streak!"
        content.body = "You haven't trained today. Don't lose your \(streak)-day streak! 5 min is all it takes."
        content.sound = .default

        var dateComponents = DateComponents()
        dateComponents.hour = 20
        dateComponents.minute = 0

        let trigger = UNCalendarNotificationTrigger(dateMatching: dateComponents, repeats: false)
        let request = UNNotificationRequest(identifier: "streak_risk", content: content, trigger: trigger)

        center.add(request)
    }

    func scheduleMilestone(streak: Int) {
        let milestones = [7, 30, 100]
        guard milestones.contains(streak) else { return }

        let content = UNMutableNotificationContent()
        content.title = "Milestone reached!"
        content.body = "You've trained for \(streak) days straight! Your memory is getting stronger."
        content.sound = .default

        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: 1, repeats: false)
        let request = UNNotificationRequest(identifier: "milestone_\(streak)", content: content, trigger: trigger)

        UNUserNotificationCenter.current().add(request)
    }

    func cancelStreakRisk() {
        UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: ["streak_risk"])
    }

    func cancelAll() {
        UNUserNotificationCenter.current().removeAllPendingNotificationRequests()
    }
}
