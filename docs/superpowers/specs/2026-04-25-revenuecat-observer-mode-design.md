# RevenueCat Observer Mode Integration

**Date:** 2026-04-25
**Branch:** v2.0-focus-mode
**Author:** dylanmiller

## Goal

Pipe StoreKit 2 transaction events into RevenueCat so the founder gets live mobile push notifications (via the RevenueCat iOS app) for new subscriptions, trial starts, renewals, cancellations, and refunds.

## Non-Goals

This is **observer mode only**. We are explicitly NOT:

- Replacing `StoreService.purchase()` with `Purchases.shared.purchase()`
- Replacing the in-app `PaywallView` with `RevenueCatUI.PaywallView`
- Routing entitlement checks through RevenueCat — `StoreService.hasActiveSubscription` continues to read directly from `Transaction.currentEntitlements`
- Defining RevenueCat Entitlements or Offerings in the dashboard
- Adding a Customer Center
- Identifying users via `Purchases.shared.logIn` — anonymous device-scoped IDs are sufficient

If observer mode proves valuable and we later want unified analytics or remote-config paywalls, we can migrate. For now, the existing StoreKit 2 stack stays untouched.

## Why observer mode

- App version 1.4.2 is currently in App Store review
- Legacy subscribers exist on the deprecated `$3.99/$19.99` SKU set; their entitlements must keep flowing through the existing code path with no behavior change
- The custom paywall is design-coupled to `AppColors` and the v2.0 Focus Mode UX
- A full migration carries non-trivial risk for zero benefit relative to the actual goal (notifications)

## Prerequisites (manual, completed)

- [x] RevenueCat account + project "Memori - Brain Training Games" created
- [x] iOS app configured with bundle ID `com.dylanmiller.mindrestore`, Apple App ID `6760178716`
- [x] In-App Purchase Key (`.p8`) generated in App Store Connect → Users and Access → Integrations → In-App Purchase, uploaded to RevenueCat
- [x] App Store Connect API key (`9GRLL5VKUX`) linked to RevenueCat for product import
- [x] Apple Server-to-Server Notifications v2 URL pasted into App Store Connect → App Information → Production + Sandbox URLs (this is what makes "live" actually live — most events happen server-side)
- [x] `purchases-ios-spm` SPM package added to Xcode project (verified in `Package.resolved`)
- [x] Production iOS public API key in hand: `appl_NUUkNGthSiwlZSAtrDjAfxUGOPC`

## Code Changes

**Single file. Single function call.** `StoreService.swift` is not modified — RevenueCat's SDK observes `Transaction.updates` on its own when configured for SK2 observer mode on iOS.

### `MindRestoreApp.swift` — configure on launch

Add `import RevenueCat` and the following inside the app's `init()`, before any UI shows:

```swift
Purchases.logLevel = .info  // verbose enough to confirm events fire; drop to .error after verify
Purchases.configure(
    withAPIKey: "appl_NUUkNGthSiwlZSAtrDjAfxUGOPC",
    purchasesAreCompletedBy: .myApp,
    storeKitVersion: .storeKit2
)
```

What each parameter does:

- **`purchasesAreCompletedBy: .myApp`** — observer-mode switch. Tells the SDK that StoreKit purchases are completed by the host app (our `StoreService`), not by RevenueCat. The SDK will not initiate any purchase or attempt to finish transactions; it only observes.
- **`storeKitVersion: .storeKit2`** — must be set explicitly when in observer mode. It tells the SDK to subscribe to the `Transaction.updates` async sequence to learn about new transactions.

That's the entire integration. No `recordPurchase` calls, no `StoreService` modifications.

### Why no `StoreService` changes

The RevenueCat docs explicitly note that manual `Purchases.shared.recordPurchase(...)` calls are only needed on **macOS**, where iOS-style background transaction observation is unavailable and the SDK can't see new transactions until the user foregrounds the app. On iOS, the SDK's own internal `Transaction.updates` listener fires in parallel with `StoreService.listenForTransactions()`, so RC sees every verified transaction without explicit forwarding.

## API Key Handling

Hardcoded as a string literal in `MindRestoreApp.swift`. Justification:

- The iOS public key is *already* public — it gets baked into the binary regardless of where it's stored, and Apple ships it embedded in any app on the App Store
- No `#if DEBUG` switching to a test key — we want notifications from real users, not sandbox-only events
- If we ever need to rotate the key, it's a one-line change

## Verification

1. Build for device: `xcodebuild -project MindRestore.xcodeproj -scheme MindRestore -configuration Debug -destination 'id=00008130-000A214E11E2001C' -allowProvisioningUpdates -derivedDataPath build`
2. Install: `xcrun devicectl device install app --device 00008130-000A214E11E2001C build/Build/Products/Debug-iphoneos/MindRestore.app`
3. Launch app — RevenueCat logs at `.info` level should print `Purchases configured` and an anonymous app user ID
4. Open paywall → buy a sub in sandbox → within ~30s, the RevenueCat dashboard's **Customer History** should show a new event with the matching product ID
5. Install the **RevenueCat** iOS app from the App Store, sign in — push notifications enable automatically; the same sandbox purchase should produce a push within ~60s

## Risks

- **Crash on launch if SDK is misconfigured.** Mitigation: `Purchases.configure` is non-throwing. Build-verify on device before commit.
- **Race between RC's listener and `StoreService.listenForTransactions()`.** Both observe the same `Transaction.updates` sequence. Async sequences in Swift Concurrency are independent observers — each subscriber receives every value — so neither steals from the other. Confirmed in RC docs.
- **Free users with no transactions** — observer mode does nothing for them, which is fine. The SDK sits idle until a transaction fires.

## Out of Scope (Explicit Won't-Dos)

- Wiring `StoreService` to consume `customerInfo` updates (would entangle the two systems)
- Adding `RevenueCatUI` SPM product (only `RevenueCat` is added)
- Mapping legacy `$3.99/$19.99` products differently from current SKUs in RevenueCat — they import as separate products and that's fine; revenue reporting will reflect the actual price each user pays

## Rollback

If RC ever causes a problem in production, comment out the `Purchases.configure` call and the `import RevenueCat` line. No state migration required — observer mode owns no app-side state.
