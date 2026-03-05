import Foundation
import SwiftData

@Model
final class Exercise {
    var id: UUID = UUID()
    var typeRaw: String = ExerciseType.spacedRepetition.rawValue
    var difficulty: Int = 1
    var completedAt: Date = Date()
    var score: Double = 0.0
    var durationSeconds: Int = 0

    init(type: ExerciseType, difficulty: Int, score: Double, durationSeconds: Int) {
        self.typeRaw = type.rawValue
        self.difficulty = difficulty
        self.score = score
        self.durationSeconds = durationSeconds
        self.completedAt = Date()
    }

    var type: ExerciseType {
        get { ExerciseType(rawValue: typeRaw) ?? .spacedRepetition }
        set { typeRaw = newValue.rawValue }
    }
}
