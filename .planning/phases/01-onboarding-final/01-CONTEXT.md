# Phase 1: Onboarding Final - Context

**Gathered:** 2026-04-27
**Status:** Ready for planning

<domain>
## Phase Boundary

Polish — not redesign — the 16-page onboarding flow so every page renders at OB-design-system polish on a clean device. The flow is already strong overall; this phase identifies and fixes specific weak slides while leaving strong slides untouched.

**In scope:** targeted polish of 6 identified weak pages + Empathy verification on device + Reduce Motion + light-mode parity audit.

**Out of scope:** new onboarding pages, reordering the 16-page sequence, copy rewrites for slides not flagged weak, any work outside `MindRestore/Views/Onboarding/`.

</domain>

<decisions>
## Implementation Decisions

### Polish Targets (locked)

The user explicitly framed this phase as "polish, not redesign — find weak slides and improve them." Per the audit confirmed by the user, these 6 pages are the polish targets:

- **D-01: Pain Cards** — Fix the 6 known issues from Codex's first implementation (review committed). Specifically: (a) "1 OF 6" reads as "1 0F 6" because monospaced + heavy + uppercase makes O indistinguishable from 0 — drop `.textCase(.uppercase)` and use lowercase brand font; (b) mascot anchored to bottomLeading with `.offset(y: 58)` is clipped — reduce y-offset or extend parent frame; (c) `minHeight: 210` + double Spacer makes receipt too tall and airy — drop minHeight and let content size; (d) back-stack `[0.54, 0.34, 0.22]` opacity is invisible — bump to `[0.78, 0.55, 0.35]`; (e) `ReceiptPerforation` rendered in middle reads as content divider, not torn edge — move to bottom edge of receipt; (f) ambient back-slip text "saved receipt" / "feed loop" is meaningless filler — leave back slips blank when `savedReceipts` is empty (no body text, just labels).

- **D-02: Goals page** — Full polish per UI-SPEC contract. Currently divider-list aesthetic (Settings-screen vibes), subtitles truncating, no visible 0/3 progress. Move to OB-system: tactile selection feedback (lift on tap), visible progress chip, no truncation (`fixedSize(horizontal: false, vertical: true)`), sharper mission labels per UI-SPEC copy contract. 4th-tap = pulse-only-no-replacement (locked in UI-SPEC patch).

- **D-03: Plan Reveal** — Targeted tweaks per audit, not a rewrite. The UI-SPEC locked the 4-row plan card (vs 3-row+footnote). Apply the receipt-aware copy variant from UI-SPEC: if `receiptCount > 0`, line reads "You admitted to {N} feed loops. Memo goes after those first." If `receiptCount == 0`, fallback to "Memo still builds the plan around your picks."

- **D-04: Commitment** — Replace the typewriter bullets with a hero treatment matching the visual gravitas of Welcome bouncer. Hold-to-agree organic shape stays. Bullets get visual structure (numbered list with accent on the verb, similar to Differentiation receipt rows but warmer). Last impression must land.

- **D-05: Screen Time Access** — OB aesthetic pass. Keep the "Make the math personal / Bounce the worst offenders / Stays on your phone" reason rows + voice. Drop the 2019 SaaS layout (big headline + bullet list + bottom CTA). Move to OB-system pattern: eyebrow + dual-color headline + receipt-card or bouncer-style hero composition.

- **D-06: Industry Scare** — User flagged "can be way better tbh." Verify on device + identify specific weak elements during build (the $57B count-up beat is good, but the surrounding layout, copy, or post-count payoff may be weak). Apply targeted improvements once weak elements are isolated.

### Verify on Device

- **D-07: Empathy** — Codex was working on Option 3 (sunglasses Memo against social media wall) but current state on device is uncertain. Walk through it on iPhone during Phase 1 implementation and decide live whether it needs polish or is fine. If polish needed, apply within this phase. If it's already strong, skip.

### Build Distribution

- **D-08: Claude builds all 6 polish targets in this phase.** No Codex/Claude split. Reasoning: (a) all polish work is code-level and iteration-friendly; (b) Claude has continuous in-session context across the polish list; (c) Codex/Claude handoff loops are slower than direct iteration; (d) the UI-SPEC already locks the visual contract so Codex's design-eye contribution is captured upstream.

### Build Order

- **D-09: Build order = Pain Cards → Goals → Industry Scare → Plan Reveal → Commitment → Screen Time → Empathy verify.** Reasoning: Pain Cards has the most discrete fixes (highest velocity start), Goals is the next-highest-stakes redesign, Industry Scare is mid-flow so it needs to be checked once Pain Cards/Goals lock the OB pattern, Plan Reveal is post-paywall so lower funnel pressure but still important, Commitment is the closer, Screen Time can be deferred slightly because it's permission-related and less stylistically polish-heavy, Empathy is a verify-only step.

### Receipt Count Plumbing (data flow)

- **D-10: receiptCount flows via callback parameter.** `OnboardingPainCardsView.onContinue: (Int) -> Void` already exists. `OnboardingView` stores the value in a new `@State private var painCardsReceiptCount: Int = 0`. `OnboardingPersonalSolutionView` (Plan Reveal) gains a `receiptCount: Int` parameter. No persistence on User model — value is ephemeral to the onboarding flow.

### Animation Accessibility

- **D-11: Reduce Motion fallbacks applied to all 6 polish-target pages.** Use `@Environment(\.accessibilityReduceMotion) private var reduceMotion`. When true, replace slide / spring / shove animations with simple opacity fades (per UI-SPEC). Apply to existing strong pages opportunistically only if a defect is observed on device — not a sweep on already-shipped pages.

### Light/Dark Parity

- **D-12: ONB-08 is a final sweep at end of phase.** After all 6 polish targets are complete, walk all 16 pages in light + dark mode on device, capture any rendering defects, fix in the same phase commit batch.

### Claude's Discretion

- Specific spacing micro-tweaks (e.g., 14pt → 18pt nudges) within the OB-system scale documented in UI-SPEC.
- Exact spring response/damping values within the `[response: 0.5±0.1, damping: 0.78-0.82]` band documented in UI-SPEC.
- Placement of mascot peek vs hero treatment within each page (e.g., bottom-left vs bottom-right) — match the visual hierarchy already established by adjacent pages.
- Specific haptic timing offsets within the entrance arc.

</decisions>

<canonical_refs>
## Canonical References

**Downstream agents MUST read these before planning or implementing.**

### Phase 1 design contract
- `.planning/phases/01-onboarding-final/01-onboarding-final-UI-SPEC.md` — UI design contract (approved 2026-04-27, all 6 dimensions PASS). Covers OB tokens, Bricolage type scale, spacing, animation cadence, per-page visual specs for Pain Cards / Goals / Empathy / Plan Reveal, copywriting contract, accessibility rules. **Required reading.**

### Project context
- `.planning/PROJECT.md` — Project context, brand voice, key decisions
- `.planning/REQUIREMENTS.md` — Phase 1 covers ONB-01..09
- `.planning/ROADMAP.md` §"Phase 1" — Goal, success criteria

### Codebase reference
- `.planning/codebase/ARCHITECTURE.md` — SwiftUI MV pattern, state management
- `.planning/codebase/CONVENTIONS.md` — AppColors mandate, brand font, game pattern
- `.planning/codebase/STRUCTURE.md` — Where to add new code; onboarding lives in `MindRestore/Views/Onboarding/`
- `MindRestore/Utilities/DesignSystem.swift` — `AppColors.*`, `Font.brand(size:weight:)` extension
- `MindRestore/Views/Onboarding/OnboardingNewScreens.swift` — OB tokens at line ~1183, plus `OBEyebrow`, `OBContinueButton`, `OnboardingPainCardsView`, `ReceiptSlipView`, `CaughtStamp`, `ReceiptPerforation`, all of Comparison/Differentiation/Notif Priming
- `MindRestore/Views/Onboarding/OnboardingView.swift` — Root TabView, `welcomePage`, `pageAtmosphere` switch, `goalsPage`, `screenTimeAccessPage`, `commitmentPage`, helper structs
- `MindRestore/Views/Onboarding/FocusOnboardingPages.swift` — FO design tokens, `FocusOnboardIndustryScare`, `FocusOnboardPersonalUnlocks`

### Brand
- `docs/BRAND.md` — Anti-big-social-media voice, two-enemies doctrine, copywriting voice rules
- `docs/ONBOARDING_REDESIGN_BRIEF.md` — Brief for the 3 originally-redesigned screens (anti-patterns from prior Claude Design rounds)

### Prior Codex specs (for context — Pain Cards has known gap to fix)
- `docs/superpowers/specs/2026-04-27-memo-questions-receipt-stack-design.md` — Codex spec for Pain Cards receipt stack (high-level direction); first implementation has 6 known issues to fix per D-01

</canonical_refs>

<code_context>
## Existing Code Insights

### Reusable Assets

- **`OBEyebrow`** in `OnboardingNewScreens.swift:1197` — eyebrow component with `.brand(size: 13, weight: .bold)` + tracking, accepts custom color. Use on every polish target.
- **`OBContinueButton`** in `OnboardingNewScreens.swift:1208` — flat solid accent CTA button, 14pt corner radius. Replaces gradient buttons in Screen Time + Commitment polish.
- **`ReceiptSlipView`** in `OnboardingNewScreens.swift:1657` — receipt slip composition (label + perforation + body + CaughtStamp slot). Pain Cards polish edits this struct directly.
- **`MonoKeypad`** in `Views/Components/MonoKeypad.swift` — shared keypad for numeric entry (used by Number Memory in Quick Assessment). Not relevant to Phase 1 but referenced for completeness.
- **`mascot-cool`, `mascot-thinking`, `mascot-welcome`, `mascot-celebrate`, `mascot-lookout`, `mascot-working-out`** in `Assets.xcassets/` — pose catalog per UI-SPEC §"Mascot Pose Catalog."
- **`logo-tiktok`, `logo-instagram`, `logo-snapchat`, `logo-youtube`, `logo-x`, `logo-reddit`, `app-icon`** at 256×256 from coloured-icons MIT — used by Welcome / Notif Priming / Goals FeedHeistBackdrop / Empathy FeedWallScene.

### Established Patterns

- **Page entrance arc** — eyebrow + headline at 0.10s easeOut → hero at 0.40s spring → secondary elements at 0.95-1.30s → CTA at 1.5-2.45s. Match this on Commitment and Screen Time polish.
- **Atmosphere blurs** — Lifted to outer ZStack via `pageAtmosphere` switch in `OnboardingView` (architectural pattern). Any page wanting blurs that extend behind the progress bar adds a case to `pageAtmosphere`. Industry Scare may want this if its current background is too contained.
- **Mascot glow** — `OB.accent.opacity(0.32)` shadow, radius 28, y 12 — used by Welcome bouncer. Match this for any hero mascot moment.
- **Haptic rules** — Light haptic on Memo arrival, medium haptic on victory/major beat. Already standardized; reuse on polish targets.

### Integration Points

- **`OnboardingView` parent state** — Phase 1 adds `painCardsReceiptCount: Int` for D-10 plumbing. Plan Reveal receives via parameter.
- **`pageAtmosphere` switch** in `OnboardingView` — extend with case for any newly-atmospheric page during polish.
- **`OBEyebrow` and `OBContinueButton`** are now module-internal (no longer `private`) so all `OnboardingView` pages can use them. Pre-condition for Screen Time + Commitment polish.

</code_context>

<specifics>
## Specific Ideas

- The UI-SPEC's anti-pattern guards are non-negotiable: no Rx / medical LARP, no checkered placeholder mascot backgrounds, no SF-symbol icon tile constellations replacing real assets, no floating App Store testimonial cards on Plan Reveal, no contained card chrome on Empathy.
- The Welcome bouncer's struggle-and-shove animation is the gold standard for "polish that lands" — Commitment polish should aspire to similar visual gravitas (without copying the literal mechanic).
- For Pain Cards back-stack: capping at 3 visible saved receipts (per UI-SPEC) vs growing infinitely — already locked.
- For Industry Scare: user said "can be way better tbh" — investigate during implementation, the layout/payoff after the count-up is most likely the weak element (the count-up itself was praised earlier).

</specifics>

<deferred>
## Deferred Ideas

- **Onboarding A/B testing instrumentation** — PostHog event-level tracking on per-page bounce, time-on-page, CTA tap rate. Belongs in a future "Onboarding Analytics" phase post-launch.
- **Animated transitions between pages** (vs current `TabView` slide) — would require non-trivial gesture refactor. Defer to a v2.1+ polish phase.
- **Localization (es-MX, fr-FR, pt-BR) for new copy** introduced in Phase 1 polish — handled by Phase 3 (Brand Rename + ASO) which already covers `BRAND-04`.
- **Onboarding skip/resume mid-flow** — if user closes app mid-onboarding, return to last-completed page on next launch. Belongs in a future UX phase.
- **Mascot Rive animations on polish-target pages** — currently using static poses; Rive integration could replace mascot-cool with an animated cool-pose. Defer to v2.1+ polish.

</deferred>

---

*Phase: 1-onboarding-final*
*Context gathered: 2026-04-27*
