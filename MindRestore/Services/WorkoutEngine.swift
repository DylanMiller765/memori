//
//  WorkoutEngine.swift
//  MindRestore
//
//  Smart Daily Workout engine: picks 3 games based on domain weakness,
//  user goals, and variety. Computes rolling Brain Score from workout results.
//

import Foundation
import SwiftUI

// MARK: - Cognitive Domain

enum WorkoutDomain: String, CaseIterable, Codable {
    case memory   // 35% weight — Sequential Memory, Chunking, Dual N-Back
    case speed    // 30% weight — Reaction Time, Color Match, Speed Match
    case visual   // 35% weight — Visual Memory

    var weight: Double {
        switch self {
        case .memory: return 0.35
        case .speed:  return 0.30
        case .visual: return 0.35
        }
    }

    var color: Color {
        switch self {
        case .memory: return AppColors.violet
        case .speed:  return AppColors.coral
        case .visual: return AppColors.sky
        }
    }

    var displayName: String {
        switch self {
        case .memory: return "Memory"
        case .speed:  return "Speed"
        case .visual: return "Visual"
        }
    }

    var exerciseTypes: [ExerciseType] {
        switch self {
        case .memory: return [.sequentialMemory, .chunkingTraining, .dualNBack]
        case .speed:  return [.reactionTime, .colorMatch, .speedMatch]
        case .visual: return [.visualMemory]
        }
    }

    var difficultyDomains: [ExerciseDomain] {
        switch self {
        case .memory: return [.sequentialMemory, .nBack]
        case .speed:  return [.colorMatch, .speedMatch]
        case .visual: return [.visualMemory]
        }
    }

    /// Map an ExerciseType back to its WorkoutDomain, if any.
    static func domain(for type: ExerciseType) -> WorkoutDomain? {
        for domain in WorkoutDomain.allCases {
            if domain.exerciseTypes.contains(type) {
                return domain
            }
        }
        return nil
    }
}

// MARK: - Workout Game

struct WorkoutGame: Codable, Identifiable {
    let id: UUID
    let exerciseTypeRaw: String
    let domainRaw: String
    let reasonTag: String
    var score: Double?
    var completed: Bool

    init(exerciseType: ExerciseType, domain: WorkoutDomain, reasonTag: String) {
        self.id = UUID()
        self.exerciseTypeRaw = exerciseType.rawValue
        self.domainRaw = domain.rawValue
        self.reasonTag = reasonTag
        self.score = nil
        self.completed = false
    }

    var exerciseType: ExerciseType {
        ExerciseType(rawValue: exerciseTypeRaw) ?? .reactionTime
    }

    var domain: WorkoutDomain {
        WorkoutDomain(rawValue: domainRaw) ?? .speed
    }
}

// MARK: - Daily Workout

struct DailyWorkout: Codable {
    let dateString: String
    var games: [WorkoutGame]

    var isComplete: Bool {
        games.allSatisfy { $0.completed }
    }

    var completedCount: Int {
        games.filter { $0.completed }.count
    }

    var nextGame: WorkoutGame? {
        games.first { !$0.completed }
    }

    static func todayDateString() -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter.string(from: Date())
    }
}

// MARK: - Workout Engine

@MainActor @Observable
final class WorkoutEngine {

    // MARK: - Published State

    private(set) var todaysWorkout: DailyWorkout?

    // MARK: - UserDefaults Keys

    private let workoutKey = "workoutEngine_todaysWorkout"
    private let yesterdayGamesKey = "workoutEngine_yesterdayGames"

    // MARK: - Init

    init() {
        loadWorkout()
    }

    // MARK: - Generate Workout

    /// Generate today's 3-game workout based on recent performance and user goals.
    /// - Parameters:
    ///   - exercises: Recent Exercise records from SwiftData (ideally last 7-14 days)
    ///   - userGoals: The user's selected focus goals from onboarding
    func generateWorkout(exercises: [Exercise], userGoals: [UserFocusGoal]) {
        let today = DailyWorkout.todayDateString()

        // If we already have today's workout, don't regenerate
        if let existing = todaysWorkout, existing.dateString == today {
            return
        }

        // Archive yesterday's games for anti-repetition
        archiveYesterdayIfNeeded()

        let domainScores = calculateDomainPerformance(from: exercises)
        let rankedDomains = rankDomainsByWeakness(domainScores)
        let yesterdayTypes = loadYesterdayGameTypes()

        var selectedGames: [WorkoutGame] = []
        var usedTypes: Set<String> = []

        // Game 1: Weakest domain ("Needs work")
        if let game = pickGame(
            from: rankedDomains[0],
            excluding: usedTypes,
            yesterdayTypes: yesterdayTypes,
            reasonTag: "Needs work"
        ) {
            selectedGames.append(game)
            usedTypes.insert(game.exerciseTypeRaw)
        }

        // Game 2: Second-weakest or goal-aligned ("Build up" / "Your goal")
        let game2Domain = rankedDomains.count > 1 ? rankedDomains[1] : rankedDomains[0]
        let goalAlignedDomain = goalDomain(for: userGoals)
        let useGoal = goalAlignedDomain != nil && goalAlignedDomain != rankedDomains[0]

        if useGoal, let goalDom = goalAlignedDomain {
            if let game = pickGame(
                from: goalDom,
                excluding: usedTypes,
                yesterdayTypes: yesterdayTypes,
                reasonTag: "Your goal"
            ) {
                selectedGames.append(game)
                usedTypes.insert(game.exerciseTypeRaw)
            } else if let game = pickGame(
                from: game2Domain,
                excluding: usedTypes,
                yesterdayTypes: yesterdayTypes,
                reasonTag: "Build up"
            ) {
                selectedGames.append(game)
                usedTypes.insert(game.exerciseTypeRaw)
            }
        } else {
            if let game = pickGame(
                from: game2Domain,
                excluding: usedTypes,
                yesterdayTypes: yesterdayTypes,
                reasonTag: "Build up"
            ) {
                selectedGames.append(game)
                usedTypes.insert(game.exerciseTypeRaw)
            }
        }

        // Game 3: Variety from remaining domains ("Mix it up")
        let remainingDomains = WorkoutDomain.allCases.filter { dom in
            !selectedGames.contains { $0.domain == dom }
        }
        let game3Domain = remainingDomains.first ?? rankedDomains.last ?? .visual
        if let game = pickGame(
            from: game3Domain,
            excluding: usedTypes,
            yesterdayTypes: yesterdayTypes,
            reasonTag: "Mix it up"
        ) {
            selectedGames.append(game)
            usedTypes.insert(game.exerciseTypeRaw)
        }

        // Fallback: if we couldn't fill 3 games, use defaults
        if selectedGames.count < 3 {
            selectedGames = newUserFallback()
        }

        let workout = DailyWorkout(dateString: today, games: selectedGames)
        todaysWorkout = workout
        persistWorkout(workout)
    }

    // MARK: - Record Completion

    /// Mark a game as completed with its score.
    /// - Returns: `true` if all 3 games are now complete.
    @discardableResult
    func recordGameCompletion(exerciseType: ExerciseType, score: Double) -> Bool {
        guard var workout = todaysWorkout else { return false }

        if let index = workout.games.firstIndex(where: {
            $0.exerciseTypeRaw == exerciseType.rawValue && !$0.completed
        }) {
            workout.games[index].score = score
            workout.games[index].completed = true
            todaysWorkout = workout
            persistWorkout(workout)
        }

        return workout.isComplete
    }

    // MARK: - Rolling Brain Score

    struct RollingScoreResult {
        let brainScore: Int
        let brainAge: Int
        let percentile: Int
        let brainType: BrainType
        let digitSpanScore: Double
        let reactionTimeScore: Double
        let visualMemoryScore: Double
    }

    /// Compute an updated Brain Score by blending old scores with today's workout.
    /// - 80% old domain scores + 20% today's workout scores per domain
    /// - Missing domains carry forward from old score
    /// - Guardrails: max +50, max -30 per day
    func computeRollingBrainScore(
        oldScore: BrainScoreResult?,
        workoutGames: [WorkoutGame]
    ) -> RollingScoreResult {
        // Old domain scores (0-100 scale)
        let oldDigit = oldScore?.digitSpanScore ?? 50.0
        let oldReaction = oldScore?.reactionTimeScore ?? 50.0
        let oldVisual = oldScore?.visualMemoryScore ?? 50.0

        // Compute today's domain scores from workout games (score is 0-1, map to 0-100)
        var todayDigit: Double?
        var todayReaction: Double?
        var todayVisual: Double?

        for game in workoutGames where game.completed {
            guard let gameScore = game.score else { continue }
            let scaled = gameScore * 100.0

            switch game.domain {
            case .memory:
                todayDigit = scaled
            case .speed:
                todayReaction = scaled
            case .visual:
                todayVisual = scaled
            }
        }

        // Blend: 80% old + 20% today, or carry forward if no today data
        let blendedDigit = blend(old: oldDigit, today: todayDigit)
        let blendedReaction = blend(old: oldReaction, today: todayReaction)
        let blendedVisual = blend(old: oldVisual, today: todayVisual)

        // Compute composite
        var newScore = BrainScoring.compositeBrainScore(
            digit: blendedDigit,
            reaction: blendedReaction,
            visual: blendedVisual
        )

        // Guardrails: max +50, max -30 per day
        if let old = oldScore {
            let delta = newScore - old.brainScore
            if delta > 50 {
                newScore = old.brainScore + 50
            } else if delta < -30 {
                newScore = old.brainScore - 30
            }
        }

        let age = BrainScoring.brainAge(from: newScore)
        let pct = BrainScoring.percentile(score: newScore)
        let brainType = BrainScoring.determineBrainType(
            digit: blendedDigit,
            reaction: blendedReaction,
            visual: blendedVisual
        )

        return RollingScoreResult(
            brainScore: newScore,
            brainAge: age,
            percentile: pct,
            brainType: brainType,
            digitSpanScore: blendedDigit,
            reactionTimeScore: blendedReaction,
            visualMemoryScore: blendedVisual
        )
    }

    // MARK: - Private: Domain Performance

    /// Calculate performance per WorkoutDomain from recent exercises + adaptive accuracy.
    /// Returns a dictionary of domain -> performance score (0.0 - 1.0), where lower is worse.
    private func calculateDomainPerformance(from exercises: [Exercise]) -> [WorkoutDomain: Double] {
        let sevenDaysAgo = Calendar.current.date(byAdding: .day, value: -7, to: Date()) ?? Date()
        let recentExercises = exercises.filter { $0.completedAt >= sevenDaysAgo }

        var domainScores: [WorkoutDomain: Double] = [:]

        for domain in WorkoutDomain.allCases {
            var scores: [Double] = []

            // Gather exercise scores for this domain
            let relevantExercises = recentExercises.filter { exercise in
                domain.exerciseTypes.contains(exercise.type)
            }
            scores.append(contentsOf: relevantExercises.map { $0.score })

            // Also incorporate AdaptiveDifficultyEngine accuracy
            for diffDomain in domain.difficultyDomains {
                if let accuracy = AdaptiveDifficultyEngine.shared.recentAccuracy(for: diffDomain) {
                    scores.append(accuracy)
                }
            }

            if scores.isEmpty {
                // No data for this domain — treat as weakest (0.0 means no data)
                domainScores[domain] = 0.0
            } else {
                domainScores[domain] = scores.reduce(0, +) / Double(scores.count)
            }
        }

        return domainScores
    }

    /// Rank domains from weakest to strongest.
    private func rankDomainsByWeakness(_ scores: [WorkoutDomain: Double]) -> [WorkoutDomain] {
        WorkoutDomain.allCases.sorted { a, b in
            (scores[a] ?? 0) < (scores[b] ?? 0)
        }
    }

    // MARK: - Private: Game Picking

    /// Pick a random exercise from a domain, avoiding duplicates and yesterday's games.
    private func pickGame(
        from domain: WorkoutDomain,
        excluding usedTypes: Set<String>,
        yesterdayTypes: Set<String>,
        reasonTag: String
    ) -> WorkoutGame? {
        // Prefer types not used yesterday
        let preferred = domain.exerciseTypes.filter {
            !usedTypes.contains($0.rawValue) && !yesterdayTypes.contains($0.rawValue)
        }

        if let type = preferred.randomElement() {
            return WorkoutGame(exerciseType: type, domain: domain, reasonTag: reasonTag)
        }

        // Fall back to any unused type in this domain
        let fallback = domain.exerciseTypes.filter {
            !usedTypes.contains($0.rawValue)
        }

        if let type = fallback.randomElement() {
            return WorkoutGame(exerciseType: type, domain: domain, reasonTag: reasonTag)
        }

        return nil
    }

    /// Map user goals to a WorkoutDomain preference.
    private func goalDomain(for goals: [UserFocusGoal]) -> WorkoutDomain? {
        // Priority: first goal that maps to a domain
        for goal in goals {
            switch goal {
            case .forgetInstantly, .attentionShot:
                return .memory
            case .loseFocus, .screenTimeFrying, .doomscrolling:
                return .speed
            case .getSharper:
                return .visual
            }
        }
        return nil
    }

    /// Default workout for new users with no exercise history.
    private func newUserFallback() -> [WorkoutGame] {
        [
            WorkoutGame(exerciseType: .reactionTime, domain: .speed, reasonTag: "Get started"),
            WorkoutGame(exerciseType: .sequentialMemory, domain: .memory, reasonTag: "Get started"),
            WorkoutGame(exerciseType: .visualMemory, domain: .visual, reasonTag: "Get started"),
        ]
    }

    // MARK: - Private: Blending

    private func blend(old: Double, today: Double?) -> Double {
        guard let today else { return old }
        return old * 0.8 + today * 0.2
    }

    // MARK: - Private: Persistence

    private func persistWorkout(_ workout: DailyWorkout) {
        if let data = try? JSONEncoder().encode(workout) {
            UserDefaults.standard.set(data, forKey: workoutKey)
        }
    }

    private func loadWorkout() {
        guard let data = UserDefaults.standard.data(forKey: workoutKey),
              let workout = try? JSONDecoder().decode(DailyWorkout.self, from: data)
        else { return }

        let today = DailyWorkout.todayDateString()
        if workout.dateString == today {
            todaysWorkout = workout
        }
        // If it's a stale workout from a previous day, don't load it —
        // it will be archived when generateWorkout is called.
    }

    /// Save yesterday's game types for anti-repetition, then clear stale workout.
    private func archiveYesterdayIfNeeded() {
        guard let data = UserDefaults.standard.data(forKey: workoutKey),
              let workout = try? JSONDecoder().decode(DailyWorkout.self, from: data),
              workout.dateString != DailyWorkout.todayDateString()
        else { return }

        let typeRaws = workout.games.map { $0.exerciseTypeRaw }
        UserDefaults.standard.set(typeRaws, forKey: yesterdayGamesKey)
    }

    private func loadYesterdayGameTypes() -> Set<String> {
        guard let types = UserDefaults.standard.stringArray(forKey: yesterdayGamesKey) else {
            return []
        }
        return Set(types)
    }
}
