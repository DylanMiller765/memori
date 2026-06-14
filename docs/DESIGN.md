# Memori Design System (v2.0)

The brain-training app for people tired of social media giants farming their attention. Fun, competitive, Gen Z, slightly pissed off. Not Lumosity-clinical. Not Calm-wellness. Not Opal-minimalist. Closer to Duolingo × NYT Games × Brick.

> **Sister docs that govern the same surfaces — read both before designing or writing copy:**
> - **Brand voice + copy rules:** Memori auto-memory `project_brand_voice.md` (informed-fear + defiance mode, line bank, do-say/don't-say, escalation across onboarding)
> - **Brand identity + positioning:** auto-memory `project_brand_identity.md` (the dual-promise USP, competitor framing)
>
> This document defines *visuals*. The voice docs define *words*. Don't ship UI without checking the voice doc for whatever copy goes on it.

> **Rename in flight:** the app is being renamed from "Memori" → "Memo - Doomscroll Blocker" (subtitle: "Block Apps. Train Your Brain."). Bundle ID stays. Codebase string sweep happens with the v2.0 onboarding redesign. Until that ships, in-code references still say "Memori" — match what's in the codebase, but new copy in design mocks should use "Memo."

---

## Token Namespaces

The app intentionally uses **three** color namespaces. They diverge because each surface has its own job.

| Namespace | Defined in | Surfaces | Posture |
|---|---|---|---|
| `AppColors` | `Utilities/DesignSystem.swift` | All standard tabs and pages | Adaptive light/dark, warm cream backdrop |
| `FM` | `Views/FocusMode/FocusModeCard.swift` (private) | The Focus Mode card | Pinned dark — a cinematic "island" on the light page |
| `PW` | `Views/Paywall/PaywallView.swift` (private) | Paywall + plans sheet | Pinned dark — premium, focused |

Don't unify them. The dark islands are the design.

---

## AppColors (canonical adaptive palette)

### Backgrounds
- `pageBg` — adaptive. Light `#F7F5F0` (warm cream), dark `#0A0A0F` (near-black)
- `cardSurface` — adaptive card fill, used by every `.appCard` and `.glowingCard`
- `cardBorder` — adaptive ring tracks, dividers, empty dots

### Text
- `textPrimary` ≡ `Color.primary`
- `textSecondary` ≡ `Color.secondary`
- `textTertiary` `rgb(0.62, 0.60, 0.58)`

### Brand
- `accent` `#4A7FE5` — the single most-used color. Buttons, rings, pills, dots
- `accentGradient` — `accent` → `rgb(0.35, 0.55, 0.95)`, top-leading → bottom-trailing
- `premiumGradient` — `accent` → `rgb(0.22, 0.42, 0.82)` (paywall surfaces use the `PW` palette in practice; this is for promo CTAs elsewhere)

### Cognitive Domain Colors
| Domain | Color | Hex |
|---|---|---|
| Memory | Violet | `rgb(0.55, 0.38, 0.75)` |
| Speed | Coral | `rgb(0.85, 0.40, 0.35)` |
| Attention | Sky | `rgb(0.35, 0.58, 0.82)` |
| Flexibility | Teal | `rgb(0.20, 0.60, 0.56)` |
| Problem Solving | Amber | `rgb(0.85, 0.65, 0.25)` |

### Accents
- `indigo` `rgb(0.38, 0.36, 0.70)` — sleep/depth
- `mint` `rgb(0.25, 0.68, 0.55)` — success, achievement unlocks
- `rose` `rgb(0.78, 0.35, 0.48)` — Chunking tile, social
- `coral` (also `speed`) — decay banner, flame icon, urgency

### Reaction-time-only
- `reactionWait` (red), `reactionGo` (green), `reactionTooEarly` (amber) — full-screen game backgrounds

### Dead — don't use, candidates for removal
- `cardElevated`, `cardBorderDark`, `error`, `warning`, `chartBlue`, `neuralGradient`, `warmGradient`, `coolGradient`

---

## Typography

- **Display:** `.system(size:, weight: .bold|.black, design: .rounded)` for scores, headlines, hero numbers
- **Body:** system default
- **Numerals:** always `.monospacedDigit()` for scores, timers, MM:SS countdowns, ranks
- **Hero numbers** (FocusModeCard timer, BrainScoreCard ring): 56pt monospaced
- **Section headers:** 13pt semibold, uppercased, 1.2 letter-spacing, `textSecondary`

---

## Modifiers (DesignSystem.swift)

| Modifier | What it actually does |
|---|---|
| `.appCard(padding:)` | `cardSurface` fill, 14pt corner radius, adaptive shadow (4pt dark / 8pt light) |
| `.heroCard(color:)` | Same as `.appCard` with bigger shadow (radius 12, y 4) |
| `.glowingCard(color:intensity:)` | Visually identical to `.appCard` — color param is vestigial. **Cleanup candidate** |
| `.pageBackground()` | `pageBg.ignoresSafeArea()` — root background on every tab |
| `.accentButton(color:)` | Full-width pill, white top-edge shimmer overlay, white text |
| `.gradientButton(_:)` | Same visual as `.accentButton` — gradient param is vestigial. **Cleanup candidate** |
| `.responsiveContent(maxWidth:)` | Constrains to 680pt. iPhone-only app, but kept for layout discipline |
| `.staggeredEntrance(index:)` | Spring-in: opacity 0→1 + y-offset 20→0, per-index delay |
| `.pulsingWhenIdle()` | 1.03× scale breathe loop after 2s |
| `.shimmer()` | Sweeping skeleton-loading gradient |
| `.edgeGlow(color:edge:)` | 60pt gradient top/bottom overlay for game-state feedback |
| `PressButtonStyle` | 0.96× scale + 2pt y-offset on press |

---

## Shared Components (Views/Components/)

- **`RiveMascotView`** — Memo (the brain mascot). Three moods (`.happy` / `.neutral` / `.sad`) driven by activity recency. Uses Rive state machine. The brand's emotional anchor — appears on Home, Profile, achievements
- **`BrainScoreCard`** — full (80pt ring) and compact (58pt ring) layouts. Used on Home stat pills, Insights, Profile
- **`SegmentedScoreRing`** — single-color arc on `cardBorder` track, score / 1000
- **`StreakWeekView`** — 7-day strip; filled accent = trained, outline = today, gray = missed
- **`StreakRingView`** — circular streak counter
- **`GameResultView`** — unified post-game screen with animated count-up + personal-best banner + stats + share
- **`AchievementToast`** — top slide-in for unlocks
- **`TrainingLimitBanner`** — "sweet spot" / "rest" advisory, bottom of Home
- **`TypewriterText`** — character-by-character reveal, used across onboarding
- **`TikTokShareCard`**, **`WeeklyReportShareCard`**, **`LevelUpShareCard`**, **`WorkoutShareCard`** — UIImage-rendered share assets
- **`SectionHeader`**, **`ColoredIconBadge`** — small layout primitives
- **`HeatmapCalendar`**, **`BrainScoreChart`** — Insights tab
- **`LeaderboardRankCard`** — Compete tab
- **`FreePlayPopup`** — one-time free-tier explainer on Train

---

## Per-Tab Layout

### Home
1. **Compact header** — greeting + streak flame badge (capsule, ultraThinMaterial)
2. **Decay banner** (conditional) — coral warning when brain score decayed overnight
3. **Mascot hero** — `RiveMascotView` 280pt, mood text, 3-dot indicator
4. **`FocusModeCard`** — the v2.0 hero. Dark island on the light page
5. **Brain stat pills** — Brain Score + Brain Age side-by-side, ultraThinMaterial pills with share / retake CTAs (or single "Discover Your Brain Score" card if no assessment yet)
6. **Weekly report card** (dismissible) — week-over-week delta + share
7. **Streak week card** — 7-day calendar + count + best
8. **Get Started card** OR **`TrainingLimitBanner`** (conditional)

### Train (`TrainingView` inline in `ContentView.swift`)
- **Daily limit banner** for free users (dot pill + Go Pro)
- **Referral banner**
- **Three categories**, each as a horizontal scroll of `GameCard` tiles:
  - **Memory** — Number Memory, Visual Memory, Chunking, Verbal Memory
  - **Speed** — Reaction Time, Math Speed, Speed Match, Color Match
  - **Focus** — Dual N-Back, Chimp Test
- **`FreePlayPopup`** overlay on first visit

### Compete
- `LeaderboardView` — Game Center–backed, `LeaderboardRankCard`. v2.0 adds Today / This Week / This Month filters

### Insights
- `ProgressDashboardView` — `BrainScoreChart`, `HeatmapCalendar`, `CognitiveDomainBar` rows

### Profile
1. **Player card** — `RiveMascotView` 120pt + name + join date + 3 stat pills (Level / Streak / Global Rank)
2. **XP progress** — small mascot 36pt + level name + bar + XP-to-next
3. **Achievements** — top 4 in numbered rows with mint "UNLOCKED" capsules + "All →"
4. **Settings** — chevron row to `SettingsView`

---

## Hero Components

### `FocusModeCard` (Home, v2.0 hero)

Six states driven by a `cardState` computed property, all on a 26pt-corner dark surface (`FM.surface` `#14141F`). Always pinned `.dark` via `.environment(\.colorScheme, .dark)` — the "Focus Mode island" sits on the warm light page intentionally. Re-evaluates every second via `TimelineView(.periodic)`.

| State | Eyebrow | Hero | CTA |
|---|---|---|---|
| `.notSetUp` | "MEMO'S WAITING" | 5 ghost app slots | Hire Memo → |
| `.idle` | "MEMO'S OFF DUTY" | Screen time stat (DeviceActivityReport or "AVG ~4.3 HRS") | Put Memo to Work → |
| `.active` | "MEMO ON PATROL" | Live MM:SS counter + locked app icons | bribe memo · Xm |
| `.cooldown` | "MEMO'S WINDED" | 110pt amber countdown ring | bribe memo / Got it |
| `.unlocked` | "MEMO'S CHILL" | MM:SS countdown + unlocked app icons | bribe memo +Xm (ghost) |
| `.scheduled` | "MEMO'S OFF THE CLOCK" | Moon icon + "Memo clocks back in at X:XX" | Wake Memo Up |

Voice rule: copy here is irreverent, anthropomorphizes the mascot ("bribe memo", "MEMO ON PATROL"). Don't sand this off — it's the brand voice in product form.

### `PaywallView` (v9-finch)

Pinned `.preferredColorScheme(.dark)`, `PW` token namespace. Single full-screen paywall, three plans accessible via "See other plans" sheet (Annual default).

Layout: brand glow ellipses (sky + brand at 30%, blurred) → 220pt mascot hero with 8 confetti dots → "Subscribe to PRO" gradient pill headline → mixed-weight subtitle → 4-feature list with icon badges → price line → gradient brand-blue CTA with brand-glow shadow → "See other plans" link → small Restore.

`PlansSheet`: 440pt detent, dark `#14141F` surface. Annual carries the amber "BEST VALUE · 52% OFF" capsule above its card.

### `BrainScoreCard`

Two layouts:
- **Full (80pt ring):** insight string + ring + brain-type Capsule + Brain Age (color-coded by age band) + percentile + 3 domain chips (MEM/SPD/VIS)
- **Compact (58pt ring):** ring + smaller badge + Brain Age and Percentile stacked

Brain-age color bands: green ≤25, accent 26–40, amber 41–55, coral 56+.

### Brain Age Reveal (`OnboardingFinaleSequence`)

Spotify-Wrapped-style reveal triggered from `QuickAssessmentView.onComplete`, presented as `.fullScreenCover`. Animated count-up to brain age, gradient background by age, RiveMascotView, share button. Continues directly into the paywall in the same cover (no chaining — single state machine).

---

## Onboarding (12 pages)

`TabView` with `.page(.never)`, manual dot indicator at bottom (hidden on assessment page), 12 dots total.

0. **Welcome** — bobbing `mascot-welcome` + "Train your brain. Block the noise."
1. **Name** — TextField + keyboard skip
2. **Goals** — pick 1–3 of 6 `UserFocusGoal` cards
3. **Age** — wheel picker 18–99
4. **Scare** — `mascot-low-score` + "Doomscrolling is frying your memory"
5. **Quick Assessment** — `QuickAssessmentView` with live background-color transitions; on complete → fullScreenCover with brain age reveal → paywall (`OnboardingFinaleSequence`)
6. **Personal Solution** — mirrors back selected goals as concrete solutions + App Store testimonial
7. **Notification Priming** — UNUserNotificationCenter request with timeout fallback
8. **Stat 144×** — `FocusOnboardA` (dark, FO tokens) + FamilyControls auth request
9. **Personal Unlocks 287×** — `FocusOnboardPersonalUnlocks` (dark) with real `DeviceActivityReport` if authorized, Settings deep-link if denied
10. **Focus Mode setup** — `FocusModeSetupView` embedded inline + "Not now" skip
11. **Commitment** — personalized contract, 4 typewriter bullets, 3-second hold-to-agree organic-circle button

---

## Mascot System

**Rive (`RiveMascotView`)** — animated, three moods (`.happy` / `.neutral` / `.sad`), driven by activity recency. Used on Home, Profile, achievements. Rive file: `memori (1).riv`, state machine `"State Machine 1"`, artboard `"Memori"`.

**Static images** — all `.renderingMode(.original).resizable().scaledToFit()`:
| Asset | Where | Size |
|---|---|---|
| `mascot-welcome` | Onboarding p0 | 220pt, bobbing |
| `mascot-lookout` | Onboarding goals / Feed Heist | 220–265pt wide, points flashlight toward feed wall |
| `mascot-low-score` | Onboarding scare p4 | 180pt |
| `mascot-goal` | FocusOnboardA | 200pt |
| `mascot-thinking` | FocusOnboardHowItWorks | 130pt, rotated -8° |
| `mascot-unlocked` | Paywall hero | 220pt + confetti |
| `mascot-locked-sad` | Exit offer sheet | 140pt, spring-in |
| `mascot-no-score` | Home fallback | 80pt |

**Mission-pose rule:** new static Memo poses are allowed for onboarding hero beats when the existing set cannot carry the scene. They must match the existing blue/purple/pink mascot system, preserve the glasses and rounded brain silhouette, and avoid extra-limb artifacts. Use them as character moments, not generic decoration.

---

## Dark-Mode-Only Surfaces

These views explicitly pin `.preferredColorScheme(.dark)` (or `.environment(\.colorScheme, .dark)`) — by design, not bug:

- `FocusModeCard` (the dark island)
- `PaywallView` + `PlansSheet`
- `FocusOnboardA`, `FocusOnboardHowItWorks`, `FocusOnboardPersonalUnlocks` (cinematic dark onboarding)

`ExitOfferSheet` does NOT pin dark — it follows the user's system appearance.

---

## What NOT to do

- No "today's session" curated workout card (removed v2.0 — replaced by Focus Mode hero)
- No flat list of exercise rows (use horizontal-scroll category cards)
- No fitness-app green
- No purple-on-white AI-slop gradients
- No fake testimonials (App Store quotes only — `sjvdheisjsbsis` and `Sana96t` are the real reviewers)
- No literal brain renders / 3D brain illustrations (use the Memo mascot)
- No corporate wellness-speak ("digital wellbeing", "mindful tech use") — see brand voice doc
- Specific consumer app names are allowed when they make the user-facing behavior concrete; avoid legalistic parent-company callouts unless the stat requires them

---

## Cleanup Backlog

- Dead `AppColors` constants: `cardElevated`, `cardBorderDark`, `error`, `warning`, `chartBlue`, `neuralGradient`, `warmGradient`, `coolGradient`
- `glowingCard` and `gradientButton` modifiers — color/gradient params are vestigial; either restore the visual or rename to match `appCard` / `accentButton`
- Compiled-but-unrouted view files (no entry from any current UI): `SpacedRepetitionView`, `ActiveRecallView`, `MemoryPalaceView`, `ProspectiveMemoryView`, `MixedTrainingView`, `WordScrambleView`, `MemoryChainView`, `EducationCardView`, `Workout*` family. Stub or delete next pass — they'll bloat the binary and confuse future readers
