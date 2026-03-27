# Optional Age in Onboarding — Design

**Goal:** Ask the user's age during onboarding (optional, skippable) and use it to show "X years younger/older" comparisons wherever brain age is displayed. Maximum shareability.

**Privacy:** Age is stored locally on device only. Never uploaded, never shared. User sees explicit privacy note on the age page.

## Onboarding Page

- **Position:** Between Goals (page 2) and Assessment (page 3) — creates anticipation for the brain age reveal
- **Title:** "How old are you?"
- **Subtitle:** "We'll compare your Brain Age to your real age"
- **Input:** Scrollable wheel picker, range 18–99
- **Privacy note:** Lock icon + "Stored on your device only. Never shared."
- **Buttons:** "Continue" (primary) and "Skip" (secondary, text-only)
- **Default state:** Picker starts at 25

## Data Model

- Add `userAge: Int = 0` to User model (0 = not provided / skipped)
- Set during `completeOnboarding()` if user provided age

## Where Age Comparison Shows Up

Only when `user.userAge > 0` (age was provided). Otherwise display brain age as-is (no change).

| Screen | What shows | Example |
|--------|-----------|---------|
| Score Reveal (after assessment) | Large text below brain age | "7 years younger than you!" (green) |
| Home brain score card | Subtitle under brain age number | "3 yrs younger" (green) or "2 yrs older" (coral) |
| WorkoutCompleteView | Next to brain age in details section | "+3 yrs younger" |
| Share cards (TikTok style) | Below brain age | "Brain Age: 38 (5 yrs younger!)" |
| Insights brain score card | Same as home | "3 yrs younger" |

## Color Coding

- Brain age < actual age → green/teal (younger = good)
- Brain age = actual age → neutral/secondary
- Brain age > actual age → coral (older = needs work)

## Age Comparison Logic

```swift
// On User model or as a helper
var brainAgeComparison: Int? {
    guard userAge > 0 else { return nil }
    return userAge - brainAge // positive = younger, negative = older
}
```

## Files to Touch

- `MindRestore/Models/User.swift` — add `userAge` field
- `MindRestore/Views/Onboarding/OnboardingView.swift` — new age page, shift page indices
- `MindRestore/Views/Home/HomeView.swift` — brain score card age comparison
- `MindRestore/Views/Assessment/ScoreRevealView.swift` — dramatic age comparison reveal
- `MindRestore/Views/Home/WorkoutCompleteView.swift` — age comparison in details
- `MindRestore/Views/Components/TikTokShareCard.swift` — age comparison on share card
- `MindRestore/Views/Progress/ProgressDashboardView.swift` — insights brain score card
- `MindRestore/Views/Settings/SettingsView.swift` — ability to update age in settings
