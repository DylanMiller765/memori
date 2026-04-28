# v2.0 Roadmap — Memo Doomscroll Blocker

**Milestone:** v2.0 ship
**Date:** 2026-04-27
**Phase Count:** 4 (Coarse granularity)
**Total Requirements:** 36

## Phase Summary

| # | Phase | Goal | Requirements | Success Criteria |
|---|-------|------|--------------|------------------|
| 1 | Onboarding Final | Lock down the 16-page redesign so every page lands at OB-system polish | ONB-01..09 (9 reqs) | 5 |
| 2 | Focus Mode + Entitlement | Resolve FamilyControls Distribution entitlement and ship train-to-unlock loop end-to-end | FOCUS-01..08, ENT-01..04 (12 reqs) | 5 |
| 3 | Brand Rename + ASO | Push the rename + ASO marketing assets to App Store Connect | BRAND-01..05, ASO-01..04 (9 reqs) | 4 |
| 4 | TestFlight + Submission | Final QA pass and App Review submission | REL-01..06 (6 reqs) | 4 |

**Coverage:** 36/36 v1 requirements mapped to a phase ✓

---

## Phase Details

### Phase 1: Onboarding Final

**Goal:** Lock down the 16-page redesigned onboarding so every page renders at OB-design-system polish on a clean device, with copy, animations, and interactions that match the brand voice and convert at top-of-funnel rates.

**Requirements:** `ONB-01`, `ONB-02`, `ONB-03`, `ONB-04`, `ONB-05`, `ONB-06`, `ONB-07`, `ONB-08`, `ONB-09`

**Already shipped (mark complete on phase entry):**
- ONB-01 Welcome bouncer scene + struggle-and-shove animation
- ONB-02 Notif Priming counter-cards
- ONB-03 Atmosphere lift behind progress bar

**Outstanding work:**
- ONB-04 Pain Cards receipt stack — fix back-stack visibility, "1 OF 6" font legibility, mascot clipping, perforation position, ambient text fallback
- ONB-05 Goals page redesign — Codex implementation in progress; needs tactile selection, no truncation, sharper labels
- ONB-06 Empathy page Option 3 (sunglasses Memo) — Codex full implementation
- ONB-07 Plan Reveal final tweaks per audit
- ONB-08 Light + dark mode parity audit on all 16 pages
- ONB-09 Receipt count handoff from Pain Cards → Plan Reveal personalized copy

**Success criteria:**
1. All 16 onboarding pages render correctly on iPhone 15+ at 60fps with no clipping, truncation, or rendering glitches
2. Pain Cards stack visibly grows as user taps "Caught me" (sunk-cost mechanic visible)
3. Goals page selection has tactile feedback (lift on tap, visible 0/3 progress, no truncated subtitles)
4. Plan Reveal personalizes copy based on `receiptCount` from Pain Cards
5. All animations respect Reduce Motion accessibility setting

**Why this is one phase:** All onboarding pages share the same design system (OB tokens), animation cadence pattern, and brand voice. Polishing them in one pass catches systemic issues that single-page work misses.

**Plans:** 8 plans

Plans:
- [x] 01-01-PLAN.md — Pain Cards polish (Wave 1) — completed 2026-04-27, commit `b6a98bc`
- [ ] 01-02-PLAN.md — Industry Scare polish (Wave 1)
- [ ] 01-03-PLAN.md — Goals polish (Wave 1)
- [ ] 01-04-PLAN.md — Plan Reveal polish + ONB-09 receipt-count verify (Wave 2; depends on 01)
- [ ] 01-05-PLAN.md — Commitment polish (Wave 2; depends on 03)
- [ ] 01-06-PLAN.md — Screen Time Access polish (Wave 3; depends on 05)
- [ ] 01-07-PLAN.md — Empathy verify-and-polish (Wave 4; depends on 06)
- [ ] 01-08-PLAN.md — Light/Dark + Reduce Motion sweep + ONB-01/02/03/09 verification (Wave 5; depends on 01-07)

---

### Phase 2: Focus Mode + Entitlement

**Goal:** Resolve the FamilyControls Distribution entitlement situation and ship the complete train-to-unlock loop. This is the v2.0 differentiator — without it, v2.0 is just a brand rename.

**Requirements:** `FOCUS-01`, `FOCUS-02`, `FOCUS-03`, `FOCUS-04`, `FOCUS-05`, `FOCUS-06`, `FOCUS-07`, `FOCUS-08`, `ENT-01`, `ENT-02`, `ENT-03`, `ENT-04`

**Critical path: entitlement decision gate at 2026-05-15**
- If Apple grants entitlement before May 15 → ship Focus Mode complete (FOCUS-01..08)
- If not granted by May 15 → execute fallback plan ENT-04: feature-flag Focus Mode, ship v2.0 as a brand+onboarding+gamification update

**Outstanding work:**
- ENT-01 Track entitlement status weekly (currently 3 requests pending, oldest April 19)
- ENT-02 Regenerate distribution provisioning post-grant
- ENT-03 Verify Focus Mode works on a clean TestFlight build
- ENT-04 Build feature flag scaffold for Focus Mode (off if entitlement absent)
- FOCUS-01..08 — finalize the loop: authorization → picker → shield → CTA → game → unlock minutes → cap

**Success criteria:**
1. User can grant FamilyControls authorization from onboarding without crashing
2. User-picked apps are shielded; tapping the shield deep-links to Memo's "play to unlock" CTA
3. Completing one brain game extends the unlock window and the app actually unlocks (verified on a clean TestFlight build)
4. Free tier hits 1-unlock/day cap; Pro tier unlocks unlimited times
5. Feature-flag fallback path proven (Focus Mode UI hides cleanly if entitlement absent)

**Why this is one phase:** FamilyControls work is gated entirely on the Apple entitlement; pulling it forward into another phase risks build-breakage on devs without the entitlement. Bundling FOCUS-01..08 with ENT-01..04 means a single phase decides whether v2.0 ships with or without the differentiator.

---

### Phase 3: Brand Rename + ASO

**Goal:** Push the rename to "Memo - Doomscroll Blocker" through App Store Connect and ship the ASO marketing assets that capture the `doomscroll` keyword.

**Requirements:** `BRAND-01`, `BRAND-02`, `BRAND-03`, `BRAND-04`, `BRAND-05`, `ASO-01`, `ASO-02`, `ASO-03`, `ASO-04`

**Outstanding work:**
- BRAND-01..02 ASC name + `CFBundleDisplayName` flip
- BRAND-03 ASC subtitle + keywords + description rewritten for v2.0 positioning
- BRAND-04 Localized metadata for es-MX, fr-FR, pt-BR aligned
- BRAND-05 In-app copy audit (any user-facing "Memori" → "Memo")
- ASO-01 Generate 5 App Store screenshots via `aso-appstore-screenshots` skill (benefits already confirmed in `aso_benefits.md`)
- ASO-02..03 Push metadata to all 10 localized storefronts via ASC API V2
- ASO-04 Privacy policy + terms reviewed (FamilyControls is Apple-private; should not change)

**Success criteria:**
1. App Store listing shows "Memo - Doomscroll Blocker" as the title with optimized subtitle/keywords
2. Home screen shows "Memo" after install (verified on clean device)
3. 5 ASO-optimized screenshots uploaded and live on the listing
4. All 10 localized storefronts have metadata aligned with v2.0 positioning

**Why this is one phase:** The rename and ASO assets all need to land together — pushing the name flip without updated screenshots/keywords creates a confusing listing. Done in one phase, the v2.0 listing transformation is a single coherent push.

---

### Phase 4: TestFlight + Submission

**Goal:** Final QA pass with external testers and submit v2.0 to App Review.

**Requirements:** `REL-01`, `REL-02`, `REL-03`, `REL-04`, `REL-05`, `REL-06`

**Outstanding work:**
- REL-01 Recruit 5+ TestFlight testers; cycle covers full onboarding completion, Focus Mode authorization (or fallback), train-to-unlock, paywall, all 10 games, streak, achievements, share cards
- REL-02 Final iOS audit: retain cycles (Memo's animations + closures), force unwraps, main-thread UI violations, light/dark mode parity on every screen
- REL-03 Confirm `ScreenshotDataGenerator` is `#if DEBUG`-wrapped (archive prerequisite)
- REL-04 Confirm `TARGETED_DEVICE_FAMILY = 1`
- REL-05 Archive + upload via `xcodebuild` CLI + ExportOptions.plist (per CLAUDE.md `/tmp/ExportOptions.plist` pattern)
- REL-06 Submit for App Review with explanatory notes covering FamilyControls usage + demo flow video

**Success criteria:**
1. TestFlight build accepted by Apple, distributed to ≥5 external testers
2. Zero P0/P1 bugs reported by testers across 7+ days
3. Archive build uploads to App Store Connect without errors
4. App Review submission accepted (no immediate rejection / metadata issues)
5. Build status moves to "Waiting for Review"

**Why this is one phase:** Release engineering is sequential by nature — TestFlight before App Review, archive before TestFlight. Splitting these phases would create artificial gates with no review value.

---

## Granularity Note

This roadmap uses **Coarse** granularity (4 phases for 36 requirements, ~9 reqs per phase). This was chosen because:

1. **v2.0 is a single coherent product release** — splitting into 8+ tiny phases would add ceremony without insight
2. **Some phases are time-gated** (Phase 2 on Apple entitlement, Phase 4 on TestFlight cycle) — finer granularity wouldn't compress the timeline
3. **YOLO mode + auto-advance** means phase boundaries are checkpoints, not approval gates — keeping them coarse reduces friction

If a phase grows complex during planning, `/gsd-plan-phase` can break it into multiple plans within the phase.

---

*Roadmap created: 2026-04-27*
