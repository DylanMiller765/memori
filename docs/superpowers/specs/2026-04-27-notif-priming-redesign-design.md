# Notif Priming Redesign — "Two Kinds of Nudges"

**Status:** approved by user, ready for implementation
**Target file:** `MindRestore/Views/Onboarding/OnboardingNewScreens.swift` — replaces the body of `OnboardingNotificationPrimingView` (lines 652–844)
**New asset:** `MindRestore/Assets.xcassets/app-icon.imageset/` (copy of `AppIcon-1024.png`)

## Goal

Replace the current generic "bell icon + 3 SF Symbol bullets + gradient button" treatment with a brand-aligned visual that converts the system permission prompt at 70-80% instead of the typical cold ~40%. The page sells the value of notifications BEFORE the system dialog fires by literally showing what Memo's notifications look like vs the algorithmic feed's.

## Concept

**Two stacked iOS-lock-screen notification cards** as the hero. Top card is a faded, slightly tilted TikTok engagement-bait notification (what the user is escaping). Bottom card is a bright Memo notification reflecting the actual Focus Mode reward loop the user just set up on the page before. Same app (TikTok) named on both notifications — Memo doesn't ban TikTok, Memo gives it back on the user's terms.

## Layout

```
┌─ progress header (existing) ─────────┐

   eyebrow:   TWO KINDS OF NUDGES

   headline:  One pulls you in.
              One pulls you out.

   ┌─────────── feed card ──────────┐
   │ [tiktok]  TikTok        now    │  ← dimmed, -3°
   │ 🔥 You haven't checked TikTok  │
   │    today. 47 friends just      │
   │    posted!                     │
   └────────────────────────────────┘

   ┌─────────── memo card ──────────┐
   │ [memo]    Memo          now    │  ← bright, +1°
   │ You earned 12 min of TikTok.   │
   │ Tap to unlock.                 │
   └────────────────────────────────┘

   caption: The feed nudges to harvest you.
            Memo nudges to give you time back.

   🔒 No spam. Once a day max.

   [    Let Memo nudge me    ]

              Not now
```

No connector glyph between cards — they breathe.

## Notification card visual spec

Both cards: 22pt corner radius, 14pt horizontal padding, 14pt vertical padding, full-width inside the page's 24pt horizontal page padding.

### Feed card (TikTok)

| Property | Value |
|---|---|
| Background | `OB.surface` |
| Border | `Color.white.opacity(0.06)`, 1pt |
| Icon | `Image("logo-tiktok")` at 38pt rounded square (corner radius 9) |
| App name | "TikTok" — `.brand(size: 14, weight: .heavy)` in `OB.fg2` |
| Timestamp | "now" — `.brand(size: 12, weight: .medium)` in `OB.fg3` |
| Body | "🔥 You haven't checked TikTok today. 47 friends just posted!" — `.brand(size: 14, weight: .medium)` in `OB.fg2`, 2-line clip |
| Whole card | `.opacity(0.55)`, `.rotationEffect(-3°)`, `.scaleEffect(0.97)` |
| Shadow | none |

### Memo card

| Property | Value |
|---|---|
| Background | `OB.surface` with overlay `OB.accent.opacity(0.05)` |
| Border | `OB.accent.opacity(0.35)`, 1.5pt |
| Icon | `Image("app-icon")` at 38pt rounded square (corner radius 9) |
| App name | "Memo" — `.brand(size: 14, weight: .heavy)` in `OB.fg` |
| Timestamp | "now" — `.brand(size: 12, weight: .medium)` in `OB.fg3` |
| Body | "You earned 12 min of TikTok. Tap to unlock." — `.brand(size: 14, weight: .heavy)` in `OB.fg`, 2-line clip |
| Whole card | full opacity, `.rotationEffect(+1°)` |
| Shadow | `OB.accent.opacity(0.32)`, radius 24, y 10 |

Card spacing: 18pt vertical gap between the two cards. Cards do NOT visually overlap.

## Copy

| Slot | Copy |
|---|---|
| Eyebrow | `TWO KINDS OF NUDGES` |
| Headline | `One pulls you in.\nOne pulls you out.` (38pt, heavy, rounded design, `OB.fg`) |
| Feed body | `🔥 You haven't checked TikTok today. 47 friends just posted!` |
| Memo body | `You earned 12 min of TikTok. Tap to unlock.` |
| Caption | `The feed nudges to harvest you. Memo nudges to give you time back.` (15pt, semibold, `OB.fg2`) |
| Privacy line | `🔒 No spam. Once a day max.` (12pt, semibold, `OB.fg3`) |
| Primary CTA | `Let Memo nudge me` (via `OBContinueButton`) |
| Skip button | `Not now` (subhead, semibold, `OB.fg2`) |
| Denied state caption | `Permission was denied earlier — open Settings to enable.` |
| Denied state CTA | `Open Settings` |
| Timeout state caption | `Couldn't request permission. Tap to retry.` (`OB.coral`) |
| Timeout state CTA | `Try Again` |

## Entrance animation

| t | Action |
|---|---|
| 0.10s | Eyebrow + headline fade in (`opacity 0→1`, `offset y 8→0`, 0.4s easeOut) |
| 0.40s | Feed card slides in from above (`offset y -40→0`, `opacity 0→0.55`, 0.5s spring response 0.55, damping 0.82) |
| 0.75s | Memo card slides up from below (`offset y 30→0`, `opacity 0→1`, 0.55s spring response 0.5, damping 0.78). On animation completion, fire `UIImpactFeedbackGenerator(style: .light).impactOccurred()` |
| 1.20s | Caption + privacy line fade in (0.35s easeOut) |
| 1.45s | CTA + skip button fade up |

Total entrance ≈ 1.5s — matches Differentiation pacing.

## Behavior preserved (must not change)

The redesign is a pure visual refactor. All existing behavior in `OnboardingNotificationPrimingView` stays intact:

- 8s timeout race against the system permission prompt
- `previouslyDenied` detection via `UNUserNotificationCenter.current().notificationSettings()` on appear
- Settings deep-link branch when previously denied
- `onResult: (Bool) -> Void` callback contract (parent advances on either outcome)
- Analytics events fire on the same triggers: `notificationsEnabled`, `notificationsDeclined`, `notificationsTimeout`, `notificationsSkipped`
- `permissionTask` cancellation on disappear
- The retry / timeout error flow

The state variables `headlineAppeared`, `bulletsAppeared`, `requesting`, `permissionTask`, `showTimeoutError`, `previouslyDenied` are renamed/refined as needed for the new animation timeline, but the permission flow logic is byte-for-byte preserved.

## Component scope

Two private views, file-local in `OnboardingNewScreens.swift` (NOT extracted to `Components/`):

```swift
private struct NotifMockupCard: View {
    enum Variant { case feed, memo }
    let variant: Variant
    let appIcon: Image
    let appName: String
    let body: String
    // body: builds the card according to variant
}
```

No new files. No changes to `MonoKeypad`, `OBContinueButton`, `OBEyebrow`, or any shared component. The font extension `.brand(size:weight:)` already exists.

## New asset

Create `MindRestore/Assets.xcassets/app-icon.imageset/`:

- `Contents.json` — standard imageset descriptor pointing at the PNG
- `app-icon.png` — copy of `MindRestore/Assets.xcassets/AppIcon.appiconset/AppIcon-1024.png`

Imagesets do not need to be registered in `project.pbxproj` because the `.xcassets` folder is a folder reference (verified via `grep -c "logo-tiktok\|mascot-thinking\.imageset" project.pbxproj` returning 0 — none of the existing imagesets are individually tracked).

## Out of scope

- No changes to the actual notification copy/scheduling in `NotificationService.swift`. The "You earned X min" notification on the mockup is illustrative — production notifications are governed by the existing 8 notification types and may not match this exact copy.
- No changes to `OnboardingView.swift` page wiring — the parent still presents `OnboardingNotificationPrimingView { granted in ... }` with the same callback.
- No changes to the page's position in the flow (still page 14 between Focus Mode and Commitment).

## Acceptance criteria

1. Build succeeds via `xcodebuild ... -destination 'id=00008130-000A214E11E2001C'`
2. Both light + dark mode render correctly (page is dark-pinned via `.preferredColorScheme(.dark)` like sibling pages)
3. Granting permission via the system prompt still fires `Analytics.onboardingStep(step: "notificationsEnabled")` and calls `onResult(true)`
4. Declining still fires `notificationsDeclined` + `onResult(false)`
5. Timeout still fires `notificationsTimeout` and shows the retry CTA
6. Skip via "Not now" still fires `notificationsSkipped` and calls `onResult(false)`
7. Previously-denied state surfaces "Open Settings" CTA that deep-links to `UIApplication.openSettingsURLString`
8. Entrance animation does not block CTA — buttons are tappable from the moment they appear
9. The Memo card icon is the actual Memo app icon (loaded from `Image("app-icon")`)
10. The TikTok card icon is the existing `logo-tiktok` asset
