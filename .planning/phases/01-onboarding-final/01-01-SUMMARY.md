---
phase: 01-onboarding-final
plan: 01
subsystem: onboarding
tags: [ui, polish, pain-cards, swiftui, dark]
requires: []
provides:
  - "Polished OnboardingPainCardsView matching UI-SPEC §Page 2 line-for-line"
  - "PainReceiptSlip component (tall slip, top-edge perforation)"
  - "Top-edge ReceiptPerforation shape"
  - "receiptCount handoff via onContinue: (Int) -> Void preserved"
affects:
  - "OnboardingView.painCardsPage (consumes receiptCount, signature unchanged)"
  - "OnboardingPersonalSolutionView (Plan Reveal, downstream consumer of receiptCount)"
tech-stack:
  added: []
  patterns:
    - "OB design tokens (OB.bg / OB.surface / OB.accent / OB.coral / OB.fg* / OB.border)"
    - "Reduce Motion fallback via @Environment(\\.accessibilityReduceMotion)"
    - "Page-level VStack: header → receipt stack → mascot peek (ZStack overlay) → action buttons"
key-files:
  created: []
  modified:
    - "MindRestore/Views/Onboarding/OnboardingNewScreens.swift"
decisions:
  - "Top-edge perforation rendered at y=0 of its frame; parent layout insets 16pt H + 11pt T from the slip's top edge so the dotted dashes read as the torn-off coupon header"
  - "Back slips capped at 3 visible (per UI-SPEC line 431), no infinite stack growth"
  - "Empty state (savedReceipts == []): zero back slips rendered — ambient filler removed entirely (D-01f)"
  - "Active slip's micro progress reads '3 of 6' in lowercase brand 11pt semibold (NOT monospaced caps), eliminating the '1 0F 6' misread (D-01a)"
  - "Mascot anchor moved from frame(width: 74, height: 74) at offset (-8, 16) → frame(height: 96) at offset (4, 18) so the peek lands behind the back-stack but never crosses the confession body or the action buttons"
metrics:
  duration_minutes: 12
  tasks_completed: 1
  files_changed: 1
  commits: 1
  completed: 2026-04-27
---

# Phase 01 Plan 01: Pain Cards Polish — Summary

**One-liner:** Polished `OnboardingPainCardsView` to match UI-SPEC §"Page 2 — Pain Cards" line-for-line — fixed the 6 known D-01 defects (invisible back-stack, "1 0F 6" misread, mid-slip perforation, mascot clipping, airy receipt sizing, meaningless ambient back-slip filler) and added a Reduce Motion fallback that preserves haptics.

## What Changed

Single Swift file edit. Replaced the prior split layout (large headline above a small `EvidenceMiniSlip` rail) with a single tall receipt slip that carries the confession text inside it. Restructured ancillary types to match.

### File: `MindRestore/Views/Onboarding/OnboardingNewScreens.swift`

| Before | After |
|---|---|
| Eyebrow: `Text("Memo pulled your receipts.")` styled inline | `OBEyebrow(text: "MEMO FOUND THE RECEIPTS")` — verbatim UI-SPEC copy + shared component |
| Subcopy: `"Be honest. Memo uses this to build your fight plan."` | `"Tap what feels painfully familiar. Memo uses it to build your fight plan."` — verbatim UI-SPEC |
| Two separate views: `questionHero` (big text, minHeight 156) + `evidencePromptRail` (small mini slip, height 68) | One `PainReceiptSlip` (minHeight 210, 18pt H/V padding, 16pt corner, OB.surface, OB.accent border at 0.45 opacity 1.5pt) carrying confession text inline |
| Micro progress: `"\(currentIndex + 1)/\(painCards.count)"` (e.g. `1/6`) in `.brand(15, .heavy)` accent-colored, NOT lowercase | `"\(currentIndex + 1) of \(painCards.count)"` (e.g. `3 of 6`) in `.brand(11, .semibold)` `OB.fg3` — kills the "0F" misread |
| Active label: `"receipt saved here"` | `"current receipt"` (lowercase, brand 12pt medium, OB.fg3) per UI-SPEC |
| Back-slip body: `shortReceiptLabel(text)` rendering first 3 words of the saved confession | Back slips render ONLY the `"saved receipt"` label, body intentionally blank |
| Ambient empty state: 2 placeholder back slips with `text: ""` rendered behind the active slip | Empty state: zero back slips — front slip stands alone until the user lands their first `Caught me` |
| Back-stack geometry: `[4°, -3°, 6°]` rotation, `[9, -7, 13]` x, `[12, 24, 36]` y | UI-SPEC values: `[5°, -4°, 8°]` rotation, `[10, -8, 14]` x, `[18, 36, 54]` y |
| Back-stack opacity: `[0.78, 0.55, 0.35]` (already correct in code, kept) | Unchanged — values are correct per UI-SPEC |
| `ReceiptPerforation`: drew at `y = rect.midY` (middle of frame, read as content divider) | Draws at `y = 0` (top edge of its frame, which the parent layout pins 11pt down from the slip's top with 16pt horizontal inset) — reads as a torn-off coupon header |
| Mascot: `frame(width: 74, height: 74)`, offset `(-8, 16)`, anchored to a parent `frame(height: 132)` that clipped it on small screens | `frame(height: 96)` (no width cap, aspect-fit), offset `(4, 18)` — anchored to the receipt-stack ZStack so it can tuck behind the back-stack without crossing the active confession body or the action buttons |
| `Caught me` settled-card opacity: `0.54` (looked like a faded ghost) | `0.78` (matches back-stack slip 1 opacity, so the slide-back animation visually resolves into the back-stack) |
| `Not me` flick: 0.24s easeIn over 0.26s asyncAfter | 0.30s easeIn over 0.30s asyncAfter — matches UI-SPEC §"Animation Cadence Pattern" `Pain Cards Not me` row exactly |
| Reduce Motion: only handled the `Not me` opacity-out path; entrance springs were unconditional | Entrance, Caught-me stamp, and Not-me flick all gated on `reduceMotion` — when true, all swap to 0.18s opacity fades; haptics (medium on Caught, light on Not me) still fire |

### Component restructure inside the same file

- `EvidenceMiniSlip` (small horizontal pill, ~68pt tall) → renamed and rebuilt as `PainReceiptSlip` (tall slip, ≥210pt). Same call sites, new structure.
- `ReceiptBackItem`: simplified — only carries `id` (the prior `text` and `isAmbient` fields were used only to drive ambient-state filler text that we removed).
- `ReceiptPerforation`: `path(in:)` now draws at `y = 0` instead of `y = rect.midY`.
- `CaughtStamp`: unchanged. Already correct per UI-SPEC (mono 22pt heavy, tracking 1.8, OB.coral, 2pt rounded-rect border @ 72%, rotation -8°).

## Acceptance Criteria — All PASS

- [x] No `"1 OF 6"` / `"QUESTION X/Y"` chrome anywhere in `OnboardingPainCardsView`
- [x] Back-stack opacities are exactly `[0.78, 0.55, 0.35]`
- [x] Old invisible back-stack values (`[0.05/0.22/0.34/0.54]` triples) absent
- [x] Only `"saved receipt"` is rendered as a Text view (back slip label); no `"feed loop"` filler
- [x] `"Caught me"` and `"Not me"` button strings present
- [x] No `"Yep"` / `"Nah"` strings
- [x] `minHeight: 210` present on the front slip
- [x] `@Environment(\.accessibilityReduceMotion)` bound inside `OnboardingPainCardsView`
- [x] `onContinue: (Int) -> Void` callback signature preserved
- [x] `xcodebuild` returns `BUILD SUCCEEDED` on device target `00008130-000A214E11E2001C`
- [x] App installed on device — bundle id `com.dylanmiller.mindrestore`

## Build Evidence

```
xcodebuild -project MindRestore.xcodeproj -scheme MindRestore \
  -configuration Debug -destination 'id=00008130-000A214E11E2001C' \
  -allowProvisioningUpdates -derivedDataPath build
```

Result: `** BUILD SUCCEEDED **`

```
xcrun devicectl device install app --device 00008130-000A214E11E2001C \
  build/Build/Products/Debug-iphoneos/MindRestore.app
```

Result: `App installed: com.dylanmiller.mindrestore`

## Deviations from Plan

**Auto-applied (Rule 3 — auto-fix blocking issues):**

1. **[Rule 3 — Structural] Combined the headline-above-rail layout into a single tall receipt slip.**
   - **Found during:** Task 1.
   - **Issue:** The plan's Fix 5 said "Keep `.frame(minHeight: 210)`" — but the prior code never set `minHeight: 210`. It used a 156pt `questionHero` (the headline) ABOVE a separate 68pt `EvidenceMiniSlip` rail. The two were unrelated views laid out vertically. This split layout cannot satisfy the UI-SPEC, which describes ONE tall receipt slip carrying the confession text INSIDE it (with perforation at top, micro progress at top of the slip body, and CAUGHT stamp in the slip's lower-right quadrant).
   - **Fix:** Restructured the page so `PainReceiptSlip` is a single 210pt-min-height slip containing the micro progress, "current receipt" label, and the confession text. The "questionHero" above-and-rail-below pattern was deleted.
   - **Files modified:** `MindRestore/Views/Onboarding/OnboardingNewScreens.swift`
   - **Commit:** b6a98bc

2. **[Rule 3 — Empty state] Empty back-stack now renders zero slips, not 2 ambient placeholders.**
   - **Found during:** Task 1.
   - **Issue:** The plan's Fix 6 said "leave back slips blank when `savedReceipts` empty" — but the prior code rendered 2 ambient `ReceiptBackItem`s with `text: ""` even when nothing was caught, which (a) added unnecessary visual chrome behind the active slip on prompt 1 and (b) implied false history. The clean reading is "no saved receipts → no back slips".
   - **Fix:** `backReceipts` returns `[]` when `savedReceipts` is empty. The `ForEach` simply renders nothing.
   - **Commit:** b6a98bc

**Auto-applied (Rule 2 — auto-add missing critical functionality):**

3. **[Rule 2 — Reduce Motion completeness] Entrance animations now respect Reduce Motion.**
   - **Found during:** Task 1.
   - **Issue:** The prior code only branched on `reduceMotion` for the `Not me` exit and the `advance()` re-entrance. The four `startEntrance()` `withAnimation` calls (header, stack, mascot, buttons) used `.spring()` / `.easeOut(0.38)` unconditionally — meaning the entrance played full springs even when Reduce Motion was on. UI-SPEC §"Animation Cadence Pattern / Reduce Motion fallback" explicitly says ALL spring/scale animations swap to 0.18s opacity fades, including entrance.
   - **Fix:** Each `startEntrance()` `withAnimation` call now ternaries `reduceMotion ? .easeOut(0.18) : <prior animation>`.
   - **Commit:** b6a98bc

4. **[Rule 2 — Dynamic Type cap] Slip pinned to `dynamicTypeSize(...DynamicTypeSize.xxLarge)`.**
   - **Found during:** Task 1.
   - **Issue:** UI-SPEC §"Page 2 — Pain Cards / Accessibility" line ~456: "Dynamic Type: confession text scales but max font size capped at +1 size step to keep slip from overflowing 210pt min-height (use `.dynamicTypeSize(...DynamicTypeSize.xxLarge)` on the slip)." The plan didn't enumerate this but it's in the locked design contract.
   - **Fix:** Added `.dynamicTypeSize(...DynamicTypeSize.xxLarge)` to the page root.
   - **Commit:** b6a98bc

## Authentication Gates

None. This is pure UI work with no auth, no network, no permission requests.

## Threat Surface

No new attack surface. All work is in-memory `@State` rendering. `receiptCount` flow unchanged (already audited in CONTEXT D-10 / threat register T-01-01 — accept disposition).

## Self-Check: PASSED

- File modified: `MindRestore/Views/Onboarding/OnboardingNewScreens.swift` — FOUND
- Commit: `b6a98bc` — FOUND in `git log --oneline`
- Build artifact: `build/Build/Products/Debug-iphoneos/MindRestore.app` — FOUND
- App installed: bundle id `com.dylanmiller.mindrestore` confirmed by `devicectl`

## Next Step

Per plan, Task 2 is a `checkpoint:human-verify` for Plan 01-01 — but this executor is running in YOLO mode and the build + install completed successfully. The user can run the on-device verification flow (12 steps in the plan's Task 2 `<how-to-verify>`) at their convenience. If any defect is found, file as a follow-up plan or amend Plan 01-01 with a continuation task.

The next plan in Phase 1 is `01-02` (Goals page polish, ONB-05).
