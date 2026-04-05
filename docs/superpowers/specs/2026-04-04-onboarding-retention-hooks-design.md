# Onboarding Retention Hooks Design

**Goal:** Increase DAU retention from ~10% by adding psychological hooks to onboarding: bad news/good news pattern, commitment device, and mascot integration.

## New Onboarding Flow (10 pages)

| Page | Index | Screen | Mascot Asset | Purpose |
|------|-------|--------|-------------|---------|
| Welcome | 0 | Feature showcase | `mascot-wave` | Introduce app (existing) |
| Name | 1 | Text field | 👋 emoji | Collect name (existing) |
| Goals | 2 | Multi-select | `mascot-goal` | Pick focus (existing) |
| Age | 3 | Wheel picker | 🎂 emoji | Collect age (existing) |
| Appearance | 4 | Theme picker | SF Symbol | Choose light/dark (existing) |
| **Bad News** | **5** | Doomscroll warning | **`mascot-low-score`** | **Scare with goldfish stat** |
| **Good News** | **6** | Brain can bounce back | **`mascot-working-out`** | **Position Memori as fix** |
| Assessment | 7 | Brain Age test | n/a (full screen) | Measure baseline (existing, index shifted) |
| **Commitment** | **8** | Hold-to-agree contract | **`mascot-streak-fire`** | **Psychological commitment device** |
| Notifications | 9 | Enable reminders | **`mascot-celebrate`** | Request permission (existing, updated with mascot) |
| Privacy | 10 | Get Started | lock SF Symbol | Final screen (existing, index shifted) |

Total: 11 pages (was 8). Three new screens + updated notifications screen with mascot.

## New Screen: Bad News (index 5)

**Layout** — matches existing onboarding pattern:
- `mascot-low-score` image at top (height: 150pt, same as goals page mascot)
- Title: "Doomscrolling is frying your memory" — `.system(size: 28, weight: .bold, design: .rounded)`, word "memory" colored `Color.red`
- Subtitle: "Heavy phone users have the attention span of a goldfish. Literally." — `.subheadline`, `.secondary`
- Standard `continueButton` at bottom
- Analytics: `Analytics.onboardingStep(step: "badNews")`

## New Screen: Good News (index 6)

**Layout:**
- `mascot-working-out` image at top (height: 150pt)
- Title: "But your brain can bounce back" — same font, "bounce back" colored with `AppColors.accent`
- Subtitle: "Just 5 minutes a day of brain training can improve memory, focus, and reaction time." — `.subheadline`, `.secondary`
- Tertiary text: "Let's see where you stand." — `.caption`, `.tertiary`
- CTA button: "Take the Brain Age Test" (not "Continue") — `.gradientButton()`
- Analytics: `Analytics.onboardingStep(step: "goodNews")`

## New Screen: Commitment (index 8)

**Layout:**
- Title: "[Name]'s Commitment" — name from `enteredName` in accent color, "'s Commitment" in primary. If no name entered, just "Your Commitment"
- 4 commitment bullets in left-aligned text:
  - "I'll train my brain for **5 minutes a day**"
  - "I'll **build my streak** and not break it"
  - "I'll **put down the scroll** and pick up the games"
  - "I'll **sharpen my mind** every single day"
- Font: `.subheadline`, bold keywords via markdown or attributed string
- Below bullets: `mascot-streak-fire` image (height: 80pt, smaller than other mascot placements)
- **Hold-to-agree circle:**
  - 72pt circle with 3pt `AppColors.accent` stroke
  - Brain emoji (🧠) centered inside
  - On long press: circle fills clockwise with `AppColors.accentGradient` over 3 seconds
  - Continuous haptic feedback (light impact every 0.3s during hold)
  - On complete: medium impact haptic, circle snaps to filled state
  - Page auto-advances after 0.5s delay
- Label below circle: "Hold to commit" — `.system(size: 17, weight: .bold)`
- Sub-label: "Committing to goals boosts follow-through by 42%" — `.caption`, `.tertiary`
- Analytics: `Analytics.onboardingStep(step: "commitment")`
- **No skip option** — user must hold to proceed (creates stronger commitment)

## Updated Screen: Notifications (index 9)

**Change:** Replace the generic bell icon + circle with `mascot-celebrate` image (height: 150pt). Keep everything else the same (title, subtitle, buttons).

## Index Shifts

- Assessment moves from index 5 → 7
- Notifications moves from index 6 → 9
- Privacy moves from index 7 → 10
- `totalPages` changes from 8 → 11

## Implementation Notes

- All new screens are computed properties in `OnboardingView.swift` following existing pattern
- Background remains `AppColors.pageBg` for all new screens (no custom backgrounds)
- Dot indicators update automatically (already driven by `totalPages`)
- `completeOnboarding()` unchanged — still fires on privacy page
- No new state variables needed except the hold progress for commitment circle
