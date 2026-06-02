import SwiftUI
import SwiftData
import UIKit
import FamilyControls
import DeviceActivity
import AVKit
import AVFoundation

struct OnboardingView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(FocusModeService.self) private var focusModeService
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Query private var users: [User]
    @State private var currentPage = 0
    @State private var selectedGoals: Set<UserFocusGoal> = []
    @State private var selectedProtectedPriority: OnboardingProtectedPriority?
    @State private var selectedDangerWindow: OnboardingDangerWindow?
    @State private var assessmentResult: BrainScoreResult?
    @State private var notificationsEnabled = false
    @State private var enteredName: String = ""
    @State private var selectedAge: Int = 25
    @State private var holdProgress: CGFloat = 0
    @State private var holdTimer: Timer?
    @State private var commitmentCompleted = false
    @State private var onboardingCompletionQueued = false
    @State private var welcomeHeadlineVisible = false
    @State private var welcomeAppsVisible: [Bool] = Array(repeating: false, count: 6)
    @State private var welcomeAppsLeaning = false
    @State private var welcomeAppsPushed: [Bool] = Array(repeating: false, count: 6)
    @State private var welcomeMemoVisible = false
    @State private var welcomeMemoLeaning = false
    @State private var welcomeMemoShoving = false
    @State private var welcomeMemoEnlarged = false
    @State private var welcomeSublineVisible = false
    @State private var welcomeCTAVisible = false
    /// After the bouncer hero animation completes, the bezel demo materializes
    /// in the same screen area. Only flips to true if the demo asset is
    /// bundled — otherwise the bouncer stays as the hero.
    @State private var welcomeBezelVisible = false
    /// Becomes true once the bezel has finished scaling in (or, when the demo
    /// asset is missing, at the equivalent point in time). Gates the "Let's
    /// go" CTA so reflexive tappers can't blow past the entrance before the
    /// bezel has even materialized.
    @State private var welcomeCTATappable = false
    @State private var commitmentBullet1Visible = false
    @State private var commitmentBullet2Visible = false
    @State private var commitmentBullet3Visible = false
    @State private var commitmentBullet4Visible = false
    @State private var nameMascotBob = false
    @State private var nameSubheadVisible = false
    @State private var nameInputVisible = false
    @FocusState private var nameFieldFocused: Bool
    @State private var empathySceneVisible = false
    @State private var empathySignalBroken = false
    @State private var empathyCopyVisible = false
    @State private var empathyCTAVisible = false
    @State private var focusModeWasSetUp = false
    @State private var quickAssessmentBgColor: Color = AppColors.pageBg
    @State private var quickAssessmentIsFullscreen = false
    @State private var screenTimeAuthorized = false
    @State private var isRequestingScreenTimeAccess = false
    @State private var screenTimeEstimateHours: Double = 4
    @State private var measuredScreenTimeHours: Double?
    @State private var useScreenTimeEstimate = false
    @State private var showingScreenTimeEstimateSheet = false
    @State private var screenTimeCacheRefreshTask: Task<Void, Never>?
    @State private var screenTimeReceiptVisible = false
    @State private var agePageAppeared = false
    @State private var receiptCount: Int = 0
    /// Single-slot cover state. iOS 17 SwiftUI silently no-ops the second of two
    /// stacked .fullScreenCover(isPresented:) modifiers — using item-based with
    /// an enum forces a clean swap and fixes the "paywall doesn't present" bug.
    @State private var presentedCover: OnboardingCover?

    enum OnboardingCover: Identifiable {
        case brainAgeReveal
        case paywall
        var id: Self { self }
    }

    var onComplete: () -> Void

    private let totalPages = 17

    init(startPage: Int = 0, previewName: String = "", onComplete: @escaping () -> Void) {
        self.onComplete = onComplete
        _currentPage = State(initialValue: startPage)
        _enteredName = State(initialValue: previewName)
    }

    var body: some View {
        ZStack {
            // Onboarding is dark-pinned regardless of system theme — use OB.bg
            // directly so light-mode iPhones don't bleed cream pageBg through
            // the chrome around the TabView. Quick Assessment keeps its
            // dynamic bg color (the assessment animates color shifts).
            (currentPage == 10 ? quickAssessmentBgColor : OB.bg).ignoresSafeArea()

            // Page-specific atmosphere lifted out of individual pages so
            // blurs/glows extend behind the progress bar instead of clipping
            // at the page's top edge. Pages should leave their atmosphere
            // empty and declare effects here keyed off `currentPage`.
            pageAtmosphere
                .ignoresSafeArea()
                .allowsHitTesting(false)
                .animation(.easeInOut(duration: 0.3), value: currentPage)

            VStack(spacing: 0) {
                // Progress header is always rendered; visibility controlled by
                // progressHeaderOpacity so it fades on entry/exit of full-bleed
                // editorial pages (Empathy 4, Quick Assessment 9, Plan Reveal 10)
                // instead of snapping when a conditional flips.
                onboardingProgressHeader
                    .opacity(progressHeaderOpacity)
                    .animation(.easeInOut(duration: 0.30), value: currentPage)
                    .allowsHitTesting(progressHeaderOpacity > 0)

                pageContent
                    .id(currentPage)
                    .zIndex(Double(currentPage))
                    .transition(reduceMotion
                        ? AnyTransition.opacity.animation(.easeInOut(duration: 0.18))
                        : AnyTransition.asymmetric(
                            insertion: .opacity
                                .combined(with: .scale(scale: 0.96, anchor: .center))
                                .combined(with: .offset(y: 8))
                                .animation(.easeOut(duration: 0.40)),
                            removal: .opacity
                                .animation(.easeIn(duration: 0.30))
                        )
                    )
                    .animation(.easeInOut(duration: 0.40), value: currentPage)
                    .onChange(of: currentPage) { _, newPage in
                        // Animate keyboard dismiss smoothly
                        UIView.animate(withDuration: 0.3, delay: 0, options: .curveEaseOut) {
                            UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
                        }
                        nameFieldFocused = false
                        #if !DEBUG
                        if newPage == 1 {
                            DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) {
                                nameFieldFocused = true
                            }
                        }
                        #endif
                        // Reset commitment typewriter bullets when navigating away
                        if newPage != 16 {
                            commitmentBullet1Visible = false
                            commitmentBullet2Visible = false
                            commitmentBullet3Visible = false
                            commitmentBullet4Visible = false
                        }
                    }
            }
        }
        .preferredColorScheme(.dark)
        .environment(\.colorScheme, .dark)
        .onDisappear {
            if users.first?.hasCompletedOnboarding != true {
                let stepNames = ["welcome", "name", "painCards", "industryScare", "empathy", "goals", "protect", "dangerWindow", "age", "screenTimeAccess", "quickAssessment", "planReveal", "comparison", "differentiation", "focusMode", "notificationPriming", "commitment"]
                let lastStep = currentPage < stepNames.count ? stepNames[currentPage] : "unknown"
                Analytics.onboardingDroppedOff(lastStep: lastStep, totalSteps: currentPage)
            }
        }
        // Single-cover slot: brain age reveal first, then paywall after differentiation.
        // Tracked-last-value handles per-cover dismissal routing.
        .fullScreenCover(item: $presentedCover, onDismiss: handleCoverDismiss) { cover in
            switch cover {
            case .brainAgeReveal:
                OnboardingBrainAgeReveal(
                    brainAge: assessmentResult?.brainAge ?? 25,
                    userAge: selectedAge > 0 ? selectedAge : 25,
                    onContinue: { presentedCover = nil }
                )
            case .paywall:
                PaywallView(isHighIntent: true, triggerSource: "onboarding")
            }
        }
        .onChange(of: presentedCover) { oldValue, newValue in
            // onDismiss fires after the binding is already nil, so capture the
            // outgoing identity here for routing.
            if newValue == nil, oldValue != nil {
                lastDismissedCover = oldValue
            }
        }
    }

    @State private var lastDismissedCover: OnboardingCover?

    private func handleCoverDismiss() {
        // Route based on which cover just closed.
        switch lastDismissedCover {
        case .brainAgeReveal:
            Analytics.onboardingStep(step: "revealDismissed")
            goToPage(11) // → planReveal
        case .paywall:
            Analytics.onboardingStep(step: "paywallDismissed")
            goToPage(14) // → focusMode
        case nil:
            break
        }
        lastDismissedCover = nil
    }

    // MARK: - Page Atmosphere
    //
    // Lives at the outer ZStack level so blur effects extend full-screen
    // (including behind the progress bar). Add new cases as pages adopt
    // atmosphere effects.

    /// Single source of truth for which page to render at a given currentPage.
    /// Wrapped in @ViewBuilder so SwiftUI can apply .id / .transition uniformly
    /// to any of the 16 child views.
    @ViewBuilder
    private var pageContent: some View {
        switch currentPage {
        case 0: welcomePage
        case 1: namePage
        case 2: painCardsPage
        case 3: industryScarePage
        case 4: empathyPage
        case 5: goalsPage
        case 6: protectedPriorityPage
        case 7: dangerWindowPage
        case 8: agePage
        case 9: screenTimeAccessPage
        case 10: quickAssessmentPage
        case 11: planRevealPage
        case 12: comparisonPage
        case 13: differentiationPage
        case 14: focusModePage
        case 15: notificationPrimingPage
        case 16: commitmentPage
        default: EmptyView()
        }
    }

    @ViewBuilder
    private var pageAtmosphere: some View {
        switch currentPage {
        case 0:
            welcomeAtmosphere
        default:
            EmptyView()
        }
    }

    // MARK: - Progress Header

    /// Pages where the top progress bar is hidden (full-bleed interactive/cinematic moments):
    /// 10 Quick Assessment, 11 Plan Reveal.
    private var progressHeaderOpacity: Double {
        let hiddenPages: Set<Int> = [10, 11]
        return hiddenPages.contains(currentPage) ? 0 : 1
    }

    /// Single funnel for every page advance / back-step. The animation
    /// context for `currentPage` state changes is tunable here in one place.
    /// The visual transition CURVE itself is defined by `.transition(...)` on
    /// the page container — this `withAnimation` only schedules SwiftUI's
    /// re-render block.
    private func goToPage(_ page: Int) {
        guard (0..<totalPages).contains(page) else { return }
        withAnimation(.easeInOut(duration: 0.40)) {
            currentPage = page
        }
    }

    private var onboardingProgressHeader: some View {
        ZStack {
            GeometryReader { proxy in
                let barWidth = min(proxy.size.width * 0.76, 320)

                ZStack(alignment: .leading) {
                    Capsule()
                        .fill(AppColors.cardBorder)

                    Capsule()
                        .fill(AppColors.accent)
                        .frame(width: barWidth * onboardingProgress)
                }
                .frame(width: barWidth, height: 8)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
            }
            .frame(height: 34)

            Button {
                guard currentPage > 0 else { return }
                goToPage(max(0, currentPage - 1))
            } label: {
                Image(systemName: "chevron.left")
                    .font(.system(size: 18, weight: .bold))
                    .foregroundStyle(currentPage > 0 ? AppColors.textSecondary : .clear)
                    .frame(width: 34, height: 34)
                    .contentShape(Rectangle())
            }
            .disabled(currentPage == 0)
            .accessibilityLabel("Back")
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(.horizontal, 24)
        .padding(.top, currentPage == 9 ? 36 : 10)
        .padding(.bottom, currentPage == 9 ? 0 : 4)
        .animation(.spring(response: 0.35, dampingFraction: 0.85), value: currentPage)
    }

    private var onboardingProgress: CGFloat {
        guard totalPages > 1 else { return 1 }
        return CGFloat(currentPage + 1) / CGFloat(totalPages)
    }

    private var onboardingGoalOrder: [UserFocusGoal] {
        [.attentionShot, .screenTimeFrying, .doomscrolling, .loseFocus, .forgetInstantly, .getSharper]
    }

    private var effectiveDailyScreenTimeHours: Double {
        if useScreenTimeEstimate { return screenTimeEstimateHours }
        let measured = measuredScreenTimeHours ?? readCachedScreenTimeHours()
        return measured ?? screenTimeEstimateHours
    }

    private var projectionIsEstimate: Bool {
        if useScreenTimeEstimate { return true }
        return measuredScreenTimeHours == nil && readCachedScreenTimeHours() == nil
    }

    private var hasMeasuredScreenTimeHours: Bool {
        measuredScreenTimeHours != nil || readCachedScreenTimeHours() != nil
    }

    private var yearsUntilSixty: Int {
        max(1, 60 - (selectedAge > 0 ? selectedAge : 25))
    }

    private var projectedScreenTimeHours: Int {
        Int((effectiveDailyScreenTimeHours * 365 * Double(yearsUntilSixty)).rounded())
    }

    private var yesterdayScreenTimeFilter: DeviceActivityFilter {
        let cal = Calendar.current
        let todayStart = cal.startOfDay(for: Date())
        let yesterdayStart = cal.date(byAdding: .day, value: -1, to: todayStart) ?? todayStart
        return DeviceActivityFilter(
            segment: .daily(during: DateInterval(start: yesterdayStart, end: todayStart)),
            users: .all,
            devices: .init([.iPhone])
        )
    }

    private func readCachedScreenTimeHours() -> Double? {
        let value = UserDefaults(suiteName: "group.com.memori.shared")?
            .double(forKey: "onboarding_daily_screen_time_hours") ?? 0
        return value > 0 ? value : nil
    }

    private func refreshCachedScreenTimeHours() {
        measuredScreenTimeHours = readCachedScreenTimeHours()
    }

    private func startScreenTimeCacheRefreshLoop() {
        screenTimeCacheRefreshTask?.cancel()
        screenTimeCacheRefreshTask = Task { @MainActor in
            for _ in 0..<12 {
                guard !Task.isCancelled else { return }
                refreshCachedScreenTimeHours()
                if measuredScreenTimeHours != nil { return }
                try? await Task.sleep(for: .milliseconds(500))
            }
        }
    }

    private func formatProjectedHours(_ value: Int) -> String {
        if value >= 1000 {
            let rounded = Int((Double(value) / 1000.0).rounded()) * 1000
            return rounded.formatted()
        }
        return value.formatted()
    }

    private var projectedYearsText: String {
        String(format: "%.1f", Double(projectedScreenTimeHours) / 8760.0)
    }

    // MARK: - Personal Scare (287×) Page
    //
    // Sits AFTER ScreenTime auth, BEFORE assessment. Shows the user's real pickup
    // count from yesterday — concrete personal stat that lands harder than any
    // industry average. Auth was already negotiated on screenTimeAccessPage so
    // we don't re-prompt here.

    private var personalScarePage: some View {
        FocusOnboardPersonalUnlocks(
            onContinue: {
                Analytics.onboardingStep(step: "personalScare")
                goToPage(10) // → quickAssessment
            },
            authorized: screenTimeAuthorized,
            count: 287,
            previouslyDenied: (focusModeService.authorizationStatus == .denied)
        )
        .onAppear {
            screenTimeAuthorized = (focusModeService.authorizationStatus == .approved)
        }
    }

    private var welcomePage: some View {
        ZStack {
            // Atmosphere is rendered at the outer body so it can extend behind
            // the progress bar. The page body itself sits on the global pageBg.
            VStack(alignment: .leading, spacing: 0) {
                VStack(alignment: .leading, spacing: 12) {
                    OBEyebrow(text: "MEMO · DOOMSCROLL BLOCKER")
                    // Headline morphs once the bezel materializes — shorter copy
                    // gives the phone-in-phone room to breathe without stealing
                    // the brand line entirely.
                    ZStack(alignment: .topLeading) {
                        (Text("Apps want you.\n") + Text("Memo wants you back.").foregroundColor(OB.accent))
                            .font(.system(size: 38, weight: .heavy, design: .rounded))
                            .foregroundStyle(OB.fg)
                            .lineSpacing(1)
                            .kerning(-0.5)
                            .fixedSize(horizontal: false, vertical: true)
                            .opacity(welcomeBezelVisible ? 0 : 1)

                        Text("Watch Memo in action.")
                            .font(.system(size: 32, weight: .heavy, design: .rounded))
                            .foregroundStyle(OB.fg)
                            .kerning(-0.5)
                            .fixedSize(horizontal: false, vertical: true)
                            .opacity(welcomeBezelVisible ? 1 : 0)
                    }
                }
                .padding(.horizontal, 28)
                .padding(.top, 14)
                .opacity(welcomeHeadlineVisible ? 1 : 0)
                .offset(y: welcomeHeadlineVisible ? 0 : 8)

                Spacer(minLength: 28)

                ZStack {
                    WelcomeBouncerHero(
                        appsVisible: welcomeAppsVisible,
                        appsLeaning: welcomeAppsLeaning,
                        appsPushed: welcomeAppsPushed,
                        memoVisible: welcomeMemoVisible,
                        memoLeaning: welcomeMemoLeaning,
                        memoShoving: welcomeMemoShoving,
                        memoEnlarged: welcomeMemoEnlarged
                    )
                    .opacity(welcomeBezelVisible ? 0 : 1)

                    WelcomeDemoBezel(isActive: welcomeBezelVisible && currentPage == 0)
                        .opacity(welcomeBezelVisible ? 1 : 0)
                        .scaleEffect(welcomeBezelVisible ? 1.0 : 0.92)
                }
                .frame(maxWidth: .infinity)
                .padding(.horizontal, 12)

                Spacer(minLength: 28)

                Text("Block Apps. Train Your Brain.")
                    .font(.system(size: 15, weight: .semibold, design: .rounded))
                    .foregroundStyle(OB.fg2)
                    .padding(.horizontal, 28)
                    .padding(.bottom, 14)
                    .opacity(welcomeSublineVisible ? 1 : 0)
                    .offset(y: welcomeSublineVisible ? 0 : 6)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .safeAreaInset(edge: .bottom) {
            VStack(spacing: 14) {
                OBContinueButton(title: "Take my brain back") {
                    Analytics.onboardingStep(step: "welcome")
                    currentPage = 1
                }
                // Disable taps until the bezel has finished materializing.
                // Otherwise the button is hit-testable behind its .opacity(0)
                // fade-in and a fast user can blow past the bouncer + bezel
                // entrance without seeing them.
                .disabled(!welcomeCTATappable)

                HStack(spacing: 6) {
                    Image(systemName: "lock.fill")
                        .font(.system(size: 10, weight: .heavy))
                    Text("No ads. No data sold. Just your brain fighting back.")
                        .font(.system(size: 12, weight: .semibold, design: .rounded))
                }
                .foregroundStyle(OB.fg3)
            }
            .padding(.horizontal, 24)
            .padding(.bottom, 18)
            .opacity(welcomeCTAVisible ? 1 : 0)
            .offset(y: welcomeCTAVisible ? 0 : 8)
            .allowsHitTesting(welcomeCTATappable)
        }
        .preferredColorScheme(.dark)
        .onAppear { startWelcomeEntrance() }
    }

    private var welcomeAtmosphere: some View {
        // Two blurs that extend behind the progress bar (rendered at the
        // outer ZStack level, ignoring safe area). Top-left accent blur
        // bleeds through the bar area, creating a continuous "you vs them"
        // color tension; bottom-right coral anchors the app pile side.
        ZStack {
            Circle()
                .fill(OB.accent.opacity(0.18))
                .frame(width: 280, height: 280)
                .blur(radius: 76)
                .offset(x: -130, y: -180)

            Circle()
                .fill(OB.coral.opacity(0.10))
                .frame(width: 220, height: 220)
                .blur(radius: 68)
                .offset(x: 140, y: 200)
        }
    }

    private func startWelcomeEntrance() {
        // Reset state so re-entering the welcome (e.g., from a back swipe) replays.
        welcomeHeadlineVisible = false
        welcomeAppsVisible = Array(repeating: false, count: 6)
        welcomeAppsLeaning = false
        welcomeAppsPushed = Array(repeating: false, count: 6)
        welcomeMemoVisible = false
        welcomeMemoLeaning = false
        welcomeMemoShoving = false
        welcomeMemoEnlarged = false
        welcomeSublineVisible = false
        welcomeCTAVisible = false
        welcomeCTATappable = false
        welcomeBezelVisible = false

        // Beat 1 — Headline (threat is being framed)
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.10) {
            withAnimation(.easeOut(duration: 0.4)) { welcomeHeadlineVisible = true }
        }

        // Beat 2 — Apps press in (cascade from right, 0.40s start, 0.08s stagger)
        for i in 0..<6 {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.40 + Double(i) * 0.08) {
                withAnimation(.spring(response: 0.55, dampingFraction: 0.82)) {
                    if i < welcomeAppsVisible.count {
                        welcomeAppsVisible[i] = true
                    }
                }
            }
        }

        // Beat 3 — Memo arrives, holds the line
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.95) {
            withAnimation(.spring(response: 0.50, dampingFraction: 0.78)) {
                welcomeMemoVisible = true
            }
        }

        // Beat 4 — TENSION: apps lean toward Memo, Memo leans into them
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.40) {
            withAnimation(.easeOut(duration: 0.30)) {
                welcomeAppsLeaning = true
                welcomeMemoLeaning = true
            }
            UIImpactFeedbackGenerator(style: .light).impactOccurred()
        }

        // Beat 5 — THE SHOVE: Memo bursts forward, apps fly off-screen
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.80) {
            withAnimation(.easeOut(duration: 0.20)) {
                welcomeAppsLeaning = false
                welcomeMemoLeaning = false
            }
            withAnimation(.spring(response: 0.18, dampingFraction: 0.70)) {
                welcomeMemoShoving = true
            }
        }
        for i in 0..<6 {
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.80 + Double(i) * 0.04) {
                withAnimation(.easeIn(duration: 0.5)) {
                    if i < welcomeAppsPushed.count {
                        welcomeAppsPushed[i] = true
                    }
                }
            }
        }

        // Beat 6 — Snapback: Memo recovers from the shove with overshoot
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.10) {
            withAnimation(.spring(response: 0.40, dampingFraction: 0.55)) {
                welcomeMemoShoving = false
            }
        }

        // Beat 7 — VICTORY: Memo enlarges
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.35) {
            withAnimation(.spring(response: 0.50, dampingFraction: 0.62)) {
                welcomeMemoEnlarged = true
            }
            UIImpactFeedbackGenerator(style: .medium).impactOccurred()
        }

        // Beat 8 — Copy + CTA settle in
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.55) {
            withAnimation(.easeOut(duration: 0.35)) { welcomeSublineVisible = true }
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.80) {
            withAnimation(.easeOut(duration: 0.4)) { welcomeCTAVisible = true }
        }

        // Beat 9 — Metaphor → receipts. The bouncer hero hands off to the
        // phone-in-phone bezel demo. Only fires if the asset is bundled, so
        // shipping without onboarding_demo.mp4 cleanly falls back to the
        // existing welcome experience.
        if Bundle.main.url(forResource: "onboarding_demo", withExtension: "mp4") != nil {
            DispatchQueue.main.asyncAfter(deadline: .now() + 3.30) {
                withAnimation(.easeInOut(duration: 0.45)) {
                    welcomeBezelVisible = true
                }
            }
        }

        // Beat 10 — Unlock the CTA. Fires regardless of whether the demo
        // asset is bundled (timing matches "bezel finished materializing"
        // when present, and serves as the same beat-after-CTA-fade-in when
        // absent). Always slightly later than welcomeCTAVisible (~3.20s) so
        // the user sees the bezel land before they can tap through.
        DispatchQueue.main.asyncAfter(deadline: .now() + 3.75) {
            welcomeCTATappable = true
        }
    }

    // MARK: - Name Entry Page

    // MARK: - Name Entry Page (redesigned)
    //
    // Memo introduces himself in first person; the user types their name on a
    // borderless underlined input field. No big Continue button — return submits.
    // Skip is a tiny tertiary link. Page is the user's first interactive moment,
    // designed to feel personal, not like a form. Pinned to dark mode + FO
    // design tokens for visual continuity with Industry Scare.
    private var namePage: some View {
        // Local color tokens — match FO.bg / FO.accent from FocusOnboardingPages.swift
        let pageBg = Color(red: 0.039, green: 0.039, blue: 0.059)
        let accent = Color(red: 0.408, green: 0.565, blue: 0.996)
        let textPrimary = Color.white.opacity(0.94)
        let textSecondary = Color.white.opacity(0.62)
        let textTertiary = Color.white.opacity(0.40)

        return ZStack {
            pageBg.ignoresSafeArea()

            VStack(alignment: .leading, spacing: 0) {
                Spacer().frame(height: 18)

                // Memo waving in top-left, gentle bob
                Image("mascot-welcome")
                    .renderingMode(.original)
                    .resizable()
                    .scaledToFit()
                    .frame(width: 100, height: 100)
                    .offset(y: nameMascotBob ? -4 : 4)
                    .animation(.easeInOut(duration: 2.0).repeatForever(autoreverses: true), value: nameMascotBob)
                    .padding(.horizontal, 24)
                    .padding(.bottom, 14)

                #if DEBUG
                HStack(spacing: 10) {
                    Button {
                        nameFieldFocused = false
                        Analytics.onboardingStep(step: "debugJumpBrainTest")
                        goToPage(10)
                    } label: {
                        Text("Debug: Brain test")
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundStyle(accent.opacity(0.9))
                            .padding(.vertical, 8)
                            .padding(.horizontal, 10)
                            .background(
                                Capsule()
                                    .fill(Color.white.opacity(0.06))
                                    .overlay(
                                        Capsule()
                                            .stroke(Color.white.opacity(0.12), lineWidth: 1)
                                    )
                            )
                    }

                    Button {
                        nameFieldFocused = false
                        Analytics.onboardingStep(step: "debugJumpContract")
                        goToPage(16)
                    } label: {
                        Text("Debug: Contract")
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundStyle(accent.opacity(0.9))
                            .padding(.vertical, 8)
                            .padding(.horizontal, 10)
                            .background(
                                Capsule()
                                    .fill(Color.white.opacity(0.06))
                                    .overlay(
                                        Capsule()
                                            .stroke(Color.white.opacity(0.12), lineWidth: 1)
                                    )
                            )
                    }
                }
                .padding(.horizontal, 24)
                .padding(.bottom, 18)
                #endif

                // Memo's intro — typewriter on the headline, fade-up on the question
                VStack(alignment: .leading, spacing: 6) {
                    TypewriterText(fullText: "Hi, I'm Memo.")
                        .font(.system(size: 32, weight: .heavy, design: .rounded))
                        .foregroundStyle(textPrimary)

                    Text("What should I call you?")
                        .font(.system(size: 18, weight: .medium))
                        .foregroundStyle(textSecondary)
                        .opacity(nameSubheadVisible ? 1 : 0)
                        .offset(y: nameSubheadVisible ? 0 : 6)
                }
                .padding(.horizontal, 24)

                Spacer().frame(height: 48)

                // Subtle label, no military cosplay
                Text("YOUR NAME")
                    .font(.system(size: 11, weight: .semibold, design: .monospaced))
                    .tracking(1.4)
                    .foregroundStyle(accent)
                    .padding(.horizontal, 24)
                    .padding(.bottom, 8)
                    .opacity(nameInputVisible ? 1 : 0)

                // Borderless underlined input — feels like signing on a line.
                // Whole row is one tap target so taps anywhere along the bar
                // focus the field, not just the narrow text content area.
                VStack(alignment: .leading, spacing: 8) {
                    TextField("", text: $enteredName)
                    .font(.system(size: 28, weight: .heavy, design: .monospaced))
                    .foregroundStyle(textPrimary)
                    .tint(accent)
                    .focused($nameFieldFocused)
                    .submitLabel(.done)
                    .autocorrectionDisabled()
                    .textInputAutocapitalization(.words)
                    .onSubmit { dismissAndAdvance() }
                    .frame(maxWidth: .infinity, alignment: .leading)

                    // Underline shifts color on focus
                    Rectangle()
                        .fill(nameFieldFocused ? accent : Color.white.opacity(0.35))
                        .frame(height: 1.5)
                        .animation(.easeInOut(duration: 0.25), value: nameFieldFocused)
                }
                .padding(.horizontal, 24)
                .contentShape(Rectangle())
                .onTapGesture { nameFieldFocused = true }
                .opacity(nameInputVisible ? 1 : 0)

                Spacer()

                // Subtle skip link, not a button
                HStack {
                    Spacer()
                    Button {
                        enteredName = ""
                        dismissAndAdvance()
                    } label: {
                        Text("Skip")
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundStyle(textTertiary)
                            .padding(.vertical, 10)
                            .padding(.horizontal, 12)
                    }
                }
                .padding(.horizontal, 16)
                .padding(.bottom, 12)
            }
        }
        .preferredColorScheme(.dark)
        .toolbar {
            // Keyboard accessory — quiet "Done" path for users who don't tap return
            ToolbarItemGroup(placement: .keyboard) {
                Spacer()
                Button {
                    dismissAndAdvance()
                } label: {
                    Text("Done")
                        .font(.subheadline.weight(.bold))
                        .foregroundStyle(accent)
                }
            }
        }
        .onAppear {
            nameMascotBob = true
            nameSubheadVisible = false
            nameInputVisible = false
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.7) {
                withAnimation(.easeOut(duration: 0.4)) { nameSubheadVisible = true }
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                withAnimation(.easeOut(duration: 0.5)) { nameInputVisible = true }
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.2) {
                #if !DEBUG
                if currentPage == 1 { nameFieldFocused = true }
                #endif
            }
        }
        .onDisappear {
            nameFieldFocused = false
        }
    }

    private func dismissAndAdvance() {
        nameFieldFocused = false
        Analytics.onboardingStep(step: "name")
        goToPage(2)
    }

    private var goalsPage: some View {
        ZStack(alignment: .topTrailing) {
            FeedHeistBackdrop()
                .padding(.top, 18)
                .padding(.trailing, 0)

            VStack(alignment: .leading, spacing: 0) {
                Spacer().frame(height: 2)

                MemoLookoutHeader()
                    .padding(.horizontal, 24)
                    .padding(.bottom, 10)

                VStack(alignment: .leading, spacing: 10) {
                    Text("What do you\nwant back?")
                        .font(.system(size: 37, weight: .heavy, design: .rounded))
                        .foregroundStyle(AppColors.textPrimary)
                        .multilineTextAlignment(.leading)
                        .lineSpacing(1)
                        .minimumScaleFactor(0.82)
                        .fixedSize(horizontal: false, vertical: true)

                    Text("Pick up to 3. Memo builds your first counterattack here.")
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(AppColors.textTertiary)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .padding(.horizontal, 24)
                .padding(.bottom, 16)

                VStack(spacing: 0) {
                    Divider()
                        .overlay(AppColors.cardBorder)

                    ForEach(Array(onboardingGoalOrder.enumerated()), id: \.element.id) { index, goal in
                        GoalCard(goal: goal, index: index, isSelected: selectedGoals.contains(goal)) {
                            withAnimation(.spring(response: 0.3, dampingFraction: 0.72)) {
                                if selectedGoals.contains(goal) {
                                    selectedGoals.remove(goal)
                                } else if selectedGoals.count < 3 {
                                    selectedGoals.insert(goal)
                                }
                            }
                        }

                        Divider()
                            .overlay(AppColors.cardBorder.opacity(selectedGoals.contains(goal) ? 0.9 : 0.7))
                    }
                }
                .padding(.horizontal, 24)

                Spacer(minLength: 10)

                continueButton("Personalize my plan") {
                    Analytics.onboardingStep(step: "goals")
                    goToPage(6) // → protect
                }
                    .disabled(selectedGoals.isEmpty)
                    .opacity(selectedGoals.isEmpty ? 0.4 : 1)
            }
            .padding(.bottom, 12)
            .responsiveContent(maxWidth: 500)
            .frame(maxWidth: .infinity)
        }
        .clipped()
        .onAppear { nameFieldFocused = false }
    }

    private var protectedPriorityPage: some View {
        OnboardingPersonalQuestionPage(
            title: "What are you\nprotecting?",
            subtitle: "Pick the thing the feed keeps stealing from.",
            options: OnboardingProtectedPriority.allCases,
            selection: selectedProtectedPriority,
            titleForOption: \.title,
            symbolForOption: \.symbolName,
            onSelect: { selectedProtectedPriority = $0 },
            ctaTitle: "Lock this in",
            onContinue: {
                Analytics.onboardingStep(step: "protect_\(selectedProtectedPriority?.rawValue ?? "unknown")")
                goToPage(7) // → dangerWindow
            }
        )
    }

    private var dangerWindowPage: some View {
        OnboardingPersonalQuestionPage(
            title: "When does the\nfeed usually win?",
            subtitle: "Memo uses this to frame your first guardrail.",
            options: OnboardingDangerWindow.allCases,
            selection: selectedDangerWindow,
            titleForOption: \.title,
            symbolForOption: \.symbolName,
            onSelect: { selectedDangerWindow = $0 },
            ctaTitle: "Build around this",
            onContinue: {
                Analytics.onboardingStep(step: "danger_window_\(selectedDangerWindow?.rawValue ?? "unknown")")
                goToPage(8) // → age
            }
        )
    }

    // MARK: - Screen Time Access Page

    private var screenTimeAccessPage: some View {
        VStack(alignment: .leading, spacing: 0) {
            Spacer().frame(height: screenTimeAuthorized ? 14 : 24)

            VStack(alignment: .leading, spacing: 12) {
                Text(screenTimeAuthorized ? "Memo found\nthe loop." : "Let Memo read\nthe receipt.")
                    .font(.system(size: 38, weight: .heavy, design: .rounded))
                    .foregroundStyle(AppColors.textPrimary)
                    .lineSpacing(-1)
                    .fixedSize(horizontal: false, vertical: true)

                Text(screenTimeAuthorized
                     ? "Yesterday’s Screen Time is now your first receipt."
                     : "Screen Time shows what the feed took. Memo keeps it private and builds your plan from the truth.")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(AppColors.textSecondary)
                    .lineSpacing(3)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(.horizontal, 28)

            if screenTimeAuthorized {
                screenTimePatternReport
                    .padding(.horizontal, 28)
                    .padding(.top, 18)
                    .transition(.opacity.combined(with: .move(edge: .bottom)))
            } else {
                screenTimePermissionPrimer
                    .padding(.horizontal, 28)
                    .padding(.top, 20)
                    .transition(.opacity.combined(with: .move(edge: .bottom)))
            }

            Spacer(minLength: screenTimeAuthorized ? 6 : 18)

            VStack(spacing: 12) {
                continueButton(screenTimeAuthorized ? "Test what it did to my brain" : "Allow Screen Time") {
                    if screenTimeAuthorized {
                        Analytics.onboardingStep(step: "screenTimeAccessApproved")
                        useScreenTimeEstimate = false
                        refreshCachedScreenTimeHours()
                        goToPage(10) // → quickAssessment
                    } else {
                        requestScreenTimeForOnboarding()
                    }
                }
                .disabled(isRequestingScreenTimeAccess)
                .opacity(isRequestingScreenTimeAccess ? 0.6 : 1)

                if !screenTimeAuthorized {
                    Button {
                        Analytics.onboardingStep(step: "screenTimeAccessEstimate")
                        showingScreenTimeEstimateSheet = true
                    } label: {
                        Text("Use a rough estimate")
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(AppColors.textTertiary)
                            .padding(.vertical, 8)
                    }
                }
            }
            .padding(.bottom, screenTimeAuthorized ? 6 : 18)
        }
        .responsiveContent(maxWidth: 500)
        .frame(maxWidth: .infinity)
        .onAppear {
            screenTimeAuthorized = (focusModeService.authorizationStatus == .approved)
            refreshCachedScreenTimeHours()
            if screenTimeAuthorized {
                startScreenTimeCacheRefreshLoop()
                animateScreenTimeReceipt()
            } else {
                screenTimeReceiptVisible = false
            }
        }
        .onDisappear {
            screenTimeCacheRefreshTask?.cancel()
            screenTimeReceiptVisible = false
        }
        .sheet(isPresented: $showingScreenTimeEstimateSheet) {
            ScreenTimeEstimateSheet(
                selection: $screenTimeEstimateHours,
                onConfirm: {
                    useScreenTimeEstimate = true
                    measuredScreenTimeHours = nil
                    showingScreenTimeEstimateSheet = false
                    Analytics.onboardingStep(step: "screenTimeEstimate")
                    goToPage(10) // → quickAssessment
                }
            )
            .presentationDetents([.medium, .large])
            .presentationDragIndicator(.visible)
        }
    }

    private var dailyScreenTimeLabel: String {
        if effectiveDailyScreenTimeHours >= 8 && projectionIsEstimate {
            return "8h+"
        }
        return String(format: "%.1fh", effectiveDailyScreenTimeHours)
    }

    private var screenTimeHoursNumber: String {
        if effectiveDailyScreenTimeHours >= 8 && projectionIsEstimate {
            return "8+"
        }
        return String(format: "%.1f", effectiveDailyScreenTimeHours)
    }

    private var screenTimeDayUsedFraction: CGFloat {
        CGFloat(min(max(effectiveDailyScreenTimeHours / 24, 0.035), 1))
    }

    private var screenTimeRemainingLabel: String {
        let remaining = max(0, 24 - effectiveDailyScreenTimeHours)
        return String(format: "%.1fh left", remaining)
    }

    private var yesterdayDeviceActivityFilter: DeviceActivityFilter {
        let calendar = Calendar.current
        let todayStart = calendar.startOfDay(for: Date())
        let yesterdayStart = calendar.date(byAdding: .day, value: -1, to: todayStart) ?? todayStart
        return DeviceActivityFilter(
            segment: .daily(during: DateInterval(start: yesterdayStart, end: todayStart)),
            users: .all,
            devices: .init([.iPhone])
        )
    }

    private var weeklyScreenTimeDeviceActivityFilter: DeviceActivityFilter {
        let calendar = Calendar.current
        let todayStart = calendar.startOfDay(for: Date())
        let weekStart = calendar.date(byAdding: .day, value: -7, to: todayStart) ?? todayStart
        return DeviceActivityFilter(
            segment: .daily(during: DateInterval(start: weekStart, end: todayStart)),
            users: .all,
            devices: .init([.iPhone])
        )
    }

    private var screenTimePatternReport: some View {
        VStack(alignment: .leading, spacing: 12) {
            connectedStamp
                .opacity(screenTimeReceiptVisible ? 1 : 0)
                .offset(y: screenTimeReceiptVisible ? 0 : 8)
                .animation(.easeOut(duration: 0.28).delay(0.04), value: screenTimeReceiptVisible)

            if screenTimeAuthorized {
                DeviceActivityReport(.screenTime, filter: yesterdayDeviceActivityFilter)
                    .frame(height: 104)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .opacity(screenTimeReceiptVisible ? 1 : 0)
                    .scaleEffect(screenTimeReceiptVisible ? 1 : 0.96, anchor: .leading)
                    .offset(y: screenTimeReceiptVisible ? 0 : 10)
                    .animation(.spring(response: 0.42, dampingFraction: 0.86).delay(0.14), value: screenTimeReceiptVisible)
            } else {
                screenTimeMetricBlock(
                    eyebrow: "estimated screen time",
                    value: screenTimeHoursNumber,
                    suffix: "h",
                    tint: AppColors.coral
                )
            }

            screenTimeReceiptChart
                .opacity(screenTimeReceiptVisible ? 1 : 0)
                .offset(y: screenTimeReceiptVisible ? 0 : 12)
                .animation(.easeOut(duration: 0.34).delay(0.28), value: screenTimeReceiptVisible)

            Divider().overlay(AppColors.cardBorder.opacity(0.7))
                .opacity(screenTimeReceiptVisible ? 1 : 0)
                .animation(.easeOut(duration: 0.24).delay(0.40), value: screenTimeReceiptVisible)

            HStack(alignment: .top, spacing: 12) {
                Rectangle()
                    .fill(AppColors.accent)
                    .frame(width: 3, height: 52)
                    .clipShape(Capsule())

                Text("That’s not willpower. That’s a pattern.")
                    .font(.system(size: 19, weight: .heavy, design: .rounded))
                    .foregroundStyle(AppColors.textPrimary)
                    .lineSpacing(1)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(.top, 2)
            .padding(.bottom, -2)
            .opacity(screenTimeReceiptVisible ? 1 : 0)
            .offset(y: screenTimeReceiptVisible ? 0 : 8)
            .animation(.easeOut(duration: 0.30).delay(0.46), value: screenTimeReceiptVisible)

            HStack(spacing: 8) {
                Image(systemName: "lock.fill")
                    .font(.system(size: 11, weight: .bold))
                Text("Stays on your phone")
                    .font(.system(size: 11, weight: .heavy, design: .monospaced))
                    .tracking(0.9)
                    .textCase(.uppercase)
            }
            .foregroundStyle(AppColors.textTertiary)
            .opacity(screenTimeReceiptVisible ? 1 : 0)
            .animation(.easeOut(duration: 0.24).delay(0.58), value: screenTimeReceiptVisible)
        }
        .padding(15)
        .background(
            RoundedRectangle(cornerRadius: 24)
                .fill(
                    LinearGradient(
                        colors: [
                            AppColors.cardElevated.opacity(0.86),
                            AppColors.pageBg.opacity(0.78)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 24)
                        .stroke(AppColors.cardBorder.opacity(0.85), lineWidth: 1)
                )
                .overlay(alignment: .topTrailing) {
                    Circle()
                        .fill(AppColors.coral.opacity(0.22))
                        .frame(width: 176, height: 176)
                        .blur(radius: 48)
                        .offset(x: 58, y: 34)
                }
                .overlay(alignment: .bottomLeading) {
                    Circle()
                        .fill(AppColors.accent.opacity(0.18))
                        .frame(width: 188, height: 188)
                        .blur(radius: 54)
                        .offset(x: -68, y: 50)
                }
        )
    }

    private var screenTimeReceiptChart: some View {
        DeviceActivityReport(.screenTimeWeekly, filter: weeklyScreenTimeDeviceActivityFilter)
            .frame(height: 106)
    }

    private func screenTimeMetricBlock(eyebrow: String, value: String, suffix: String, tint: Color) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(eyebrow)
                .font(.system(size: 11, weight: .heavy, design: .monospaced))
                .tracking(1.0)
                .textCase(.uppercase)
                .foregroundStyle(AppColors.textTertiary)

            HStack(alignment: .firstTextBaseline, spacing: 4) {
                Text(value)
                    .font(.system(size: 74, weight: .black, design: .rounded))
                    .monospacedDigit()
                    .foregroundStyle(tint)
                    .minimumScaleFactor(0.62)
                    .lineLimit(1)

                Text(suffix)
                    .font(.system(size: 30, weight: .black, design: .rounded))
                    .foregroundStyle(AppColors.textTertiary)
            }
        }
    }

    private var screenTimePermissionPrimer: some View {
        VStack(alignment: .leading, spacing: 14) {
            screenTimePrivateReceiptPreview

            VStack(spacing: 0) {
                permissionReasonRow(
                    icon: "waveform.path.ecg",
                    title: "Real usage",
                    detail: "No guessing, no averages."
                )
                Divider().overlay(AppColors.cardBorder.opacity(0.72))
                permissionReasonRow(
                    icon: "hand.raised.fill",
                    title: "Pick your apps",
                    detail: "You choose what Memo blocks."
                )
                Divider().overlay(AppColors.cardBorder.opacity(0.72))
                permissionReasonRow(
                    icon: "lock.fill",
                    title: "Stays on device",
                    detail: "Private by Apple design."
                )
            }
            .padding(.horizontal, 2)
        }
    }

    private var screenTimePrivateReceiptPreview: some View {
        ZStack(alignment: .topTrailing) {
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [
                            AppColors.cardElevated.opacity(0.88),
                            AppColors.pageBg.opacity(0.72)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 24, style: .continuous)
                        .stroke(AppColors.cardBorder.opacity(0.78), lineWidth: 1)
                )
                .overlay(alignment: .topTrailing) {
                    Circle()
                        .fill(AppColors.electricViolet.opacity(0.18))
                        .frame(width: 140, height: 140)
                        .blur(radius: 40)
                        .offset(x: 44, y: -22)
                }
                .overlay(alignment: .bottomLeading) {
                    Circle()
                        .fill(AppColors.accent.opacity(0.16))
                        .frame(width: 150, height: 150)
                        .blur(radius: 44)
                        .offset(x: -46, y: 38)
                }

            VStack(alignment: .leading, spacing: 12) {
                HStack(spacing: 8) {
                    Image(systemName: "lock.shield.fill")
                        .font(.system(size: 15, weight: .bold))
                    Text("Private Screen Time receipt")
                        .font(.system(size: 14, weight: .heavy, design: .rounded))
                }
                .foregroundStyle(AppColors.accent)

                HStack(alignment: .bottom, spacing: 12) {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Real data")
                            .font(.system(size: 13, weight: .bold, design: .rounded))
                            .foregroundStyle(AppColors.textSecondary)

                        screenTimeMiniBars
                    }

                    Spacer(minLength: 8)

                    VStack(alignment: .trailing, spacing: 2) {
                        Text("on-device")
                            .font(.system(size: 10, weight: .heavy, design: .monospaced))
                            .tracking(0.8)
                            .textCase(.uppercase)
                            .foregroundStyle(AppColors.textTertiary)
                        Text("private")
                            .font(.system(size: 22, weight: .black, design: .rounded))
                            .foregroundStyle(AppColors.textPrimary)
                    }
                    .padding(.trailing, 4)
                }
            }
            .padding(16)

            Image("mascot-thinking")
                .renderingMode(.original)
                .resizable()
                .scaledToFit()
                .frame(width: 66, height: 66)
                .shadow(color: AppColors.electricViolet.opacity(0.30), radius: 16, y: 7)
                .offset(x: 7, y: 10)
                .accessibilityHidden(true)
        }
        .frame(height: 154)
    }

    private var screenTimeMiniBars: some View {
        HStack(alignment: .bottom, spacing: 6) {
            ForEach(Array([0.32, 0.66, 0.48, 0.86, 0.56].enumerated()), id: \.offset) { index, value in
                RoundedRectangle(cornerRadius: 4, style: .continuous)
                    .fill(
                        LinearGradient(
                            colors: [AppColors.electricViolet, AppColors.periwinkle],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
                    .frame(width: 14, height: 48 * value)
                    .overlay(alignment: .top) {
                        if index == 3 {
                            Capsule()
                                .fill(AppColors.coral)
                                .frame(width: 14, height: 4)
                        }
                    }
            }
        }
        .frame(height: 52, alignment: .bottom)
    }

    private func permissionReasonRow(icon: String, title: String, detail: String) -> some View {
        HStack(spacing: 14) {
            ZStack {
                Circle()
                    .fill(AppColors.accent.opacity(0.12))
                Image(systemName: icon)
                    .font(.system(size: 14, weight: .bold))
                    .foregroundStyle(AppColors.accent)
            }
            .frame(width: 34, height: 34)

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.system(size: 17, weight: .heavy, design: .rounded))
                    .foregroundStyle(AppColors.textPrimary)
                Text(detail)
                    .font(.system(size: 13, weight: .semibold, design: .rounded))
                    .foregroundStyle(AppColors.textSecondary)
                    .lineLimit(2)
            }

            Spacer(minLength: 0)
        }
        .padding(.vertical, 13)
    }

    private var connectedStamp: some View {
        HStack(spacing: 8) {
            Image(systemName: "checkmark.seal.fill")
                .font(.system(size: 18, weight: .bold))
            Text("Screen Time connected")
                .font(.system(size: 17, weight: .heavy, design: .rounded))
        }
        .foregroundStyle(AppColors.accent)
    }

    private var screenTimeDayStrip: some View {
        VStack(alignment: .leading, spacing: 8) {
            GeometryReader { proxy in
                ZStack(alignment: .leading) {
                    Capsule()
                        .fill(AppColors.cardBorder.opacity(0.55))

                    Capsule()
                        .fill(
                            LinearGradient(
                                colors: [AppColors.coralDeep, AppColors.coral],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .frame(width: proxy.size.width * screenTimeDayUsedFraction)
                        .shadow(color: AppColors.coral.opacity(0.32), radius: 14, y: 5)
                }
            }
            .frame(height: 13)

            HStack {
                Text("\(dailyScreenTimeLabel) used")
                Spacer()
                Text(screenTimeRemainingLabel)
            }
            .font(.system(size: 11, weight: .heavy, design: .monospaced))
            .tracking(0.5)
            .foregroundStyle(AppColors.textTertiary)
            .textCase(.uppercase)
        }
    }

    private func requestScreenTimeForOnboarding() {
        isRequestingScreenTimeAccess = true
        Task {
            await focusModeService.requestAuthorization()
            screenTimeAuthorized = (focusModeService.authorizationStatus == .approved)
            refreshCachedScreenTimeHours()
            isRequestingScreenTimeAccess = false
            if screenTimeAuthorized {
                useScreenTimeEstimate = false
                Analytics.onboardingStep(step: "screenTimeAccessApproved")
                startScreenTimeCacheRefreshLoop()
                animateScreenTimeReceipt()
            } else {
                useScreenTimeEstimate = true
                Analytics.onboardingStep(step: "screenTimeAccessDenied")
                showingScreenTimeEstimateSheet = true
            }
        }
    }

    private func animateScreenTimeReceipt() {
        screenTimeReceiptVisible = false
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
            guard screenTimeAuthorized else { return }
            screenTimeReceiptVisible = true
        }
    }

    private func screenTimeReasonRow(title: String, detail: String, isConfirmed: Bool = false) -> some View {
        HStack(alignment: .center, spacing: 16) {
            ZStack {
                if isConfirmed {
                    Image(systemName: "checkmark")
                        .font(.system(size: 12, weight: .heavy))
                        .foregroundStyle(AppColors.accent)
                } else {
                    Circle()
                        .fill(AppColors.accent)
                        .frame(width: 8, height: 8)
                        .shadow(color: AppColors.accent.opacity(0.55), radius: 8)
                }
            }
            .frame(width: 34, alignment: .leading)

            VStack(alignment: .leading, spacing: 3) {
                Text(title)
                    .font(.system(size: 17, weight: .bold, design: .rounded))
                    .foregroundStyle(AppColors.textPrimary)
                Text(detail)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(AppColors.textTertiary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer()
        }
        .padding(.vertical, 16)
    }

    // MARK: - Empathy Page

    private var empathyPage: some View {
        ZStack {
            EmpathySignalBackdrop(signalBroken: empathySignalBroken)
                .opacity(empathySceneVisible ? 1 : 0)
                .animation(.easeOut(duration: 0.55), value: empathySceneVisible)

            VStack(alignment: .leading, spacing: 0) {
                Spacer().frame(height: 28)

                EmpathyFeedWallScene(sceneVisible: empathySceneVisible, feedMuted: empathySignalBroken)
                    .frame(height: 306)
                    .padding(.top, 0)

                VStack(alignment: .leading, spacing: 8) {
                    VStack(alignment: .leading, spacing: -8) {
                        Text("Your brain")
                        Text("isn't broken.")
                    }
                    .font(.brand(size: 38, weight: .heavy))
                    .foregroundStyle(AppColors.textPrimary)
                    .lineSpacing(-4)
                    .fixedSize(horizontal: false, vertical: true)
                    .opacity(empathyCopyVisible ? 1 : 0)
                    .offset(y: empathyCopyVisible ? 0 : 10)

                    Text("It's been hijacked.")
                        .font(.brand(size: 38, weight: .heavy))
                        .foregroundStyle(AppColors.accent)
                        .lineLimit(1)
                        .minimumScaleFactor(0.78)
                        .fixedSize(horizontal: false, vertical: true)
                        .scaleEffect(empathySignalBroken ? 1 : 0.97, anchor: .leading)
                        .opacity(empathySignalBroken ? 1 : 0)

                    Text("You're not weak. You're outgunned. Memo helps you take the controls back.")
                        .font(.brand(size: 17, weight: .semibold))
                        .foregroundStyle(AppColors.textSecondary)
                        .lineSpacing(3)
                        .fixedSize(horizontal: false, vertical: true)
                        .padding(.top, 4)
                        .frame(maxWidth: 320, alignment: .leading)
                        .opacity(empathyCopyVisible ? 1 : 0)
                        .offset(y: empathyCopyVisible ? 0 : 8)
                }
                .padding(.horizontal, 28)

                Spacer()

                Button {
                    Analytics.onboardingStep(step: "empathy")
                    goToPage(5) // → goals
                } label: {
                    Text("Pick what I take back")
                        .gradientButton()
                }
                .accessibilityHint("Continues to the goals selection step")
                .padding(.horizontal, 32)
                .padding(.bottom, 18)
                .opacity(empathyCTAVisible ? 1 : 0)
                .offset(y: empathyCTAVisible ? 0 : 8)
            }
            .responsiveContent(maxWidth: 500)
            .frame(maxWidth: .infinity)
        }
        .preferredColorScheme(.dark)
        .onAppear {
            resetEmpathyAnimation()
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.08) {
                withAnimation(.easeOut(duration: 0.45)) { empathySceneVisible = true }
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.34) {
                withAnimation(.easeOut(duration: 0.38)) { empathyCopyVisible = true }
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.58) {
                withAnimation(.spring(response: 0.34, dampingFraction: 0.72)) { empathySignalBroken = true }
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.92) {
                withAnimation(.easeOut(duration: 0.32)) { empathyCTAVisible = true }
            }
        }
        .onDisappear(perform: resetEmpathyAnimation)
    }

    private func resetEmpathyAnimation() {
        empathySceneVisible = false
        empathySignalBroken = false
        empathyCopyVisible = false
        empathyCTAVisible = false
    }

    // MARK: - Age Page

    private var agePage: some View {
        VStack(alignment: .leading, spacing: 0) {
            Spacer().frame(height: 18)

            VStack(alignment: .leading, spacing: 11) {
                Text("LIFETIME MATH")
                    .font(.system(size: 11, weight: .heavy, design: .monospaced))
                    .tracking(1.6)
                    .foregroundStyle(AppColors.accent)

                Text("How many years\nare we defending?")
                    .font(.brand(size: 35, weight: .heavy))
                    .foregroundStyle(AppColors.textPrimary)
                    .lineSpacing(1)
                    .fixedSize(horizontal: false, vertical: true)

                Text("Memo uses your age to calculate what the feed costs by 60.")
                    .font(.brand(size: 16, weight: .medium))
                    .foregroundStyle(AppColors.textSecondary)
                    .lineSpacing(3)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .opacity(agePageAppeared ? 1 : 0)
            .offset(y: agePageAppeared ? 0 : 10)

            Spacer().frame(height: 38)

            VStack(alignment: .leading, spacing: 12) {
                AgeNumberRail(selectedAge: $selectedAge)
                    .opacity(agePageAppeared ? 1 : 0)
                    .scaleEffect(agePageAppeared ? 1 : 0.96)

                ageProjectionStrip
                    .opacity(agePageAppeared ? 1 : 0)
                    .offset(y: agePageAppeared ? 0 : 6)

                // Quiet inline privacy line — no border, no box, no coral. Trust whispers.
                HStack(spacing: 6) {
                    Image(systemName: "lock.fill")
                        .font(.system(size: 9, weight: .semibold))
                    Text("Stays on your phone · Never sold")
                        .font(.system(size: 10, weight: .semibold, design: .monospaced))
                        .tracking(0.4)
                        .lineLimit(1)
                        .minimumScaleFactor(0.85)
                }
                .foregroundStyle(AppColors.textTertiary.opacity(0.7))
                .frame(maxWidth: .infinity, alignment: .center)
                .opacity(agePageAppeared ? 1 : 0)
                .offset(y: agePageAppeared ? 0 : 6)
            }

            Spacer(minLength: 12)

            VStack(spacing: 0) {
                Button {
                    Analytics.onboardingStep(step: "age")
                    goToPage(9) // → screenTimeAccess
                } label: {
                    Text("Calculate my cost")
                        .gradientButton()
                }
                .accessibilityHint("Uses your age to personalize the next onboarding step")
            }
            .frame(maxWidth: .infinity)
        }
        .padding(.horizontal, 28)
        .padding(.bottom, 8)
        .responsiveContent(maxWidth: 500)
        .frame(maxWidth: .infinity)
        .preferredColorScheme(.dark)
        .onAppear {
            selectedAge = selectedAge == 0 ? 25 : selectedAge
            withAnimation(.easeOut(duration: 0.38)) {
                agePageAppeared = true
            }
        }
        .onDisappear {
            agePageAppeared = false
        }
    }

    private var ageProjectionStrip: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .firstTextBaseline, spacing: 8) {
                Text("\(yearsUntilSixty)")
                    .font(.system(size: 28, weight: .black, design: .monospaced))
                    .monospacedDigit()
                    .foregroundStyle(AppColors.accent)

                Text(yearsUntilSixty == 1 ? "year left in the projection" : "years left in the projection")
                    .font(.system(size: 13, weight: .heavy, design: .rounded))
                    .foregroundStyle(AppColors.textPrimary.opacity(0.76))
                    .lineLimit(1)
                    .minimumScaleFactor(0.78)
            }

            VStack(spacing: 8) {
                GeometryReader { proxy in
                    let trackWidth = proxy.size.width
                    let tickCount = 5

                    ZStack(alignment: .leading) {
                        Capsule()
                            .fill(AppColors.cardBorder.opacity(0.56))
                            .frame(height: 16)

                        Capsule()
                            .fill(
                                LinearGradient(
                                    colors: [
                                        AppColors.accent,
                                        AppColors.violet.opacity(0.92),
                                        AppColors.coral.opacity(0.94)
                                    ],
                                    startPoint: .leading,
                                    endPoint: .trailing
                                )
                            )
                            .frame(height: 16)
                            .overlay(alignment: .top) {
                                Capsule()
                                    .fill(AppColors.textPrimary.opacity(0.18))
                                    .frame(height: 5)
                                    .padding(.horizontal, 6)
                                    .padding(.top, 3)
                            }
                            .shadow(color: AppColors.accent.opacity(0.28), radius: 14, y: 6)

                        ForEach(1..<tickCount, id: \.self) { index in
                            Capsule()
                                .fill(AppColors.pageBg.opacity(0.58))
                                .frame(width: 2, height: 18)
                                .offset(x: trackWidth * CGFloat(index) / CGFloat(tickCount))
                        }

                        Circle()
                            .fill(AppColors.accent)
                            .frame(width: 18, height: 18)
                            .overlay {
                                Circle()
                                    .stroke(AppColors.textPrimary.opacity(0.82), lineWidth: 2)
                            }
                            .shadow(color: AppColors.accent.opacity(0.65), radius: 12)
                            .offset(x: -1)

                        Circle()
                            .fill(AppColors.coral)
                            .frame(width: 18, height: 18)
                            .overlay {
                                Circle()
                                    .stroke(AppColors.textPrimary.opacity(0.66), lineWidth: 2)
                            }
                            .shadow(color: AppColors.coral.opacity(0.46), radius: 12)
                            .offset(x: trackWidth - 17)
                    }
                }
                .frame(height: 24)

                HStack(alignment: .firstTextBaseline) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("TODAY")
                            .foregroundStyle(AppColors.accent)
                        Text("\(max(selectedAge, 18))")
                            .font(.system(size: 13, weight: .black, design: .monospaced))
                            .monospacedDigit()
                    }

                    Spacer()

                    HStack(alignment: .firstTextBaseline, spacing: 6) {
                        Text("AGE 60")
                            .foregroundStyle(AppColors.coral.opacity(0.92))
                        Text("projection")
                            .font(.system(size: 10, weight: .heavy, design: .monospaced))
                            .tracking(1.0)
                            .foregroundStyle(AppColors.textTertiary.opacity(0.58))
                    }
                    .lineLimit(1)
                    .minimumScaleFactor(0.82)
                }
                .font(.system(size: 10, weight: .heavy, design: .monospaced))
                .tracking(1.1)
                .foregroundStyle(AppColors.textTertiary.opacity(0.76))
            }
        }
        .padding(.horizontal, 18)
        .padding(.vertical, 13)
        .background {
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(AppColors.cardElevated.opacity(0.72))
                .overlay {
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .stroke(AppColors.cardBorder.opacity(0.8), lineWidth: 1)
                }
        }
    }

    // MARK: - Quick Assessment Page

    private var quickAssessmentPage: some View {
        ZStack(alignment: .topTrailing) {
            QuickAssessmentView(
                backgroundColor: $quickAssessmentBgColor,
                isInFullscreenPhase: $quickAssessmentIsFullscreen
            ) { result in
                assessmentResult = result
                Analytics.onboardingStep(step: "quickAssessment")
                // Present dramatic reveal as a full-screen cover so it escapes the TabView.
                // Cover only fires from a legitimate onComplete — swiping the TabView won't trigger it.
                presentedCover = .brainAgeReveal
            }

            #if DEBUG
            if !quickAssessmentIsFullscreen {
            Button {
                Analytics.onboardingStep(step: "debugSkipBrainAgeTest")
                assessmentResult = nil
                quickAssessmentBgColor = AppColors.pageBg
                goToPage(11) // → planReveal
            } label: {
                Text("Skip test")
                    .font(.system(size: 12, weight: .heavy, design: .rounded))
                    .foregroundStyle(AppColors.accent)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .background(
                        Capsule()
                            .fill(AppColors.cardElevated.opacity(0.92))
                            .overlay(
                                Capsule()
                                    .stroke(AppColors.accent.opacity(0.32), lineWidth: 1)
                            )
                    )
            }
            .buttonStyle(.plain)
            .padding(.top, 56)
            .padding(.trailing, 24)
            }
            #endif
        }
    }

    // MARK: - Plan Reveal Page (was Personal Solution)
    //
    // Critical: this page presents the paywall on CTA. The user has now seen the
    // plan they're paying for. Paywall dismiss → focusMode setup.

    private var planRevealPage: some View {
        OnboardingPersonalSolutionView(
            userGoals: selectedGoals,
            brainAge: assessmentResult?.brainAge,
            userAge: selectedAge,
            dailyScreenTimeHours: effectiveDailyScreenTimeHours,
            projectedScreenTimeHours: projectedScreenTimeHours,
            projectionIsEstimate: projectionIsEstimate,
            receiptCount: receiptCount,
            protectedPriority: selectedProtectedPriority,
            dangerWindow: selectedDangerWindow,
            onContinue: {
                Analytics.onboardingStep(step: "planReveal")
                goToPage(12) // → comparison
            }
        )
    }

    // MARK: - Notification Priming Page

    private var notificationPrimingPage: some View {
        OnboardingNotificationPrimingView { granted in
            notificationsEnabled = granted
            goToPage(16) // → commitment
        }
    }

    // MARK: - Industry Scare Page (NEW — $57B engineering spend)

    private var industryScarePage: some View {
        FocusOnboardIndustryScare {
            Analytics.onboardingStep(step: "industryScare")
            goToPage(4) // → empathy
        }
    }

    // MARK: - Pain Cards Page (NEW)

    private var painCardsPage: some View {
        OnboardingPainCardsView { count in
            receiptCount = count
            goToPage(3) // → industryScare
        }
    }

    // MARK: - Comparison Page (NEW)

    private var comparisonPage: some View {
        OnboardingComparisonView(
            pickupCount: 287,
            dailyHours: effectiveDailyScreenTimeHours,
            brainAge: assessmentResult?.brainAge,
            onContinue: {
                goToPage(13) // → differentiation
            }
        )
    }

    // MARK: - Differentiation Page (NEW)

    private var differentiationPage: some View {
        OnboardingDifferentiationView {
            Analytics.onboardingStep(step: "differentiation")
            presentedCover = .paywall
        }
    }

    // MARK: - Commitment Page

    private var commitmentPage: some View {
        VStack(alignment: .leading, spacing: 0) {
            Spacer().frame(height: 46)

            Text("FINAL STEP")
                .font(.system(size: 13, weight: .heavy, design: .monospaced))
                .tracking(2.4)
                .foregroundStyle(AppColors.accent)
                .padding(.bottom, 12)

            VStack(alignment: .leading, spacing: 0) {
                Text("Sign the pact.")
                    .font(.brand(size: 35, weight: .heavy))
                    .foregroundStyle(.primary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.84)

                Text("Make the feed wait.")
                    .font(.brand(size: 32, weight: .heavy))
                    .foregroundStyle(AppColors.accent)
                    .lineLimit(1)
                    .minimumScaleFactor(0.78)
            }
            .padding(.bottom, 12)

            Text("Hold the seal and your name signs the plan. Training comes before scrolling.")
                .font(.brand(size: 16, weight: .medium))
                .foregroundStyle(.secondary)
                .lineSpacing(4)
                .lineLimit(2)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.bottom, 18)

            CommitmentPactSheet(
                name: enteredName.trimmingCharacters(in: .whitespacesAndNewlines),
                isSigned: commitmentCompleted,
                signatureProgress: holdProgress,
                line1Visible: commitmentBullet1Visible,
                line2Visible: commitmentBullet2Visible,
                line3Visible: commitmentBullet3Visible,
                line4Visible: commitmentBullet4Visible,
                onHoldStart: {
                    guard !commitmentCompleted else { return }
                    if holdTimer == nil {
                        startHoldTimer()
                    }
                },
                onHoldEnd: {
                    if !commitmentCompleted {
                        cancelHoldTimer()
                    }
                }
            )
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

            VStack(spacing: 6) {
                if !commitmentCompleted {
                    Text("Hold the seal to sign")
                        .font(.brand(size: 22, weight: .heavy))
                        .foregroundStyle(holdProgress > 0.05 ? AppColors.accent : Color.primary)
                        .animation(.easeOut(duration: 0.15), value: holdProgress > 0.05)

                    Text("The feed doesn't get a vote.")
                        .font(.brand(size: 15, weight: .semibold))
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 32)
                } else {
                    Text("Signed.")
                        .font(.brand(size: 22, weight: .heavy))
                        .foregroundStyle(AppColors.accent)
                        .transition(.opacity.combined(with: .scale))
                }
            }
            .frame(maxWidth: .infinity)
            .padding(.bottom, 22)

            HStack(spacing: 6) {
                Image(systemName: "lock.fill")
                    .font(.caption2)
                Text("No ads. No data sold. Memo stays on your side.")
                    .font(.brand(size: 13, weight: .medium))
            }
            .foregroundStyle(.secondary)
            .frame(maxWidth: .infinity)
        }
        .padding(.horizontal, 28)
        .padding(.bottom, 8)
        .responsiveContent(maxWidth: 500)
        .frame(maxWidth: .infinity)
    }

    private struct CommitmentPactSheet: View {
        let name: String
        let isSigned: Bool
        let signatureProgress: CGFloat
        let line1Visible: Bool
        let line2Visible: Bool
        let line3Visible: Bool
        let line4Visible: Bool
        let onHoldStart: () -> Void
        let onHoldEnd: () -> Void

        private var pactTitle: String {
            name.isEmpty ? "Memo pact" : "\(name)'s Memo pact"
        }

        private var signatureName: String {
            name.isEmpty ? "Memo trainee" : name
        }

        var body: some View {
            ZStack(alignment: .bottomTrailing) {
                VStack(alignment: .leading, spacing: 0) {
                    HStack(alignment: .firstTextBaseline) {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(pactTitle)
                                .font(.brand(size: 24, weight: .heavy))
                                .foregroundStyle(.primary)

                            Text("Training first. Feed second.")
                                .font(.brand(size: 14, weight: .semibold))
                                .foregroundStyle(.secondary)
                        }

                        Spacer()

                        Text(isSigned ? "SIGNED" : "READY")
                            .font(.system(size: 12, weight: .heavy, design: .monospaced))
                            .tracking(1.6)
                            .foregroundStyle(isSigned ? AppColors.coral : AppColors.accent)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 6)
                            .background {
                                Capsule()
                                    .stroke((isSigned ? AppColors.coral : AppColors.accent).opacity(0.6), lineWidth: 1)
                            }
                    }
                    .padding(.bottom, 18)

                    PactDivider()

                    VStack(alignment: .leading, spacing: 0) {
                        CommitmentPactLine(isVisible: line1Visible, text: "Train before I scroll")
                        CommitmentPactLine(isVisible: line2Visible, text: "Make unlocks cost reps")
                        CommitmentPactLine(isVisible: line3Visible, text: "Bounce the apps draining me")
                        CommitmentPactLine(isVisible: line4Visible, text: "Don't let Big Social colonize my attention")
                    }

                    SignatureLine(
                        name: signatureName,
                        progress: signatureProgress,
                        isSigned: isSigned
                    )
                    .padding(.top, 10)
                }
                .padding(18)
                .padding(.bottom, 10)
                .background {
                    RoundedRectangle(cornerRadius: 24, style: .continuous)
                        .fill(AppColors.cardElevated)
                        .overlay(alignment: .top) {
                            RoundedRectangle(cornerRadius: 24, style: .continuous)
                                .stroke(AppColors.accent.opacity(0.24), lineWidth: 1.2)
                        }
                        .overlay {
                            RoundedRectangle(cornerRadius: 24, style: .continuous)
                                .stroke(AppColors.cardBorder.opacity(0.9), lineWidth: 1)
                        }
                        .shadow(color: AppColors.accent.opacity(0.12), radius: 28, y: 14)
                }

                if isSigned {
                    Text("SIGNED")
                        .font(.system(size: 34, weight: .black, design: .monospaced))
                        .tracking(2.5)
                        .foregroundStyle(AppColors.coral)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 8)
                        .overlay {
                            RoundedRectangle(cornerRadius: 10)
                                .stroke(AppColors.coral, lineWidth: 2)
                        }
                        .rotationEffect(.degrees(-9))
                        .offset(x: -16, y: -70)
                        .transition(.scale(scale: 1.2).combined(with: .opacity))
                }

                Image("mascot-celebrate")
                    .resizable()
                    .scaledToFit()
                    .frame(width: 86, height: 86)
                    .shadow(color: AppColors.accent.opacity(0.25), radius: 18, y: 8)
                    .offset(x: -92, y: 42)
                    .accessibilityHidden(true)

                CommitmentSeal(progress: signatureProgress, isSigned: isSigned)
                    .offset(x: 6, y: 22)
                    .gesture(
                        DragGesture(minimumDistance: 0)
                            .onChanged { _ in
                                guard !isSigned else { return }
                                onHoldStart()
                            }
                            .onEnded { _ in
                                guard !isSigned else { return }
                                onHoldEnd()
                            }
                    )
            }
            .padding(.trailing, 8)
            .padding(.bottom, 42)
        }
    }

    private struct SignatureLine: View {
        let name: String
        let progress: CGFloat
        let isSigned: Bool

        var body: some View {
            VStack(alignment: .leading, spacing: 8) {
                Text("signature")
                    .font(.system(size: 11, weight: .heavy, design: .monospaced))
                    .tracking(1.8)
                    .foregroundStyle(.tertiary)

                GeometryReader { proxy in
                    let width = proxy.size.width
                    let clamped = min(max(progress, 0), 1)
                    let revealWidth = max(1, width * clamped)

                    ZStack(alignment: .leading) {
                        Rectangle()
                            .fill(AppColors.cardBorder.opacity(0.85))
                            .frame(height: 1)
                            .offset(y: 18)

                        Text(name)
                            .font(.custom("Snell Roundhand", size: 38).weight(.bold))
                            .lineLimit(1)
                            .minimumScaleFactor(0.58)
                            .foregroundStyle(AppColors.accent)
                            .shadow(color: AppColors.accent.opacity(0.35), radius: 10)
                            .mask(alignment: .leading) {
                                Rectangle()
                                    .frame(width: isSigned ? width : revealWidth)
                            }

                        Circle()
                            .fill(AppColors.accent)
                            .frame(width: 9, height: 9)
                            .shadow(color: AppColors.accent.opacity(0.65), radius: 8)
                            .offset(x: max(0, revealWidth - 5), y: 18)
                            .opacity(isSigned || clamped <= 0.02 ? 0 : 1)
                    }
                }
                .frame(height: 52)
            }
            .accessibilityElement(children: .ignore)
            .accessibilityLabel("Signature \(name)")
        }
    }

    private struct CommitmentPactLine: View {
        let isVisible: Bool
        let text: String
        var showDivider = true

        var body: some View {
            VStack(spacing: 0) {
                HStack(alignment: .top, spacing: 12) {
                    Image(systemName: "checkmark")
                        .font(.system(size: 13, weight: .heavy))
                        .foregroundStyle(AppColors.accent)
                        .frame(width: 20, height: 20)
                        .background {
                            Circle()
                                .fill(AppColors.accent.opacity(0.16))
                        }
                        .opacity(isVisible ? 1 : 0.18)

                    Group {
                        if isVisible {
                            TypewriterText(fullText: text, speed: 0.025)
                                .transition(.opacity)
                        } else {
                            Text(text)
                                .redacted(reason: .placeholder)
                                .opacity(0.18)
                        }
                    }
                    .font(.brand(size: 15, weight: .bold))
                    .foregroundStyle(.primary)
                    .lineLimit(2)
                    .fixedSize(horizontal: false, vertical: true)
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
                .padding(.vertical, 11)

                if showDivider {
                    PactDivider()
                }
            }
        }
    }

    private struct PactDivider: View {
        var body: some View {
            Rectangle()
                .fill(AppColors.cardBorder.opacity(0.75))
                .frame(height: 1)
        }
    }

    private struct CommitmentSeal: View {
        let progress: CGFloat
        let isSigned: Bool

        var body: some View {
            let sealWidth: CGFloat = 118
            let sealHeight: CGFloat = 96
            let sealRotation: Angle = .degrees(-8)

            ZStack {
                ZStack {
                    SealBlobShape()
                        .fill(AppColors.accent.opacity(0.10 + 0.52 * progress))

                    SealBlobShape()
                        .stroke(AppColors.accent.opacity(isSigned ? 0.85 : 0.34 + 0.46 * progress), lineWidth: 2)

                    SealBlobShape()
                        .trim(from: 0, to: min(progress, 1))
                        .stroke(AppColors.accent, style: StrokeStyle(lineWidth: 6, lineCap: .round, lineJoin: .round))
                        .shadow(color: AppColors.accent.opacity(0.55 * progress), radius: 14 * progress)
                        .animation(.easeOut(duration: 0.08), value: progress)
                }
                .frame(width: sealWidth, height: sealHeight)
                .rotationEffect(sealRotation)
                .shadow(color: AppColors.accent.opacity(0.22 + 0.34 * progress), radius: 18 + 8 * progress, y: 8)
                .overlay {
                    if isSigned {
                        SealBlobShape()
                            .stroke(AppColors.coral.opacity(0.75), lineWidth: 2)
                            .frame(width: sealWidth - 12, height: sealHeight - 12)
                            .rotationEffect(sealRotation)
                            .transition(.opacity)
                    }
                }

                VStack(spacing: 2) {
                    if isSigned {
                        Image(systemName: "checkmark")
                            .font(.system(size: 25, weight: .heavy))
                            .foregroundStyle(.white)
                            .transition(.scale.combined(with: .opacity))
                    } else {
                        Text("HOLD")
                            .font(.system(size: 11, weight: .heavy, design: .monospaced))
                            .tracking(1.5)
                            .foregroundStyle(AppColors.textTertiary)

                        Text("SIGN")
                            .font(.system(size: 21, weight: .black, design: .monospaced))
                            .tracking(1.4)
                            .foregroundStyle(progress > 0.08 ? .white : AppColors.accent)
                    }
                }
                .rotationEffect(.degrees(-7))
                .scaleEffect(isSigned ? 1.08 : 1)
                .animation(.spring(response: 0.35, dampingFraction: 0.65), value: isSigned)

            }
            .frame(width: 136, height: 118)
            .contentShape(Rectangle())
        }
    }

    private struct SealBlobShape: Shape {
        func path(in rect: CGRect) -> Path {
            let w = rect.width
            let h = rect.height

            var path = Path()
            path.move(to: CGPoint(x: 0.18 * w, y: 0.16 * h))
            path.addCurve(
                to: CGPoint(x: 0.62 * w, y: 0.08 * h),
                control1: CGPoint(x: 0.30 * w, y: -0.01 * h),
                control2: CGPoint(x: 0.48 * w, y: 0.02 * h)
            )
            path.addCurve(
                to: CGPoint(x: 0.92 * w, y: 0.32 * h),
                control1: CGPoint(x: 0.78 * w, y: 0.00 * h),
                control2: CGPoint(x: 0.91 * w, y: 0.15 * h)
            )
            path.addCurve(
                to: CGPoint(x: 0.84 * w, y: 0.76 * h),
                control1: CGPoint(x: 1.02 * w, y: 0.47 * h),
                control2: CGPoint(x: 0.96 * w, y: 0.66 * h)
            )
            path.addCurve(
                to: CGPoint(x: 0.45 * w, y: 0.94 * h),
                control1: CGPoint(x: 0.75 * w, y: 0.96 * h),
                control2: CGPoint(x: 0.58 * w, y: 0.98 * h)
            )
            path.addCurve(
                to: CGPoint(x: 0.10 * w, y: 0.78 * h),
                control1: CGPoint(x: 0.30 * w, y: 1.04 * h),
                control2: CGPoint(x: 0.12 * w, y: 0.96 * h)
            )
            path.addCurve(
                to: CGPoint(x: 0.18 * w, y: 0.16 * h),
                control1: CGPoint(x: -0.03 * w, y: 0.60 * h),
                control2: CGPoint(x: 0.00 * w, y: 0.32 * h)
            )
            path.closeSubpath()
            return path
        }
    }

    private func startHoldTimer() {
        guard !onboardingCompletionQueued else { return }
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
        holdTimer = Timer.scheduledTimer(withTimeInterval: 0.05, repeats: true) { _ in
            Task { @MainActor in
                guard !onboardingCompletionQueued else {
                    cancelHoldTimer()
                    return
                }
                holdProgress += 0.05 / 3.0 // 3 seconds total
                if holdProgress.truncatingRemainder(dividingBy: 0.1) < 0.02 {
                    UIImpactFeedbackGenerator(style: .light).impactOccurred()
                }
                if holdProgress >= 1.0 {
                    holdProgress = 1.0
                    onboardingCompletionQueued = true
                    cancelHoldTimer()
                    UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                    withAnimation(.spring(response: 0.4, dampingFraction: 0.6)) {
                        commitmentCompleted = true
                    }
                    Analytics.onboardingStep(step: "commitment")
                    DispatchQueue.main.asyncAfter(deadline: .now() + 1.15) {
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
                goToPage(15) // → notificationPriming
            })

            // "Set up later" skip button
            Button {
                Analytics.onboardingStep(step: "focusModeSkipped")
                Analytics.focusSetupSkipped()
                goToPage(15) // → notificationPriming
            } label: {
                Text("Set up later")
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(.secondary)
            }
            .padding(.bottom, 8)
        }
    }

    private func continueButton(_ title: String = "Continue", action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(title)
                .gradientButton()
        }
        .accessibilityHint("Continues to the next step")
        .padding(.horizontal, 32)
    }

    private func completeOnboarding() {
        guard onboardingCompletionQueued else { return }
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
        let sharedDefaults = UserDefaults(suiteName: "group.com.memori.shared")
        sharedDefaults?.set(effectiveDailyScreenTimeHours, forKey: "onboarding_projection_daily_hours")
        sharedDefaults?.set(projectionIsEstimate, forKey: "onboarding_projection_is_estimate")
        sharedDefaults?.set(projectedScreenTimeHours, forKey: "onboarding_projected_screen_time_hours")
        sharedDefaults?.set(selectedProtectedPriority?.rawValue, forKey: "onboarding_protected_priority")
        sharedDefaults?.set(selectedDangerWindow?.rawValue, forKey: "onboarding_danger_window")

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

struct AgeNumberRail: View {
    @Binding var selectedAge: Int
    @State private var dragStartAge: Int?
    @State private var dragOffset: CGFloat = 0
    /// Per-tick compensation that accumulates as selectedAge changes during drag.
    /// dragOffset = rawTranslation + committedOffset. Without this separate state,
    /// reassigning dragOffset from rawTranslation every frame wiped the
    /// per-tick compensation and caused 60pt visual jumps at each age boundary.
    @State private var committedOffset: CGFloat = 0

    private let range = 18...99
    private let tickWidth: CGFloat = 60

    private var isDragging: Bool { dragStartAge != nil }

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            // Top row: lab-coat Memo on the LEFT, big age number on the RIGHT.
            HStack(alignment: .center, spacing: 0) {
                Image("mascot-lab-coat")
                    .resizable()
                    .scaledToFit()
                    .frame(width: 200, height: 200)
                    .rotationEffect(.degrees(-4))
                    .shadow(color: AppColors.accent.opacity(0.22), radius: 22, y: 10)

                Spacer(minLength: 8)

                Text("\(selectedAge)")
                    .font(.system(size: 100, weight: .heavy, design: .monospaced))
                    .foregroundStyle(AppColors.accent)
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
                    .contentTransition(.numericText(value: Double(selectedAge)))
                    .shadow(color: AppColors.accent.opacity(0.28), radius: 22, y: 10)
                    .animation(.spring(response: 0.3, dampingFraction: 0.85), value: selectedAge)
            }
            .padding(.trailing, 12)

            // Manual rail: stable full range, continuous offset that tracks finger
            // 1:1 during drag, snaps to selectedAge on release. Compensates dragOffset
            // when selectedAge ticks so the visual position stays continuous (no
            // jumping mid-drag). Skips animation during drag — animations queueing
            // per-tick was the original jitter source. DragGesture (vs ScrollView)
            // because the parent TabView's `scrollDisabled` blocks DragGesture but
            // not ScrollView's internal pan gesture.
            GeometryReader { geo in
                let centerX = geo.size.width / 2
                let baseOffset = centerX - (CGFloat(selectedAge - range.lowerBound) * tickWidth + tickWidth / 2)

                HStack(spacing: 0) {
                    ForEach(Array(range), id: \.self) { age in
                        railTick(age: age)
                    }
                }
                .frame(width: tickWidth * CGFloat(range.count), alignment: .leading)
                .offset(x: baseOffset + dragOffset)
                .animation(isDragging ? nil : .spring(response: 0.32, dampingFraction: 0.86), value: selectedAge)
                .animation(isDragging ? nil : .spring(response: 0.28, dampingFraction: 0.85), value: dragOffset)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .contentShape(Rectangle())
                .gesture(railDragGesture)
            }
            .frame(height: 56)
            .clipped()
            .overlay(alignment: .bottom) {
                // Fixed center indicator — numbers scroll under it
                Capsule()
                    .fill(AppColors.accent)
                    .frame(width: 24, height: 4)
                    .offset(y: -2)
                    .allowsHitTesting(false)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Age")
        .accessibilityValue("\(selectedAge)")
        .accessibilityAdjustableAction { direction in
            switch direction {
            case .increment:
                selectedAge = min(range.upperBound, selectedAge + 1)
            case .decrement:
                selectedAge = max(range.lowerBound, selectedAge - 1)
            @unknown default:
                break
            }
        }
    }

    private var railDragGesture: some Gesture {
        DragGesture(minimumDistance: 4)
            .onChanged { value in
                if dragStartAge == nil {
                    dragStartAge = selectedAge
                    committedOffset = 0
                }
                let raw = value.translation.width

                // Compute target age from RAW translation relative to drag start —
                // not from selectedAge, since selectedAge moves as we tick.
                let stepsFromStart = (-raw / tickWidth).rounded()
                let candidate = clampedAge((dragStartAge ?? selectedAge) + Int(stepsFromStart))

                if candidate != selectedAge {
                    UIImpactFeedbackGenerator(style: .light).impactOccurred()
                    let ageDiff = candidate - selectedAge
                    selectedAge = candidate
                    // Accumulate compensation: when age decreases by 1, baseOffset
                    // jumps right by tickWidth. Counter that with -tickWidth here
                    // so the rail's visual position stays continuous with the finger.
                    committedOffset += CGFloat(ageDiff) * tickWidth
                }

                // Always derived from raw translation + accumulated compensation —
                // never assigned from raw alone (that was the bug).
                dragOffset = raw + committedOffset
            }
            .onEnded { _ in
                UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                dragStartAge = nil
                dragOffset = 0
                committedOffset = 0
            }
    }

    @ViewBuilder
    private func railTick(age: Int) -> some View {
        let isCentered = age == selectedAge
        Text("\(age)")
            .font(.system(
                size: isCentered ? 20 : 16,
                weight: isCentered ? .heavy : .semibold,
                design: .monospaced
            ))
            .foregroundStyle(
                isCentered ? AppColors.accent : AppColors.textTertiary.opacity(0.55)
            )
            .frame(width: tickWidth, height: 50)
    }

    private func clampedAge(_ age: Int) -> Int {
        min(range.upperBound, max(range.lowerBound, age))
    }
}

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

struct EmpathySignalBackdrop: View {
    let signalBroken: Bool

    var body: some View {
        ZStack(alignment: .topTrailing) {
            RadialGradient(
                colors: [
                    AppColors.accent.opacity(signalBroken ? 0.24 : 0.14),
                    AppColors.violet.opacity(0.10),
                    .clear
                ],
                center: .topTrailing,
                startRadius: 24,
                endRadius: 330
            )
            .frame(maxWidth: .infinity, maxHeight: 430, alignment: .topTrailing)
            .blur(radius: 10)
            .offset(y: 42)

            Rectangle()
                .fill(
                    LinearGradient(
                        colors: [
                            AppColors.pageBg.opacity(0.0),
                            AppColors.pageBg.opacity(0.64),
                            AppColors.pageBg
                        ],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
                .frame(height: 360)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottom)
                .accessibilityHidden(true)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topTrailing)
        .allowsHitTesting(false)
    }
}

struct EmpathyFeedWallScene: View {
    let sceneVisible: Bool
    let feedMuted: Bool

    private let tiles: [(x: CGFloat, y: CGFloat, w: CGFloat, h: CGFloat, color: Color, asset: String, rotation: Double)] = [
        (184, 8, 66, 78, AppColors.coral, "logo-tiktok", -7),
        (270, 26, 58, 70, AppColors.rose, "logo-instagram", 5),
        (222, 102, 80, 64, AppColors.violet, "logo-youtube", -4),
        (318, 112, 66, 78, AppColors.coral, "logo-snapchat", 7),
        (174, 190, 68, 76, AppColors.amber, "logo-x", 6),
        (268, 202, 84, 70, AppColors.coral, "logo-reddit", -5),
        (356, 214, 62, 74, AppColors.rose, "logo-tiktok", 4)
    ]

    var body: some View {
        GeometryReader { proxy in
            let width = proxy.size.width
            let height = proxy.size.height

            ZStack(alignment: .topTrailing) {
                LinearGradient(
                    colors: [
                        AppColors.pageBg.opacity(0.0),
                        AppColors.coral.opacity(0.10),
                        AppColors.coral.opacity(0.22)
                    ],
                    startPoint: .leading,
                    endPoint: .trailing
                )
                .frame(width: width * 0.72, height: height * 1.10)
                .blur(radius: 16)
                .offset(x: 18, y: -4)
                .opacity(sceneVisible ? 1 : 0)

                ZStack {
                    ForEach(Array(tiles.enumerated()), id: \.offset) { index, tile in
                        FeedWallTile(
                            width: tile.w,
                            height: tile.h,
                            color: tile.color,
                            assetName: tile.asset,
                            dimmed: feedMuted
                        )
                        .rotationEffect(.degrees(tile.rotation))
                        .offset(
                            x: tile.x + (feedMuted ? 18 : 0),
                            y: tile.y + (feedMuted ? CGFloat(index % 2 == 0 ? -8 : 6) : 0)
                        )
                        .opacity(sceneVisible ? (feedMuted ? 0.54 : 0.82) : 0)
                        .blur(radius: feedMuted ? 1.1 : 0.4)
                        .animation(.easeOut(duration: 0.46).delay(Double(index) * 0.035), value: sceneVisible)
                        .animation(.easeInOut(duration: 0.55).delay(Double(index) * 0.025), value: feedMuted)
                    }
                }
                .frame(width: width, height: height, alignment: .topLeading)
                .mask(
                    LinearGradient(
                        colors: [
                            .clear,
                            AppColors.pageBg,
                            AppColors.pageBg,
                            AppColors.pageBg.opacity(0.15)
                        ],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                )
                .rotation3DEffect(.degrees(-18), axis: (x: 0, y: 1, z: 0), perspective: 0.72)
                .offset(x: feedMuted ? 22 : 0, y: sceneVisible ? 0 : 8)

                RadialGradient(
                    colors: [
                        AppColors.accent.opacity(feedMuted ? 0.36 : 0.26),
                        AppColors.accent.opacity(0.10),
                        .clear
                    ],
                    center: .center,
                    startRadius: 8,
                    endRadius: 126
                )
                .frame(width: 248, height: 248)
                .position(x: 126, y: 204)
                .blur(radius: 4)
                .opacity(sceneVisible ? 1 : 0)

                Image("mascot-cool")
                    .resizable()
                    .scaledToFit()
                    .frame(width: 156, height: 156)
                    .rotationEffect(.degrees(-3))
                    .shadow(color: AppColors.accent.opacity(0.55), radius: 24, y: 12)
                    .shadow(color: AppColors.pageBg.opacity(0.95), radius: 14)
                    .position(x: 126, y: 206)
                    .opacity(sceneVisible ? 1 : 0)
                    .scaleEffect(sceneVisible ? 1 : 0.92)
                    .animation(.spring(response: 0.44, dampingFraction: 0.78), value: sceneVisible)
                    .accessibilityHidden(true)

                LinearGradient(
                    colors: [
                        AppColors.pageBg.opacity(0.0),
                        AppColors.pageBg.opacity(0.52),
                        AppColors.pageBg
                    ],
                    startPoint: .top,
                    endPoint: .bottom
                )
                .frame(height: 130)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottom)
            }
        }
        .allowsHitTesting(false)
    }
}

struct FeedWallTile: View {
    let width: CGFloat
    let height: CGFloat
    let color: Color
    let assetName: String
    let dimmed: Bool

    var body: some View {
        Image(assetName)
            .resizable()
            .scaledToFit()
            .frame(width: width, height: height)
            .opacity(dimmed ? 0.34 : 0.78)
            .saturation(dimmed ? 0.65 : 1)
            .blur(radius: dimmed ? 1.2 : 0.35)
            .shadow(color: color.opacity(dimmed ? 0.18 : 0.42), radius: 22, y: 10)
            .shadow(color: AppColors.pageBg.opacity(0.88), radius: 10)
    }
}

// MARK: - Welcome Bouncer Hero (the bouncer scene composition)
//
// Memo holds the line on the left; six real social media app logos
// cascade in from the right edge, layered like a fan. Composition is
// asymmetric on purpose. After the entrance, everything is static.

private struct WelcomeBouncerHero: View {
    let appsVisible: [Bool]
    let appsLeaning: Bool
    let appsPushed: [Bool]
    let memoVisible: Bool
    let memoLeaning: Bool
    let memoShoving: Bool
    let memoEnlarged: Bool

    private struct AppSlot {
        let asset: String
        let size: CGFloat
        let rotation: Double
        let xOffset: CGFloat
        let opacity: Double
        let blur: CGFloat
    }

    private let slots: [AppSlot] = [
        AppSlot(asset: "logo-tiktok",    size: 64, rotation:  -8, xOffset:  30, opacity: 1.00, blur: 0.0),
        AppSlot(asset: "logo-instagram", size: 60, rotation:   6, xOffset:  62, opacity: 0.92, blur: 0.0),
        AppSlot(asset: "logo-snapchat",  size: 56, rotation: -12, xOffset:  94, opacity: 0.85, blur: 0.0),
        AppSlot(asset: "logo-youtube",   size: 54, rotation:   9, xOffset: 122, opacity: 0.75, blur: 0.5),
        AppSlot(asset: "logo-reddit",    size: 50, rotation:  -6, xOffset: 148, opacity: 0.62, blur: 1.0),
        AppSlot(asset: "logo-x",         size: 48, rotation:  14, xOffset: 170, opacity: 0.45, blur: 2.0),
    ]

    /// Memo's horizontal offset from his resting x:
    ///  - shoving: +30 (lurching into the apps)
    ///  - leaning: +6 (pressing into them)
    ///  - else: 0
    private var memoXOffset: CGFloat {
        if memoShoving { return 30 }
        if memoLeaning { return 6 }
        return 0
    }

    /// Memo's scale composes lean (compressed 0.97), enlarge (victory 1.2),
    /// or default 1.0. Lean and enlarge never co-occur in the timeline.
    private var memoScale: CGFloat {
        guard memoVisible else { return 0.92 }
        if memoEnlarged { return 1.2 }
        if memoLeaning { return 0.97 }
        return 1.0
    }

    var body: some View {
        ZStack(alignment: .center) {
            // App pile cascading from right-of-center; tension lean toward Memo, then shoved off-screen
            ZStack {
                ForEach(Array(slots.enumerated().reversed()), id: \.offset) { index, slot in
                    let visible = index < appsVisible.count ? appsVisible[index] : false
                    let pushed = index < appsPushed.count ? appsPushed[index] : false

                    let enterOffset: CGFloat = visible ? 0 : 120
                    // Lean toward Memo: shift left, dim, slightly tilt harder. Pushed overrides lean.
                    let leanOffset: CGFloat = (appsLeaning && !pushed) ? -8 : 0
                    let leanRotationMultiplier: Double = (appsLeaning && !pushed) ? 1.4 : 1.0
                    let leanOpacityMultiplier: Double = (appsLeaning && !pushed) ? 0.85 : 1.0

                    let pushOffset: CGFloat = pushed ? 320 : 0
                    let pushRotation: Double = pushed ? 30 : 0
                    let pushOpacityMultiplier: Double = pushed ? 0 : 1

                    WelcomeAppLogo(
                        assetName: slot.asset,
                        size: slot.size,
                        baseRotation: slot.rotation * leanRotationMultiplier + pushRotation,
                        targetOpacity: slot.opacity * leanOpacityMultiplier * pushOpacityMultiplier,
                        blur: slot.blur,
                        visible: visible
                    )
                    .offset(x: slot.xOffset + enterOffset + leanOffset + pushOffset)
                }
            }
            .frame(maxWidth: .infinity, alignment: .center)

            // Memo (cool / sunglasses pose) holding the line on the left
            HStack {
                Image("mascot-cool")
                    .renderingMode(.original)
                    .resizable()
                    .scaledToFit()
                    .frame(height: 200)
                    .shadow(
                        color: OB.accent.opacity(memoEnlarged ? 0.45 : 0.32),
                        radius: memoEnlarged ? 36 : 28,
                        y: 12
                    )
                    .scaleEffect(memoScale)
                    .offset(x: memoXOffset)
                    .opacity(memoVisible ? 1 : 0)

                Spacer()
            }
            .padding(.leading, 8)
        }
        .frame(height: 240)
    }
}

private struct WelcomeAppLogo: View {
    let assetName: String
    let size: CGFloat
    let baseRotation: Double
    let targetOpacity: Double
    let blur: CGFloat
    let visible: Bool

    var body: some View {
        Image(assetName)
            .resizable()
            .scaledToFill()
            .frame(width: size, height: size)
            .clipShape(RoundedRectangle(cornerRadius: size * 0.22))
            .shadow(color: .black.opacity(0.4), radius: 8, y: 4)
            .blur(radius: blur)
            .rotationEffect(.degrees(baseRotation))
            .opacity(visible ? targetOpacity : 0)
    }
}

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

// MARK: - Screen Time Estimate Sheet
//
// Replaces the old standalone "rough estimate" page. Surfaces 4 hour buckets
// the user can pick from when they decline Screen Time access. Shorter than
// the old full page, keeps the funnel moving.

struct ScreenTimeEstimateSheet: View {
    @Binding var selection: Double
    let onConfirm: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Spacer().frame(height: 24)

            VStack(alignment: .leading, spacing: 8) {
                Text("Roughly how much\ndoes the feed get you?")
                    .font(.system(size: 26, weight: .heavy, design: .rounded))
                    .foregroundStyle(AppColors.textPrimary)
                    .lineSpacing(1)

                Text("We'll mark the projection as estimated. You can hand Memo Screen Time later.")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(AppColors.textSecondary)
            }
            .padding(.horizontal, 24)

            Spacer().frame(height: 24)

            VStack(spacing: 0) {
                Divider().overlay(AppColors.cardBorder)
                ForEach([2.0, 4.0, 6.0, 8.0], id: \.self) { hours in
                    ScreenTimeEstimateRow(
                        hours: hours,
                        isSelected: selection == hours,
                        action: {
                            withAnimation(.spring(response: 0.3, dampingFraction: 0.78)) {
                                selection = hours
                            }
                        }
                    )
                    Divider().overlay(AppColors.cardBorder)
                }
            }
            .padding(.horizontal, 24)

            Spacer()

            Button(action: onConfirm) {
                Text("Use \(selection >= 8 ? "8h+" : "\(Int(selection))h")")
                    .gradientButton()
            }
            .padding(.horizontal, 28)
            .padding(.bottom, 18)
        }
        .background(AppColors.pageBg.ignoresSafeArea())
    }
}

// MARK: - Screen Time Estimate Row

struct ScreenTimeEstimateRow: View {
    let hours: Double
    let isSelected: Bool
    let action: () -> Void

    private var title: String {
        hours >= 8 ? "8h+" : "\(Int(hours))h"
    }

    private var subtitle: String {
        switch hours {
        case ..<3: return "Light scroll, still worth defending"
        case ..<5: return "Average phone pace"
        case ..<7: return "Heavy feed territory"
        default: return "The algorithm is clocked in"
        }
    }

    var body: some View {
        Button(action: action) {
            HStack(spacing: 16) {
                Text(title)
                    .font(.system(size: 23, weight: .black, design: .rounded))
                    .monospacedDigit()
                    .foregroundStyle(isSelected ? AppColors.accent : AppColors.textSecondary)
                    .frame(width: 56, alignment: .leading)

                VStack(alignment: .leading, spacing: 3) {
                    Text(subtitle)
                        .font(.system(size: 17, weight: .bold, design: .rounded))
                        .foregroundStyle(AppColors.textPrimary)

                    Text("\(projectedAnnualHours.formatted()) hours a year")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(AppColors.textTertiary)
                }

                Spacer()

                Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                    .font(.system(size: 24, weight: .bold))
                    .foregroundStyle(isSelected ? AppColors.accent : AppColors.cardBorder)
            }
            .padding(.vertical, 16)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    private var projectedAnnualHours: Int {
        Int((hours * 365).rounded())
    }
}

// MARK: - Personal Question Page

struct OnboardingPersonalQuestionPage<Option: Identifiable & Equatable>: View {
    let title: String
    let subtitle: String
    let options: [Option]
    let selection: Option?
    let titleForOption: KeyPath<Option, String>
    let symbolForOption: KeyPath<Option, String>
    let onSelect: (Option) -> Void
    let ctaTitle: String
    let onContinue: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Spacer().frame(height: 18)

            VStack(alignment: .leading, spacing: 11) {
                Text(title)
                    .font(.brand(size: 36, weight: .heavy))
                    .foregroundStyle(AppColors.textPrimary)
                    .lineSpacing(1)
                    .fixedSize(horizontal: false, vertical: true)

                Text(subtitle)
                    .font(.brand(size: 16, weight: .medium))
                    .foregroundStyle(AppColors.textSecondary)
                    .lineSpacing(3)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(.horizontal, 28)

            Spacer().frame(height: 28)

            VStack(spacing: 0) {
                Divider().overlay(AppColors.cardBorder)

                ForEach(options) { option in
                    personalQuestionRow(option)

                    Divider()
                        .overlay(AppColors.cardBorder.opacity(selection == option ? 0.9 : 0.7))
                }
            }
            .padding(.horizontal, 24)

            Spacer(minLength: 16)

            Button {
                guard selection != nil else { return }
                onContinue()
            } label: {
                Text(ctaTitle)
                    .gradientButton()
            }
            .disabled(selection == nil)
            .opacity(selection == nil ? 0.42 : 1)
            .padding(.horizontal, 28)
            .padding(.bottom, 12)
        }
        .responsiveContent(maxWidth: 500)
        .frame(maxWidth: .infinity)
        .preferredColorScheme(.dark)
    }

    private func personalQuestionRow(_ option: Option) -> some View {
        let selected = selection == option

        return Button {
            UISelectionFeedbackGenerator().selectionChanged()
            withAnimation(.spring(response: 0.28, dampingFraction: 0.78)) {
                onSelect(option)
            }
        } label: {
            HStack(spacing: 14) {
                ZStack {
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .fill(selected ? AppColors.accent.opacity(0.18) : AppColors.cardElevated.opacity(0.72))
                        .frame(width: 42, height: 42)
                        .overlay(
                            RoundedRectangle(cornerRadius: 10, style: .continuous)
                                .stroke(selected ? AppColors.accent.opacity(0.45) : AppColors.cardBorder, lineWidth: 1)
                        )

                    Image(systemName: option[keyPath: symbolForOption])
                        .font(.system(size: 20, weight: .bold))
                        .symbolRenderingMode(.hierarchical)
                        .foregroundStyle(selected ? AppColors.accent : AppColors.textSecondary)
                        .frame(width: 24, height: 24)
                        .accessibilityHidden(true)
                }

                Text(option[keyPath: titleForOption])
                    .font(.system(size: 17, weight: .bold, design: .rounded))
                    .foregroundStyle(AppColors.textPrimary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .lineLimit(1)
                    .minimumScaleFactor(0.86)

                GoalSelectionMark(isSelected: selected)
            }
            .padding(.vertical, 11)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel("\(option[keyPath: titleForOption])\(selected ? ", selected" : "")")
    }
}

// MARK: - Goal Card

struct GoalCard: View {
    let goal: UserFocusGoal
    let index: Int
    let isSelected: Bool
    let action: () -> Void

    private var missionTitle: String {
        switch goal {
        case .attentionShot:    return "Uncolonized attention"
        case .screenTimeFrying: return "Your hours back"
        case .doomscrolling:    return "Sleep that survives"
        case .loseFocus:        return "Outscore the feed"
        case .forgetInstantly:  return "Memory that sticks"
        case .getSharper:       return "Younger Brain Score"
        }
    }

    private var missionSubtitle: String {
        switch goal {
        case .attentionShot:    return "Keep Big Social out of your focus"
        case .screenTimeFrying: return "Take time back from the feed"
        case .doomscrolling:    return "Stop the 2am scroll before it starts"
        case .loseFocus:        return "Climb while your apps wait"
        case .forgetInstantly:  return "Remember what you read and opened"
        case .getSharper:       return "Push your Brain Score up"
        }
    }

    private var missionNumber: String {
        String(format: "%02d", index + 1)
    }

    var body: some View {
        Button {
            UISelectionFeedbackGenerator().selectionChanged()
            action()
        } label: {
            ZStack(alignment: .leading) {
                HStack(spacing: 16) {
                    Rectangle()
                        .fill(isSelected ? AppColors.accent : Color.clear)
                        .frame(width: 3, height: 44)
                        .shadow(color: AppColors.accent.opacity(isSelected ? 0.45 : 0), radius: 8)

                    Text(missionNumber)
                        .font(.system(size: 14, weight: .heavy, design: .rounded))
                        .tracking(0.8)
                        .foregroundStyle(isSelected ? AppColors.accent : AppColors.textTertiary.opacity(0.74))
                        .frame(width: 36, alignment: .leading)

                    VStack(alignment: .leading, spacing: 3) {
                        Text(missionTitle)
                            .font(.system(size: 17, weight: .bold, design: .rounded))
                            .foregroundStyle(isSelected ? AppColors.textPrimary : AppColors.textPrimary.opacity(0.92))
                            .lineLimit(1)
                            .multilineTextAlignment(.leading)

                        Text(missionSubtitle)
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundStyle(AppColors.textTertiary)
                            .lineLimit(1)
                            .multilineTextAlignment(.leading)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)

                    GoalSelectionMark(isSelected: isSelected)
                }
            }
            .padding(.vertical, 9)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel("\(missionTitle), \(missionSubtitle)\(isSelected ? ", selected" : "")")
    }
}

private struct MemoLookoutHeader: View {
    var body: some View {
        Image("mascot-lookout")
            .renderingMode(.original)
            .resizable()
            .aspectRatio(contentMode: .fit)
            .frame(width: 265, height: 118, alignment: .leading)
            .offset(x: -20)
            .shadow(color: AppColors.accent.opacity(0.28), radius: 18, y: 8)
            .accessibilityHidden(true)
            .frame(maxWidth: .infinity, alignment: .leading)
    }
}

// Stack of social-media app tiles in the top-right.
// Visual story: Memo (lookout) is watching the actual apps farming you.
//
// Each tile prefers a real logo asset (e.g. "logo-tiktok") if present in
// Assets.xcassets. Falls back to a brand-colored tile with an SF Symbol
// approximation so the page never looks broken if assets are missing.
private struct FeedHeistBackdrop: View {
    private struct FeedApp {
        let logoAsset: String          // Image asset name; renders if present
        let fallbackSymbol: String     // SF Symbol used until logoAsset is added
        let fallbackBg: AnyShapeStyle  // Brand color for the fallback tile
        let fallbackFg: Color
        let rotation: Double
        let xOffset: CGFloat
    }

    private let apps: [FeedApp] = [
        FeedApp(
            logoAsset: "logo-tiktok",
            fallbackSymbol: "music.note",
            fallbackBg: AnyShapeStyle(Color.black),
            fallbackFg: .white,
            rotation: -6,
            xOffset: 6
        ),
        FeedApp(
            logoAsset: "logo-youtube",
            fallbackSymbol: "play.rectangle.fill",
            fallbackBg: AnyShapeStyle(Color(red: 1.0, green: 0.0, blue: 0.2)),
            fallbackFg: .white,
            rotation: 5,
            xOffset: -8
        ),
        FeedApp(
            logoAsset: "logo-instagram",
            fallbackSymbol: "camera.fill",
            fallbackBg: AnyShapeStyle(LinearGradient(
                colors: [
                    Color(red: 0.98, green: 0.42, blue: 0.35),
                    Color(red: 0.72, green: 0.34, blue: 0.96)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )),
            fallbackFg: .white,
            rotation: -3,
            xOffset: 8
        ),
        FeedApp(
            logoAsset: "logo-snapchat",
            fallbackSymbol: "bubble.left.fill",
            fallbackBg: AnyShapeStyle(Color(red: 1.0, green: 0.99, blue: 0.0)),
            fallbackFg: .black,
            rotation: 4,
            xOffset: -6
        ),
        FeedApp(
            logoAsset: "logo-x",
            fallbackSymbol: "xmark",
            fallbackBg: AnyShapeStyle(Color.black),
            fallbackFg: .white,
            rotation: -4,
            xOffset: 2
        ),
        FeedApp(
            logoAsset: "logo-reddit",
            fallbackSymbol: "bubble.left.and.bubble.right.fill",
            fallbackBg: AnyShapeStyle(Color(red: 1.0, green: 0.27, blue: 0.0)),
            fallbackFg: .white,
            rotation: 3,
            xOffset: -4
        )
    ]

    var body: some View {
        VStack(spacing: 8) {
            ForEach(Array(apps.enumerated()), id: \.offset) { _, app in
                appTile(app)
            }
        }
        .rotation3DEffect(.degrees(-18), axis: (x: 0, y: 1, z: 0), perspective: 0.55)
        .rotationEffect(.degrees(3))
        .frame(width: 132, height: 320)
        .mask(
            RadialGradient(
                colors: [.black, .black.opacity(0.7), .clear],
                center: .topTrailing,
                startRadius: 60,
                endRadius: 240
            )
        )
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }

    @ViewBuilder
    private func appTile(_ app: FeedApp) -> some View {
        Group {
            if UIImage(named: app.logoAsset) != nil {
                Image(app.logoAsset)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(width: 44, height: 44)
                    .clipShape(RoundedRectangle(cornerRadius: 11, style: .continuous))
            } else {
                RoundedRectangle(cornerRadius: 11, style: .continuous)
                    .fill(app.fallbackBg)
                    .frame(width: 44, height: 44)
                    .overlay(
                        Image(systemName: app.fallbackSymbol)
                            .font(.system(size: 18, weight: .bold))
                            .foregroundStyle(app.fallbackFg)
                    )
            }
        }
        .overlay(
            RoundedRectangle(cornerRadius: 11, style: .continuous)
                .stroke(Color.white.opacity(0.08), lineWidth: 1)
        )
        .shadow(color: .black.opacity(0.5), radius: 6, y: 4)
        .rotationEffect(.degrees(app.rotation))
        .offset(x: app.xOffset)
    }
}

private struct GoalSelectionMark: View {
    let isSelected: Bool

    var body: some View {
        ZStack {
            if isSelected {
                Image(systemName: "checkmark")
                    .font(.system(size: 21, weight: .heavy, design: .rounded))
                    .foregroundStyle(AppColors.accent)
                    .shadow(color: AppColors.accent.opacity(0.55), radius: 8)
                    .transition(.scale.combined(with: .opacity))
            } else {
                Circle()
                    .stroke(AppColors.cardBorder.opacity(0.92), lineWidth: 2)
                    .frame(width: 24, height: 24)
            }
        }
        .frame(width: 30, height: 30)
    }
}

// MARK: - Welcome Demo Bezel
//
// Phone-in-phone bezel showing the auto-looping product demo. Materializes
// after the existing WelcomeBouncerHero animation completes — metaphor (Memo
// pushing apps) hands off to receipts (real recording of the block-train-
// unlock loop). Asset: `onboarding_demo.mp4` in the main bundle. The caller
// guards transition to this bezel with a Bundle lookup, so shipping without
// the asset cleanly falls back to the bouncer-only welcome.

private struct WelcomeDemoBezel: View {
    /// Drives play/pause so the AVPlayer doesn't burn cycles when the welcome
    /// page is off-screen (still in the navigation stack but not visible).
    let isActive: Bool

    @State private var isMuted = true

    private static let videoName = "onboarding_demo"
    private static let videoExt = "mp4"

    var body: some View {
        GeometryReader { geo in
            // PNG aspect = 450 / 920 ≈ 0.489. Use the asset's exact ratio so
            // the screen cutout matches up with the video underneath.
            let bezelWidth: CGFloat = min(geo.size.width * 0.55, 220)
            let bezelHeight: CGFloat = bezelWidth * (920.0 / 450.0)
            // The PNG's chrome is roughly 4% of width on each side. Inset the
            // video by that much so it sits flush inside the screen cutout
            // and doesn't bleed under the bezel.
            let screenInset: CGFloat = bezelWidth * 0.04
            let screenCornerRadius: CGFloat = bezelWidth * 0.12

            HStack {
                Spacer(minLength: 0)
                bezelFrame(screenInset: screenInset, screenCornerRadius: screenCornerRadius)
                    .frame(width: bezelWidth, height: bezelHeight)
                    .rotation3DEffect(
                        .degrees(10),
                        axis: (x: 0.0, y: 1.0, z: 0.0),
                        anchor: .center,
                        anchorZ: 0,
                        perspective: 0.45
                    )
                    .shadow(color: .black.opacity(0.75), radius: 28, x: 10, y: 18)
                    .shadow(color: Color(red: 0.408, green: 0.565, blue: 0.996).opacity(0.18), radius: 36, x: 0, y: 0)
                    .offset(y: -36)
                Spacer(minLength: 0)
            }
            .frame(width: geo.size.width, height: geo.size.height, alignment: .center)
        }
    }

    private func bezelFrame(screenInset: CGFloat, screenCornerRadius: CGFloat) -> some View {
        ZStack {
            // Layer 1: video plays in the screen cutout area, clipped to
            // match the PNG's screen corner radius.
            LoopingVideoPlayer(
                videoName: Self.videoName,
                videoExt: Self.videoExt,
                isPlaying: isActive,
                isMuted: isMuted
            )
            .clipShape(RoundedRectangle(cornerRadius: screenCornerRadius, style: .continuous))
            .padding(screenInset)

            // Layer 2: real iPhone 17 Pro PNG with transparent screen. Sits
            // on top of the video — its transparent screen lets the video
            // show through, and the PNG provides photoreal chrome edges,
            // baked highlights, and Dynamic Island detail.
            // Loaded via UIImage explicitly because SwiftUI's `Image(_ name:)`
            // sometimes fails to resolve loose bundle PNGs that aren't part
            // of an Asset Catalog.
            if let frame = UIImage(named: "iphone17pro") {
                Image(uiImage: frame)
                    .resizable()
                    .scaledToFit()
                    .allowsHitTesting(false)
            }
        }
    }
}

// Plays the demo video on a seamless loop using AVPlayerLooper. Pauses when
// `isPlaying` flips to false so backgrounded onboarding pages don't keep the
// decoder running.
private struct LoopingVideoPlayer: UIViewRepresentable {
    let videoName: String
    let videoExt: String
    let isPlaying: Bool
    let isMuted: Bool

    final class Coordinator {
        var player: AVQueuePlayer?
        var looper: AVPlayerLooper?
    }

    func makeCoordinator() -> Coordinator { Coordinator() }

    func makeUIView(context: Context) -> PlayerHostView {
        let view = PlayerHostView()
        view.backgroundColor = .black

        guard let url = Bundle.main.url(forResource: videoName, withExtension: videoExt) else {
            return view
        }

        let item = AVPlayerItem(url: url)
        let queuePlayer = AVQueuePlayer(playerItem: item)
        queuePlayer.isMuted = isMuted
        queuePlayer.actionAtItemEnd = .advance

        let looper = AVPlayerLooper(player: queuePlayer, templateItem: item)

        context.coordinator.player = queuePlayer
        context.coordinator.looper = looper

        view.playerLayer.player = queuePlayer
        view.playerLayer.videoGravity = .resizeAspectFill

        if isPlaying {
            queuePlayer.play()
        }
        return view
    }

    func updateUIView(_ uiView: PlayerHostView, context: Context) {
        guard let player = context.coordinator.player else { return }
        player.isMuted = isMuted
        if isPlaying {
            if player.timeControlStatus != .playing {
                player.play()
            }
        } else {
            if player.timeControlStatus != .paused {
                player.pause()
            }
        }
    }

    static func dismantleUIView(_ uiView: PlayerHostView, coordinator: Coordinator) {
        coordinator.player?.pause()
        coordinator.looper = nil
        coordinator.player = nil
        uiView.playerLayer.player = nil
    }

    final class PlayerHostView: UIView {
        override class var layerClass: AnyClass { AVPlayerLayer.self }
        var playerLayer: AVPlayerLayer { layer as! AVPlayerLayer }
    }
}

#Preview("Contract Page") {
    OnboardingView(startPage: 16, previewName: "Dylan") {}
        .environment(FocusModeService())
        .modelContainer(for: [
            User.self,
            Exercise.self,
            DailySession.self,
            BrainScoreResult.self,
            Achievement.self
        ], inMemory: true)
}
