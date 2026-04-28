# Welcome Page Redesign — "The Bouncer Scene"

**Status:** approved by user, ready for implementation
**Target file:** `MindRestore/Views/Onboarding/OnboardingView.swift` — replaces the body of `welcomePage` (line 282) and removes `WelcomeFeedPressureBackground` (line 1589, dead code after this change)

## Goal

Replace the current generic "centered headline + bobbing mascot + typewriter + SF symbol constellation" Welcome layout with a brand-aligned hero scene that hooks in 2 seconds, matches the OB design system used by every other polished onboarding page, and sets the "you vs them" tension before the user reads a word.

This is the first impression — every user sees it. Conversion impact is top-of-funnel: bounce here = bounce on every downstream redesign.

## Concept

**The Bouncer Scene.** Memo (sunglasses pose, confident, unbothered) stands on the left holding the line. From the right edge, six real social media app logos cascade in — TikTok, Instagram, Snapchat, YouTube, Reddit, X — layered like a fan of cards being pushed against an invisible wall. The composition is deliberately asymmetric: Memo on the left, the app pile crashing in from the right. The "fight" is implied by the composition, not animated. After the entrance, everything is static — Memo is holding the line, nothing moves.

The app has no login or signup. Welcome → Name (page 1) → rest of flow.

## Layout

```
┌── progress (1/16) ────────────────┐

  eyebrow:  MEMO · DOOMSCROLL BLOCKER

  headline: Apps want you.
            Memo wants you back.        ← "Memo wants..." in OB.accent

  ┌────────── hero scene ──────────┐
  │                                │
  │   [ MEMO ]      [ TT ]         │  ← Memo (cool pose) on left
  │   sunglasses    [ IG ]         │    apps cascade from right
  │                 [ SC ]         │    layered/rotated
  │                 [ YT ]         │    back ones blurred
  │                 [ RD ]         │
  │                 [ X  ]         │
  │                                │
  └────────────────────────────────┘

  subline:  Block Apps. Train Your Brain.

  [          Let's go          ]

  🔒 No ads. No data sold. Just your brain fighting back.
```

Asymmetric on purpose. Memo holds ground; the apps pile in from one direction.

## Hero scene visual spec

### Mascot

- Asset: `mascot-cool` (sunglasses Memo, confident pose)
- Size: 200pt height, scaled to fit
- Position: ~35% from left edge of the hero scene container
- Glow: drop shadow `OB.accent.opacity(0.32)`, radius 28, y 12
- No bob animation. No rotation. Static after entrance.

### App pile (right side)

Six real logos cascade from off-screen-right, layered like a fan of cards. Front-most is sharpest; back-most is blurred and dim. The fan extends past the right safe area so it visually continues off-screen.

| Logo | Z-order | Size | Rotation | x-offset from container center | Opacity | Blur |
|---|---|---|---|---|---|---|
| `logo-tiktok` | front | 64pt | -8° | +30pt | 1.00 | 0 |
| `logo-instagram` | 2 | 60pt | +6° | +62pt | 0.92 | 0 |
| `logo-snapchat` | 3 | 56pt | -12° | +94pt | 0.85 | 0 |
| `logo-youtube` | 4 | 54pt | +9° | +122pt | 0.75 | 0.5pt |
| `logo-reddit` | 5 | 50pt | -6° | +148pt | 0.62 | 1pt |
| `logo-x` | back | 48pt | +14° | +170pt | 0.45 | 2pt |

Each logo is rendered as `Image(name)` resizable, scaledToFill, clipped to a `RoundedRectangle(cornerRadius: size * 0.22)` (matches iOS app icon corner ratio). Each card has a subtle shadow `Color.black.opacity(0.4)`, radius 8, y 4 to lift off the background.

### Background atmosphere

Small accent + coral blurred circles for "you vs them" color tension:

- `OB.accent.opacity(0.18)`, 280pt circle, blur 76, offset (-130, -180) — top-left behind Memo
- `OB.coral.opacity(0.10)`, 220pt circle, blur 68, offset (140, 200) — bottom-right behind app pile

### Removed

- `WelcomeFeedPressureBackground` struct (line 1589) — delete entirely. Only used by Welcome and replaced by the new scene.
- `mascotBob` `@State` and its `.repeatForever` animation — delete.
- `welcomeSubtitleVisible` `@State` and the typewriter logic — delete (typewriter is dropped per user constraint, also still used on Commitment so kept there).

## Copy

| Slot | Copy | Style |
|---|---|---|
| Eyebrow | `MEMO · DOOMSCROLL BLOCKER` | `OBEyebrow` (`.brand(size: 13, weight: .bold)`, `OB.accent`, tracking 1.0) |
| Headline | `Apps want you.\nMemo wants you back.` | `.system(size: 38, weight: .heavy, design: .rounded)`, `OB.fg`. The phrase "Memo wants you back." rendered in `OB.accent` via concat: `Text("Apps want you.\n") + Text("Memo wants you back.").foregroundColor(OB.accent)` |
| Subline | `Block Apps. Train Your Brain.` | `.system(size: 15, weight: .semibold, design: .rounded)`, `OB.fg2` |
| CTA | `Let's go` | via `OBContinueButton` |
| Footer | `🔒 No ads. No data sold. Just your brain fighting back.` | `.system(size: 12, weight: .semibold, design: .rounded)`, `OB.fg3` |

## Animation

| t | Action |
|---|---|
| 0.10s | Eyebrow + headline fade in (`opacity 0→1`, `offset y 8→0`, 0.4s easeOut) |
| 0.40s | App logos cascade in from right. Each: `offset x: +120→target`, `opacity: 0→target`, 0.5s spring response 0.55, damping 0.82. Stagger = 0.08s × index (so logo 0 starts at 0.40s, logo 5 starts at 0.80s). All six land within ~1.30s |
| 0.95s | Memo mascot enters: `scale: 0.92→1.0`, `opacity: 0→1`, 0.55s spring response 0.5, damping 0.78. On animation completion fire `UIImpactFeedbackGenerator(style: .light).impactOccurred()` |
| 1.30s | Subline fades up (`opacity 0→1`, `offset y 6→0`, 0.35s easeOut) |
| 1.50s | CTA + footer fade up (0.4s easeOut) |

Total entrance ≈ 1.7s. Slightly longer than other pages because there is a 2-beat story (apps arrive → Memo arrives to hold them). After 1.7s, everything is static — no idle bob, no breathing on the app pile.

## Behavior preserved

- Continue button advances `currentPage = 1` (→ Name page)
- `Analytics.onboardingStep(step: "welcome")` fires on Continue tap
- Page is dark-pinned via `.preferredColorScheme(.dark)` (matches sibling OB pages)
- No state changes to `OnboardingView` parent — just `welcomePage` body rewrite + cleanup of three local `@State` vars (`mascotBob`, `welcomeSubtitleVisible`, and any related)
- No new analytics events
- No login / signup affordance — the app does not have account auth

## Component scope

Two private helpers, file-local in `OnboardingView.swift`:

```swift
private struct WelcomeBouncerHero: View {
    let appsVisible: [Bool]   // length 6, staggered reveal flags
    let memoVisible: Bool
    // body: composes mascot + app pile + atmosphere
}

private struct WelcomeAppLogo: View {
    let assetName: String
    let size: CGFloat
    let rotation: Double
    let targetOpacity: Double
    let blur: CGFloat
    let visible: Bool
    let staggerIndex: Int
    // body: rounded-square logo with shadow + transition state
}
```

No new files. No changes to shared `Components/`. No new dependencies. The existing `OBEyebrow` and `OBContinueButton` are used as-is.

## Out of scope

- No changes to `OnboardingView.swift` page wiring beyond the `welcomePage` body
- No changes to other onboarding pages
- No changes to the progress bar component
- No changes to mascot assets (uses existing `mascot-cool`)
- No changes to logo assets (uses existing `logo-tiktok`, `logo-instagram`, `logo-snapchat`, `logo-youtube`, `logo-reddit`, `logo-x`)

## Acceptance criteria

1. Build succeeds via `xcodebuild ... -destination 'id=00008130-000A214E11E2001C'`
2. Welcome page renders correctly with all six app logos visible after entrance
3. Continue button (`Let's go`) advances to page 1 (Name page) and fires `Analytics.onboardingStep(step: "welcome")`
4. Page renders correctly in dark mode (the only mode it uses)
5. `WelcomeFeedPressureBackground` struct is fully removed from the file
6. Typewriter usage is removed from the Welcome page (still used on Commitment, untouched there)
7. No idle animation after the 1.7s entrance — everything is static
8. Light haptic fires when Memo lands (~0.95s + 0.55s = ~1.5s after page appears)
9. The app pile fan extends past the right edge of the safe area so it visually continues off-screen
10. The `mascot-cool` asset is the visible mascot (not `mascot-welcome`)
