import Foundation

struct ActiveRecallChallenge: Identifiable {
    let id = UUID()
    let type: ChallengeType
    let title: String
    let displayContent: String
    let displayDuration: TimeInterval
    let questions: [RecallQuestion]
    let difficulty: Int
}

struct RecallQuestion: Identifiable {
    let id = UUID()
    let question: String
    let answer: String
}

@Observable
final class ActiveRecallEngine {
    private var usedChallengeIndices: Set<Int> = []

    func getChallenge(from challenges: [ActiveRecallChallenge], type: ChallengeType? = nil) -> ActiveRecallChallenge? {
        var pool = challenges
        if let type {
            pool = pool.filter { $0.type == type }
        }

        let available = pool.enumerated().filter { !usedChallengeIndices.contains($0.offset) }

        if available.isEmpty {
            usedChallengeIndices.removeAll()
            return pool.randomElement()
        }

        if let selected = available.randomElement() {
            usedChallengeIndices.insert(selected.offset)
            return selected.element
        }

        return nil
    }

    func scoreAnswers(questions: [RecallQuestion], userAnswers: [String]) -> Double {
        guard !questions.isEmpty else { return 0 }

        var correct = 0
        for (i, question) in questions.enumerated() {
            guard i < userAnswers.count else { continue }
            let answer = userAnswers[i].trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
            let expected = question.answer.lowercased()

            if answer == expected || expected.contains(answer) || answer.contains(expected) {
                if !answer.isEmpty {
                    correct += 1
                }
            }
        }

        return Double(correct) / Double(questions.count)
    }
}
