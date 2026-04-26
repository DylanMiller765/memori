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

### 1. `MindRestoreApp.swift` — configure on launch

Add to the app's `init()`:

```swift
import RevenueCat

// inside init(), before any UI shows
Purchases.logLevel = .info  // verbose enough to confirm events fire; can drop to .error later
Purchases.configure(
    with: Configuration.Builder(withAPIKey: "appl_NUUkNGthSiwlZSAtrDjAfxUGOPC")
        .with(purchasesAreCompletedBy: .myApp, storeKitVersion: .storeKit2)
        .build()
)
```

The `purchasesAreCompletedBy: .myApp` flag is the observer-mode switch — it tells the SDK that StoreKit purchases are completed by the host app (i.e., our `StoreService`), not by RevenueCat.

### 2. `StoreService.swift` — forward verified transactions

Two call sites, both feeding the same `recordPurchase` API:

**a) Inside `purchase(_:)` after `case .success(let verification)`:**
After we call `await transaction.finish()` for a successful purchase, also call:

```swift
_ = try? await Purchases.shared.recordPurchase(verification)
```

**b) Inside `listenForTransactions()`'s `for await result in Transaction.updates` loop:**
After processing the verified transaction with the existing logic, call the same `recordPurchase` line.

Both calls are best-effort: failures in observer-mode forwarding must never block or affect the user's purchase outcome. Use `try?` and ignore the return value.

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

- **Crash on launch if SDK is misconfigured.** Mitigation: `Purchases.configure` is non-throwing; only invalid Configuration usage would crash, and the call is unit-testable. Build verify on device before commit.
- **Duplicate transaction reporting.** `Purchases.shared.recordPurchase` is idempotent server-side (RC dedupes by `transactionId`), so calling it from both the purchase site and the `Transaction.updates` listener for the same transaction is safe.
- **Free users with no transactions** — observer mode does nothing for them, which is fine. The SDK just sits idle until a transaction fires.

## Out of Scope (Explicit Won't-Dos)

- Wiring `StoreService` to consume `customerInfo` updates (would entangle the two systems)
- Adding `RevenueCatUI` SPM product (only `RevenueCat` is added)
- Mapping legacy `$3.99/$19.99` products differently from current SKUs in RevenueCat — they import as separate products and that's fine; revenue reporting will reflect the actual price each user pays

## Rollback

If RC ever causes a problem in production, comment out the `Purchases.configure` call and the two `recordPurchase` calls. No state migration required — observer mode owns no app-side state.
