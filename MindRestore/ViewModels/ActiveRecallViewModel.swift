import Foundation

@Observable
final class ActiveRecallViewModel {
    let engine = ActiveRecallEngine()
    var currentChallenge: ActiveRecallChallenge?
    var phase: ChallengePhase = .reading
    var userAnswers: [String] = []
    var score: Double = 0
    var isComplete = false
    var startTime = Date()
    var timeRemaining: TimeInterval = 0
    private var displayTimer: Timer?

    enum ChallengePhase {
        case reading, answering, results
    }

    func startChallenge(type: ChallengeType? = nil) {
        currentChallenge = engine.getChallenge(from: ActiveRecallContent.challenges, type: type)
        guard let challenge = currentChallenge else { return }

        phase = .reading
        userAnswers = Array(repeating: "", count: challenge.questions.count)
        isComplete = false
        startTime = Date()
        timeRemaining = challenge.displayDuration

        startDisplayTimer()
    }

    private func startDisplayTimer() {
        displayTimer?.invalidate()
        displayTimer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { [weak self] _ in
            Task { @MainActor in
                guard let self else { return }
                self.timeRemaining -= 1
                if self.timeRemaining <= 0 {
                    self.displayTimer?.invalidate()
                    self.phase = .answering
                }
            }
        }
    }

    func submitAnswers() {
        guard let challenge = currentChallenge else { return }
        score = engine.scoreAnswers(questions: challenge.questions, userAnswers: userAnswers)
        phase = .results
        isComplete = true
    }

    func skipToAnswering() {
        displayTimer?.invalidate()
        phase = .answering
    }

    var durationSeconds: Int {
        Int(Date().timeIntervalSince(startTime))
    }
}
