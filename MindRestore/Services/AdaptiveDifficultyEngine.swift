//
//  AdaptiveDifficultyEngine.swift
//  MindRestore
//
//  Adaptive difficulty system based on Wilson et al. 2019 ("The 85% Rule")
//  and Guadagnoli & Lee 2004 (Challenge Point Framework).
//  Optimal learning occurs at ~85% accuracy — the engine keeps users in that zone.
//

import Foundation
import SwiftUI

// MARK: - Exercise Domain

enum ExerciseDomain: String, CaseIterable, Codable {
    case digits
    case words
    case faces
    case locations
    case patterns
    case nBack
    case activeRecall
    case dailyChallenge
    case visualMemory
    case mathSpeed
    case colorMatch
    case speedMatch
    case sequentialMemory
    case wordScramble
    case memoryChain
}

// MARK: - Difficulty Parameters

struct DifficultyParameters {
    // Digits
    let digitCount: Int

    // Words
    let wordCount: Int

    // Faces
    let faceNamePairCount: Int

    // Locations
    let locationCount: Int

    // Patterns
    let gridSize: Int
    let cellCount: Int

    // N-Back
    let nBackLevel: Int

    // Active Recall
    let readingTimeSeconds: Double
    let detailCount: Int

    // Daily Challenge
    let memorizeTimeSeconds: Double
    let itemCount: Int
}

// MARK: - Difficulty Adjustment

enum DifficultyAdjustment {
    case increase
    case maintain
    case decrease

    var description: String {
        switch self {
        case .increase: return "Increasing difficulty — you're crushing it"
        case .maintain: return "Right in the sweet spot"
        case .decrease: return "Dialing it back to build confidence"
        }
    }
}

// MARK: - Adaptive Difficulty Engine

@MainActor @Observable
final class AdaptiveDifficultyEngine {

    // MARK: - Singleton

    static let shared = AdaptiveDifficultyEngine()

    // MARK: - Published State

    private(set) var difficultyLevels: [ExerciseDomain: Int] = [:]
    private(set) var lastAdjustment: [ExerciseDomain: DifficultyAdjustment] = [:]

    // MARK: - Accuracy Tracking

    /// Rolling window of recent attempts per domain (correct = true, incorrect = false)
    private var attemptHistory: [ExerciseDomain: [Bool]] = [:]

    /// Number of attempts that constitute a "block" for difficulty adjustment
    private let blockSize: Int = 10

    // MARK: - Difficulty Ranges

    private let difficultyRanges: [ExerciseDomain: ClosedRange<Int>] = [
        .digits:         1...12,
        .words:          1...10,
        .faces:          1...7,
        .locations:      1...8,
        .patterns:       1...10,
        .nBack:          1...7,
        .activeRecall:   1...10,
        .dailyChallenge: 1...10,
        .visualMemory:   1...10,
        .mathSpeed:      1...5,
        .colorMatch:     1...8,
        .speedMatch:     1...8,
        .sequentialMemory: 1...10,
        .wordScramble:   1...10,
        .memoryChain:    1...10
    ]

    /// Starting difficulty for each domain (maps to level 1 in the range)
    private let defaultLevels: [ExerciseDomain: Int] = [
        .digits:         2,   // 4 digits
        .words:          3,   // 5 words
        .faces:          2,   // 3 pairs
        .locations:      2,   // 4 locations
        .patterns:       1,   // 3x3 / 3 cells
        .nBack:          1,   // N=1
        .activeRecall:   1,   // 30s / 4 details
        .dailyChallenge: 1,
        .visualMemory:   1,   // grid level 1
        .mathSpeed:      2,   // start at medium
        .colorMatch:     1,   // round count/speed scaling
        .speedMatch:     1,   // round count/speed scaling
        .sequentialMemory: 1, // starts at 4 digits
        .wordScramble:     1, // starting difficulty
        .memoryChain:      1  // starting sequence length
    ]

    // MARK: - Threshold Constants (Wilson et al. 2019 — 85% Rule)

    private let increaseThreshold: Double = 0.90
    private let sweetSpotLow: Double = 0.75
    private let sweetSpotHigh: Double = 0.85
    private let decreaseThreshold: Double = 0.70

    // MARK: - UserDefaults Keys

    private let defaultsPrefix = "adaptiveDifficulty_"

    // MARK: - Init

    private init() {
        loadAllLevels()
        for domain in ExerciseDomain.allCases {
            if attemptHistory[domain] == nil {
                attemptHistory[domain] = []
            }
        }
    }

    // MARK: - Public API

    /// Record a single attempt result for a domain.
    func recordAttempt(domain: ExerciseDomain, correct: Bool) {
        attemptHistory[domain, default: []].append(correct)

        // Trim history to last 50 attempts max
        if let count = attemptHistory[domain]?.count, count > 50 {
            if let history = attemptHistory[domain] {
                attemptHistory[domain] = Array(history.suffix(50))
            }
        }

        // Check if we have a full block to evaluate
        if let history = attemptHistory[domain], history.count >= blockSize {
            evaluateAndAdjust(domain: domain)
        }
    }

    /// Record a batch of attempt results at once (e.g., after completing an exercise round).
    func recordBlock(domain: ExerciseDomain, correct: Int, total: Int) {
        guard total > 0 else { return }

        for i in 0..<total {
            attemptHistory[domain, default: []].append(i < correct)
        }

        // Trim history
        if let count = attemptHistory[domain]?.count, count > 50 {
            if let history = attemptHistory[domain] {
                attemptHistory[domain] = Array(history.suffix(50))
            }
        }

        evaluateAndAdjust(domain: domain)
    }

    /// Get the current difficulty level (raw integer) for a domain.
    func currentLevel(for domain: ExerciseDomain) -> Int {
        difficultyLevels[domain] ?? defaultLevels[domain] ?? 1
    }

    /// Get the concrete parameters for the current difficulty of a domain.
    func parameters(for domain: ExerciseDomain) -> DifficultyParameters {
        let level = currentLevel(for: domain)
        return buildParameters(level: level)
    }

    /// Get display/memorize time in seconds for a domain at its current difficulty.
    /// Shorter time = harder. Returns time in seconds.
    func displayTime(for domain: ExerciseDomain) -> TimeInterval {
        return displayTime(for: domain, difficulty: currentLevel(for: domain))
    }

    /// Get display/memorize time for a specific difficulty level.
    func displayTime(for domain: ExerciseDomain, difficulty: Int) -> TimeInterval {
        switch domain {
        case .digits:
            // Base 3s, +0.8s per digit count, -0.15s per difficulty level
            let digitCount = 3 + difficulty
            let baseTime = Double(digitCount) * 0.8
            let adjusted = max(baseTime * (1.0 - Double(difficulty) * 0.03), Double(digitCount) * 0.35)
            return adjusted

        case .words:
            // Base 2s per word, scales down with difficulty
            let wordCount = 2 + difficulty
            let perWordTime = max(2.0 - Double(difficulty) * 0.1, 0.8)
            return Double(wordCount) * perWordTime

        case .faces:
            // 4s per face-name pair, decreasing with difficulty
            let pairCount = 1 + difficulty
            let perPairTime = max(4.0 - Double(difficulty) * 0.25, 2.0)
            return Double(pairCount) * perPairTime

        case .locations:
            // 3s per location, scales down
            let locCount = 2 + difficulty
            let perLocTime = max(3.0 - Double(difficulty) * 0.15, 1.5)
            return Double(locCount) * perLocTime

        case .patterns:
            // Grid display time: starts at 4s, decreases
            let cellCount = 2 + difficulty
            let baseTime = max(4.0 - Double(difficulty) * 0.2, 1.5)
            return baseTime + Double(cellCount) * 0.3

        case .nBack:
            // Stimulus display time: shorter = harder
            return max(3.0 - Double(difficulty) * 0.25, 1.0)

        case .activeRecall:
            // Reading time decreases with difficulty
            return max(30.0 - Double(difficulty) * 2.5, 8.0)

        case .dailyChallenge:
            // Memorize time per item
            let itemCount = 3 + difficulty
            let perItemTime = max(3.0 - Double(difficulty) * 0.15, 1.2)
            return Double(itemCount) * perItemTime

        case .visualMemory:
            // Grid show time: decreases with difficulty
            return max(2.0 - Double(difficulty) * 0.12, 0.6)

        case .mathSpeed:
            // Time per problem: decreases with difficulty
            return max(10.0 - Double(difficulty) * 1.0, 4.0)

        case .colorMatch:
            // Time limit: decreases with difficulty
            return max(4.0 - Double(difficulty) * 0.3, 1.2)

        case .speedMatch:
            // Time limit: decreases with difficulty
            return max(4.0 - Double(difficulty) * 0.3, 1.2)

        case .sequentialMemory:
            // Per-digit show time: decreases with difficulty
            return max(1.0 - Double(difficulty) * 0.04, 0.5)

        case .wordScramble:
            // Time per word: decreases with difficulty
            return max(30.0 - Double(difficulty) * 2.0, 10.0)

        case .memoryChain:
            // Sequence display time: decreases with difficulty
            return max(1.5 - Double(difficulty) * 0.08, 0.5)
        }
    }

    /// Get the recent accuracy for a domain (0.0 - 1.0), or nil if insufficient data.
    func recentAccuracy(for domain: ExerciseDomain) -> Double? {
        guard let history = attemptHistory[domain], history.count >= 3 else {
            return nil
        }
        let recent = history.suffix(blockSize)
        let correctCount = recent.filter { $0 }.count
        return Double(correctCount) / Double(recent.count)
    }

    /// Manually set the difficulty level for a domain (e.g., from settings).
    func setLevel(_ level: Int, for domain: ExerciseDomain) {
        let range = difficultyRanges[domain] ?? 1...10
        let clamped = min(max(level, range.lowerBound), range.upperBound)
        difficultyLevels[domain] = clamped
        persistLevel(domain: domain, level: clamped)
    }

    /// Reset a specific domain to its default difficulty.
    func resetDomain(_ domain: ExerciseDomain) {
        let defaultLevel = defaultLevels[domain] ?? 1
        difficultyLevels[domain] = defaultLevel
        attemptHistory[domain] = []
        lastAdjustment[domain] = nil
        persistLevel(domain: domain, level: defaultLevel)
    }

    /// Reset all domains to defaults.
    func resetAll() {
        for domain in ExerciseDomain.allCases {
            resetDomain(domain)
        }
    }

    // MARK: - Private Methods

    private func evaluateAndAdjust(domain: ExerciseDomain) {
        guard let history = attemptHistory[domain], history.count >= blockSize else { return }

        let recentBlock = Array(history.suffix(blockSize))
        let correctCount = recentBlock.filter { $0 }.count
        let accuracy = Double(correctCount) / Double(recentBlock.count)

        let currentLvl = currentLevel(for: domain)
        let range = difficultyRanges[domain] ?? 1...10
        var newLevel = currentLvl

        if accuracy > increaseThreshold && currentLvl < range.upperBound {
            newLevel = currentLvl + 1
            lastAdjustment[domain] = .increase
        } else if accuracy >= sweetSpotLow && accuracy <= sweetSpotHigh {
            lastAdjustment[domain] = .maintain
        } else if accuracy < decreaseThreshold && currentLvl > range.lowerBound {
            newLevel = currentLvl - 1
            lastAdjustment[domain] = .decrease
        } else {
            // Between 85-90% or 70-75% — slight adjustments not needed, maintain
            lastAdjustment[domain] = .maintain
        }

        if newLevel != currentLvl {
            difficultyLevels[domain] = newLevel
            persistLevel(domain: domain, level: newLevel)
        }

        // Clear the evaluated block so we don't re-evaluate immediately
        attemptHistory[domain] = []
    }

    private func buildParameters(level: Int) -> DifficultyParameters {
        // Digits: start 4, range 3-15 (also used by sequentialMemory for starting digit length = 3 + level)
        // Visual Memory: reuses gridSize/cellCount for grid levels
        // Math Speed: reuses level directly (1=easy, 2=easy, 3=medium, 4=hard, 5=hard)
        // Color Match / Speed Match: reuses level for round count and speed scaling
        // Sequential Memory: reuses digitCount for starting digit length
        let digitCount = min(3 + level, 15)

        // Words: start 5, range 3-12
        let wordCount = min(2 + level, 12)

        // Faces: start 3, range 2-8
        let faceNamePairCount = min(1 + level, 8)

        // Locations: start 4, range 3-10
        let locationCount = min(2 + level, 10)

        // Patterns: start 3x3/3cells, scale to 6x6/12cells
        let gridSize = min(2 + (level / 3), 6)        // 3, 3, 3, 4, 4, 4, 5, 5, 5, 6, 6
        let cellCount = min(2 + level, 12)

        // N-Back: start 1, range 1-7
        let nBackLevel = min(max(level, 1), 7)

        // Active Recall: start 30s/4 details, scale down time and up details
        let readingTime = max(30.0 - Double(level - 1) * 2.5, 8.0)
        let detailCount = min(3 + level, 12)

        // Daily Challenge
        let memorizeTime = max(25.0 - Double(level - 1) * 2.0, 8.0)
        let itemCount = min(3 + level, 15)

        return DifficultyParameters(
            digitCount: digitCount,
            wordCount: wordCount,
            faceNamePairCount: faceNamePairCount,
            locationCount: locationCount,
            gridSize: gridSize,
            cellCount: cellCount,
            nBackLevel: nBackLevel,
            readingTimeSeconds: readingTime,
            detailCount: detailCount,
            memorizeTimeSeconds: memorizeTime,
            itemCount: itemCount
        )
    }

    // MARK: - Persistence

    private func persistLevel(domain: ExerciseDomain, level: Int) {
        UserDefaults.standard.set(level, forKey: defaultsPrefix + domain.rawValue)
    }

    private func loadAllLevels() {
        for domain in ExerciseDomain.allCases {
            let key = defaultsPrefix + domain.rawValue
            let stored = UserDefaults.standard.integer(forKey: key)
            if stored > 0 {
                difficultyLevels[domain] = stored
            } else {
                difficultyLevels[domain] = defaultLevels[domain] ?? 1
            }
        }
    }
}

// MARK: - Personal Best Tracker

@MainActor @Observable
final class PersonalBestTracker {
    static let shared = PersonalBestTracker()

    private let defaults = UserDefaults.standard
    private let prefix = "personalBest_"

    private init() {
        migrateCompositeScores()
    }

    /// One-time migration: composite leaderboard scores → primary scores for PB display.
    private func migrateCompositeScores() {
        let migrationKey = "personalBest_migrated_v2"
        guard !defaults.bool(forKey: migrationKey) else { return }

        // Math Speed, Color Match, Speed Match stored composite (primary * 1000 + timeBonus)
        // Convert back to primary score
        for type in [ExerciseType.mathSpeed, .colorMatch, .speedMatch] {
            let stored = best(for: type)
            if stored > 999 {
                let primary = stored / 1000
                defaults.set(primary, forKey: prefix + type.rawValue)
            }
        }
        defaults.set(true, forKey: migrationKey)
    }

    /// Get the personal best score for an exercise type.
    func best(for type: ExerciseType) -> Int {
        defaults.integer(forKey: prefix + type.rawValue)
    }

    /// Record a score, returns true if it's a new personal best.
    @discardableResult
    func record(score: Int, for type: ExerciseType) -> Bool {
        let current = best(for: type)
        if score > current {
            defaults.set(score, forKey: prefix + type.rawValue)
            return true
        }
        return false
    }

    /// Force-set a score (used by screenshot data generator).
    func forceSet(score: Int, for type: ExerciseType) {
        defaults.set(score, forKey: prefix + type.rawValue)
    }

    /// Reset all personal bests.
    func resetAll() {
        for type in ExerciseType.allCases {
            defaults.removeObject(forKey: prefix + type.rawValue)
        }
    }
}
