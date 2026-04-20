# Memori 2.0 Onboarding Redesign

## Identity Shift

Memori 2.0 is a **screen time blocker powered by brain training**. The onboarding must reflect this. The old identity ("competitive brain games") becomes a supporting feature, not the lead.

**Tagline:** "Train your brain. Block the noise."

## Current State

- 12-step onboarding: Welcome → Name → Goals → Age → Appearance → Bad News → Good News → 3-Game Assessment → Commitment → Notifications → Focus Mode → Privacy
- Focus Mode buried at step 10 as "one more thing"
- Brain assessment is 3 full games (~3 minutes)
- Welcome page pitches "Compete Globally", "10 Brain Games", "Track Your Brain Score"
- No paywall in onboarding
- Default appearance: system

## New Onboarding Flow (10 steps)

Narrative arc: **Scare → Proof → Hope → Solution → Commit**

### Step 1: Welcome

**Purpose:** Establish new identity immediately.

- Memo mascot with bobbing animation (existing `mascot-welcome` asset)
- TypewriterText: **"Train your brain. Block the noise."**
- Subtitle fades in: "The app that blocks distractions and sharpens your mind."
- Three feature pills (fade in after subtitle):
  1. Shield icon (coral): **"Block distracting apps"**
  2. Brain icon (violet): **"10 brain games to earn screen time"**
  3. Chart icon (accent): **"Track your Brain Age"**
- Continue button

### Step 2: Name Entry

**Purpose:** Personalization. Quick and skippable.

- No changes from current implementation
- Emoji: 👋
- "What should we call you?"
- Subtitle: "So Memo knows what to call you"
- TextField with keyboard toolbar (Continue / Skip)
- Skip button below when keyboard is hidden

### Step 3: Goals

**Purpose:** Prime user for Focus Mode by surfacing screen time goals first.

- Mascot: `mascot-goal`
- "Pick your focus" — "Select 1-3 goals"
- **Reorder `UserFocusGoal` cases** so display order is:
  1. `screenTimeFrying` — "My screen time is out of control" (FIRST)
  2. NEW: `doomscrolling` — "I doomscroll way too much"
  3. `attentionShot` — "I can't focus like I used to"
  4. `loseFocus` — "I lose my train of thought easily"
  5. `forgetInstantly` — "I forget things too quickly"
  6. `getSharper` — "I want to stay mentally sharp"
- Add new enum case `doomscrolling` to `UserFocusGoal` with rawValue `"doomscroll"`, icon `"iphone"`, color `AppColors.coral`

### Step 4: Age

**Purpose:** Collect real age for brain age comparison.

- No changes from current implementation
- Emoji: 🎂
- "How old are you?"
- "We'll compare your Brain Age to your real age"
- Wheel picker 18-99
- Privacy note: "Stored on your device only. Never shared."
- Continue + Skip buttons

### Step 5: The Scare

**Purpose:** Emotional hook. Create urgency.

- Mascot: `mascot-low-score` (sad)
- TypewriterText: **"Doomscrolling is frying"** → then "your memory" pops in red (existing animation)
- Subtitle: "Heavy phone users have the attention span of a goldfish. Literally."
- Button text changed from "Continue" to: **"Don't believe us? Let's test it."**
- Analytics: `onboarding.step` = `"scare"`

### Step 6: Quick Brain Age Test

**Purpose:** Prove the scare with real data. Fast enough to not lose users.

- **Two mini-games, shortened versions:**
  1. **Reaction Time** — 3 taps (not the full 5). Measures average reaction time in ms.
  2. **Visual Memory** — 3 rounds starting at 3x3 grid. Measures max level reached.
- Total time: ~60-90 seconds
- Use existing game engines (`ReactionTimeView`, `VisualMemoryView`) but create a `QuickAssessmentView` wrapper that:
  - Runs reaction time first, then visual memory
  - Shows minimal UI (no scores between games, just "Next test..." transition)
  - Collects raw scores and computes estimated brain age using `BrainScoring.brainAge(from:)` with only 2 domain scores (speed + visual, memory domain defaults to median)
- On completion, transitions to reveal with computed brain age
- Analytics: `onboarding.step` = `"quickAssessment"`

### Step 7: Brain Age Reveal + Hope

**Purpose:** Gut punch → then hope. Bridge to the solution.

- **Reveal phase:** Same gradient animation as current `ScoreRevealView`
  - "Your Brain Age: 49" (dramatic, full-screen gradient)
  - Pause for 2 seconds
- **Hope phase:** Transition to new screen (or animate within same view):
  - Mascot: `mascot-working-out`
  - TypewriterText: **"But your brain can bounce back"**
  - Subtitle: "5 minutes of daily brain training can reverse the damage."
  - NEW line: **"And we can block the apps that caused it."** (accent color, fades in after subtitle)
  - Button: **"Let's fix it"**
- Analytics: `onboarding.step` = `"reveal"`
- Save the `BrainScoreResult` from the quick assessment (source: `.onboarding`)

### Step 8: Soft Paywall

**Purpose:** Convert at peak motivation. Always skippable.

- Positioned after emotional peak (just saw brain age, feeling motivated to fix it)
- Show Pro vs Ultra comparison:
  - **Pro** ($3.99/mo): Unlimited brain games, all 10 exercises, insights
  - **Ultra** ($6.99/mo or $2.99/wk): Everything in Pro + Focus Mode (block unlimited apps), priority features
- Highlight Ultra as recommended (pre-selected)
- Show weekly price prominently: "$2.99/week" with annual savings callout
- 3-day free trial on annual plans
- **"Maybe later" skip button** — always visible, not hidden
- If user subscribes → continue to Focus Mode setup
- If user skips → continue to Focus Mode setup (free tier: 1 app limit)
- Analytics: `onboarding.step` = `"paywall"`, track `paywall.shown(trigger: "onboarding")`, `paywall.converted` or `paywall.dismissed`

### Step 9: Focus Mode Setup

**Purpose:** Set up the core feature. This is the solution to everything shown above.

- Flows directly from paywall — no "one more thing" framing
- Uses existing `FocusModeSetupView` sheet with 4 internal steps:
  1. **Intro:** "Take back your screen time" — block apps, play brain game to unlock
  2. **Pick Apps:** FamilyActivityPicker. **Free/Pro users: 1 app limit.** When tapping a second app, show inline upsell banner: "Upgrade to Ultra to block unlimited apps" with small "Upgrade" button that opens paywall sheet. Ultra users: unlimited.
  3. **Schedule:** Always-on or timed window (start/end time pickers)
  4. **Duration:** How long apps stay unlocked after playing (5/15/30/60 min)
- Requests FamilyControls authorization during this flow
- Notifications permission requested here too (needed for Focus Mode reminders)
- **"Not now" skip** available — skips entire Focus Mode setup
- Analytics: `onboarding.step` = `"focusModeSetup"` or `"focusModeSkipped"`

### Step 10: Commitment Contract

**Purpose:** Psychological commitment device. Closes the onboarding.

- Title: "{Name}'s Contract" (or "Your Contract" if no name)
- Bullets appear one by one with TypewriterText (existing animation):
  1. "I'll train my brain for 5 minutes a day"
  2. "I'll build my streak and not break it"
  3. "I'll let Memori block my distracting apps" (only if Focus Mode was set up)
  4. "I'll take back my screen time"
- If Focus Mode was NOT set up, bullet 3 becomes: "I'll put down the scroll and pick up the games"
- Hold-to-agree organic circle (existing implementation)
- Small privacy note at bottom: "All data stays on your device. No tracking. No cloud uploads."
- On completion: save user, mark onboarding complete, transition to main app
- Analytics: `onboarding.step` = `"commitment"`, `onboarding.completed`

## What Got Cut

| Removed | Reason |
|---------|--------|
| Appearance picker (step 4) | Default to dark mode. Changeable in Settings. |
| Privacy page (step 11) | Moved to a one-line note on the commitment page. |
| "Good News" as separate page | Merged into the brain age reveal (step 7). |
| Full 3-game assessment | Shortened to 2 games, 3 rounds each (~60-90 sec). |

## What Changed

| Area | Before | After |
|------|--------|-------|
| Identity | "Brain games that make you competitive" | "Train your brain. Block the noise." |
| Welcome features | Compete, 10 Games, Brain Score | Block apps, Brain games, Brain Age |
| Goals order | Screen time goal was last | Screen time goal is first, added doomscrolling |
| Assessment | 3 games, ~3 min | 2 games (3 rounds each), ~60-90 sec |
| Focus Mode position | Step 10, "one more thing" | Step 9, directly after emotional peak |
| Paywall | Not in onboarding | Soft paywall at step 8, always skippable |
| App picker | No limit enforcement | 1 app free/Pro, unlimited Ultra, inline upsell |
| Commitment bullets | Generic brain training | References Focus Mode and screen time |
| Default appearance | System | Dark |
| Total steps | 12 | 10 |

## Files to Modify

### Existing Files

1. **`MindRestore/Views/Onboarding/OnboardingView.swift`**
   - Restructure page order and reduce `totalPages` to 10
   - Update `welcomePage` with new tagline and feature pills
   - Update `goalsPage` to reorder goals
   - Rename `badNewsPage` → `scarePage`, change button text
   - Remove `goodNewsPage` (merge into reveal)
   - Replace `assessmentPage` with `QuickAssessmentView`
   - Update reveal page to include "block the apps that caused it" line
   - Add `paywallPage` between reveal and Focus Mode
   - Update `focusModePage` to remove "one more thing" framing
   - Update `commitmentPage` bullets to reference Focus Mode
   - Remove `appearancePage` and `privacyPage`
   - Set default appearance to dark in `completeOnboarding()`

2. **`MindRestore/Models/Enums.swift`**
   - Add `doomscrolling` case to `UserFocusGoal`
   - Add displayName: "I doomscroll way too much"
   - Add icon: "iphone"
   - Add color: `AppColors.coral`

3. **`MindRestore/Views/FocusMode/FocusModeSetupView.swift`**
   - Add 1-app limit for free/Pro users in the app picker step
   - Add inline upsell banner when user tries to select 2+ apps without Ultra
   - Wire up upgrade button to open paywall sheet

4. **`MindRestore/Views/Onboarding/OnboardingAssessmentView.swift`**
   - Keep for reference but replace usage with new `QuickAssessmentView`

5. **`MindRestore/Services/AnalyticsService.swift`**
   - Add `onboardingPaywallShown()` event
   - Update step names for new flow

6. **`MindRestore/Configuration.storekit`**
   - Update Ultra Weekly price from $3.99 to $2.99

### New Files

7. **`MindRestore/Views/Onboarding/QuickAssessmentView.swift`** (NEW)
   - Wrapper that runs shortened Reaction Time (3 taps) then Visual Memory (3 rounds)
   - Minimal UI between games
   - Computes estimated brain age from 2 domain scores
   - Returns `BrainScoreResult` on completion

8. **`MindRestore/Views/Onboarding/OnboardingPaywallView.swift`** (NEW)
   - Onboarding-specific paywall with Pro vs Ultra comparison
   - Ultra pre-selected and highlighted
   - Shows $2.99/week prominently
   - "Maybe later" skip button always visible
   - Tailored copy referencing brain age result: "Your brain age is 49. Let's fix that."

## Pricing Summary (v2.0)

| Tier | Weekly | Monthly | Annual |
|------|--------|---------|--------|
| **Free** | - | - | - |
| **Pro** | $1.99 | $3.99 | $19.99 (3-day trial) |
| **Ultra** | **$2.99** (was $3.99) | $6.99 | $39.99 |

Free: 3 games/day, try each game once, 1 blocked app in Focus Mode
Pro: Unlimited games, insights, all exercises
Ultra: Everything in Pro + Focus Mode with unlimited app blocking

## Edge Cases

- **User skips assessment:** No brain age to show. Skip reveal, go straight to paywall with generic copy ("Start your brain training journey").
- **User skips Focus Mode:** Commitment bullet 3 changes to "I'll put down the scroll and pick up the games."
- **User skips paywall AND Focus Mode:** They're a free brain-training-only user. That's fine. Focus Mode card on Home tab will re-engage them.
- **FamilyControls authorization denied:** Show error, offer to retry or skip. Don't block onboarding.
- **User already has Pro from v1:** Don't show Pro tier in paywall, only show Ultra upgrade.
- **Assessment scores are very good (brain age < real age):** Reveal says "Not bad! But can you stay sharp?" instead of scare copy. Still push Focus Mode as prevention.

## Success Metrics

- Onboarding completion rate (target: >70%, current unknown)
- Focus Mode setup rate during onboarding (target: >40%)
- Paywall conversion rate during onboarding (target: >5%)
- Assessment completion rate (target: >80% — shorter test should help)
- Drop-off by step (track via `onboarding.dropped_off` analytics)
