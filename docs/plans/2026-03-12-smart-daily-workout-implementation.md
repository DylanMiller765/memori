# Smart Daily Workout — Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Add a personalized daily 3-game workout to the Home screen that targets weak cognitive domains and updates Brain Score after completion.

**Architecture:** New `WorkoutEngine` service generates daily workout based on domain performance from Exercise history + AdaptiveDifficultyEngine accuracy. New `WorkoutCard` replaces the existing todaySessionCard on Home. Workout completion triggers a rolling Brain Score update (80/20 blend) and shows a celebration screen with share card.

**Tech Stack:** SwiftUI, SwiftData, UserDefaults (workout state persistence)

---

### Task 1: Add `sourceRaw` field to BrainScoreResult

**Files:**
- Modify: `MindRestore/Models/BrainScore.swift:51-72`

**What:** Add a `sourceRaw` field to distinguish assessment-generated scores from workout-generated scores. This is needed so the celebration screen knows it's showing a workout result and so we can filter by source later.

**Step 1: Add the source enum and field**

Add above the `BrainScoreResult` class:

```swift
enum BrainScoreSource: String, Codable {
    case assessment
    case workout
}
```

Add to `BrainScoreResult` properties (after `percentile`):

```swift
var sourceRaw: String = BrainScoreSource.assessment.rawValue

var source: BrainScoreSource {
    get { BrainScoreSource(rawValue: sourceRaw) ?? .assessment }
    set { sourceRaw = newValue.rawValue }
}
```

**Step 2: Build to verify**

Run: `xcodebuild -scheme MindRestore -destination 'generic/platform=iOS' -derivedDataPath build/ build 2>&1 | tail -5`
Expected: BUILD SUCCEEDED

**Step 3: Commit**

```bash
git add MindRestore/Models/BrainScore.swift
git commit -m "feat: add source field to BrainScoreResult for workout vs assessment tracking"
```

---

### Task 2: Create WorkoutEngine service

**Files:**
- Create: `MindRestore/Services/WorkoutEngine.swift`

**What:** The brain of the daily workout. Picks 3 games based on domain weakness, manages workout state, and computes rolling Brain Score updates.

**Step 1: Create the file with full implementation**

```swift
import Foundation
import SwiftData
import SwiftUI

// MARK: - Cognitive Domain (high-level, maps to Brain Score weights)

enum CognitiveDomain: String, CaseIterable {
    case memory   // 35% weight — Sequential Memory, Chunking, Dual N-Back
    case speed    // 30% weight — Reaction Time, Color Match, Speed Match
    case visual   // 35% weight — Visual Memory

    var weight: Double {
        switch self {
        case .memory: return 0.35
        case .speed: return 0.30
        case .visual: return 0.35
        }
    }

    var color: Color {
        switch self {
        case .memory: return AppColors.violet
        case .speed: return AppColors.coral
        case .visual: return AppColors.sky
        }
    }

    var displayName: String {
        switch self {
        case .memory: return "Memory"
        case .speed: return "Speed"
        case .visual: return "Visual"
        }
    }

    /// Exercise types that belong to this domain
    var exerciseTypes: [ExerciseType] {
        switch self {
        case .memory: return [.sequentialMemory, .chunkingTraining, .dualNBack]
        case .speed: return [.reactionTime, .colorMatch, .speedMatch]
        case .visual: return [.visualMemory]
        }
    }

    /// Maps to AdaptiveDifficultyEngine domains for accuracy queries
    var difficultyDomains: [ExerciseDomain] {
        switch self {
        case .memory: return [.sequentialMemory, .nBack, .digits]
        case .speed: return [.colorMatch, .speedMatch]
        case .visual: return [.visualMemory]
        }
    }
}

// MARK: - Workout Game

struct WorkoutGame: Identifiable, Codable {
    let id: UUID
    let exerciseTypeRaw: String
    let domainRaw: String
    let reasonTag: String
    var score: Double?
    var completed: Bool

    init(exerciseType: ExerciseType, domain: CognitiveDomain, reasonTag: String) {
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

    var domain: CognitiveDomain {
        CognitiveDomain(rawValue: domainRaw) ?? .speed
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
}

// MARK: - Workout Engine

@MainActor @Observable
final class WorkoutEngine {

    // MARK: - State

    private(set) var todaysWorkout: DailyWorkout?

    // MARK: - Private

    private let defaults = UserDefaults.standard
    private let workoutKey = "daily_workout_data"
    private let yesterdayGamesKey = "yesterday_workout_games"

    // MARK: - Init

    init() {
        loadWorkout()
    }

    // MARK: - Generate Workout

    /// Generate today's workout based on recent exercise performance and user goals.
    func generateWorkout(exercises: [Exercise], userGoals: [UserFocusGoal]) {
        let today = Self.todayString()

        // Already generated for today?
        if let existing = todaysWorkout, existing.dateString == today {
            return
        }

        // Calculate domain performance
        let domainScores = calculateDomainScores(from: exercises)

        // Rank domains weakest → strongest
        let ranked = CognitiveDomain.allCases.sorted { a, b in
            (domainScores[a] ?? 0) < (domainScores[b] ?? 0)
        }

        let yesterdayGames = loadYesterdayGames()
        var pickedGames: [WorkoutGame] = []
        var usedTypes = Set<ExerciseType>()

        // Game 1: Weakest domain
        if let game = pickGame(from: ranked[0], excluding: usedTypes, yesterdayGames: yesterdayGames, tag: "Needs work") {
            pickedGames.append(game)
            usedTypes.insert(game.exerciseType)
        }

        // Game 2: Second-weakest or goal-aligned
        let game2Domain = ranked[1]
        let goalTag = goalAlignedTag(domain: game2Domain, goals: userGoals)
        let tag2 = goalTag ?? "Build up"
        if let game = pickGame(from: game2Domain, excluding: usedTypes, yesterdayGames: yesterdayGames, tag: tag2) {
            pickedGames.append(game)
            usedTypes.insert(game.exerciseType)
        }

        // Game 3: Variety from remaining
        let game3Domain = ranked[2]
        if let game = pickGame(from: game3Domain, excluding: usedTypes, yesterdayGames: yesterdayGames, tag: "Mix it up") {
            pickedGames.append(game)
            usedTypes.insert(game.exerciseType)
        }

        // Fallback: if we couldn't pick 3 games (shouldn't happen), fill from any domain
        if pickedGames.count < 3 {
            let fallbackTypes: [ExerciseType] = [.reactionTime, .sequentialMemory, .visualMemory]
            for ft in fallbackTypes where !usedTypes.contains(ft) && pickedGames.count < 3 {
                let domain = Self.domainFor(ft)
                pickedGames.append(WorkoutGame(exerciseType: ft, domain: domain, reasonTag: "Recommended"))
                usedTypes.insert(ft)
            }
        }

        let workout = DailyWorkout(dateString: today, games: pickedGames)
        todaysWorkout = workout
        saveWorkout()
    }

    // MARK: - Record Completion

    /// Mark a game as completed with its score. Returns true if the full workout is now complete.
    @discardableResult
    func recordGameCompletion(exerciseType: ExerciseType, score: Double) -> Bool {
        guard var workout = todaysWorkout else { return false }

        if let index = workout.games.firstIndex(where: { $0.exerciseType == exerciseType && !$0.completed }) {
            workout.games[index].score = score
            workout.games[index].completed = true
            todaysWorkout = workout
            saveWorkout()
        }

        return workout.isComplete
    }

    // MARK: - Rolling Brain Score

    /// Compute new Brain Score using 80/20 rolling blend.
    func computeRollingBrainScore(oldScore: BrainScoreResult?, workoutGames: [WorkoutGame]) -> (brainScore: Int, brainAge: Int, percentile: Int, brainType: BrainType, digitScore: Double, reactionScore: Double, visualScore: Double) {
        // Calculate today's domain performance from workout games
        var domainTotals: [CognitiveDomain: (total: Double, count: Int)] = [:]
        for game in workoutGames where game.completed {
            let domain = game.domain
            let existing = domainTotals[domain] ?? (total: 0, count: 0)
            domainTotals[domain] = (total: existing.total + (game.score ?? 0), count: existing.count + 1)
        }

        // Convert game scores (0.0-1.0) to domain scores (0-100 scale matching BrainScoring)
        let todayMemory = domainTotals[.memory].map { $0.total / Double($0.count) * 100 }
        let todaySpeed = domainTotals[.speed].map { $0.total / Double($0.count) * 100 }
        let todayVisual = domainTotals[.visual].map { $0.total / Double($0.count) * 100 }

        let oldDigit = oldScore?.digitSpanScore ?? 50.0
        let oldReaction = oldScore?.reactionTimeScore ?? 50.0
        let oldVisual = oldScore?.visualMemoryScore ?? 50.0

        // 80/20 rolling blend per domain (carry forward old score for missing domains)
        let newDigit = todayMemory.map { $0 * 0.2 + oldDigit * 0.8 } ?? oldDigit
        let newReaction = todaySpeed.map { $0 * 0.2 + oldReaction * 0.8 } ?? oldReaction
        let newVisual = todayVisual.map { $0 * 0.2 + oldVisual * 0.8 } ?? oldVisual

        var newBrainScore = BrainScoring.compositeBrainScore(digit: newDigit, reaction: newReaction, visual: newVisual)

        // Guardrails
        if let old = oldScore {
            let diff = newBrainScore - old.brainScore
            if diff > 50 { newBrainScore = old.brainScore + 50 }
            if diff < -30 { newBrainScore = old.brainScore - 30 }
        }

        let brainAge = BrainScoring.brainAge(from: newBrainScore)
        let percentile = BrainScoring.percentile(score: newBrainScore)
        let brainType = BrainScoring.determineBrainType(digit: newDigit, reaction: newReaction, visual: newVisual)

        return (newBrainScore, brainAge, percentile, brainType, newDigit, newReaction, newVisual)
    }

    // MARK: - Day Reset

    /// Archive today's games as yesterday's (for anti-repetition) and clear workout.
    func archiveAndReset() {
        if let workout = todaysWorkout {
            let gameTypes = workout.games.map { $0.exerciseTypeRaw }
            defaults.set(gameTypes, forKey: yesterdayGamesKey)
        }
        todaysWorkout = nil
        defaults.removeObject(forKey: workoutKey)
    }

    // MARK: - Helpers

    private func calculateDomainScores(from exercises: [Exercise]) -> [CognitiveDomain: Double] {
        let sevenDaysAgo = Calendar.current.date(byAdding: .day, value: -7, to: .now) ?? .now
        let recent = exercises.filter { $0.completedAt > sevenDaysAgo }

        var scores: [CognitiveDomain: Double] = [:]

        for domain in CognitiveDomain.allCases {
            let domainExercises = recent.filter { domain.exerciseTypes.contains($0.type) }

            // Blend exercise scores with adaptive difficulty accuracy
            var avgScore: Double = 0.5 // default if no data
            if !domainExercises.isEmpty {
                avgScore = domainExercises.map(\.score).reduce(0, +) / Double(domainExercises.count)
            }

            // Also check adaptive difficulty engine accuracy
            let accuracies = domain.difficultyDomains.compactMap {
                AdaptiveDifficultyEngine.shared.recentAccuracy(for: $0)
            }
            let avgAccuracy = accuracies.isEmpty ? nil : accuracies.reduce(0, +) / Double(accuracies.count)

            // Blend: 60% exercise score, 40% accuracy (if available)
            if let acc = avgAccuracy {
                scores[domain] = avgScore * 0.6 + acc * 0.4
            } else {
                scores[domain] = avgScore
            }
        }

        return scores
    }

    private func pickGame(from domain: CognitiveDomain, excluding used: Set<ExerciseType>, yesterdayGames: Set<String>, tag: String) -> WorkoutGame? {
        // Prefer games not played yesterday, then any from domain
        let available = domain.exerciseTypes.filter { !used.contains($0) }
        let fresh = available.filter { !yesterdayGames.contains($0.rawValue) }
        let pool = fresh.isEmpty ? available : fresh

        guard let picked = pool.randomElement() else { return nil }
        return WorkoutGame(exerciseType: picked, domain: domain, reasonTag: tag)
    }

    private func goalAlignedTag(domain: CognitiveDomain, goals: [UserFocusGoal]) -> String? {
        for goal in goals {
            switch (goal, domain) {
            case (.forgetThings, .memory), (.forgetThings, .visual): return "Your goal"
            case (.cantFocus, .speed): return "Your goal"
            case (.gettingWorse, .memory): return "Your goal"
            case (.staySharp, .speed): return "Your goal"
            default: continue
            }
        }
        return nil
    }

    private func loadYesterdayGames() -> Set<String> {
        Set(defaults.stringArray(forKey: yesterdayGamesKey) ?? [])
    }

    static func domainFor(_ type: ExerciseType) -> CognitiveDomain {
        for domain in CognitiveDomain.allCases {
            if domain.exerciseTypes.contains(type) { return domain }
        }
        return .speed // fallback (mathSpeed maps here)
    }

    static func todayString() -> String {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd"
        return f.string(from: .now)
    }

    // MARK: - Persistence

    private func saveWorkout() {
        guard let workout = todaysWorkout,
              let data = try? JSONEncoder().encode(workout) else { return }
        defaults.set(data, forKey: workoutKey)
    }

    private func loadWorkout() {
        guard let data = defaults.data(forKey: workoutKey),
              let workout = try? JSONDecoder().decode(DailyWorkout.self, from: data) else { return }

        // Only load if it's today's workout
        if workout.dateString == Self.todayString() {
            todaysWorkout = workout
        } else {
            // Archive yesterday's and clear
            let gameTypes = workout.games.map { $0.exerciseTypeRaw }
            defaults.set(gameTypes, forKey: yesterdayGamesKey)
            defaults.removeObject(forKey: workoutKey)
        }
    }
}
```

**Step 2: Build to verify**

Run: `xcodebuild -scheme MindRestore -destination 'generic/platform=iOS' -derivedDataPath build/ build 2>&1 | tail -5`
Expected: BUILD SUCCEEDED

**Step 3: Commit**

```bash
git add MindRestore/Services/WorkoutEngine.swift
git commit -m "feat: add WorkoutEngine with domain-weakness algorithm and rolling Brain Score"
```

**Note:** This file must be added to the Xcode project. After creating it, tell the user to add it in Xcode (File → Add Files) before building.

---

### Task 3: Register WorkoutEngine as environment object

**Files:**
- Modify: `MindRestore/MindRestoreApp.swift` — add WorkoutEngine to environment
- Modify: `MindRestore/ContentView.swift` — pass WorkoutEngine to HomeView

**What:** Wire WorkoutEngine into the app's environment so HomeView can access it.

**Step 1: Find where other environment objects are created in MindRestoreApp.swift**

Look for where `StoreService`, `TrainingSessionManager`, etc. are created and passed via `.environment()`.

Add:
```swift
@State private var workoutEngine = WorkoutEngine()
```

And in the body, chain:
```swift
.environment(workoutEngine)
```

**Step 2: Build to verify**

Run: `xcodebuild -scheme MindRestore -destination 'generic/platform=iOS' -derivedDataPath build/ build 2>&1 | tail -5`
Expected: BUILD SUCCEEDED

**Step 3: Commit**

```bash
git add MindRestore/MindRestoreApp.swift
git commit -m "feat: register WorkoutEngine as environment object"
```

---

### Task 4: Create WorkoutCard view

**Files:**
- Create: `MindRestore/Views/Home/WorkoutCard.swift`

**What:** The 3-state card (not started, in progress, complete) that replaces todaySessionCard on the Home screen.

**Step 1: Create the file**

```swift
import SwiftUI
import SwiftData

struct WorkoutCard: View {
    let workout: DailyWorkout
    let onStartGame: (ExerciseType) -> Void
    let onSeeResults: () -> Void

    var body: some View {
        VStack(spacing: 16) {
            if workout.isComplete {
                completeState
            } else {
                activeState
            }
        }
        .glowingCard(color: workout.isComplete ? AppColors.teal : AppColors.accent, intensity: 0.20)
    }

    // MARK: - Active State (not started + in progress)

    private var activeState: some View {
        VStack(spacing: 16) {
            // Header
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("TODAY'S WORKOUT")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundStyle(.secondary)
                        .tracking(1.2)
                    Text(workout.completedCount == 0 ? "Picked for your brain" : "\(workout.completedCount) of 3 complete")
                        .font(.subheadline.weight(.medium))
                }

                Spacer()

                // Progress ring
                ZStack {
                    Circle()
                        .stroke(AppColors.accent.opacity(0.18), lineWidth: 5)
                    Circle()
                        .trim(from: 0, to: Double(workout.completedCount) / 3.0)
                        .stroke(AppColors.accent, style: StrokeStyle(lineWidth: 5, lineCap: .round))
                        .rotationEffect(.degrees(-90))
                    Text("\(workout.completedCount)")
                        .font(.system(size: 14, weight: .bold, design: .rounded))
                }
                .frame(width: 44, height: 44)
            }

            // Game tiles
            HStack(spacing: 10) {
                ForEach(workout.games) { game in
                    gameTile(game)
                }
            }

            // Action button
            if let nextGame = workout.nextGame {
                Button {
                    onStartGame(nextGame.exerciseType)
                } label: {
                    Text(workout.completedCount == 0 ? "Start Workout" : "Continue → \(nextGame.exerciseType.displayName)")
                        .gradientButton()
                }
            }
        }
    }

    // MARK: - Complete State

    private var completeState: some View {
        VStack(spacing: 12) {
            HStack {
                Image(systemName: "checkmark.circle.fill")
                    .font(.title3)
                    .foregroundStyle(AppColors.teal)
                Text("Workout Complete!")
                    .font(.headline.weight(.bold))
                Spacer()
            }

            Button {
                onSeeResults()
            } label: {
                Text("See Results")
                    .gradientButton()
            }
        }
    }

    // MARK: - Game Tile

    private func gameTile(_ game: WorkoutGame) -> some View {
        VStack(spacing: 6) {
            if game.completed {
                Image(systemName: "checkmark.circle.fill")
                    .font(.title2)
                    .foregroundStyle(AppColors.teal)
                    .frame(height: 36)
            } else {
                Image(systemName: game.exerciseType.icon)
                    .font(.title2)
                    .foregroundStyle(game.domain.color)
                    .frame(height: 36)
            }

            Text(game.exerciseType.displayName)
                .font(.system(size: 10, weight: .bold))
                .foregroundStyle(.primary)
                .lineLimit(1)
                .minimumScaleFactor(0.8)

            if game.completed, let score = game.score {
                Text("\(Int(score * 100))%")
                    .font(.system(size: 9, weight: .bold, design: .rounded))
                    .foregroundStyle(AppColors.teal)
            } else {
                Text(game.reasonTag)
                    .font(.system(size: 9, weight: .medium))
                    .foregroundStyle(AppColors.textTertiary)
            }
        }
        .padding(.vertical, 10)
        .frame(maxWidth: .infinity)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(AppColors.cardSurface)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke((game.completed ? AppColors.teal : game.domain.color).opacity(0.2), lineWidth: 1)
        )
    }
}
```

**Step 2: Build to verify**

Run: `xcodebuild -scheme MindRestore -destination 'generic/platform=iOS' -derivedDataPath build/ build 2>&1 | tail -5`
Expected: BUILD SUCCEEDED

**Step 3: Commit**

```bash
git add MindRestore/Views/Home/WorkoutCard.swift
git commit -m "feat: add WorkoutCard with 3-state design (pending, in-progress, complete)"
```

**Note:** Add to Xcode project before building.

---

### Task 5: Create WorkoutCompleteView (celebration screen)

**Files:**
- Create: `MindRestore/Views/Home/WorkoutCompleteView.swift`

**What:** The celebration screen shown after completing all 3 workout games. Shows Brain Score ticker animation, confetti, and share button.

**Step 1: Create the file**

```swift
import SwiftUI

struct WorkoutCompleteView: View {
    let oldBrainScore: Int
    let newBrainScore: Int
    let oldBrainAge: Int
    let newBrainAge: Int
    let streak: Int
    let onShare: () -> Void
    let onDone: () -> Void

    @State private var displayedScore: Int = 0
    @State private var showDelta = false
    @State private var showDetails = false
    @State private var showConfetti = false

    private var scoreDelta: Int { newBrainScore - oldBrainScore }
    private var ageDelta: Int { oldBrainAge - newBrainAge } // positive = improvement

    var body: some View {
        VStack(spacing: 24) {
            Spacer()

            Text("Workout Complete!")
                .font(.system(size: 28, weight: .black, design: .rounded))
                .foregroundStyle(AppColors.textPrimary)

            // Score ring with ticker
            ZStack {
                Circle()
                    .stroke(AppColors.accent.opacity(0.18), lineWidth: 14)
                Circle()
                    .trim(from: 0, to: min(CGFloat(displayedScore) / 1000.0, 1.0))
                    .stroke(AppColors.accent, style: StrokeStyle(lineWidth: 14, lineCap: .round))
                    .rotationEffect(.degrees(-90))

                VStack(spacing: 2) {
                    Text("\(displayedScore)")
                        .font(.system(size: 48, weight: .black, design: .rounded))
                        .foregroundStyle(AppColors.textPrimary)
                        .contentTransition(.numericText())
                    Text("BRAIN SCORE")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundStyle(AppColors.textTertiary)
                        .tracking(1.0)
                }
            }
            .frame(width: 160, height: 160)

            // Delta badge
            if showDelta && scoreDelta != 0 {
                Text(scoreDelta > 0 ? "+\(scoreDelta) points ↑" : "\(scoreDelta) points ↓")
                    .font(.system(size: 18, weight: .bold, design: .rounded))
                    .foregroundStyle(scoreDelta > 0 ? AppColors.teal : AppColors.coral)
                    .transition(.scale.combined(with: .opacity))
            }

            // Brain Age + Streak
            if showDetails {
                VStack(spacing: 8) {
                    if ageDelta != 0 {
                        Text("Brain Age: \(newBrainAge) (\(ageDelta > 0 ? "↓\(ageDelta) year\(ageDelta == 1 ? "" : "s")" : "↑\(abs(ageDelta)) year\(abs(ageDelta) == 1 ? "" : "s")"))")
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(AppColors.textSecondary)
                    }

                    if streak > 0 {
                        HStack(spacing: 4) {
                            Image(systemName: "flame.fill")
                                .foregroundStyle(AppColors.coral)
                            Text("\(streak) day streak")
                                .font(.subheadline.weight(.semibold))
                        }
                        .foregroundStyle(AppColors.textSecondary)
                    }
                }
                .transition(.opacity)
            }

            Spacer()

            // Action buttons
            HStack(spacing: 16) {
                Button(action: onShare) {
                    HStack(spacing: 6) {
                        Image(systemName: "square.and.arrow.up")
                        Text("Share")
                    }
                    .font(.headline.weight(.bold))
                    .foregroundStyle(AppColors.accent)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
                    .background(
                        RoundedRectangle(cornerRadius: 16)
                            .fill(AppColors.accent.opacity(0.12))
                    )
                }

                Button(action: onDone) {
                    Text("Done")
                        .gradientButton()
                }
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 30)
        }
        .overlay {
            if showConfetti {
                ConfettiView()
                    .allowsHitTesting(false)
            }
        }
        .onAppear {
            startAnimationSequence()
        }
    }

    private func startAnimationSequence() {
        displayedScore = oldBrainScore

        // Ticker animation: count up from old to new over 1.2s
        withAnimation(.easeInOut(duration: 1.2)) {
            displayedScore = newBrainScore
        }

        // Show delta after ticker completes
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.3) {
            withAnimation(.spring(response: 0.5, dampingFraction: 0.6)) {
                showDelta = true
            }
        }

        // Show details
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.6) {
            withAnimation(.easeOut(duration: 0.4)) {
                showDetails = true
            }
        }

        // Confetti
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.8) {
            showConfetti = true
        }
    }
}
```

**Step 2: Build to verify**

**Step 3: Commit**

```bash
git add MindRestore/Views/Home/WorkoutCompleteView.swift
git commit -m "feat: add WorkoutCompleteView with ticker animation and confetti"
```

**Note:** Add to Xcode project before building.

---

### Task 6: Create workout share card

**Files:**
- Create: `MindRestore/Views/Components/WorkoutShareCard.swift`

**What:** TikTok-style dark share card for daily workout completion. Shows Brain Score, delta, Brain Age, and streak.

**Step 1: Create the file**

```swift
import SwiftUI

struct WorkoutShareCard: View {
    let brainScore: Int
    let scoreDelta: Int
    let brainAge: Int
    let streak: Int

    var body: some View {
        VStack(spacing: 20) {
            // Header
            HStack {
                Image(systemName: "brain.head.profile.fill")
                    .font(.title3.weight(.bold))
                Text("Memori")
                    .font(.title3.weight(.black))
                Spacer()
                Text("Daily Workout")
                    .font(.caption.weight(.bold))
                    .foregroundStyle(.white.opacity(0.6))
            }
            .foregroundStyle(.white)

            // Brain Score
            VStack(spacing: 4) {
                Text("\(brainScore)")
                    .font(.system(size: 64, weight: .black, design: .rounded))
                    .foregroundStyle(.white)
                Text("BRAIN SCORE")
                    .font(.system(size: 11, weight: .bold))
                    .foregroundStyle(.white.opacity(0.5))
                    .tracking(1.5)
                if scoreDelta != 0 {
                    Text(scoreDelta > 0 ? "+\(scoreDelta) today" : "\(scoreDelta) today")
                        .font(.system(size: 16, weight: .bold, design: .rounded))
                        .foregroundStyle(scoreDelta > 0 ? Color(red: 0.18, green: 0.75, blue: 0.50) : AppColors.coral)
                }
            }

            // Stats row
            HStack(spacing: 24) {
                VStack(spacing: 2) {
                    Text("\(brainAge)")
                        .font(.system(size: 28, weight: .black, design: .rounded))
                        .foregroundStyle(.white)
                    Text("Brain Age")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundStyle(.white.opacity(0.5))
                }

                if streak > 0 {
                    VStack(spacing: 2) {
                        HStack(spacing: 4) {
                            Text("\(streak)")
                                .font(.system(size: 28, weight: .black, design: .rounded))
                            Image(systemName: "flame.fill")
                                .font(.system(size: 18))
                                .foregroundStyle(AppColors.coral)
                        }
                        .foregroundStyle(.white)
                        Text("Day Streak")
                            .font(.system(size: 10, weight: .bold))
                            .foregroundStyle(.white.opacity(0.5))
                    }
                }
            }
        }
        .padding(28)
        .frame(width: 360)
        .background(
            RoundedRectangle(cornerRadius: 24)
                .fill(
                    LinearGradient(
                        colors: [Color(red: 0.08, green: 0.08, blue: 0.14), Color(red: 0.12, green: 0.10, blue: 0.22)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
        )
    }
}
```

**Step 2: Build and commit**

```bash
git add MindRestore/Views/Components/WorkoutShareCard.swift
git commit -m "feat: add WorkoutShareCard for daily workout completion sharing"
```

---

### Task 7: Integrate workout into HomeView

**Files:**
- Modify: `MindRestore/Views/Home/HomeView.swift`

**What:** Replace `todaysSessionCard` with `WorkoutCard`. Wire up workout generation on appear, game completion tracking, and navigation to the celebration screen.

**Step 1: Add WorkoutEngine environment and state**

At the top of HomeView struct, add:
```swift
@Environment(WorkoutEngine.self) private var workoutEngine
@State private var showingWorkoutComplete = false
@State private var workoutOldScore: Int = 0
@State private var workoutNewScore: Int = 0
@State private var workoutOldAge: Int = 25
@State private var workoutNewAge: Int = 25
@State private var workoutShareImage: UIImage?
```

**Step 2: Generate workout on appear**

In the `.onAppear` or `.task` modifier of the main body, add:
```swift
workoutEngine.generateWorkout(
    exercises: exercises,
    userGoals: user?.focusGoals ?? []
)
```

**Step 3: Replace todaysSessionCard**

Replace the `todaysSessionCard` usage in the body with:
```swift
if let workout = workoutEngine.todaysWorkout {
    WorkoutCard(
        workout: workout,
        onStartGame: { exerciseType in
            // Navigate to the exercise
            viewModel.pendingWorkoutGame = exerciseType
        },
        onSeeResults: {
            showingWorkoutComplete = true
        }
    )
}
```

**Step 4: Add navigation destination for workout games**

Add a `.navigationDestination` for workout game types that, on disappear, records the completion back to WorkoutEngine.

**Step 5: Add fullScreenCover for WorkoutCompleteView**

```swift
.fullScreenCover(isPresented: $showingWorkoutComplete) {
    WorkoutCompleteView(
        oldBrainScore: workoutOldScore,
        newBrainScore: workoutNewScore,
        oldBrainAge: workoutOldAge,
        newBrainAge: workoutNewAge,
        streak: user?.currentStreak ?? 0,
        onShare: { /* render and share WorkoutShareCard */ },
        onDone: { showingWorkoutComplete = false }
    )
}
```

**Step 6: Wire workout completion to Brain Score save**

When `workoutEngine.recordGameCompletion()` returns `true` (all 3 done):
1. Call `workoutEngine.computeRollingBrainScore()` with the latest BrainScoreResult
2. Save a new `BrainScoreResult` with `.source = .workout`
3. Set `workoutOldScore`, `workoutNewScore`, etc.
4. Set `showingWorkoutComplete = true`

**Step 7: Build to verify**

**Step 8: Commit**

```bash
git add MindRestore/Views/Home/HomeView.swift MindRestore/ViewModels/HomeViewModel.swift
git commit -m "feat: integrate WorkoutCard into HomeView with completion flow"
```

---

### Task 8: Wire exercise completion back to WorkoutEngine

**Files:**
- Modify: Exercise completion handlers in individual game views OR in a central place where exercises are saved

**What:** When a user completes a game that's part of their daily workout, notify WorkoutEngine. Find where `Exercise(type:...)` is created and `DailySession.addExercise()` is called — add `workoutEngine.recordGameCompletion()` alongside.

**Step 1: Find exercise save points**

Search for where exercises are saved: `Exercise(type:` or `addExercise` calls in game result views.

**Step 2: Add workout recording**

At each save point, check if the completed exercise type matches a workout game:
```swift
if let workout = workoutEngine.todaysWorkout,
   workout.games.contains(where: { $0.exerciseType == exerciseType && !$0.completed }) {
    let isComplete = workoutEngine.recordGameCompletion(exerciseType: exerciseType, score: score)
    if isComplete {
        // Trigger Brain Score update and celebration
    }
}
```

**Step 3: Build and test on device**

**Step 4: Commit**

```bash
git commit -am "feat: wire exercise completion into WorkoutEngine tracking"
```

---

### Task 9: Delete old todaySessionCard code

**Files:**
- Modify: `MindRestore/Views/Home/HomeView.swift`

**What:** Remove the old `todaysSessionCard` computed property and `sessionTileMiniPreview` helper since they're replaced by WorkoutCard. Also remove any dead code from HomeViewModel related to the old card.

**Step 1: Remove todaysSessionCard** (lines ~419-513)

**Step 2: Remove sessionTileMiniPreview** and related helpers if only used by the old card

**Step 3: Build to verify nothing else depended on removed code**

**Step 4: Commit**

```bash
git add MindRestore/Views/Home/HomeView.swift
git commit -m "refactor: remove old todaysSessionCard replaced by WorkoutCard"
```

---

### Task 10: Build, install, and verify on device

**Files:** None (verification only)

**Step 1: Full build**

```bash
xcodebuild -scheme MindRestore -destination 'generic/platform=iOS' -derivedDataPath build/ build 2>&1 | tail -5
```

**Step 2: Install on device**

```bash
xcrun devicectl device install app --device 00008130-000A214E11E2001C build/Build/Products/Debug-iphoneos/MindRestore.app
```

**Step 3: Verify checklist**

- [ ] Home screen shows "Today's Workout" card with 3 games
- [ ] Each game tile shows domain color, name, and reason tag
- [ ] "Start Workout" launches the first game
- [ ] After completing game 1, card shows "1 of 3" with checkmark on completed game
- [ ] "Continue" button shows next game name
- [ ] After all 3 games, celebration screen appears
- [ ] Score ticker animates from old to new
- [ ] Confetti fires
- [ ] Brain Score delta and Brain Age shown
- [ ] Share card renders correctly
- [ ] "Done" returns to Home with completed workout card
- [ ] Next day: new workout generates with different games
- [ ] New user (no history): falls back to balanced recommendations
- [ ] Brain Score guardrails: score doesn't swing more than +50/-30

**Step 4: Final commit**

```bash
git add -A
git commit -m "feat: Smart Daily Workout v1.2 — complete implementation"
```
