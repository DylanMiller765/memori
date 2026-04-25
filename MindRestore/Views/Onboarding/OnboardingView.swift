import SwiftUI
import SwiftData
import UIKit
import FamilyControls

struct OnboardingView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(FocusModeService.self) private var focusModeService
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
    @State private var showingBrainAgeReveal = false
    @State private var screenTimeAuthorized = false

    var onComplete: () -> Void

    private let totalPages = 12

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
                    personalSolutionPage.tag(6)
                    notificationPrimingPage.tag(7)
                    stat144Page.tag(8)
                    personalUnlocksPage.tag(9)
                    focusModePage.tag(10)
                    commitmentPage.tag(11)
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
                    if newPage != 11 {
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
                let stepNames = ["welcome", "name", "goals", "age", "scare", "quickAssessment", "personalSolution", "notificationPriming", "stat144", "personalUnlocks", "focusMode", "commitment"]
                let lastStep = currentPage < stepNames.count ? stepNames[currentPage] : "unknown"
                Analytics.onboardingDroppedOff(lastStep: lastStep, totalSteps: currentPage)
            }
        }
        // Single full-screen cover for reveal → paywall. Chaining two .fullScreenCover
        // presentations produces a race where the second cover can silently fail to present
        // while the first is still in its dismiss animation.
        .fullScreenCover(isPresented: $showingBrainAgeReveal, onDismiss: {
            Analytics.onboardingStep(step: "paywallDismissed")
            withAnimation { currentPage = 6 } // → personalSolution
        }) {
            OnboardingFinaleSequence(
                brainAge: assessmentResult?.brainAge ?? 25,
                userAge: selectedAge > 0 ? selectedAge : 25
            )
        }
    }

    // MARK: - Stat 144× Page

    private var stat144Page: some View {
        FocusOnboardA {
            Analytics.onboardingStep(step: "stat144")
            // Request FamilyControls/Screen Time auth so the next page can show real unlocks.
            Task {
                await focusModeService.requestAuthorization()
                screenTimeAuthorized = (focusModeService.authorizationStatus == .approved)
                withAnimation { currentPage = 9 } // → personalUnlocks
            }
        }
    }

    // MARK: - Personal Unlocks (287×) Page

    private var personalUnlocksPage: some View {
        // Once iOS marks FamilyControls as .denied, requestAuthorization() silently
        // no-ops — the only path back is Settings. The page handles that CTA itself.
        let denied = (focusModeService.authorizationStatus == .denied)
        return FocusOnboardPersonalUnlocks(
            onContinue: {
                if screenTimeAuthorized {
                    Analytics.onboardingStep(step: "personalUnlocksAuthorized")
                    withAnimation { currentPage = 10 } // → focusMode
                } else if denied {
                    // CTA already deep-links to Settings inside the view. Nothing to do here.
                    // (User returns to this page; if they enabled it, screenTimeAuthorized
                    // will flip on next .onAppear via the focusModeService refresh.)
                    Analytics.onboardingStep(step: "personalUnlocksOpenedSettings")
                } else {
                    // First decline (or .notDetermined) — re-prompt auth
                    Task {
                        await focusModeService.requestAuthorization()
                        screenTimeAuthorized = (focusModeService.authorizationStatus == .approved)
                        if screenTimeAuthorized {
                            Analytics.onboardingStep(step: "personalUnlocksAuthorized")
                        } else {
                            // still declined — let them continue anyway
                            Analytics.onboardingStep(step: "personalUnlocksDeclined")
                            withAnimation { currentPage = 10 } // → focusMode
                        }
                    }
                }
            },
            authorized: screenTimeAuthorized,
            count: 287,
            previouslyDenied: denied
        )
        .onAppear {
            // Re-check authorization in case user just returned from Settings.
            screenTimeAuthorized = (focusModeService.authorizationStatus == .approved)
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
        VStack(alignment: .leading, spacing: 0) {
            Spacer().frame(height: 32)

            VStack(alignment: .leading, spacing: 8) {
                Text("Pick your focus")
                    .font(.system(size: 32, weight: .bold))
                    .kerning(-0.6)
                Text("Select 1–3 goals")
                    .font(.system(size: 15))
                    .foregroundStyle(.secondary)
            }
            .padding(.horizontal, 24)
            .padding(.bottom, 28)

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

            VStack(spacing: 10) {
                Text("How old are you?")
                    .font(.system(size: 32, weight: .bold))
                    .kerning(-0.6)
                    .multilineTextAlignment(.center)

                Text("We'll compare your Brain Age to your real age.")
                    .font(.system(size: 15))
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 32)
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
            // Present dramatic reveal as a full-screen cover so it escapes the TabView.
            // Cover only fires from a legitimate onComplete — swiping the TabView won't trigger it.
            showingBrainAgeReveal = true
        }
    }

    // MARK: - Personal Solution Page (NEW)

    private var personalSolutionPage: some View {
        OnboardingPersonalSolutionView(
            userGoals: selectedGoals,
            brainAge: assessmentResult?.brainAge,
            userAge: selectedAge,
            onContinue: {
                Analytics.onboardingStep(step: "personalSolution")
                withAnimation { currentPage = 7 } // → notification priming
            }
        )
    }

    // MARK: - Notification Priming Page (NEW)

    private var notificationPrimingPage: some View {
        OnboardingNotificationPrimingView { granted in
            notificationsEnabled = granted
            withAnimation { currentPage = 8 } // → stat144
        }
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
                    TypewriterText(fullText: "• I'll train my brain for 5 minutes a day", speed: 0.025)
                        .font(.subheadline)
                        .transition(.opacity)
                }
                if commitmentBullet2Visible {
                    TypewriterText(fullText: "• I'll build my streak and not break it", speed: 0.025)
                        .font(.subheadline)
                        .transition(.opacity)
                }
                if commitmentBullet3Visible {
                    TypewriterText(fullText: focusModeWasSetUp
                        ? "• I'll let Memori block my distracting apps"
                        : "• I'll put down the scroll and pick up the games", speed: 0.025)
                        .font(.subheadline)
                        .transition(.opacity)
                }
                if commitmentBullet4Visible {
                    TypewriterText(fullText: "• I'll take back my screen time", speed: 0.025)
                        .font(.subheadline)
                        .transition(.opacity)
                }
            }
            .padding(.horizontal, 32)
            .onAppear {
                let delays = [0.15, 0.85, 1.55, 2.25]
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

                    // Base grey ring (always visible)
                    OrganicCircle()
                        .stroke(AppColors.cardBorder, lineWidth: 2.5)
                        .frame(width: 80, height: 80)

                    // Bright accent ring fades in as you hold
                    OrganicCircle()
                        .stroke(AppColors.accent, lineWidth: 3.5)
                        .frame(width: 80, height: 80)
                        .opacity(holdProgress)
                        .shadow(color: AppColors.accent.opacity(0.7 * holdProgress), radius: 14 * holdProgress)
                        .animation(.easeOut(duration: 0.08), value: holdProgress)

                    // Progress fill — strong at full hold
                    OrganicCircle()
                        .fill(AppColors.accent.opacity(0.85 * holdProgress))
                        .frame(width: 74, height: 74)
                        .scaleEffect(0.5 + 0.5 * holdProgress)
                        .shadow(color: AppColors.accent.opacity(0.5 * holdProgress), radius: 16 * holdProgress)
                        .animation(.easeOut(duration: 0.08), value: holdProgress)

                    // Completed state
                    if commitmentCompleted {
                        OrganicCircle()
                            .fill(AppColors.accent)
                            .frame(width: 74, height: 74)
                            .shadow(color: AppColors.accent.opacity(0.6), radius: 18)

                        Image(systemName: "checkmark")
                            .font(.system(size: 24, weight: .semibold))
                            .foregroundStyle(.white)
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
                        .foregroundStyle(holdProgress > 0.05 ? AppColors.accent : Color.primary)
                        .animation(.easeOut(duration: 0.15), value: holdProgress > 0.05)

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
        ZStack(alignment: .bottom) {
            FocusModeSetupView(onComplete: {
                focusModeWasSetUp = true
                Analytics.onboardingStep(step: "focusModeCompleted")
                withAnimation { currentPage = 11 } // → commitment
            })

            // "Not now" skip button
            Button {
                Analytics.onboardingStep(step: "focusModeSkipped")
                Analytics.focusSetupSkipped()
                withAnimation { currentPage = 11 } // → commitment
            } label: {
                Text("Not now")
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(.secondary)
            }
            .padding(.bottom, 8)
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

    private var goalColor: Color {
        switch goal {
        case .screenTimeFrying: return AppColors.coral
        case .doomscrolling:    return AppColors.violet
        case .attentionShot:    return AppColors.accent
        case .loseFocus:        return AppColors.sky
        case .forgetInstantly:  return AppColors.mint
        case .getSharper:       return AppColors.amber
        }
    }

    var body: some View {
        Button(action: action) {
            HStack(spacing: 14) {
                ZStack {
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .fill(goalColor)
                    Image(systemName: goal.icon)
                        .font(.system(size: 26, weight: .bold))
                        .foregroundStyle(.white)
                }
                .frame(width: 56, height: 56)

                Text(goal.displayName)
                    .font(.system(size: 17, weight: .bold))
                    .foregroundStyle(isSelected ? goalColor : .primary)
                    .lineLimit(2)
                    .multilineTextAlignment(.leading)
                    .fixedSize(horizontal: false, vertical: true)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            .padding(.vertical, 12)
            .padding(.horizontal, 14)
            .background(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(isSelected ? goalColor.opacity(0.10) : AppColors.cardSurface)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .stroke(
                        isSelected ? goalColor : AppColors.cardBorder,
                        lineWidth: isSelected ? 2 : 1
                    )
            )
        }
        .buttonStyle(.plain)
        .accessibilityLabel("\(goal.displayName)\(isSelected ? ", selected" : "")")
    }
}
