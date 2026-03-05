import Foundation

@Observable
final class HomeViewModel {
    var todaySessionCount: Int = 0
    var totalSessions: Int = 0
    var averageScore: Double = 0
    var currentStreak: Int = 0
    var longestStreak: Int = 0
    var dailyGoal: Int = 3
    var hasTrainedToday: Bool = false

    func refresh(user: User?, sessions: [DailySession]) {
        guard let user else { return }

        currentStreak = user.currentStreak
        longestStreak = user.longestStreak
        dailyGoal = user.dailyGoal
        totalSessions = sessions.count
        hasTrainedToday = user.lastSessionDate?.isToday ?? false

        let todaySessions = sessions.filter { Calendar.current.isDateInToday($0.date) }
        todaySessionCount = todaySessions.first?.exercisesCompleted.count ?? 0

        let allScores = sessions.compactMap { $0.totalScore }
        averageScore = allScores.isEmpty ? 0 : allScores.reduce(0, +) / Double(allScores.count)
    }
}
