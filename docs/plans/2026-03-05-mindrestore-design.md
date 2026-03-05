# MindRestore — Design Document

**Date:** 2026-03-05
**Status:** Approved

## Overview

MindRestore is a native iOS app (Swift/SwiftUI, iOS 17+) for evidence-based cognitive training. It helps users rebuild memory through spaced repetition, dual n-back, and active recall exercises. All data local, monetized via StoreKit 2 subscription. Design language mirrors StretchCheck (Dylan's published app).

## Architecture

### Stack
- Swift 5.9+, SwiftUI, iOS 17.0 minimum
- SwiftData for persistence, StoreKit 2 for payments
- MVVM with `@Observable` (Observation framework, not ObservableObject)
- No external dependencies, no network calls

### Project Structure
```
MindRestore/
├── MindRestore.xcodeproj
├── MindRestore/
│   ├── MindRestoreApp.swift
│   ├── Models/
│   │   ├── User.swift
│   │   ├── Exercise.swift
│   │   ├── SpacedRepetitionCard.swift
│   │   ├── DailySession.swift
│   │   ├── PsychoEducationCard.swift
│   │   └── Enums.swift
│   ├── ViewModels/
│   │   ├── HomeViewModel.swift
│   │   ├── SpacedRepetitionViewModel.swift
│   │   ├── DualNBackViewModel.swift
│   │   ├── ActiveRecallViewModel.swift
│   │   ├── ProgressViewModel.swift
│   │   └── StoreViewModel.swift
│   ├── Views/
│   │   ├── Onboarding/OnboardingView.swift
│   │   ├── Home/HomeView.swift
│   │   ├── Exercises/
│   │   │   ├── SpacedRepetitionView.swift
│   │   │   ├── DualNBackView.swift
│   │   │   └── ActiveRecallView.swift
│   │   ├── Education/
│   │   │   ├── EducationFeedView.swift
│   │   │   └── EducationDetailView.swift
│   │   ├── Progress/ProgressView.swift
│   │   ├── Settings/SettingsView.swift
│   │   ├── Paywall/PaywallView.swift
│   │   └── Components/
│   │       ├── StreakBadge.swift
│   │       ├── ProgressRing.swift
│   │       ├── ExerciseCard.swift
│   │       ├── HeatmapCalendar.swift
│   │       └── ScoreChart.swift
│   ├── Services/
│   │   ├── SpacedRepetitionEngine.swift
│   │   ├── NotificationService.swift
│   │   └── StoreService.swift
│   ├── Content/
│   │   ├── EducationContent.swift
│   │   ├── SpacedRepetitionContent.swift
│   │   └── ActiveRecallContent.swift
│   ├── Utilities/
│   │   ├── Constants.swift
│   │   ├── DesignSystem.swift
│   │   └── Extensions.swift
│   └── Assets.xcassets/
```

### Data Flows
```
HomeView → HomeViewModel → queries User, DailySession via ModelContext
SpacedRepetitionView → SpacedRepetitionViewModel → SpacedRepetitionEngine → updates SpacedRepetitionCard
DualNBackView → DualNBackViewModel → DualNBackEngine (timer-driven) → creates Exercise
ActiveRecallView → ActiveRecallViewModel → ActiveRecallEngine → creates Exercise
PaywallView → StoreViewModel → StoreService (StoreKit 2) → updates User.subscriptionStatus
```

## Data Models

### User
SwiftData `@Model`. Fields: id, createdAt, currentStreak, longestStreak, lastSessionDate, subscriptionStatus (raw string → enum computed property), trialStartDate, onboardingCompleted, selectedGoals (raw strings → enum array), dailyGoal (default 3), notificationsEnabled, reminderTime, soundEnabled.

### Exercise
SwiftData `@Model`. Fields: id, type (raw string → ExerciseType enum), difficulty, completedAt, score (0.0-1.0), durationSeconds.

### SpacedRepetitionCard
SwiftData `@Model`. Fields: id, category (raw string → CardCategory enum), prompt, answer, easeFactor (default 2.5), interval, repetitions, nextReviewDate, lastReviewDate.

### DailySession
SwiftData `@Model`. Fields: id, date, exercises (relationship to [Exercise]), totalScore, durationSeconds.

### PsychoEducationCard
Plain struct (not SwiftData — hardcoded content). Fields: id, title, body, category, isRead (tracked via UserDefaults), sortOrder.

### Enums
- ExerciseType: spacedRepetition, dualNBack, activeRecall
- CardCategory: numbers, words, sequences, faces, locations
- SubscriptionStatus: free, trial, subscribed, lifetime
- EduCategory: socialMedia, cannabis, sleep, neuroplasticity, techniques
- ChallengeType: storyRecall, instructionRecall, patternRecognition, conversationRecall

All enums use String raw values for SwiftData compatibility.

## Exercise Engines

### SpacedRepetitionEngine
Pure logic class implementing SM-2 variant:
- `processRating(card, rating: 0-3)`: updates easeFactor, interval, repetitions, nextReviewDate
  - Rating 0 (Again): reset interval to 1, repetitions to 0
  - Rating >= 1: interval = previous interval × easeFactor
  - EF adjustment: EF += 0.1 - (3 - rating) × (0.08 + (3 - rating) × 0.02), min 1.3
- `getSessionCards(allCards, limit: 15)`: due cards first (nextReviewDate <= today), then new cards

### DualNBackEngine
Timer-driven game loop (2.5s intervals):
- State: currentN, positions[Int], letters[String], trialIndex, hits/misses/falseAlarms
- Each trial: random grid position (0-8) + random letter
- Match detection: compare current vs N-steps-ago for position and letter channels
- Score = max(0, hits - falseAlarms) / totalPossibleMatches
- Adaptive N: increase if >80% both channels, decrease if <50% either
- Free: N=1 position only. Pro: N=1-5 dual channel.
- Letters via AVSpeechSynthesizer (toggleable to text)

### ActiveRecallEngine
- Selects challenge from content pool, avoids repeats within session
- Challenge types: story recall (paragraph + questions), instruction recall (steps to reproduce), pattern recognition (colored grid), conversation recall (chat messages + questions)
- Display content for set duration, then ask questions
- Score: per-question accuracy averaged to 0-100%
- Free: 1/day. Pro: unlimited.

### Session Flow
1. "Start Training" → present exercises sequentially (count = dailyGoal, default 3)
2. Order: due spaced rep cards → dual n-back → active recall
3. Each completion creates Exercise record, adds to DailySession
4. Summary screen after all done, streak updated

## Content

### Spaced Repetition Cards
100 total: 20 per category (numbers, words, faces, locations, daily life).
- Numbers: digit sequences of length 4-8
- Words: lists of 5-10 words to recall in order
- Faces: text-based face description + name pairs
- Locations: grid-based location sequences
- Daily life: meeting/conversation memory scenarios

### Active Recall Challenges
40 total: 10 per type (story, instruction, pattern, conversation).
Each has display content, display duration, and 3-5 questions with answers.

### Psychoeducation
15 articles as specified in PRD, hardcoded in EducationContent.swift.

## Design System

Ported from StretchCheck, accent changed from orange to green.

| Token | Value |
|-------|-------|
| Accent | `#2E7D32` (green) |
| Card background | `Color(.secondarySystemGroupedBackground)` |
| Card corner radius | 16pt |
| Card padding | 16pt |
| Card shadow | black 4% opacity, radius 8, y offset 2 |
| Button corner radius | 14pt |
| Button vertical padding | 16pt |
| Section spacing | 24pt |
| Base spacing unit | 8pt |
| Screen edge padding | 16pt |

Components: AppCardModifier, AccentButtonStyle, StreakBadge, ProgressRing, ExerciseCard, HeatmapCalendar, ScoreChart.

Typography: system SF fonts using SwiftUI text styles (.largeTitle, .title2, .headline, .body, .caption). No custom fonts.

Animations: spring(response: 0.5, dampingFraction: 0.6) for celebrations, easeInOut(0.2) for state changes. Haptics via UIImpactFeedbackGenerator.

## Subscription

### StoreKit 2
- Products: com.mindrestore.pro.monthly ($6.99), com.mindrestore.pro.annual ($39.99), com.mindrestore.pro.lifetime ($14.99)
- StoreViewModel loads products on launch, handles purchase/restore
- Transaction.updates stream monitored, currentEntitlements checked on launch
- Entitlement stored in User.subscriptionStatus

### Feature Gating
- Spaced rep: free = numbers only, pro = all 5 categories
- Dual N-Back: free = N=1 position only, pro = adaptive N=1-5 dual
- Active Recall: free = 1/day, pro = unlimited
- Progress: free = heatmap + streak + totals, pro = charts + trends + memory score

### Paywall Triggers
1. After first completed session (soft, dismissible)
2. Tapping locked category/feature
3. Tapping locked analytics
4. Day 7 trial expiry

## Notifications

UNUserNotificationCenter. Permission requested after first completed session.
- Daily reminder at user-set time (default 9 AM)
- Streak risk at 8 PM if no session today
- Milestone celebrations at 7, 30, 100 day streaks
- NotificationService handles scheduling/cancellation

## Settings

List-based, grouped sections:
- Notifications (toggle + time picker)
- Appearance (dark/light/system via AppStorage)
- Daily goal (stepper 1-10)
- Sound toggle
- Subscription + restore
- Privacy statement
- About + citations
- Reset data (confirmation alert)
