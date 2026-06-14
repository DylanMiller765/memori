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

    // MARK: - Daily Reminder

    private static let reminderMessages: [(title: String, body: String)] = [
        ("Memo is on patrol", "Run 3 quick rounds, then close the app before the feed gets loud."),
        ("Train before the feed wins", "A few reps now makes the next scroll harder to justify."),
        ("Put the feed on notice", "Train memory, speed, or attention. Then get back to your day."),
        ("Memo needs 3 reps", "Quick session in, phone down after. That's the whole move."),
        ("Guard the next unlock", "Train now so Memo has something to push back with later."),
        ("The feed can wait", "One fast workout. Then leave Memo and do the real thing."),
        ("Your brain gets first dibs", "Train before TikTok, Instagram, or YouTube gets the opening bid."),
        ("Lock in today's reps", "3 games keeps Memo sharp without turning into another app spiral."),
        ("Memo is still guarding", "Give it a quick training receipt, then get off your phone."),
        ("Tiny workout, real pushback", "A few minutes of training makes the feed less automatic."),
    ]

    func scheduleDailyReminder(hour: Int, minute: Int, streak: Int) {
        let center = UNUserNotificationCenter.current()
        center.removePendingNotificationRequests(withIdentifiers: ["daily_reminder"])

        let dayOfYear = Calendar.current.ordinality(of: .day, in: .year, for: .now) ?? 0
        let message = Self.reminderMessages[dayOfYear % Self.reminderMessages.count]

        let content = UNMutableNotificationContent()
        content.title = message.title
        content.body = streak > 0
            ? "\(message.body) \(streak)-day streak on deck."
            : message.body
        content.sound = .default
        content.userInfo = ["deepLink": "memo://train"]

        var dateComponents = DateComponents()
        dateComponents.hour = hour
        dateComponents.minute = minute

        let trigger = UNCalendarNotificationTrigger(dateMatching: dateComponents, repeats: true)
        let request = UNNotificationRequest(identifier: "daily_reminder", content: content, trigger: trigger)

        center.add(request)
    }

    // MARK: - Streak Risk

    private static func streakRiskMessages(streak: Int) -> [(title: String, body: String)] {
        [
            ("Streak on the line", "One game keeps your \(streak)-day training streak alive before midnight."),
            ("Protect the streak", "\(streak) days of reps. One quick round keeps it moving."),
            ("Last call for today's rep", "Train once before midnight and Memo keeps the streak receipt."),
            ("Do the tiny hard thing", "One game saves the \(streak)-day streak. Then get off the app."),
            ("The feed would love a miss", "One training round keeps your \(streak)-day streak out of its hands."),
        ]
    }

    func scheduleStreakRisk(streak: Int) {
        let center = UNUserNotificationCenter.current()
        center.removePendingNotificationRequests(withIdentifiers: ["streak_risk"])

        guard streak > 0 else { return }

        let messages = Self.streakRiskMessages(streak: streak)
        let message = messages[streak % messages.count]

        let content = UNMutableNotificationContent()
        content.title = message.title
        content.body = message.body
        content.sound = .default
        content.userInfo = ["deepLink": "memo://train"]

        var dateComponents = DateComponents()
        dateComponents.hour = 20
        dateComponents.minute = 0

        let trigger = UNCalendarNotificationTrigger(dateMatching: dateComponents, repeats: false)
        let request = UNNotificationRequest(identifier: "streak_risk", content: content, trigger: trigger)

        center.add(request)
    }

    // MARK: - Milestones

    func scheduleMilestone(streak: Int) {
        let milestones = [3, 7, 14, 30, 60, 100]
        guard milestones.contains(streak) else { return }

        let messages: [Int: (title: String, body: String)] = [
            3: ("3 days on patrol", "Memo has a real training streak now. Keep the feed earning its way back."),
            7: ("One week guarded", "7 straight days of reps. The feed had to work harder this week."),
            14: ("Two weeks of pushback", "14 days of training before the scroll. That is the system working."),
            30: ("30 days trained", "A full month of putting your brain before the feed."),
            60: ("60 days guarded", "Two months of reps, locks, and comeback receipts."),
            100: ("100 days of Memo", "Triple digits. The feed is no longer driving without a fight."),
        ]

        let message = messages[streak] ?? ("\(streak) days trained", "Memo logged another streak milestone.")

        let content = UNMutableNotificationContent()
        content.title = message.title
        content.body = message.body
        content.sound = .default
        content.userInfo = ["deepLink": "memo://train"]

        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: 1, repeats: false)
        let request = UNNotificationRequest(identifier: "milestone_\(streak)", content: content, trigger: trigger)

        UNUserNotificationCenter.current().add(request)
    }

    // MARK: - Comeback Notifications

    func scheduleComebackNotification(lastTrainedDaysAgo: Int) {
        let center = UNUserNotificationCenter.current()
        center.removePendingNotificationRequests(withIdentifiers: ["comeback"])

        guard lastTrainedDaysAgo >= 2 else { return }

        let messages: [(title: String, body: String)] = [
            ("The feed got comfortable", "\(lastTrainedDaysAgo) days without a rep. One game puts Memo back on patrol."),
            ("Memo needs a fresh receipt", "Train once today so the next unlock is earned, not automatic."),
            ("Comeback round", "\(lastTrainedDaysAgo) days off. Start with one fast game and leave."),
            ("Reset the pattern", "The scroll had \(lastTrainedDaysAgo) quiet days. Memo only needs one rep to push back."),
        ]

        let message = messages[lastTrainedDaysAgo % messages.count]

        let content = UNMutableNotificationContent()
        content.title = message.title
        content.body = message.body
        content.sound = .default
        content.userInfo = ["deepLink": "memo://train"]

        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: 3600, repeats: false)
        let request = UNNotificationRequest(identifier: "comeback", content: content, trigger: trigger)

        center.add(request)
    }

    // MARK: - Achievement Nudge

    func scheduleAchievementNudge(achievementName: String, progress: String) {
        let content = UNMutableNotificationContent()
        content.title = "Achievement almost unlocked"
        content.body = "\(progress) to earn \"\(achievementName)\". One more receipt for Memo."
        content.sound = .default
        content.userInfo = ["deepLink": "memo://train"]

        var dateComponents = DateComponents()
        dateComponents.hour = 10
        dateComponents.minute = 0

        let trigger = UNCalendarNotificationTrigger(dateMatching: dateComponents, repeats: false)
        let request = UNNotificationRequest(identifier: "achievement_nudge", content: content, trigger: trigger)

        UNUserNotificationCenter.current().add(request)
    }

    // MARK: - Level Up

    func scheduleLevelUpNotification(level: Int, levelName: String) {
        let content = UNMutableNotificationContent()
        content.title = "Level \(level): \(levelName)"
        content.body = "Memo logged the upgrade. Train again when the feed asks for another pass."
        content.sound = .default
        content.userInfo = ["deepLink": "memo://train"]

        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: 1, repeats: false)
        let request = UNNotificationRequest(identifier: "level_up", content: content, trigger: trigger)

        UNUserNotificationCenter.current().add(request)
    }

    // MARK: - Retake Assessment Reminder

    private static let retakeIdentifier = "retake-reminder"

    func scheduleRetakeReminder(lastAssessmentDate: Date) {
        let center = UNUserNotificationCenter.current()
        center.removePendingNotificationRequests(withIdentifiers: [Self.retakeIdentifier])

        guard let fireDate = Calendar.current.date(byAdding: .day, value: 7, to: lastAssessmentDate),
              fireDate > Date.now else { return }

        let content = UNMutableNotificationContent()
        content.title = "Retake your Brain Score"
        content.body = "Memo has new training receipts. Check what changed."
        content.sound = .default
        content.userInfo = ["deepLink": "memo://insights"]

        let interval = fireDate.timeIntervalSinceNow
        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: max(1, interval), repeats: false)
        let request = UNNotificationRequest(identifier: Self.retakeIdentifier, content: content, trigger: trigger)

        center.add(request)
    }

    func cancelRetakeReminder() {
        UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: [Self.retakeIdentifier])
    }

    // MARK: - Trial Reminders

    private static let trialEndDateKey = "memo_trial_end_date"
    private static let trialReminderIdentifiers = [
        "trial_reminder_day5",
        "trial_reminder_last_day"
    ]

    func recordTrialStarted(days: Int) {
        guard let endDate = Calendar.current.date(byAdding: .day, value: days, to: Date.now) else { return }
        UserDefaults.standard.set(endDate, forKey: Self.trialEndDateKey)
        scheduleStoredTrialRemindersIfAuthorized()
    }

    func scheduleStoredTrialRemindersIfAuthorized() {
        guard let endDate = UserDefaults.standard.object(forKey: Self.trialEndDateKey) as? Date,
              endDate > Date.now else { return }

        Task {
            let center = UNUserNotificationCenter.current()
            let settings = await center.notificationSettings()
            guard settings.authorizationStatus == .authorized ||
                  settings.authorizationStatus == .provisional ||
                  settings.authorizationStatus == .ephemeral else { return }

            scheduleTrialReminders(endDate: endDate)
        }
    }

    private func scheduleTrialReminders(endDate: Date) {
        let center = UNUserNotificationCenter.current()
        center.removePendingNotificationRequests(withIdentifiers: Self.trialReminderIdentifiers)

        let calendar = Calendar.current
        let reminderDates: [(id: String, offsetDays: Int, hour: Int, minute: Int, title: String, body: String)] = [
            (
                "trial_reminder_day5",
                -2,
                10,
                0,
                "Your Memo trial ends in 2 days",
                "Keep Memo guarding the feed, or cancel anytime in App Store."
            ),
            (
                "trial_reminder_last_day",
                -1,
                9,
                0,
                "Trial ends tomorrow",
                "Your $49.99/year plan starts tomorrow unless you cancel in App Store."
            )
        ]

        for reminder in reminderDates {
            guard let reminderDay = calendar.date(byAdding: .day, value: reminder.offsetDays, to: endDate),
                  let fireDate = calendar.date(
                    bySettingHour: reminder.hour,
                    minute: reminder.minute,
                    second: 0,
                    of: reminderDay
                  ),
                  fireDate > Date.now else { continue }

            let content = UNMutableNotificationContent()
            content.title = reminder.title
            content.body = reminder.body
            content.sound = .default
            content.userInfo = ["deepLink": "memo://profile"]

            let trigger = UNTimeIntervalNotificationTrigger(timeInterval: max(1, fireDate.timeIntervalSinceNow), repeats: false)
            let request = UNNotificationRequest(identifier: reminder.id, content: content, trigger: trigger)
            center.add(request)
        }
    }

    // MARK: - Brain Score Follow-Up

    func scheduleBrainScoreFollowUp(currentScore: Int) {
        let content = UNMutableNotificationContent()
        content.title = "Brain Score: \(currentScore)"
        content.body = "Nice receipt. One more quick game before the feed gets another shot."
        content.sound = .default
        content.userInfo = ["deepLink": "memo://train"]

        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: 24 * 60 * 60, repeats: false)
        let request = UNNotificationRequest(
            identifier: "brainScoreFollowUp",
            content: content,
            trigger: trigger
        )
        UNUserNotificationCenter.current().add(request)
    }

    func cancelStreakRisk() {
        UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: ["streak_risk"])
    }

    // MARK: - Competitive Nudge

    func scheduleSocialProof(currentRank: Int? = nil, brainScore: Int? = nil) {
        let center = UNUserNotificationCenter.current()
        center.removePendingNotificationRequests(withIdentifiers: ["social_proof"])

        let content = UNMutableNotificationContent()
        if let currentRank {
            content.title = "Rank #\(currentRank) is not parked"
            content.body = "Train once before the week moves without you."
        } else if let brainScore, brainScore > 0 {
            content.title = "Defend Brain Score \(brainScore)"
            content.body = "One short workout keeps your score from going stale."
        } else {
            content.title = "The leaderboard is open"
            content.body = "Train once, check your rank, then get off the app."
        }
        content.sound = .default
        content.userInfo = ["deepLink": "memo://compete"]

        // Fire at 7pm
        var dateComponents = DateComponents()
        dateComponents.hour = 19
        dateComponents.minute = 0
        let trigger = UNCalendarNotificationTrigger(dateMatching: dateComponents, repeats: false)

        let request = UNNotificationRequest(identifier: "social_proof", content: content, trigger: trigger)
        center.add(request)
    }

    func cancelSocialProof() {
        UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: ["social_proof"])
    }

    // MARK: - Training Tip

    private static let brainFacts: [(title: String, body: String)] = [
        ("Attention rep", "Color Match makes your brain ignore the obvious trap. Useful against the feed."),
        ("Memory rep", "Visual Memory trains the same muscle the scroll tries to numb."),
        ("Speed rep", "Reaction Time is a quick reset before you hand the phone back to Big Social."),
        ("Pattern rep", "Speed Match forces fast decisions without opening another feed."),
        ("Focus rep", "Dual N-Back is hard on purpose. The feed is easy on purpose."),
        ("Unlock rep", "Train first, unlock second. That is the Memo contract."),
        ("Feed patrol tip", "Pick the app you open automatically. Memo works best against the reflex."),
        ("Short session wins", "One focused round beats ten minutes of pretending to be productive."),
        ("Protect the next hour", "Train now, then close Memo before it becomes another place to hide."),
        ("Brain before feed", "Give your attention one rep before the algorithm gets a turn."),
    ]

    func scheduleDailyBrainFact() {
        let center = UNUserNotificationCenter.current()
        center.removePendingNotificationRequests(withIdentifiers: ["brain_fact"])

        let fact = Self.brainFacts.randomElement()!
        let content = UNMutableNotificationContent()
        content.title = fact.title
        content.body = fact.body
        content.sound = .default
        content.userInfo = ["deepLink": "memo://train"]

        // Fire at a random time between 9am and 8pm
        var dateComponents = DateComponents()
        dateComponents.hour = Int.random(in: 9...20)
        dateComponents.minute = Int.random(in: 0...59)
        let trigger = UNCalendarNotificationTrigger(dateMatching: dateComponents, repeats: false)

        let request = UNNotificationRequest(identifier: "brain_fact", content: content, trigger: trigger)
        center.add(request)
    }

    // MARK: - Weekly Leaderboard Reset Warning (Sunday 8pm — 4h before midnight reset)

    func scheduleWeeklyLeaderboardReset() {
        let center = UNUserNotificationCenter.current()
        center.removePendingNotificationRequests(withIdentifiers: ["weekly_leaderboard_reset"])

        let messages: [(String, String)] = [
            ("Leaderboard resets tonight", "One clean session before midnight. Then leave the app alone."),
            ("Final reps of the week", "Train once if you want the receipt on this week's board."),
            ("Week closes at midnight", "Memo can still log one more pushback before reset."),
        ]
        let pick = messages.randomElement()!

        let content = UNMutableNotificationContent()
        content.title = pick.0
        content.body = pick.1
        content.sound = .default
        content.userInfo = ["deepLink": "memo://compete"]

        // Sunday at 8pm, repeats weekly
        var dateComponents = DateComponents()
        dateComponents.weekday = 1 // Sunday (Calendar.current's Sunday = 1)
        dateComponents.hour = 20
        dateComponents.minute = 0

        let trigger = UNCalendarNotificationTrigger(dateMatching: dateComponents, repeats: true)
        let request = UNNotificationRequest(identifier: "weekly_leaderboard_reset", content: content, trigger: trigger)
        center.add(request)
    }

    func cancelAll() {
        UNUserNotificationCenter.current().removeAllPendingNotificationRequests()
    }
}
