# MindRestore Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Build a complete, buildable iOS app for evidence-based cognitive training with spaced repetition, dual n-back, and active recall exercises.

**Architecture:** MVVM + SwiftData, SwiftUI views, @Observable ViewModels, pure-logic exercise engines. StoreKit 2 for subscriptions. No external dependencies. Design system ported from StretchCheck (green accent instead of orange).

**Tech Stack:** Swift 5.9+, SwiftUI, SwiftData, StoreKit 2, Swift Charts, AVFoundation, UserNotifications. iOS 17.0+.

**Design Reference:** StretchCheck at `/Users/dylanmiller/Desktop/StretchCheck/` — match its `DesignSystem.swift` patterns (AppCardModifier, AccentButtonStyle, StreakRingView, SectionHeader), spacing (8pt grid, 16pt cards, 24pt sections), and component styles.

---

## Task 1: Xcode Project + SwiftData Models

**Files:**
- Create: `MindRestore/MindRestoreApp.swift`
- Create: `MindRestore/Models/Enums.swift`
- Create: `MindRestore/Models/User.swift`
- Create: `MindRestore/Models/Exercise.swift`
- Create: `MindRestore/Models/SpacedRepetitionCard.swift`
- Create: `MindRestore/Models/DailySession.swift`
- Create: `MindRestore/Models/PsychoEducationCard.swift`
- Create: `MindRestore/Utilities/DesignSystem.swift`
- Create: `MindRestore/Utilities/Constants.swift`
- Create: `MindRestore/Utilities/Extensions.swift`
- Create: `MindRestore/Views/ContentView.swift`
- Create: `project.yml` (for xcodegen)

**Step 1: Create project.yml for xcodegen**

```yaml
name: MindRestore
options:
  bundleIdPrefix: com.mindrestore
  deploymentTarget:
    iOS: "17.0"
  xcodeVersion: "15.0"
  createIntermediateGroups: true
settings:
  INFOPLIST_KEY_UILaunchScreen_Generation: true
  INFOPLIST_KEY_UISupportedInterfaceOrientations: UIInterfaceOrientationPortrait
  SWIFT_VERSION: "5.9"
targets:
  MindRestore:
    type: application
    platform: iOS
    sources:
      - MindRestore
    settings:
      PRODUCT_BUNDLE_IDENTIFIER: com.mindrestore.app
      INFOPLIST_KEY_CFBundleDisplayName: MindRestore
      MARKETING_VERSION: "1.0.0"
      CURRENT_PROJECT_VERSION: 1
      ASSETCATALOG_COMPILER_APPICON_NAME: AppIcon
      GENERATE_INFOPLIST_FILE: true
      INFOPLIST_KEY_UIApplicationSceneManifest_Generation: true
```

Generate project: `brew install xcodegen 2>/dev/null; xcodegen generate`

**Step 2: Create Enums.swift**

```swift
import Foundation

enum ExerciseType: String, Codable, CaseIterable {
    case spacedRepetition
    case dualNBack
    case activeRecall

    var displayName: String {
        switch self {
        case .spacedRepetition: return "Spaced Repetition"
        case .dualNBack: return "Dual N-Back"
        case .activeRecall: return "Active Recall"
        }
    }

    var icon: String {
        switch self {
        case .spacedRepetition: return "rectangle.on.rectangle.angled"
        case .dualNBack: return "square.grid.3x3"
        case .activeRecall: return "brain.head.profile"
        }
    }
}

enum CardCategory: String, Codable, CaseIterable {
    case numbers
    case words
    case faces
    case locations
    case dailyLife

    var displayName: String {
        switch self {
        case .numbers: return "Number Sequences"
        case .words: return "Word Lists"
        case .faces: return "Face-Name Pairs"
        case .locations: return "Location Sequences"
        case .dailyLife: return "Daily Life Scenarios"
        }
    }

    var icon: String {
        switch self {
        case .numbers: return "number"
        case .words: return "textformat.abc"
        case .faces: return "person.crop.circle"
        case .locations: return "map"
        case .dailyLife: return "bubble.left.and.bubble.right"
        }
    }

    var isFree: Bool { self == .numbers }
}

enum SubscriptionStatus: String, Codable {
    case free
    case trial
    case subscribed
    case lifetime
}

enum EduCategory: String, Codable, CaseIterable {
    case socialMedia
    case cannabis
    case neuroplasticity
    case techniques

    var displayName: String {
        switch self {
        case .socialMedia: return "Social Media"
        case .cannabis: return "Cannabis"
        case .neuroplasticity: return "Neuroplasticity"
        case .techniques: return "Techniques"
        }
    }
}

enum ChallengeType: String, Codable, CaseIterable {
    case storyRecall
    case instructionRecall
    case patternRecognition
    case conversationRecall

    var displayName: String {
        switch self {
        case .storyRecall: return "Story Recall"
        case .instructionRecall: return "Instruction Recall"
        case .patternRecognition: return "Pattern Recognition"
        case .conversationRecall: return "Conversation Recall"
        }
    }
}

enum UserGoal: String, Codable, CaseIterable, Identifiable {
    case forgetThings
    case cantFocus
    case gettingWorse
    case staySharp

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .forgetThings: return "I forget things people tell me"
        case .cantFocus: return "I can't focus or concentrate"
        case .gettingWorse: return "I feel like my memory is getting worse"
        case .staySharp: return "I want to stay sharp"
        }
    }

    var icon: String {
        switch self {
        case .forgetThings: return "bubble.left.and.exclamationmark.bubble.right"
        case .cantFocus: return "eyes"
        case .gettingWorse: return "brain"
        case .staySharp: return "bolt.shield"
        }
    }
}
```

**Step 3: Create User.swift**

```swift
import Foundation
import SwiftData

@Model
final class User {
    var id: UUID = UUID()
    var createdAt: Date = Date()
    var currentStreak: Int = 0
    var longestStreak: Int = 0
    var lastSessionDate: Date?
    var subscriptionStatusRaw: String = SubscriptionStatus.free.rawValue
    var trialStartDate: Date?
    var hasCompletedOnboarding: Bool = false
    var selectedGoalsRaw: [String] = []
    var dailyGoal: Int = 3
    var notificationsEnabled: Bool = false
    var reminderHour: Int = 9
    var reminderMinute: Int = 0
    var soundEnabled: Bool = true

    init() {}

    var subscriptionStatus: SubscriptionStatus {
        get { SubscriptionStatus(rawValue: subscriptionStatusRaw) ?? .free }
        set { subscriptionStatusRaw = newValue.rawValue }
    }

    var selectedGoals: [UserGoal] {
        get { selectedGoalsRaw.compactMap { UserGoal(rawValue: $0) } }
        set { selectedGoalsRaw = newValue.map(\.rawValue) }
    }

    var isProUser: Bool {
        subscriptionStatus == .subscribed || subscriptionStatus == .lifetime || subscriptionStatus == .trial
    }

    func updateStreak(on date: Date = .now) {
        let calendar = Calendar.current
        if let last = lastSessionDate {
            if calendar.isDate(last, inSameDayAs: date) {
                return
            } else if let yesterday = calendar.date(byAdding: .day, value: -1, to: date),
                      calendar.isDate(last, inSameDayAs: yesterday) {
                currentStreak += 1
            } else {
                currentStreak = 1
            }
        } else {
            currentStreak = 1
        }
        lastSessionDate = date
        longestStreak = max(longestStreak, currentStreak)
    }

    var isStreakActive: Bool {
        guard let last = lastSessionDate else { return false }
        let calendar = Calendar.current
        return calendar.isDateInToday(last) || calendar.isDateInYesterday(last)
    }
}
```

**Step 4: Create Exercise.swift**

```swift
import Foundation
import SwiftData

@Model
final class Exercise {
    var id: UUID = UUID()
    var typeRaw: String = ExerciseType.spacedRepetition.rawValue
    var difficulty: Int = 1
    var completedAt: Date = Date()
    var score: Double = 0.0
    var durationSeconds: Int = 0

    init() {}

    init(type: ExerciseType, difficulty: Int, score: Double, durationSeconds: Int) {
        self.id = UUID()
        self.typeRaw = type.rawValue
        self.difficulty = difficulty
        self.completedAt = Date()
        self.score = score
        self.durationSeconds = durationSeconds
    }

    var type: ExerciseType {
        get { ExerciseType(rawValue: typeRaw) ?? .spacedRepetition }
        set { typeRaw = newValue.rawValue }
    }
}
```

**Step 5: Create SpacedRepetitionCard.swift**

```swift
import Foundation
import SwiftData

@Model
final class SpacedRepetitionCard {
    var id: UUID = UUID()
    var categoryRaw: String = CardCategory.numbers.rawValue
    var prompt: String = ""
    var answer: String = ""
    var easeFactor: Double = 2.5
    var interval: Int = 0
    var repetitions: Int = 0
    var nextReviewDate: Date = Date()
    var lastReviewDate: Date?

    init() {}

    init(category: CardCategory, prompt: String, answer: String) {
        self.id = UUID()
        self.categoryRaw = category.rawValue
        self.prompt = prompt
        self.answer = answer
        self.easeFactor = 2.5
        self.interval = 0
        self.repetitions = 0
        self.nextReviewDate = Date()
    }

    var category: CardCategory {
        get { CardCategory(rawValue: categoryRaw) ?? .numbers }
        set { categoryRaw = newValue.rawValue }
    }
}
```

**Step 6: Create DailySession.swift**

```swift
import Foundation
import SwiftData

@Model
final class DailySession {
    var id: UUID = UUID()
    var date: Date = Date()
    @Relationship(deleteRule: .cascade) var exercises: [Exercise] = []
    var totalScore: Double = 0.0
    var durationSeconds: Int = 0

    init() {}

    init(date: Date) {
        self.id = UUID()
        self.date = date
    }

    var dateOnly: Date {
        Calendar.current.startOfDay(for: date)
    }

    var exercisesCompleted: Int {
        exercises.count
    }

    func recalculateScore() {
        guard !exercises.isEmpty else {
            totalScore = 0
            return
        }
        totalScore = exercises.reduce(0) { $0 + $1.score } / Double(exercises.count)
    }

    func recalculateDuration() {
        durationSeconds = exercises.reduce(0) { $0 + $1.durationSeconds }
    }
}
```

**Step 7: Create PsychoEducationCard.swift**

```swift
import Foundation

struct PsychoEducationCard: Identifiable {
    let id: UUID
    let title: String
    let body: String
    let category: EduCategory
    let sortOrder: Int

    init(title: String, body: String, category: EduCategory, sortOrder: Int) {
        self.id = UUID()
        self.title = title
        self.body = body
        self.category = category
        self.sortOrder = sortOrder
    }
}
```

**Step 8: Create DesignSystem.swift**

Port from StretchCheck, change accent from orange to green:

```swift
import SwiftUI

// MARK: - App Theme

enum AppTheme: String, CaseIterable {
    case light, dark, system

    var displayName: String {
        switch self {
        case .light: return "Light"
        case .dark: return "Dark"
        case .system: return "System"
        }
    }

    var icon: String {
        switch self {
        case .light: return "sun.max.fill"
        case .dark: return "moon.fill"
        case .system: return "circle.lefthalf.filled"
        }
    }

    var colorScheme: ColorScheme? {
        switch self {
        case .light: return .light
        case .dark: return .dark
        case .system: return nil
        }
    }
}

// MARK: - App Card Modifier

struct AppCardModifier: ViewModifier {
    var padding: CGFloat = 16

    func body(content: Content) -> some View {
        content
            .padding(padding)
            .background(Color(UIColor.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 16))
            .shadow(color: .black.opacity(0.04), radius: 8, y: 2)
    }
}

extension View {
    func appCard(padding: CGFloat = 16) -> some View {
        modifier(AppCardModifier(padding: padding))
    }

    func pageBackground() -> some View {
        self.background(Color(UIColor.systemGroupedBackground))
    }
}

// MARK: - Accent Button Style

struct AccentButtonStyle: ViewModifier {
    var color: Color = .accent

    func body(content: Content) -> some View {
        content
            .font(.headline)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 16)
            .background(color, in: RoundedRectangle(cornerRadius: 14))
            .foregroundStyle(.white)
    }
}

extension View {
    func accentButton(color: Color = .accent) -> some View {
        modifier(AccentButtonStyle(color: color))
    }
}

// MARK: - Section Header

struct SectionHeader: View {
    let title: String

    var body: some View {
        Text(title)
            .font(.title3.weight(.semibold))
            .frame(maxWidth: .infinity, alignment: .leading)
    }
}
```

**Step 9: Create Constants.swift**

```swift
import SwiftUI

enum AppConstants {
    // MARK: - Subscription Product IDs
    static let monthlyProductID = "com.mindrestore.pro.monthly"
    static let annualProductID = "com.mindrestore.pro.annual"
    static let lifetimeProductID = "com.mindrestore.pro.lifetime"

    // MARK: - Spacing
    static let sectionSpacing: CGFloat = 24
    static let cardPadding: CGFloat = 16
    static let baseSpacing: CGFloat = 8

    // MARK: - Exercise Defaults
    static let defaultDailyGoal = 3
    static let spacedRepSessionSize = 15
    static let dualNBackTrialDuration: TimeInterval = 2.5
    static let defaultReminderHour = 9
    static let streakRiskHour = 20 // 8 PM

    // MARK: - Streak Milestones
    static let streakMilestones = [7, 30, 100]
}
```

**Step 10: Create Extensions.swift**

```swift
import SwiftUI

// MARK: - Color

extension Color {
    static let accent = Color(hex: "#2E7D32")
    static let error = Color(hex: "#EF5350")
    static let warning = Color(hex: "#FFA726")

    init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet(charactersIn: "#"))
        let scanner = Scanner(string: hex)
        var rgbValue: UInt64 = 0
        scanner.scanHexInt64(&rgbValue)
        let r = Double((rgbValue & 0xFF0000) >> 16) / 255.0
        let g = Double((rgbValue & 0x00FF00) >> 8) / 255.0
        let b = Double(rgbValue & 0x0000FF) / 255.0
        self.init(red: r, green: g, blue: b)
    }
}

// MARK: - Date

extension Date {
    var startOfDay: Date {
        Calendar.current.startOfDay(for: self)
    }

    var isToday: Bool {
        Calendar.current.isDateInToday(self)
    }

    func daysFrom(_ date: Date) -> Int {
        Calendar.current.dateComponents([.day], from: date.startOfDay, to: self.startOfDay).day ?? 0
    }
}
```

**Step 11: Create ContentView.swift (tab navigation)**

```swift
import SwiftUI

struct ContentView: View {
    @AppStorage("hasCompletedOnboarding") private var hasCompletedOnboarding = false

    var body: some View {
        if hasCompletedOnboarding {
            MainTabView()
        } else {
            OnboardingView()
        }
    }
}

struct MainTabView: View {
    var body: some View {
        TabView {
            Tab("Home", systemImage: "house") {
                Text("Home")
            }
            Tab("Train", systemImage: "brain.head.profile") {
                Text("Train")
            }
            Tab("Progress", systemImage: "chart.line.uptrend.xyaxis") {
                Text("Progress")
            }
            Tab("Settings", systemImage: "gearshape") {
                Text("Settings")
            }
        }
        .tint(.accent)
    }
}
```

**Step 12: Create MindRestoreApp.swift**

```swift
import SwiftUI
import SwiftData

@main
struct MindRestoreApp: App {
    @AppStorage("appTheme") private var appTheme: String = AppTheme.system.rawValue

    private var selectedTheme: AppTheme {
        AppTheme(rawValue: appTheme) ?? .system
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
                .preferredColorScheme(selectedTheme.colorScheme)
        }
        .modelContainer(for: [
            User.self,
            Exercise.self,
            SpacedRepetitionCard.self,
            DailySession.self
        ])
    }
}
```

**Step 13: Create Assets.xcassets**

Create `MindRestore/Assets.xcassets/Contents.json`:
```json
{ "info": { "version": 1, "author": "xcode" } }
```

Create `MindRestore/Assets.xcassets/AccentColor.colorset/Contents.json`:
```json
{
  "colors": [
    {
      "color": { "color-space": "srgb", "components": { "red": "0.180", "green": "0.490", "blue": "0.196", "alpha": "1.000" } },
      "idiom": "universal"
    }
  ],
  "info": { "version": 1, "author": "xcode" }
}
```

Create `MindRestore/Assets.xcassets/AppIcon.appiconset/Contents.json`:
```json
{
  "images": [{ "idiom": "universal", "platform": "ios", "size": "1024x1024" }],
  "info": { "version": 1, "author": "xcode" }
}
```

**Step 14: Generate Xcode project and verify it builds**

```bash
cd /Users/dylanmiller/Desktop/mindrestore
xcodegen generate
xcodebuild -project MindRestore.xcodeproj -scheme MindRestore -destination 'platform=iOS Simulator,name=iPhone 16' build
```

Expected: BUILD SUCCEEDED

**Step 15: Commit**

```bash
git init
git add .
git commit -m "feat: initial project setup with SwiftData models and design system"
```

---

## Task 2: Onboarding Flow

**Files:**
- Create: `MindRestore/Views/Onboarding/OnboardingView.swift`
- Modify: `MindRestore/Views/ContentView.swift`

**Step 1: Create OnboardingView.swift**

3-screen paged TabView:
- Screen 1: "Your memory is a muscle. Let's train it." — brain SF Symbol, explanation text
- Screen 2: "Pick your focus" — multi-select goal cards using UserGoal enum, stored to User model
- Screen 3: "Your data stays on your device. Always." — lock SF Symbol, privacy pitch, "Get Started" CTA

Layout pattern: VStack with large SF Symbol at top, .largeTitle heading, .body description, spacer, action area at bottom. Match StretchCheck's onboarding spacing.

Goal selection: LazyVGrid of tappable cards, each with icon + text, highlighted border when selected (green accent). Min 1, max 3 selections.

"Get Started" button uses `.accentButton()` modifier. On tap: create User in SwiftData, set hasCompletedOnboarding = true, save selectedGoals.

```swift
import SwiftUI
import SwiftData

struct OnboardingView: View {
    @Environment(\.modelContext) private var modelContext
    @AppStorage("hasCompletedOnboarding") private var hasCompletedOnboarding = false
    @State private var currentPage = 0
    @State private var selectedGoals: Set<UserGoal> = []

    var body: some View {
        TabView(selection: $currentPage) {
            welcomePage.tag(0)
            goalsPage.tag(1)
            privacyPage.tag(2)
        }
        .tabViewStyle(.page(indexDisplayMode: .always))
        .indexViewStyle(.page(backgroundDisplayMode: .always))
        .background(Color(UIColor.systemGroupedBackground))
    }

    // Screen 1
    private var welcomePage: some View {
        VStack(spacing: 24) {
            Spacer()
            Image(systemName: "brain.head.profile")
                .font(.system(size: 80))
                .foregroundStyle(.accent)
            Text("Your memory is a muscle.\nLet's train it.")
                .font(.largeTitle.bold())
                .multilineTextAlignment(.center)
            Text("MindRestore uses research-backed techniques — spaced repetition, working memory training, and active recall — to strengthen your memory.")
                .font(.body)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 24)
            Spacer()
            Button("Next") {
                withAnimation(.easeInOut(duration: 0.2)) { currentPage = 1 }
            }
            .accentButton()
            .padding(.horizontal, 24)
            .padding(.bottom, 48)
        }
    }

    // Screen 2
    private var goalsPage: some View {
        VStack(spacing: 24) {
            Spacer()
            Text("Pick your focus")
                .font(.largeTitle.bold())
            Text("Select 1–3 areas you want to improve")
                .font(.body)
                .foregroundStyle(.secondary)
            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                ForEach(UserGoal.allCases) { goal in
                    GoalCard(goal: goal, isSelected: selectedGoals.contains(goal)) {
                        if selectedGoals.contains(goal) {
                            selectedGoals.remove(goal)
                        } else if selectedGoals.count < 3 {
                            selectedGoals.insert(goal)
                        }
                    }
                }
            }
            .padding(.horizontal, 24)
            Spacer()
            Button("Next") {
                withAnimation(.easeInOut(duration: 0.2)) { currentPage = 2 }
            }
            .accentButton()
            .disabled(selectedGoals.isEmpty)
            .opacity(selectedGoals.isEmpty ? 0.5 : 1)
            .padding(.horizontal, 24)
            .padding(.bottom, 48)
        }
    }

    // Screen 3
    private var privacyPage: some View {
        VStack(spacing: 24) {
            Spacer()
            Image(systemName: "lock.shield")
                .font(.system(size: 80))
                .foregroundStyle(.accent)
            Text("Your data stays on your device. Always.")
                .font(.largeTitle.bold())
                .multilineTextAlignment(.center)
            Text("MindRestore never transmits your data anywhere. No accounts, no cloud, no tracking. Just you and your training.")
                .font(.body)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 24)
            Spacer()
            Button("Get Started") {
                completeOnboarding()
            }
            .accentButton()
            .padding(.horizontal, 24)
            .padding(.bottom, 48)
        }
    }

    private func completeOnboarding() {
        let user = User()
        user.selectedGoals = Array(selectedGoals)
        modelContext.insert(user)
        hasCompletedOnboarding = true
    }
}

struct GoalCard: View {
    let goal: UserGoal
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: 8) {
                Image(systemName: goal.icon)
                    .font(.title2)
                    .foregroundStyle(isSelected ? .white : .accent)
                Text(goal.displayName)
                    .font(.caption)
                    .foregroundStyle(isSelected ? .white : .primary)
                    .multilineTextAlignment(.center)
                    .lineLimit(2)
            }
            .frame(maxWidth: .infinity)
            .frame(height: 100)
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(isSelected ? Color.accent : Color(UIColor.secondarySystemGroupedBackground))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 16)
                    .strokeBorder(isSelected ? Color.accent : .clear, lineWidth: 2)
            )
        }
        .buttonStyle(.plain)
    }
}
```

**Step 2: Build and verify**

```bash
xcodebuild -project MindRestore.xcodeproj -scheme MindRestore -destination 'platform=iOS Simulator,name=iPhone 16' build
```

**Step 3: Commit**

```bash
git add MindRestore/Views/Onboarding/
git commit -m "feat: add 3-screen onboarding flow with goal selection"
```

---

## Task 3: Home Dashboard

**Files:**
- Create: `MindRestore/Views/Home/HomeView.swift`
- Create: `MindRestore/Views/Components/StreakBadge.swift`
- Create: `MindRestore/Views/Components/ProgressRing.swift`
- Create: `MindRestore/ViewModels/HomeViewModel.swift`
- Modify: `MindRestore/Views/ContentView.swift` (wire up HomeView in tab)

**Step 1: Create StreakBadge.swift**

```swift
import SwiftUI

struct StreakBadge: View {
    let count: Int
    let isActive: Bool
    @State private var animate = false

    var body: some View {
        HStack(spacing: 6) {
            Image(systemName: "flame.fill")
                .foregroundStyle(isActive ? .accent : .secondary)
                .scaleEffect(animate ? 1.2 : 1.0)
            Text("\(count)")
                .font(.title2.bold())
                .foregroundStyle(isActive ? .primary : .secondary)
        }
        .onChange(of: count) { oldValue, newValue in
            if AppConstants.streakMilestones.contains(newValue) {
                withAnimation(.spring(response: 0.5, dampingFraction: 0.6)) {
                    animate = true
                }
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                    animate = false
                }
            }
        }
    }
}
```

**Step 2: Create ProgressRing.swift**

Port StretchCheck's StreakRingView, use green accent:

```swift
import SwiftUI

struct ProgressRing: View {
    let progress: Double // 0.0 - 1.0
    var lineWidth: CGFloat = 12
    var size: CGFloat = 120
    let label: String
    let sublabel: String

    var body: some View {
        ZStack {
            Circle()
                .stroke(Color.accent.opacity(0.15), lineWidth: lineWidth)
            Circle()
                .trim(from: 0, to: CGFloat(min(progress, 1.0)))
                .stroke(Color.accent, style: StrokeStyle(lineWidth: lineWidth, lineCap: .round))
                .rotationEffect(.degrees(-90))
                .animation(.easeInOut(duration: 0.3), value: progress)
            VStack(spacing: 2) {
                Text(label)
                    .font(.system(size: size * 0.25, weight: .bold, design: .rounded))
                Text(sublabel)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .frame(width: size, height: size)
    }
}
```

**Step 3: Create HomeViewModel.swift**

```swift
import SwiftUI
import SwiftData

@Observable
final class HomeViewModel {
    var user: User?
    var todaySession: DailySession?

    var currentStreak: Int { user?.currentStreak ?? 0 }
    var isStreakActive: Bool { user?.isStreakActive ?? false }
    var longestStreak: Int { user?.longestStreak ?? 0 }
    var dailyGoal: Int { user?.dailyGoal ?? AppConstants.defaultDailyGoal }
    var exercisesCompletedToday: Int { todaySession?.exercisesCompleted ?? 0 }
    var sessionProgress: Double {
        guard dailyGoal > 0 else { return 0 }
        return Double(exercisesCompletedToday) / Double(dailyGoal)
    }
    var todayComplete: Bool { exercisesCompletedToday >= dailyGoal }

    func load(users: [User], sessions: [DailySession]) {
        self.user = users.first
        let today = Calendar.current.startOfDay(for: .now)
        self.todaySession = sessions.first { Calendar.current.isDate($0.date, inSameDayAs: today) }
    }
}
```

**Step 4: Create HomeView.swift**

```swift
import SwiftUI
import SwiftData

struct HomeView: View {
    @Query private var users: [User]
    @Query(sort: \DailySession.date, order: .reverse) private var sessions: [DailySession]
    @State private var viewModel = HomeViewModel()
    @State private var showTraining = false

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: AppConstants.sectionSpacing) {
                    streakCard
                    todayCard
                    quickStatsRow
                    learnSection
                }
                .padding(.horizontal)
                .padding(.top, 8)
                .padding(.bottom, 32)
            }
            .background(Color(UIColor.systemGroupedBackground))
            .navigationTitle("MindRestore")
            .onAppear { viewModel.load(users: users, sessions: sessions) }
            .onChange(of: users) { _, new in viewModel.load(users: new, sessions: sessions) }
            .onChange(of: sessions) { _, new in viewModel.load(users: users, sessions: new) }
        }
    }

    // MARK: - Streak Card
    private var streakCard: some View {
        HStack(spacing: 16) {
            ProgressRing(
                progress: viewModel.sessionProgress,
                lineWidth: 10,
                size: 100,
                label: "\(viewModel.exercisesCompletedToday)/\(viewModel.dailyGoal)",
                sublabel: "today"
            )
            VStack(alignment: .leading, spacing: 8) {
                StreakBadge(count: viewModel.currentStreak, isActive: viewModel.isStreakActive)
                Text(viewModel.isStreakActive ? "Streak active" : "Start training to begin a streak")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                if viewModel.longestStreak > 0 {
                    Text("Best: \(viewModel.longestStreak) days")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            Spacer()
        }
        .appCard()
    }

    // MARK: - Today Card
    private var todayCard: some View {
        VStack(spacing: 16) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(viewModel.todayComplete ? "Training Complete" : "Today's Training")
                        .font(.headline)
                    Text(viewModel.todayComplete
                         ? "Great work! Come back tomorrow."
                         : "\(viewModel.dailyGoal - viewModel.exercisesCompletedToday) exercises remaining")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                Image(systemName: viewModel.todayComplete ? "checkmark.circle.fill" : "play.circle.fill")
                    .font(.title)
                    .foregroundStyle(.accent)
            }
            if !viewModel.todayComplete {
                Button("Start Training") {
                    showTraining = true
                }
                .accentButton()
            }
        }
        .appCard()
        .fullScreenCover(isPresented: $showTraining) {
            // Training flow will be wired in Task 7
            Text("Training Flow Placeholder")
        }
    }

    // MARK: - Quick Stats
    private var quickStatsRow: some View {
        HStack(spacing: 12) {
            StatCard(icon: "calendar", label: "Sessions", value: "\(sessions.count)")
            StatCard(icon: "star", label: "Avg Score", value: avgScoreString)
        }
    }

    private var avgScoreString: String {
        let scores = sessions.map(\.totalScore).filter { $0 > 0 }
        guard !scores.isEmpty else { return "—" }
        let avg = scores.reduce(0, +) / Double(scores.count)
        return "\(Int(avg * 100))%"
    }

    // MARK: - Learn Section
    private var learnSection: some View {
        VStack(spacing: 12) {
            SectionHeader(title: "Learn")
            Text("Psychoeducation cards coming soon")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .frame(maxWidth: .infinity, alignment: .leading)
                .appCard()
        }
    }
}

// MARK: - Stat Card

struct StatCard: View {
    let icon: String
    let label: String
    let value: String

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Image(systemName: icon)
                .font(.title3)
                .foregroundStyle(.accent)
            Text(value)
                .font(.title2.bold())
            Text(label)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .appCard()
    }
}
```

**Step 5: Wire HomeView into ContentView tabs**

Update `MainTabView` to use `HomeView()` for the Home tab.

**Step 6: Build and verify**

```bash
xcodebuild -project MindRestore.xcodeproj -scheme MindRestore -destination 'platform=iOS Simulator,name=iPhone 16' build
```

**Step 7: Commit**

```bash
git add MindRestore/Views/Home/ MindRestore/Views/Components/ MindRestore/ViewModels/HomeViewModel.swift
git commit -m "feat: add home dashboard with streak, progress ring, and stats"
```

---

## Task 4: Spaced Repetition Engine + Exercise

**Files:**
- Create: `MindRestore/Services/SpacedRepetitionEngine.swift`
- Create: `MindRestore/Content/SpacedRepetitionContent.swift`
- Create: `MindRestore/ViewModels/SpacedRepetitionViewModel.swift`
- Create: `MindRestore/Views/Exercises/SpacedRepetitionView.swift`

**Step 1: Create SpacedRepetitionEngine.swift**

SM-2 algorithm implementation:

```swift
import Foundation

final class SpacedRepetitionEngine {
    /// Process a user rating and update the card's scheduling parameters
    /// Rating: 0 = Again, 1 = Hard, 2 = Good, 3 = Easy
    func processRating(_ card: SpacedRepetitionCard, rating: Int) {
        let rating = max(0, min(3, rating))

        if rating == 0 {
            card.repetitions = 0
            card.interval = 1
        } else {
            if card.repetitions == 0 {
                card.interval = 1
            } else if card.repetitions == 1 {
                card.interval = 6
            } else {
                card.interval = Int(Double(card.interval) * card.easeFactor)
            }
            card.repetitions += 1
        }

        // Update ease factor
        let ef = card.easeFactor + (0.1 - Double(3 - rating) * (0.08 + Double(3 - rating) * 0.02))
        card.easeFactor = max(1.3, ef)

        // Schedule next review
        card.lastReviewDate = Date()
        card.nextReviewDate = Calendar.current.date(byAdding: .day, value: card.interval, to: Date()) ?? Date()
    }

    /// Get cards for a session: due cards first, then new cards
    func getSessionCards(from allCards: [SpacedRepetitionCard], limit: Int = 15) -> [SpacedRepetitionCard] {
        let now = Date()
        let dueCards = allCards.filter { $0.nextReviewDate <= now && $0.repetitions > 0 }
            .sorted { $0.nextReviewDate < $1.nextReviewDate }
        let newCards = allCards.filter { $0.repetitions == 0 }
            .shuffled()

        var session: [SpacedRepetitionCard] = []
        session.append(contentsOf: dueCards.prefix(limit))
        if session.count < limit {
            session.append(contentsOf: newCards.prefix(limit - session.count))
        }
        return session
    }
}
```

**Step 2: Create SpacedRepetitionContent.swift**

100 cards total (20 per category). Structure:

```swift
import Foundation

enum SpacedRepetitionContent {
    static func allCards() -> [(category: CardCategory, prompt: String, answer: String)] {
        numberCards + wordCards + faceCards + locationCards + dailyLifeCards
    }

    // 20 number sequence cards
    static let numberCards: [(category: CardCategory, prompt: String, answer: String)] = [
        (.numbers, "Remember this sequence: 4 7 2 9", "4 7 2 9"),
        (.numbers, "Remember this sequence: 3 8 1 5", "3 8 1 5"),
        (.numbers, "Remember this sequence: 6 2 9 4 1", "6 2 9 4 1"),
        (.numbers, "Remember this sequence: 8 3 7 1 5", "8 3 7 1 5"),
        (.numbers, "Remember this sequence: 2 9 4 7 3 6", "2 9 4 7 3 6"),
        (.numbers, "Remember this sequence: 5 1 8 3 9 2", "5 1 8 3 9 2"),
        (.numbers, "Remember this sequence: 7 4 1 8 2 5 9", "7 4 1 8 2 5 9"),
        (.numbers, "Remember this sequence: 3 6 9 2 5 8 1", "3 6 9 2 5 8 1"),
        (.numbers, "Remember this sequence: 1 5 9 3 7", "1 5 9 3 7"),
        (.numbers, "Remember this sequence: 8 2 6 4 1 7", "8 2 6 4 1 7"),
        (.numbers, "Remember this sequence: 4 8 2 6 9 3 7", "4 8 2 6 9 3 7"),
        (.numbers, "Remember this sequence: 9 1 5 3 7 2 8 4", "9 1 5 3 7 2 8 4"),
        (.numbers, "Remember this sequence: 2 7 4 9", "2 7 4 9"),
        (.numbers, "Remember this sequence: 6 3 8 1 5 9", "6 3 8 1 5 9"),
        (.numbers, "Remember this sequence: 1 4 7 2 8", "1 4 7 2 8"),
        (.numbers, "Remember this sequence: 5 9 3 7 1 4 8", "5 9 3 7 1 4 8"),
        (.numbers, "Remember this sequence: 3 6 1 8 4", "3 6 1 8 4"),
        (.numbers, "Remember this sequence: 7 2 5 9 3 6 1 8", "7 2 5 9 3 6 1 8"),
        (.numbers, "Remember this sequence: 9 4 7 2 5", "9 4 7 2 5"),
        (.numbers, "Remember this sequence: 8 1 4 7 3 6 9 2", "8 1 4 7 3 6 9 2"),
    ]

    // 20 word list cards
    static let wordCards: [(category: CardCategory, prompt: String, answer: String)] = [
        (.words, "Remember these words: Apple, Bridge, Clock, Drum, Eagle", "Apple, Bridge, Clock, Drum, Eagle"),
        (.words, "Remember these words: Forest, Guitar, Hammer, Island, Jacket", "Forest, Guitar, Hammer, Island, Jacket"),
        (.words, "Remember these words: Kettle, Lemon, Mirror, Notebook, Orange", "Kettle, Lemon, Mirror, Notebook, Orange"),
        (.words, "Remember these words: Pencil, Quilt, River, Sunset, Tower", "Pencil, Quilt, River, Sunset, Tower"),
        (.words, "Remember these words: Umbrella, Violin, Window, Anchor, Bottle", "Umbrella, Violin, Window, Anchor, Bottle"),
        (.words, "Remember these words: Canyon, Diamond, Elephant, Fountain, Globe", "Canyon, Diamond, Elephant, Fountain, Globe"),
        (.words, "Remember these words: Harbor, Igloo, Jungle, Kite, Lantern", "Harbor, Igloo, Jungle, Kite, Lantern"),
        (.words, "Remember these words: Marble, Neptune, Orchid, Puzzle, Rocket", "Marble, Neptune, Orchid, Puzzle, Rocket"),
        (.words, "Remember these words: Saddle, Thunder, Velvet, Whistle, Crystal", "Saddle, Thunder, Velvet, Whistle, Crystal"),
        (.words, "Remember these words: Feather, Glacier, Horizon, Jasmine, Magnet", "Feather, Glacier, Horizon, Jasmine, Magnet"),
        (.words, "Remember these words: Cabin, Desert, Engine, Falcon, Garden, Harbor", "Cabin, Desert, Engine, Falcon, Garden, Harbor"),
        (.words, "Remember these words: Piano, Basket, Coral, Dragon, Ember, Flute", "Piano, Basket, Coral, Dragon, Ember, Flute"),
        (.words, "Remember these words: Silver, Timber, Valley, Walnut, Anchor, Breeze", "Silver, Timber, Valley, Walnut, Anchor, Breeze"),
        (.words, "Remember these words: Chapel, Dagger, Falcon, Gravel, Helmet, Ivory", "Chapel, Dagger, Falcon, Gravel, Helmet, Ivory"),
        (.words, "Remember these words: Meadow, Nebula, Oyster, Pebble, Rapids, Shelter", "Meadow, Nebula, Oyster, Pebble, Rapids, Shelter"),
        (.words, "Remember these words: Candle, Throne, Voyage, Willow, Zenith", "Candle, Throne, Voyage, Willow, Zenith"),
        (.words, "Remember these words: Branch, Copper, Geyser, Plume, Sphinx", "Branch, Copper, Geyser, Plume, Sphinx"),
        (.words, "Remember these words: Cobalt, Driftwood, Ember, Fossil, Garnet, Heron", "Cobalt, Driftwood, Ember, Fossil, Garnet, Heron"),
        (.words, "Remember these words: Prism, Quartz, Raven, Summit, Tundra", "Prism, Quartz, Raven, Summit, Tundra"),
        (.words, "Remember these words: Atlas, Beacon, Crest, Delta, Echo, Forge", "Atlas, Beacon, Crest, Delta, Echo, Forge"),
    ]

    // 20 face-name pair cards (text-based)
    static let faceCards: [(category: CardCategory, prompt: String, answer: String)] = [
        (.faces, "Sarah has curly red hair and wears glasses. What does Sarah look like?", "Curly red hair, wears glasses"),
        (.faces, "Marcus has a beard and a scar on his left cheek. What does Marcus look like?", "Beard, scar on left cheek"),
        (.faces, "Elena has straight black hair and dimples. What does Elena look like?", "Straight black hair, dimples"),
        (.faces, "James is bald with blue eyes and freckles. What does James look like?", "Bald, blue eyes, freckles"),
        (.faces, "Priya has a nose ring and long braided hair. What does Priya look like?", "Nose ring, long braided hair"),
        (.faces, "Tom has a mustache and wears a baseball cap. What does Tom look like?", "Mustache, wears baseball cap"),
        (.faces, "Mei has bangs and round glasses. What does Mei look like?", "Bangs, round glasses"),
        (.faces, "Carlos has a goatee and a tattoo on his neck. What does Carlos look like?", "Goatee, neck tattoo"),
        (.faces, "Aisha has high cheekbones and silver earrings. What does Aisha look like?", "High cheekbones, silver earrings"),
        (.faces, "Ryan has shaggy blond hair and green eyes. What does Ryan look like?", "Shaggy blond hair, green eyes"),
        (.faces, "Olivia has a pixie cut and a birthmark on her forehead. What does Olivia look like?", "Pixie cut, birthmark on forehead"),
        (.faces, "David has thick eyebrows and a crooked nose. What does David look like?", "Thick eyebrows, crooked nose"),
        (.faces, "Nina has wavy brown hair and a gap in her front teeth. What does Nina look like?", "Wavy brown hair, gap in front teeth"),
        (.faces, "Kenji wears wire-frame glasses and has a crew cut. What does Kenji look like?", "Wire-frame glasses, crew cut"),
        (.faces, "Sophie has freckles and auburn hair in a ponytail. What does Sophie look like?", "Freckles, auburn ponytail"),
        (.faces, "Andre has dreadlocks and a wide smile. What does Andre look like?", "Dreadlocks, wide smile"),
        (.faces, "Lily has almond-shaped eyes and a mole above her lip. What does Lily look like?", "Almond-shaped eyes, mole above lip"),
        (.faces, "Max has a buzz cut and deep-set eyes. What does Max look like?", "Buzz cut, deep-set eyes"),
        (.faces, "Zara has a long neck and wears hoop earrings. What does Zara look like?", "Long neck, hoop earrings"),
        (.faces, "Owen has a cleft chin and sandy brown hair. What does Owen look like?", "Cleft chin, sandy brown hair"),
    ]

    // 20 location sequence cards
    static let locationCards: [(category: CardCategory, prompt: String, answer: String)] = [
        (.locations, "Path: Kitchen → Bedroom → Bathroom", "Kitchen → Bedroom → Bathroom"),
        (.locations, "Path: Park → Library → Cafe → Home", "Park → Library → Cafe → Home"),
        (.locations, "Path: Office → Elevator → Lobby → Parking", "Office → Elevator → Lobby → Parking"),
        (.locations, "Path: Beach → Pier → Boardwalk → Restaurant", "Beach → Pier → Boardwalk → Restaurant"),
        (.locations, "Path: Airport → Gate B4 → Plane → Taxi", "Airport → Gate B4 → Plane → Taxi"),
        (.locations, "Path: School → Gym → Pool → Locker Room → Exit", "School → Gym → Pool → Locker Room → Exit"),
        (.locations, "Path: Market → Bakery → Butcher → Checkout", "Market → Bakery → Butcher → Checkout"),
        (.locations, "Path: Station → Train → Bridge → Tunnel → Downtown", "Station → Train → Bridge → Tunnel → Downtown"),
        (.locations, "Path: Garden → Greenhouse → Shed → Patio", "Garden → Greenhouse → Shed → Patio"),
        (.locations, "Path: Museum → Hall A → Gallery 3 → Gift Shop", "Museum → Hall A → Gallery 3 → Gift Shop"),
        (.locations, "Path: Hospital → Floor 3 → Room 312 → Pharmacy", "Hospital → Floor 3 → Room 312 → Pharmacy"),
        (.locations, "Path: Mall → Escalator → Food Court → Cinema", "Mall → Escalator → Food Court → Cinema"),
        (.locations, "Path: Forest → Trail → Lake → Cabin → Dock", "Forest → Trail → Lake → Cabin → Dock"),
        (.locations, "Path: Hotel → Lobby → Pool → Spa → Room 205", "Hotel → Lobby → Pool → Spa → Room 205"),
        (.locations, "Path: Campus → Library → Quad → Lab Building", "Campus → Library → Quad → Lab Building"),
        (.locations, "Path: Downtown → Bridge → Island → Lighthouse", "Downtown → Bridge → Island → Lighthouse"),
        (.locations, "Path: Subway → Transfer → Line 4 → Exit C", "Subway → Transfer → Line 4 → Exit C"),
        (.locations, "Path: Village → Church → Square → River → Mill", "Village → Church → Square → River → Mill"),
        (.locations, "Path: Stadium → Section 12 → Row F → Seat 8", "Stadium → Section 12 → Row F → Seat 8"),
        (.locations, "Path: Harbor → Dock 7 → Ferry → Island Terminal", "Harbor → Dock 7 → Ferry → Island Terminal"),
    ]

    // 20 daily life scenario cards
    static let dailyLifeCards: [(category: CardCategory, prompt: String, answer: String)] = [
        (.dailyLife, "At a meeting, you're told: 1) Email the report by Friday 2) Book the conference room 3) Call the client at 3pm 4) Update the spreadsheet", "1) Email report by Friday 2) Book conference room 3) Call client at 3pm 4) Update spreadsheet"),
        (.dailyLife, "Your friend says: Meet at the Italian place on Oak Street at 7:30, bring the book you borrowed, and Sarah might join us", "Italian place, Oak Street, 7:30, bring book, Sarah might join"),
        (.dailyLife, "Shopping list: eggs, whole wheat bread, almond milk, avocados, chicken thighs, garlic", "Eggs, whole wheat bread, almond milk, avocados, chicken thighs, garlic"),
        (.dailyLife, "Your doctor says: Take the blue pill twice daily with food, the white pill once at bedtime, follow up in 2 weeks", "Blue pill 2x daily with food, white pill 1x at bedtime, follow up 2 weeks"),
        (.dailyLife, "Directions: Go north on Main St, turn left on 3rd Ave, right on Pine Rd, destination is the 4th building on the left", "North on Main, left on 3rd Ave, right on Pine Rd, 4th building on left"),
        (.dailyLife, "Your boss mentions: The deadline moved to Wednesday, use the new template, cc Marketing on all updates", "Deadline Wednesday, use new template, cc Marketing"),
        (.dailyLife, "At the mechanic: Oil change done, front brakes need replacing within 3 months, tire rotation at next visit, total today is $89", "Oil change done, front brakes within 3 months, tire rotation next visit, $89 today"),
        (.dailyLife, "Party details: Saturday at 6pm, bring a dessert, it's at Mike's new apartment on 5th floor, buzzer code is 4521", "Saturday 6pm, bring dessert, Mike's apartment 5th floor, buzzer 4521"),
        (.dailyLife, "Landlord says: Maintenance coming Tuesday 9-12, leave key under mat, they'll fix the dishwasher and check the AC filter", "Tuesday 9-12, key under mat, fix dishwasher, check AC filter"),
        (.dailyLife, "Travel info: Flight AA234 departs at 6:15am from Terminal B, board at gate 47, connecting in Dallas, 1 hour layover", "AA234, 6:15am, Terminal B, Gate 47, connect Dallas, 1 hour layover"),
        (.dailyLife, "Recipe: Preheat to 375°F, mix 2 cups flour and 1 tsp baking soda, bake for 22 minutes, let cool 10 minutes", "375°F, 2 cups flour + 1 tsp baking soda, bake 22 min, cool 10 min"),
        (.dailyLife, "Coworker asks: Print 15 copies of the Q3 report, staple them, put them in the blue folders, leave on Karen's desk by 2pm", "15 copies Q3 report, staple, blue folders, Karen's desk by 2pm"),
        (.dailyLife, "Vet says: Give Rex the antibiotics for 10 days, half a tablet morning and evening, no swimming for a week, check up on the 15th", "Antibiotics 10 days, half tablet AM/PM, no swimming 1 week, checkup 15th"),
        (.dailyLife, "Event details: Conference starts at 9am in Building C, your panel is at 11:30 in Room 204, lunch is catered in the atrium", "9am Building C, panel 11:30 Room 204, lunch catered in atrium"),
        (.dailyLife, "Parent says: Pick up your sister at 3:15 from soccer practice at Lincoln Park, stop for gas, grab milk on the way home", "Sister 3:15, soccer at Lincoln Park, stop for gas, grab milk"),
        (.dailyLife, "Barista instructions: Large oat milk latte with an extra shot, no sugar, extra hot, name is for Jordan", "Large oat milk latte, extra shot, no sugar, extra hot, name Jordan"),
        (.dailyLife, "Moving day: Truck arrives at 8am, disassemble the bed frame first, fragile boxes go in the car, new address is 742 Elm St Apt 3B", "Truck 8am, bed frame first, fragile in car, 742 Elm St Apt 3B"),
        (.dailyLife, "IT support says: Reset your password using the link they emailed, new VPN server is vpn2.company.com, ticket number is INC-4488", "Reset password via email link, VPN: vpn2.company.com, ticket INC-4488"),
        (.dailyLife, "Gym trainer says: 3 sets of 12 squats, 4 sets of 8 deadlifts at 135lbs, finish with 15 minutes on the bike", "3×12 squats, 4×8 deadlifts 135lbs, 15 min bike"),
        (.dailyLife, "Neighbor says: Package coming Thursday, leave it by the back door if we're not home, dog walker comes at noon so gate should be closed", "Package Thursday, back door if not home, dog walker noon, close gate"),
    ]
}
```

**Step 3: Create SpacedRepetitionViewModel.swift**

```swift
import SwiftUI
import SwiftData

@Observable
final class SpacedRepetitionViewModel {
    private let engine = SpacedRepetitionEngine()

    var sessionCards: [SpacedRepetitionCard] = []
    var currentIndex = 0
    var isShowingAnswer = false
    var sessionComplete = false
    var sessionScore: Double = 0.0
    var startTime = Date()

    // For timed display of prompts
    var isShowingPrompt = true
    var promptCountdown: Int = 5

    var currentCard: SpacedRepetitionCard? {
        guard currentIndex < sessionCards.count else { return nil }
        return sessionCards[currentIndex]
    }

    var progress: Double {
        guard !sessionCards.isEmpty else { return 0 }
        return Double(currentIndex) / Double(sessionCards.count)
    }

    func loadSession(allCards: [SpacedRepetitionCard], isProUser: Bool) {
        let filtered = isProUser ? allCards : allCards.filter { $0.category == .numbers }
        sessionCards = engine.getSessionCards(from: filtered)
        currentIndex = 0
        isShowingAnswer = false
        sessionComplete = false
        sessionScore = 0.0
        startTime = Date()
    }

    func revealAnswer() {
        isShowingAnswer = true
    }

    func rate(_ rating: Int) {
        guard let card = currentCard else { return }
        engine.processRating(card, rating: rating)

        // Track score (Good=2 or Easy=3 count as correct)
        if rating >= 2 {
            sessionScore += 1
        }

        currentIndex += 1
        isShowingAnswer = false

        if currentIndex >= sessionCards.count {
            sessionComplete = true
            sessionScore = sessionCards.isEmpty ? 0 : sessionScore / Double(sessionCards.count)
        }
    }

    var durationSeconds: Int {
        Int(Date().timeIntervalSince(startTime))
    }
}
```

**Step 4: Create SpacedRepetitionView.swift**

```swift
import SwiftUI
import SwiftData

struct SpacedRepetitionView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @Query private var cards: [SpacedRepetitionCard]
    @Query private var users: [User]
    @State private var viewModel = SpacedRepetitionViewModel()
    let onComplete: (Exercise) -> Void

    var body: some View {
        VStack(spacing: 0) {
            header
            if viewModel.sessionComplete {
                completionView
            } else if let card = viewModel.currentCard {
                cardView(card)
            } else {
                emptyView
            }
        }
        .background(Color(UIColor.systemGroupedBackground))
        .onAppear { loadSession() }
    }

    private var header: some View {
        HStack {
            Button { dismiss() } label: {
                Image(systemName: "xmark")
                    .font(.title3)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            Text("Spaced Repetition")
                .font(.headline)
            Spacer()
            Text("\(viewModel.currentIndex + 1)/\(viewModel.sessionCards.count)")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .padding()
    }

    private func cardView(_ card: SpacedRepetitionCard) -> some View {
        VStack(spacing: 24) {
            // Progress bar
            ProgressView(value: viewModel.progress)
                .tint(.accent)
                .padding(.horizontal)

            Spacer()

            // Card content
            VStack(spacing: 24) {
                Text(card.prompt)
                    .font(.title3)
                    .multilineTextAlignment(.center)
                    .padding()

                if viewModel.isShowingAnswer {
                    Divider()
                    Text(card.answer)
                        .font(.title2.bold())
                        .multilineTextAlignment(.center)
                        .padding()
                        .transition(.opacity)
                }
            }
            .appCard()
            .padding(.horizontal)

            Spacer()

            // Action area
            if viewModel.isShowingAnswer {
                ratingButtons
            } else {
                Button("Show Answer") {
                    withAnimation(.easeInOut(duration: 0.2)) {
                        viewModel.revealAnswer()
                    }
                }
                .accentButton()
                .padding(.horizontal)
            }
        }
        .padding(.bottom, 32)
    }

    private var ratingButtons: some View {
        HStack(spacing: 12) {
            ratingButton("Again", color: .error, rating: 0)
            ratingButton("Hard", color: .warning, rating: 1)
            ratingButton("Good", color: .accent, rating: 2)
            ratingButton("Easy", color: .blue, rating: 3)
        }
        .padding(.horizontal)
    }

    private func ratingButton(_ title: String, color: Color, rating: Int) -> some View {
        Button {
            UIImpactFeedbackGenerator(style: .light).impactOccurred()
            viewModel.rate(rating)
        } label: {
            Text(title)
                .font(.subheadline.weight(.semibold))
                .frame(maxWidth: .infinity)
                .padding(.vertical, 14)
                .background(color, in: RoundedRectangle(cornerRadius: 12))
                .foregroundStyle(.white)
        }
    }

    private var completionView: some View {
        VStack(spacing: 24) {
            Spacer()
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 64))
                .foregroundStyle(.accent)
            Text("Session Complete!")
                .font(.title.bold())
            Text("\(Int(viewModel.sessionScore * 100))% accuracy")
                .font(.title3)
                .foregroundStyle(.secondary)
            Spacer()
            Button("Done") {
                let exercise = Exercise(
                    type: .spacedRepetition,
                    difficulty: 1,
                    score: viewModel.sessionScore,
                    durationSeconds: viewModel.durationSeconds
                )
                onComplete(exercise)
                dismiss()
            }
            .accentButton()
            .padding(.horizontal)
            .padding(.bottom, 32)
        }
    }

    private var emptyView: some View {
        VStack(spacing: 16) {
            Spacer()
            Image(systemName: "tray")
                .font(.system(size: 48))
                .foregroundStyle(.secondary)
            Text("No cards to review")
                .font(.headline)
            Text("All caught up! Check back later.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
            Spacer()
        }
    }

    private func loadSession() {
        let isProUser = users.first?.isProUser ?? false
        if cards.isEmpty {
            seedCards()
        }
        viewModel.loadSession(allCards: cards, isProUser: isProUser)
    }

    private func seedCards() {
        for cardData in SpacedRepetitionContent.allCards() {
            let card = SpacedRepetitionCard(category: cardData.category, prompt: cardData.prompt, answer: cardData.answer)
            modelContext.insert(card)
        }
        try? modelContext.save()
    }
}
```

**Step 5: Build and verify**

```bash
xcodebuild -project MindRestore.xcodeproj -scheme MindRestore -destination 'platform=iOS Simulator,name=iPhone 16' build
```

**Step 6: Commit**

```bash
git add MindRestore/Services/SpacedRepetitionEngine.swift MindRestore/Content/SpacedRepetitionContent.swift MindRestore/ViewModels/SpacedRepetitionViewModel.swift MindRestore/Views/Exercises/SpacedRepetitionView.swift
git commit -m "feat: add spaced repetition engine with SM-2 algorithm and 100 cards"
```

---

## Task 5: Dual N-Back Exercise

**Files:**
- Create: `MindRestore/ViewModels/DualNBackViewModel.swift`
- Create: `MindRestore/Views/Exercises/DualNBackView.swift`

**Step 1: Create DualNBackViewModel.swift**

```swift
import SwiftUI
import AVFoundation

@Observable
final class DualNBackViewModel {
    // Game state
    var currentN: Int = 1
    var positions: [Int] = []       // 0-8 grid indices
    var letters: [String] = []
    var trialIndex: Int = 0
    var totalTrials: Int = 0
    var isRunning = false
    var isPaused = false
    var gameComplete = false
    var isProUser = false

    // Current trial display
    var activePosition: Int? = nil
    var activeLetter: String = ""

    // User input tracking
    var positionMatchTapped = false
    var soundMatchTapped = false

    // Scoring
    var positionHits = 0
    var positionMisses = 0
    var positionFalseAlarms = 0
    var soundHits = 0
    var soundMisses = 0
    var soundFalseAlarms = 0
    var startTime = Date()

    // Timer
    private var timer: Timer?
    private let synthesizer = AVSpeechSynthesizer()

    private let availableLetters = ["C", "H", "K", "L", "Q", "R", "S", "T"]

    var positionScore: Double {
        let total = positionHits + positionMisses
        guard total > 0 else { return 0 }
        return Double(max(0, positionHits - positionFalseAlarms)) / Double(total)
    }

    var soundScore: Double {
        let total = soundHits + soundMisses
        guard total > 0 else { return 0 }
        return Double(max(0, soundHits - soundFalseAlarms)) / Double(total)
    }

    var overallScore: Double {
        isProUser ? (positionScore + soundScore) / 2.0 : positionScore
    }

    var trialProgress: Double {
        guard totalTrials > 0 else { return 0 }
        return Double(trialIndex) / Double(totalTrials)
    }

    func startGame(n: Int, isProUser: Bool) {
        self.isProUser = isProUser
        self.currentN = isProUser ? n : 1
        self.totalTrials = 20 + currentN
        self.trialIndex = 0
        self.positions = []
        self.letters = []
        self.positionHits = 0
        self.positionMisses = 0
        self.positionFalseAlarms = 0
        self.soundHits = 0
        self.soundMisses = 0
        self.soundFalseAlarms = 0
        self.gameComplete = false
        self.startTime = Date()
        self.isRunning = true

        nextTrial()
    }

    func nextTrial() {
        guard trialIndex < totalTrials else {
            endGame()
            return
        }

        // Score previous trial responses (if not the first N trials)
        if trialIndex >= currentN {
            scoreTrial()
        }

        // Reset taps
        positionMatchTapped = false
        soundMatchTapped = false

        // Generate new stimulus
        let newPosition = Int.random(in: 0...8)
        let newLetter = availableLetters.randomElement() ?? "C"
        positions.append(newPosition)
        letters.append(newLetter)

        activePosition = newPosition
        activeLetter = newLetter

        // Speak letter if pro (dual mode)
        if isProUser {
            speakLetter(newLetter)
        }

        trialIndex += 1

        // Schedule next trial
        timer?.invalidate()
        timer = Timer.scheduledTimer(withTimeInterval: AppConstants.dualNBackTrialDuration, repeats: false) { [weak self] _ in
            Task { @MainActor in
                self?.activePosition = nil
                // Brief pause then next
                try? await Task.sleep(for: .milliseconds(300))
                self?.nextTrial()
            }
        }
    }

    private func scoreTrial() {
        let idx = positions.count - 1
        let nBackIdx = idx - currentN

        guard nBackIdx >= 0 else { return }

        // Position scoring
        let isPositionMatch = positions[idx] == positions[nBackIdx]
        if isPositionMatch {
            if positionMatchTapped { positionHits += 1 }
            else { positionMisses += 1 }
        } else {
            if positionMatchTapped { positionFalseAlarms += 1 }
        }

        // Sound scoring (pro only)
        if isProUser {
            let isSoundMatch = letters[idx] == letters[nBackIdx]
            if isSoundMatch {
                if soundMatchTapped { soundHits += 1 }
                else { soundMisses += 1 }
            } else {
                if soundMatchTapped { soundFalseAlarms += 1 }
            }
        }
    }

    func tapPositionMatch() {
        guard isRunning, !positionMatchTapped else { return }
        positionMatchTapped = true
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
    }

    func tapSoundMatch() {
        guard isRunning, isProUser, !soundMatchTapped else { return }
        soundMatchTapped = true
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
    }

    private func endGame() {
        // Score the last trial
        scoreTrial()

        isRunning = false
        gameComplete = true
        timer?.invalidate()

        // Adaptive difficulty (pro only)
        if isProUser {
            if positionScore > 0.8 && soundScore > 0.8 {
                currentN = min(5, currentN + 1)
            } else if positionScore < 0.5 || soundScore < 0.5 {
                currentN = max(1, currentN - 1)
            }
        }
    }

    private func speakLetter(_ letter: String) {
        let utterance = AVSpeechUtterance(string: letter)
        utterance.rate = 0.5
        utterance.volume = 0.8
        synthesizer.speak(utterance)
    }

    func stop() {
        timer?.invalidate()
        isRunning = false
    }

    var durationSeconds: Int {
        Int(Date().timeIntervalSince(startTime))
    }
}
```

**Step 2: Create DualNBackView.swift**

```swift
import SwiftUI
import SwiftData

struct DualNBackView: View {
    @Environment(\.dismiss) private var dismiss
    @Query private var users: [User]
    @State private var viewModel = DualNBackViewModel()
    let onComplete: (Exercise) -> Void

    private let gridSize = 3
    private let cellSize: CGFloat = 90

    var body: some View {
        VStack(spacing: 0) {
            header

            if viewModel.gameComplete {
                resultsView
            } else if viewModel.isRunning {
                gameView
            } else {
                startView
            }
        }
        .background(Color(UIColor.systemGroupedBackground))
        .onDisappear { viewModel.stop() }
    }

    private var header: some View {
        HStack {
            Button { viewModel.stop(); dismiss() } label: {
                Image(systemName: "xmark")
                    .font(.title3)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            Text("\(viewModel.currentN)-Back")
                .font(.headline)
            Spacer()
            Text("\(viewModel.trialIndex)/\(viewModel.totalTrials)")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .padding()
    }

    private var startView: some View {
        VStack(spacing: 24) {
            Spacer()
            Image(systemName: "square.grid.3x3")
                .font(.system(size: 64))
                .foregroundStyle(.accent)
            Text("Dual N-Back")
                .font(.title.bold())
            Text("Tap 'Position Match' when the square appears in the same position as \(viewModel.currentN) step\(viewModel.currentN > 1 ? "s" : "") ago.")
                .font(.body)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)
            Spacer()
            Button("Start") {
                let isProUser = users.first?.isProUser ?? false
                viewModel.startGame(n: 1, isProUser: isProUser)
            }
            .accentButton()
            .padding(.horizontal)
            .padding(.bottom, 32)
        }
    }

    private var gameView: some View {
        VStack(spacing: 24) {
            ProgressView(value: viewModel.trialProgress)
                .tint(.accent)
                .padding(.horizontal)

            if viewModel.isProUser {
                Text(viewModel.activeLetter)
                    .font(.title.bold())
                    .foregroundStyle(.accent)
            }

            Spacer()

            // 3x3 Grid
            Grid(horizontalSpacing: 8, verticalSpacing: 8) {
                ForEach(0..<gridSize, id: \.self) { row in
                    GridRow {
                        ForEach(0..<gridSize, id: \.self) { col in
                            let index = row * gridSize + col
                            RoundedRectangle(cornerRadius: 12)
                                .fill(viewModel.activePosition == index ? Color.accent : Color(UIColor.tertiarySystemGroupedBackground))
                                .frame(width: cellSize, height: cellSize)
                                .animation(.easeInOut(duration: 0.15), value: viewModel.activePosition)
                        }
                    }
                }
            }

            Spacer()

            // Match buttons
            HStack(spacing: 16) {
                Button {
                    viewModel.tapPositionMatch()
                } label: {
                    VStack(spacing: 4) {
                        Image(systemName: "square.on.square")
                            .font(.title2)
                        Text("Position")
                            .font(.caption.weight(.semibold))
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 20)
                    .background(
                        viewModel.positionMatchTapped ? Color.accent : Color(UIColor.secondarySystemGroupedBackground),
                        in: RoundedRectangle(cornerRadius: 14)
                    )
                    .foregroundStyle(viewModel.positionMatchTapped ? .white : .primary)
                }

                if viewModel.isProUser {
                    Button {
                        viewModel.tapSoundMatch()
                    } label: {
                        VStack(spacing: 4) {
                            Image(systemName: "speaker.wave.2")
                                .font(.title2)
                            Text("Sound")
                                .font(.caption.weight(.semibold))
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 20)
                        .background(
                            viewModel.soundMatchTapped ? Color.accent : Color(UIColor.secondarySystemGroupedBackground),
                            in: RoundedRectangle(cornerRadius: 14)
                        )
                        .foregroundStyle(viewModel.soundMatchTapped ? .white : .primary)
                    }
                }
            }
            .padding(.horizontal)
            .padding(.bottom, 32)
        }
    }

    private var resultsView: some View {
        VStack(spacing: 24) {
            Spacer()
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 64))
                .foregroundStyle(.accent)
            Text("Round Complete!")
                .font(.title.bold())

            VStack(spacing: 12) {
                resultRow("Position Accuracy", value: viewModel.positionScore)
                if viewModel.isProUser {
                    resultRow("Sound Accuracy", value: viewModel.soundScore)
                }
                Divider()
                resultRow("Overall", value: viewModel.overallScore)
            }
            .appCard()
            .padding(.horizontal)

            Text("Next level: \(viewModel.currentN)-Back")
                .font(.subheadline)
                .foregroundStyle(.secondary)

            Spacer()
            Button("Done") {
                let exercise = Exercise(
                    type: .dualNBack,
                    difficulty: viewModel.currentN,
                    score: viewModel.overallScore,
                    durationSeconds: viewModel.durationSeconds
                )
                onComplete(exercise)
                dismiss()
            }
            .accentButton()
            .padding(.horizontal)
            .padding(.bottom, 32)
        }
    }

    private func resultRow(_ label: String, value: Double) -> some View {
        HStack {
            Text(label)
                .font(.subheadline)
            Spacer()
            Text("\(Int(value * 100))%")
                .font(.subheadline.bold())
                .foregroundStyle(value >= 0.8 ? .accent : value >= 0.5 ? .warning : .error)
        }
    }
}
```

**Step 3: Build and verify, then commit**

```bash
xcodebuild -project MindRestore.xcodeproj -scheme MindRestore -destination 'platform=iOS Simulator,name=iPhone 16' build
git add MindRestore/ViewModels/DualNBackViewModel.swift MindRestore/Views/Exercises/DualNBackView.swift
git commit -m "feat: add dual n-back exercise with adaptive difficulty"
```

---

## Task 6: Active Recall Exercise

**Files:**
- Create: `MindRestore/Content/ActiveRecallContent.swift`
- Create: `MindRestore/ViewModels/ActiveRecallViewModel.swift`
- Create: `MindRestore/Views/Exercises/ActiveRecallView.swift`

**Step 1: Create ActiveRecallContent.swift**

Define 40 challenges (10 per type) as static data. Each challenge has: type, content to display, display duration, and an array of (question, answer) tuples.

```swift
import Foundation

struct ActiveRecallChallenge: Identifiable {
    let id = UUID()
    let type: ChallengeType
    let content: String
    let displayDuration: TimeInterval
    let questions: [(question: String, answer: String)]
}

enum ActiveRecallContent {
    static let allChallenges: [ActiveRecallChallenge] = storyRecall + instructionRecall + patternRecognition + conversationRecall

    // 10 story recall challenges
    static let storyRecall: [ActiveRecallChallenge] = [
        ActiveRecallChallenge(
            type: .storyRecall,
            content: "Maria drove her blue Toyota to the grocery store on Pine Street at 3:15 PM. She bought six apples, a loaf of sourdough bread, and two cartons of oat milk. On her way home, she stopped at the dry cleaner to pick up her husband's gray suit.",
            displayDuration: 30,
            questions: [
                ("What color was Maria's car?", "Blue"),
                ("What street was the grocery store on?", "Pine Street"),
                ("What time did she go?", "3:15 PM"),
                ("What type of bread did she buy?", "Sourdough"),
                ("What did she pick up from the dry cleaner?", "Her husband's gray suit"),
            ]
        ),
        // ... (9 more story challenges - abbreviated for plan, full content in implementation)
    ]

    // 10 instruction recall, 10 pattern recognition, 10 conversation recall
    // Full content written during implementation
    static let instructionRecall: [ActiveRecallChallenge] = []
    static let patternRecognition: [ActiveRecallChallenge] = []
    static let conversationRecall: [ActiveRecallChallenge] = []
}
```

Note: During implementation, write all 40 challenges with full content. The plan shows the structure; the executing agent will generate all content.

**Step 2: Create ActiveRecallViewModel.swift**

```swift
import SwiftUI

@Observable
final class ActiveRecallViewModel {
    var currentChallenge: ActiveRecallChallenge?
    var phase: ChallengePhase = .displaying
    var currentQuestionIndex = 0
    var answers: [String] = []
    var score: Double = 0.0
    var startTime = Date()
    var displayTimeRemaining: Int = 0
    var challengeComplete = false

    private var displayTimer: Timer?
    private var usedChallengeIDs: Set<UUID> = []

    enum ChallengePhase {
        case displaying
        case answering
        case results
    }

    func loadChallenge(type: ChallengeType? = nil) {
        let available = ActiveRecallContent.allChallenges
            .filter { type == nil || $0.type == type }
            .filter { !usedChallengeIDs.contains($0.id) }

        guard let challenge = available.randomElement() else { return }

        currentChallenge = challenge
        usedChallengeIDs.insert(challenge.id)
        phase = .displaying
        currentQuestionIndex = 0
        answers = Array(repeating: "", count: challenge.questions.count)
        displayTimeRemaining = Int(challenge.displayDuration)
        challengeComplete = false
        startTime = Date()

        startDisplayTimer()
    }

    private func startDisplayTimer() {
        displayTimer?.invalidate()
        displayTimer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { [weak self] _ in
            Task { @MainActor in
                guard let self else { return }
                self.displayTimeRemaining -= 1
                if self.displayTimeRemaining <= 0 {
                    self.displayTimer?.invalidate()
                    withAnimation(.easeInOut(duration: 0.2)) {
                        self.phase = .answering
                    }
                }
            }
        }
    }

    func submitAnswer(_ answer: String) {
        guard let challenge = currentChallenge else { return }
        answers[currentQuestionIndex] = answer

        if currentQuestionIndex < challenge.questions.count - 1 {
            currentQuestionIndex += 1
        } else {
            calculateScore()
            phase = .results
            challengeComplete = true
        }
    }

    func skipDisplay() {
        displayTimer?.invalidate()
        withAnimation(.easeInOut(duration: 0.2)) {
            phase = .answering
        }
    }

    private func calculateScore() {
        guard let challenge = currentChallenge else { return }
        var correct = 0
        for (index, qa) in challenge.questions.enumerated() {
            let userAnswer = answers[index].lowercased().trimmingCharacters(in: .whitespacesAndNewlines)
            let correctAnswer = qa.answer.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)
            // Simple contains check for flexibility
            if userAnswer.contains(correctAnswer) || correctAnswer.contains(userAnswer) {
                correct += 1
            }
        }
        score = Double(correct) / Double(challenge.questions.count)
    }

    var durationSeconds: Int {
        Int(Date().timeIntervalSince(startTime))
    }

    func stop() {
        displayTimer?.invalidate()
    }
}
```

**Step 3: Create ActiveRecallView.swift**

```swift
import SwiftUI
import SwiftData

struct ActiveRecallView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var viewModel = ActiveRecallViewModel()
    @State private var answerText = ""
    let onComplete: (Exercise) -> Void

    var body: some View {
        VStack(spacing: 0) {
            header
            switch viewModel.phase {
            case .displaying: displayPhase
            case .answering: answerPhase
            case .results: resultsPhase
            }
        }
        .background(Color(UIColor.systemGroupedBackground))
        .onAppear { viewModel.loadChallenge() }
        .onDisappear { viewModel.stop() }
    }

    private var header: some View {
        HStack {
            Button { viewModel.stop(); dismiss() } label: {
                Image(systemName: "xmark")
                    .font(.title3)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            Text("Active Recall")
                .font(.headline)
            Spacer()
            Text(viewModel.currentChallenge?.type.displayName ?? "")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding()
    }

    private var displayPhase: some View {
        VStack(spacing: 24) {
            Text("\(viewModel.displayTimeRemaining)s")
                .font(.system(size: 48, weight: .bold, design: .rounded))
                .foregroundStyle(.accent)
                .contentTransition(.numericText())
                .animation(.linear(duration: 0.2), value: viewModel.displayTimeRemaining)

            ScrollView {
                Text(viewModel.currentChallenge?.content ?? "")
                    .font(.body)
                    .padding()
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            .appCard()
            .padding(.horizontal)

            Spacer()

            Button("I'm ready") {
                viewModel.skipDisplay()
            }
            .accentButton()
            .padding(.horizontal)
            .padding(.bottom, 32)
        }
    }

    private var answerPhase: some View {
        VStack(spacing: 24) {
            Spacer()
            if let challenge = viewModel.currentChallenge {
                Text("Question \(viewModel.currentQuestionIndex + 1) of \(challenge.questions.count)")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)

                Text(challenge.questions[viewModel.currentQuestionIndex].question)
                    .font(.title3)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal)

                TextField("Your answer", text: $answerText)
                    .textFieldStyle(.roundedBorder)
                    .padding(.horizontal, 24)

                Spacer()

                Button("Submit") {
                    viewModel.submitAnswer(answerText)
                    answerText = ""
                    UIImpactFeedbackGenerator(style: .light).impactOccurred()
                }
                .accentButton()
                .disabled(answerText.isEmpty)
                .opacity(answerText.isEmpty ? 0.5 : 1)
                .padding(.horizontal)
                .padding(.bottom, 32)
            }
        }
    }

    private var resultsPhase: some View {
        VStack(spacing: 24) {
            Spacer()
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 64))
                .foregroundStyle(.accent)
            Text("Challenge Complete!")
                .font(.title.bold())
            Text("\(Int(viewModel.score * 100))% accuracy")
                .font(.title3)
                .foregroundStyle(.secondary)

            // Show correct answers
            if let challenge = viewModel.currentChallenge {
                VStack(alignment: .leading, spacing: 12) {
                    ForEach(Array(challenge.questions.enumerated()), id: \.offset) { index, qa in
                        VStack(alignment: .leading, spacing: 4) {
                            Text(qa.question)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                            HStack {
                                Text("Your answer: \(viewModel.answers[index])")
                                    .font(.subheadline)
                                Spacer()
                                Text(qa.answer)
                                    .font(.subheadline.bold())
                                    .foregroundStyle(.accent)
                            }
                        }
                        if index < challenge.questions.count - 1 { Divider() }
                    }
                }
                .appCard()
                .padding(.horizontal)
            }

            Spacer()
            Button("Done") {
                let exercise = Exercise(
                    type: .activeRecall,
                    difficulty: 1,
                    score: viewModel.score,
                    durationSeconds: viewModel.durationSeconds
                )
                onComplete(exercise)
                dismiss()
            }
            .accentButton()
            .padding(.horizontal)
            .padding(.bottom, 32)
        }
    }
}
```

**Step 4: Build, verify, commit**

```bash
xcodebuild build
git add MindRestore/Content/ActiveRecallContent.swift MindRestore/ViewModels/ActiveRecallViewModel.swift MindRestore/Views/Exercises/ActiveRecallView.swift
git commit -m "feat: add active recall exercise with story and instruction challenges"
```

---

## Task 7: Daily Session + Training Flow

**Files:**
- Create: `MindRestore/Views/Exercises/TrainingFlowView.swift`
- Modify: `MindRestore/Views/Home/HomeView.swift` (wire fullScreenCover)
- Modify: `MindRestore/ViewModels/HomeViewModel.swift` (add session creation)

**Step 1: Create TrainingFlowView.swift**

Orchestrates sequential exercises. Presents each exercise type as a full-screen child view. After each exercise completes, adds Exercise to DailySession, checks if session is done.

```swift
import SwiftUI
import SwiftData

struct TrainingFlowView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @Query private var users: [User]
    @Query(sort: \DailySession.date, order: .reverse) private var sessions: [DailySession]

    @State private var currentExerciseIndex = 0
    @State private var exerciseTypes: [ExerciseType] = [.spacedRepetition, .dualNBack, .activeRecall]
    @State private var completedExercises: [Exercise] = []
    @State private var sessionComplete = false
    @State private var todaySession: DailySession?

    private var dailyGoal: Int { users.first?.dailyGoal ?? AppConstants.defaultDailyGoal }

    var body: some View {
        if sessionComplete {
            sessionSummary
        } else if currentExerciseIndex < min(dailyGoal, exerciseTypes.count) {
            currentExerciseView
        } else {
            sessionSummary
        }
    }

    @ViewBuilder
    private var currentExerciseView: some View {
        let type = exerciseTypes[currentExerciseIndex % exerciseTypes.count]
        switch type {
        case .spacedRepetition:
            SpacedRepetitionView { exercise in
                completeExercise(exercise)
            }
        case .dualNBack:
            DualNBackView { exercise in
                completeExercise(exercise)
            }
        case .activeRecall:
            ActiveRecallView { exercise in
                completeExercise(exercise)
            }
        }
    }

    private var sessionSummary: some View {
        VStack(spacing: 24) {
            Spacer()
            Image(systemName: "star.fill")
                .font(.system(size: 64))
                .foregroundStyle(.accent)
            Text("Training Complete!")
                .font(.title.bold())

            let avgScore = completedExercises.isEmpty ? 0.0 :
                completedExercises.reduce(0) { $0 + $1.score } / Double(completedExercises.count)
            Text("\(Int(avgScore * 100))% average score")
                .font(.title3)
                .foregroundStyle(.secondary)

            VStack(spacing: 12) {
                ForEach(completedExercises, id: \.id) { ex in
                    HStack {
                        Image(systemName: ex.type.icon)
                            .foregroundStyle(.accent)
                        Text(ex.type.displayName)
                            .font(.subheadline)
                        Spacer()
                        Text("\(Int(ex.score * 100))%")
                            .font(.subheadline.bold())
                    }
                }
            }
            .appCard()
            .padding(.horizontal)

            Spacer()
            Button("Done") { dismiss() }
                .accentButton()
                .padding(.horizontal)
                .padding(.bottom, 32)
        }
        .background(Color(UIColor.systemGroupedBackground))
    }

    private func completeExercise(_ exercise: Exercise) {
        modelContext.insert(exercise)
        completedExercises.append(exercise)

        // Get or create today's session
        let today = Calendar.current.startOfDay(for: .now)
        if todaySession == nil {
            todaySession = sessions.first { Calendar.current.isDate($0.date, inSameDayAs: today) }
            if todaySession == nil {
                let session = DailySession(date: today)
                modelContext.insert(session)
                todaySession = session
            }
        }

        todaySession?.exercises.append(exercise)
        todaySession?.recalculateScore()
        todaySession?.recalculateDuration()

        // Update streak
        if let user = users.first {
            user.updateStreak()
        }

        try? modelContext.save()

        // Move to next exercise or complete
        currentExerciseIndex += 1
        if currentExerciseIndex >= dailyGoal {
            sessionComplete = true
        }
    }
}
```

**Step 2: Wire into HomeView**

Replace the fullScreenCover placeholder in HomeView with `TrainingFlowView()`.

**Step 3: Build, verify, commit**

```bash
xcodebuild build
git add MindRestore/Views/Exercises/TrainingFlowView.swift
git commit -m "feat: add training flow with sequential exercises and session tracking"
```

---

## Task 8: Psychoeducation Feed

**Files:**
- Create: `MindRestore/Content/EducationContent.swift`
- Create: `MindRestore/Views/Education/EducationFeedView.swift`
- Create: `MindRestore/Views/Education/EducationDetailView.swift`
- Modify: `MindRestore/Views/Home/HomeView.swift` (wire learn section)

**Step 1: Create EducationContent.swift**

15 hardcoded articles as specified in PRD. Each has title, body (150-250 words), and category.

```swift
import Foundation

enum EducationContent {
    static let allCards: [PsychoEducationCard] = [
        PsychoEducationCard(
            title: "Your Brain Thinks Your Phone Is Its Memory",
            body: "Your brain has evolved to be efficient...", // Full 150-250 word article
            category: .socialMedia,
            sortOrder: 1
        ),
        // ... all 15 cards with full content written during implementation
    ]
}
```

Note: The implementing agent writes all 15 full articles based on the PRD's topic list.

**Step 2: Create EducationFeedView + EducationDetailView**

Horizontal scrollable card list on home. Tapping opens sheet with full article. Read status tracked via `@AppStorage`.

**Step 3: Wire into HomeView learnSection, build, commit**

```bash
git commit -m "feat: add psychoeducation feed with 15 science-based articles"
```

---

## Task 9: Progress / Analytics

**Files:**
- Create: `MindRestore/Views/Components/HeatmapCalendar.swift`
- Create: `MindRestore/Views/Components/ScoreChart.swift`
- Create: `MindRestore/ViewModels/ProgressViewModel.swift`
- Create: `MindRestore/Views/Progress/MindRestoreProgressView.swift`
- Modify: `MindRestore/Views/ContentView.swift` (wire Progress tab)

**Step 1: Create HeatmapCalendar.swift**

GitHub contribution graph style. Grid of colored squares. Green intensity based on session score for each day. Uses SwiftUI Grid with 7 columns (weekdays).

**Step 2: Create ScoreChart.swift (Pro)**

Line chart using Swift Charts showing score trends per exercise type over time.

**Step 3: Create ProgressViewModel + ProgressView**

Free tier: heatmap + streak + total sessions.
Pro tier: score trend charts + retention rate + n-back progression + memory score.

Pro features shown with blur + lock overlay for free users, tapping shows paywall.

**Step 4: Build, commit**

```bash
git commit -m "feat: add progress view with heatmap calendar and analytics"
```

---

## Task 10: StoreKit 2 Paywall

**Files:**
- Create: `MindRestore/Services/StoreService.swift`
- Create: `MindRestore/ViewModels/StoreViewModel.swift`
- Create: `MindRestore/Views/Paywall/PaywallView.swift`

**Step 1: Create StoreService.swift**

Wrapper around StoreKit 2 APIs. Matches StretchCheck's SubscriptionManager pattern:
- `loadProducts()` using `Product.products(for:)`
- `purchase(_ product:)` with verification
- `restorePurchases()` using `AppStore.sync()`
- `updateSubscriptionStatus()` checking `Transaction.currentEntitlements`
- `listenForTransactions()` via `Transaction.updates`
- 3 products: monthly, annual, lifetime

**Step 2: Create StoreViewModel.swift**

`@Observable` class wrapping StoreService. Published state: isProUser, products, purchaseError, isLoading.

**Step 3: Create PaywallView.swift**

Layout matches StretchCheck's paywall:
- Star icon + "Unlock Your Full Potential" heading
- Feature comparison rows (checkmarks)
- Plan selection cards (annual highlighted as best value)
- "Start 7-Day Free Trial" CTA
- Restore purchases link
- Fine print

**Step 4: Wire paywall triggers**

- After first session completion
- On locked exercise categories
- On locked analytics
- StoreViewModel injected via environment

**Step 5: Build, commit**

```bash
git commit -m "feat: add StoreKit 2 paywall with monthly, annual, and lifetime options"
```

---

## Task 11: Local Notifications

**Files:**
- Create: `MindRestore/Services/NotificationService.swift`
- Modify: `MindRestore/Views/Exercises/TrainingFlowView.swift` (request permission after first session)

**Step 1: Create NotificationService.swift**

Using UNUserNotificationCenter:
- `requestPermission()` — called after first completed session
- `scheduleDailyReminder(at hour: Int, minute: Int, streak: Int)` — daily notification
- `scheduleStreakRisk(streak: Int)` — 8 PM if no session today
- `scheduleMilestone(streak: Int)` — on reaching 7, 30, 100
- `cancelAll()` and `reschedule()` helpers

**Step 2: Build, commit**

```bash
git commit -m "feat: add local notification service for reminders and streaks"
```

---

## Task 12: Settings

**Files:**
- Create: `MindRestore/Views/Settings/SettingsView.swift`
- Modify: `MindRestore/Views/ContentView.swift` (wire Settings tab)

**Step 1: Create SettingsView.swift**

List-based grouped form matching StretchCheck's pattern:
- Notifications section: toggle + DatePicker for time
- Appearance section: theme picker (light/dark/system) with icons
- Training section: stepper for daily goal (1-10)
- Sound section: toggle
- Subscription section: status display + manage/restore
- Privacy section: info card
- About section: version, citations, credits
- Reset section: destructive button with confirmation alert

**Step 2: Build, commit**

```bash
git commit -m "feat: add settings view with notifications, appearance, and subscription management"
```

---

## Task 13: Polish + Final Wiring

**Step 1: Wire all tabs in ContentView**

Ensure Home, Train (or merge into Home), Progress, Settings all display correct views.

**Step 2: Add haptic feedback**

UIImpactFeedbackGenerator on correct/incorrect answers, button taps, streak milestones.

**Step 3: Add accessibility labels**

VoiceOver labels on all interactive elements, SF Symbols, and charts.

**Step 4: Verify dark/light mode**

Test both color schemes with semantic colors.

**Step 5: Final build verification**

```bash
xcodebuild -project MindRestore.xcodeproj -scheme MindRestore -destination 'platform=iOS Simulator,name=iPhone 16' build
```

**Step 6: Commit**

```bash
git add .
git commit -m "polish: add haptics, accessibility, and final wiring"
```

---

## Execution Notes

- **Content generation**: Tasks 4, 6, and 8 require writing substantial hardcoded content (100 cards, 40 challenges, 15 articles). The implementing agent should write full, realistic content — not placeholder text.
- **Build after every task**: Verify the project compiles after each task before committing.
- **StretchCheck reference**: When unsure about spacing, animations, or component patterns, read the equivalent file from `/Users/dylanmiller/Desktop/StretchCheck/`.
- **No external deps**: Use only Apple frameworks. No SPM packages.
- **iOS 17+**: Use `@Observable` (not `ObservableObject`), `Tab` enum for TabView (iOS 18 syntax — verify compatibility, fall back to `.tabItem` if needed for iOS 17).
