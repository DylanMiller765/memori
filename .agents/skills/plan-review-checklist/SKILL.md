---
name: plan-review-checklist
description: "Self-review checklist that runs after drafting any implementation plan, feature design, or multi-step task. Use this skill whenever you've just written a plan, outlined an approach, or proposed changes to the codebase — before the user approves and you start coding. Also use when the user says 'plan this', 'how should we build', 'let me know your approach', or after using superpowers:writing-plans. This catches missing edge cases, forgotten screens, and gaps before they become bugs."
---

# Plan Review Checklist

You just drafted a plan. Before presenting it as final or starting implementation, run through this checklist. The goal is to catch what you missed *before* the user has to catch it for you.

## Step 1: Did you use the right tools to get here?

Check whether you used the superpowers plugins that would have helped:

- **superpowers:brainstorming** — Did the task involve creative work, new features, UI changes, or behavior modifications? If yes and you skipped brainstorming, flag it. Consider whether going back and brainstorming would improve the plan.
- **superpowers:writing-plans** — Did the task have multiple steps, touch multiple files, or require sequencing? If yes and you didn't use it, flag it.

If you skipped a relevant one, briefly note why (e.g., "task was too simple") or go back and use it.

## Step 2: Edge case audit

For each change in the plan, ask yourself:

- **What happens with empty/nil/zero state?** First launch, no data, no internet, no Game Center, no subscription.
- **What happens at boundaries?** Max scores, negative values, integer overflow, very long strings, very short strings.
- **What about concurrency?** Multiple taps, background/foreground transitions, async operations completing after the user navigates away.
- **What about different user states?** Free vs Pro, new user vs power user, onboarding incomplete vs complete.
- **What about accessibility?** VoiceOver, Dynamic Type, reduced motion.

You don't need to solve all of these — just flag any that are relevant and not addressed in the plan.

## Step 3: Affected screens audit

This is the one that gets missed most. For every model or service change, trace the impact:

- List every view/screen that reads from or writes to the changed data
- Check if the plan accounts for ALL of them, not just the primary one
- Common misses: share cards, widgets, leaderboards, achievements, onboarding, settings

For SwiftUI specifically, grep for usages of any modified `@Observable`, `@Environment`, or `@Query` properties to find affected views.

## Step 4: Present the gaps

After running through steps 1-3, present your findings to the user in this format:

**Plan looks good. Before we start, a few things to consider:**

- [List any edge cases worth mentioning]
- [List any screens/views that might be affected but aren't in the plan]
- [Note any superpowers plugins that would have helped]

If you found nothing, just say "Plan looks solid, no gaps found" and move on. Don't manufacture concerns for the sake of it.

## Step 5: Ask the user

End with: **"Anything else you want me to account for before I start?"**

Wait for their response before coding.
