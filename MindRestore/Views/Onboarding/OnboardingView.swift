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
    @State private var holdProgress: CGFloat = 0
    @State private var holdTimer: Timer?
    @State private var commitmentCompleted = false
    @FocusState private var nameFieldFocused: Bool

    var onComplete: () -> Void

    private let totalPages = 11

    var body: some View {
        ZStack {
            (currentPage == 7 ? assessmentBgColor : AppColors.pageBg).ignoresSafeArea()

            VStack(spacing: 0) {
                TabView(selection: $currentPage) {
                    welcomePage.tag(0)
                    namePage.tag(1)
                    goalsPage.tag(2)
                    agePage.tag(3)
                    appearancePage.tag(4)
                    badNewsPage.tag(5)
                    goodNewsPage.tag(6)
                    assessmentPage.tag(7)
                    commitmentPage.tag(8)
                    notificationsPage.tag(9)
                    privacyPage.tag(10)
                }
                .tabViewStyle(.page(indexDisplayMode: .never))
                .scrollDisabled(true)
                .animation(.easeInOut, value: currentPage)
                .onChange(of: currentPage) { _, newPage in
                    // Animate keyboard dismiss smoothly
                    UIView.animate(withDuration: 0.3, delay: 0, options: .curveEaseOut) {
                        UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
                    }
                    nameFieldFocused = false
                    if newPage == 1 {
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) {
                            nameFieldFocused = true
                        }
                    }
                }

                if currentPage != 7 {
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
        VStack(spacing: 24) {
            Spacer().frame(height: 40)

            Image("mascot-wave")
                .renderingMode(.original)
                .resizable()
                .scaledToFit()
                .frame(height: 180)

            VStack(spacing: 10) {
                Text("Memori")
                    .font(.system(size: 36, weight: .bold, design: .rounded))

                Text("Brain games that actually\nmake you competitive.")
                    .font(.title3)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }

            VStack(alignment: .leading, spacing: 14) {
                FeatureRow(icon: "trophy.fill", color: AppColors.amber, title: "Compete Globally", subtitle: "Climb leaderboards & challenge friends")
                FeatureRow(icon: "brain.head.profile", color: CognitiveDomain.memory.color, title: "8 Brain Games", subtitle: "Memory, speed, focus & problem solving")
                FeatureRow(icon: "chart.line.uptrend.xyaxis", color: AppColors.accent, title: "Track Your Brain Score", subtitle: "See how you stack up against everyone")
            }
            .padding(.horizontal, 36)

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
        VStack(spacing: 16) {
            Spacer().frame(height: 20)

            Image("mascot-goal")
                .renderingMode(.original)
                .resizable()
                .scaledToFit()
                .frame(height: 130)

            VStack(spacing: 6) {
                Text("Pick your focus")
                    .font(.system(size: 28, weight: .bold, design: .rounded))
                Text("Select 1-3 goals")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }

            VStack(spacing: 10) {
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

    // MARK: - Bad News Page

    private var badNewsPage: some View {
        VStack(spacing: 24) {
            Spacer().frame(height: 60)

            Image("mascot-low-score")
                .renderingMode(.original)
                .resizable()
                .scaledToFit()
                .frame(height: 180)

            VStack(spacing: 8) {
                (Text("Doomscrolling is frying\nyour ")
                    .font(.system(size: 28, weight: .bold, design: .rounded))
                + Text("memory")
                    .font(.system(size: 28, weight: .bold, design: .rounded))
                    .foregroundColor(.red))
                    .multilineTextAlignment(.center)

                Text("Heavy phone users have the attention span\nof a goldfish. Literally.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }

            Spacer()

            continueButton {
                Analytics.onboardingStep(step: "badNews")
                currentPage = 6
            }
        }
        .padding(.bottom, 8)
        .responsiveContent(maxWidth: 500)
        .frame(maxWidth: .infinity)
    }

    // MARK: - Good News Page

    private var goodNewsPage: some View {
        VStack(spacing: 24) {
            Spacer().frame(height: 60)

            Image("mascot-working-out")
                .renderingMode(.original)
                .resizable()
                .scaledToFit()
                .frame(height: 180)

            VStack(spacing: 8) {
                (Text("But your brain can\n")
                    .font(.system(size: 28, weight: .bold, design: .rounded))
                + Text("bounce back")
                    .font(.system(size: 28, weight: .bold, design: .rounded))
                    .foregroundColor(AppColors.accent))
                    .multilineTextAlignment(.center)

                Text("Just 5 minutes a day of brain training\ncan improve memory, focus, and reaction time.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)

                Text("Let's see where you stand.")
                    .font(.caption)
                    .foregroundStyle(.tertiary)
                    .padding(.top, 4)
            }

            Spacer()

            Button {
                Analytics.onboardingStep(step: "goodNews")
                withAnimation { currentPage = 7 }
            } label: {
                Text("Take the Brain Age Test")
                    .gradientButton()
            }
            .padding(.horizontal, 32)
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
            // Brain score result is saved in completeOnboarding() along with the User,
            // so both are persisted in a single transaction before the view transition.
            withAnimation {
                currentPage = 8 // → commitment
            }
        }
    }

    // Note: OnboardingAssessmentView's onComplete now passes nil when skipped

    // MARK: - Commitment Page

    private var commitmentPage: some View {
        VStack(spacing: 0) {
            Spacer().frame(height: 80)

            // Title with user's name
            Group {
                if enteredName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    Text("Your Contract")
                        .font(.system(size: 28, weight: .bold, design: .rounded))
                } else {
                    (Text(enteredName.trimmingCharacters(in: .whitespacesAndNewlines))
                        .foregroundColor(AppColors.accent)
                    + Text("'s Contract"))
                        .font(.system(size: 28, weight: .bold, design: .rounded))
                }
            }
            .padding(.bottom, 28)

            // Commitment bullets
            VStack(alignment: .leading, spacing: 16) {
                commitmentBullet("I'll train my brain for ", bold: "5 minutes a day")
                commitmentBullet("I'll ", bold: "build my streak", suffix: " and not break it")
                commitmentBullet("I'll ", bold: "put down the scroll", suffix: " and pick up the games")
                commitmentBullet("I'll ", bold: "sharpen my mind", suffix: " every single day")
            }
            .padding(.horizontal, 32)

            Spacer()

            // Hold to agree — organic shape
            VStack(spacing: 12) {
                ZStack {
                    // Invisible hit target
                    Circle()
                        .fill(Color.clear)
                        .frame(width: 100, height: 100)
                        .contentShape(Circle())

                    // Organic background outline
                    OrganicCircle()
                        .stroke(AppColors.cardBorder, lineWidth: 2.5)
                        .frame(width: 80, height: 80)

                    // Progress fill inside
                    OrganicCircle()
                        .fill(AppColors.accent.opacity(0.15 * holdProgress))
                        .frame(width: 74, height: 74)
                        .scaleEffect(0.3 + 0.7 * holdProgress)
                        .animation(.easeOut(duration: 0.1), value: holdProgress)

                    // Completed state
                    if commitmentCompleted {
                        OrganicCircle()
                            .fill(AppColors.accent.opacity(0.2))
                            .frame(width: 74, height: 74)

                        Image(systemName: "checkmark")
                            .font(.system(size: 24, weight: .semibold))
                            .foregroundStyle(AppColors.accent)
                            .transition(.scale.combined(with: .opacity))
                    }
                }
                .gesture(
                    DragGesture(minimumDistance: 0)
                        .onChanged { _ in
                            guard !commitmentCompleted else { return }
                            if holdTimer == nil {
                                startHoldTimer()
                            }
                        }
                        .onEnded { _ in
                            if !commitmentCompleted {
                                cancelHoldTimer()
                            }
                        }
                )

                if !commitmentCompleted {
                    Text("Hold to agree")
                        .font(.system(size: 20, weight: .bold, design: .rounded))

                    Text("Research shows that committing to contracts\nboosts follow-through and accountability")
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 32)
                }
            }
            .padding(.bottom, 32)
        }
        .padding(.bottom, 8)
        .responsiveContent(maxWidth: 500)
        .frame(maxWidth: .infinity)
    }

    private func commitmentBullet(_ prefix: String, bold: String, suffix: String = "") -> some View {
        (Text("• " + prefix)
            .font(.subheadline)
        + Text(bold)
            .font(.subheadline.weight(.bold))
        + Text(suffix)
            .font(.subheadline))
            .foregroundStyle(.primary)
    }

    private func startHoldTimer() {
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
        holdTimer = Timer.scheduledTimer(withTimeInterval: 0.05, repeats: true) { _ in
            Task { @MainActor in
                holdProgress += 0.05 / 3.0 // 3 seconds total
                if holdProgress.truncatingRemainder(dividingBy: 0.1) < 0.02 {
                    UIImpactFeedbackGenerator(style: .light).impactOccurred()
                }
                if holdProgress >= 1.0 {
                    holdProgress = 1.0
                    cancelHoldTimer()
                    UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                    withAnimation(.spring(response: 0.4, dampingFraction: 0.6)) {
                        commitmentCompleted = true
                    }
                    Analytics.onboardingStep(step: "commitment")
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.8) {
                        withAnimation { currentPage = 9 }
                    }
                }
            }
        }
    }

    private func cancelHoldTimer() {
        holdTimer?.invalidate()
        holdTimer = nil
        // Don't reset progress — let users resume from where they stopped
    }

    // MARK: - Notifications Page

    private var notificationsPage: some View {
        VStack(spacing: 32) {
            Spacer()

            Image("mascot-celebrate")
                .renderingMode(.original)
                .resizable()
                .scaledToFit()
                .frame(height: 150)

            VStack(spacing: 8) {
                Text("Stay on track")
                    .font(.system(size: 28, weight: .bold, design: .rounded))
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
                        withAnimation { currentPage = 10 }
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
        VStack(spacing: 24) {
            Spacer().frame(height: 60)

            Text(selectedAppearance == 2 ? "🌙" : selectedAppearance == 1 ? "☀️" : "🌗")
                .font(.system(size: 80))
                .contentTransition(.symbolEffect(.replace))

            VStack(spacing: 8) {
                Text("Choose your look")
                    .font(.system(size: 28, weight: .bold, design: .rounded))
                    .multilineTextAlignment(.center)
                Text("You can change this anytime in Settings.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }

            VStack(spacing: 10) {
                appearanceOption(value: 0, label: "System", emoji: "📱", description: "Match device")
                appearanceOption(value: 1, label: "Light", emoji: "☀️", description: "Always light")
                appearanceOption(value: 2, label: "Dark", emoji: "🌙", description: "Always dark")
            }
            .padding(.horizontal, 24)

            Spacer()

            Button {
                Analytics.onboardingStep(step: "appearance")
                withAnimation { currentPage = 5 } // → bad news
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

    private func appearanceOption(value: Int, label: String, emoji: String, description: String) -> some View {
        let isSelected = selectedAppearance == value
        return Button {
            withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                selectedAppearance = value
                applyAppearance(value)
            }
        } label: {
            HStack(spacing: 14) {
                Text(emoji)
                    .font(.system(size: 28))

                VStack(alignment: .leading, spacing: 2) {
                    Text(label)
                        .font(.body.weight(.semibold))
                        .foregroundStyle(.primary)
                    Text(description)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Spacer()
            }
            .padding(.vertical, 14)
            .padding(.horizontal, 18)
            .background(
                ZStack {
                    RoundedRectangle(cornerRadius: 14)
                        .fill(isSelected ? AppColors.accent.opacity(0.4) : AppColors.cardBorder)
                        .offset(y: 3)
                    RoundedRectangle(cornerRadius: 14)
                        .fill(isSelected ? AppColors.accent.opacity(0.08) : AppColors.cardSurface)
                }
            )
            .overlay(
                RoundedRectangle(cornerRadius: 14)
                    .stroke(isSelected ? AppColors.accent : AppColors.cardBorder, lineWidth: isSelected ? 2 : 1.5)
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
        VStack(spacing: 24) {
            Spacer().frame(height: 60)

            Image("mascot-streak-fire")
                .renderingMode(.original)
                .resizable()
                .scaledToFit()
                .frame(height: 180)

            VStack(spacing: 10) {
                Text("You're ready!")
                    .font(.system(size: 32, weight: .bold, design: .rounded))

                Text("Start training and climb\nthe leaderboards.")
                    .font(.title3)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }

            // Privacy note - subtle, not the focus
            HStack(spacing: 8) {
                Image(systemName: "lock.fill")
                    .font(.caption)
                    .foregroundStyle(.tertiary)
                Text("Your data stays on your device. Always.")
                    .font(.caption)
                    .foregroundStyle(.tertiary)
            }
            .padding(.top, 8)

            Spacer()

            Button {
                Analytics.onboardingStep(step: "privacy")
                completeOnboarding()
            } label: {
                Text("Let's Go")
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
        if let result = assessmentResult {
            modelContext.insert(result)
            user.totalXP += 50  // Bonus XP for completing onboarding assessment
        }

        Analytics.onboardingCompleted(goals: Array(selectedGoals).map(\.rawValue))

        try? modelContext.save()
        onComplete()
    }
}

// MARK: - Organic Circle Shape

struct OrganicCircle: Shape {
    func path(in rect: CGRect) -> Path {
        let w = rect.width
        let h = rect.height
        let cx = rect.midX
        let cy = rect.midY

        var path = Path()
        let points = 60
        for i in 0..<points {
            let angle = Double(i) / Double(points) * 2 * .pi
            let wobble = sin(angle * 3) * 0.06 + cos(angle * 5) * 0.04
            let r = 0.5 + wobble
            let x = cx + CGFloat(cos(angle) * r) * w
            let y = cy + CGFloat(sin(angle) * r) * h
            if i == 0 {
                path.move(to: CGPoint(x: x, y: y))
            } else {
                path.addLine(to: CGPoint(x: x, y: y))
            }
        }
        path.closeSubpath()
        return path
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
            HStack(spacing: 14) {
                Text(goal.emoji)
                    .font(.system(size: 28))

                Text(goal.displayName)
                    .font(.body.weight(.semibold))
                    .foregroundStyle(.primary)

                Spacer()
            }
            .padding(.vertical, 14)
            .padding(.horizontal, 18)
            .background(
                ZStack {
                    // Bottom shadow/3D edge
                    RoundedRectangle(cornerRadius: 14)
                        .fill(isSelected ? AppColors.accent.opacity(0.4) : AppColors.cardBorder)
                        .offset(y: 3)
                    // Main card
                    RoundedRectangle(cornerRadius: 14)
                        .fill(isSelected ? AppColors.accent.opacity(0.08) : AppColors.cardSurface)
                }
            )
            .overlay(
                RoundedRectangle(cornerRadius: 14)
                    .stroke(
                        isSelected ? AppColors.accent : AppColors.cardBorder,
                        lineWidth: isSelected ? 2 : 1.5
                    )
            )
        }
        .buttonStyle(.plain)
        .accessibilityLabel("\(goal.displayName)\(isSelected ? ", selected" : "")")
    }
}
