# Phase 1: Onboarding Final - Discussion Log

> **Audit trail only.** Do not use as input to planning, research, or execution agents.
> Decisions are captured in CONTEXT.md — this log preserves the alternatives considered.

**Date:** 2026-04-27
**Phase:** 1-onboarding-final
**Areas discussed:** Build order + Codex/Claude split (reframed by user to: Polish targets + Build distribution)

---

## Initial Gray Area Selection

| Option | Description | Selected |
|--------|-------------|----------|
| Build order + Codex/Claude split | Who builds what; page ordering | ✓ |
| Receipt count plumbing | Pain Cards → Plan Reveal data flow | (resolved by Claude default in CONTEXT.md D-10) |
| Reduce Motion scope | All 16 pages vs 4 outstanding | (resolved by Claude default in CONTEXT.md D-11/D-12) |
| Empathy Option 3 — pre-design or just build | Codex spec round vs jump in | (resolved by Claude default in CONTEXT.md D-07) |

**User's choice:** "Build order + Codex/Claude split" + freeform redirect: *"i really just want to polish up and redeisgn our onboarding mostly just polish since onboarding is really strong. so find any weak slides in onboarding that we shoulf fix and improve."*

**Notes:** User explicitly reframed the phase from "heavy redesigns of 4 pages" (per original ROADMAP.md) to "polish-not-redesign — find weak slides and improve them." This pivots the entire phase scope.

---

## Polish list (after Claude audit)

Claude presented audit findings: 10 strong pages, 5 weak pages identified, 1 page to verify.

**Identified weak pages (audit):**
- Pain Cards (6 known issues from Codex first impl)
- Goals (divider-list aesthetic, truncation, no tactile feedback)
- Plan Reveal (REDESIGN-tier flag from earlier audit)
- Commitment (typewriter bullets feel flat)
- Screen Time Access (2019 SaaS aesthetic)

**To verify on device:** Empathy

| Option | Description | Selected |
|--------|-------------|----------|
| Pain Cards (6 known fixes) | Fix Codex first-impl issues | ✓ |
| Goals (full polish) | Divider-list → OB-system; tactile feedback; 0/3 progress | ✓ |
| Plan Reveal (targeted tweaks) | Per audit, not a rewrite | ✓ |
| Commitment + Screen Time bundle | Both get OB-system polish | ✓ |

**User's choice:** All 4 polish-target groups + Empathy verify (live on device) + freeform addition: *"i feel like industry scare screen can be way better tbh too"*

**Notes:** User added Industry Scare to the polish list. Specific weak element TBD during implementation (the $57B count-up is good per session history; layout/copy/payoff after the count-up is the likely weak element).

---

## Build distribution

| Option | Description | Selected |
|--------|-------------|----------|
| Claude does all | All polish is code-level + iteration-friendly. Faster than handoff loops. (Recommended) | ✓ |
| Codex does Goals only, Claude does the rest | Codex's design eye on the highest-stakes redesign | |
| Codex does visual heroes, Claude does fixes | Codex specs + builds Goals + Commitment hero; Claude does Pain Cards + Plan Reveal + Screen Time + Empathy verify | |

**User's choice:** Claude does all.
**Notes:** Velocity prioritized over Codex/Claude collaboration loops. UI-SPEC already locks visual contract upstream so Codex's design-eye contribution is captured.

---

## Claude's Discretion

- Receipt count plumbing approach (D-10) — Claude defaulted to callback-parameter pattern (no User model persistence)
- Reduce Motion scope (D-11) — Claude defaulted to "applied to 6 polish targets, opportunistic on already-shipped pages"
- Light/dark parity (D-12) — Claude defaulted to "final sweep at end of phase"
- Empathy verify-or-polish (D-07) — Claude will decide live on device during Phase 1 implementation
- Build order (D-09) — Claude defaulted to Pain Cards → Goals → Industry Scare → Plan Reveal → Commitment → Screen Time → Empathy verify
- Specific spacing micro-tweaks within OB scale
- Spring response/damping values within UI-SPEC band
- Mascot peek placement on each polish target

## Deferred Ideas

- PostHog onboarding A/B instrumentation — future "Onboarding Analytics" phase
- Animated transitions between pages (replacing TabView slide) — v2.1+ polish phase
- Localization for new copy — handled by Phase 3 (BRAND-04)
- Onboarding skip/resume mid-flow — future UX phase
- Mascot Rive animations on polish targets — v2.1+ polish

---

*End of discussion log*
