# v2.0 Requirements

**Milestone:** v2.0 ship — "Memo - Doomscroll Blocker"
**Date:** 2026-04-27

## v1 Requirements (this milestone)

### Brand Rename

- [ ] **BRAND-01**: App Store listing name updated to "Memo - Doomscroll Blocker" (29 char limit)
- [ ] **BRAND-02**: Home-screen `CFBundleDisplayName` shows "Memo" on the device after install
- [ ] **BRAND-03**: ASC subtitle, keywords, and description updated to reflect Doomscroll Blocker positioning + ASO targets
- [ ] **BRAND-04**: Localized title/subtitle/keywords for es-MX, fr-FR, pt-BR locales aligned with rename
- [ ] **BRAND-05**: In-app references to "Memori" audited for any user-facing copy that should now say "Memo"

### Focus Mode (train-to-unlock loop)

- [ ] **FOCUS-01**: User can grant FamilyControls authorization from onboarding (priming page → system prompt)
- [ ] **FOCUS-02**: User can pick which apps to block via Apple's `FamilyActivitySelection` picker
- [ ] **FOCUS-03**: Picked apps are shielded by `ManagedSettings` and show a custom Memo shield when tapped
- [ ] **FOCUS-04**: Tapping the shield opens Memo and surfaces the "play a brain game to unlock" CTA
- [ ] **FOCUS-05**: Completing a brain game extends `ManagedSettings` shield exception by N minutes (configurable per game type)
- [ ] **FOCUS-06**: Earned unlock minutes are tracked, capped, and displayed in `FocusModeCard`
- [ ] **FOCUS-07**: Free tier sees 1 daily unlock-via-training; Pro tier unlimited
- [ ] **FOCUS-08**: Focus Mode setting can be toggled fully OFF from Settings (`FocusModeSettingsView`)

### FamilyControls Distribution Entitlement

- [ ] **ENT-01**: FamilyControls Distribution entitlement granted by Apple (3 requests submitted; awaiting approval)
- [ ] **ENT-02**: Distribution provisioning profile regenerated post-grant and committed to project
- [ ] **ENT-03**: TestFlight build succeeds with new entitlement on a clean device
- [ ] **ENT-04 (FALLBACK)**: If entitlement not granted by 2026-05-15, ship v2.0 without Focus Mode (gate UI behind feature flag)

### Onboarding Final Polish

- [ ] **ONB-01**: Welcome page bouncer scene + struggle-and-shove animation lands on iPhone (shipped 2026-04-27)
- [ ] **ONB-02**: Notif Priming counter-cards (TikTok feed-bait vs Memo unlock) lands on iPhone (shipped 2026-04-27)
- [ ] **ONB-03**: Page atmosphere lifted to outer ZStack so blurs extend behind progress bar (shipped 2026-04-27)
- [x] **ONB-04**: Pain Cards receipt stack — Codex implementation reviewed and gaps fixed (back-stack visibility, "1 OF 6" font legibility, mascot clipping, perforation position, ambient text fallback) — completed Plan 01-01 (2026-04-27, commit `b6a98bc`)
- [ ] **ONB-05**: Goals page redesign — Codex working; eliminate divider-list aesthetic, fix subtitle truncation, add tactile selection feedback, sharper mission labels
- [ ] **ONB-06**: Empathy page Option 3 (sunglasses Memo against social media wall) — Codex full implementation
- [ ] **ONB-07**: Plan Reveal final tweaks per audit (REDESIGN tier)
- [ ] **ONB-08**: All 16 onboarding pages render correctly in both light and dark mode (dark-pinned where applicable)
- [ ] **ONB-09**: Receipt count from Pain Cards passes through to Plan Reveal personalized copy

### App Store Marketing Assets

- [ ] **ASO-01**: 5 App Store screenshots designed and rendered (per `aso-appstore-screenshots` skill — confirmed benefits in memory `aso_benefits.md`)
- [ ] **ASO-02**: ASC metadata (subtitle, keywords, description, what's-new) updated for v2.0
- [ ] **ASO-03**: Optimized keywords pushed to all 10 localized storefronts via App Store Connect API V2
- [ ] **ASO-04**: Privacy policy + Terms updated if v2.0 changes data practices (FamilyControls is Apple-private, should not change)

### Release Engineering

- [ ] **REL-01**: TestFlight QA cycle with ≥5 testers covering: onboarding completion, Focus Mode authorization, train-to-unlock loop, paywall, all 10 games, streak, achievements, share cards
- [ ] **REL-02**: Common iOS issues audit before submission: retain cycles, force unwraps, main-thread UI violations, light/dark mode parity
- [ ] **REL-03**: `ScreenshotDataGenerator` confirmed wrapped in `#if DEBUG` so archive builds succeed
- [ ] **REL-04**: `TARGETED_DEVICE_FAMILY = 1` (iPhone-only) maintained
- [ ] **REL-05**: Release archive uploaded to App Store Connect via xcodebuild + ExportOptions.plist
- [ ] **REL-06**: App Review submission with explanatory notes covering FamilyControls usage rationale + demo flow

## v2 Requirements (deferred to v2.1 milestone)

These are explicitly held over to the next milestone:

- **GAM-01 (v2.1)**: Rank system (Bronze/Silver/Gold/Platinum text-only ranks)
- **GAM-02 (v2.1)**: Weekly leaderboard becomes default tab on Compete
- **GAM-03 (v2.1)**: Friend challenges (async link sharing, already built but shelved)
- **GAM-04 (v2.1)**: Custom profiles via CloudKit (replace Game Center default name display)
- **GAM-05 (v2.1)**: Aim Trainer game (next addition from Human Benchmark)
- **GAM-06 (v2.1)**: Real-time 1v1 (gated until 1K+ active users for matchmaking)

## Out of Scope (explicit exclusions)

- **Login / signup / accounts** — Memo has no auth, never will. Privacy-first positioning.
- **Lifetime subscription tier** — only monthly/annual/weekly Pro tier; no perpetual licenses.
- **Mixed training, spaced repetition, memory palace, active recall, prospective memory** — removed from UI permanently (boring per user testing).
- **Lottie animations** — Rive only for mascot animations.
- **iPad layout** — iPhone-only (TARGETED_DEVICE_FAMILY = 1).
- **Apple Watch companion app** — out of scope until iPhone product is mature.

## Traceability

Filled by roadmap (REQ-ID → phase mapping).

| REQ-ID | Phase |
|--------|-------|
| ONB-01 | PH-01 (already shipped, marks complete on phase entry) |
| ONB-02 | PH-01 (already shipped) |
| ONB-03 | PH-01 (already shipped) |
| ONB-04 | PH-01 |
| ONB-05 | PH-01 |
| ONB-06 | PH-01 |
| ONB-07 | PH-01 |
| ONB-08 | PH-01 |
| ONB-09 | PH-01 |
| FOCUS-01 | PH-02 |
| FOCUS-02 | PH-02 |
| FOCUS-03 | PH-02 |
| FOCUS-04 | PH-02 |
| FOCUS-05 | PH-02 |
| FOCUS-06 | PH-02 |
| FOCUS-07 | PH-02 |
| FOCUS-08 | PH-02 |
| ENT-01 | PH-02 |
| ENT-02 | PH-02 |
| ENT-03 | PH-02 |
| ENT-04 | PH-02 |
| BRAND-01 | PH-03 |
| BRAND-02 | PH-03 |
| BRAND-03 | PH-03 |
| BRAND-04 | PH-03 |
| BRAND-05 | PH-03 |
| ASO-01 | PH-03 |
| ASO-02 | PH-03 |
| ASO-03 | PH-03 |
| ASO-04 | PH-03 |
| REL-01 | PH-04 |
| REL-02 | PH-04 |
| REL-03 | PH-04 |
| REL-04 | PH-04 |
| REL-05 | PH-04 |
| REL-06 | PH-04 |

---

*Requirements scoped: 2026-04-27*
