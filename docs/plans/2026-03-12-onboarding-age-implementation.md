# Optional Age in Onboarding — Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Add an optional age question to onboarding and display "X years younger/older" comparisons wherever brain age appears.

**Architecture:** Add `userAge` field to the User model, insert a new onboarding page (wheel picker) between Goals and Assessment, then add age comparison labels to ScoreRevealView, BrainScoreCard, WorkoutCompleteView, and share cards. All conditional on `userAge > 0`.

**Tech Stack:** SwiftUI, SwiftData

---

### Task 1: Add `userAge` to User model

**Files:**
- Modify: `MindRestore/Models/User.swift:31`

**Step 1: Add the field**

After line 31 (`var username: String = ""`), add:

```swift
var userAge: Int = 0  // 0 = not provided
```

**Step 2: Build to verify**

```bash
xcodebuild -project MindRestore.xcodeproj -scheme MindRestore -destination 'platform=iOS Simulator,name=iPhone 16' build 2>&1 | tail -5
```

Expected: BUILD SUCCEEDED

---

### Task 2: Add age page to OnboardingView

**Files:**
- Modify: `MindRestore/Views/Onboarding/OnboardingView.swift`

**Step 1: Add state variable**

After line 13 (`@State private var enteredName: String = ""`), add:

```swift
@State private var selectedAge: Int = 25
```

**Step 2: Update totalPages from 6 to 7**

Change line 18:
```swift
private let totalPages = 7
```

**Step 3: Shift page tags**

Update the TabView tags to insert the age page at position 3:

```swift
TabView(selection: $currentPage) {
    welcomePage.tag(0)
    namePage.tag(1)
    goalsPage.tag(2)
    agePage.tag(3)           // NEW
    assessmentPage.tag(4)    // was 3
    notificationsPage.tag(5) // was 4
    privacyPage.tag(6)       // was 5
}
```

**Step 4: Update background color condition**

Change line 22 from `currentPage == 3` to `currentPage == 4`:
```swift
(currentPage == 4 ? assessmentBgColor : AppColors.pageBg).ignoresSafeArea()
```

**Step 5: Update page indicator visibility**

Change line 37 from `currentPage != 3` to `currentPage != 4`:
```swift
if currentPage != 4 {
```

**Step 6: Update goalsPage continue button**

Change line 220 from `currentPage = 3` to `currentPage = 3` (still goes to 3, which is now the age page — no change needed).

**Step 7: Update assessmentPage onComplete**

Change `currentPage = 4` inside the assessment callback (was `currentPage = 4`, now goes to `currentPage = 5`):
```swift
withAnimation {
    currentPage = 5
}
```

**Step 8: Update notificationsPage buttons**

Change both `currentPage = 5` to `currentPage = 6`:
```swift
withAnimation { currentPage = 6 }
```

**Step 9: Create the age page view**

Add this computed property after `goalsPage` (after line 228):

```swift
// MARK: - Age Page

private var agePage: some View {
    VStack(spacing: 32) {
        Spacer()

        VStack(spacing: 8) {
            Text("🎂")
                .font(.system(size: 64))

            Text("How old are you?")
                .font(.system(size: 28, weight: .bold, design: .rounded))
                .multilineTextAlignment(.center)

            Text("We'll compare your Brain Age to your real age")
                .font(.subheadline)
                .foregroundStyle(AppColors.textTertiary)
                .multilineTextAlignment(.center)
        }

        Picker("Age", selection: $selectedAge) {
            ForEach(18...99, id: \.self) { age in
                Text("\(age)").tag(age)
            }
        }
        .pickerStyle(.wheel)
        .frame(height: 150)

        // Privacy note
        HStack(spacing: 6) {
            Image(systemName: "lock.fill")
                .font(.caption2)
            Text("Stored on your device only. Never shared.")
                .font(.caption)
        }
        .foregroundStyle(AppColors.textTertiary)

        Spacer()

        VStack(spacing: 12) {
            continueButton { currentPage = 4 }

            Button {
                selectedAge = 0
                withAnimation { currentPage = 4 }
            } label: {
                Text("Skip")
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(.secondary)
                    .padding(.vertical, 8)
            }
        }
    }
    .padding(.bottom, 8)
    .responsiveContent(maxWidth: 500)
    .frame(maxWidth: .infinity)
}
```

**Step 10: Save age in completeOnboarding()**

In `completeOnboarding()`, after line 365 (`user.notificationsEnabled = notificationsEnabled`), add:

```swift
user.userAge = selectedAge
```

**Step 11: Build to verify**

```bash
xcodebuild -project MindRestore.xcodeproj -scheme MindRestore -destination 'platform=iOS Simulator,name=iPhone 16' build 2>&1 | tail -5
```

Expected: BUILD SUCCEEDED

---

### Task 3: Add age comparison to ScoreRevealView

**Files:**
- Modify: `MindRestore/Views/Assessment/ScoreRevealView.swift`

The ScoreRevealView needs access to the user's age. It uses `BrainAssessmentViewModel` which has `brainAge`.

**Step 1: Add userAge parameter to ScoreRevealView**

Add a parameter to the ScoreRevealView struct:
```swift
var userAge: Int = 0
```

**Step 2: Add age comparison helper**

Add a computed property:
```swift
private var ageComparisonText: String? {
    guard userAge > 0 else { return nil }
    let diff = userAge - viewModel.brainAge
    if diff > 0 {
        return "\(diff) years younger than you!"
    } else if diff < 0 {
        return "\(abs(diff)) years older than your real age"
    } else {
        return "Same as your real age!"
    }
}

private var ageComparisonColor: Color {
    guard userAge > 0 else { return .secondary }
    let diff = userAge - viewModel.brainAge
    if diff > 0 { return AppColors.teal }
    if diff < 0 { return AppColors.coral }
    return .secondary
}
```

**Step 3: Add comparison to the brain age overlay**

After the "You have the brain of a X-year-old" text (around line 402-404), add:

```swift
// Age comparison (if user provided age)
if let comparison = ageComparisonText {
    Text(comparison)
        .font(.title3.weight(.bold))
        .foregroundStyle(ageComparisonColor)
}
```

**Step 4: Add comparison to the brain age summary section**

After the Brain Age summary HStack (around line 66-80), inside the `if brainAgeOverlayDismissed` block, add:

```swift
if let comparison = ageComparisonText {
    Text(comparison)
        .font(.subheadline.weight(.semibold))
        .foregroundStyle(ageComparisonColor)
}
```

**Step 5: Pass userAge from callers**

Find all places ScoreRevealView is instantiated and pass the user's age. Search for `ScoreRevealView(` in the codebase and add `userAge: user?.userAge ?? 0` where the user is available.

**Step 6: Build to verify**

---

### Task 4: Add age comparison to BrainScoreCard

**Files:**
- Modify: `MindRestore/Views/Components/BrainScoreCard.swift`

**Step 1: Add userAge parameter**

Add to the BrainScoreCard struct:
```swift
var userAge: Int = 0
```

**Step 2: Add comparison text below brain age**

In the full layout, after the brain age `statBlock` (around line 120), add a conditional subtitle:

```swift
if userAge > 0 {
    let diff = userAge - score.brainAge
    Text(diff > 0 ? "\(diff) yrs younger" : diff < 0 ? "\(abs(diff)) yrs older" : "Your age")
        .font(.system(size: 11, weight: .bold, design: .rounded))
        .foregroundStyle(diff > 0 ? AppColors.teal : diff < 0 ? AppColors.coral : .secondary)
}
```

In the compact layout, add the same after the brain age display (around line 200-206).

**Step 3: Update callers**

Find all `BrainScoreCard(score:` calls and add `userAge: user?.userAge ?? 0`:
- `HomeView.swift` (line ~362)
- `ProgressDashboardView.swift`
- `SettingsView.swift`

**Step 4: Build to verify**

---

### Task 5: Add age comparison to WorkoutCompleteView

**Files:**
- Modify: `MindRestore/Views/Home/WorkoutCompleteView.swift`

**Step 1: Add userAge parameter**

Add to the struct:
```swift
var userAge: Int = 0
```

**Step 2: Add comparison label in detailsSection**

In the Brain Age VStack within `detailsSection` (around line 155-165), after the brain age number and delta, add:

```swift
if userAge > 0 {
    let diff = userAge - newBrainAge
    Text(diff > 0 ? "\(diff) yrs younger" : diff < 0 ? "\(abs(diff)) yrs older" : "Your age")
        .font(.system(size: 10, weight: .bold, design: .rounded))
        .foregroundStyle(diff > 0 ? AppColors.teal : diff < 0 ? AppColors.coral : .secondary)
}
```

**Step 3: Update callers**

Update the WorkoutCompleteView call in `HomeView.swift` to pass `userAge: user?.userAge ?? 0`.

**Step 4: Build to verify**

---

### Task 6: Add age comparison to share cards

**Files:**
- Modify: `MindRestore/Views/Components/WorkoutShareCard.swift`
- Modify: `MindRestore/Views/Components/TikTokShareCard.swift` (if it shows brain age)

**Step 1: Add userAge parameter to WorkoutShareCard**

```swift
var userAge: Int = 0
```

**Step 2: Add comparison text**

Below the brain age display, add:
```swift
if userAge > 0 {
    let diff = userAge - brainAge
    Text(diff > 0 ? "(\(diff) yrs younger!)" : diff < 0 ? "(\(abs(diff)) yrs older)" : "")
        .font(.system(size: 14, weight: .bold))
        .foregroundStyle(diff > 0 ? Color(red: 0.34, green: 0.85, blue: 0.74) : Color(red: 1, green: 0.45, blue: 0.45))
}
```

**Step 3: Update callers**

Update `renderShareImage()` in WorkoutCompleteView and any other share card renderers to pass userAge.

**Step 4: Do the same for TikTokShareCard if it shows brain age**

**Step 5: Build to verify**

---

### Task 7: Add age setting in Settings/Profile

**Files:**
- Modify: `MindRestore/Views/Settings/SettingsView.swift`

**Step 1: Add age edit option**

In the profile/settings section, add a row that lets users update their age:

```swift
HStack {
    Text("Your Age")
    Spacer()
    if user.userAge > 0 {
        Text("\(user.userAge)")
            .foregroundStyle(.secondary)
    } else {
        Text("Not set")
            .foregroundStyle(.secondary)
    }
}
```

With a tap action that presents a picker sheet to change age, or a Stepper.

**Step 2: Build to verify**

---

### Task 8: Build, install, and verify on device

```bash
xcodebuild -project MindRestore.xcodeproj -scheme MindRestore -destination 'platform=iOS,id=00008130-000A214E11E2001C' build 2>&1 | tail -5
xcrun devicectl device install app --device 00008130-000A214E11E2001C [path to .app]
```

**Verify:**
- Fresh onboarding flow: Welcome → Name → Goals → Age (with privacy note) → Assessment → Notifications → Privacy
- Skip age → no comparison labels anywhere
- Provide age → "X years younger/older" on score reveal, home card, workout complete, share cards
- Settings shows age and allows editing
