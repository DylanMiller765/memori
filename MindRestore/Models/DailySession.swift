import Foundation
import SwiftData

@Model
final class DailySession {
    var id: UUID = UUID()
    var date: Date = Date()
    @Relationship(deleteRule: .cascade) var exercisesCompleted: [Exercise] = []
    var totalScore: Double = 0.0
    var durationSeconds: Int = 0

    init() {}

    func addExercise(_ exercise: Exercise) {
        exercisesCompleted.append(exercise)
        let scores = exercisesCompleted.map(\.score)
        totalScore = scores.reduce(0, +) / Double(scores.count)
        durationSeconds = exercisesCompleted.reduce(0) { $0 + $1.durationSeconds }
    }
}
