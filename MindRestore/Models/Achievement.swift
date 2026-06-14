import Foundation
import SwiftData
import SwiftUI

// MARK: - Achievement Category

enum AchievementCategory: String, CaseIterable, Codable {
    case streaks = "Streaks"
    case exercises = "Exercises"
    case scores = "Scores"
    case brainScore = "Brain Score"
    case exerciseTypes = "Exercise Types"
    case speed = "Speed"
    case social = "Social"
    case dedication = "Dedication"
    case mastery = "Mastery"

    var gradient: LinearGradient {
        switch self {
        case .streaks:
            return LinearGradient(
                colors: [AppColors.coral, AppColors.rose],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        case .exercises:
            return LinearGradient(
                colors: [AppColors.accent, AppColors.mint],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        case .scores:
            return LinearGradient(
                colors: [AppColors.violet, AppColors.indigo],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        case .brainScore:
            return LinearGradient(
                colors: [AppColors.indigo, AppColors.sky],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        case .exerciseTypes:
            return LinearGradient(
                colors: [AppColors.teal, AppColors.accent],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        case .speed:
            return LinearGradient(
                colors: [AppColors.sky, AppColors.teal],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        case .social:
            return LinearGradient(
                colors: [AppColors.rose, AppColors.violet],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        case .dedication:
            return LinearGradient(
                colors: [AppColors.coral, AppColors.accent],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        case .mastery:
            return LinearGradient(
                colors: [AppColors.violet, AppColors.rose, AppColors.coral],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        }
    }

    var primaryColor: Color {
        switch self {
        case .streaks: return AppColors.coral
        case .exercises: return AppColors.accent
        case .scores: return AppColors.violet
        case .brainScore: return AppColors.indigo
        case .exerciseTypes: return AppColors.teal
        case .speed: return AppColors.sky
        case .social: return AppColors.rose
        case .dedication: return AppColors.coral
        case .mastery: return AppColors.violet
        }
    }
}

// MARK: - Achievement Type

enum AchievementType: String, CaseIterable, Codable, Identifiable {
    var id: String { rawValue }

    // Streaks
    case streak3
    case streak7
    case streak14
    case streak30
    case streak60
    case streak100

    // Exercises
    case firstExercise
    case tenExercises
    case fiftyExercises
    case hundredExercises
    case twoHundredFiftyExercises

    // Scores
    case firstPerfect
    case fivePerfects
    case tenPerfects

    // Brain Score
    case brainScore500
    case brainScore700
    case brainScore900

    // Exercise Types
    case firstDualNBack

    // Speed
    case lightningReaction

    // Social
    case firstShare

    // Dedication
    case earlyBird
    case nightOwl
    case weekendWarrior

    // Mastery
    case memoryMaster

    // MARK: - Display Name

    var displayName: String {
        switch self {
        // Streaks
        case .streak3: return "Getting Started"
        case .streak7: return "One Week Strong"
        case .streak14: return "Two Week Warrior"
        case .streak30: return "Monthly Master"
        case .streak60: return "Iron Will"
        case .streak100: return "Unstoppable"

        // Exercises
        case .firstExercise: return "First Steps"
        case .tenExercises: return "Warming Up"
        case .fiftyExercises: return "Dedicated Learner"
        case .hundredExercises: return "Century Club"
        case .twoHundredFiftyExercises: return "Exercise Enthusiast"

        // Scores
        case .firstPerfect: return "Perfectionist"
        case .fivePerfects: return "Flawless Five"
        case .tenPerfects: return "Perfect Ten"

        // Brain Score
        case .brainScore500: return "Sharp Mind"
        case .brainScore700: return "Brilliant Brain"
        case .brainScore900: return "Genius Level"

        // Exercise Types
        case .firstDualNBack: return "Dual Threat"

        // Speed
        case .lightningReaction: return "Lightning Reflexes"

        // Social
        case .firstShare: return "Spread the Word"

        // Dedication
        case .earlyBird: return "Early Bird"
        case .nightOwl: return "Night Owl"
        case .weekendWarrior: return "Weekend Warrior"

        // Mastery
        case .memoryMaster: return "Memory Master"
        }
    }

    // MARK: - Description

    var description: String {
        switch self {
        // Streaks
        case .streak3: return "You kept Memo on patrol for 3 days straight. Consistency is key!"
        case .streak7: return "A full week of blocking the noise. Your brain thanks you!"
        case .streak14: return "Two weeks of dedication. You are building powerful habits."
        case .streak30: return "A whole month of daily training. You are truly committed!"
        case .streak60: return "60 days without missing a beat. Your willpower is incredible."
        case .streak100: return "100 days of training! You are an absolute legend."

        // Exercises
        case .firstExercise: return "You completed your very first exercise. The journey begins!"
        case .tenExercises: return "10 exercises completed. You are finding your rhythm."
        case .fiftyExercises: return "50 exercises down. Your dedication is inspiring!"
        case .hundredExercises: return "100 exercises completed. Welcome to the century club!"
        case .twoHundredFiftyExercises: return "250 exercises! Your commitment to cognitive health is outstanding."

        // Scores
        case .firstPerfect: return "You scored a perfect 100% on an exercise. Impressive!"
        case .fivePerfects: return "Five perfect scores achieved. You are on fire!"
        case .tenPerfects: return "Ten perfect scores. Perfection is your habit."

        // Brain Score
        case .brainScore500: return "Your brain score reached 500. A sharp mind indeed!"
        case .brainScore700: return "Brain score of 700! Your cognitive abilities are thriving."
        case .brainScore900: return "Brain score of 900. You have reached genius territory!"

        // Exercise Types
        case .firstDualNBack: return "You took on the dual n-back challenge for the first time."

        // Speed
        case .lightningReaction: return "Sub-200ms average reaction time. Your reflexes are superhuman!"

        // Social
        case .firstShare: return "You shared your progress with others. Inspire the world!"

        // Dedication
        case .earlyBird: return "You trained before 7 AM. The early bird sharpens the mind!"
        case .nightOwl: return "Late-night training after 10 PM. Burning the midnight oil!"
        case .weekendWarrior: return "You trained every day of the week. No days off!"

        // Mastery
        case .memoryMaster: return "Scored 95%+ on five exercises. Your memory is exceptional."
        }
    }

    // MARK: - Icon (SF Symbols)

    var icon: String {
        switch self {
        // Streaks
        case .streak3: return "flame"
        case .streak7: return "flame.fill"
        case .streak14: return "flame.circle"
        case .streak30: return "flame.circle.fill"
        case .streak60: return "bolt.heart.fill"
        case .streak100: return "trophy.fill"

        // Exercises
        case .firstExercise: return "star"
        case .tenExercises: return "star.fill"
        case .fiftyExercises: return "star.circle"
        case .hundredExercises: return "star.circle.fill"
        case .twoHundredFiftyExercises: return "sparkles"

        // Scores
        case .firstPerfect: return "checkmark.seal"
        case .fivePerfects: return "checkmark.seal.fill"
        case .tenPerfects: return "crown"

        // Brain Score
        case .brainScore500: return "brain"
        case .brainScore700: return "brain.head.profile"
        case .brainScore900: return "brain.fill"

        // Exercise Types
        case .firstDualNBack: return "square.grid.2x2"

        // Speed
        case .lightningReaction: return "bolt.fill"

        // Social
        case .firstShare: return "square.and.arrow.up.fill"

        // Dedication
        case .earlyBird: return "sunrise.fill"
        case .nightOwl: return "moon.stars.fill"
        case .weekendWarrior: return "figure.strengthtraining.traditional"

        // Mastery
        case .memoryMaster: return "medal.fill"
        }
    }

    // MARK: - Color

    var color: Color {
        return category.primaryColor
    }

    // MARK: - Category

    var category: AchievementCategory {
        switch self {
        case .streak3, .streak7, .streak14, .streak30, .streak60, .streak100:
            return .streaks
        case .firstExercise, .tenExercises, .fiftyExercises, .hundredExercises, .twoHundredFiftyExercises:
            return .exercises
        case .firstPerfect, .fivePerfects, .tenPerfects:
            return .scores
        case .brainScore500, .brainScore700, .brainScore900:
            return .brainScore
        case .firstDualNBack:
            return .exerciseTypes
        case .lightningReaction:
            return .speed
        case .firstShare:
            return .social
        case .earlyBird, .nightOwl, .weekendWarrior:
            return .dedication
        case .memoryMaster:
            return .mastery
        }
    }

    // MARK: - Requirement Description

    var requirementDescription: String {
        switch self {
        // Streaks
        case .streak3: return "Maintain a 3-day training streak"
        case .streak7: return "Maintain a 7-day training streak"
        case .streak14: return "Maintain a 14-day training streak"
        case .streak30: return "Maintain a 30-day training streak"
        case .streak60: return "Maintain a 60-day training streak"
        case .streak100: return "Maintain a 100-day training streak"

        // Exercises
        case .firstExercise: return "Complete your first exercise"
        case .tenExercises: return "Complete 10 exercises"
        case .fiftyExercises: return "Complete 50 exercises"
        case .hundredExercises: return "Complete 100 exercises"
        case .twoHundredFiftyExercises: return "Complete 250 exercises"

        // Scores
        case .firstPerfect: return "Score 100% on any exercise"
        case .fivePerfects: return "Score 100% on 5 exercises"
        case .tenPerfects: return "Score 100% on 10 exercises"

        // Brain Score
        case .brainScore500: return "Reach a brain score of 500"
        case .brainScore700: return "Reach a brain score of 700"
        case .brainScore900: return "Reach a brain score of 900"

        // Exercise Types
        case .firstDualNBack: return "Complete a dual n-back exercise"

        // Speed
        case .lightningReaction: return "Achieve sub-200ms average reaction time"

        // Social
        case .firstShare: return "Share your progress with someone"

        // Dedication
        case .earlyBird: return "Complete a training session before 7 AM"
        case .nightOwl: return "Complete a training session after 10 PM"
        case .weekendWarrior: return "Train every day for a full week (Mon-Sun)"

        // Mastery
        case .memoryMaster: return "Score 95%+ on 5 different exercises"
        }
    }

    // MARK: - Progress Target

    var targetValue: Int {
        switch self {
        case .streak3: return 3
        case .streak7: return 7
        case .streak14: return 14
        case .streak30: return 30
        case .streak60: return 60
        case .streak100: return 100
        case .firstExercise: return 1
        case .tenExercises: return 10
        case .fiftyExercises: return 50
        case .hundredExercises: return 100
        case .twoHundredFiftyExercises: return 250
        case .firstPerfect: return 1
        case .fivePerfects: return 5
        case .tenPerfects: return 10
        case .brainScore500: return 500
        case .brainScore700: return 700
        case .brainScore900: return 900
        case .firstDualNBack: return 1
        case .lightningReaction: return 1
        case .firstShare: return 1
        case .earlyBird, .nightOwl, .weekendWarrior: return 1
        case .memoryMaster: return 5
        }
    }

    func currentProgress(user: User?) -> Int {
        guard let user else { return 0 }
        switch self {
        case .streak3, .streak7, .streak14, .streak30, .streak60, .streak100:
            return user.currentStreak
        case .firstExercise, .tenExercises, .fiftyExercises, .hundredExercises, .twoHundredFiftyExercises:
            return user.totalExercises
        case .firstPerfect, .fivePerfects, .tenPerfects:
            return user.totalPerfectScores
        case .brainScore500, .brainScore700, .brainScore900:
            return 0 // Brain score tracked elsewhere
        case .firstShare:
            return user.hasShared ? 1 : 0
        default:
            return 0
        }
    }

    var progressLabel: String {
        switch self {
        case .streak3, .streak7, .streak14, .streak30, .streak60, .streak100:
            return "streak days"
        case .firstExercise, .tenExercises, .fiftyExercises, .hundredExercises, .twoHundredFiftyExercises:
            return "exercises"
        case .firstPerfect, .fivePerfects, .tenPerfects:
            return "perfect scores"
        case .brainScore500, .brainScore700, .brainScore900:
            return "brain score"
        default:
            return "completed"
        }
    }

    // MARK: - Gradient

    var gradient: LinearGradient {
        return category.gradient
    }

    var gradientColors: [Color] {
        switch category {
        case .streaks: return [AppColors.coral, AppColors.rose]
        case .exercises: return [AppColors.accent, AppColors.mint]
        case .scores: return [AppColors.violet, AppColors.indigo]
        case .brainScore: return [AppColors.indigo, AppColors.sky]
        case .exerciseTypes: return [AppColors.teal, AppColors.accent]
        case .speed: return [AppColors.sky, AppColors.teal]
        case .social: return [AppColors.rose, AppColors.violet]
        case .dedication: return [AppColors.coral, AppColors.accent]
        case .mastery: return [AppColors.violet, AppColors.rose]
        }
    }
}

// MARK: - Achievement Model

@Model
final class Achievement {
    var id: UUID
    var typeRaw: String
    var unlockedAt: Date
    var isNew: Bool

    init(type: AchievementType, unlockedAt: Date = .now) {
        self.id = UUID()
        self.typeRaw = type.rawValue
        self.unlockedAt = unlockedAt
        self.isNew = true
    }

    var type: AchievementType? {
        AchievementType(rawValue: typeRaw)
    }

    var displayName: String {
        type?.displayName ?? "Unknown Achievement"
    }

    var description: String {
        type?.description ?? ""
    }

    var icon: String {
        type?.icon ?? "questionmark.circle"
    }

    var color: Color {
        type?.color ?? .gray
    }

    var category: AchievementCategory {
        type?.category ?? .exercises
    }

    var gradient: LinearGradient {
        type?.gradient ?? LinearGradient(colors: [.gray, .secondary], startPoint: .topLeading, endPoint: .bottomTrailing)
    }

    var requirementDescription: String {
        type?.requirementDescription ?? ""
    }

    /// Mark achievement as seen so the toast is not shown again.
    func markAsSeen() {
        isNew = false
    }
}
