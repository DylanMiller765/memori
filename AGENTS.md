# Memo / MindRestore Repository Guide

Last audited: 2026-08-25. Verify fast-moving facts in the code before relying on them.

## Product identity

- Memo is the current user-facing product/marketing name.
- `MindRestore` is the main Xcode target, bundle identifier family, and legacy repository name.
- `Memori` names internal Screen Time extensions and related targets; do not rename them casually.
- Core loop must remain truthful: block an app → slot/random selection → complete a brain game → receive a temporary unlock. Say “play,” “finish,” or “complete,” never “win.”

## Current project state

- SwiftUI + SwiftData, iOS 17+, iPhone-only (`TARGETED_DEVICE_FAMILY = 1`).
- Project version audited at `2.1.2`; confirm `MARKETING_VERSION` before describing a release.
- Main target: `MindRestore`; tests: `MindRestoreTests`; extensions include Memori shield/configuration and widget targets.
- Exercise views live in `MindRestore/Views/Exercises/`; tests live in `MindRestoreTests/`.
- StoreKit product IDs are defined in `MindRestore/Services/StoreService.swift`; analytics is PostHog in `AnalyticsService.swift`.

## Before implementation

- Questions, ideas, and planning are discussion—not authorization to edit.
- For approved UI work, describe layout, colors, icons, states, and semantic meaning before coding.
- Codex may edit `.xcodeproj` settings when the user explicitly approves the change, including release version/build metadata. Keep edits narrowly scoped, inspect the resulting diff, and verify with `xcodebuild`. Structural target changes and package additions still require advance discussion and explicit approval.
- Preserve unrelated dirty-worktree changes. Never expose keys, tokens, or private analytics data.

## Architecture anchors

- `MindRestoreApp.swift`: app entry, SwiftData container, services, analytics initialization.
- `ContentView.swift`: root tabs, training flow, exercise navigation, XP awarding.
- `DesignSystem.swift`: `AppColors`, shared styles, `CognitiveDomain`.
- `StoreService.swift` / `Views/Paywall/PaywallView.swift`: StoreKit products and purchase flow.
- `AnalyticsService.swift`: PostHog event names and funnel properties.
- `Services/FocusModeService.swift` and `Services/DeepLinkRouter.swift`: Screen Time/unlock and deep-link state.

## Commands

```bash
xcodebuild -project MindRestore.xcodeproj -scheme MindRestore -configuration Debug -destination 'platform=iOS Simulator,name=iPhone 16 Pro' -derivedDataPath build
xcodebuild test -project MindRestore.xcodeproj -scheme MindRestoreTests -destination 'platform=iOS Simulator,name=iPhone 16 Pro' -derivedDataPath build
xcodebuild -project MindRestore.xcodeproj -scheme MindRestore -configuration Debug -destination 'id=00008130-000A214E11E2001C' -allowProvisioningUpdates -derivedDataPath build
```

## Verification and QA

- After Swift/UI/behavior changes, run the `verify-changes` workflow: build, inspect the relevant screen in light/dark mode, and verify the changed interaction end to end.
- Trust `xcodebuild` diagnostics over SourceKit-only errors.
- Before a commit, run relevant tests and a clean Debug build; install on a physical device when the change depends on Screen Time, notifications, StoreKit, or lifecycle behavior.
- Check state transitions, retain cycles, force unwraps, main-thread UI, accessibility, and both color schemes.

## StoreKit and analytics rules

- Product IDs are compatibility-sensitive; changing an App Store product requires an explicit release plan.
- Local StoreKit configuration is not proof of real commerce. Validate restore, trial, renewal, and purchase behavior in Xcode StoreKit or ASC sandbox/TestFlight.
- Use PostHog events—not assumptions—for onboarding, paywall, purchase, unlock, and retention decisions.

## Git and debugging

- Work on the requested branch; do not create or switch branches without direction.
- Commit only when requested or when an explicitly approved shipping workflow requires it; never push without authorization.
- For bugs, reproduce and verify the root cause, inspect sibling callers/patterns, then explain the fix before editing.
- `build/` and derived-data directories are generated artifacts and may be cleaned when safe.
- If using XcodeBuildMCP, use the installed XcodeBuildMCP skill before calling XcodeBuildMCP tools.
