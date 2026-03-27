import SwiftUI
import SwiftData
import UIKit

struct OnboardingView: View {
    @Environment(\.modelContext) private var modelContext
    @Query private var users: [User]
    @State private var currentPage = 0
    @State private var selectedGoals: Set<UserFocusGoal> = []
    @State private var assessmentResult: BrainScoreResult?
    @State private var assessmentBgColor: Color = AppColors.pageBg
    @State private var notificationsEnabled = false
    @State private var enteredName: String = ""
    @State private var selectedAge: Int = 25
    @State private var selectedAppearance: Int = 0 // 0=system, 1=light, 2=dark
    @FocusState private var nameFieldFocused: Bool

    var onComplete: () -> Void

    private let totalPages = 8

    var body: some View {
        ZStack {
            (currentPage == 5 ? assessmentBgColor : AppColors.pageBg).ignoresSafeArea()

            VStack(spacing: 0) {
                TabView(selection: $currentPage) {
                    welcomePage.tag(0)
                    namePage.tag(1)
                    goalsPage.tag(2)
                    agePage.tag(3)
                    appearancePage.tag(4)
                    assessmentPage.tag(5)
                    notificationsPage.tag(6)
                    privacyPage.tag(7)
                }
                .tabViewStyle(.page(indexDisplayMode: .never))
                .scrollDisabled(true)
                .animation(.easeInOut, value: currentPage)
                .onChange(of: currentPage) { _, newPage in
                    if newPage == 1 {
                        nameFieldFocused = true
                    } else {
                        nameFieldFocused = false
                    }
                }

                if currentPage != 5 {
                    HStack(spacing: 8) {
                        ForEach(0..<totalPages, id: \.self) { index in
                            Capsule()
                                .fill(
                                    index == currentPage
                                        ? AnyShapeStyle(AppColors.accentGradient)
                                        : AnyShapeStyle(Color.gray.opacity(0.25))
                                )
                                .frame(width: index == currentPage ? 24 : 8, height: 8)

                                .animation(.spring(response: 0.3), value: currentPage)
                        }
                    }
                    .padding(.bottom, 16)
                }
            }
        }
    }

    private var welcomePage: some View {
        VStack(spacing: 40) {
            Spacer()

            VStack(spacing: 16) {
                Image("mascot-wave")
                    .renderingMode(.original)
                    .resizable()
                    .scaledToFit()
                    .frame(height: 160)

                Text("Memori")
                    .font(.largeTitle.bold())

                Text("Train your brain.\nSharpen your mind.")
                    .font(.title3)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }

            VStack(alignment: .leading, spacing: 16) {
                FeatureRow(icon: CognitiveDomain.memory.icon, color: CognitiveDomain.memory.color, title: "Memory Training", subtitle: "Visual, sequential & chunking games")
                FeatureRow(icon: CognitiveDomain.attention.icon, color: CognitiveDomain.attention.color, title: "Dual N-Back", subtitle: "Working memory & attention")
                FeatureRow(icon: CognitiveDomain.speed.icon, color: CognitiveDomain.speed.color, title: "Processing Speed", subtitle: "Reaction time challenges")
                FeatureRow(icon: "chart.line.uptrend.xyaxis", color: AppColors.amber, title: "Brain Score", subtitle: "Track your cognitive improvement")
            }
            .padding(.horizontal, 40)

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

    // MARK: - Name Entry Page

    private var namePage: some View {
        ScrollView {
            VStack(spacing: 32) {
                Spacer(minLength: 60)

                // Animated greeting emoji
                Text("👋")
                    .font(.system(size: 64))

                VStack(spacing: 10) {
                    Text("What should we\ncall you?")
                        .font(.system(size: 28, weight: .bold, design: .rounded))
                        .multilineTextAlignment(.center)
                    Text("Used for greetings and leaderboards")
                        .font(.subheadline)
                        .foregroundStyle(AppColors.textTertiary)
                        .multilineTextAlignment(.center)
                }

                TextField("Your name", text: $enteredName)
                    .font(.system(size: 20, weight: .semibold, design: .rounded))
                    .multilineTextAlignment(.center)
                    .padding(.vertical, 16)
                    .padding(.horizontal, 24)
                    .background(
                        RoundedRectangle(cornerRadius: 16)
                            .fill(AppColors.cardSurface)
                            .shadow(color: AppColors.accent.opacity(nameFieldFocused ? 0.15 : 0), radius: 12, y: 4)
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 16)
                            .stroke(
                                nameFieldFocused ? AppColors.accent.opacity(0.5) : AppColors.cardBorder,
                                lineWidth: nameFieldFocused ? 1.5 : 1
                            )
                    )
                    .padding(.horizontal, 32)
                    .focused($nameFieldFocused)
                    .submitLabel(.continue)
                    .onSubmit { dismissAndAdvance() }
                    .animation(.easeInOut(duration: 0.2), value: nameFieldFocused)
                    .toolbar {
                        ToolbarItemGroup(placement: .keyboard) {
                            Button("Skip") {
                                enteredName = ""
                                dismissAndAdvance()
                            }
                            .font(.subheadline.weight(.medium))
                            .foregroundStyle(.secondary)

                            Spacer()

                            Button {
                                dismissAndAdvance()
                            } label: {
                                Text("Continue")
                                    .font(.subheadline.weight(.bold))
                                    .foregroundStyle(AppColors.accent)
                            }
                        }
                    }

                if !nameFieldFocused {
                    VStack(spacing: 12) {
                        continueButton { dismissAndAdvance() }

                        Button {
                            enteredName = ""
                            dismissAndAdvance()
                        } label: {
                            Text("Skip")
                                .font(.subheadline.weight(.medium))
                                .foregroundStyle(.secondary)
                                .padding(.vertical, 8)
                        }
                    }
                    .padding(.top, 4)
                }
            }
            .padding(.bottom, 16)
            .responsiveContent(maxWidth: 500)
            .frame(maxWidth: .infinity)
        }
        .scrollDismissesKeyboard(.interactively)
        .onAppear {
                if currentPage == 1 { nameFieldFocused = true }
            }
    }

    private func dismissAndAdvance() {
        nameFieldFocused = false
        Analytics.onboardingStep(step: "name")
        withAnimation { currentPage = 2 }
    }

    private var goalsPage: some View {
        VStack(spacing: 32) {
            Spacer()

            Image("mascot-goal")
                .renderingMode(.original)
                .resizable()
                .scaledToFit()
                .frame(height: 150)

            VStack(spacing: 8) {
                Text("Pick your focus")
                    .font(.title.bold())
                Text("Select 1-3 goals")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }

            VStack(spacing: 12) {
                ForEach(UserFocusGoal.allCases) { goal in
                    GoalCard(goal: goal, isSelected: selectedGoals.contains(goal)) {
                        withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                            if selectedGoals.contains(goal) {
                                selectedGoals.remove(goal)
                            } else if selectedGoals.count < 3 {
                                selectedGoals.insert(goal)
                            }
                        }
                    }
                }
            }
            .padding(.horizontal, 24)

            Spacer()

            continueButton {
                Analytics.onboardingStep(step: "goals")
                currentPage = 3
            }
                .disabled(selectedGoals.isEmpty)
                .opacity(selectedGoals.isEmpty ? 0.4 : 1)
        }
        .padding(.bottom, 8)
        .responsiveContent(maxWidth: 500)
        .frame(maxWidth: .infinity)
        .onAppear { nameFieldFocused = false }
    }

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
                continueButton {
                    Analytics.onboardingStep(step: "age")
                    currentPage = 4
                }

                Button {
                    selectedAge = 0
                    Analytics.onboardingStep(step: "age")
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

    // MARK: - Brain Assessment Page

    private var assessmentPage: some View {
        OnboardingAssessmentView(backgroundColor: $assessmentBgColor) { result in
            assessmentResult = result
            Analytics.onboardingStep(step: "assessment")
            // Save brain score immediately so it's not lost
            if let result {
                modelContext.insert(result)
                try? modelContext.save()
            }
            withAnimation {
                currentPage = 6
            }
        }
    }

    // Note: OnboardingAssessmentView's onComplete now passes nil when skipped

    // MARK: - Notifications Page

    private var notificationsPage: some View {
        VStack(spacing: 32) {
            Spacer()

            ZStack {
                Circle()
                    .fill(AppColors.cardBorder)
                    .frame(width: 140, height: 140)
                Image(systemName: "bell.badge.fill")
                    .font(.system(size: 64))
                    .foregroundStyle(AppColors.accent)
            }

            VStack(spacing: 8) {
                Text("Stay on track")
                    .font(.title.bold())
                    .multilineTextAlignment(.center)
                Text("Get gentle reminders to train daily\nand keep your streak alive.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }

            Spacer()

            VStack(spacing: 12) {
                Button {
                    Task {
                        let granted = await NotificationService.shared.requestPermission()
                        notificationsEnabled = granted
                        Analytics.onboardingStep(step: "notifications")
                        withAnimation { currentPage = 7 }
                    }
                } label: {
                    Text("Enable Notifications")
                        .gradientButton()
                }

                Button {
                    Analytics.onboardingStep(step: "notifications")
                    withAnimation { currentPage = 7 }
                } label: {
                    Text("Maybe Later")
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
    }

    // MARK: - Appearance Page

    private var appearancePage: some View {
        VStack(spacing: 28) {
            Spacer()

            ZStack {
                Circle()
                    .fill(AppColors.cardBorder)
                    .frame(width: 140, height: 140)
                Image(systemName: selectedAppearance == 2 ? "moon.fill" : selectedAppearance == 1 ? "sun.max.fill" : "circle.lefthalf.filled")
                    .font(.system(size: 64))
                    .foregroundStyle(AppColors.accent)
                    .contentTransition(.symbolEffect(.replace))
            }

            VStack(spacing: 8) {
                Text("Choose your look")
                    .font(.title.bold())
                    .multilineTextAlignment(.center)
                Text("You can change this anytime in Settings.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }

            HStack(spacing: 12) {
                appearanceOption(value: 0, label: "System", icon: "iphone", description: "Match device")
                appearanceOption(value: 1, label: "Light", icon: "sun.max.fill", description: "Always light")
                appearanceOption(value: 2, label: "Dark", icon: "moon.fill", description: "Always dark")
            }
            .padding(.horizontal, 24)

            Spacer()

            Button {
                Analytics.onboardingStep(step: "appearance")
                withAnimation { currentPage = 5 }
            } label: {
                Text("Continue")
                    .gradientButton()
            }
            .padding(.horizontal, 32)
        }
        .padding(.bottom, 8)
        .responsiveContent(maxWidth: 500)
        .frame(maxWidth: .infinity)
    }

    private func appearanceOption(value: Int, label: String, icon: String, description: String) -> some View {
        Button {
            withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                selectedAppearance = value
                applyAppearance(value)
            }
        } label: {
            VStack(spacing: 8) {
                Image(systemName: icon)
                    .font(.system(size: 24, weight: .medium))
                    .foregroundStyle(selectedAppearance == value ? .white : AppColors.accent)
                    .frame(width: 48, height: 48)
                    .background(
                        selectedAppearance == value
                            ? AnyShapeStyle(AppColors.accentGradient)
                            : AnyShapeStyle(AppColors.accent.opacity(0.1))
                        , in: Circle()
                    )

                Text(label)
                    .font(.subheadline.weight(.bold))
                    .foregroundStyle(selectedAppearance == value ? .primary : .secondary)

                Text(description)
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 16)
            .background(AppColors.cardSurface, in: RoundedRectangle(cornerRadius: 14))
            .overlay(
                RoundedRectangle(cornerRadius: 14)
                    .stroke(selectedAppearance == value ? AppColors.accent : AppColors.cardBorder, lineWidth: selectedAppearance == value ? 2 : 1)
            )
        }
        .buttonStyle(.plain)
    }

    private func applyAppearance(_ value: Int) {
        let theme: AppTheme = switch value {
        case 1: .light
        case 2: .dark
        default: .system
        }
        UserDefaults.standard.set(theme.rawValue, forKey: "appTheme")
    }

    // MARK: - Privacy Page

    private var privacyPage: some View {
        VStack(spacing: 32) {
            Spacer()

            ZStack {
                Circle()
                    .fill(AppColors.cardBorder)
                    .frame(width: 140, height: 140)
                Image(systemName: "lock.shield.fill")
                    .font(.system(size: 64))
                    .foregroundStyle(AppColors.accent)
            }

            VStack(spacing: 8) {
                Text("Your data stays on\nyour device. Always.")
                    .font(.title.bold())
                    .multilineTextAlignment(.center)
                Text("No accounts. Privacy-first.\nYour training data stays on your device.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }

            Spacer()

            Button {
                Analytics.onboardingStep(step: "privacy")
                completeOnboarding()
            } label: {
                Text("Get Started")
                    .gradientButton()
            }
            .padding(.horizontal, 32)
        }
        .padding(.bottom, 8)
        .responsiveContent(maxWidth: 500)
        .frame(maxWidth: .infinity)
    }

    private func continueButton(action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text("Continue")
                .gradientButton()
        }
        .accessibilityHint("Continues to the next step")
        .padding(.horizontal, 32)
    }

    private func completeOnboarding() {
        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
        let user: User
        if let existing = users.first {
            user = existing
        } else {
            user = User()
            modelContext.insert(user)
        }

        user.hasCompletedOnboarding = true
        user.username = enteredName.trimmingCharacters(in: .whitespacesAndNewlines)
        user.focusGoals = Array(selectedGoals)
        user.notificationsEnabled = notificationsEnabled
        user.userAge = selectedAge

        // Save brain score result — assessment does NOT count toward daily session/limit
        if assessmentResult != nil {
            user.totalXP += 50  // Bonus XP for completing onboarding assessment
        }

        Analytics.onboardingCompleted(goals: Array(selectedGoals).map(\.rawValue))

        try? modelContext.save()
        onComplete()
    }
}

// MARK: - Feature Row

struct FeatureRow: View {
    let icon: String
    let color: Color
    let title: String
    let subtitle: String

    var body: some View {
        HStack(spacing: 14) {
            ColoredIconBadge(icon: icon, color: color, size: 36)

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.subheadline.weight(.semibold))
                Text(subtitle)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()
        }
    }
}

// MARK: - Goal Card

struct GoalCard: View {
    let goal: UserFocusGoal
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 16) {
                Image(systemName: goal.icon)
                    .font(.title3)
                    .foregroundStyle(isSelected ? .white : .secondary)
                    .frame(width: 40, height: 40)
                    .background(
                        RoundedRectangle(cornerRadius: 12)
                            .fill(isSelected ? AppColors.accentGradient : LinearGradient(colors: [AppColors.cardBorder.opacity(0.4)], startPoint: .top, endPoint: .bottom))
                    )

                Text(goal.displayName)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.primary)
                    .multilineTextAlignment(.leading)

                Spacer()

                if isSelected {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.title3)
                        .foregroundStyle(AppColors.accent)
                }
            }
            .padding(.vertical, 12)
            .padding(.horizontal, 14)
            .background(
                ZStack {
                    RoundedRectangle(cornerRadius: 12)
                        .fill(AppColors.cardSurface)
                    if isSelected {
                        RoundedRectangle(cornerRadius: 12)
                            .fill(AppColors.accent.opacity(0.06))
                    }
                }
            )
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(
                        isSelected ? AppColors.accent.opacity(0.5) : Color.clear,
                        lineWidth: 1.5
                    )
            )
        }
        .buttonStyle(.plain)
        .accessibilityLabel("\(goal.displayName)\(isSelected ? ", selected" : "")")
    }
}
