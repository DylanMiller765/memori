import Foundation
import SwiftData

@Model
final class User {
    var id: UUID = UUID()
    var createdAt: Date = Date()
    var currentStreak: Int = 0
    var longestStreak: Int = 0
    var lastSessionDate: Date?
    var subscriptionStatusRaw: String = SubscriptionStatus.free.rawValue
    var trialStartDate: Date?
    var hasCompletedOnboarding: Bool = false
    var focusGoalsRaw: [String] = []
    var dailyGoal: Int = 3
    var notificationsEnabled: Bool = false
    var reminderHour: Int = 9
    var reminderMinute: Int = 0
    var soundEnabled: Bool = true

    init() {}

    var subscriptionStatus: SubscriptionStatus {
        get { SubscriptionStatus(rawValue: subscriptionStatusRaw) ?? .free }
        set { subscriptionStatusRaw = newValue.rawValue }
    }

    var focusGoals: [UserFocusGoal] {
        get { focusGoalsRaw.compactMap { UserFocusGoal(rawValue: $0) } }
        set { focusGoalsRaw = newValue.map(\.rawValue) }
    }

    var isProUser: Bool {
        subscriptionStatus == .subscribed || subscriptionStatus == .lifetime || subscriptionStatus == .trial
    }

    func updateStreak(on date: Date = .now) {
        let calendar = Calendar.current
        if let last = lastSessionDate {
            if calendar.isDate(last, inSameDayAs: date) {
                return
            } else if let yesterday = calendar.date(byAdding: .day, value: -1, to: date),
                      calendar.isDate(last, inSameDayAs: yesterday) {
                currentStreak += 1
            } else {
                currentStreak = 1
            }
        } else {
            currentStreak = 1
        }
        lastSessionDate = date
        longestStreak = max(longestStreak, currentStreak)
    }

    var isStreakActive: Bool {
        guard let last = lastSessionDate else { return false }
        let calendar = Calendar.current
        return calendar.isDateInToday(last) || calendar.isDateInYesterday(last)
    }
}
