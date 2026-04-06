# Referral System Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Free users who hit the paywall can invite friends via a unique referral link. When a friend downloads and opens the app via that link, both users get 1 week of Pro access.

**Architecture:** Referral codes are UUID-based, stored on the User model. Links use the existing `memori://` URL scheme (`memori://refer?code=<userId>`). A `ReferralService` manages code generation, validation, and granting temporary Pro trials stored in UserDefaults with an expiry date. `StoreService.isProUser` is extended to also check referral trial status. No backend needed — referral attribution is peer-to-peer via deep links.

**Tech Stack:** SwiftUI, SwiftData, UserDefaults (trial expiry), existing DeepLinkRouter pattern

---

## File Map

| File | Action | Responsibility |
|------|--------|----------------|
| `MindRestore/Services/ReferralService.swift` | Create | Referral code generation, validation, trial granting, share sheet |
| `MindRestore/Views/Paywall/ReferralBannerView.swift` | Create | "Invite a friend" banner shown on paywall |
| `MindRestore/Services/DeepLinkRouter.swift` | Modify | Add `referral(String)` destination, parse `memori://refer` URLs |
| `MindRestore/Services/StoreService.swift` | Modify | Check referral trial expiry in `isProUser` |
| `MindRestore/Views/Paywall/PaywallView.swift` | Modify | Add referral banner below paywall dismiss |
| `MindRestore/ContentView.swift` | Modify | Handle referral deep link arrival, show confirmation |
| `MindRestore/Services/AnalyticsService.swift` | Modify | Add referral tracking events |

---

### Task 1: Create ReferralService

**Files:**
- Create: `MindRestore/Services/ReferralService.swift`

- [ ] **Step 1: Create ReferralService with referral code generation**

```swift
import SwiftUI
import SwiftData

@MainActor
@Observable
final class ReferralService {
    // UserDefaults keys
    private let trialExpiryKey = "referral_trial_expiry"
    private let referredByKey = "referral_referred_by"
    private let referralCountKey = "referral_count"
    private let defaults = UserDefaults.standard

    // MARK: - Referral Code (user's own ID)

    /// Get the current user's referral code (their UUID)
    func getReferralCode(modelContext: ModelContext) -> String? {
        let descriptor = FetchDescriptor<User>()
        guard let user = try? modelContext.fetch(descriptor).first else { return nil }
        return user.id.uuidString
    }

    /// Build the referral URL for sharing
    func getReferralURL(modelContext: ModelContext) -> URL? {
        guard let code = getReferralCode(modelContext: modelContext) else { return nil }
        var components = URLComponents()
        components.scheme = "https"
        components.host = "memori-website-sooty.vercel.app"
        components.path = "/refer"
        components.queryItems = [URLQueryItem(name: "code", value: code)]
        return components.url
    }

    /// Build the direct deep link URL
    func getReferralDeepLink(modelContext: ModelContext) -> URL? {
        guard let code = getReferralCode(modelContext: modelContext) else { return nil }
        var components = URLComponents()
        components.scheme = "memori"
        components.host = "refer"
        components.queryItems = [URLQueryItem(name: "code", value: code)]
        return components.url
    }

    // MARK: - Trial Management

    /// Whether the user currently has an active referral trial
    var hasActiveReferralTrial: Bool {
        guard let expiry = defaults.object(forKey: trialExpiryKey) as? Date else {
            return false
        }
        return expiry > Date.now
    }

    /// Days remaining on referral trial
    var trialDaysRemaining: Int {
        guard let expiry = defaults.object(forKey: trialExpiryKey) as? Date else { return 0 }
        let days = Calendar.current.dateComponents([.day], from: Date.now, to: expiry).day ?? 0
        return max(0, days)
    }

    /// Grant 7-day Pro trial to the current user
    func grantReferralTrial() {
        let currentExpiry = defaults.object(forKey: trialExpiryKey) as? Date ?? Date.now
        let baseDate = max(currentExpiry, Date.now)
        let newExpiry = Calendar.current.date(byAdding: .day, value: 7, to: baseDate) ?? Date.now
        defaults.set(newExpiry, forKey: trialExpiryKey)
    }

    /// Record who referred this user
    func recordReferrer(code: String) {
        // Don't allow self-referral or re-referral
        guard defaults.string(forKey: referredByKey) == nil else { return }
        defaults.set(code, forKey: referredByKey)
    }

    /// Whether this user was already referred by someone
    var wasReferred: Bool {
        defaults.string(forKey: referredByKey) != nil
    }

    // MARK: - Referral Count (for referrer rewards)

    /// How many friends this user has successfully referred
    var referralCount: Int {
        defaults.integer(forKey: referralCountKey)
    }

    /// Increment referral count (called when a referred user opens the app)
    func incrementReferralCount() {
        defaults.set(referralCount + 1, forKey: referralCountKey)
    }

    // MARK: - Share

    /// Present share sheet with referral link
    func shareReferralLink(modelContext: ModelContext) {
        guard let url = getReferralURL(modelContext: modelContext) else { return }
        let text = "Try Memori and test your brain age! Use my link to get 1 week of Pro free 🧠"
        let activityVC = UIActivityViewController(
            activityItems: [text, url],
            applicationActivities: nil
        )
        if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
           let window = windowScene.windows.first,
           let rootVC = window.rootViewController {
            rootVC.present(activityVC, animated: true)
        }
    }
}
```

- [ ] **Step 2: Verify it compiles**

Run: `xcodebuild -project MindRestore.xcodeproj -scheme MindRestore -configuration Debug -destination 'id=00008130-000A214E11E2001C' -allowProvisioningUpdates -derivedDataPath build 2>&1 | tail -5`

**Note:** Must add file to Xcode project (`project.pbxproj`) with a PBX ID prefix `RFRRL`.

- [ ] **Step 3: Commit**

```bash
git add MindRestore/Services/ReferralService.swift MindRestore.xcodeproj/project.pbxproj
git commit -m "feat: add ReferralService for referral code generation and trial management"
```

---

### Task 2: Extend StoreService to Check Referral Trial

**Files:**
- Modify: `MindRestore/Services/StoreService.swift`

- [ ] **Step 1: Add referral trial check to isProUser**

In `StoreService.swift`, the `isProUser` property is set in `updateSubscriptionStatus()`. We need to also check the referral trial. Add a computed property that combines both:

Change the `isProUser` from a simple stored property to also check referral trial:

```swift
// Add at top of class, after existing properties:
private let referralTrialExpiryKey = "referral_trial_expiry"

var hasActiveReferralTrial: Bool {
    guard let expiry = UserDefaults.standard.object(forKey: referralTrialExpiryKey) as? Date else {
        return false
    }
    return expiry > Date.now
}
```

Then modify `updateSubscriptionStatus()` — at the end where it sets `isProUser`, change to:

```swift
isProUser = hasActiveEntitlement || hasActiveReferralTrial
```

Where `hasActiveEntitlement` is the existing StoreKit check result (rename the local variable).

- [ ] **Step 2: Verify it compiles**

Run: `xcodebuild -project MindRestore.xcodeproj -scheme MindRestore -configuration Debug -destination 'id=00008130-000A214E11E2001C' -allowProvisioningUpdates -derivedDataPath build 2>&1 | tail -5`

- [ ] **Step 3: Commit**

```bash
git add MindRestore/Services/StoreService.swift
git commit -m "feat: extend StoreService to recognize referral trial as Pro"
```

---

### Task 3: Extend DeepLinkRouter for Referral Links

**Files:**
- Modify: `MindRestore/Services/DeepLinkRouter.swift`

- [ ] **Step 1: Add referral destination and URL parsing**

Add to `DeepLinkDestination` enum:

```swift
case referral(String) // referral code
```

Add to `DeepLinkRouter.handle(_:)` switch on `url.host`:

```swift
case "refer":
    if let components = URLComponents(url: url, resolvingAgainstBaseURL: false),
       let code = components.queryItems?.first(where: { $0.name == "code" })?.value {
        pendingDestination = .referral(code)
    } else {
        pendingDestination = .home
    }
```

- [ ] **Step 2: Verify it compiles**

Run build command. Note: ContentView will need updating to handle `.referral` case — this will produce a warning but should still compile.

- [ ] **Step 3: Commit**

```bash
git add MindRestore/Services/DeepLinkRouter.swift
git commit -m "feat: add referral deep link parsing to DeepLinkRouter"
```

---

### Task 4: Handle Referral Arrival in ContentView

**Files:**
- Modify: `MindRestore/ContentView.swift`

- [ ] **Step 1: Add ReferralService as environment object**

In `MindRestoreApp.swift`, create and inject `ReferralService`:

```swift
@State private var referralService = ReferralService()
// In body, add: .environment(referralService)
```

- [ ] **Step 2: Handle referral deep link in ContentView**

Add state for referral confirmation alert:

```swift
@State private var showReferralWelcome = false
@State private var referralTrialGranted = false
```

In the `.onChange(of: deepLinkRouter.pendingDestination)` handler, add the referral case:

```swift
case .referral(let code):
    // Don't process self-referrals
    if let myCode = referralService.getReferralCode(modelContext: modelContext),
       code == myCode {
        break
    }
    // Record referrer and grant trial to new user
    if !referralService.wasReferred {
        referralService.recordReferrer(code: code)
        referralService.grantReferralTrial()
        referralTrialGranted = true
        showReferralWelcome = true
        // Notify referrer via CloudKit so they get their trial too
        referralService.notifyReferrer(referrerCode: code)
        // Refresh Pro status
        Task { await storeService.updateSubscriptionStatus() }
    }
    deepLinkRouter.pendingDestination = nil
```

Add alert:

```swift
.alert("Welcome to Memori! 🧠", isPresented: $showReferralWelcome) {
    Button("Let's go!") {}
} message: {
    Text("Your friend referred you! Enjoy 1 week of Memori Pro — all games unlocked.")
}
```

- [ ] **Step 3: Verify it compiles and install on device**

Run build + install commands.

- [ ] **Step 4: Commit**

```bash
git add MindRestore/ContentView.swift MindRestore/MindRestoreApp.swift
git commit -m "feat: handle referral deep link arrival with trial grant"
```

---

### Task 5: Create ReferralBannerView

**Files:**
- Create: `MindRestore/Views/Paywall/ReferralBannerView.swift`

- [ ] **Step 1: Create the referral invite banner**

```swift
import SwiftUI
import SwiftData

struct ReferralBannerView: View {
    @Environment(ReferralService.self) private var referralService
    @Environment(\.modelContext) private var modelContext

    var body: some View {
        Button {
            referralService.shareReferralLink(modelContext: modelContext)
        } label: {
            HStack(spacing: 12) {
                Image(systemName: "gift.fill")
                    .font(.system(size: 20))
                    .foregroundStyle(AppColors.accent)

                VStack(alignment: .leading, spacing: 2) {
                    Text("Invite a friend")
                        .font(.system(size: 15, weight: .bold))
                        .foregroundStyle(.white)
                    Text("You both get 1 week of Pro free")
                        .font(.system(size: 12))
                        .foregroundStyle(.white.opacity(0.7))
                }

                Spacer()

                Image(systemName: "chevron.right")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(.white.opacity(0.5))
            }
            .padding(16)
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(.ultraThinMaterial)
                    .overlay(
                        RoundedRectangle(cornerRadius: 16)
                            .stroke(AppColors.accent.opacity(0.3), lineWidth: 1)
                    )
            )
        }
        .buttonStyle(.plain)
    }
}
```

- [ ] **Step 2: Add to Xcode project and verify it compiles**

Add PBX entries with prefix `RFRRL` for the new file.

- [ ] **Step 3: Commit**

```bash
git add MindRestore/Views/Paywall/ReferralBannerView.swift MindRestore.xcodeproj/project.pbxproj
git commit -m "feat: add ReferralBannerView for paywall referral CTA"
```

---

### Task 6: Add Referral Banner to PaywallView

**Files:**
- Modify: `MindRestore/Views/Paywall/PaywallView.swift`

- [ ] **Step 1: Add referral banner to paywall**

Add the `ReferralBannerView` below the existing paywall content, above the dismiss/close area. Find the section after the subscription buttons and before the close button. Add:

```swift
// Referral option — below subscription buttons
ReferralBannerView()
    .padding(.horizontal, 20)
    .padding(.top, 8)

Text("or")
    .font(.system(size: 13))
    .foregroundStyle(.white.opacity(0.4))
    .padding(.vertical, 4)
```

This gives users an alternative path: "Don't want to pay? Invite a friend instead."

- [ ] **Step 2: Verify it compiles and install on device**

Run build + install commands.

- [ ] **Step 3: Commit**

```bash
git add MindRestore/Views/Paywall/PaywallView.swift
git commit -m "feat: add referral invite option to paywall"
```

---

### Task 7: CloudKit Referrer Reward System

**Files:**
- Modify: `MindRestore/Services/ReferralService.swift`
- Modify: `MindRestore/ContentView.swift`

The referred user gets their trial immediately (Task 4). The **referrer** also needs their trial. We use CloudKit's **public database** (no sign-in required) to coordinate:

1. When friend redeems → write a `ReferralReward` record to CloudKit with referrer's code
2. When referrer opens app → query CloudKit for pending rewards → grant trial → mark claimed

- [ ] **Step 1: Add CloudKit reward writing (called when friend redeems)**

Add to `ReferralService`:

```swift
import CloudKit

// MARK: - CloudKit Referrer Rewards (Public DB, no sign-in needed)

private let container = CKContainer.default()

/// Write a pending reward for the referrer to CloudKit
/// Called when a referred user redeems a referral link
func notifyReferrer(referrerCode: String) {
    let record = CKRecord(recordType: "ReferralReward")
    record["referrerCode"] = referrerCode
    record["status"] = "pending"
    record["createdAt"] = Date.now

    container.publicCloudDatabase.save(record) { _, error in
        if let error {
            print("CloudKit save error: \(error.localizedDescription)")
        }
    }
}

/// Check CloudKit for pending referral rewards for this user
/// Called on app launch
func checkForPendingRewards(myCode: String) {
    let predicate = NSPredicate(format: "referrerCode == %@ AND status == %@", myCode, "pending")
    let query = CKQuery(recordType: "ReferralReward", predicate: predicate)

    container.publicCloudDatabase.fetch(withQuery: query, inZoneWith: nil, desiredKeys: nil, resultsLimit: 100) { result in
        switch result {
        case .success(let (matchResults, _)):
            var rewardCount = 0
            for (_, recordResult) in matchResults {
                if case .success(let record) = recordResult {
                    // Mark as claimed
                    record["status"] = "claimed"
                    self.container.publicCloudDatabase.save(record) { _, _ in }
                    rewardCount += 1
                }
            }
            if rewardCount > 0 {
                Task { @MainActor in
                    for _ in 0..<rewardCount {
                        self.grantReferralTrial()
                        self.incrementReferralCount()
                    }
                }
            }
        case .failure(let error):
            print("CloudKit query error: \(error.localizedDescription)")
        }
    }
}
```

- [ ] **Step 2: Wire CloudKit calls**

In `ContentView.swift` referral handling (Task 4), after granting the friend's trial, add:

```swift
// Notify referrer via CloudKit
referralService.notifyReferrer(referrerCode: code)
```

In `ContentView.swift` `.onAppear` or `.task`, add the referrer reward check:

```swift
// Check for pending referral rewards
if let myCode = referralService.getReferralCode(modelContext: modelContext) {
    referralService.checkForPendingRewards(myCode: myCode)
}
```

- [ ] **Step 3: Enable CloudKit in Xcode**

**Manual step — must do in Xcode UI:**
1. Select MindRestore target → Signing & Capabilities
2. Click "+ Capability" → add "CloudKit"
3. Ensure the default container `iCloud.com.dylanmiller.mindrestore` is checked
4. The `ReferralReward` record type will be auto-created when the first record is saved

- [ ] **Step 4: Verify it compiles**

Run build command.

- [ ] **Step 5: Commit**

```bash
git add MindRestore/Services/ReferralService.swift MindRestore/ContentView.swift MindRestore.xcodeproj/project.pbxproj MindRestore/MindRestore.entitlements
git commit -m "feat: add CloudKit-based referrer reward system"
```

---

### Task 8: Add Analytics Events

**Files:**
- Modify: `MindRestore/Services/AnalyticsService.swift`

- [ ] **Step 1: Add referral analytics events**

Add to the analytics event tracking:

```swift
static func trackReferralShared() {
    TelemetryDeck.signal("referral.shared")
}

static func trackReferralRedeemed() {
    TelemetryDeck.signal("referral.redeemed")
}

static func trackReferralTrialStarted() {
    TelemetryDeck.signal("referral.trial.started")
}
```

- [ ] **Step 2: Wire analytics calls**

In `ReferralService.shareReferralLink()`, add:
```swift
AnalyticsService.trackReferralShared()
```

In `ContentView` referral handling (Task 4), add:
```swift
AnalyticsService.trackReferralRedeemed()
AnalyticsService.trackReferralTrialStarted()
```

- [ ] **Step 3: Commit**

```bash
git add MindRestore/Services/AnalyticsService.swift MindRestore/Services/ReferralService.swift MindRestore/ContentView.swift
git commit -m "feat: add referral analytics tracking"
```

---

### Task 9: Universal Link Setup for App Store Redirect

**Files:**
- Note: This requires web changes, not just app code

- [ ] **Step 1: Add redirect page on Vercel site**

The referral URL (`https://memori-website-sooty.vercel.app/refer?code=ABC123`) needs to redirect to the App Store if the app isn't installed, or open the app if it is.

Create a simple redirect page at `/refer` on the Vercel site that:
- On iOS: tries `memori://refer?code=ABC123` first, falls back to App Store link
- On other platforms: redirects to App Store

```html
<script>
  const params = new URLSearchParams(window.location.search);
  const code = params.get('code');
  const deepLink = `memori://refer?code=${code}`;
  const appStore = 'https://apps.apple.com/app/id6760178716';

  // Try deep link, fall back to App Store
  window.location.href = deepLink;
  setTimeout(() => { window.location.href = appStore; }, 1500);
</script>
```

- [ ] **Step 2: Commit web changes separately**

---

### Task 10: QA & Install on Device

- [ ] **Step 1: Full build**

```bash
xcodebuild -project MindRestore.xcodeproj -scheme MindRestore -configuration Debug -destination 'id=00008130-000A214E11E2001C' -allowProvisioningUpdates -derivedDataPath build
```

- [ ] **Step 2: Install on device**

```bash
xcrun devicectl device install app --device 00008130-000A214E11E2001C build/Build/Products/Debug-iphoneos/MindRestore.app
```

- [ ] **Step 3: Test the full flow**

1. Open app → hit daily limit → see paywall with referral banner
2. Tap "Invite a friend" → share sheet opens with referral link
3. Copy link, open in Safari → should redirect to app or App Store
4. Test deep link: `memori://refer?code=TEST123` → should show welcome alert
5. Verify Pro status is granted (games unlocked)
6. Verify trial expiry shows correctly

- [ ] **Step 4: Commit all final fixes**

```bash
git add -A
git commit -m "feat: referral system — invite friends for 1 week Pro trial"
```
