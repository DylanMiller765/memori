import Foundation

@Observable
final class SpacedRepetitionEngine {

    func processRating(_ card: SpacedRepetitionCard, rating: SelfRating) {
        let ratingValue = rating.rawValue

        if ratingValue == 0 {
            card.repetitions = 0
            card.interval = 1
        } else {
            if card.repetitions == 0 {
                card.interval = 1
            } else if card.repetitions == 1 {
                card.interval = 6
            } else {
                card.interval = Int(round(Double(card.interval) * card.easeFactor))
            }
            card.repetitions += 1
        }

        let q = Double(ratingValue)
        card.easeFactor = card.easeFactor + (0.1 - (3.0 - q) * (0.08 + (3.0 - q) * 0.02))
        card.easeFactor = max(1.3, card.easeFactor)

        card.lastReviewDate = Date()
        card.nextReviewDate = Calendar.current.date(byAdding: .day, value: card.interval, to: Date()) ?? Date()
    }

    func getSessionCards(from allCards: [SpacedRepetitionCard], limit: Int = 15) -> [SpacedRepetitionCard] {
        let now = Date()

        let dueCards = allCards
            .filter { $0.nextReviewDate <= now }
            .sorted { $0.nextReviewDate < $1.nextReviewDate }

        let newCards = allCards
            .filter { $0.repetitions == 0 && $0.nextReviewDate > now }
            .shuffled()

        var result = Array(dueCards.prefix(limit))
        let remaining = limit - result.count
        if remaining > 0 {
            result.append(contentsOf: newCards.prefix(remaining))
        }

        return result
    }
}
