# Memori 2.0 Onboarding Redesign Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Redesign onboarding from a "competitive brain games" identity to a "screen time blocker powered by brain training" identity. 10 steps (down from 12), with shortened brain assessment, soft paywall, and Focus Mode elevated to core feature.

**Architecture:** Restructure `OnboardingView.swift` page order, create `QuickAssessmentView` (2-game mini assessment), create `OnboardingPaywallView` (soft paywall), add `doomscrolling` goal to `UserFocusGoal` enum, update `FocusModeSetupView` with inline upsell for 1-app limit, and update `Configuration.storekit` Ultra weekly price to $2.99.

**Tech Stack:** SwiftUI, SwiftData, FamilyControls, StoreKit 2

**Spec:** `docs/superpowers/specs/2026-04-20-onboarding-redesign-v2.md`

---

### Task 1: Add `doomscrolling` goal to UserFocusGoal enum

**Files:**
- Modify: `MindRestore/Models/Enums.swift:192-229`

- [ ] **Step 1: Add the new enum case and reorder**

In `MindRestore/Models/Enums.swift`, replace the entire `UserFocusGoal` enum:

```swift
enum UserFocusGoal: String, Codable, CaseIterable, Identifiable {
    case screenTimeFrying = "screentime"
    case doomscrolling = "doomscroll"
    case attentionShot = "attention"
    case loseFocus = "focus"
    case forgetInstantly = "forget"
    case getSharper = "sharper"
    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .screenTimeFrying: return "My screen time is out of control"
        case .doomscrolling: return "I doomscroll way too much"
        case .attentionShot: return "I can't focus like I used to"
        case .loseFocus: return "I lose my train of thought easily"
        case .forgetInstantly: return "I forget things too quickly"
        case .getSharper: return "I want to stay mentally sharp"
        }
    }

    var icon: String {
        switch self {
        case .screenTimeFrying: return "iphone.gen3.slash"
        case .doomscrolling: return "iphone"
        case .attentionShot: return "brain.head.profile"
        case .loseFocus: return "eye.slash"
        case .forgetInstantly: return "wind"
        case .getSharper: return "bolt.fill"
        }
    }

    var emoji: String {
        switch self {
        case .screenTimeFrying: return "📱"
        case .doomscrolling: return "🫠"
        case .attentionShot: return "🧠"
        case .loseFocus: return "💭"
        case .forgetInstantly: return "💨"
        case .getSharper: return "⚡️"
        }
    }
}
```

- [ ] **Step 2: Build to verify**

Run: `xcodebuild -project MindRestore.xcodeproj -scheme MindRestore -configuration Debug -destination 'id=00008130-000A214E11E2001C' -allowProvisioningUpdates -derivedDataPath build 2>&1 | grep -E "error:|BUILD"`

Expected: BUILD SUCCEEDED (the enum is used via `CaseIterable` so reordering + adding a case is safe — all switch statements should still compile since they use explicit cases)

- [ ] **Step 3: Commit**

```bash
git add MindRestore/Models/Enums.swift
git commit -m "feat: add doomscrolling goal + reorder UserFocusGoal for screen time identity"
```

---

### Task 2: Create QuickAssessmentView (shortened 2-game assessment)

**Files:**
- Create: `MindRestore/Views/Onboarding/QuickAssessmentView.swift`

- [ ] **Step 1: Create the QuickAssessmentView**

Create `MindRestore/Views/Onboarding/QuickAssessmentView.swift`:

```swift
import SwiftUI

/// Shortened brain age assessment for onboarding.
/// Runs Reaction Time (3 taps) then Visual Memory (3 rounds).
/// Returns an estimated BrainScoreResult with 2 domain scores.
struct QuickAssessmentView: View {
    @Binding var backgroundColor: Color
    let onComplete: (BrainScoreResult) -> Void

    @State private var viewModel = QuickAssessmentViewModel()

    var body: some View {
        ZStack {
            phaseBackgroundColor.ignoresSafeArea()

            switch viewModel.phase {
            case .reactionInstructions:
                instructionCard(
                    icon: "bolt.fill",
                    title: "Reaction Time",
                    subtitle: "Tap as fast as you can when the screen turns green",
                    color: .yellow
                )
            case .reactionWait:
                Color.red.ignoresSafeArea()
                    .overlay(
                        Text("Wait for green...")
                            .font(.title2.weight(.bold))
                            .foregroundStyle(.white)
                    )
                    .onTapGesture { viewModel.reactionTappedEarly() }
            case .reactionGo:
                Color.green.ignoresSafeArea()
                    .overlay(
                        Text("TAP!")
                            .font(.system(size: 48, weight: .black, design: .rounded))
                            .foregroundStyle(.white)
                    )
                    .onTapGesture { viewModel.reactionTapped() }
            case .reactionTooEarly:
                Color.red.ignoresSafeArea()
                    .overlay(
                        VStack(spacing: 12) {
                            Text("Too early!")
                                .font(.title.weight(.bold))
                                .foregroundStyle(.white)
                            Text("Wait for green")
                                .font(.subheadline)
                                .foregroundStyle(.white.opacity(0.8))
                        }
                    )
                    .onTapGesture { viewModel.startReactionRound() }
            case .reactionResult:
                Color.green.opacity(0.9).ignoresSafeArea()
                    .overlay(
                        VStack(spacing: 8) {
                            Text("\(viewModel.lastReactionMs) ms")
                                .font(.system(size: 48, weight: .black, design: .rounded))
                                .foregroundStyle(.white)
                            Text("Tap to continue")
                                .font(.subheadline)
                                .foregroundStyle(.white.opacity(0.7))
                        }
                    )
                    .onTapGesture { viewModel.nextReactionRound() }
            case .visualInstructions:
                instructionCard(
                    icon: "square.grid.3x3.fill",
                    title: "Visual Memory",
                    subtitle: "Remember which squares light up",
                    color: .purple
                )
            case .visualShow:
                visualGrid(interactive: false)
            case .visualInput:
                visualGrid(interactive: true)
            case .calculating:
                VStack(spacing: 16) {
                    ProgressView()
                        .scaleEffect(1.5)
                    Text("Calculating your Brain Age...")
                        .font(.headline)
                }
            case .done:
                Color.clear
                    .onAppear {
                        let result = viewModel.createResult()
                        onComplete(result)
                    }
            }
        }
        .onChange(of: viewModel.phase) { _, newPhase in
            withAnimation(.easeInOut(duration: 0.3)) {
                backgroundColor = phaseBackgroundColor
            }
        }
        .onAppear {
            viewModel.start()
        }
    }

    // MARK: - Background Color

    private var phaseBackgroundColor: Color {
        switch viewModel.phase {
        case .reactionWait, .reactionTooEarly: return .red
        case .reactionGo: return .green
        case .reactionResult: return Color.green.opacity(0.9)
        default: return AppColors.pageBg
        }
    }

    // MARK: - Instruction Card

    private func instructionCard(icon: String, title: String, subtitle: String, color: Color) -> some View {
        VStack(spacing: 24) {
            Spacer()

            Image(systemName: icon)
                .font(.system(size: 60))
                .foregroundStyle(color)

            VStack(spacing: 8) {
                Text(title)
                    .font(.system(size: 28, weight: .bold, design: .rounded))
                Text(subtitle)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }

            // Progress indicator
            HStack(spacing: 16) {
                assessmentStepLabel("SPD", active: viewModel.phase == .reactionInstructions)
                assessmentStepLabel("VIS", active: viewModel.phase == .visualInstructions)
            }

            Spacer()

            Button {
                viewModel.dismissInstructions()
            } label: {
                Text("Start")
                    .gradientButton()
            }
            .padding(.horizontal, 32)
        }
        .padding(.bottom, 8)
    }

    private func assessmentStepLabel(_ text: String, active: Bool) -> some View {
        Text(text)
            .font(.system(size: 12, weight: .bold, design: .monospaced))
            .foregroundStyle(active ? AppColors.accent : .secondary)
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background(active ? AppColors.accent.opacity(0.15) : Color.gray.opacity(0.1), in: Capsule())
    }

    // MARK: - Visual Grid

    private func visualGrid(interactive: Bool) -> some View {
        VStack(spacing: 24) {
            Spacer()

            Text(interactive ? "Tap the squares that lit up" : "Remember these squares")
                .font(.headline)

            let gridSize = viewModel.visualGridSize
            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 8), count: gridSize), spacing: 8) {
                ForEach(0..<(gridSize * gridSize), id: \.self) { index in
                    let isHighlighted = viewModel.highlightedCells.contains(index)
                    let isSelected = viewModel.selectedCells.contains(index)

                    RoundedRectangle(cornerRadius: 8)
                        .fill(cellColor(index: index, isHighlighted: isHighlighted, isSelected: isSelected, interactive: interactive))
                        .aspectRatio(1, contentMode: .fit)
                        .onTapGesture {
                            if interactive {
                                viewModel.toggleVisualCell(index)
                            }
                        }
                }
            }
            .padding(.horizontal, 32)

            Spacer()

            if interactive {
                Button {
                    viewModel.submitVisualRound()
                } label: {
                    Text("Submit")
                        .gradientButton()
                }
                .padding(.horizontal, 32)
            }
        }
        .padding(.bottom, 8)
    }

    private func cellColor(index: Int, isHighlighted: Bool, isSelected: Bool, interactive: Bool) -> Color {
        if !interactive {
            return isHighlighted ? AppColors.accent : AppColors.cardSurface
        }
        return isSelected ? AppColors.accent : AppColors.cardSurface
    }
}
```

- [ ] **Step 2: Create the QuickAssessmentViewModel**

Add below the view in the same file, or create a separate file. For simplicity, add at the bottom of `QuickAssessmentView.swift`:

```swift
// MARK: - ViewModel

enum QuickAssessmentPhase: Equatable {
    case reactionInstructions
    case reactionWait
    case reactionGo
    case reactionTooEarly
    case reactionResult
    case visualInstructions
    case visualShow
    case visualInput
    case calculating
    case done
}

@MainActor @Observable
final class QuickAssessmentViewModel {
    var phase: QuickAssessmentPhase = .reactionInstructions

    // Reaction Time — 3 rounds
    var reactionRound = 0
    var reactionTimes: [Int] = []
    var reactionStartTime: Date?
    var lastReactionMs = 0
    private var reactionTimer: Timer?
    private let totalReactionRounds = 3

    // Visual Memory — 3 rounds
    var visualRound = 0
    var visualGridSize = 3
    var highlightedCells: Set<Int> = []
    var selectedCells: Set<Int> = []
    private var visualMaxCorrect = 0
    private let totalVisualRounds = 3
    private var visualTimer: Timer?

    func start() {
        phase = .reactionInstructions
    }

    // MARK: - Reaction Time

    func dismissInstructions() {
        if phase == .reactionInstructions {
            startReactionRound()
        } else if phase == .visualInstructions {
            startVisualRound()
        }
    }

    func startReactionRound() {
        phase = .reactionWait
        let delay = Double.random(in: 1.5...4.0)
        reactionTimer?.invalidate()
        reactionTimer = Timer.scheduledTimer(withTimeInterval: delay, repeats: false) { _ in
            Task { @MainActor in
                self.reactionStartTime = Date()
                self.phase = .reactionGo
            }
        }
    }

    func reactionTappedEarly() {
        reactionTimer?.invalidate()
        phase = .reactionTooEarly
    }

    func reactionTapped() {
        guard let start = reactionStartTime else { return }
        let ms = Int(Date().timeIntervalSince(start) * 1000)
        lastReactionMs = ms
        reactionTimes.append(ms)
        reactionRound += 1
        phase = .reactionResult
    }

    func nextReactionRound() {
        if reactionRound >= totalReactionRounds {
            // Move to visual memory
            phase = .visualInstructions
        } else {
            startReactionRound()
        }
    }

    // MARK: - Visual Memory

    private func startVisualRound() {
        selectedCells = []
        let cellCount = visualRound + 3 // Start with 3 highlighted, then 4, then 5
        let totalCells = visualGridSize * visualGridSize
        var cells = Set<Int>()
        while cells.count < min(cellCount, totalCells) {
            cells.insert(Int.random(in: 0..<totalCells))
        }
        highlightedCells = cells
        phase = .visualShow

        // Show for 1.5 seconds then hide
        visualTimer?.invalidate()
        visualTimer = Timer.scheduledTimer(withTimeInterval: 1.5, repeats: false) { _ in
            Task { @MainActor in
                self.phase = .visualInput
            }
        }
    }

    func toggleVisualCell(_ index: Int) {
        if selectedCells.contains(index) {
            selectedCells.remove(index)
        } else {
            selectedCells.insert(index)
        }
    }

    func submitVisualRound() {
        let correct = selectedCells == highlightedCells
        if correct {
            visualMaxCorrect = visualRound + 1
        }
        visualRound += 1

        if visualRound >= totalVisualRounds {
            // Done — calculate result
            phase = .calculating
            Timer.scheduledTimer(withTimeInterval: 1.5, repeats: false) { _ in
                Task { @MainActor in
                    self.phase = .done
                }
            }
        } else {
            startVisualRound()
        }
    }

    // MARK: - Result

    var avgReactionMs: Int {
        guard !reactionTimes.isEmpty else { return 500 }
        return reactionTimes.reduce(0, +) / reactionTimes.count
    }

    func createResult() -> BrainScoreResult {
        // Reaction score: 100ms = perfect (100), 500ms = bad (0)
        let reactionScore = max(0, min(100, Double(500 - avgReactionMs) / 4.0))

        // Visual score: 0 correct = 0, 3 correct = 100
        let visualScore = Double(visualMaxCorrect) / Double(totalVisualRounds) * 100.0

        // Memory domain defaults to median (50) since we didn't test it
        let memoryScore = 50.0

        let brainScore = BrainScoring.compositeBrainScore(
            digit: memoryScore,
            reaction: reactionScore,
            visual: visualScore
        )
        let brainAge = BrainScoring.brainAge(from: brainScore)
        let brainType = BrainScoring.determineBrainType(
            digit: memoryScore,
            reaction: reactionScore,
            visual: visualScore
        )
        let percentile = BrainScoring.percentile(score: brainScore)

        let result = BrainScoreResult()
        result.brainScore = brainScore
        result.brainAge = brainAge
        result.brainType = brainType
        result.reactionTimeScore = reactionScore
        result.visualMemoryScore = visualScore
        result.digitSpanScore = memoryScore
        result.reactionTimeAvgMs = avgReactionMs
        result.visualMemoryMax = visualMaxCorrect
        result.percentile = percentile
        result.sourceRaw = "onboarding"
        return result
    }
}
```

- [ ] **Step 3: Build to verify**

Run: `xcodebuild -project MindRestore.xcodeproj -scheme MindRestore -configuration Debug -destination 'id=00008130-000A214E11E2001C' -allowProvisioningUpdates -derivedDataPath build 2>&1 | grep -E "error:|BUILD"`

Expected: BUILD SUCCEEDED

- [ ] **Step 4: Commit**

```bash
git add MindRestore/Views/Onboarding/QuickAssessmentView.swift
git commit -m "feat: add QuickAssessmentView — 2-game mini brain age test for onboarding"
```

---

### Task 3: Create OnboardingPaywallView

**Files:**
- Create: `MindRestore/Views/Onboarding/OnboardingPaywallView.swift`

- [ ] **Step 1: Create the onboarding-specific paywall view**

Create `MindRestore/Views/Onboarding/OnboardingPaywallView.swift`:

```swift
import SwiftUI
import StoreKit

/// Soft paywall shown during onboarding after brain age reveal.
/// Always skippable via "Maybe later" button.
struct OnboardingPaywallView: View {
    let brainAge: Int?
    let onContinue: () -> Void

    @Environment(StoreService.self) private var storeService
    @State private var selectedTier: SubscriptionTier = .ultra
    @State private var selectedPlan: String = StoreService.weeklyUltraProductID
    @State private var isPurchasing = false

    var body: some View {
        VStack(spacing: 0) {
            ScrollView {
                VStack(spacing: 20) {
                    Spacer().frame(height: 20)

                    // Headline referencing brain age
                    VStack(spacing: 6) {
                        if let brainAge {
                            Text("Your brain age is \(brainAge).")
                                .font(.system(size: 28, weight: .bold, design: .rounded))
                            Text("Let's fix that.")
                                .font(.system(size: 28, weight: .bold, design: .rounded))
                                .foregroundStyle(AppColors.accent)
                        } else {
                            Text("Unlock your\nfull potential")
                                .font(.system(size: 28, weight: .bold, design: .rounded))
                                .multilineTextAlignment(.center)
                        }
                    }

                    // Tier selector
                    HStack(spacing: 0) {
                        tierTab(title: "Pro", isSelected: selectedTier == .pro) {
                            withAnimation(.easeInOut(duration: 0.2)) {
                                selectedTier = .pro
                                selectedPlan = StoreService.monthlyProductID
                            }
                        }
                        tierTab(title: "Ultra", badge: "Best value", isSelected: selectedTier == .ultra) {
                            withAnimation(.easeInOut(duration: 0.2)) {
                                selectedTier = .ultra
                                selectedPlan = StoreService.weeklyUltraProductID
                            }
                        }
                    }
                    .padding(.horizontal, 24)

                    // Benefits list
                    VStack(alignment: .leading, spacing: 12) {
                        if selectedTier == .pro {
                            benefitRow(icon: "infinity", text: "Unlimited brain games")
                            benefitRow(icon: "chart.line.uptrend.xyaxis", text: "Detailed insights & analytics")
                            benefitRow(icon: "gamecontroller.fill", text: "All 10 exercises")
                        } else {
                            benefitRow(icon: "infinity", text: "Unlimited brain games")
                            benefitRow(icon: "shield.fill", text: "Block unlimited distracting apps")
                            benefitRow(icon: "brain.head.profile", text: "Play brain games to unlock apps")
                            benefitRow(icon: "chart.line.uptrend.xyaxis", text: "Detailed insights & analytics")
                        }
                    }
                    .padding(.horizontal, 28)

                    // Price options
                    VStack(spacing: 10) {
                        if selectedTier == .ultra {
                            priceOption(
                                label: "Weekly",
                                price: storeService.weeklyUltraProduct?.displayPrice ?? "$2.99/wk",
                                productID: StoreService.weeklyUltraProductID,
                                isSelected: selectedPlan == StoreService.weeklyUltraProductID
                            )
                            priceOption(
                                label: "Monthly",
                                price: storeService.monthlyUltraProduct?.displayPrice ?? "$6.99/mo",
                                productID: StoreService.monthlyUltraProductID,
                                isSelected: selectedPlan == StoreService.monthlyUltraProductID
                            )
                            priceOption(
                                label: "Annual",
                                price: storeService.annualUltraProduct?.displayPrice ?? "$39.99/yr",
                                detail: "Save 52%",
                                productID: StoreService.annualUltraProductID,
                                isSelected: selectedPlan == StoreService.annualUltraProductID
                            )
                        } else {
                            priceOption(
                                label: "Monthly",
                                price: storeService.monthlyProduct?.displayPrice ?? "$3.99/mo",
                                productID: StoreService.monthlyProductID,
                                isSelected: selectedPlan == StoreService.monthlyProductID
                            )
                            priceOption(
                                label: "Annual",
                                price: storeService.annualProduct?.displayPrice ?? "$19.99/yr",
                                detail: "Save 58% · 3-day free trial",
                                productID: StoreService.annualProductID,
                                isSelected: selectedPlan == StoreService.annualProductID
                            )
                        }
                    }
                    .padding(.horizontal, 24)
                }
            }

            // Bottom buttons
            VStack(spacing: 12) {
                Button {
                    isPurchasing = true
                    Task {
                        await storeService.purchase(productID: selectedPlan)
                        isPurchasing = false
                        if storeService.isProUser || storeService.isUltraUser {
                            Analytics.paywallConverted(plan: selectedPlan)
                            onContinue()
                        }
                    }
                } label: {
                    if isPurchasing {
                        ProgressView()
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 16)
                    } else {
                        Text("Start Free Trial")
                            .gradientButton()
                    }
                }
                .disabled(isPurchasing)

                Button {
                    Analytics.paywallDismissed(trigger: "onboarding")
                    onContinue()
                } label: {
                    Text("Maybe later")
                        .font(.subheadline.weight(.medium))
                        .foregroundStyle(.secondary)
                        .padding(.vertical, 8)
                }
            }
            .padding(.horizontal, 32)
            .padding(.bottom, 8)
        }
        .onAppear {
            Analytics.paywallShown(trigger: "onboarding")
        }
    }

    // MARK: - Components

    private func tierTab(title: String, badge: String? = nil, isSelected: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            VStack(spacing: 2) {
                if let badge {
                    Text(badge)
                        .font(.system(size: 9, weight: .bold))
                        .foregroundStyle(isSelected ? .white : .secondary)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(isSelected ? AppColors.violet : Color.clear, in: Capsule())
                }
                Text(title)
                    .font(.system(size: 16, weight: .bold))
                    .foregroundStyle(isSelected ? .primary : .secondary)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 12)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(isSelected ? AppColors.cardSurface : Color.clear)
                    .shadow(color: isSelected ? Color.black.opacity(0.08) : .clear, radius: 4, y: 2)
            )
        }
        .buttonStyle(.plain)
    }

    private func benefitRow(icon: String, text: String) -> some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(AppColors.accent)
                .frame(width: 24)
            Text(text)
                .font(.subheadline)
        }
    }

    private func priceOption(label: String, price: String, detail: String? = nil, productID: String, isSelected: Bool) -> some View {
        Button {
            withAnimation(.easeInOut(duration: 0.15)) {
                selectedPlan = productID
            }
        } label: {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text(label)
                        .font(.subheadline.weight(.semibold))
                    if let detail {
                        Text(detail)
                            .font(.caption)
                            .foregroundStyle(AppColors.accent)
                    }
                }
                Spacer()
                Text(price)
                    .font(.subheadline.weight(.bold))
            }
            .padding(14)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(isSelected ? AppColors.accent.opacity(0.08) : AppColors.cardSurface)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(isSelected ? AppColors.accent : AppColors.cardBorder, lineWidth: isSelected ? 2 : 1)
            )
        }
        .buttonStyle(.plain)
    }
}
```

- [ ] **Step 2: Build to verify**

Run: `xcodebuild -project MindRestore.xcodeproj -scheme MindRestore -configuration Debug -destination 'id=00008130-000A214E11E2001C' -allowProvisioningUpdates -derivedDataPath build 2>&1 | grep -E "error:|BUILD"`

Expected: BUILD SUCCEEDED

- [ ] **Step 3: Commit**

```bash
git add MindRestore/Views/Onboarding/OnboardingPaywallView.swift
git commit -m "feat: add OnboardingPaywallView — soft paywall with Pro/Ultra tiers"
```

---

### Task 4: Restructure OnboardingView — page order and new identity

**Files:**
- Modify: `MindRestore/Views/Onboarding/OnboardingView.swift`

This is the largest task. It restructures the page order, updates copy, removes cut pages, and wires in the new views.

- [ ] **Step 1: Update state vars and totalPages**

In `OnboardingView.swift`, update the state declarations. Change `totalPages` from 12 to 10. Add new state for the quick assessment result and whether Focus Mode was set up:

Replace:
```swift
    @State private var showingFocusModeSetup = false

    var onComplete: () -> Void

    private let totalPages = 12
```

With:
```swift
    @State private var showingFocusModeSetup = false
    @State private var focusModeWasSetUp = false
    @State private var quickAssessmentBgColor: Color = AppColors.pageBg

    var onComplete: () -> Void

    private let totalPages = 10
```

- [ ] **Step 2: Restructure the TabView page order**

Replace the TabView content (the page tags) with the new 10-step flow:

```swift
TabView(selection: $currentPage) {
    welcomePage.tag(0)
    namePage.tag(1)
    goalsPage.tag(2)
    agePage.tag(3)
    scarePage.tag(4)
    quickAssessmentPage.tag(5)
    revealAndHopePage.tag(6)
    onboardingPaywallPage.tag(7)
    focusModePage.tag(8)
    commitmentPage.tag(9)
}
```

- [ ] **Step 3: Update onChange step name mapping**

Update the `stepNames` array in `onDisappear` for analytics:

```swift
let stepNames = ["welcome", "name", "goals", "age", "scare", "quickAssessment", "reveal", "paywall", "focusMode", "commitment"]
```

- [ ] **Step 4: Update welcomePage with new identity**

Replace the `welcomePage` computed property. Change the TypewriterText to "Train your brain.\nBlock the noise." and update the three feature rows:

```swift
private var welcomePage: some View {
    VStack(spacing: 24) {
        Spacer().frame(height: 40)

        Image("mascot-welcome")
            .renderingMode(.original)
            .resizable()
            .scaledToFit()
            .frame(height: 220)
            .offset(y: mascotBob ? -6 : 6)
            .animation(.easeInOut(duration: 2.0).repeatForever(autoreverses: true), value: mascotBob)
            .onAppear { mascotBob = true }

        VStack(spacing: 10) {
            TypewriterText(fullText: "Train your brain.\nBlock the noise.")
                .font(.system(size: 32, weight: .bold, design: .rounded))
                .multilineTextAlignment(.center)

            Text("The app that blocks distractions\nand sharpens your mind.")
                .font(.title3)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .opacity(welcomeSubtitleVisible ? 1 : 0)
                .offset(y: welcomeSubtitleVisible ? 0 : 10)
                .animation(.easeOut(duration: 0.5), value: welcomeSubtitleVisible)
                .onAppear {
                    DispatchQueue.main.asyncAfter(deadline: .now() + 1.2) {
                        welcomeSubtitleVisible = true
                    }
                }
        }

        VStack(alignment: .leading, spacing: 14) {
            FeatureRow(icon: "shield.fill", color: AppColors.coral, title: "Block Distracting Apps", subtitle: "Shield yourself from doomscrolling")
            FeatureRow(icon: "brain.head.profile", color: CognitiveDomain.memory.color, title: "10 Brain Games", subtitle: "Play to earn your screen time back")
            FeatureRow(icon: "chart.line.uptrend.xyaxis", color: AppColors.accent, title: "Track Your Brain Age", subtitle: "See how your brain stacks up")
        }
        .padding(.horizontal, 36)
        .opacity(welcomeSubtitleVisible ? 1 : 0)
        .offset(y: welcomeSubtitleVisible ? 0 : 15)
        .animation(.easeOut(duration: 0.6).delay(0.2), value: welcomeSubtitleVisible)

        Spacer()

        continueButton {
            Analytics.onboardingStep(step: "welcome")
            currentPage = 1
        }
    }
    .padding(.bottom, 8)
    .responsiveContent(maxWidth: 500)
    .frame(maxWidth: .infinity)
}
```

- [ ] **Step 5: Rename badNewsPage to scarePage and update button text**

Rename `badNewsPage` to `scarePage`. Change the continue button text from "Continue" to "Don't believe us? Let's test it.":

```swift
private var scarePage: some View {
    VStack(spacing: 24) {
        Spacer().frame(height: 60)

        Image("mascot-low-score")
            .renderingMode(.original)
            .resizable()
            .scaledToFit()
            .frame(height: 180)

        VStack(spacing: 8) {
            VStack(spacing: 4) {
                TypewriterText(fullText: "Doomscrolling is frying") {
                    withAnimation(.easeOut(duration: 0.3)) {
                        badNewsTypingDone = true
                    }
                }
                .font(.system(size: 28, weight: .bold, design: .rounded))
                .multilineTextAlignment(.center)

                Text("your memory")
                    .font(.system(size: 28, weight: .bold, design: .rounded))
                    .foregroundColor(.red)
                    .opacity(badNewsTypingDone ? 1 : 0)
                    .scaleEffect(badNewsTypingDone ? 1 : 0.5)
                    .animation(.spring(response: 0.4, dampingFraction: 0.6), value: badNewsTypingDone)
            }

            Text("Heavy phone users have the attention span\nof a goldfish. Literally.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .opacity(badNewsSubtitleVisible ? 1 : 0)
                .offset(y: badNewsSubtitleVisible ? 0 : 10)
                .animation(.easeOut(duration: 0.5), value: badNewsSubtitleVisible)
                .onChange(of: badNewsTypingDone) { _, done in
                    if done {
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                            badNewsSubtitleVisible = true
                        }
                    }
                }
        }

        Spacer()

        Button {
            Analytics.onboardingStep(step: "scare")
            withAnimation { currentPage = 5 }
        } label: {
            Text("Don't believe us? Let's test it.")
                .gradientButton()
        }
        .padding(.horizontal, 32)
    }
    .padding(.bottom, 8)
    .responsiveContent(maxWidth: 500)
    .frame(maxWidth: .infinity)
}
```

- [ ] **Step 6: Add quickAssessmentPage**

```swift
private var quickAssessmentPage: some View {
    QuickAssessmentView(backgroundColor: $quickAssessmentBgColor) { result in
        assessmentResult = result
        Analytics.onboardingStep(step: "quickAssessment")
        withAnimation { currentPage = 6 }
    }
}
```

- [ ] **Step 7: Create revealAndHopePage (merged reveal + hope)**

```swift
private var revealAndHopePage: some View {
    VStack(spacing: 24) {
        Spacer().frame(height: 60)

        if let result = assessmentResult {
            // Brain age result
            VStack(spacing: 4) {
                Text("Your Brain Age")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(.secondary)
                Text("\(result.brainAge)")
                    .font(.system(size: 72, weight: .black, design: .rounded))
                    .foregroundStyle(result.brainAge > (selectedAge > 0 ? selectedAge : 25) ? AppColors.coral : AppColors.teal)
            }
        }

        Image("mascot-working-out")
            .renderingMode(.original)
            .resizable()
            .scaledToFit()
            .frame(height: 160)

        VStack(spacing: 8) {
            VStack(spacing: 4) {
                TypewriterText(fullText: "But your brain can") {
                    withAnimation(.easeOut(duration: 0.3)) {
                        goodNewsTypingDone = true
                    }
                }
                .font(.system(size: 28, weight: .bold, design: .rounded))
                .multilineTextAlignment(.center)

                Text("bounce back")
                    .font(.system(size: 28, weight: .bold, design: .rounded))
                    .foregroundColor(AppColors.accent)
                    .opacity(goodNewsTypingDone ? 1 : 0)
                    .scaleEffect(goodNewsTypingDone ? 1 : 0.5)
                    .animation(.spring(response: 0.4, dampingFraction: 0.6), value: goodNewsTypingDone)
            }

            Text("5 minutes of daily brain training\ncan reverse the damage.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .opacity(goodNewsSubtitleVisible ? 1 : 0)
                .offset(y: goodNewsSubtitleVisible ? 0 : 10)
                .animation(.easeOut(duration: 0.5), value: goodNewsSubtitleVisible)
                .onChange(of: goodNewsTypingDone) { _, done in
                    if done {
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                            goodNewsSubtitleVisible = true
                        }
                    }
                }

            Text("And we can block the apps that caused it.")
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(AppColors.accent)
                .multilineTextAlignment(.center)
                .opacity(goodNewsSubtitleVisible ? 1 : 0)
                .animation(.easeOut(duration: 0.5).delay(0.3), value: goodNewsSubtitleVisible)
        }

        Spacer()

        Button {
            Analytics.onboardingStep(step: "reveal")
            withAnimation { currentPage = 7 }
        } label: {
            Text("Let's fix it")
                .gradientButton()
        }
        .padding(.horizontal, 32)
    }
    .padding(.bottom, 8)
    .responsiveContent(maxWidth: 500)
    .frame(maxWidth: .infinity)
}
```

- [ ] **Step 8: Add onboardingPaywallPage**

```swift
private var onboardingPaywallPage: some View {
    OnboardingPaywallView(
        brainAge: assessmentResult?.brainAge,
        onContinue: {
            Analytics.onboardingStep(step: "paywall")
            withAnimation { currentPage = 8 }
        }
    )
}
```

- [ ] **Step 9: Update focusModePage — remove "one more thing" framing**

Replace the focusModePage content. Remove "One more thing..." and update to flow naturally from the paywall:

```swift
private var focusModePage: some View {
    VStack(spacing: 24) {
        Spacer().frame(height: 60)

        Image("mascot-goal")
            .renderingMode(.original)
            .resizable()
            .scaledToFit()
            .frame(height: 160)

        VStack(spacing: 8) {
            Text("Block the noise")
                .font(.system(size: 28, weight: .bold, design: .rounded))
                .multilineTextAlignment(.center)

            Text("Pick distracting apps to block.\nPlay a brain game to unlock them.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }

        Spacer()

        VStack(spacing: 12) {
            Button {
                showingFocusModeSetup = true
            } label: {
                Text("Set up Focus Mode")
                    .gradientButton()
            }

            Button {
                Analytics.onboardingStep(step: "focusModeSkipped")
                withAnimation { currentPage = 9 }
            } label: {
                Text("Not now")
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(.secondary)
                    .padding(.vertical, 8)
            }
        }
        .padding(.horizontal, 32)
    }
    .padding(.bottom, 8)
    .responsiveContent(maxWidth: 500)
    .frame(maxWidth: .infinity)
    .sheet(isPresented: $showingFocusModeSetup) {
        FocusModeSetupView()
            .onDisappear {
                focusModeWasSetUp = true
                Analytics.onboardingStep(step: "focusModeCompleted")
                withAnimation { currentPage = 9 }
            }
    }
}
```

- [ ] **Step 10: Update commitmentPage bullets**

Update the commitment bullets to reference Focus Mode and screen time. Replace the bullet content:

```swift
// Commitment bullets
VStack(alignment: .leading, spacing: 16) {
    if commitmentBullet1Visible {
        TypewriterText(fullText: "• I'll train my brain for 5 minutes a day")
            .font(.subheadline)
            .transition(.opacity)
    }
    if commitmentBullet2Visible {
        TypewriterText(fullText: "• I'll build my streak and not break it")
            .font(.subheadline)
            .transition(.opacity)
    }
    if commitmentBullet3Visible {
        TypewriterText(fullText: focusModeWasSetUp
            ? "• I'll let Memori block my distracting apps"
            : "• I'll put down the scroll and pick up the games")
            .font(.subheadline)
            .transition(.opacity)
    }
    if commitmentBullet4Visible {
        TypewriterText(fullText: "• I'll take back my screen time")
            .font(.subheadline)
            .transition(.opacity)
    }
}
```

Also add the privacy note below the hold-to-agree circle:

```swift
// After the hold-to-agree section, before the closing brace
HStack(spacing: 6) {
    Image(systemName: "lock.fill")
        .font(.caption2)
    Text("All data stays on your device. No tracking. No cloud uploads.")
        .font(.caption)
}
.foregroundStyle(.tertiary)
.padding(.top, 8)
```

- [ ] **Step 11: Remove appearancePage, privacyPage, goodNewsPage**

Delete the `appearancePage`, `appearanceOption()`, `applyAppearance()`, `privacyPage`, and `goodNewsPage` computed properties entirely. They are no longer referenced in the TabView.

- [ ] **Step 12: Update completeOnboarding to default to dark mode**

In `completeOnboarding()`, add the dark mode default:

```swift
// Set dark mode as default
UserDefaults.standard.set(AppTheme.dark.rawValue, forKey: "appTheme")
```

- [ ] **Step 13: Update onChange page reset logic**

Update the `onChange(of: currentPage)` handler to use new page numbers:

```swift
.onChange(of: currentPage) { _, newPage in
    UIView.animate(withDuration: 0.3, delay: 0, options: .curveEaseOut) {
        UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
    }
    nameFieldFocused = false
    if newPage == 1 {
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) {
            nameFieldFocused = true
        }
    }
    // Reset typewriter animation states
    if newPage != 4 {
        badNewsTypingDone = false
        badNewsSubtitleVisible = false
    }
    if newPage != 6 {
        goodNewsTypingDone = false
        goodNewsSubtitleVisible = false
    }
    if newPage != 9 {
        commitmentBullet1Visible = false
        commitmentBullet2Visible = false
        commitmentBullet3Visible = false
        commitmentBullet4Visible = false
    }
}
```

- [ ] **Step 14: Build to verify**

Run: `xcodebuild -project MindRestore.xcodeproj -scheme MindRestore -configuration Debug -destination 'id=00008130-000A214E11E2001C' -allowProvisioningUpdates -derivedDataPath build 2>&1 | grep -E "error:|BUILD"`

Expected: BUILD SUCCEEDED. Fix any compilation errors iteratively.

- [ ] **Step 15: Commit**

```bash
git add MindRestore/Views/Onboarding/OnboardingView.swift
git commit -m "feat: restructure onboarding — 10 steps, screen time blocker identity, soft paywall"
```

---

### Task 5: Update FocusModeSetupView — inline upsell for app limit

**Files:**
- Modify: `MindRestore/Views/FocusMode/FocusModeSetupView.swift:130-194`

- [ ] **Step 1: Add inline upsell banner**

The app picker step already has a free-user limit note and enforces the 1-app limit on the continue button (lines 149-189). This is already implemented correctly. Verify the behavior:

- Free/Pro users see: "Free plan: 1 app. Upgrade to Ultra for unlimited."
- When they tap Continue with >1 app selected, it shows the Ultra paywall
- Ultra users see no restriction

If the banner currently says "Free plan" but should also apply to Pro users, update the text:

Replace `"Free plan: 1 app. Upgrade to Ultra for unlimited."` with:

```swift
Text(storeService.isProUser ? "Pro plan: 1 app. Upgrade to Ultra for unlimited." : "Free plan: 1 app. Upgrade to Ultra for unlimited.")
```

- [ ] **Step 2: Build to verify**

Run: `xcodebuild -project MindRestore.xcodeproj -scheme MindRestore -configuration Debug -destination 'id=00008130-000A214E11E2001C' -allowProvisioningUpdates -derivedDataPath build 2>&1 | grep -E "error:|BUILD"`

Expected: BUILD SUCCEEDED

- [ ] **Step 3: Commit**

```bash
git add MindRestore/Views/FocusMode/FocusModeSetupView.swift
git commit -m "fix: update Focus Mode app limit text for Pro users"
```

---

### Task 6: Update Ultra Weekly price in StoreKit config

**Files:**
- Modify: `MindRestore/Configuration.storekit`

- [ ] **Step 1: Change Ultra Weekly price from $3.99 to $2.99**

In `Configuration.storekit`, find the `ultra_weekly_001` subscription and change `displayPrice` from `"3.99"` to `"2.99"`:

```json
{
  "displayPrice" : "2.99",
  "familyShareable" : false,
  "groupNumber" : 6,
  "internalID" : "ultra_weekly_001",
  ...
}
```

- [ ] **Step 2: Commit**

```bash
git add MindRestore/Configuration.storekit
git commit -m "chore: update Ultra Weekly price from $3.99 to $2.99"
```

Note: The actual App Store Connect price must also be updated manually in ASC. The StoreKit config is for local testing only.

---

### Task 7: Add new files to Xcode project + final build + install

**Files:**
- All new files created in Tasks 2-3

- [ ] **Step 1: Verify all new files are included in build**

The new files (`QuickAssessmentView.swift`, `OnboardingPaywallView.swift`) should be automatically included if they're in the project directory and the project uses folder references. If not, flag for the user to manually add them in Xcode:

> **Manual step:** In Xcode, right-click the `Views/Onboarding` group → Add Files to "MindRestore" → select `QuickAssessmentView.swift` and `OnboardingPaywallView.swift`.

- [ ] **Step 2: Full build for device**

Run: `xcodebuild -project MindRestore.xcodeproj -scheme MindRestore -configuration Debug -destination 'id=00008130-000A214E11E2001C' -allowProvisioningUpdates -derivedDataPath build 2>&1 | tail -5`

Expected: BUILD SUCCEEDED

- [ ] **Step 3: Install on device**

Run: `xcrun devicectl device install app --device 00008130-000A214E11E2001C build/Build/Products/Debug-iphoneos/MindRestore.app`

Expected: App installed successfully

- [ ] **Step 4: Commit all remaining changes**

```bash
git add -A
git commit -m "feat: Memori 2.0 onboarding redesign — train your brain, block the noise"
```
