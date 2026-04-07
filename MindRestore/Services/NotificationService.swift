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
        ("Your Brain Score awaits", "3 games. 5 minutes. See if you improved."),
        ("Quick brain check", "Your score won't improve itself. Play today."),
        ("Train your brain", "Yesterday's you set the bar. Beat it."),
        ("Brain training time", "Your ranking is live. Climb higher."),
        ("Don't let your brain slack", "5 minutes today = sharper tomorrow."),
        ("Your brain called", "It wants its daily workout. 3 games, let's go."),
        ("Score check", "Your Brain Score is waiting. Did it go up?"),
        ("Daily brain reps", "Even 3 games makes a difference."),
        ("Quick session?", "Your brain gets sharper every day you train."),
        ("The leaderboard moved", "Did you move with it? Play now."),
    ]

    func scheduleDailyReminder(hour: Int, minute: Int, streak: Int) {
        let center = UNUserNotificationCenter.current()
        center.removePendingNotificationRequests(withIdentifiers: ["daily_reminder"])

        let dayOfYear = Calendar.current.ordinality(of: .day, in: .year, for: .now) ?? 0
        let message = Self.reminderMessages[dayOfYear % Self.reminderMessages.count]

        let content = UNMutableNotificationContent()
        content.title = message.title
        content.body = streak > 0
            ? "\(message.body) (\(streak)-day streak!)"
            : message.body
        content.sound = .default

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
            ("Your streak is at risk!", "You've trained \(streak) days straight. Don't break it now."),
            ("\(streak)-day streak on the line", "One quick game saves it. 2 minutes."),
            ("Don't lose \(streak) days!", "Your streak vanishes at midnight. Play now."),
            ("Streak alert", "\(streak) days of brain training. Keep the chain alive."),
            ("Last chance today", "Your \(streak)-day streak needs you. One game."),
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
            3: ("3-Day Streak!", "You're building a habit. Keep it up!"),
            7: ("One Week Strong!", "7 days straight — you're on fire!"),
            14: ("Two Weeks!", "14 days of brain training. Impressive dedication."),
            30: ("30-Day Legend!", "A full month of training. Your brain thanks you."),
            60: ("60-Day Titan!", "Two months strong. You're in the top 1%."),
            100: ("100 DAYS!", "Triple digits! You are a cognitive legend."),
        ]

        let message = messages[streak] ?? ("Milestone!", "You've trained for \(streak) days straight!")

        let content = UNMutableNotificationContent()
        content.title = message.title
        content.body = message.body
        content.sound = .default

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
            ("Your brain misses training", "It's been a while. See where you rank now."),
            ("Brain Score check-in", "Come back and see if your score held up."),
            ("Your leaderboard rank dropped", "Other players are training. Are you?"),
            ("Quick comeback session?", "3 games. Your brain remembers how to play."),
        ]

        let message = messages[lastTrainedDaysAgo % messages.count]

        let content = UNMutableNotificationContent()
        content.title = message.title
        content.body = message.body
        content.sound = .default

        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: 3600, repeats: false)
        let request = UNNotificationRequest(identifier: "comeback", content: content, trigger: trigger)

        center.add(request)
    }

    // MARK: - Achievement Nudge

    func scheduleAchievementNudge(achievementName: String, progress: String) {
        let content = UNMutableNotificationContent()
        content.title = "Almost there!"
        content.body = "\(progress) to unlock \"\(achievementName)\". You got this!"
        content.sound = .default

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
        content.title = "Level \(level) — \(levelName)!"
        content.body = "You leveled up! Keep training to reach the next milestone."
        content.sound = .default

        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: 1, repeats: false)
        let request = UNNotificationRequest(identifier: "level_up", content: content, trigger: trigger)

        UNUserNotificationCenter.current().add(request)
    }

    // MARK: - Weekly Brain Report

    func scheduleWeeklyReport(brainScore: Int, previousBrainScore: Int) {
        let center = UNUserNotificationCenter.current()
        center.removePendingNotificationRequests(withIdentifiers: ["weeklyReport"])

        let content = UNMutableNotificationContent()
        content.sound = .default

        if brainScore == 0 {
            content.title = "Your first Brain Score awaits"
            content.body = "Play a few games this week and find out how sharp your brain really is."
        } else {
            let delta = brainScore - previousBrainScore
            if delta > 0 {
                content.title = "Your brain got sharper!"
                content.body = "Brain Score: \(brainScore) — up \(delta) points from last week. Keep the momentum going."
            } else if delta < 0 {
                content.title = "Your Brain Score dipped"
                content.body = "Brain Score: \(brainScore) — down \(abs(delta)) points. A quick session can turn it around."
            } else {
                content.title = "Weekly Brain Report"
                content.body = "Brain Score: \(brainScore) — holding steady. Can you push it higher this week?"
            }
        }

        var dateComponents = DateComponents()
        dateComponents.weekday = 2  // Monday
        dateComponents.hour = 9     // 9 AM
        dateComponents.minute = 0

        let trigger = UNCalendarNotificationTrigger(dateMatching: dateComponents, repeats: true)
        let request = UNNotificationRequest(identifier: "weeklyReport", content: content, trigger: trigger)

        center.add(request)
    }

    // MARK: - Retake Assessment Reminder

    private static let retakeIdentifier = "retake-reminder"

    func scheduleRetakeReminder(lastAssessmentDate: Date) {
        let center = UNUserNotificationCenter.current()
        center.removePendingNotificationRequests(withIdentifiers: [Self.retakeIdentifier])

        guard let fireDate = Calendar.current.date(byAdding: .day, value: 7, to: lastAssessmentDate),
              fireDate > Date.now else { return }

        let content = UNMutableNotificationContent()
        content.title = "Your brain has been training!"
        content.body = "Retake your Brain Score to see how much you've improved"
        content.sound = .default

        let interval = fireDate.timeIntervalSinceNow
        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: max(1, interval), repeats: false)
        let request = UNNotificationRequest(identifier: Self.retakeIdentifier, content: content, trigger: trigger)

        center.add(request)
    }

    func cancelRetakeReminder() {
        UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: [Self.retakeIdentifier])
    }

    // MARK: - Brain Score Follow-Up

    func scheduleBrainScoreFollowUp(currentScore: Int) {
        let content = UNMutableNotificationContent()
        content.title = "Your Brain Score hit \(currentScore)"
        content.body = "Play today to push it even higher."
        content.sound = .default

        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: 24 * 60 * 60, repeats: false)
        let request = UNNotificationRequest(
            identifier: "brainScoreFollowUp",
            content: content,
            trigger: trigger
        )
        UNUserNotificationCenter.current().add(request)
    }

    func scheduleDecayWarning(pointsLost: Int) {
        let content = UNMutableNotificationContent()
        content.title = "Your Brain Score dropped \(pointsLost) points"
        content.body = "Play today to recover. Your brain needs consistent training."
        content.sound = .default

        // Schedule for 2 hours from now (give them time to play first)
        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: 2 * 60 * 60, repeats: false)
        let request = UNNotificationRequest(
            identifier: "decay_warning",
            content: content,
            trigger: trigger
        )
        UNUserNotificationCenter.current().add(request)
    }

    func cancelDecayWarning() {
        UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: ["decay_warning"])
    }

    func cancelStreakRisk() {
        UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: ["streak_risk"])
    }

    // MARK: - Social Proof (competitive urgency)

    func scheduleSocialProof(currentRank: Int? = nil, brainScore: Int? = nil) {
        let center = UNUserNotificationCenter.current()
        center.removePendingNotificationRequests(withIdentifiers: ["social_proof"])

        // Generate a competitive message with fake but believable numbers
        let dropped = Int.random(in: 2...8)
        let beatCount = Int.random(in: 3...12)
        let scoreGap = Int.random(in: 5...25)

        let messages: [(title: String, body: String)] = [
            ("You dropped \(dropped) spots on the leaderboard", "\(beatCount) players passed you today. Train now to win it back."),
            ("\(beatCount) players just beat your score", "They trained today — you didn't. Take it back."),
            ("Your rank dropped to #\(Int.random(in: 40...150))", "Others are grinding. One session to reclaim your spot."),
            ("Someone scored \(scoreGap) points higher than you", "Your Brain Score is falling behind. Fight back."),
            ("The leaderboard moved without you", "\(beatCount) players climbed past you. Show them who's boss."),
            ("You're losing ground", "\(dropped) players overtook you since yesterday. Defend your rank."),
        ]

        let msg = messages.randomElement()!
        let content = UNMutableNotificationContent()
        content.title = msg.title
        content.body = msg.body
        content.sound = .default

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

    // MARK: - Daily Brain Fact

    private static let brainFacts: [(title: String, body: String)] = [
        ("Your brain uses 20% of your energy", "Despite being only 2% of your body weight. Train it daily."),
        ("Neurons fire up to 200 times per second", "Reaction time training strengthens these pathways."),
        ("Working memory peaks in your 20s", "But training can slow the decline at any age."),
        ("Sleep consolidates memory", "What you trained today gets stronger overnight."),
        ("Your brain creates 700 new neurons daily", "In the hippocampus — the memory center. Keep them busy."),
        ("Multitasking is a myth", "Your brain switches tasks, it doesn't parallel process. Dual N-Back trains this."),
        ("Stress shrinks your hippocampus", "But cognitive training can reverse the effect."),
        ("Brain training improves processing speed by 15%", "Studies show consistent training pays off."),
        ("Chimps beat humans at short-term memory", "Chimpanzee Ayumu memorizes faster than any human tested."),
        ("The Stroop effect was discovered in 1935", "Your Color Match game is based on 90 years of research."),
        ("Your brain can hold 7±2 items", "George Miller's magic number. Number Memory tests this limit."),
        ("Neuroplasticity never stops", "Your brain rewires itself every time you learn something new."),
        ("Speed of thought: 268 mph", "Signals travel through myelinated neurons at highway speeds."),
        ("Reading changes your brain structure", "The brain physically adapts. So does training."),
    ]

    func scheduleDailyBrainFact() {
        let center = UNUserNotificationCenter.current()
        center.removePendingNotificationRequests(withIdentifiers: ["brain_fact"])

        let fact = Self.brainFacts.randomElement()!
        let content = UNMutableNotificationContent()
        content.title = fact.title
        content.body = fact.body
        content.sound = .default

        // Fire at a random time between 9am and 8pm
        var dateComponents = DateComponents()
        dateComponents.hour = Int.random(in: 9...20)
        dateComponents.minute = Int.random(in: 0...59)
        let trigger = UNCalendarNotificationTrigger(dateMatching: dateComponents, repeats: false)

        let request = UNNotificationRequest(identifier: "brain_fact", content: content, trigger: trigger)
        center.add(request)
    }

    // MARK: - Decay Preview Warning (24h before decay starts)

    func scheduleDecayPreview() {
        let content = UNMutableNotificationContent()
        content.title = "Your brain score starts dropping tomorrow"
        content.body = "Train today to keep your score safe."
        content.sound = .default

        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: 24 * 60 * 60, repeats: false)
        let request = UNNotificationRequest(identifier: "decay_preview", content: content, trigger: trigger)
        UNUserNotificationCenter.current().add(request)
    }

    func cancelDecayPreview() {
        UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: ["decay_preview"])
    }

    func cancelAll() {
        UNUserNotificationCenter.current().removeAllPendingNotificationRequests()
    }
}
