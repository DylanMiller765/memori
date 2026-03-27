import Foundation
import UIKit

enum DailyChallengeType: Int, CaseIterable {
    case speedNumbers = 0
    case speedWords = 1
    case speedPattern = 2
    case faceNamePairs = 3

    var displayName: String {
        switch self {
        case .speedNumbers: return "Speed Numbers"
        case .speedWords: return "Speed Words"
        case .speedPattern: return "Speed Pattern"
        case .faceNamePairs: return "Face-Name Pairs"
        }
    }

    var icon: String {
        switch self {
        case .speedNumbers: return "number.circle.fill"
        case .speedWords: return "textformat.abc"
        case .speedPattern: return "square.grid.3x3.fill"
        case .faceNamePairs: return "person.text.rectangle.fill"
        }
    }

    var instruction: String {
        switch self {
        case .speedNumbers: return "Memorize the numbers, then type them back"
        case .speedWords: return "Memorize the words, then type as many as you can"
        case .speedPattern: return "Memorize the pattern, then recreate it"
        case .faceNamePairs: return "Memorize the face-name pairs, then recall the names"
        }
    }
}

enum DailyChallengePhase {
    case preview
    case countdown
    case memorize
    case recall
    case results
}

@MainActor @Observable
final class DailyChallengeViewModel {
    var phase: DailyChallengePhase = .preview
    var challengeType: DailyChallengeType = .speedNumbers
    var countdownValue: Int = 3
    var timeRemaining: Double = 10
    var recallTimeRemaining: Double = 30

    // Content
    var numbers: [Int] = []
    var words: [String] = []
    var patternCells: Set<Int> = []
    var selectedCells: Set<Int> = []
    var textInput: String = ""

    // Face-Name content
    var faceNamePairs: [(name: String, description: String)] = []
    var faceNameInputs: [String] = []

    // Results
    var score: Int = 0
    var percentile: Int = 50
    var isCorrect: Bool = false
    var correctAnswer: String = ""
    var userAnswer: String = ""
    var correctCells: Set<Int> = []

    private var timer: Timer?
    let gridSize = 4

    private static let faceNamePool: [(name: String, description: String)] = [
        ("Margaret", "curly red hair, librarian"),
        ("James", "tall, mechanic, loves jazz"),
        ("Sofia", "baker, bright smile"),
        ("David", "professor, round glasses"),
        ("Elena", "architect, plays violin"),
        ("Marcus", "firefighter, mustache"),
        ("Ling", "software engineer, Portland"),
        ("Amara", "nurse, collects stamps"),
        ("Roberto", "chef, booming laugh"),
        ("Priya", "teacher, runs marathons"),
        ("Thomas", "pilot, silver watch"),
        ("Yuki", "artist, paints landscapes"),
        ("Carlos", "dentist, loves gardening"),
        ("Olivia", "journalist, freckles"),
        ("Raj", "accountant, plays chess"),
        ("Hannah", "vet, rescues animals")
    ]

    func setup() {
        let dayOfYear = Calendar.current.ordinality(of: .day, in: .year, for: .now) ?? 0
        let typeIndex = dayOfYear % DailyChallengeType.allCases.count
        challengeType = DailyChallengeType(rawValue: typeIndex) ?? .speedNumbers

        var rng = SeededGenerator(seed: UInt64(dayOfYear * 31 + 2024))

        switch challengeType {
        case .speedNumbers:
            numbers = (0..<8).map { _ in Int.random(in: 0...9, using: &rng) }
        case .speedWords:
            let pool = ["apple", "river", "clock", "mountain", "paper", "bridge", "candle",
                        "forest", "guitar", "shadow", "ocean", "pencil", "rabbit", "sunset",
                        "violin", "chair", "diamond", "eagle", "flame", "garden", "hammer",
                        "island", "jacket", "kettle", "lantern", "mirror", "olive", "piano",
                        "rocket", "tunnel", "anchor", "basket", "compass", "dragon", "emerald"]
            words = Array(pool.shuffled(using: &rng).prefix(8))
        case .speedPattern:
            let total = gridSize * gridSize
            let indices = Array(0..<total).shuffled(using: &rng)
            patternCells = Set(indices.prefix(6))
        case .faceNamePairs:
            let shuffled = Self.faceNamePool.shuffled(using: &rng)
            faceNamePairs = Array(shuffled.prefix(4))
            faceNameInputs = Array(repeating: "", count: faceNamePairs.count)
        }
    }

    func startCountdown() {
        phase = .countdown
        countdownValue = 3
        timer?.invalidate()
        timer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            Task { @MainActor in
                guard let self else { return }
                self.countdownValue -= 1
                UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                if self.countdownValue <= 0 {
                    self.timer?.invalidate()
                    self.startMemorize()
                }
            }
        }
    }

    private func startMemorize() {
        phase = .memorize
        timeRemaining = 10
        timer?.invalidate()
        timer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { [weak self] _ in
            Task { @MainActor in
                guard let self else { return }
                self.timeRemaining -= 0.1
                if self.timeRemaining <= 0 {
                    self.timer?.invalidate()
                    self.startRecall()
                }
            }
        }
    }

    private func startRecall() {
        phase = .recall
        textInput = ""
        selectedCells = []
        recallTimeRemaining = 30
        timer?.invalidate()
        timer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { [weak self] _ in
            Task { @MainActor in
                guard let self else { return }
                self.recallTimeRemaining -= 0.1
                if self.recallTimeRemaining <= 0 {
                    self.timer?.invalidate()
                    self.submit()
                }
            }
        }
    }

    func togglePatternCell(_ index: Int) {
        if selectedCells.contains(index) {
            selectedCells.remove(index)
        } else {
            selectedCells.insert(index)
            UIImpactFeedbackGenerator(style: .light).impactOccurred()
        }
    }

    func submit() {
        timer?.invalidate()

        switch challengeType {
        case .speedNumbers:
            let correct = numbers.map(String.init).joined()
            let input = textInput.filter(\.isNumber)
            var matched = 0
            for (a, b) in zip(correct, input) where a == b { matched += 1 }
            score = Int(Double(matched) / Double(numbers.count) * 1000)
            isCorrect = input == correct
            correctAnswer = numbers.map(String.init).joined(separator: " ")
            userAnswer = Array(input).map(String.init).joined(separator: " ")

        case .speedWords:
            let inputWords = textInput
                .lowercased()
                .components(separatedBy: CharacterSet.alphanumerics.inverted)
                .filter { !$0.isEmpty }
            let targetWords = Set(words.map { $0.lowercased() })
            let matched = inputWords.filter { targetWords.contains($0) }.count
            score = Int(Double(matched) / Double(words.count) * 1000)
            isCorrect = matched == words.count
            correctAnswer = words.joined(separator: ", ")
            userAnswer = inputWords.joined(separator: ", ")

        case .speedPattern:
            let correct = selectedCells == patternCells
            let intersection = selectedCells.intersection(patternCells).count
            score = Int(Double(intersection) / Double(patternCells.count) * 1000)
            isCorrect = correct
            correctCells = patternCells

        case .faceNamePairs:
            var matched = 0
            for (i, pair) in faceNamePairs.enumerated() {
                let input = i < faceNameInputs.count ? faceNameInputs[i].trimmingCharacters(in: .whitespacesAndNewlines).lowercased() : ""
                if input == pair.name.lowercased() {
                    matched += 1
                }
            }
            score = Int(Double(matched) / Double(faceNamePairs.count) * 1000)
            isCorrect = matched == faceNamePairs.count
            correctAnswer = faceNamePairs.map(\.name).joined(separator: ", ")
            userAnswer = faceNameInputs.map { $0.isEmpty ? "(blank)" : $0 }.joined(separator: ", ")
        }

        percentile = estimatePercentile(score: score)
        phase = .results
    }

    private func estimatePercentile(score: Int) -> Int {
        let z = (Double(score) - 550.0) / 200.0
        let absZ = abs(z)
        let t = 1.0 / (1.0 + 0.2316419 * absZ)
        let d = 0.3989422804014327 * exp(-z * z / 2.0)
        let p = d * t * (0.3193815 + t * (-0.3565638 + t * (1.781478 + t * (-1.8212560 + t * 1.330274))))
        let cdf = z > 0 ? 1.0 - p : p
        return max(1, min(99, Int(cdf * 100)))
    }

    var displayContent: String {
        switch challengeType {
        case .speedNumbers:
            return numbers.map(String.init).joined(separator: "  ")
        case .speedWords:
            return words.joined(separator: "  ·  ")
        case .speedPattern, .faceNamePairs:
            return ""
        }
    }
}

