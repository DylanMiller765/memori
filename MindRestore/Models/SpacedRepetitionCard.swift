import Foundation
import SwiftData

@Model
final class SpacedRepetitionCard {
    var id: UUID = UUID()
    var categoryRaw: String = CardCategory.numbers.rawValue
    var prompt: String = ""
    var answer: String = ""
    var easeFactor: Double = 2.5
    var interval: Int = 0
    var repetitions: Int = 0
    var nextReviewDate: Date = Date()
    var lastReviewDate: Date?

    init(category: CardCategory, prompt: String, answer: String) {
        self.categoryRaw = category.rawValue
        self.prompt = prompt
        self.answer = answer
    }

    var category: CardCategory {
        get { CardCategory(rawValue: categoryRaw) ?? .numbers }
        set { categoryRaw = newValue.rawValue }
    }
}
