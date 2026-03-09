# Memori Next Steps
> **Date:** 2026-03-09 | **Status:** Ready to implement

---

## DONE THIS SESSION

- [x] Reaction Time: full-screen red/green restored, tab/nav bar hidden during gameplay
- [x] Removed lifetime subscription entirely
- [x] Train tab: no more locks, games always playable, Daily Challenge card added
- [x] Free exercise counter moved to Train tab, dots = remaining games
- [x] Activity calendar: proper monthly calendar with day numbers + weekday alignment
- [x] ConfettiSwiftUI package added (replaces custom confetti)
- [x] Share card wired to Reaction Time results (TikTok-style ReactionTimeShareCard)
- [x] Brain Score reveal now uses TikTokBrainScoreCard for share image
- [x] Spaced rep & memory palace removed from UI (boring)
- [x] Adaptive difficulty confirmed available to all (not paywalled)

---

## P0 — DO NEXT (Highest Impact)

### 1. Redesign Insights Tab
The Overview section repeats streak/session/exercise stats already on Home. Pro content (score trend + weekly avg) isn't valuable enough.

**Kill:**
- Remove "Overview" section (Sessions, Exercises, Training Time, Total XP cards — all duplicated)

**Add (Free):**
- **Personal Records** section — best score per exercise with date achieved
- **Consistency Score** — % of days trained this month (visual ring)
- **Exercise Library Progress** — "You've tried 4 of 8 games"

**Add (Pro):**
- **Cognitive Domain Progress** — sparkline charts per domain (Memory, Speed, Attention, Flexibility) showing trend over time
- **Trending indicators** — "+12% faster this week" per exercise
- **Weekly Review card** (shareable) — "12 exercises, 45 min training, best score: 94%"
- **Accuracy by Exercise** — which games you're best/worst at
- **Time-to-Mastery** — "3 more sessions to hit 90% on Color Match"

### 2. Add Share Buttons to ALL Exercise Results
Currently only ReactionTime has a share button. These 7 exercises are missing share:
- [ ] VisualMemoryView
- [ ] DualNBackView
- [ ] SequentialMemoryView
- [ ] ColorMatchView
- [ ] SpeedMatchView
- [ ] ChunkingTrainingView
- [ ] MathSpeedView

Pattern: copy ReactionTimeView's ShareLink + ReactionTimeShareCard approach. Create a generic `ExerciseShareCard` or per-exercise cards.

### 3. Improve Paywall Messaging
- Add explicit "Free: 3 games/day. Pro: Unlimited." comparison
- Personalize exit offer with user's stats
- Add smart trigger after personal bests ("Unlock unlimited to keep improving")

---

## P1 — MEDIUM PRIORITY

### 4. Achievement Share Moments
- Add "Share" button to AchievementToast when it appears
- Create AchievementShareCard (reuse TikTok card dark style)

### 5. Leaderboard Share
- Add ShareLink to LeaderboardRankCard ("I'm ranked #47 in Reaction Time!")
- Remove or replace "1v1 Coming Soon" dead-end card

### 6. Weekly Review Feature
- Auto-generate a "Week in Review" card every Sunday
- Shows: exercises completed, total time, domains improved, best moment
- Shareable card for social media

### 7. Fix Restore Purchases Access
- Move "Restore Purchases" out of pro-only section in Settings
- Free users need access to restore expired purchases

### 8. Lottie Animations
- Add Lottie for: level-up celebrations, achievement unlocks, brain score reveal
- High perceived polish boost

---

## P2 — POLISH

### 9. Onboarding Improvements
- Reduce friction: skip assessment on first launch, offer it after 3 exercises
- Add quick tutorial overlays for first exercise played

### 10. Sound Assets
- SoundService exists with methods but needs actual audio files
- Need: correct/wrong chimes, exercise complete fanfare, UI taps

### 11. Deep Linking
- Custom URL scheme for share links
- Notification deep links (tap notification -> go to exercise)

### 12. ProspectiveMemory Trigger Randomization
- Already partially fixed but could be more random

---

## PACKAGES INSTALLED
- **ConfettiSwiftUI** (1.1.0) — celebration confetti animations

## PACKAGES TO CONSIDER
- **Lottie** (Airbnb) — rich animations for celebrations/transitions
- **SwiftUI Shimmer** — loading skeleton screens
- Built-in iOS 17+: Charts framework, TipKit (tooltips) already available

---

## ARCHITECTURE NOTES
- Build artifacts in `build/` now gitignored
- SPM package reference: ConfettiSwiftUI via XCRemoteSwiftPackageReference in pbxproj
- PBX IDs: CONFETTI00000001 (package ref), CONFETTI00000003 (product dep), CONFETTI00000005 (build file), CONFETTI00000006 (frameworks phase)
- Lifetime product removed from Configuration.storekit and StoreService
- ReactionTimeShareCard lives in TikTokShareCard.swift alongside other share cards
