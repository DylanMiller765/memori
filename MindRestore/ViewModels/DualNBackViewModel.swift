import Foundation
import AVFoundation
import UIKit

@Observable
final class DualNBackViewModel {
    let engine = DualNBackEngine()
    var isPlaying = false
    var showResults = false
    var startTime = Date()
    var isDual = true
    private var trialTimer: Timer?
    private var synthesizer = AVSpeechSynthesizer()

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
        startTime = Date()
        scheduleNextTrial()
    }

    private func scheduleNextTrial() {
        trialTimer?.invalidate()

        if isDual && !currentLetter.isEmpty {
            speakLetter(currentLetter)
        }

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
        engine.respondPosition()
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
    }

    func tapSound() {
        engine.respondSound()
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
    }

    func stop() {
        trialTimer?.invalidate()
        engine.endGame()
        isPlaying = false
        showResults = true
    }

    var nextN: Int {
        engine.adaptDifficulty()
    }

    var durationSeconds: Int {
        Int(Date().timeIntervalSince(startTime))
    }

    private func speakLetter(_ letter: String) {
        let utterance = AVSpeechUtterance(string: letter)
        utterance.rate = 0.5
        utterance.volume = 0.8
        synthesizer.speak(utterance)
    }
}
