import Foundation
import UIKit

@MainActor @Observable
final class DualNBackViewModel {
    let engine = DualNBackEngine()
    var isPlaying = false
    var showResults = false
    var startTime = Date()
    var isDual = true
    private var trialTimer: Timer?
    var wrongPositionNBack: Int? = nil
    var wrongLetterNBack: String? = nil

    var currentN: Int { engine.currentN }
    var trialIndex: Int { engine.trialIndex }
    var totalTrials: Int { engine.totalTrials }
    var currentPosition: Int { engine.currentPosition }
    var currentLetter: String { engine.currentLetter }
    var positionScore: Double { engine.positionScore }
    var soundScore: Double { engine.soundScore }
    var overallScore: Double { engine.overallScore }
    var isComplete: Bool { engine.isComplete }

    func startGame(n: Int, dual: Bool) {
        isDual = dual
        engine.startGame(n: n, isDual: dual)
        isPlaying = true
        showResults = false
        startTime = Date.now
        scheduleNextTrial()
    }

    private func scheduleNextTrial() {
        trialTimer?.invalidate()

        trialTimer = Timer.scheduledTimer(withTimeInterval: Constants.Exercise.dualNBackTrialInterval, repeats: false) { [weak self] _ in
            Task { @MainActor in
                self?.advanceTrial()
            }
        }
    }

    private func advanceTrial() {
        engine.advanceToNextTrial()

        if engine.isComplete {
            trialTimer?.invalidate()
            isPlaying = false
            showResults = true
        } else {
            scheduleNextTrial()
        }
    }

    func tapPosition() {
        let prevHits = engine.positionHits
        engine.respondPosition()
        if engine.positionHits > prevHits {
            HapticService.correct()
            wrongPositionNBack = nil
        } else {
            HapticService.wrong()
            wrongPositionNBack = engine.nBackPosition()
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) { [weak self] in
                self?.wrongPositionNBack = nil
            }
        }
    }

    func tapSound() {
        let prevHits = engine.soundHits
        engine.respondSound()
        if engine.soundHits > prevHits {
            HapticService.correct()
            wrongLetterNBack = nil
        } else {
            HapticService.wrong()
            wrongLetterNBack = engine.nBackLetter()
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) { [weak self] in
                self?.wrongLetterNBack = nil
            }
        }
    }

    func stop() {
        trialTimer?.invalidate()
        engine.endGame()
        isPlaying = false
        showResults = true
    }

    func cleanup() {
        trialTimer?.invalidate()
        trialTimer = nil
    }

    var nextN: Int {
        engine.adaptDifficulty()
    }

    var durationSeconds: Int {
        Int(Date.now.timeIntervalSince(startTime))
    }

}
