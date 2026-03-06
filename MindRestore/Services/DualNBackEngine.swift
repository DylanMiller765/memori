import Foundation

@Observable
final class DualNBackEngine {
    var currentN: Int = 1
    var positions: [Int] = []
    var letters: [String] = []
    var trialIndex: Int = 0
    var totalTrials: Int = 0
    var isRunning: Bool = false
    var isComplete: Bool = false

    var positionHits: Int = 0
    var positionMisses: Int = 0
    var positionFalseAlarms: Int = 0
    var soundHits: Int = 0
    var soundMisses: Int = 0
    var soundFalseAlarms: Int = 0

    var currentPosition: Int = -1
    var currentLetter: String = ""

    private var positionMatches: Set<Int> = []
    private var soundMatches: Set<Int> = []
    private var userPositionResponses: Set<Int> = []
    private var userSoundResponses: Set<Int> = []

    private let availableLetters = ["C", "H", "K", "L", "Q", "R", "S", "T"]

    var positionScore: Double {
        let total = positionMatches.count
        guard total > 0 else { return 0 }
        return max(0, Double(positionHits - positionFalseAlarms) / Double(total))
    }

    var soundScore: Double {
        let total = soundMatches.count
        guard total > 0 else { return 0 }
        return max(0, Double(soundHits - soundFalseAlarms) / Double(total))
    }

    var isDual: Bool = false

    var overallScore: Double {
        isDual ? (positionScore + soundScore) / 2.0 : positionScore
    }

    func startGame(n: Int, isDual dual: Bool) {
        currentN = n
        isDual = dual
        totalTrials = 20 + n
        trialIndex = 0
        isRunning = true
        isComplete = false

        positions = []
        letters = []
        positionMatches = []
        soundMatches = []
        userPositionResponses = []
        userSoundResponses = []
        positionHits = 0
        positionMisses = 0
        positionFalseAlarms = 0
        soundHits = 0
        soundMisses = 0
        soundFalseAlarms = 0

        generateSequence(isDual: dual)
        presentTrial()
    }

    private func generateSequence(isDual: Bool) {
        for i in 0..<totalTrials {
            if i >= currentN && Double.random(in: 0...1) < 0.3 {
                positions.append(positions[i - currentN])
                positionMatches.insert(i)
            } else {
                positions.append(Int.random(in: 0...8))
            }

            if isDual {
                if i >= currentN && Double.random(in: 0...1) < 0.3 {
                    letters.append(letters[i - currentN])
                    soundMatches.insert(i)
                } else {
                    letters.append(availableLetters.randomElement()!)
                }
            } else {
                letters.append("")
            }
        }
    }

    func presentTrial() {
        guard trialIndex < totalTrials else {
            endGame()
            return
        }
        currentPosition = positions[trialIndex]
        currentLetter = letters[trialIndex]
    }

    func advanceToNextTrial() {
        if trialIndex >= currentN {
            if positionMatches.contains(trialIndex) && !userPositionResponses.contains(trialIndex) {
                positionMisses += 1
            }
            if soundMatches.contains(trialIndex) && !userSoundResponses.contains(trialIndex) {
                soundMisses += 1
            }
        }

        trialIndex += 1

        if trialIndex >= totalTrials {
            endGame()
        } else {
            presentTrial()
        }
    }

    func respondPosition() {
        guard trialIndex >= currentN else { return }
        userPositionResponses.insert(trialIndex)

        if positionMatches.contains(trialIndex) {
            positionHits += 1
        } else {
            positionFalseAlarms += 1
        }
    }

    func respondSound() {
        guard trialIndex >= currentN else { return }
        userSoundResponses.insert(trialIndex)

        if soundMatches.contains(trialIndex) {
            soundHits += 1
        } else {
            soundFalseAlarms += 1
        }
    }

    func endGame() {
        isRunning = false
        isComplete = true
    }

    func adaptDifficulty() -> Int {
        if positionScore > 0.8 && soundScore > 0.8 {
            return min(currentN + 1, 5)
        } else if positionScore < 0.5 || soundScore < 0.5 {
            return max(currentN - 1, 1)
        }
        return currentN
    }
}
