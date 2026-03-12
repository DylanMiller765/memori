# Smart Daily Workout — Design Doc

## Context
Memori's #1 gap vs Lumosity/Elevate: no personalized daily workout. Users open the app and just pick random games. There's no guidance, no "why," no structure that drives daily habit formation. The existing "Today's Session" card on Home has a progress ring and goal-based recommendations, but it's generic — not personalized to the user's weak areas.

This is the centerpiece of v1.2. Brain Score should feel alive — something you're actively building every day, not a static number from an assessment you took last week.

## Decisions

| Decision | Choice | Why |
|----------|--------|-----|
| Brain Score update method | Weighted rolling (80% old + 20% today) | Feels alive without wild daily swings |
| Who gets it | Everyone (free + Pro) | Drives habit from day one. Paywall stays on 3-game daily limit |
| Card design | Replace existing "Today's Session" card | Fresh design that communicates "picked for YOU" |
| Celebration | Brain Score update + share card | One punchy shareable moment, not a detailed report |
| Show reasoning | Yes, 2-3 word tags per game | Transparency builds trust, kills "rigged" perception |

## Feature 1: Workout Algorithm

### Game Selection (runs on app open, cached for the day)

1. **Calculate domain performance** from last 7 days of exercises:
   - Memory domain: Sequential Memory, Chunking, Dual N-Back
   - Speed domain: Reaction Time, Color Match, Speed Match
   - Visual domain: Visual Memory
   - Use both `Exercise.score` averages and `AdaptiveDifficultyEngine.recentAccuracy()` per domain

2. **Rank domains** weakest → strongest

3. **Pick 3 games:**
   - Game 1: From weakest domain
   - Game 2: From second-weakest domain (or goal-aligned if user set goals in onboarding)
   - Game 3: Variety pick from remaining games (don't repeat yesterday's set)

4. **Avoid repetition:** Track yesterday's workout games in UserDefaults. Don't pick the same 3 two days in a row.

5. **New users (< 3 sessions):** Fall back to `TrainingSessionManager.recommendedExercises(for: user.focusGoals)` until enough data. If no goals, default balanced spread (1 memory, 1 speed, 1 visual).

### Reason Tags
Each game tile shows a short reason:
- "Needs work" — weakest domain
- "Build on strength" — strongest domain
- "Your goal" — matches onboarding goal
- "Mix it up" — variety pick

### Domain-to-Game Mapping
| Domain | Games | Weight in Brain Score |
|--------|-------|----------------------|
| Memory | Sequential Memory, Chunking, Dual N-Back | 35% |
| Speed | Reaction Time, Color Match, Speed Match | 30% |
| Visual | Visual Memory | 35% |

Note: Math Speed is cross-domain (speed + memory). Map it to Speed for workout purposes.

### Files
- New: `MindRestore/Services/WorkoutEngine.swift` — algorithm lives here
- Modify: `MindRestore/Services/TrainingSessionManager.swift` — integrate workout engine
- Read: `AdaptiveDifficultyEngine.swift` — query `recentAccuracy()`
- Read: Exercise model — query last 7 days

---

## Feature 2: Workout Card (Home Screen)

Replaces the existing "Today's Session" card in `HomeView.swift`.

### State 1: Not Started
```
┌──────────────────────────────────┐
│  🧠 Today's Workout              │
│  Picked for your brain           │
│                                  │
│  ┌────────┐┌────────┐┌────────┐ │
│  │ 🟣     ││ 🔴     ││ 🔵     │ │
│  │Number  ││Speed   ││Visual  │ │
│  │Memory  ││Match   ││Memory  │ │
│  │        ││        ││        │ │
│  │Needs   ││Your    ││Mix it  │ │
│  │work    ││goal    ││up      │ │
│  └────────┘└────────┘└────────┘ │
│                                  │
│  [ Start Workout ]               │
└──────────────────────────────────┘
```
- 3 game tiles with domain-colored accents (Memory=Violet, Speed=Coral, Visual=Sky)
- Reason tag below each game name (9pt, tertiary color)
- "Start Workout" button launches game 1

### State 2: In Progress
```
┌──────────────────────────────────┐
│  🧠 Today's Workout    2 of 3   │
│                                  │
│  ┌────────┐┌────────┐┌────────┐ │
│  │   ✓    ││   ✓    ││ 🔵     │ │
│  │Number  ││Speed   ││Visual  │ │
│  │Memory  ││Match   ││Memory  │ │
│  │  92%   ││  87%   ││        │ │
│  └────────┘└────────┘└────────┘ │
│                                  │
│  [ Continue → Visual Memory ]    │
└──────────────────────────────────┘
```
- Completed tiles show checkmark + score
- Button shows next game name

### State 3: Complete
```
┌──────────────────────────────────┐
│  ✅ Workout Complete!             │
│                                  │
│  Brain Score: 643 → 655 (+12)    │
│                                  │
│  [ See Results ]                 │
└──────────────────────────────────┘
```
- "See Results" opens celebration screen
- Card stays as completed badge for rest of day

### Files
- New: `MindRestore/Views/Home/WorkoutCard.swift` — the 3-state card
- Modify: `MindRestore/Views/Home/HomeView.swift` — replace todaySessionCard with WorkoutCard
- Need: Workout state tracking (UserDefaults or @AppStorage)

---

## Feature 3: Brain Score Rolling Update

### Formula
```
newBrainScore = (oldBrainScore × 0.8) + (todayPerformance × 0.2)
```

Where `todayPerformance`:
- Maps each workout game score to its domain
- Scales using the same sigmoid curves from `BrainScore.swift`
- Weights by domain (Memory 35%, Speed 30%, Visual 35%)
- If workout only covers 2 of 3 domains, missing domain carries forward from old score

### Brain Age
Recalculated from the new Brain Score using existing age formula.

### Guardrails
- Max drop: 30 points per day (bad session protection)
- Max gain: 50 points per day (prevents unrealistic spikes)
- First workout ever (no prior Brain Score): use full calculation, not rolling average

### Storage
- Save as new `BrainScoreResult` in SwiftData
- Add `source` field to `BrainScoreResult`: `.assessment` vs `.workout`
- Brain Score history chart shows all data points
- Can filter by source if needed

### Files
- Modify: `MindRestore/Models/BrainScoreResult.swift` — add `source` field
- New: method in `WorkoutEngine.swift` to compute rolling Brain Score
- Modify: wherever BrainScoreResult is created — pass source

---

## Feature 4: Celebration Screen

Shown after completing the 3rd workout game.

```
┌──────────────────────────────────┐
│                                  │
│         Workout Complete!        │
│                                  │
│        ╭── score ring ──╮        │
│        │                │        │
│        │      655       │        │
│        │   BRAIN SCORE  │        │
│        │                │        │
│        ╰────────────────╯        │
│                                  │
│           +12 points ↑           │
│     Brain Age: 31 (↓1 year)     │
│                                  │
│     🔥 7 day streak              │
│                                  │
│  ┌──────────┐  ┌──────────────┐ │
│  │  Share   │  │     Done     │ │
│  └──────────┘  └──────────────┘ │
│                                  │
└──────────────────────────────────┘
```

- Score does a **ticker animation** counting up from old → new (screen-record worthy)
- "+12 points" pops in after ticker completes
- Confetti on appear
- Brain Age change shown if it moved
- Share card: TikTok-style dark card — "Daily Workout Complete — Brain Score 655 (+12) — Brain Age 31 — 7 day streak"
- "Done" returns to Home with completed workout card

### Files
- New: `MindRestore/Views/Home/WorkoutCompleteView.swift` — celebration screen
- New: Share card variant in `TikTokShareCard.swift` or new file
- Uses existing: ConfettiView, SegmentedScoreRing

---

## Workout Flow (End to End)

1. User opens app → Home screen shows **WorkoutCard** with 3 personalized games
2. User taps "Start Workout" → navigates to game 1
3. Game 1 completes → returns to Home, card updates to "1 of 3" state
4. User taps "Continue → [Game 2]" → plays game 2
5. Game 2 completes → card updates to "2 of 3"
6. User taps "Continue → [Game 3]" → plays game 3
7. Game 3 completes → **WorkoutCompleteView** appears with Brain Score update + confetti
8. User shares or taps Done → Home shows completed workout card for rest of day
9. Next day → new workout generated

## Out of Scope (for v1.2)
- Weekly progress reports (v1.3)
- Brain Score sparkline on Home (v1.3)
- Workout history / streaks beyond existing streak system
- Custom workout building (always algorithm-picked)
- More than 3 games per workout

## Verification
- Build and install on device
- New user: verify fallback to goal-based recommendations
- Existing user: verify weak domain detection picks appropriate games
- Complete all 3 games: verify Brain Score updates with rolling formula
- Verify guardrails: score doesn't swing more than 30 down or 50 up
- Verify share card renders correctly
- Verify workout resets next day with different games
- Verify free users can complete the workout within their 3-game limit
