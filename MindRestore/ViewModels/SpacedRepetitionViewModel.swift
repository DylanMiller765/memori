import Foundation

@Observable
final class SpacedRepetitionViewModel {
    let engine = SpacedRepetitionEngine()
    var sessionCards: [SpacedRepetitionCard] = []
    var currentCardIndex: Int = 0
    var isRevealed: Bool = false
    var isSessionComplete: Bool = false
    var sessionScore: Double = 0
    var startTime: Date = Date()
    var ratings: [SelfRating] = []

    var currentCard: SpacedRepetitionCard? {
        guard currentCardIndex < sessionCards.count else { return nil }
        return sessionCards[currentCardIndex]
    }

    var progress: Double {
        guard !sessionCards.isEmpty else { return 0 }
        return Double(currentCardIndex) / Double(sessionCards.count)
    }

    func startSession(cards: [SpacedRepetitionCard]) {
        sessionCards = engine.getSessionCards(from: cards)
        currentCardIndex = 0
        isRevealed = false
        isSessionComplete = false
        ratings = []
        startTime = Date()
    }

    func reveal() {
        isRevealed = true
    }

    func rate(_ rating: SelfRating) {
        guard let card = currentCard else { return }
        engine.processRating(card, rating: rating)
        ratings.append(rating)

        currentCardIndex += 1
        isRevealed = false

        if currentCardIndex >= sessionCards.count {
            completeSession()
        }
    }

    private func completeSession() {
        isSessionComplete = true
        let goodOrBetter = ratings.filter { $0.rawValue >= 2 }.count
        sessionScore = Double(goodOrBetter) / Double(max(ratings.count, 1))
    }

    var durationSeconds: Int {
        Int(Date().timeIntervalSince(startTime))
    }
}
