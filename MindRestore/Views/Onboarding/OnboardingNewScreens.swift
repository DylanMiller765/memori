import SwiftUI
import UIKit
import UserNotifications

// MARK: - Processing Moment
//
// Sits between the assessment (page 5) and the brain age reveal.
// Auto-advances after a brief delay. Makes the result feel earned.

struct OnboardingProcessingView: View {
    let onComplete: () -> Void

    @State private var progress: Double = 0
    @State private var statusIndex: Int = 0
    @State private var dots: String = ""

    private let statuses = [
        "Analyzing your responses",
        "Comparing to 47,000+ players",
        "Calibrating your Brain Age"
    ]

    var body: some View {
        VStack(spacing: 32) {
            Spacer()

            // Animated brain icon with pulse
            ZStack {
                Circle()
                    .fill(AppColors.accent.opacity(0.12))
                    .frame(width: 140, height: 140)
                    .scaleEffect(1 + progress * 0.15)
                    .opacity(1 - progress * 0.3)

                Circle()
                    .fill(AppColors.accent.opacity(0.18))
                    .frame(width: 100, height: 100)

                Image(systemName: "brain.head.profile")
                    .font(.system(size: 44, weight: .semibold))
                    .foregroundStyle(AppColors.accent)
                    .symbolEffect(.pulse, options: .repeating)
            }

            VStack(spacing: 14) {
                Text(statuses[statusIndex] + dots)
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundStyle(.primary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 32)
                    .animation(.easeInOut(duration: 0.2), value: statusIndex)

                ProgressView(value: progress)
                    .tint(AppColors.accent)
                    .padding(.horizontal, 60)
            }

            Spacer()

            HStack(spacing: 6) {
                Image(systemName: "sparkles")
                    .font(.caption2)
                Text("Personalizing your results")
                    .font(.caption)
            }
            .foregroundStyle(.tertiary)
            .padding(.bottom, 24)
        }
        .responsiveContent(maxWidth: 500)
        .frame(maxWidth: .infinity)
        .onAppear {
            startAnimation()
        }
    }

    private func startAnimation() {
        // Smooth progress bar over ~2.5 seconds
        withAnimation(.easeInOut(duration: 2.5)) {
            progress = 1.0
        }

        // Cycle through status messages
        for (i, _) in statuses.enumerated() {
            DispatchQueue.main.asyncAfter(deadline: .now() + (Double(i) * 0.85)) {
                withAnimation { statusIndex = i }
            }
        }

        // Animate dots
        Timer.scheduledTimer(withTimeInterval: 0.4, repeats: true) { timer in
            DispatchQueue.main.async {
                if dots.count < 3 {
                    dots += "."
                } else {
                    dots = ""
                }
                if progress >= 1.0 {
                    timer.invalidate()
                }
            }
        }

        // Auto-advance
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.6) {
            onComplete()
        }
    }
}

// MARK: - Personal Solution + Testimonial
//
// Mirrors back the user's goals with concrete app solutions.
// Embeds a real App Store testimonial as social proof.
// Sits after the brain age reveal.

struct OnboardingPersonalSolutionView: View {
    let userGoals: Set<UserFocusGoal>
    let brainAge: Int?
    let userAge: Int
    let onContinue: () -> Void

    @State private var cardsAppeared: [Bool] = [false, false, false]
    @State private var headlineAppeared = false
    @State private var testimonialAppeared = false

    /// Top 3 solutions to mirror back. Falls back to a sensible default trio
    /// if the user skipped goal selection (so the page still has substance).
    private var solutions: [UserFocusGoal] {
        let priorityOrder: [UserFocusGoal] = [
            .screenTimeFrying, .doomscrolling, .attentionShot,
            .loseFocus, .forgetInstantly, .getSharper
        ]
        let ordered = priorityOrder.filter { userGoals.contains($0) }
        if ordered.isEmpty {
            return [.screenTimeFrying, .doomscrolling, .attentionShot]
        }
        return Array(ordered.prefix(3))
    }

    private func solutionTitle(_ goal: UserFocusGoal) -> String {
        switch goal {
        case .screenTimeFrying: return "200+ apps stay locked"
        case .doomscrolling:    return "Earn back screen time"
        case .attentionShot:    return "Rebuild your focus"
        case .loseFocus:        return "Restore concentration"
        case .forgetInstantly:  return "Sharpen recall in days"
        case .getSharper:       return "Track your Brain Age"
        }
    }

    private func solutionDetail(_ goal: UserFocusGoal) -> String {
        switch goal {
        case .screenTimeFrying: return "Until you train. No willpower required."
        case .doomscrolling:    return "Play brain games to unlock minutes."
        case .attentionShot:    return "10 games. 5 minutes a day. That's it."
        case .loseFocus:        return "Working memory exercises rebuild it."
        case .forgetInstantly:  return "Memory drills you'll actually feel work."
        case .getSharper:       return "Daily score shows your cognitive age."
        }
    }

    private func goalColor(_ goal: UserFocusGoal) -> Color {
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
        VStack(spacing: 0) {
            Spacer().frame(height: 32)

            VStack(alignment: .leading, spacing: 8) {
                Text("Your plan")
                    .font(.system(size: 32, weight: .bold))
                    .kerning(-0.6)
                Text(brainAgeSubtitle)
                    .font(.system(size: 15))
                    .foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 24)
            .opacity(headlineAppeared ? 1 : 0)
            .offset(y: headlineAppeared ? 0 : 8)

            Spacer().frame(height: 24)

            VStack(spacing: 12) {
                ForEach(Array(solutions.enumerated()), id: \.offset) { index, goal in
                    solutionRow(goal: goal, index: index)
                }
            }
            .padding(.horizontal, 24)

            Spacer().frame(height: 20)

            testimonialCard
                .padding(.horizontal, 24)
                .opacity(testimonialAppeared ? 1 : 0)
                .offset(y: testimonialAppeared ? 0 : 12)

            Spacer(minLength: 16)

            Button(action: onContinue) {
                Text("Continue")
                    .gradientButton()
            }
            .padding(.horizontal, 32)
            .padding(.bottom, 24)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .onAppear {
            withAnimation(.easeOut(duration: 0.4)) { headlineAppeared = true }
            for i in 0..<solutions.count {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.25 + Double(i) * 0.15) {
                    withAnimation(.spring(response: 0.5, dampingFraction: 0.8)) {
                        if i < cardsAppeared.count { cardsAppeared[i] = true }
                    }
                }
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.25 + Double(solutions.count) * 0.15) {
                withAnimation(.easeOut(duration: 0.4)) { testimonialAppeared = true }
            }
        }
    }

    private var brainAgeSubtitle: String {
        if let brainAge, userAge > 0 {
            let diff = brainAge - userAge
            if diff > 0 {
                return "Built to drop your brain age \(diff) year\(diff == 1 ? "" : "s")."
            } else if diff < 0 {
                return "Built to keep you sharper than your real age."
            } else {
                return "Built to push your brain age below \(userAge)."
            }
        }
        return "Built around what you told us."
    }

    private func solutionRow(goal: UserFocusGoal, index: Int) -> some View {
        let appeared = index < cardsAppeared.count ? cardsAppeared[index] : true
        let color = goalColor(goal)
        return HStack(spacing: 14) {
            ZStack {
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(color)
                Image(systemName: goal.icon)
                    .font(.system(size: 22, weight: .bold))
                    .foregroundStyle(.white)
            }
            .frame(width: 52, height: 52)

            VStack(alignment: .leading, spacing: 3) {
                Text(solutionTitle(goal))
                    .font(.system(size: 16, weight: .bold))
                    .foregroundStyle(.primary)
                Text(solutionDetail(goal))
                    .font(.system(size: 13))
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Spacer(minLength: 0)
        }
        .padding(.vertical, 10)
        .padding(.horizontal, 14)
        .background(AppColors.cardSurface, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(AppColors.cardBorder, lineWidth: 1)
        )
        .opacity(appeared ? 1 : 0)
        .offset(y: appeared ? 0 : 12)
    }

    private var testimonialCard: some View {
        HStack(alignment: .top, spacing: 12) {
            VStack(alignment: .leading, spacing: 6) {
                HStack(spacing: 3) {
                    ForEach(0..<5) { _ in
                        Image(systemName: "star.fill")
                            .font(.system(size: 11))
                            .foregroundStyle(AppColors.amber)
                    }
                    Spacer()
                    Text("App Store")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(.tertiary)
                }
                Text("\u{201C}Apparently my brain age is 43. I'm 21, training daily now.\u{201D}")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(.primary)
                    .fixedSize(horizontal: false, vertical: true)
                Text("— sjvdheisjsbsis")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(.secondary)
            }
        }
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(AppColors.amber.opacity(0.07))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(AppColors.amber.opacity(0.22), lineWidth: 1)
        )
    }
}

// MARK: - Notification Priming
//
// Sells the value of notifications BEFORE the system prompt fires.
// Cold prompts convert at ~40%; primed prompts at 70-80%+.

struct OnboardingNotificationPrimingView: View {
    let onResult: (Bool) -> Void

    @State private var headlineAppeared = false
    @State private var bulletsAppeared = false
    @State private var requesting = false
    @State private var permissionTask: Task<Void, Never>?
    @State private var showTimeoutError = false
    /// Once the user denies notifications, iOS won't re-prompt — we have to
    /// deep-link to Settings instead.
    @State private var previouslyDenied = false

    var body: some View {
        VStack(spacing: 24) {
            Spacer().frame(height: 40)

            // Bell icon with notification dot
            ZStack {
                Circle()
                    .fill(AppColors.coral.opacity(0.12))
                    .frame(width: 120, height: 120)

                Image(systemName: "bell.badge.fill")
                    .font(.system(size: 56, weight: .semibold))
                    .foregroundStyle(AppColors.coral)
                    .symbolRenderingMode(.hierarchical)
            }

            VStack(spacing: 10) {
                Text("Stay on track,\neven when life gets busy")
                    .font(.system(size: 26, weight: .bold, design: .rounded))
                    .multilineTextAlignment(.center)
                    .opacity(headlineAppeared ? 1 : 0)
                    .offset(y: headlineAppeared ? 0 : 12)

                Text("We'll send a quiet nudge when it matters.")
                    .font(.system(size: 14))
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .opacity(headlineAppeared ? 1 : 0)
            }

            VStack(spacing: 14) {
                primingBullet(icon: "flame.fill", color: AppColors.coral, text: "Save your streak before it breaks")
                primingBullet(icon: "trophy.fill", color: AppColors.amber, text: "Heads-up before leaderboards reset")
                primingBullet(icon: "brain.head.profile", color: AppColors.accent, text: "A daily reminder to keep training")
            }
            .padding(.horizontal, 32)
            .padding(.top, 8)
            .opacity(bulletsAppeared ? 1 : 0)
            .offset(y: bulletsAppeared ? 0 : 16)

            Spacer()

            HStack(spacing: 6) {
                Image(systemName: "lock.fill")
                    .font(.caption2)
                Text("No spam. We won't notify more than once a day.")
                    .font(.caption)
            }
            .foregroundStyle(.tertiary)

            VStack(spacing: 10) {
                if previouslyDenied {
                    Text("Permission was denied earlier — open Settings to enable.")
                        .font(.caption.weight(.medium))
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                        .transition(.opacity)
                } else if showTimeoutError {
                    Text("Couldn't request permission. Tap to retry.")
                        .font(.caption.weight(.medium))
                        .foregroundStyle(AppColors.coral)
                        .multilineTextAlignment(.center)
                        .transition(.opacity)
                }

                Button {
                    if previouslyDenied {
                        if let url = URL(string: UIApplication.openSettingsURLString) {
                            UIApplication.shared.open(url)
                        }
                    } else {
                        requestPermission()
                    }
                } label: {
                    Group {
                        if requesting {
                            ProgressView()
                                .tint(.white)
                        } else {
                            Text(buttonTitle)
                                .font(.headline.weight(.bold))
                        }
                    }
                    .gradientButton()
                }
                .disabled(requesting)

                Button {
                    Analytics.onboardingStep(step: "notificationsSkipped")
                    permissionTask?.cancel()
                    onResult(false)
                } label: {
                    Text("Not now")
                        .font(.subheadline.weight(.medium))
                        .foregroundStyle(.secondary)
                        .padding(.vertical, 8)
                }
            }
            .padding(.horizontal, 32)
            .padding(.bottom, 8)
        }
        .onDisappear { permissionTask?.cancel() }
        .responsiveContent(maxWidth: 500)
        .frame(maxWidth: .infinity)
        .onAppear {
            withAnimation(.easeOut(duration: 0.4)) {
                headlineAppeared = true
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.25) {
                withAnimation(.easeOut(duration: 0.5)) {
                    bulletsAppeared = true
                }
            }
            // Detect previously-denied so we can offer Settings deep-link instead
            // of a no-op system prompt.
            Task {
                let settings = await UNUserNotificationCenter.current().notificationSettings()
                await MainActor.run {
                    previouslyDenied = (settings.authorizationStatus == .denied)
                }
            }
        }
    }

    private var buttonTitle: String {
        if previouslyDenied { return "Open Settings" }
        if showTimeoutError { return "Try Again" }
        return "Enable Notifications"
    }

    private func primingBullet(icon: String, color: Color, text: String) -> some View {
        HStack(spacing: 14) {
            Image(systemName: icon)
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(.white)
                .frame(width: 32, height: 32)
                .background(color, in: RoundedRectangle(cornerRadius: 8))

            Text(text)
                .font(.system(size: 14, weight: .medium))

            Spacer()
        }
    }

    private func requestPermission() {
        requesting = true
        showTimeoutError = false
        permissionTask?.cancel()
        permissionTask = Task {
            // Race the permission request against an 8s timeout. If the system
            // prompt hangs (rare but possible), we surface a retry instead of
            // leaving the user stuck on a spinner.
            let granted: Bool? = await withTaskGroup(of: Bool?.self) { group in
                group.addTask {
                    await NotificationService.shared.requestPermission()
                }
                group.addTask {
                    try? await Task.sleep(for: .seconds(8))
                    return nil
                }
                let first = await group.next() ?? nil
                group.cancelAll()
                return first
            }

            if Task.isCancelled { return }

            await MainActor.run {
                requesting = false
                if let granted {
                    Analytics.onboardingStep(step: granted ? "notificationsEnabled" : "notificationsDeclined")
                    onResult(granted)
                } else {
                    Analytics.onboardingStep(step: "notificationsTimeout")
                    withAnimation { showTimeoutError = true }
                }
            }
        }
    }
}

// MARK: - Onboarding Brain Age Reveal (Spotify Wrapped style)

struct OnboardingBrainAgeReveal: View {
    let brainAge: Int
    let userAge: Int
    let onContinue: () -> Void
    var skipAnimation: Bool = false

    @State private var displayedBrainAge: Int
    @State private var isCountingUp: Bool
    @State private var countUpFinished: Bool
    @State private var showLabel: Bool
    @State private var showSubtitle: Bool
    @State private var showShare: Bool
    @State private var pulseGlow: Bool
    @State private var countUpTimer: Timer?

    init(brainAge: Int, userAge: Int, onContinue: @escaping () -> Void, skipAnimation: Bool = false) {
        self.brainAge = brainAge
        self.userAge = userAge
        self.onContinue = onContinue
        self.skipAnimation = skipAnimation
        _displayedBrainAge = State(initialValue: skipAnimation ? brainAge : 18)
        _isCountingUp = State(initialValue: skipAnimation)
        _countUpFinished = State(initialValue: skipAnimation)
        _showLabel = State(initialValue: skipAnimation)
        _showSubtitle = State(initialValue: skipAnimation)
        _showShare = State(initialValue: skipAnimation)
        _pulseGlow = State(initialValue: skipAnimation)
    }

    private var ageColor: Color {
        Self.brainAgeColor(for: countUpFinished ? brainAge : displayedBrainAge)
    }

    private var mascotMood: MascotRiveMood {
        if brainAge <= 30 { return .happy }
        if brainAge <= 50 { return .neutral }
        return .sad
    }

    private var ageComparison: (text: String, color: Color)? {
        guard userAge > 0 else { return nil }
        let diff = userAge - brainAge
        if diff > 0 {
            return ("\(diff) years younger than you!", AppColors.teal)
        }
        if diff < 0 {
            return ("\(abs(diff)) years older than your real age", AppColors.coral)
        }
        return ("Same as your real age!", AppColors.teal)
    }

    private var shareText: String {
        "My Brain Age is \(brainAge)! Test yours with Memori"
    }

    var body: some View {
        ZStack {
            Self.revealGradient(for: brainAge).ignoresSafeArea()

            if countUpFinished {
                Circle()
                    .fill(ageColor.opacity(0.18))
                    .blur(radius: 100)
                    .frame(width: 300, height: 300)
                    .offset(x: -80, y: -120)

                Circle()
                    .fill(ageColor.opacity(pulseGlow ? 0.12 : 0.06))
                    .blur(radius: 80)
                    .frame(width: 200, height: 200)
                    .offset(x: 100, y: 80)
                    .animation(.easeInOut(duration: 3.0).repeatForever(autoreverses: true), value: pulseGlow)
            }

            VStack(spacing: 0) {
                Spacer()

                RiveMascotView(mood: mascotMood, size: 140)
                    .frame(height: 120)
                    .padding(.bottom, 8)
                    .opacity(countUpFinished ? 1 : 0)
                    .scaleEffect(countUpFinished ? 1 : 0.3)
                    .animation(.spring(response: 0.5, dampingFraction: 0.7), value: countUpFinished)

                Text("YOUR BRAIN AGE")
                    .font(.system(size: 11, weight: .heavy))
                    .foregroundStyle(.white.opacity(0.5))
                    .tracking(6)
                    .opacity(showLabel ? 1 : 0)
                    .animation(.easeIn(duration: 0.4), value: showLabel)

                Text("\(displayedBrainAge)")
                    .font(.system(size: 140, weight: .black, design: .rounded))
                    .foregroundStyle(.white)
                    .shadow(color: ageColor.opacity(0.8), radius: 40, y: 0)
                    .shadow(color: ageColor.opacity(0.4), radius: 80, y: 0)
                    .contentTransition(.numericText(value: Double(displayedBrainAge)))
                    .scaleEffect(countUpFinished ? 1.0 : 0.8)
                    .animation(.spring(response: 0.3, dampingFraction: 0.5), value: countUpFinished)
                    .minimumScaleFactor(0.5)
                    .padding(.vertical, -16)
                    .opacity(isCountingUp || countUpFinished ? 1 : 0)

                VStack(spacing: 8) {
                    Text(Self.brainAgeVerdict(brainAge))
                        .font(.system(size: 24, weight: .black, design: .rounded))
                        .foregroundStyle(.white)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 24)
                        .padding(.top, 4)

                    if let comp = ageComparison {
                        Text(comp.text)
                            .font(.system(size: 17, weight: .bold, design: .rounded))
                            .foregroundStyle(comp.color)
                    }
                }
                .opacity(showSubtitle ? 1 : 0)
                .offset(y: showSubtitle ? 0 : 20)
                .animation(.spring(response: 0.4, dampingFraction: 0.7), value: showSubtitle)

                Spacer()

                VStack(spacing: 14) {
                    ShareLink(item: shareText) {
                        HStack(spacing: 8) {
                            Image(systemName: "square.and.arrow.up")
                                .font(.headline)
                            Text("Share Your Brain Age")
                                .font(.headline.weight(.bold))
                        }
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                        .background(
                            LinearGradient(
                                colors: [ageColor, ageColor.opacity(0.7)],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .clipShape(Capsule())
                        .shadow(color: ageColor.opacity(0.4), radius: 16, y: 6)
                    }

                    Button(action: onContinue) {
                        Text("See My Plan →")
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(.white.opacity(0.55))
                    }
                }
                .padding(.horizontal, 36)
                .padding(.bottom, 28)
                .opacity(showShare ? 1 : 0)
                .offset(y: showShare ? 0 : 30)
                .animation(.easeOut(duration: 0.4), value: showShare)
            }
        }
        .ignoresSafeArea()
        .onAppear {
            Analytics.onboardingStep(step: "reveal")
            if !skipAnimation { startSequence() }
        }
        .onDisappear {
            countUpTimer?.invalidate()
            countUpTimer = nil
        }
        .onChange(of: countUpFinished) { _, finished in if finished { pulseGlow = true } }
    }

    private func startSequence() {
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) {
            withAnimation(.easeIn(duration: 0.4)) { showLabel = true }
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.2) {
            startCountUp(target: brainAge)
        }
    }

    private func startCountUp(target: Int) {
        displayedBrainAge = 18
        isCountingUp = true
        let totalSteps = max(target - 18, 1)
        let interval = 3.0 / Double(totalSteps)
        let lightImpact = UIImpactFeedbackGenerator(style: .light)
        let heavyImpact = UIImpactFeedbackGenerator(style: .heavy)
        lightImpact.prepare()
        heavyImpact.prepare()

        countUpTimer?.invalidate()
        countUpTimer = Timer.scheduledTimer(withTimeInterval: interval, repeats: true) { timer in
            Task { @MainActor in
                if displayedBrainAge >= target {
                    timer.invalidate()
                    countUpTimer = nil
                    displayedBrainAge = target
                    heavyImpact.impactOccurred(intensity: 1.0)
                    withAnimation(.easeOut(duration: 0.3)) { countUpFinished = true }
                    withAnimation(.spring(response: 0.4, dampingFraction: 0.6).delay(0.4)) {
                        showSubtitle = true
                    }
                    withAnimation(.easeOut(duration: 0.4).delay(1.2)) {
                        showShare = true
                    }
                } else {
                    displayedBrainAge += 1
                    if (displayedBrainAge - 18) % 3 == 0 {
                        lightImpact.impactOccurred(intensity: 0.3)
                    }
                }
            }
        }
    }

    // MARK: Helpers (mirror ScoreRevealView)

    static func revealGradient(for age: Int) -> LinearGradient {
        if age <= 25 {
            return LinearGradient(colors: [
                Color(red: 0.0, green: 0.15, blue: 0.35),
                Color(red: 0.0, green: 0.25, blue: 0.45),
                Color(red: 0.0, green: 0.15, blue: 0.30),
            ], startPoint: .top, endPoint: .bottom)
        } else if age <= 40 {
            return LinearGradient(colors: [
                Color(red: 0.12, green: 0.04, blue: 0.30),
                Color(red: 0.22, green: 0.08, blue: 0.42),
                Color(red: 0.12, green: 0.04, blue: 0.25),
            ], startPoint: .top, endPoint: .bottom)
        } else {
            return LinearGradient(colors: [
                Color(red: 0.35, green: 0.08, blue: 0.08),
                Color(red: 0.45, green: 0.12, blue: 0.08),
                Color(red: 0.28, green: 0.06, blue: 0.06),
            ], startPoint: .top, endPoint: .bottom)
        }
    }

    static func brainAgeColor(for age: Int) -> Color {
        switch age {
        case ...25: return Color(red: 0, green: 0.82, blue: 0.62)
        case 26...40: return Color(red: 0.25, green: 0.61, blue: 0.98)
        case 41...55: return Color(red: 1.0, green: 0.76, blue: 0.28)
        default: return Color(red: 0.98, green: 0.42, blue: 0.35)
        }
    }

    static func brainAgeVerdict(_ age: Int) -> String {
        switch age {
        case ...20: return "Your brain is actually built different"
        case 21...25: return "OK you're sharp... for now"
        case 26...30: return "Average. TikTok hasn't fully won yet"
        case 31...35: return "Your attention span left the chat"
        case 36...45: return "More screen time than brain time"
        case 46...55: return "The doomscrolling is showing"
        default: return "Your brain is rotting. Not a joke."
        }
    }
}

#Preview("Personal Solution — 3 goals") {
    OnboardingPersonalSolutionView(
        userGoals: [.screenTimeFrying, .doomscrolling, .attentionShot],
        brainAge: 35,
        userAge: 28,
        onContinue: {}
    )
}

#Preview("Personal Solution — no goals (fallback)") {
    OnboardingPersonalSolutionView(
        userGoals: [],
        brainAge: nil,
        userAge: 0,
        onContinue: {}
    )
}

// MARK: - Onboarding Finale Sequence (reveal → paywall in one cover)

/// Wraps the brain-age reveal and the paywall into a single full-screen cover so
/// onboarding never has to chain two `.fullScreenCover` presentations (which races
/// — the second cover can silently fail to appear while the first is still dismissing).
struct OnboardingFinaleSequence: View {
    let brainAge: Int
    let userAge: Int

    private enum Step { case reveal, paywall }
    @State private var step: Step = .reveal

    var body: some View {
        Group {
            switch step {
            case .reveal:
                OnboardingBrainAgeReveal(
                    brainAge: brainAge,
                    userAge: userAge,
                    onContinue: {
                        withAnimation(.easeInOut(duration: 0.35)) { step = .paywall }
                    }
                )
            case .paywall:
                // PaywallView's @Environment(\.dismiss) closes the parent fullScreenCover,
                // which fires its onDismiss → onboarding advances to personalSolution.
                PaywallView(isHighIntent: true, triggerSource: "onboarding")
            }
        }
        .transition(.opacity)
    }
}

#Preview("Reveal — Good (25)") {
    OnboardingBrainAgeReveal(brainAge: 25, userAge: 28, onContinue: {}, skipAnimation: true)
}

#Preview("Reveal — Mid (35)") {
    OnboardingBrainAgeReveal(brainAge: 35, userAge: 28, onContinue: {}, skipAnimation: true)
}

#Preview("Reveal — Bad (55)") {
    OnboardingBrainAgeReveal(brainAge: 55, userAge: 28, onContinue: {}, skipAnimation: true)
}
