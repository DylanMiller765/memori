import SwiftUI
import SwiftData
import UIKit

struct OnboardingView: View {
    @Environment(\.modelContext) private var modelContext
    @Query private var users: [User]
    @State private var currentPage = 0
    @State private var selectedGoals: Set<UserFocusGoal> = []
    @State private var assessmentResult: BrainScoreResult?
    @State private var notificationsEnabled = false
    @State private var enteredName: String = ""
    @State private var selectedAge: Int = 25
    @State private var holdProgress: CGFloat = 0
    @State private var holdTimer: Timer?
    @State private var commitmentCompleted = false
    @State private var mascotBob = false
    @State private var welcomeSubtitleVisible = false
    @State private var badNewsTypingDone = false
    @State private var goodNewsTypingDone = false
    @State private var badNewsSubtitleVisible = false
    @State private var goodNewsSubtitleVisible = false
    @State private var commitmentBullet1Visible = false
    @State private var commitmentBullet2Visible = false
    @State private var commitmentBullet3Visible = false
    @State private var commitmentBullet4Visible = false
    @FocusState private var nameFieldFocused: Bool
    @State private var showingFocusModeSetup = false
    @State private var focusModeWasSetUp = false
    @State private var quickAssessmentBgColor: Color = AppColors.pageBg
    @State private var showingOnboardingPaywall = false

    var onComplete: () -> Void

    private let totalPages = 9

    var body: some View {
        ZStack {
            (currentPage == 5 ? quickAssessmentBgColor : AppColors.pageBg).ignoresSafeArea()

            VStack(spacing: 0) {
                TabView(selection: $currentPage) {
                    welcomePage.tag(0)
                    namePage.tag(1)
                    goalsPage.tag(2)
                    agePage.tag(3)
                    scarePage.tag(4)
                    quickAssessmentPage.tag(5)
                    revealAndHopePage.tag(6)
                    focusModePage.tag(7)
                    commitmentPage.tag(8)
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
                    // Reset typewriter animation states when navigating away
                    if newPage != 4 {
                        badNewsTypingDone = false
                        badNewsSubtitleVisible = false
                    }
                    if newPage != 6 {
                        goodNewsTypingDone = false
                        goodNewsSubtitleVisible = false
                    }
                    if newPage != 8 {
                        commitmentBullet1Visible = false
                        commitmentBullet2Visible = false
                        commitmentBullet3Visible = false
                        commitmentBullet4Visible = false
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
        .onDisappear {
            if users.first?.hasCompletedOnboarding != true {
                let stepNames = ["welcome", "name", "goals", "age", "scare", "quickAssessment", "reveal", "focusMode", "commitment"]
                let lastStep = currentPage < stepNames.count ? stepNames[currentPage] : "unknown"
                Analytics.onboardingDroppedOff(lastStep: lastStep, totalSteps: currentPage)
            }
        }
    }

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
                    .font(.system(size: 36, weight: .bold, design: .rounded))

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

    // MARK: - Name Entry Page

    private var namePage: some View {
        ScrollView {
            VStack(spacing: 32) {
                Spacer(minLength: 60)

                // Animated greeting emoji
                Text("👋")
                    .font(.system(size: 64))

                VStack(spacing: 10) {
                    TypewriterText(fullText: "What should we\ncall you?")
                        .font(.system(size: 28, weight: .bold, design: .rounded))
                        .multilineTextAlignment(.center)
                    Text("So Memo knows what to call you")
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

    // MARK: - Scare Page

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

    // MARK: - Quick Assessment Page

    private var quickAssessmentPage: some View {
        QuickAssessmentView(backgroundColor: $quickAssessmentBgColor) { result in
            assessmentResult = result
            Analytics.onboardingStep(step: "quickAssessment")
            withAnimation { currentPage = 6 }
        }
    }

    // MARK: - Reveal and Hope Page

    private var revealAndHopePage: some View {
        VStack(spacing: 24) {
            Spacer().frame(height: 60)

            if let result = assessmentResult {
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
                .frame(height: 140)

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

            VStack(spacing: 12) {
                Button {
                    showingOnboardingPaywall = true
                } label: {
                    Text("Start Free Trial")
                        .gradientButton()
                }

                Button {
                    Analytics.onboardingStep(step: "reveal")
                    withAnimation { currentPage = 7 }
                } label: {
                    Text("Maybe later")
                        .font(.subheadline.weight(.medium))
                        .foregroundStyle(.secondary)
                        .padding(.vertical, 8)
                }
            }
            .padding(.horizontal, 32)
            .sheet(isPresented: $showingOnboardingPaywall) {
                PaywallView(
                    isHighIntent: true,
                    triggerSource: "onboarding"
                )
            }
        }
        .padding(.bottom, 8)
        .responsiveContent(maxWidth: 500)
        .frame(maxWidth: .infinity)
    }

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
            .padding(.horizontal, 32)
            .onAppear {
                let delays = [0.3, 1.8, 3.3, 4.8]
                DispatchQueue.main.asyncAfter(deadline: .now() + delays[0]) {
                    withAnimation { commitmentBullet1Visible = true }
                }
                DispatchQueue.main.asyncAfter(deadline: .now() + delays[1]) {
                    withAnimation { commitmentBullet2Visible = true }
                }
                DispatchQueue.main.asyncAfter(deadline: .now() + delays[2]) {
                    withAnimation { commitmentBullet3Visible = true }
                }
                DispatchQueue.main.asyncAfter(deadline: .now() + delays[3]) {
                    withAnimation { commitmentBullet4Visible = true }
                }
            }

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

            HStack(spacing: 6) {
                Image(systemName: "lock.fill")
                    .font(.caption2)
                Text("All data stays on your device. No tracking. No cloud uploads.")
                    .font(.caption)
            }
            .foregroundStyle(.tertiary)
            .padding(.top, 8)
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
                        completeOnboarding()
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

    // MARK: - Focus Mode Page

    private var focusModePage: some View {
        Color.clear
            .onAppear {
                showingFocusModeSetup = true
            }
            .sheet(isPresented: $showingFocusModeSetup) {
                FocusModeSetupView()
                    .onDisappear {
                        focusModeWasSetUp = true
                        Analytics.onboardingStep(step: "focusModeCompleted")
                        withAnimation { currentPage = 8 }
                    }
            }
            .overlay {
                VStack {
                    Spacer()
                    Button {
                        showingFocusModeSetup = false
                        Analytics.onboardingStep(step: "focusModeSkipped")
                        withAnimation { currentPage = 8 }
                    } label: {
                        Text("Skip Focus Mode")
                            .font(.subheadline.weight(.medium))
                            .foregroundStyle(.secondary)
                            .padding(.vertical, 8)
                    }
                    .padding(.bottom, 40)
                }
            }
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

        UserDefaults.standard.set(AppTheme.dark.rawValue, forKey: "appTheme")
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
                    .lineLimit(2)
                    .minimumScaleFactor(0.8)

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
