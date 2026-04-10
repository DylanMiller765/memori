#if DEBUG
import Foundation
import SwiftData

/// Generates realistic fake data for App Store screenshots.
/// Only available in DEBUG builds. Accessible from Settings.
enum ScreenshotDataGenerator {

    /// Populate the app with impressive-looking demo data for screenshots.
    @MainActor
    static func generate(modelContext: ModelContext, user: User, gameCenterService: GameCenterService? = nil) {
        // Mark as authenticated for screenshot purposes
        if let gc = gameCenterService {
            gc.isAuthenticated = true
        }
        // 1. Reset existing data
        try? modelContext.delete(model: Exercise.self)
        try? modelContext.delete(model: DailySession.self)
        try? modelContext.delete(model: BrainScoreResult.self)
        try? modelContext.delete(model: Achievement.self)

        // 2. Configure user profile
        user.username = "Dylan"
        user.totalXP = 4_850
        user.level = 12
        user.currentStreak = 18
        user.longestStreak = 18
        user.lastSessionDate = Date()
        user.totalExercises = 94
        user.totalPerfectScores = 7
        user.hasShared = true
        user.dailyGoal = 3
        user.soundEnabled = true
        user.streakFreezes = 2
        user.subscriptionStatusRaw = "subscribed"
        user.hasCompletedOnboarding = true

        // 3. Generate brain score history (5 assessments over past 3 weeks)
        let brainScores: [(daysAgo: Int, score: Int)] = [
            (21, 520), (14, 590), (10, 645), (5, 710), (0, 748)
        ]
        for entry in brainScores {
            let result = BrainScoreResult()
            result.date = Date().daysAgo(entry.daysAgo)
            result.brainScore = entry.score

            let digit = BrainScoring.digitSpanScore(maxDigits: digitSpan(for: entry.score))
            let reaction = BrainScoring.reactionTimeScore(avgMs: reactionMs(for: entry.score))
            let visual = BrainScoring.visualMemoryScore(maxLevel: visualLevel(for: entry.score))

            result.digitSpanScore = digit
            result.reactionTimeScore = reaction
            result.visualMemoryScore = visual
            result.digitSpanMax = digitSpan(for: entry.score)
            result.reactionTimeAvgMs = reactionMs(for: entry.score)
            result.visualMemoryMax = visualLevel(for: entry.score)
            result.brainAge = BrainScoring.brainAge(from: entry.score)
            result.brainType = BrainScoring.determineBrainType(digit: digit, reaction: reaction, visual: visual)
            result.percentile = BrainScoring.percentile(score: entry.score)

            modelContext.insert(result)
        }

        // 4. Generate exercise history (past 21 days, 3-5 exercises/day)
        let exerciseTypes: [(ExerciseType, scoreFn: () -> Double, diffFn: () -> Int, durFn: () -> Int)] = [
            (.reactionTime,     { Double.random(in: 0.65...0.92) }, { 1 }, { Int.random(in: 25...40) }),
            (.colorMatch,       { Double.random(in: 0.70...0.95) }, { Int.random(in: 1...3) }, { Int.random(in: 30...50) }),
            (.speedMatch,       { Double.random(in: 0.68...0.90) }, { Int.random(in: 1...3) }, { Int.random(in: 35...55) }),
            (.visualMemory,     { Double.random(in: 0.55...0.88) }, { Int.random(in: 3...7) }, { Int.random(in: 40...70) }),
            (.sequentialMemory, { Double.random(in: 0.60...0.85) }, { Int.random(in: 5...9) }, { Int.random(in: 30...50) }),
            (.mathSpeed,        { Double.random(in: 0.65...0.90) }, { Int.random(in: 1...3) }, { Int.random(in: 40...60) }),
            (.dualNBack,        { Double.random(in: 0.50...0.80) }, { Int.random(in: 2...4) }, { Int.random(in: 60...120) }),
            (.chunkingTraining, { Double.random(in: 0.55...0.85) }, { Int.random(in: 1...3) }, { Int.random(in: 30...50) }),
        ]

        for daysAgo in 0..<21 {
            // Skip 2-3 random days for realism
            if [3, 8, 16].contains(daysAgo) { continue }

            let session = DailySession()
            session.date = Date().daysAgo(daysAgo)

            let exerciseCount = Int.random(in: 3...5)
            var usedTypes = Set<Int>()

            for _ in 0..<exerciseCount {
                var typeIndex: Int
                repeat {
                    typeIndex = Int.random(in: 0..<exerciseTypes.count)
                } while usedTypes.contains(typeIndex) && usedTypes.count < exerciseTypes.count
                usedTypes.insert(typeIndex)

                let template = exerciseTypes[typeIndex]
                let exercise = Exercise(
                    type: template.0,
                    difficulty: template.diffFn(),
                    score: template.scoreFn(),
                    durationSeconds: template.durFn()
                )
                exercise.completedAt = session.date

                modelContext.insert(exercise)
                session.addExercise(exercise)
            }

            modelContext.insert(session)
        }

        // 5. Set personal bests in PersonalBestTracker
        let bests: [(ExerciseType, Int)] = [
            (.reactionTime, 712),      // inverted: 1000 - 288ms = 712
            (.colorMatch, 92),         // 92%
            (.speedMatch, 88),         // 88%
            (.visualMemory, 7),        // level 7
            (.sequentialMemory, 9),    // 9 digits
            (.mathSpeed, 16),          // 16 correct
            (.dualNBack, 4),           // N=4
            (.chimpTest, 8),           // level 8 (beat the chimp!)
            (.verbalMemory, 42),       // 42 word streak
        ]
        for (type, score) in bests {
            PersonalBestTracker.shared.forceSet(score: score, for: type)
        }

        // 6. Unlock achievements
        let unlockedAchievements: [AchievementType] = [
            .firstExercise, .tenExercises, .fiftyExercises,
            .streak3, .streak7, .streak14,
            .firstPerfect, .fivePerfects,
            .brainScore500, .brainScore700,
            .firstDualNBack, .firstActiveRecall, .firstDailyChallenge,
            .lightningReaction, .firstShare,
            .earlyBird, .weekendWarrior
        ]
        for (i, type) in unlockedAchievements.enumerated() {
            let achievement = Achievement(
                type: type,
                unlockedAt: Date().daysAgo(21 - i)
            )
            achievement.isNew = false
            modelContext.insert(achievement)
        }

        try? modelContext.save()
    }

    // MARK: - Helpers

    private static func digitSpan(for brainScore: Int) -> Int {
        switch brainScore {
        case 700...: return 9
        case 600..<700: return 8
        case 500..<600: return 7
        default: return 6
        }
    }

    private static func reactionMs(for brainScore: Int) -> Int {
        switch brainScore {
        case 700...: return 215
        case 600..<700: return 245
        case 500..<600: return 270
        default: return 310
        }
    }

    private static func visualLevel(for brainScore: Int) -> Int {
        switch brainScore {
        case 700...: return 7
        case 600..<700: return 6
        case 500..<600: return 5
        default: return 4
        }
    }
}
#endif
