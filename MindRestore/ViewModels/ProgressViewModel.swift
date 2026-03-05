import Foundation

@Observable
final class ProgressViewModel {
    var trainingDays: Set<Date> = []
    var weeklyScores: [(date: Date, score: Double)] = []
    var exerciseBreakdown: [ExerciseType: Int] = [:]
    var memoryScore: Double = 0

    func refresh(sessions: [DailySession]) {
        trainingDays = Set(sessions.map { Calendar.current.startOfDay(for: $0.date) })

        let sevenDaysAgo = Date().daysAgo(7)
        let recentSessions = sessions.filter { $0.date >= sevenDaysAgo }

        weeklyScores = recentSessions.map { (date: $0.date, score: $0.totalScore) }

        var breakdown: [ExerciseType: Int] = [:]
        for session in sessions {
            for exercise in session.exercisesCompleted {
                breakdown[exercise.type, default: 0] += 1
            }
        }
        exerciseBreakdown = breakdown

        let recentScores = recentSessions.map(\.totalScore)
        memoryScore = recentScores.isEmpty ? 0 : recentScores.reduce(0, +) / Double(recentScores.count)
    }
}
