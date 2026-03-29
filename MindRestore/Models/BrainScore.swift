import Foundation
import SwiftData

// MARK: - Brain Type

enum BrainType: String, Codable, CaseIterable {
    case lightningReflex
    case numberCruncher
    case patternMaster
    case balancedBrain

    var displayName: String {
        switch self {
        case .lightningReflex: return "Lightning Reflex"
        case .numberCruncher: return "Number Cruncher"
        case .patternMaster: return "Pattern Master"
        case .balancedBrain: return "Balanced Brain"
        }
    }

    var icon: String {
        switch self {
        case .lightningReflex: return "bolt.fill"
        case .numberCruncher: return "number.circle.fill"
        case .patternMaster: return "square.grid.3x3.fill"
        case .balancedBrain: return "brain.head.profile.fill"
        }
    }

    var description: String {
        switch self {
        case .lightningReflex: return "Your reaction speed is elite. You process visual information faster than most."
        case .numberCruncher: return "You excel at holding numbers in memory. Your digit span is impressive."
        case .patternMaster: return "You have exceptional visual-spatial memory. Patterns are your superpower."
        case .balancedBrain: return "Your cognitive abilities are well-rounded across all areas."
        }
    }

    var color: String {
        switch self {
        case .lightningReflex: return "yellow"
        case .numberCruncher: return "blue"
        case .patternMaster: return "purple"
        case .balancedBrain: return "green"
        }
    }
}

// MARK: - Brain Score Source

enum BrainScoreSource: String, Codable {
    case assessment
    case workout
}

// MARK: - Brain Score Result

@Model
final class BrainScoreResult {
    var id: UUID = UUID()
    var date: Date = Date()
    var brainScore: Int = 0
    var brainAge: Int = 25
    var brainTypeRaw: String = BrainType.balancedBrain.rawValue
    var digitSpanScore: Double = 0
    var reactionTimeScore: Double = 0
    var visualMemoryScore: Double = 0
    var digitSpanMax: Int = 0
    var reactionTimeAvgMs: Int = 0
    var visualMemoryMax: Int = 0
    var percentile: Int = 50
    var sourceRaw: String = BrainScoreSource.assessment.rawValue

    var source: BrainScoreSource {
        get { BrainScoreSource(rawValue: sourceRaw) ?? .assessment }
        set { sourceRaw = newValue.rawValue }
    }

    init() {}

    var brainType: BrainType {
        get { BrainType(rawValue: brainTypeRaw) ?? .balancedBrain }
        set { brainTypeRaw = newValue.rawValue }
    }
}

// MARK: - Scoring Utilities
//
// Based on cognitive science norms:
// - Digit span: Average adult forward span is 7 +/- 2 (Miller's Law)
//   4 digits = below average, 7 = average, 9+ = exceptional
// - Reaction time: Average simple RT is ~250ms for young adults
//   150ms = exceptional, 250ms = average, 400ms+ = slow
// - Visual memory: Average pattern recall ~4-5 cells on 4x4 grid
//   3 = below average, 5 = average, 8 = exceptional

enum BrainScoring {

    /// Digit span score (0-100) using sigmoid curve centered on 7 digits
    static func digitSpanScore(maxDigits: Int) -> Double {
        // Sigmoid: maps 3->5, 5->25, 7->50, 9->85, 10->95
        let x = Double(maxDigits)
        let score = 100.0 / (1.0 + exp(-1.2 * (x - 7.0)))
        return min(100, max(0, score))
    }

    /// Reaction time score (0-100) using inverse sigmoid
    /// Lower ms = higher score
    static func reactionTimeScore(avgMs: Int) -> Double {
        // 150ms -> ~95, 200ms -> ~80, 250ms -> ~55, 300ms -> ~30, 400ms -> ~5
        let x = Double(avgMs)
        let score = 100.0 / (1.0 + exp(0.025 * (x - 260.0)))
        return min(100, max(0, score))
    }

    /// Visual memory score (0-100) using sigmoid curve centered on 5 cells
    static func visualMemoryScore(maxLevel: Int) -> Double {
        // 3->15, 4->30, 5->50, 6->70, 7->85, 8->93
        let x = Double(maxLevel)
        let score = 100.0 / (1.0 + exp(-1.4 * (x - 5.0)))
        return min(100, max(0, score))
    }

    /// Composite brain score (0-1000)
    /// Weighted: digit span 35%, reaction time 30%, visual memory 35%
    static func compositeBrainScore(digit: Double, reaction: Double, visual: Double) -> Int {
        let weighted = digit * 0.35 + reaction * 0.30 + visual * 0.35
        return min(1000, max(0, Int(weighted * 10)))
    }

    /// Brain age estimation using logarithmic curve
    /// Score 1000 -> age 18, score 500 -> age 32, score 0 -> age 75
    static func brainAge(from score: Int) -> Int {
        let s = Double(score) / 1000.0
        // Logarithmic mapping — sharper at high scores, gradual at low
        let age = 75.0 - 57.0 * pow(s, 0.7)
        return max(18, min(75, Int(age)))
    }

    /// Determine dominant brain type based on score distribution
    static func determineBrainType(digit: Double, reaction: Double, visual: Double) -> BrainType {
        let scores = [digit, reaction, visual]
        let avg = scores.reduce(0, +) / 3.0
        let maxScore = scores.max() ?? 0
        let minScore = scores.min() ?? 0

        // Need meaningful separation — at least 20% above average
        let spread = maxScore - avg
        if spread < 10 || (maxScore - minScore) < 15 {
            return .balancedBrain
        }

        if reaction == maxScore && reaction - avg >= 10 { return .lightningReflex }
        if digit == maxScore && digit - avg >= 10 { return .numberCruncher }
        if visual == maxScore && visual - avg >= 10 { return .patternMaster }
        return .balancedBrain
    }

    /// Percentile estimation using normal CDF approximation
    /// Centered on 500 with SD of 180 for realistic distribution
    static func percentile(score: Int) -> Int {
        let z = (Double(score) - 480.0) / 180.0
        let cdf = normalCDF(z)
        return max(1, min(99, Int(cdf * 100)))
    }

    private static func normalCDF(_ z: Double) -> Double {
        let absZ = abs(z)
        let t = 1.0 / (1.0 + 0.2316419 * absZ)
        let d = 0.3989422804014327 * exp(-z * z / 2.0)
        let p = d * t * (0.3193815 + t * (-0.3565638 + t * (1.781478 + t * (-1.8212560 + t * 1.330274))))
        return z > 0 ? 1.0 - p : p
    }

    /// Calculate domain score (0-100) from an exercise result
    static func domainScore(for exerciseType: ExerciseType, gameScore: Int, score: Double) -> (domain: String, score: Double)? {
        switch exerciseType {
        // Memory domain — maps to digitSpanScore
        case .sequentialMemory:
            // gameScore = maxCorrectLength (digit span)
            return ("memory", digitSpanScore(maxDigits: gameScore))
        case .chunkingTraining:
            // gameScore = correctDigits, approximate as digit span
            return ("memory", digitSpanScore(maxDigits: max(1, gameScore / 3)))

        // Speed domain — maps to reactionTimeScore
        case .reactionTime:
            // gameScore = averageMs
            return ("speed", reactionTimeScore(avgMs: gameScore))
        case .colorMatch, .speedMatch:
            // composite score: accuracy% * 1000 + timeBonus. Extract accuracy as speed proxy
            let accuracy = Double(gameScore / 1000)
            return ("speed", accuracy)
        case .mathSpeed:
            // composite: correct * 1000 + speedBonus. Map correct/20 to 0-100
            let correct = Double(gameScore / 1000)
            return ("speed", correct * 5.0) // 20/20 = 100

        // Visual domain — maps to visualMemoryScore
        case .visualMemory:
            // gameScore = maxLevelReached
            return ("visual", visualMemoryScore(maxLevel: gameScore))
        case .dualNBack:
            // gameScore = currentN level. Map N to visual memory equivalent
            // N=1 ~ level 3, N=2 ~ level 5, N=3 ~ level 7, N=4 ~ level 9
            return ("visual", visualMemoryScore(maxLevel: gameScore * 2 + 1))

        default:
            return nil
        }
    }
}

// MARK: - Brain Score Decay

/// Applies daily Brain Score decay when user hasn't played.
/// - Grace period: 48 hours (no decay)
/// - Decay rate: 10 points/day
/// - Floor: 50% of peak score
enum BrainScoreDecayService {
    private static let decayPerDay = 10
    private static let floorPercentage = 0.50
    private static let gracePeriodHours = 48

    @discardableResult
    static func applyDecayIfNeeded(modelContext: ModelContext) -> Int {
        var descriptor = FetchDescriptor<BrainScoreResult>(sortBy: [SortDescriptor(\BrainScoreResult.date, order: .reverse)])
        descriptor.fetchLimit = 1
        guard let latest = (try? modelContext.fetch(descriptor))?.first else { return 0 }

        // Get last exercise date
        var exerciseDescriptor = FetchDescriptor<Exercise>(sortBy: [SortDescriptor(\Exercise.completedAt, order: .reverse)])
        exerciseDescriptor.fetchLimit = 1
        let lastExercise = (try? modelContext.fetch(exerciseDescriptor))?.first
        let lastPlayedDate = lastExercise?.completedAt ?? latest.date

        let hoursSincePlay = Calendar.current.dateComponents([.hour], from: lastPlayedDate, to: Date()).hour ?? 0
        guard hoursSincePlay >= gracePeriodHours else { return 0 }

        // Only decay once per day
        let lastDecayKey = "lastDecayDate"
        let today = Calendar.current.startOfDay(for: Date())
        if let lastDecay = UserDefaults.standard.object(forKey: lastDecayKey) as? Date,
           Calendar.current.isDate(lastDecay, inSameDayAs: today) {
            return 0
        }

        let decayHours = hoursSincePlay - gracePeriodHours
        let decayDays = max(1, decayHours / 24)

        // Find peak score
        var peakDescriptor = FetchDescriptor<BrainScoreResult>(sortBy: [SortDescriptor(\BrainScoreResult.brainScore, order: .reverse)])
        peakDescriptor.fetchLimit = 1
        let peakScore = (try? modelContext.fetch(peakDescriptor))?.first?.brainScore ?? latest.brainScore

        let floor = Int(Double(peakScore) * floorPercentage)
        let totalDecay = min(decayDays * decayPerDay, latest.brainScore - floor)
        guard totalDecay > 0 else { return 0 }

        let decayedScore = max(floor, latest.brainScore - totalDecay)
        let ratio = latest.brainScore > 0 ? Double(decayedScore) / Double(latest.brainScore) : 1.0

        let result = BrainScoreResult()
        result.date = Date()
        result.brainScore = decayedScore
        result.brainAge = BrainScoring.brainAge(from: decayedScore)
        result.digitSpanScore = latest.digitSpanScore * ratio
        result.reactionTimeScore = latest.reactionTimeScore * ratio
        result.visualMemoryScore = latest.visualMemoryScore * ratio
        result.digitSpanMax = latest.digitSpanMax
        result.reactionTimeAvgMs = latest.reactionTimeAvgMs
        result.visualMemoryMax = latest.visualMemoryMax
        result.percentile = BrainScoring.percentile(score: decayedScore)
        result.brainType = BrainScoring.determineBrainType(
            digit: latest.digitSpanScore * ratio,
            reaction: latest.reactionTimeScore * ratio,
            visual: latest.visualMemoryScore * ratio
        )
        result.source = .workout

        modelContext.insert(result)
        try? modelContext.save()

        UserDefaults.standard.set(today, forKey: lastDecayKey)
        return latest.brainScore - decayedScore
    }
}
