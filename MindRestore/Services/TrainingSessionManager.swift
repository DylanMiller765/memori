import Foundation
import SwiftUI

/// Manages daily training session time and exercise recommendations.
///
/// Research basis:
/// - Lampit 2014 meta-analysis: sessions >30 min show diminishing returns; 15-20 min is optimal.
/// - Deci & Ryan 2000 (Self-Determination Theory): autonomy in choosing exercises increases motivation.
@MainActor @Observable
final class TrainingSessionManager {

    // MARK: - Constants

    private static let dailyLimitMinutes: Double = 20
    private static let sweetSpotMinutes: Double = 15
    private static let defaultsPrefix = "trainingSeconds_"

    // MARK: - Properties

    private let defaults = UserDefaults.standard

    var todayTrainingSeconds: Int {
        get { defaults.integer(forKey: Self.todayKey) }
        set { defaults.set(newValue, forKey: Self.todayKey) }
    }

    var todayTrainingMinutes: Double {
        Double(todayTrainingSeconds) / 60.0
    }

    /// True once the user has trained for 20+ minutes today.
    var hasReachedDailyLimit: Bool {
        todayTrainingMinutes >= Self.dailyLimitMinutes
    }

    /// True when the user is in the 15-20 minute sweet-spot window.
    var shouldShowSlowDown: Bool {
        todayTrainingMinutes >= Self.sweetSpotMinutes && !hasReachedDailyLimit
    }

    /// Formatted string like "12 min" for display.
    var formattedTrainingTime: String {
        let minutes = Int(todayTrainingMinutes)
        if minutes < 1 {
            return "\(todayTrainingSeconds)s"
        }
        return "\(minutes) min"
    }

    /// Progress toward the 20-minute daily limit (0.0 – 1.0).
    var dailyProgress: Double {
        min(todayTrainingMinutes / Self.dailyLimitMinutes, 1.0)
    }

    // MARK: - Methods

    func addTrainingTime(_ seconds: Int) {
        todayTrainingSeconds += seconds
    }

    /// Resets today's counter. Typically not needed since date-keyed storage
    /// auto-resets, but useful for testing.
    func resetToday() {
        todayTrainingSeconds = 0
    }

    // MARK: - Focus Goal Recommendations

    /// Returns a prioritized list of exercises based on the user's onboarding focus goals.
    /// When users choose their own exercises (SDT — autonomy), motivation increases.
    func recommendedExercises(for goals: [UserFocusGoal]) -> [ExerciseRecommendation] {
        guard !goals.isEmpty else { return defaultRecommendations() }

        var seen = Set<String>()
        var recommendations: [ExerciseRecommendation] = []

        for goal in goals {
            for rec in exercises(for: goal) {
                if seen.insert(rec.title).inserted {
                    recommendations.append(rec)
                }
            }
        }

        return recommendations
    }

    // MARK: - Private Helpers

    private static var todayKey: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        return defaultsPrefix + formatter.string(from: .now)
    }

    private func exercises(for goal: UserFocusGoal) -> [ExerciseRecommendation] {
        switch goal {
        case .forgetInstantly:
            return [
                ExerciseRecommendation(
                    title: "Visual Memory",
                    subtitle: "Remember and recall tile patterns",
                    icon: "square.grid.3x3.fill",
                    color: AppColors.indigo,
                    destination: .exercise(.visualMemory)
                ),
                ExerciseRecommendation(
                    title: "Number Memory",
                    subtitle: "Strengthen digit recall span",
                    icon: "number.circle.fill",
                    color: AppColors.teal,
                    destination: .exercise(.sequentialMemory)
                ),
                ExerciseRecommendation(
                    title: "Chunking",
                    subtitle: "Group info for better recall",
                    icon: "rectangle.split.3x1.fill",
                    color: AppColors.rose,
                    destination: .exercise(.chunkingTraining)
                ),
            ]

        case .loseFocus:
            return [
                ExerciseRecommendation(
                    title: "Dual N-Back",
                    subtitle: "Builds sustained attention & working memory",
                    icon: "square.grid.3x3",
                    color: AppColors.sky,
                    destination: .dualNBack
                ),
                ExerciseRecommendation(
                    title: "Color Match",
                    subtitle: "Fight distraction with Stroop effect",
                    icon: "paintpalette.fill",
                    color: AppColors.violet,
                    destination: .exercise(.colorMatch)
                ),
                ExerciseRecommendation(
                    title: "Speed Match",
                    subtitle: "Stay focused under time pressure",
                    icon: "bolt.square.fill",
                    color: AppColors.sky,
                    destination: .exercise(.speedMatch)
                ),
            ]

        case .attentionShot:
            return [
                ExerciseRecommendation(
                    title: "Dual N-Back",
                    subtitle: "The gold standard for cognitive training",
                    icon: "square.grid.3x3",
                    color: AppColors.sky,
                    destination: .dualNBack
                ),
                ExerciseRecommendation(
                    title: "Math Speed",
                    subtitle: "Keep mental arithmetic sharp",
                    icon: "multiply.circle.fill",
                    color: AppColors.amber,
                    destination: .exercise(.mathSpeed)
                ),
                ExerciseRecommendation(
                    title: "Visual Memory",
                    subtitle: "Train pattern recognition",
                    icon: "square.grid.3x3.fill",
                    color: AppColors.indigo,
                    destination: .exercise(.visualMemory)
                ),
            ]

        case .getSharper:
            return [
                ExerciseRecommendation(
                    title: "Reaction Time",
                    subtitle: "Test and improve processing speed",
                    icon: "bolt.fill",
                    color: AppColors.coral,
                    destination: .exercise(.reactionTime)
                ),
                ExerciseRecommendation(
                    title: "Dual N-Back",
                    subtitle: "Challenge your working memory",
                    icon: "square.grid.3x3",
                    color: AppColors.sky,
                    destination: .dualNBack
                ),
                ExerciseRecommendation(
                    title: "Color Match",
                    subtitle: "Stroop effect cognitive flexibility",
                    icon: "paintpalette.fill",
                    color: AppColors.violet,
                    destination: .exercise(.colorMatch)
                ),
            ]

        case .screenTimeFrying:
            return [
                ExerciseRecommendation(
                    title: "Dual N-Back",
                    subtitle: "Rebuild attention damaged by scrolling",
                    icon: "square.grid.3x3",
                    color: AppColors.sky,
                    destination: .dualNBack
                ),
                ExerciseRecommendation(
                    title: "Reaction Time",
                    subtitle: "Sharpen sluggish processing speed",
                    icon: "bolt.fill",
                    color: AppColors.coral,
                    destination: .exercise(.reactionTime)
                ),
                ExerciseRecommendation(
                    title: "Speed Match",
                    subtitle: "Train sustained focus under pressure",
                    icon: "bolt.square.fill",
                    color: AppColors.sky,
                    destination: .exercise(.speedMatch)
                ),
            ]
        }
    }

    private func defaultRecommendations() -> [ExerciseRecommendation] {
        [
            ExerciseRecommendation(
                title: "Reaction Time",
                subtitle: "Test your processing speed",
                icon: "bolt.fill",
                color: AppColors.coral,
                destination: .exercise(.reactionTime)
            ),
            ExerciseRecommendation(
                title: "Dual N-Back",
                subtitle: "Train your working memory",
                icon: "square.grid.3x3",
                color: AppColors.sky,
                destination: .dualNBack
            ),
            ExerciseRecommendation(
                title: "Visual Memory",
                subtitle: "Remember tile patterns",
                icon: "square.grid.3x3.fill",
                color: AppColors.indigo,
                destination: .exercise(.visualMemory)
            ),
        ]
    }
}

// MARK: - Supporting Types

struct ExerciseRecommendation: Identifiable {
    let id = UUID()
    let title: String
    let subtitle: String
    let icon: String
    let color: Color
    let destination: ExerciseDestination
}

enum ExerciseDestination {
    case spacedRepetition(CardCategory)
    case dualNBack
    case activeRecall
    case mixedTraining
    case dailyChallenge
    case brainAssessment
    case exercise(ExerciseType)
}
