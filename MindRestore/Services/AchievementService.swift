import Foundation
import SwiftData

@MainActor @Observable
final class AchievementService {

    var newlyUnlocked: [AchievementType] = []

    // MARK: - Public API

    func checkAchievements(context: ModelContext, user: User) {
        let unlockedSet = fetchUnlockedSet(context: context)
        let exercises = fetchAllExercises(context: context)
        let brainScores = fetchBrainScores(context: context)

        var toUnlock: [AchievementType] = []

        // Streak achievements
        let streak = max(user.currentStreak, user.longestStreak)
        let streakMilestones: [(Int, AchievementType)] = [
            (3, .streak3), (7, .streak7), (14, .streak14),
            (30, .streak30), (60, .streak60), (100, .streak100)
        ]
        for (threshold, type) in streakMilestones {
            if streak >= threshold && !unlockedSet.contains(type) {
                toUnlock.append(type)
            }
        }

        // Exercise count achievements
        let totalExercises = exercises.count
        let countMilestones: [(Int, AchievementType)] = [
            (1, .firstExercise), (10, .tenExercises), (50, .fiftyExercises),
            (100, .hundredExercises), (250, .twoHundredFiftyExercises)
        ]
        for (threshold, type) in countMilestones {
            if totalExercises >= threshold && !unlockedSet.contains(type) {
                toUnlock.append(type)
            }
        }

        // Perfect score achievements (score >= 0.95)
        let perfectCount = exercises.filter { $0.score >= 0.95 }.count
        let perfectMilestones: [(Int, AchievementType)] = [
            (1, .firstPerfect), (5, .fivePerfects), (10, .tenPerfects)
        ]
        for (threshold, type) in perfectMilestones {
            if perfectCount >= threshold && !unlockedSet.contains(type) {
                toUnlock.append(type)
            }
        }

        // Brain score achievements
        if let bestScore = brainScores.map(\.brainScore).max() {
            let brainMilestones: [(Int, AchievementType)] = [
                (500, .brainScore500), (700, .brainScore700), (900, .brainScore900)
            ]
            for (threshold, type) in brainMilestones {
                if bestScore >= threshold && !unlockedSet.contains(type) {
                    toUnlock.append(type)
                }
            }
        }

        // First exercise type completion (Dual N-Back is the only "first type" achievement still active)
        let exerciseTypes = Set(exercises.map { $0.type })
        if exerciseTypes.contains(.dualNBack) && !unlockedSet.contains(.firstDualNBack) {
            toUnlock.append(.firstDualNBack)
        }

        // Lightning reaction — under 200ms average
        if !unlockedSet.contains(.lightningReaction) {
            let hasLightning = brainScores.contains { $0.reactionTimeAvgMs > 0 && $0.reactionTimeAvgMs < 200 }
            if hasLightning {
                toUnlock.append(.lightningReaction)
            }
        }

        // Time-based achievements
        let calendar = Calendar.current
        if !unlockedSet.contains(.earlyBird) {
            let hasEarly = exercises.contains { exercise in
                let hour = calendar.component(.hour, from: exercise.completedAt)
                return hour < 7
            }
            if hasEarly {
                toUnlock.append(.earlyBird)
            }
        }

        if !unlockedSet.contains(.nightOwl) {
            let hasLate = exercises.contains { exercise in
                let hour = calendar.component(.hour, from: exercise.completedAt)
                return hour >= 22
            }
            if hasLate {
                toUnlock.append(.nightOwl)
            }
        }

        // Weekend warrior — exercises on both Saturday and Sunday
        if !unlockedSet.contains(.weekendWarrior) {
            var hasSaturday = false
            var hasSunday = false
            for exercise in exercises {
                let weekday = calendar.component(.weekday, from: exercise.completedAt)
                if weekday == 7 { hasSaturday = true }
                if weekday == 1 { hasSunday = true }
                if hasSaturday && hasSunday { break }
            }
            if hasSaturday && hasSunday {
                toUnlock.append(.weekendWarrior)
            }
        }

        // Memory master — 95%+ score on 5 or more exercises
        if !unlockedSet.contains(.memoryMaster) {
            let highScoreCount = exercises.filter { $0.score >= 0.95 }.count
            if highScoreCount >= 5 {
                toUnlock.append(.memoryMaster)
            }
        }

        // Persist newly unlocked achievements
        for type in toUnlock {
            let achievement = Achievement(type: type)
            context.insert(achievement)
        }

        if !toUnlock.isEmpty {
            try? context.save()
            newlyUnlocked.append(contentsOf: toUnlock)
            for type in toUnlock {
                Analytics.achievementUnlocked(achievement: type.rawValue)
            }
        }

        // Schedule nudge for achievements user is close to unlocking
        scheduleNearUnlockNudges(
            unlockedSet: unlockedSet.union(Set(toUnlock)),
            user: user,
            exercises: exercises,
            brainScores: brainScores
        )
    }

    func unlockShareAchievement(context: ModelContext) {
        let unlockedSet = fetchUnlockedSet(context: context)
        guard !unlockedSet.contains(.firstShare) else { return }

        let achievement = Achievement(type: .firstShare)
        context.insert(achievement)
        try? context.save()
        newlyUnlocked.append(.firstShare)
        Analytics.achievementUnlocked(achievement: AchievementType.firstShare.rawValue)
    }

    func dismissAchievement(_ type: AchievementType) {
        newlyUnlocked.removeAll { $0 == type }
    }

    func markSeen(context: ModelContext) {
        let descriptor = FetchDescriptor<Achievement>(
            predicate: #Predicate<Achievement> { $0.isNew == true }
        )
        guard let achievements = try? context.fetch(descriptor) else { return }
        for achievement in achievements {
            achievement.isNew = false
        }
        try? context.save()
    }

    // MARK: - Achievement Nudge Notifications

    private func scheduleNearUnlockNudges(
        unlockedSet: Set<AchievementType>,
        user: User,
        exercises: [Exercise],
        brainScores: [BrainScoreResult]
    ) {
        let streak = max(user.currentStreak, user.longestStreak)
        let totalExercises = exercises.count
        let perfectCount = exercises.filter { $0.score >= 0.95 }.count

        // Check streak milestones
        let streakTargets: [(Int, AchievementType)] = [
            (7, .streak7), (14, .streak14), (30, .streak30)
        ]
        for (target, type) in streakTargets {
            let remaining = target - streak
            if remaining > 0 && remaining <= 3 && !unlockedSet.contains(type) {
                NotificationService.shared.scheduleAchievementNudge(
                    achievementName: type.displayName,
                    progress: "\(remaining) more day\(remaining == 1 ? "" : "s")"
                )
                return
            }
        }

        // Check exercise count milestones
        let countTargets: [(Int, AchievementType)] = [
            (10, .tenExercises), (50, .fiftyExercises), (100, .hundredExercises)
        ]
        for (target, type) in countTargets {
            let remaining = target - totalExercises
            if remaining > 0 && remaining <= 3 && !unlockedSet.contains(type) {
                NotificationService.shared.scheduleAchievementNudge(
                    achievementName: type.displayName,
                    progress: "\(remaining) more exercise\(remaining == 1 ? "" : "s")"
                )
                return
            }
        }

        // Check perfect score milestones
        let perfectTargets: [(Int, AchievementType)] = [
            (5, .fivePerfects), (10, .tenPerfects)
        ]
        for (target, type) in perfectTargets {
            let remaining = target - perfectCount
            if remaining > 0 && remaining <= 2 && !unlockedSet.contains(type) {
                NotificationService.shared.scheduleAchievementNudge(
                    achievementName: type.displayName,
                    progress: "\(remaining) more perfect score\(remaining == 1 ? "" : "s")"
                )
                return
            }
        }
    }

    // MARK: - Private Helpers

    private func fetchUnlockedSet(context: ModelContext) -> Set<AchievementType> {
        let descriptor = FetchDescriptor<Achievement>()
        guard let achievements = try? context.fetch(descriptor) else { return [] }
        return Set(achievements.compactMap { AchievementType(rawValue: $0.typeRaw) })
    }

    private func fetchAllExercises(context: ModelContext) -> [Exercise] {
        let descriptor = FetchDescriptor<Exercise>()
        return (try? context.fetch(descriptor)) ?? []
    }

    private func fetchBrainScores(context: ModelContext) -> [BrainScoreResult] {
        let descriptor = FetchDescriptor<BrainScoreResult>()
        return (try? context.fetch(descriptor)) ?? []
    }
}
