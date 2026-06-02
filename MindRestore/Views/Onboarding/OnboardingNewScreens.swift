import SwiftUI
import UIKit
import UserNotifications

enum OnboardingProtectedPriority: String, CaseIterable, Identifiable {
    case school
    case work
    case sleep
    case creativeWork
    case relationships
    case mentalClarity

    var id: Self { self }

    var title: String {
        switch self {
        case .school: return "School"
        case .work: return "Work"
        case .sleep: return "Sleep"
        case .creativeWork: return "Creative work"
        case .relationships: return "Relationships"
        case .mentalClarity: return "Mental clarity"
        }
    }

    var planValue: String {
        switch self {
        case .school: return "school"
        case .work: return "work"
        case .sleep: return "sleep"
        case .creativeWork: return "creative work"
        case .relationships: return "relationships"
        case .mentalClarity: return "mental clarity"
        }
    }

    var emoji: String {
        switch self {
        case .school: return "🎓"
        case .work: return "💼"
        case .sleep: return "💤"
        case .creativeWork: return "✨"
        case .relationships: return "🫶"
        case .mentalClarity: return "🧠"
        }
    }

    var symbolName: String {
        switch self {
        case .school: return "graduationcap.fill"
        case .work: return "briefcase.fill"
        case .sleep: return "bed.double.fill"
        case .creativeWork: return "sparkles"
        case .relationships: return "heart.fill"
        case .mentalClarity: return "brain.head.profile"
        }
    }

}

enum OnboardingDangerWindow: String, CaseIterable, Identifiable {
    case lateNight
    case morning
    case workBreaks
    case afterStress
    case boredom
    case allDay

    var id: Self { self }

    var title: String {
        switch self {
        case .lateNight: return "Late night"
        case .morning: return "Morning"
        case .workBreaks: return "Between work or class"
        case .afterStress: return "After stress"
        case .boredom: return "When bored"
        case .allDay: return "All day"
        }
    }

    var planValue: String {
        switch self {
        case .lateNight: return "late night"
        case .morning: return "morning"
        case .workBreaks: return "work/class breaks"
        case .afterStress: return "after stress"
        case .boredom: return "boredom"
        case .allDay: return "all day"
        }
    }

    var bubbleLead: String {
        switch self {
        case .lateNight: return "Late night"
        case .morning: return "Morning"
        case .workBreaks: return "Work/class breaks"
        case .afterStress: return "Stress"
        case .boredom: return "Boredom"
        case .allDay: return "All day"
        }
    }

    var emoji: String {
        switch self {
        case .lateNight: return "🌙"
        case .morning: return "☀️"
        case .workBreaks: return "⏰"
        case .afterStress: return "😵‍💫"
        case .boredom: return "🫠"
        case .allDay: return "♾️"
        }
    }

    var symbolName: String {
        switch self {
        case .lateNight: return "moon.stars.fill"
        case .morning: return "sun.max.fill"
        case .workBreaks: return "clock.fill"
        case .afterStress: return "bolt.heart.fill"
        case .boredom: return "face.dashed.fill"
        case .allDay: return "infinity"
        }
    }

}

struct PlanBuildBeatContent {
    enum Beat: CaseIterable {
        case goals, protect, dangerWindow, age, screenTime, final
    }

    struct Line: Equatable {
        let label: String
        let value: String
    }

    let beat: Beat
    let goals: Set<UserFocusGoal>
    let protectedPriority: OnboardingProtectedPriority?
    let dangerWindow: OnboardingDangerWindow?
    let age: Int
    let dailyScreenTimeHours: Double
    let isEstimate: Bool

    private static let lifeExpectancy = 80

    private var yearsAhead: Int { max(0, Self.lifeExpectancy - age) }

    private var hoursLabel: String {
        if dailyScreenTimeHours >= 8 && isEstimate { return "8h+" }
        let rounded = (dailyScreenTimeHours * 10).rounded() / 10
        if rounded == rounded.rounded() {
            return "\(Int(rounded))h"
        }
        return "\(rounded)h"
    }

    private var daysPerYear: Int {
        Int((dailyScreenTimeHours * 365 / 24).rounded())
    }

    static func goalSummary(_ goals: Set<UserFocusGoal>) -> String {
        if goals.contains(.screenTimeFrying) { return "hours back" }
        if goals.contains(.doomscrolling) { return "sleep protected" }
        if goals.contains(.attentionShot) { return "attention guarded" }
        if goals.contains(.loseFocus) { return "focus that holds" }
        if goals.contains(.forgetInstantly) { return "memory that sticks" }
        if goals.contains(.getSharper) { return "sharper scores" }
        return "hours back"
    }

    var bubble: String {
        switch beat {
        case .goals:
            return "Hours back. That's the mission."
        case .protect:
            return "Protect \(protectedPriority?.planValue ?? "your time"). That changes the plan."
        case .dangerWindow:
            return "\(dangerWindow?.bubbleLead ?? "The feed") is where the feed gets loud."
        case .age:
            return "\(age)? You've got ~\(yearsAhead) years of phone ahead."
        case .screenTime:
            return "\(hoursLabel) a day... that's ~\(daysPerYear) days a year gone."
        case .final:
            return "Your counterattack's ready."
        }
    }

    var newLine: Line? {
        switch beat {
        case .goals:
            return Line(label: "Goal", value: Self.goalSummary(goals))
        case .protect:
            return Line(label: "Protect", value: protectedPriority?.planValue ?? "your time")
        case .dangerWindow:
            return Line(label: "Danger window", value: dangerWindow?.planValue ?? "feed pull")
        case .age:
            return Line(label: "Age", value: "\(age) · ~\(yearsAhead) yrs ahead")
        case .screenTime:
            return Line(label: "Screen time", value: "\(hoursLabel)/day")
        case .final:
            return nil
        }
    }

    static func cumulativeLines(
        upTo: Beat,
        goals: Set<UserFocusGoal>,
        protectedPriority: OnboardingProtectedPriority?,
        dangerWindow: OnboardingDangerWindow?,
        age: Int,
        dailyScreenTimeHours: Double,
        isEstimate: Bool
    ) -> [Line] {
        let order: [Beat] = [.goals, .protect, .dangerWindow, .age, .screenTime]
        let cutoff = (upTo == .final) ? order.count : (order.firstIndex(of: upTo).map { $0 + 1 } ?? 0)
        return order.prefix(cutoff).compactMap { beat in
            PlanBuildBeatContent(
                beat: beat,
                goals: goals,
                protectedPriority: protectedPriority,
                dangerWindow: dangerWindow,
                age: age,
                dailyScreenTimeHours: dailyScreenTimeHours,
                isEstimate: isEstimate
            ).newLine
        }
    }
}

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

// MARK: - Personal Plan Reveal
//
// Sits after the brain age reveal. Turns the user's inputs into the
// resistance plan: train, lock apps, earn unlocks, compete.

struct OnboardingPersonalSolutionView: View {
    let userGoals: Set<UserFocusGoal>
    let brainAge: Int?
    let userAge: Int
    let dailyScreenTimeHours: Double
    let projectedScreenTimeHours: Int
    let projectionIsEstimate: Bool
    let receiptCount: Int
    let protectedPriority: OnboardingProtectedPriority?
    let dangerWindow: OnboardingDangerWindow?
    let onContinue: () -> Void

    private enum RevealBeat {
        case stakes
        case reclaim   // was .withMemo — Beat 1: post-cut hero + corporate punch + CTA
        case plan
    }

    @State private var cardsAppeared: [Bool] = [false, false, false, false]
    @State private var revealBeat: RevealBeat = .stakes
    @State private var headlineAppeared = false
    @State private var animatedProjectionHours = 0
    @State private var animatedReclaimedHours = 0
    @State private var revealStarted = false
    @State private var revealTask: Task<Void, Never>?
    /// Drives the backdrop's recoil + drift fade-out + opacity drop in a
    /// single animatable scalar. 0 = stakes (apps alive), 1 = reclaim
    /// (apps pushed back). Animated via withAnimation so the TimelineView
    /// inside PlanRevealBackdrop sees a smoothly interpolated value.
    @State private var recoilProgress: CGFloat = 0
    /// Slash sweep: capsule scale-x from 0 → 1 as the brand-blue cut beam
    /// crosses the projected number. Separate from slashOpacity so the
    /// capsule can fade out independently after the sweep completes.
    @State private var slashProgress: CGFloat = 0
    @State private var slashOpacity: CGFloat = 0
    /// Tracks count progress 0 → 1 so the projected-number color can
    /// interpolate coral → coralDeep continuously instead of step-by-step.
    @State private var countProgress: Double = 0
    /// Plan-beat life-bar draw-in. Animates 0 → 1 with easeOut once the
    /// plan beat appears so the 2-color bar fills in from the leading edge
    /// (saved blue → residual coral) instead of snapping in fully drawn.
    @State private var planBarProgress: CGFloat = 0
    /// Per-row glow trigger for plan-card numbers. Each row pulses brand-
    /// blue when it appears so the plan reads as "unsealed" instead of
    /// "printed."
    @State private var cardGlowing: [Bool] = [false, false, false, false]

    /// Drives the Beat 1 hero number's format. The cut snaps to .hours so
    /// the user reads continuity with the count-up; ~700ms later we flip
    /// to .breakdown ("4 YEARS · 132 DAYS") so the emotional weight lands.
    private enum HeroFormat {
        case hours
        case breakdown
    }
    @State private var heroFormat: HeroFormat = .hours

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
        GeometryReader { proxy in
            ZStack {
                revealBackdrop(size: proxy.size)

                Group {
                    switch revealBeat {
                    case .stakes:
                        VStack(alignment: .leading, spacing: 0) {
                            cinematicProjectionHero
                                .padding(.top, 38)
                                .opacity(headlineAppeared ? 1 : 0)
                                .offset(y: headlineAppeared ? 0 : 10)

                            Spacer(minLength: 24)

                            heroNumberBlock
                                .opacity(headlineAppeared ? 1 : 0)

                            Spacer(minLength: 24)
                        }
                        .padding(.horizontal, 28)
                        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                    case .reclaim:
                        VStack(alignment: .leading, spacing: 0) {
                            Spacer(minLength: 0)

                            VStack(alignment: .leading, spacing: 4) {
                                cinematicProjectionHero
                                heroNumberBlock
                            }

                            Spacer(minLength: 24)

                            beat1Extras
                        }
                        .padding(.horizontal, 28)
                        .padding(.top, 38)
                        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
                        .safeAreaInset(edge: .bottom) {
                            beat1CTAButton
                                .padding(.horizontal, 32)
                                .padding(.bottom, 16)
                                .padding(.top, 8)
                                .background(
                                    LinearGradient(
                                        colors: [AppColors.pageBg.opacity(0), AppColors.pageBg.opacity(0.85), AppColors.pageBg],
                                        startPoint: .top,
                                        endPoint: .bottom
                                    )
                                    .ignoresSafeArea(edges: .bottom)
                                )
                        }
                        .transition(.opacity)
                    case .plan:
                        planBeatLayout
                            .transition(.move(edge: .bottom).combined(with: .opacity))
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
            }
        }
        .animation(.spring(response: 0.68, dampingFraction: 0.86), value: revealBeat)
        .animation(.spring(response: 0.48, dampingFraction: 0.82), value: headlineAppeared)
        .onAppear {
            startRevealAnimation()
        }
        .onDisappear {
            revealTask?.cancel()
        }
    }

    private func revealBackdrop(size: CGSize) -> some View {
        PlanRevealBackdrop(
            isStakes: revealBeat == .stakes,
            isDefeated: revealBeat != .stakes,   // Beat 1 + Beat 2 share defeated grid
            recoilProgress: recoilProgress,
            size: size,
            logos: feedTileLogos
        )
    }

    /// Top-anchored content for the stakes/reclaim states. Pill +
    /// eyebrow + headline. The number + caption block lives in
    /// `heroNumberBlock`, which the parent positions independently
    /// (centered for stakes, tight under this view for reclaim).
    private var cinematicProjectionHero: some View {
        let isReclaim = revealBeat == .reclaim
        let eyebrowAccent = isReclaim ? AppColors.accent : AppColors.coral

        return VStack(alignment: .leading, spacing: 10) {
            // Screen Time provenance pill — only on stakes
            if !isReclaim {
                screenTimeSourcePill
                    .transition(.opacity)
            }

            // Eyebrow
            Text(isReclaim ? "WITH MEMO" : "WITHOUT MEMO")
                .font(.system(size: 11, weight: .heavy, design: .monospaced))
                .tracking(1.4)
                .foregroundStyle(eyebrowAccent)
                .contentTransition(.opacity)

            // Stakes-only headline ("You're giving social media giants").
            // Fades out at the cut.
            if !isReclaim {
                Text("You're giving social\nmedia giants")
                    .font(.system(size: 28, weight: .heavy, design: .rounded))
                    .foregroundStyle(AppColors.textPrimary.opacity(0.92))
                    .lineSpacing(1)
                    .fixedSize(horizontal: false, vertical: true)
                    .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
    }

    /// The hero number + caption stack. On stakes: animated count-up
    /// in coral with HOURS + climbing breakdown subtitle. On reclaim
    /// + .hours: snapped reclaimedHoursText with "hours back in your
    /// life" subtitle. On reclaim + .breakdown: savedBreakdownText
    /// with the same subtitle. The parent body chooses where this
    /// view sits relative to `cinematicProjectionHero` — vertically
    /// centered for stakes, tight under the eyebrow for reclaim.
    private var heroNumberBlock: some View {
        let isReclaim = revealBeat == .reclaim
        let numberAccent: Color = isReclaim
            ? AppColors.accent
            : AppColors.coral.interpolated(with: AppColors.coralDeep, by: countProgress)

        return VStack(alignment: .leading, spacing: 6) {
            heroNumber(numberAccent: numberAccent)

            if isReclaim {
                if heroFormat == .hours {
                    Text("HOURS BACK")
                        .font(.system(size: 11, weight: .heavy, design: .monospaced))
                        .tracking(1.2)
                        .foregroundStyle(AppColors.textPrimary.opacity(0.48))
                        .transition(.opacity)
                } else {
                    Text("back in your life")
                        .font(.system(size: 17, weight: .semibold, design: .rounded))
                        .foregroundStyle(AppColors.textPrimary.opacity(0.7))
                        .transition(.opacity)
                }
            } else {
                VStack(alignment: .leading, spacing: 6) {
                    Text("HOURS")
                        .font(.system(size: 11, weight: .heavy, design: .monospaced))
                        .tracking(1.2)
                        .foregroundStyle(AppColors.textPrimary.opacity(0.4))

                    Text(lifeBreakdownText)
                        .font(.system(size: 14, weight: .heavy, design: .monospaced))
                        .tracking(0.8)
                        .foregroundStyle(AppColors.coral)
                        .contentTransition(.numericText(value: Double(animatedProjectionHours)))
                }
            }
        }
    }

    /// The hero number block with the slash overlay. Two visual states:
    /// - hours form (during stakes count-up AND immediately post-cut):
    ///   shows `animatedHoursText` while .stakes, `reclaimedHoursText`
    ///   while .reclaim + .hours. Frame height locks to 122pt so the
    ///   slash overlay has consistent room across the cut animation.
    /// - breakdown form (post-dwell): shows `savedBreakdownText`. No
    ///   slash. Height is intrinsic so the subtitle sits directly
    ///   under the number — no residual 80pt of empty space.
    @ViewBuilder
    private func heroNumber(numberAccent: Color) -> some View {
        let useHoursForm = heroFormat == .hours || revealBeat == .stakes

        ZStack(alignment: .leading) {
            if useHoursForm {
                let displayText = revealBeat == .stakes ? animatedHoursText : reclaimedHoursText
                let numericValue = revealBeat == .stakes
                    ? Double(animatedProjectionHours)
                    : Double(savedHoursTotal)

                Text(displayText)
                    .font(.system(size: 92, weight: .black, design: .rounded))
                    .monospacedDigit()
                    .foregroundStyle(numberAccent)
                    .minimumScaleFactor(0.55)
                    .lineLimit(1)
                    .contentTransition(.numericText(value: numericValue))
                    .shadow(
                        color: (revealBeat == .stakes ? AppColors.coral : AppColors.accent).opacity(0.28),
                        radius: 18, y: 8
                    )
                    .overlay(alignment: .leading) {
                        GeometryReader { proxy in
                            Capsule()
                                .fill(AppColors.accent)
                                .frame(width: proxy.size.width, height: 8)
                                .scaleEffect(x: slashProgress, y: 1, anchor: .leading)
                                .offset(y: proxy.size.height / 2 - 4)
                                .opacity(slashOpacity)
                                .shadow(color: AppColors.accent.opacity(0.55), radius: 10, y: 0)
                        }
                        .allowsHitTesting(false)
                    }
                    .transition(.opacity)
            } else {
                // .reclaim + .breakdown — drop the slash, show breakdown text.
                Text(savedBreakdownText)
                    .font(.system(size: 39, weight: .heavy, design: .rounded))
                    .foregroundStyle(AppColors.accent)
                    .minimumScaleFactor(0.6)
                    .lineLimit(1)
                    .shadow(color: AppColors.accent.opacity(0.32), radius: 16, y: 8)
                    .transition(.opacity)
            }
        }
        .frame(height: useHoursForm ? 122 : nil, alignment: .leading)
    }

    /// Small "● from your Screen Time" / "● estimated from your input"
    /// pill above the stakes eyebrow. Builds trust at the count-up moment.
    /// Driven by the existing `projectionIsEstimate` input.
    private var screenTimeSourcePill: some View {
        HStack(spacing: 6) {
            Circle()
                .fill(AppColors.accent)
                .frame(width: 5, height: 5)
            Text(projectionIsEstimate ? "estimated from your input" : "from your Screen Time")
                .font(.system(size: 9, weight: .heavy, design: .monospaced))
                .tracking(0.8)
                .foregroundStyle(AppColors.textPrimary.opacity(0.4))
        }
    }

    /// Beat 2 elements that enter under the reclaimed-time hero after the cut:
    /// the corporate-attack punchline that tees up the plan.
    private var beat1Extras: some View {
        return VStack(alignment: .leading, spacing: 0) {
            // Corporate punch — the brand-voice anchor after the reclaimed time lands.
            VStack(alignment: .leading, spacing: 4) {
                Text("Big tech is colonizing\nyour attention.")
                    .font(.system(size: 22, weight: .heavy, design: .rounded))
                    .foregroundStyle(AppColors.textPrimary.opacity(0.94))
                    .lineSpacing(1)
                    .fixedSize(horizontal: false, vertical: true)
                Text("Memo helps you take it back.")
                    .font(.system(size: 22, weight: .heavy, design: .rounded))
                    .italic()
                    .foregroundStyle(AppColors.accent)
            }
            .transition(.opacity.combined(with: .move(edge: .bottom)))
            .animation(.spring(response: 0.55, dampingFraction: 0.85).delay(0.10), value: revealBeat)
        }
    }

    /// Beat 1's "See the plan →" — fires advanceToPlan() (Phase 1 stub).
    private var beat1CTAButton: some View {
        Button(action: advanceToPlan) {
            HStack(spacing: 8) {
                Text("Show me how")
                Image(systemName: "arrow.right")
                    .font(.system(size: 15, weight: .heavy))
            }
            .font(.system(size: 18, weight: .heavy, design: .rounded))
            .foregroundStyle(AppColors.textPrimary)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 16)
            .background(AppColors.accent, in: RoundedRectangle(cornerRadius: 16))
            .overlay {
                RoundedRectangle(cornerRadius: 16)
                    .stroke(AppColors.textPrimary.opacity(0.2), lineWidth: 1)
            }
            .shadow(color: AppColors.accent.opacity(0.34), radius: 22, y: 10)
        }
        .buttonStyle(.plain)
    }

    /// Rev 4 plan-beat layout. Reframes the page from "Memo halves your
    /// damage (still 3 years lost)" to "Memo reclaims 4Y 132D — backed by
    /// behavioral science — want the last bit too?". The hero is the
    /// reclaim total; the 2-color life bar shows saved (blue) vs residual
    /// (coral); the explainer makes the 75% claim defensible; the
    /// Beat 2 — the plan card. No ScrollView per spec implementation note 4;
    /// fixed VStack + safeAreaInset(.bottom) for the CTA. Hero + bridge
    /// added in Phase 5.
    /// Beat 2 — the brain-trainer USP + tactical plan card + brand-voice
    /// bridge. Fixed VStack, no ScrollView. Mirrors Beat 1's safeAreaInset
    /// pattern for the CTA.
    private var planBeatLayout: some View {
        VStack(alignment: .leading, spacing: 18) {
            // Eyebrow
            Text("YOUR COUNTERATTACK")
                .font(.system(size: 11, weight: .heavy, design: .monospaced))
                .tracking(1.4)
                .foregroundStyle(AppColors.textPrimary.opacity(0.4))

            // Hero — brain-trainer USP
            VStack(alignment: .leading, spacing: 0) {
                Text("Train first.")
                    .font(.system(size: 26, weight: .heavy, design: .rounded))
                    .foregroundStyle(AppColors.textPrimary.opacity(0.94))
                Text("Unlock time after.")
                    .font(.system(size: 26, weight: .heavy, design: .rounded))
                    .foregroundStyle(AppColors.accent)
            }

            // Supporting subhead
            Text("Beat brain games, earn screen time, and keep the feed boxed out.")
                .font(.system(size: 13, weight: .semibold, design: .rounded))
                .foregroundStyle(AppColors.textPrimary.opacity(0.55))
                .lineSpacing(2)
                .fixedSize(horizontal: false, vertical: true)

            // Plan card
            planCard

            Spacer(minLength: 0)

            // Bridge — carries the corporate antagonist into Beat 2
            VStack(alignment: .leading, spacing: 4) {
                Text("Take your brain back.")
                    .font(.system(size: 17, weight: .heavy, design: .rounded))
                    .foregroundStyle(AppColors.textPrimary.opacity(0.94))
                Text("Big tech won't give it back voluntarily.")
                    .font(.system(size: 13, weight: .semibold, design: .rounded))
                    .foregroundStyle(AppColors.textPrimary.opacity(0.55))
                    .fixedSize(horizontal: false, vertical: true)
            }
            .opacity(cardsAppeared[3] ? 1 : 0)
        }
        .padding(.horizontal, 24)
        .padding(.top, 12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .safeAreaInset(edge: .bottom) {
            unlockPlanButton
                .padding(.horizontal, 32)
                .padding(.bottom, 16)
                .padding(.top, 8)
                .background(
                    LinearGradient(
                        colors: [AppColors.pageBg.opacity(0), AppColors.pageBg.opacity(0.85), AppColors.pageBg],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                    .ignoresSafeArea(edges: .bottom)
                )
        }
    }

    /// Rev 5 tactical color-coded plan stack. No outer container box; each
    /// row is its own RoundedRectangle with a 3pt colored leading bar.
    /// Order encodes the brand story: Train (mechanism) → Earn (payoff) →
    /// Block (enforcement) → Compete (long game).
    private var planCard: some View {
        VStack(alignment: .leading, spacing: 7) {
            planCardRow(
                color: AppColors.violet,
                label: "Train",
                detail: "5 min brain games",
                value: "5 min/day",
                index: 0
            )
            planCardRow(
                color: AppColors.accent,
                label: "Protect",
                detail: protectedPriority.map { "guard \($0.planValue)" } ?? "guard your time",
                value: protectedPriority?.title ?? "Your time",
                index: 1
            )
            planCardRow(
                color: AppColors.coral,
                label: "Window",
                detail: "feed pull peaks",
                value: dangerWindow?.title ?? "Your pattern",
                index: 2
            )
            planCardRow(
                color: AppColors.amber,
                label: "Compete",
                detail: "climb the board",
                value: "live",
                index: 3
            )
        }
    }

    private var unlockPlanButton: some View {
        Button(action: onContinue) {
            HStack(spacing: 8) {
                Text("Take my brain back")
                Image(systemName: "arrow.right")
                    .font(.system(size: 15, weight: .heavy))
            }
            .font(.system(size: 18, weight: .heavy, design: .rounded))
            .foregroundStyle(AppColors.textPrimary)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 16)
            .background(AppColors.accent, in: RoundedRectangle(cornerRadius: 16))
            .overlay {
                RoundedRectangle(cornerRadius: 16)
                    .stroke(AppColors.textPrimary.opacity(0.2), lineWidth: 1)
            }
            .shadow(color: AppColors.accent.opacity(0.34), radius: 22, y: 10)
        }
        .buttonStyle(.plain)
    }

    private var brainAgeSubtitle: String {
        if let brainAge, userAge > 0 {
            let diff = brainAge - userAge
            if diff > 0 {
                return "You're not stuck with that score. Memo trains the brain and locks the noise."
            } else if diff < 0 {
                return "You're ahead. Memo helps you stay dangerous."
            } else {
                return "Memo's plan is built to push your Brain Age down."
            }
        }
        return "Train your brain. Block the noise. Earn your time back."
    }

    private var projectionSubtitle: String {
        let source = projectionIsEstimate ? "estimated \(dailyScreenTimeText)/day" : "\(dailyScreenTimeText)/day from Screen Time"
        return "\(source). \(brainAgeSubtitle)"
    }

    private var dailyScreenTimeText: String {
        String(format: "%.1fh", dailyScreenTimeHours)
    }

    private var targetProjectionHours: Int {
        projectedScreenTimeHours >= 1000
            ? Int((Double(projectedScreenTimeHours) / 1000.0).rounded()) * 1000
            : projectedScreenTimeHours
    }

    private var projectedHoursText: String {
        targetProjectionHours.formatted()
    }

    private var animatedHoursText: String {
        animatedProjectionHours.formatted()
    }

    /// Memo's reduction claim — single source of truth across this view AND
    /// the comparison page (next page in the funnel). Bumped from 0.50 →
    /// 0.75 so the user sees an aspirational reclaim, not "still wasting 3
    /// years." Industry baseline is 70-90% (Opal, Brick, ScreenZen) — 0.75
    /// is conservative even by category standard.
    static let memoReductionFraction: Double = 0.75

    /// Hours Memo gives back when the user follows the plan. This is the
    /// hero number on the plan beat — "RECLAIMED X YEARS Y DAYS."
    private var savedHoursTotal: Int {
        Int(Double(targetProjectionHours) * Self.memoReductionFraction)
    }

    /// Hours still given to social media giants under the Memo plan.
    /// Surfaced as a small footnote ("still: X YEARS Y DAYS on the table")
    /// so the user feels there's more to take back.
    private var residualHoursTotal: Int {
        targetProjectionHours - savedHoursTotal
    }

    private var reclaimedHoursText: String {
        max(animatedReclaimedHours, savedHoursTotal).formatted()
    }

    private var finalReclaimedHoursText: String {
        savedHoursTotal.formatted()
    }

    /// "4 YEARS · 132 DAYS" — what Memo reclaims. Hero on the plan beat.
    private var savedYears: Int { (savedHoursTotal / 24) / 365 }
    private var savedRemainingDays: Int { (savedHoursTotal / 24) - (savedYears * 365) }
    private var savedBreakdownText: String {
        "\(savedYears) YEARS · \(savedRemainingDays) DAYS"
    }

    /// "1 YEAR · 166 DAYS" — what's still on the table. Plan-beat footnote.
    private var residualYears: Int { (residualHoursTotal / 24) / 365 }
    private var residualRemainingDays: Int { (residualHoursTotal / 24) - (residualYears * 365) }
    private var residualBreakdownText: String {
        "\(residualYears) \(residualYears == 1 ? "YEAR" : "YEARS") · \(residualRemainingDays) DAYS"
    }

    private var projectedYearsText: String {
        String(format: "%.1f", Double(projectedScreenTimeHours) / 8760.0)
    }

    /// Years portion of the live-counting hours total. Updates in lockstep
    /// with the count-up so the bar + breakdown line all climb together.
    /// Ignores leap years (~0.07% off, invisible at this scale).
    private var animatedYears: Int {
        let totalDays = animatedProjectionHours / 24
        return totalDays / 365
    }

    /// Remainder days after subtracting whole years.
    private var animatedRemainingDays: Int {
        let totalDays = animatedProjectionHours / 24
        return totalDays - (animatedYears * 365)
    }

    /// "5 YEARS · 292 DAYS" — climbs alongside the projected number.
    private var lifeBreakdownText: String {
        "\(animatedYears) YEARS · \(animatedRemainingDays) DAYS"
    }

    /// Real social-app logos for the backdrop tile grid. Twelve brands now
    /// (six original PNGs + six color SVGs) — enough variety that the 77-tile
    /// grid reads as a feed wall, not a wallpaper pattern.
    private var feedTileLogos: [String] {
        [
            "logo-tiktok", "logo-instagram", "logo-youtube",
            "logo-snapchat", "logo-reddit", "logo-x",
            "logo-facebook", "logo-pinterest", "logo-threads",
            "logo-discord", "logo-twitch", "logo-bluesky"
        ]
    }

    private func startRevealAnimation() {
        guard !revealStarted else { return }
        revealStarted = true

        // Reset siege-animation state so a re-entry replays cleanly.
        recoilProgress = 0
        slashProgress = 0
        slashOpacity = 0
        countProgress = 0
        planBarProgress = 0
        heroFormat = .hours
        cardGlowing = [false, false, false, false]

        revealTask?.cancel()
        revealTask = Task { @MainActor in
            // 400ms buffer so the count-up doesn't tick during the page
            // transition's 0.40s dissolve. See:
            // docs/superpowers/specs/2026-04-28-onboarding-page-transitions-design.md
            try? await Task.sleep(for: .milliseconds(400))
            guard !Task.isCancelled else { return }

            withAnimation(.easeOut(duration: 0.36)) {
                headlineAppeared = true
            }

            await countProjection()
            guard !Task.isCancelled else { return }

            // 600ms hold post-climb (down from 900ms). The drift continues
            // and the number's color settles to full coralDeep — motion stays
            // present, no dead frames.
            try? await Task.sleep(for: .milliseconds(600))
            guard !Task.isCancelled else { return }

            // The cut. Rev 5 sequence:
            // (1) recoil + slash sweep at slash-start (concurrent, no revealBeat change yet)
            // (2) at +0.8s, number snaps AND revealBeat flips to .reclaim in same withAnimation block
            // (3) at +1.10s, slash fades + planBarProgress draws in + Beat 1 elements enter
            // (4) at +1.50s, heroFormat flips to .breakdown
            UIImpactFeedbackGenerator(style: .medium).impactOccurred()

            // Slash + recoil — independent of revealBeat. Apps recoil while the
            // hero block is still showing the stakes count.
            withAnimation(.easeOut(duration: 0.5)) {
                slashProgress = 1.0
                slashOpacity = 1.0
            }
            withAnimation(.spring(response: 1.2, dampingFraction: 0.86)) {
                recoilProgress = 1.0
            }

            try? await Task.sleep(for: .milliseconds(800))
            guard !Task.isCancelled else { return }

            // Number snap + layout swap to .reclaim in the SAME withAnimation
            // block — the eyebrow / subtitle / headline crossfades all ride
            // this spring. heroFormat stays .hours so the snapped number
            // renders as `38,000` (continuity with the count-up).
            withAnimation(.spring(response: 0.5, dampingFraction: 0.85)) {
                animatedReclaimedHours = savedHoursTotal
                revealBeat = .reclaim
            }

            // 300ms breath, then slash fades + Beat 1 elements draw in
            // (lifeBar via planBarProgress). See spec animation table at
            // t=7.12s relative to page-enter.
            try? await Task.sleep(for: .milliseconds(300))
            guard !Task.isCancelled else { return }

            withAnimation(.easeIn(duration: 0.4)) {
                slashOpacity = 0
            }
            withAnimation(.easeOut(duration: 0.6)) {
                planBarProgress = 1
            }

            // 400ms more — slash fade is finishing — then flip the hero
            // number from .hours to .breakdown. Total post-snap dwell = 700ms.
            try? await Task.sleep(for: .milliseconds(400))
            guard !Task.isCancelled else { return }

            withAnimation(.easeInOut(duration: 0.4)) {
                heroFormat = .breakdown
            }

            // startRevealAnimation EXITS here — Beat 1 dwells until user
            // taps "See the plan →", which calls advanceToPlan().
        }
    }

    @MainActor
    private func countProjection() async {
        let target = targetProjectionHours
        // ~5.0s total count-up (was ~4.0s). 209 steps × 24ms — the rev 4
        // reframe leans on the climb to *earn* the cut, so it gets more
        // breathing room. Tick frequency (step % 24) still gives ~7
        // drumbeat haptics across the climb.
        let steps = 209
        let lightTick = UIImpactFeedbackGenerator(style: .light)
        lightTick.prepare()

        for step in 0...steps {
            guard !Task.isCancelled else { return }
            let progress = Double(step) / Double(steps)
            let eased = 1 - pow(1 - progress, 3)
            animatedProjectionHours = Int((Double(target) * eased).rounded())
            // countProgress drives the projected-number color blend
            // (coral → coralDeep) via cinematicProjectionHero.
            countProgress = eased

            // Light haptic tick every 24 steps — ~7 taps across the climb.
            // Spaces them out enough that they read as drumbeats, not buzz.
            if step > 0 && step % 24 == 0 {
                lightTick.impactOccurred(intensity: 0.4)
            }

            try? await Task.sleep(for: .milliseconds(24))
        }
    }

    /// Beat 1 → Beat 2 transition, fired by Beat 1's "See the plan →" CTA.
    /// Wired in Phase 3. Defined here in Phase 1 to keep the diff in
    /// each phase tight.
    @MainActor
    private func advanceToPlan() {
        guard revealBeat == .reclaim else { return }
        withAnimation(.spring(response: 0.74, dampingFraction: 0.86)) {
            revealBeat = .plan
        }
        revealTask?.cancel()
        revealTask = Task { @MainActor in
            await revealPlanRows()
        }
    }

    @MainActor
    private func revealPlanRows() async {
        // Soft success haptic when the first plan row lands — completes
        // the haptic arc: light ticks during climb → medium impact at cut →
        // soft success at the counterattack reveal.
        UINotificationFeedbackGenerator().notificationOccurred(.success)
        for i in 0..<cardsAppeared.count {
            guard !Task.isCancelled else { return }
            withAnimation(.spring(response: 0.5, dampingFraction: 0.82)) {
                cardsAppeared[i] = true
                if i < cardGlowing.count {
                    cardGlowing[i] = true
                }
            }
            // Each row's leading number pulses brand-blue for ~250ms then
            // settles. Gives the rows an "unsealed" feel rather than a
            // static printed list.
            Task { @MainActor [i] in
                try? await Task.sleep(for: .milliseconds(250))
                guard !Task.isCancelled else { return }
                withAnimation(.easeOut(duration: 0.4)) {
                    if i < cardGlowing.count {
                        cardGlowing[i] = false
                    }
                }
            }
            try? await Task.sleep(for: .milliseconds(86))
        }
    }

    /// Single row card. Row-color@10% background, 3pt leading bar in
    /// row-color, label + detail stack on the leading edge, mono value
    /// trailing. Reuses cardsAppeared[index] for the entry animation.
    @ViewBuilder
    private func planCardRow(
        color: Color,
        label: String,
        detail: String,
        value: String,
        index: Int
    ) -> some View {
        let appeared = index < cardsAppeared.count ? cardsAppeared[index] : true

        HStack(spacing: 12) {
            Rectangle()
                .fill(color)
                .frame(width: 3)

            VStack(alignment: .leading, spacing: 3) {
                Text(label)
                    .font(.system(size: 13, weight: .heavy, design: .rounded))
                    .foregroundStyle(AppColors.textPrimary)
                Text(detail)
                    .font(.system(size: 10, weight: .semibold, design: .rounded))
                    .foregroundStyle(AppColors.textPrimary.opacity(0.55))
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(.vertical, 11)

            Spacer(minLength: 8)

            Text(value)
                .font(.system(size: 11, weight: .heavy, design: .monospaced))
                .monospacedDigit()
                .foregroundStyle(color)
                .padding(.trailing, 12)
        }
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(color.opacity(0.10))
        )
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        .opacity(appeared ? 1 : 0)
        .offset(y: appeared ? 0 : 12)
    }
}

// MARK: - LifeBar
//
// Two-color life bar shown on the plan beat. The leading section is brand
// blue (what Memo reclaims, sized via `savedFraction`); the trailing section
// is muted coral (what's still on the table). Both sections are scaled by
// `progress` (0 → 1) so the bar draws in from the leading edge after the
// plan beat appears.

private struct LifeBar: View {
    let savedFraction: CGFloat
    let progress: CGFloat
    let width: CGFloat
    let height: CGFloat

    var body: some View {
        let p = max(0, min(1, progress))
        let saved = max(0, min(1, savedFraction))
        let savedWidth = width * saved * p
        let residualWidth = width * (1 - saved) * p

        return HStack(spacing: 0) {
            LinearGradient(
                colors: [AppColors.accent.opacity(0.85), AppColors.accent],
                startPoint: .leading,
                endPoint: .trailing
            )
            .frame(width: savedWidth, height: height)

            AppColors.coral.opacity(0.55)
                .frame(width: residualWidth, height: height)

            Spacer(minLength: 0)
        }
        .frame(width: width, height: height, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: height / 2, style: .continuous)
                .fill(Color.white.opacity(0.10))
        )
        .clipShape(RoundedRectangle(cornerRadius: height / 2, style: .continuous))
        .shadow(color: .black.opacity(0.28), radius: 2, y: 1)
    }
}

// MARK: - PlanRevealBackdrop ("The Siege")
//
// Single-TimelineView backdrop for the plan-reveal page. Renders a 7×5 grid
// of social-app logos with three behaviors:
//
// 1. **Drift** — per-tile sin/cos offsets driven from one timeline value
//    (no 35 independent state animations). Reads as the algorithm always-on.
// 2. **Pulse** — smooth ~1.5s sine-wave opacity breath, phase-shifted per tile
//    so the wave rolls across the grid instead of all tiles flashing in sync.
// 3. **Recoil** — when `recoilProgress` animates 0 → 1 (driven by the parent's
//    withAnimation block on the stakes → reclaim transition), tiles push
//    outward from center, drift fades, opacity halves, saturation drops.
//
// Tile depth is a continuous gradient (not three discrete bands) by
// distance from grid center — front-most tiles are sharp + opaque, edge
// tiles are dim + blurred. Reads as "feed wall in the fog."

private struct PlanRevealBackdrop: View {
    let isStakes: Bool
    let isDefeated: Bool   // true when revealBeat != .stakes — apps recoiled, dim grid
    /// 0 = full drift / pulse / opacity (apps alive). 1 = recoiled, halved
    /// opacity, drift muted (apps defeated). Animated by the parent.
    let recoilProgress: CGFloat
    let size: CGSize
    let logos: [String]

    private let rows = 11
    private let cols = 7
    private let tileSpacing: CGFloat = 10
    private let nominalTileSize: CGFloat = 28

    /// Deterministic permutation of the logo array, expanded to fill all
    /// `rows * cols` tiles. Replaces a naive `index % logos.count` mapping
    /// (which produced visible row/column patterns) with a shuffled
    /// sequence seeded from a fixed value, so the same view re-renders
    /// identically across frames but reads as varied across the grid.
    private var permutedLogos: [String] {
        let total = rows * cols
        var rng = LinearCongruentialRNG(seed: 0xA17C0DE)
        var output: [String] = []
        output.reserveCapacity(total)
        var pool: [String] = []
        while output.count < total {
            if pool.isEmpty {
                pool = logos.shuffled(using: &rng)
            }
            output.append(pool.removeLast())
        }
        return output
    }

    private var maxDist: Double {
        let centerRow = Double(rows - 1) / 2.0
        let centerCol = Double(cols - 1) / 2.0
        return sqrt(centerRow * centerRow + centerCol * centerCol)
    }

    private var accent: Color {
        isStakes ? AppColors.coral : AppColors.accent
    }

    var body: some View {
        ZStack {
            AppColors.pageBg

            // Glow halo behind the grid — color shifts from coral (stakes)
            // to accent (reclaim / plan).
            Circle()
                .fill(accent.opacity(isDefeated ? 0.14 : 0.24))
                .frame(width: size.width * 0.95, height: size.width * 0.95)
                .blur(radius: 76)
                .offset(x: size.width * 0.34, y: isStakes ? size.height * 0.12 : -size.height * 0.05)

            TimelineView(.animation(minimumInterval: 1.0 / 30.0)) { timeline in
                let t = timeline.date.timeIntervalSinceReferenceDate
                tileGrid(at: t)
            }
            .rotationEffect(.degrees(-8))
            .offset(x: size.width * 0.2, y: isStakes ? size.height * 0.18 : size.height * 0.08)
            .opacity(isDefeated ? 0.45 : 1)
        }
        .ignoresSafeArea()
    }

    @ViewBuilder
    private func tileGrid(at t: Double) -> some View {
        // 6s drift period for x; 7.5s for y (slightly off so the pattern
        // never looks like rigid linear motion). 1.5s breath for pulse.
        let driftFreqX = 2.0 * .pi / 6.0
        let driftFreqY = 2.0 * .pi / 7.5
        let breathFreq = 2.0 * .pi / 1.5
        let centerRow = Double(rows - 1) / 2.0
        let centerCol = Double(cols - 1) / 2.0
        let permuted = permutedLogos

        VStack(spacing: tileSpacing) {
            ForEach(0..<rows, id: \.self) { row in
                HStack(spacing: tileSpacing) {
                    ForEach(0..<cols, id: \.self) { col in
                        tile(row: row, col: col, t: t,
                             logoName: permuted[row * cols + col],
                             driftFreqX: driftFreqX,
                             driftFreqY: driftFreqY,
                             breathFreq: breathFreq,
                             centerRow: centerRow,
                             centerCol: centerCol)
                    }
                }
                .offset(x: row.isMultiple(of: 2) ? 12 : -6)
            }
        }
    }

    @ViewBuilder
    private func tile(
        row: Int,
        col: Int,
        t: Double,
        logoName: String,
        driftFreqX: Double,
        driftFreqY: Double,
        breathFreq: Double,
        centerRow: Double,
        centerCol: Double
    ) -> some View {
        let dx = Double(row) - centerRow
        let dy = Double(col) - centerCol
        let dist = sqrt(dx * dx + dy * dy)
        let normDist = dist / maxDist  // 0 (center) → 1 (corner)

        // Continuous depth gradient — front tiles are sharp + opaque,
        // edge tiles fade into atmosphere. Rev 4 trim: peak drops 0.55 →
        // 0.40 so stakes copy reads cleanly without the grid muddying it.
        let baseOpacity = 0.40 - normDist * 0.27     // 0.40 → 0.13
        let baseBlur = normDist * 2.2                // 0pt → 2.2pt
        let baseScale = 1.0 - normDist * 0.15        // 1.0 → 0.85

        // Per-tile phase so motion isn't synchronized across the grid.
        let phase = Double(row * cols + col) * 0.7

        // Drift fades as recoil takes over — at recoilProgress=1 there's
        // effectively no drift left.
        let driftMul = max(0.0, 1.0 - Double(recoilProgress) * 1.5)
        let stakesGate = isStakes ? 1.0 : 0.0
        let driftX = sin(t * driftFreqX + phase) * 4.0 * driftMul * stakesGate
        let driftY = cos(t * driftFreqY + phase) * 3.0 * driftMul * stakesGate

        // Pulse fades on the same curve as drift — apps stop breathing
        // when defeated.
        let pulse = sin(t * breathFreq + phase * 0.3) * 0.08 * driftMul * stakesGate

        // Recoil: push outward from center by 30pt × normDist × progress.
        let unitX = dist > 0.001 ? dy / dist : 0     // dy = column delta = horizontal axis
        let unitY = dist > 0.001 ? dx / dist : 0     // dx = row delta = vertical axis
        let recoilX = unitX * 30.0 * normDist * Double(recoilProgress)
        let recoilY = unitY * 30.0 * normDist * Double(recoilProgress)

        // Combined opacity: base × pulse × recoil-halve × plan-fade.
        let recoilOpacityMul = 1.0 - 0.5 * Double(recoilProgress)
        // Rev 4: plan beat pushes the grid further into the background
        // (0.45 → 0.20) so the new RECLAIMED hero + 2-color life bar own
        // the focus. Effective max ~0.40 × 0.20 = 0.08.
        let planOpacityMul = isDefeated ? 0.20 : 1.0
        let opacity = (baseOpacity + pulse) * recoilOpacityMul * planOpacityMul

        Image(logoName)
            .resizable()
            .scaledToFit()
            .frame(width: nominalTileSize, height: nominalTileSize)
            .scaleEffect(baseScale)
            .opacity(opacity)
            .blur(radius: baseBlur + Double(recoilProgress) * 0.8)
            .saturation(1.0 - Double(recoilProgress) * 0.45)
            .offset(x: CGFloat(driftX + recoilX), y: CGFloat(driftY + recoilY))
    }
}

// MARK: - Notification Priming
//
// Sells the value of notifications BEFORE the system prompt fires.
// Cold prompts convert at ~40%; primed prompts at 70-80%+.

struct OnboardingNotificationPrimingView: View {
    let onResult: (Bool) -> Void

    @State private var headlineVisible = false
    @State private var feedCardVisible = false
    @State private var memoCardVisible = false
    @State private var captionVisible = false
    @State private var ctaVisible = false
    @State private var requesting = false
    @State private var permissionTask: Task<Void, Never>?
    @State private var showTimeoutError = false
    /// Once the user denies notifications, iOS won't re-prompt — we have to
    /// deep-link to Settings instead.
    @State private var previouslyDenied = false

    var body: some View {
        ZStack {
            OB.bg.ignoresSafeArea()

            notifPrimingAtmosphere

            VStack(alignment: .leading, spacing: 0) {
                VStack(alignment: .leading, spacing: 12) {
                    OBEyebrow(text: "TWO KINDS OF NUDGES")
                    Text("One pulls you in.\nOne pulls you out.")
                        .font(.system(size: 38, weight: .heavy, design: .rounded))
                        .foregroundStyle(OB.fg)
                        .lineSpacing(1)
                        .kerning(-0.5)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .padding(.horizontal, 28)
                .padding(.top, 14)
                .opacity(headlineVisible ? 1 : 0)
                .offset(y: headlineVisible ? 0 : 8)

                Spacer(minLength: 28)

                VStack(spacing: 18) {
                    NotifMockupCard(
                        variant: .feed,
                        appIcon: Image("logo-tiktok"),
                        appName: "TikTok",
                        bodyText: "🔥 Your For You page is moving. Come see what you missed."
                    )
                    .opacity(feedCardVisible ? 0.55 : 0)
                    .scaleEffect(feedCardVisible ? 0.97 : 0.92)
                    .rotationEffect(.degrees(feedCardVisible ? -3 : 0))
                    .offset(y: feedCardVisible ? 0 : -40)

                    NotifMockupCard(
                        variant: .memo,
                        appIcon: Image("app-icon"),
                        appName: "Memo",
                        bodyText: "You earned 12 min of TikTok. Tap to unlock."
                    )
                    .opacity(memoCardVisible ? 1 : 0)
                    .rotationEffect(.degrees(memoCardVisible ? 1 : 0))
                    .offset(y: memoCardVisible ? 0 : 30)
                }
                .padding(.horizontal, 24)

                Spacer(minLength: 20)

                VStack(alignment: .leading, spacing: 10) {
                    Text("The feed nudges to pull you back. Memo nudges to give you time back.")
                        .font(.system(size: 15, weight: .semibold, design: .rounded))
                        .foregroundStyle(OB.fg2)
                        .lineSpacing(2)
                        .fixedSize(horizontal: false, vertical: true)

                    HStack(spacing: 6) {
                        Image(systemName: "lock.fill")
                            .font(.system(size: 10, weight: .heavy))
                        Text("No spam. Just unlocks, streak saves, and patrol reminders.")
                            .font(.system(size: 12, weight: .semibold, design: .rounded))
                    }
                    .foregroundStyle(OB.fg3)
                }
                .padding(.horizontal, 28)
                .padding(.bottom, 14)
                .opacity(captionVisible ? 1 : 0)
                .offset(y: captionVisible ? 0 : 6)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .safeAreaInset(edge: .bottom) {
            VStack(spacing: 8) {
                if previouslyDenied {
                    Text("Permission was denied earlier — open Settings to enable.")
                        .font(.system(size: 12, weight: .semibold, design: .rounded))
                        .foregroundStyle(OB.fg2)
                        .multilineTextAlignment(.center)
                } else if showTimeoutError {
                    Text("Couldn't request permission. Tap to retry.")
                        .font(.system(size: 12, weight: .semibold, design: .rounded))
                        .foregroundStyle(OB.coral)
                        .multilineTextAlignment(.center)
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
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 17)
                                .background(OB.accent, in: RoundedRectangle(cornerRadius: 14))
                        } else {
                            Text(buttonTitle)
                                .font(.system(size: 17, weight: .bold))
                                .foregroundStyle(.white)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 17)
                                .background(OB.accent, in: RoundedRectangle(cornerRadius: 14))
                        }
                    }
                }
                .buttonStyle(.plain)
                .disabled(requesting)

                Button {
                    Analytics.onboardingStep(step: "notificationsSkipped")
                    permissionTask?.cancel()
                    onResult(false)
                } label: {
                    Text("Not now")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(OB.fg2)
                        .padding(.vertical, 6)
                }
            }
            .padding(.horizontal, 24)
            .padding(.bottom, 18)
            .opacity(ctaVisible ? 1 : 0)
            .offset(y: ctaVisible ? 0 : 8)
        }
        .preferredColorScheme(.dark)
        .onDisappear { permissionTask?.cancel() }
        .onAppear { startEntrance() }
    }

    private var notifPrimingAtmosphere: some View {
        ZStack {
            Circle()
                .fill(OB.accent.opacity(0.14))
                .frame(width: 280, height: 280)
                .blur(radius: 76)
                .offset(x: 130, y: -200)

            Circle()
                .fill(OB.coral.opacity(0.08))
                .frame(width: 220, height: 220)
                .blur(radius: 70)
                .offset(x: -140, y: 220)
        }
    }

    private func startEntrance() {
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.10) {
            withAnimation(.easeOut(duration: 0.4)) { headlineVisible = true }
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.40) {
            withAnimation(.spring(response: 0.55, dampingFraction: 0.82)) {
                feedCardVisible = true
            }
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.75) {
            withAnimation(.spring(response: 0.50, dampingFraction: 0.78)) {
                memoCardVisible = true
            }
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.30) {
            UIImpactFeedbackGenerator(style: .light).impactOccurred()
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.20) {
            withAnimation(.easeOut(duration: 0.35)) { captionVisible = true }
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.45) {
            withAnimation(.easeOut(duration: 0.4)) { ctaVisible = true }
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

    private var buttonTitle: String {
        if previouslyDenied { return "Open Settings" }
        if showTimeoutError { return "Try Again" }
        return "Let Memo nudge me"
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

// MARK: - Notification Card Mockup
//
// File-local lock-screen-style notification mockup used by
// OnboardingNotificationPrimingView. Two variants: dimmed/tilted "feed"
// (the algorithmic enemy) vs bright "memo" (the bouncer). Built fresh
// rather than extracted to Components/ — onboarding-only.

private struct NotifMockupCard: View {
    enum Variant { case feed, memo }

    let variant: Variant
    let appIcon: Image
    let appName: String
    let bodyText: String

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            appIcon
                .resizable()
                .scaledToFill()
                .frame(width: 38, height: 38)
                .clipShape(RoundedRectangle(cornerRadius: 9))

            VStack(alignment: .leading, spacing: 4) {
                HStack(alignment: .firstTextBaseline) {
                    Text(appName)
                        .font(.brand(size: 14, weight: .heavy))
                        .foregroundStyle(variant == .memo ? OB.fg : OB.fg2)

                    Spacer()

                    Text("now")
                        .font(.brand(size: 12, weight: .medium))
                        .foregroundStyle(OB.fg3)
                }

                Text(bodyText)
                    .font(.brand(size: 14, weight: variant == .memo ? .bold : .medium))
                    .foregroundStyle(variant == .memo ? OB.fg : OB.fg2)
                    .lineLimit(2)
                    .multilineTextAlignment(.leading)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background {
            ZStack {
                RoundedRectangle(cornerRadius: 22)
                    .fill(OB.surface)

                if variant == .memo {
                    RoundedRectangle(cornerRadius: 22)
                        .fill(OB.accent.opacity(0.05))
                }
            }
        }
        .overlay {
            RoundedRectangle(cornerRadius: 22)
                .stroke(
                    variant == .memo
                        ? OB.accent.opacity(0.35)
                        : Color.white.opacity(0.06),
                    lineWidth: variant == .memo ? 1.5 : 1
                )
        }
        .shadow(
            color: variant == .memo ? OB.accent.opacity(0.32) : .clear,
            radius: variant == .memo ? 24 : 0,
            y: variant == .memo ? 10 : 0
        )
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
        "My Brain Age is \(brainAge)! Test yours with Memo"
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
        dailyScreenTimeHours: 4.3,
        projectedScreenTimeHours: 50200,
        projectionIsEstimate: false,
        receiptCount: 4,
        protectedPriority: .sleep,
        dangerWindow: .lateNight,
        onContinue: {}
    )
}

#Preview("Personal Solution — no goals (fallback)") {
    OnboardingPersonalSolutionView(
        userGoals: [],
        brainAge: nil,
        userAge: 0,
        dailyScreenTimeHours: 4,
        projectedScreenTimeHours: 51100,
        projectionIsEstimate: true,
        receiptCount: 0,
        protectedPriority: nil,
        dangerWindow: nil,
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

// MARK: - Shared Tokens for v2 Onboarding Pages
//
// Mirror the FO design tokens from FocusOnboardingPages.swift so the Industry
// Scare → Empathy → Goals → Pain Cards → … → Plan Reveal arc all reads as one
// coherent visual system in the dark/cool v2.0 palette.

enum OB {
    static let bg = Color(red: 0.039, green: 0.039, blue: 0.059)         // #0A0A0F
    static let surface = Color(red: 0.078, green: 0.078, blue: 0.122)    // #14141F
    static let border = Color.white.opacity(0.08)
    static let fg = Color.white.opacity(0.94)
    static let fg2 = Color.white.opacity(0.62)
    static let fg3 = Color.white.opacity(0.40)
    static let accent = Color(red: 0.408, green: 0.565, blue: 0.996)     // #6890FE
    static let coral = Color(red: 0.980, green: 0.420, blue: 0.349)      // #FA6B59
    static let memoPurple = Color(red: 0.722, green: 0.341, blue: 0.961) // #B857F5
    static let success = Color(red: 0.0, green: 0.820, blue: 0.620)      // #00D19E
    static let amber = Color(red: 1.0, green: 0.761, blue: 0.278)        // #FFC247
}

struct OBEyebrow: View {
    let text: String
    var color: Color = OB.accent
    var body: some View {
        Text(text)
            .font(.brand(size: 13, weight: .bold))
            .tracking(1.0)
            .foregroundStyle(color)
    }
}

struct OBContinueButton: View {
    let title: String
    let action: () -> Void
    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.system(size: 17, weight: .bold))
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 17)
                .background(OB.accent, in: RoundedRectangle(cornerRadius: 14))
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Pain Cards (NEW)
//
// Sits after Goals. Six specific Gen-Z pain statements presented one at a time
// inside a tall "receipt slip" with a torn perforation along its TOP edge. User
// taps "Caught me" to confess (CAUGHT stamp drops in the lower-right and the
// slip slides into the saved-receipt back-stack) or "Not me" to flick it away.
// Tap-based instead of swipe so gesture conflicts with TabView don't strand
// the user.

struct OnboardingPainCardsView: View {
    let onContinue: (Int) -> Void

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var currentIndex: Int = 0
    @State private var receiptCount: Int = 0
    @State private var savedReceipts: [String] = []
    @State private var cardOffsetX: CGFloat = 0
    @State private var cardOffsetY: CGFloat = 0
    @State private var cardRotation: Double = 0
    @State private var cardScale: CGFloat = 1
    @State private var cardOpacity: Double = 1
    @State private var headlineVisible = false
    @State private var stackVisible = false
    @State private var mascotVisible = false
    @State private var buttonsVisible = false
    @State private var showCaughtStamp = false
    @State private var isAnimating = false

    private let painCards: [String] = [
        "I check my phone before I check the time",
        "I forget what I just read on a page",
        "I uninstall TikTok, then redownload by Friday",
        "I scroll until 2am even when I know better",
        "I open the same 4 apps in a loop",
        "I can't sit through a movie without my phone"
    ]

    private var currentCard: String {
        guard currentIndex < painCards.count else { return painCards.last ?? "" }
        return painCards[currentIndex]
    }

    // Cap at 3 visible saved slips (UI-SPEC §"Page 2 — Pain Cards" line ~431).
    // Empty state: render no back slips when nothing has been caught yet — per
    // CONTEXT D-01f, ambient filler text is meaningless and should be dropped.
    private var backReceipts: [ReceiptBackItem] {
        let saved = Array(savedReceipts.suffix(3).reversed())
        return saved.enumerated().map { index, _ in
            ReceiptBackItem(id: "saved-\(savedReceipts.count)-\(index)")
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            VStack(alignment: .leading, spacing: 10) {
                Text("Which ones are yours?")
                    .font(.brand(size: 31, weight: .heavy))
                    .foregroundStyle(OB.fg)
                    .lineSpacing(1)
                    .kerning(-0.4)

                Text("Tap what feels painfully familiar. Memo uses it to build your fight plan.")
                    .font(.brand(size: 15, weight: .semibold))
                    .foregroundStyle(OB.fg2)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(.horizontal, 28)
            .padding(.top, 16)
            .opacity(headlineVisible ? 1 : 0)
            .offset(y: headlineVisible ? 0 : 8)

            Spacer(minLength: 28)

            receiptStack
                .padding(.horizontal, 24)
                .opacity(stackVisible ? 1 : 0)
                .offset(y: stackVisible ? 0 : 24)

            Spacer(minLength: 0)

            HStack(spacing: 12) {
                Button(action: { handleTap(caught: false) }) {
                    Text("Not me")
                        .font(.brand(size: 17, weight: .heavy))
                        .foregroundStyle(OB.fg2)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 18)
                        .background(
                            RoundedRectangle(cornerRadius: 14)
                                .fill(OB.surface)
                                .overlay(
                                    RoundedRectangle(cornerRadius: 14)
                                        .stroke(Color.white.opacity(0.10), lineWidth: 1.5)
                                )
                                .shadow(color: .black.opacity(0.5), radius: 0, x: 0, y: 4)
                        )
                }
                .buttonStyle(.plain)
                .disabled(isAnimating)

                Button(action: { handleTap(caught: true) }) {
                    Text("Caught me")
                        .font(.brand(size: 17, weight: .heavy))
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 18)
                        .background(
                            RoundedRectangle(cornerRadius: 14)
                                .fill(OB.accent)
                                .overlay(
                                    RoundedRectangle(cornerRadius: 14)
                                        .stroke(Color.white.opacity(0.18), lineWidth: 1.5)
                                )
                                .shadow(color: OB.accent.opacity(0.4), radius: 12, y: 4)
                                .shadow(color: .black.opacity(0.5), radius: 0, x: 0, y: 4)
                        )
                }
                .buttonStyle(.plain)
                .disabled(isAnimating)
            }
            .padding(.horizontal, 28)
            .padding(.top, 18)
            .padding(.bottom, 18)
            .opacity(buttonsVisible ? 1 : 0)
            .offset(y: buttonsVisible ? 0 : 10)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(OB.bg.ignoresSafeArea())
        .preferredColorScheme(.dark)
        .dynamicTypeSize(...DynamicTypeSize.xxLarge)
        .onAppear {
            startEntrance()
        }
    }

    // The receipt stack: dim back slips (capped at 3) + the active front slip,
    // with the mascot peeking from the bottom-leading edge so its head/glasses
    // hover behind the stack but never cross into the active confession or
    // the action buttons below.
    private var receiptStack: some View {
        ZStack(alignment: .bottomLeading) {
            ZStack(alignment: .top) {
                receiptBackStack

                PainReceiptSlip(
                    progressText: "\(currentIndex + 1) of \(painCards.count)",
                    label: "current receipt",
                    confession: currentCard,
                    showCaughtStamp: showCaughtStamp,
                    isActive: true
                )
                .scaleEffect(cardScale, anchor: .center)
                .rotationEffect(.degrees(cardRotation))
                .offset(x: cardOffsetX, y: cardOffsetY)
                .opacity(cardOpacity)
                .animation(reduceMotion ? .easeOut(duration: 0.18) : .spring(response: 0.48, dampingFraction: 0.82), value: currentIndex)
            }
            .frame(maxWidth: .infinity)

            Image("mascot-thinking")
                .renderingMode(.original)
                .resizable()
                .scaledToFit()
                .frame(height: 96)
                .rotationEffect(.degrees(mascotVisible ? -4 : -7))
                .scaleEffect(mascotVisible ? 1 : 0.9)
                .opacity(mascotVisible ? 1 : 0)
                .offset(x: 4, y: 18)
                .shadow(color: .black.opacity(0.35), radius: 10, y: 8)
                .accessibilityHidden(true)
        }
    }

    private var receiptBackStack: some View {
        ZStack {
            let layers = Array(backReceipts.prefix(3).enumerated())
            ForEach(Array(layers.reversed()), id: \.element.id) { index, item in
                PainReceiptSlip(
                    progressText: "",
                    label: "saved receipt",
                    confession: "",
                    showCaughtStamp: false,
                    isActive: false
                )
                .id(item.id)
                .rotationEffect(.degrees(backLayerRotation(index)))
                .offset(x: backLayerX(index), y: backLayerY(index))
                .opacity(backLayerOpacity(index))
                .accessibilityHidden(true)
            }
        }
    }

    private func startEntrance() {
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.10) {
            withAnimation(reduceMotion ? .easeOut(duration: 0.18) : .easeOut(duration: 0.38)) {
                headlineVisible = true
            }
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.32) {
            withAnimation(reduceMotion ? .easeOut(duration: 0.18) : .spring(response: 0.50, dampingFraction: 0.82)) {
                stackVisible = true
            }
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.48) {
            withAnimation(reduceMotion ? .easeOut(duration: 0.18) : .spring(response: 0.46, dampingFraction: 0.80)) {
                mascotVisible = true
            }
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.78) {
            withAnimation(reduceMotion ? .easeOut(duration: 0.18) : .easeOut(duration: 0.30)) {
                buttonsVisible = true
            }
        }
    }

    private func handleTap(caught: Bool) {
        guard !isAnimating else { return }
        isAnimating = true

        let answeredCard = currentCard
        let nextReceiptCount = receiptCount + (caught ? 1 : 0)
        receiptCount = nextReceiptCount
        // Haptic fires BEFORE the visual animation per UI-SPEC. Both Reduce
        // Motion paths preserve haptic feedback (D-11).
        UIImpactFeedbackGenerator(style: caught ? .medium : .light).impactOccurred()

        if reduceMotion {
            // Reduce Motion: no scale-pop, no slide. Stamp shows at full scale
            // via opacity fade-in; slip exits via a 0.18s opacity fade.
            if caught { showCaughtStamp = true }
            withAnimation(.easeOut(duration: 0.18)) {
                cardOpacity = 0
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.18) {
                advance(after: answeredCard, caught: caught, finalReceiptCount: nextReceiptCount)
            }
            return
        }

        if caught {
            // Stamp scale-pop: 0.72 → 1.08 → 1.0 over 0.18s, hold, then slip
            // slides back into the stack with a +5° rotation.
            withAnimation(.spring(response: 0.18, dampingFraction: 0.62)) {
                showCaughtStamp = true
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.18) {
                withAnimation(.easeInOut(duration: 0.26)) {
                    cardOffsetX = 10
                    cardOffsetY = 18
                    cardRotation = 5
                    cardScale = 0.94
                    cardOpacity = 0.78
                }
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.46) {
                advance(after: answeredCard, caught: true, finalReceiptCount: nextReceiptCount)
            }
        } else {
            // Not me: flick left, rotate -9°, fade to 0 over 0.30s.
            withAnimation(.easeIn(duration: 0.30)) {
                cardOffsetX = -340
                cardRotation = -9
                cardOpacity = 0
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.30) {
                advance(after: answeredCard, caught: false, finalReceiptCount: nextReceiptCount)
            }
        }
    }

    private func advance(after answeredCard: String, caught: Bool, finalReceiptCount: Int) {
        if caught {
            savedReceipts.append(answeredCard)
        }

        if currentIndex < painCards.count - 1 {
            currentIndex += 1
            showCaughtStamp = false
            cardRotation = 0
            cardScale = reduceMotion ? 1 : 0.98
            cardOffsetX = 0
            cardOffsetY = reduceMotion ? 0 : 24
            cardOpacity = 0
            withAnimation(reduceMotion ? .easeOut(duration: 0.18) : .spring(response: 0.45, dampingFraction: 0.82)) {
                cardOffsetY = 0
                cardScale = 1
                cardOpacity = 1
            }
            isAnimating = false
        } else {
            Analytics.onboardingStep(step: "painCards")
            onContinue(finalReceiptCount)
        }
    }

    // Back-stack geometry per UI-SPEC §"Page 2 — Pain Cards" visual spec table.
    // Slip 1: rot +5°, y +18, x +10, opacity 0.78
    // Slip 2: rot -4°, y +36, x -8,  opacity 0.55
    // Slip 3: rot +8°, y +54, x +14, opacity 0.35  (only if ≥3 caught)
    private func backLayerRotation(_ index: Int) -> Double {
        [5, -4, 8][min(index, 2)]
    }

    private func backLayerX(_ index: Int) -> CGFloat {
        [10, -8, 14][min(index, 2)]
    }

    private func backLayerY(_ index: Int) -> CGFloat {
        [18, 36, 54][min(index, 2)]
    }

    private func backLayerOpacity(_ index: Int) -> Double {
        [0.78, 0.55, 0.35][min(index, 2)]
    }
}

private struct ReceiptBackItem {
    let id: String
}

// MARK: - Pain Receipt Slip
//
// Tall receipt slip (210pt min-height) with a dotted perforation line along
// the TOP edge so the slip reads as a torn-off coupon header rather than a
// content card with a divider through its middle. Active state shows the
// confession text large in the body; back-stack state shows ONLY the dim
// "saved receipt" label — the confession body is intentionally blank to
// kill the meaningless "feed loop" filler from the first Codex pass (D-01f).
private struct PainReceiptSlip: View {
    let progressText: String
    let label: String
    let confession: String
    let showCaughtStamp: Bool
    let isActive: Bool

    var body: some View {
        ZStack(alignment: .bottomTrailing) {
            VStack(alignment: .leading, spacing: 10) {
                // Micro progress + active label — only render on the active slip.
                // Brand 11pt semibold, lowercase ("3 of 6") to kill the "1 0F 6"
                // misread that the first Codex pass shipped with a monospaced +
                // uppercase treatment (D-01a).
                if isActive && !progressText.isEmpty {
                    HStack(alignment: .firstTextBaseline, spacing: 8) {
                        Text(progressText)
                            .font(.brand(size: 11, weight: .semibold))
                            .foregroundStyle(OB.fg3)

                        Text("·")
                            .font(.brand(size: 11, weight: .semibold))
                            .foregroundStyle(OB.fg3)

                        Text(label)
                            .font(.brand(size: 12, weight: .medium))
                            .foregroundStyle(OB.fg3)
                    }
                } else {
                    // Back slips: ONLY the dim "saved receipt" label, no body
                    // text. Empty body is intentional — see D-01f.
                    Text(label)
                        .font(.brand(size: 12, weight: .medium))
                        .foregroundStyle(OB.fg3)
                }

                if isActive {
                    Text(confession)
                        .font(.brand(size: 22, weight: .heavy))
                        .foregroundStyle(OB.fg)
                        .lineSpacing(2)
                        .kerning(-0.4)
                        .multilineTextAlignment(.leading)
                        .fixedSize(horizontal: false, vertical: true)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .accessibilityLabel(confession)
                }
            }
            .padding(.horizontal, 18)
            .padding(.top, 22) // 18pt vertical + 4pt clearance below the perforation dashes
            .padding(.bottom, 18)
            .frame(maxWidth: .infinity, minHeight: 210, alignment: .topLeading)
            .background {
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(OB.surface)
                    .overlay {
                        RoundedRectangle(cornerRadius: 16, style: .continuous)
                            .stroke(isActive ? OB.accent.opacity(0.45) : Color.white.opacity(0.08),
                                    lineWidth: isActive ? 1.5 : 1)
                    }
                    .shadow(color: isActive ? OB.accent.opacity(0.18) : .black.opacity(0.32),
                            radius: isActive ? 22 : 14, y: 10)
                    // Perforation rides on the TOP edge — inset 16pt from each
                    // side, dotted [2,5] white@14% — so the slip reads as a
                    // torn-off coupon header (D-01e).
                    .overlay(alignment: .top) {
                        ReceiptPerforation()
                            .stroke(Color.white.opacity(0.14),
                                    style: StrokeStyle(lineWidth: 1, dash: [2, 5]))
                            .frame(height: 1)
                            .padding(.horizontal, 16)
                            .padding(.top, 11)
                    }
            }

            if showCaughtStamp && isActive {
                CaughtStamp()
                    .padding(.trailing, 18)
                    .padding(.bottom, 18)
                    .transition(.scale(scale: 0.72).combined(with: .opacity))
            }
        }
        .accessibilityElement(children: .combine)
    }
}

private struct CaughtStamp: View {
    var body: some View {
        Text("CAUGHT")
            .font(.system(size: 22, weight: .heavy, design: .monospaced))
            .tracking(1.8)
            .foregroundStyle(OB.coral)
            .padding(.horizontal, 12)
            .padding(.vertical, 5)
            .overlay {
                RoundedRectangle(cornerRadius: 6, style: .continuous)
                    .stroke(OB.coral.opacity(0.72), lineWidth: 2)
            }
            .rotationEffect(.degrees(-8))
    }
}

// Top-edge perforation: draws a horizontal line at y = 0 of the bounding rect.
// The frame this is rendered into is already inset 16pt from each side and
// padded 11pt down from the slip's top edge by the parent layout.
private struct ReceiptPerforation: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.move(to: CGPoint(x: rect.minX, y: 0))
        path.addLine(to: CGPoint(x: rect.maxX, y: 0))
        return path
    }
}

// MARK: - Comparison (NEW)
//
// Sits after Brain Age Reveal. Two-column WITHOUT/WITH contrast personalized
// using the user's pickup count, daily hours, and brain age from earlier
// pages. Makes the cost of inaction concrete in their own terms.

struct OnboardingComparisonView: View {
    let pickupCount: Int
    let dailyHours: Double
    let brainAge: Int?
    let onContinue: () -> Void

    @State private var headlineVisible = false
    @State private var rowsVisible: [Bool] = [false, false, false, false]
    @State private var footerVisible = false

    private struct Row { let without: String; let with: String }

    private var rows: [Row] {
        let pickups = max(pickupCount, 80)
        let hrs = max(dailyHours, 1)
        // Mirrors OnboardingPersonalSolutionView.memoReductionFraction
        // (0.75) — the comparison row must claim the same reclaim as the
        // plan-reveal page right before it, or the funnel reads off-key.
        let saved = max(hrs * 0.75, 0.5)
        let brainAgeLine = brainAge.map { "Brain Age \($0) drifts up" } ?? "Brain rot keeps compounding"
        return [
            Row(without: "Open the same apps \(pickups)\u{00D7}", with: "Open after training"),
            Row(without: "\(formatHrs(hrs)) leaks into the feed", with: "\(formatHrs(saved)) back in play"),
            Row(without: brainAgeLine, with: "Train the score down"),
            Row(without: "You're the product", with: "You're the customer")
        ]
    }

    private func formatHrs(_ h: Double) -> String {
        let rounded = h.rounded()
        if abs(h - rounded) < 0.05 { return "\(Int(rounded))h" }
        return String(format: "%.1fh", h)
    }

    var body: some View {
        ZStack {
            OB.bg.ignoresSafeArea()

            comparisonAtmosphere

            VStack(alignment: .leading, spacing: 0) {
                VStack(alignment: .leading, spacing: 10) {
                    Text("Same phone.\nDifferent rules.")
                        .font(.system(size: 37, weight: .heavy, design: .rounded))
                        .foregroundStyle(OB.fg)
                        .lineSpacing(1)
                        .kerning(-0.5)
                        .fixedSize(horizontal: false, vertical: true)

                    Text("Without Memo, the feed wins by default. With Memo, every open costs reps.")
                        .font(.system(size: 16, weight: .semibold, design: .rounded))
                        .foregroundStyle(OB.fg2)
                        .lineSpacing(3)
                        .fixedSize(horizontal: false, vertical: true)
                        .padding(.top, 2)
                }
                .padding(.horizontal, 28)
                .padding(.top, 24)
                .opacity(headlineVisible ? 1 : 0)
                .offset(y: headlineVisible ? 0 : 8)

                Spacer().frame(height: 26)

                splitLedger
                    .padding(.horizontal, 24)

                Spacer()

                Text("Memo doesn't ask for more willpower. It changes the rules.")
                    .font(.system(size: 15, weight: .heavy, design: .rounded))
                    .foregroundStyle(OB.fg)
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: .infinity)
                    .padding(.horizontal, 34)
                    .padding(.bottom, 14)
                    .opacity(footerVisible ? 1 : 0)
                    .offset(y: footerVisible ? 0 : 6)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .safeAreaInset(edge: .bottom) {
            OBContinueButton(title: "Why Memo wins", action: {
                Analytics.onboardingStep(step: "comparison")
                onContinue()
            })
            .padding(.horizontal, 24)
            .padding(.bottom, 18)
        }
        .preferredColorScheme(.dark)
        .onAppear { startEntrance() }
    }

    private var comparisonAtmosphere: some View {
        ZStack {
            Circle()
                .fill(OB.coral.opacity(0.12))
                .frame(width: 260, height: 260)
                .blur(radius: 64)
                .offset(x: -150, y: -160)

            Circle()
                .fill(OB.accent.opacity(0.15))
                .frame(width: 300, height: 300)
                .blur(radius: 70)
                .offset(x: 160, y: 140)
        }
    }

    private var splitLedger: some View {
        VStack(spacing: 0) {
            HStack(spacing: 0) {
                Text("Without Memo")
                    .font(.system(size: 12, weight: .heavy, design: .rounded))
                    .foregroundStyle(OB.coral)
                    .frame(maxWidth: .infinity, alignment: .leading)

                Text("With Memo")
                    .font(.system(size: 12, weight: .heavy, design: .rounded))
                    .foregroundStyle(OB.accent)
                    .frame(maxWidth: .infinity, alignment: .trailing)
            }
            .textCase(.uppercase)
            .tracking(1.1)
            .padding(.bottom, 13)

            Rectangle()
                .fill(OB.border)
                .frame(height: 1)

            ForEach(Array(rows.enumerated()), id: \.offset) { index, row in
                comparisonRow(index: index, row: row)
                if index < rows.count - 1 {
                    Rectangle()
                        .fill(OB.border)
                        .frame(height: 1)
                }
            }
        }
    }

    private func comparisonRow(index: Int, row: Row) -> some View {
        let isVisible = index < rowsVisible.count && rowsVisible[index]

        return HStack(alignment: .center, spacing: 0) {
            Text(row.without)
                .font(.system(size: 16, weight: .heavy, design: .rounded))
                .foregroundStyle(index == 3 ? OB.coral : OB.fg.opacity(0.82))
                .lineSpacing(2)
                .fixedSize(horizontal: false, vertical: true)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.trailing, 14)

            ZStack {
                Rectangle()
                    .fill(OB.border)
                    .frame(width: 1)

                Circle()
                    .fill(index == 3 ? OB.accent : OB.bg)
                    .frame(width: 9, height: 9)
                    .overlay {
                        Circle()
                            .stroke(index == 3 ? OB.accent : OB.border, lineWidth: 1)
                    }
            }
            .frame(width: 22)

            Text(row.with)
                .font(.system(size: 16, weight: .heavy, design: .rounded))
                .foregroundStyle(index == 3 ? OB.accent : OB.fg)
                .lineSpacing(2)
                .fixedSize(horizontal: false, vertical: true)
                .frame(maxWidth: .infinity, alignment: .trailing)
                .padding(.leading, 14)
        }
        .padding(.vertical, 18)
        .opacity(isVisible ? 1 : 0)
        .offset(y: isVisible ? 0 : 12)
    }

    private func startEntrance() {
        rowsVisible = Array(repeating: false, count: rows.count)
        footerVisible = false
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            withAnimation(.easeOut(duration: 0.4)) { headlineVisible = true }
        }
        for i in 0..<rows.count {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.42 + Double(i) * 0.12) {
                withAnimation(.spring(response: 0.5, dampingFraction: 0.82)) {
                    rowsVisible[i] = true
                }
            }
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.08) {
            withAnimation(.easeOut(duration: 0.4)) { footerVisible = true }
        }
    }
}

// MARK: - Social Proof / Founder (NEW)
//
// Pivoted from "testimonials" to David vs Goliath since Memori has no v2 reviews
// yet. The indie founder origin + leaderboard preview together make the
// social-proof case stronger than fake testimonials would. Surfaces the
// Compete tab existence which is currently buried.

struct OnboardingSocialProofView: View {
    let onContinue: () -> Void

    @State private var headlineVisible = false
    @State private var quoteVisible = false
    @State private var leaderboardVisible = false
    @State private var taglineVisible = false

    private let leaderboardPreview: [(rank: Int, name: String, score: Int)] = [
        (1, "sarah_m_", 921),
        (2, "noahduke", 887),
        (3, "luc.codes", 852),
        (47, "you?", 0)
    ]

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            VStack(alignment: .leading, spacing: 8) {
                OBEyebrow(text: "NOT A CORPORATION")

                (Text("Built by ") + Text("one developer").foregroundColor(OB.accent) + Text("."))
                    .font(.system(size: 30, weight: .heavy, design: .rounded))
                    .foregroundStyle(OB.fg)
                    .lineSpacing(1)
                    .kerning(-0.4)
                    .fixedSize(horizontal: false, vertical: true)

                Text("Up against an industry spending $57B/year on you.")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(OB.fg2)
                    .padding(.top, 4)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(.horizontal, 28)
            .padding(.top, 24)
            .opacity(headlineVisible ? 1 : 0)
            .offset(y: headlineVisible ? 0 : 8)

            Spacer().frame(height: 22)

            // Founder pull-quote
            HStack(alignment: .top, spacing: 14) {
                Rectangle()
                    .fill(OB.accent)
                    .frame(width: 2)

                VStack(alignment: .leading, spacing: 8) {
                    Text("\u{201C}I built Memo because I couldn't put TikTok down either. No VC. No ads. Just an app on your side.\u{201D}")
                        .font(.system(size: 16, weight: .medium).italic())
                        .foregroundStyle(OB.fg)
                        .lineSpacing(3)
                        .fixedSize(horizontal: false, vertical: true)

                    Text("\u{2014} Dylan, founder")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(OB.fg3)
                }
            }
            .padding(.horizontal, 28)
            .opacity(quoteVisible ? 1 : 0)
            .offset(y: quoteVisible ? 0 : 6)

            Spacer().frame(height: 24)

            // Leaderboard preview
            VStack(alignment: .leading, spacing: 10) {
                HStack {
                    OBEyebrow(text: "LEADERBOARDS")
                    Spacer()
                    HStack(spacing: 4) {
                        Circle().fill(OB.success).frame(width: 6, height: 6)
                            .shadow(color: OB.success, radius: 3)
                        Text("LIVE")
                            .font(.system(size: 10, weight: .heavy, design: .monospaced))
                            .tracking(1.2)
                            .foregroundStyle(OB.success)
                    }
                    .padding(.horizontal, 8).padding(.vertical, 3)
                    .background(Capsule().fill(OB.success.opacity(0.12)))
                }

                VStack(spacing: 0) {
                    ForEach(Array(leaderboardPreview.enumerated()), id: \.offset) { i, entry in
                        leaderboardRow(rank: entry.rank, name: entry.name, score: entry.score, isYou: entry.name == "you?")
                        if i < leaderboardPreview.count - 1 {
                            Divider().overlay(OB.border)
                        }
                    }
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 4)
                .background(
                    RoundedRectangle(cornerRadius: 14)
                        .fill(OB.surface)
                        .overlay(
                            RoundedRectangle(cornerRadius: 14)
                                .stroke(OB.border, lineWidth: 1)
                        )
                )
            }
            .padding(.horizontal, 28)
            .opacity(leaderboardVisible ? 1 : 0)
            .offset(y: leaderboardVisible ? 0 : 8)

            Spacer()

            Text("Compete weekly. Climb monthly. Live now.")
                .font(.system(size: 12, weight: .heavy, design: .monospaced))
                .tracking(0.8)
                .foregroundStyle(OB.fg3)
                .frame(maxWidth: .infinity, alignment: .center)
                .padding(.bottom, 14)
                .opacity(taglineVisible ? 1 : 0)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .background(OB.bg.ignoresSafeArea())
        .safeAreaInset(edge: .bottom) {
            OBContinueButton(title: "Continue", action: {
                Analytics.onboardingStep(step: "socialProof")
                onContinue()
            })
            .padding(.horizontal, 24)
            .padding(.bottom, 12)
        }
        .preferredColorScheme(.dark)
        .onAppear { startEntrance() }
    }

    private func leaderboardRow(rank: Int, name: String, score: Int, isYou: Bool) -> some View {
        HStack(spacing: 12) {
            Text("\(rank)")
                .font(.system(size: 13, weight: .heavy, design: .monospaced))
                .foregroundStyle(isYou ? OB.accent : OB.fg2)
                .frame(width: 28, alignment: .leading)

            Text(name)
                .font(.system(size: 14, weight: .semibold, design: .monospaced))
                .foregroundStyle(isYou ? OB.accent : OB.fg)

            Spacer()

            if isYou {
                Text("waiting on you")
                    .font(.system(size: 12, weight: .semibold, design: .monospaced))
                    .foregroundStyle(OB.fg3)
            } else {
                Text("\(score)")
                    .font(.system(size: 14, weight: .heavy, design: .monospaced))
                    .foregroundStyle(OB.fg)
            }
        }
        .padding(.vertical, 10)
    }

    private func startEntrance() {
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            withAnimation(.easeOut(duration: 0.4)) { headlineVisible = true }
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            withAnimation(.easeOut(duration: 0.45)) { quoteVisible = true }
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.85) {
            withAnimation(.spring(response: 0.55, dampingFraction: 0.82)) {
                leaderboardVisible = true
            }
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.4) {
            withAnimation(.easeOut(duration: 0.4)) { taglineVisible = true }
        }
    }
}

// MARK: - Differentiation / Paid Because You're The Customer
//
// Final objection-handler before paywall. This is not a values list; it is a
// pricing-positioning argument with one receipt artifact users can remember.

struct OnboardingDifferentiationView: View {
    let onContinue: () -> Void

    @State private var headlineVisible = false
    @State private var receiptVisible = false
    @State private var receiptLinesVisible: [Bool] = [false, false, false, false]
    @State private var taglineVisible = false

    private let receiptLines = [
        "NO ADS",
        "NO DATA SOLD",
        "YOU'RE THE CUSTOMER",
        "TRAIN BEFORE YOU SCROLL"
    ]

    var body: some View {
        ZStack {
            OB.bg.ignoresSafeArea()

            differentiationAtmosphere

            VStack(alignment: .leading, spacing: 0) {
                VStack(alignment: .leading, spacing: 12) {
                    (Text("Free apps\nsell you.\n") + Text("Memo works\nfor you.").foregroundColor(OB.accent))
                        .font(.system(size: 38, weight: .heavy, design: .rounded))
                        .foregroundStyle(OB.fg)
                        .lineSpacing(1)
                        .kerning(-0.5)
                        .fixedSize(horizontal: false, vertical: true)

                    Text("Social media is free because your attention pays the bill. Memo is paid because you're the customer.")
                        .font(.system(size: 16, weight: .semibold, design: .rounded))
                        .foregroundStyle(OB.fg2)
                        .lineSpacing(3)
                        .fixedSize(horizontal: false, vertical: true)
                        .padding(.top, 2)
                }
                .padding(.horizontal, 28)
                .padding(.top, 24)
                .opacity(headlineVisible ? 1 : 0)
                .offset(y: headlineVisible ? 0 : 8)

                Spacer().frame(height: 28)

                receiptArtifact
                    .padding(.horizontal, 28)
                    .opacity(receiptVisible ? 1 : 0)
                    .scaleEffect(receiptVisible ? 1 : 0.96)
                    .rotationEffect(.degrees(receiptVisible ? -1.2 : 0))

                Spacer()

                HStack(alignment: .top, spacing: 12) {
                    Image("mascot-thinking")
                        .renderingMode(.original)
                        .resizable()
                        .scaledToFit()
                        .frame(width: 54, height: 54)
                        .accessibilityHidden(true)

                    Text("Built by one developer who got tired of losing to the feed too.")
                        .font(.system(size: 15, weight: .heavy, design: .rounded))
                        .foregroundStyle(OB.fg)
                        .lineSpacing(2)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .padding(.horizontal, 28)
                .padding(.bottom, 14)
                .opacity(taglineVisible ? 1 : 0)
                .offset(y: taglineVisible ? 0 : 6)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .safeAreaInset(edge: .bottom) {
            OBContinueButton(title: "See my offer", action: {
                Analytics.onboardingStep(step: "differentiation")
                onContinue()
            })
            .padding(.horizontal, 24)
            .padding(.bottom, 18)
        }
        .preferredColorScheme(.dark)
        .onAppear { startEntrance() }
    }

    private var differentiationAtmosphere: some View {
        ZStack {
            Circle()
                .fill(OB.accent.opacity(0.15))
                .frame(width: 300, height: 300)
                .blur(radius: 78)
                .offset(x: 150, y: -180)

            Circle()
                .fill(OB.memoPurple.opacity(0.10))
                .frame(width: 250, height: 250)
                .blur(radius: 72)
                .offset(x: -150, y: 180)
        }
    }

    private var receiptArtifact: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                Text("Memo")
                    .font(.system(size: 17, weight: .heavy, design: .rounded))
                    .foregroundStyle(OB.fg)

                Spacer()

                Text("PAID, NOT FARMED")
                    .font(.system(size: 10, weight: .heavy, design: .monospaced))
                    .tracking(1.0)
                    .foregroundStyle(OB.fg3)
            }
            .padding(.bottom, 16)

            Rectangle()
                .fill(OB.border)
                .frame(height: 1)

            ForEach(Array(receiptLines.enumerated()), id: \.offset) { index, line in
                receiptLine(index: index, text: line)
                if index < receiptLines.count - 1 {
                    Rectangle()
                        .fill(OB.border)
                        .frame(height: 1)
                }
            }
        }
        .padding(18)
        .background {
            RoundedRectangle(cornerRadius: 18)
                .fill(OB.surface)
                .overlay {
                    RoundedRectangle(cornerRadius: 18)
                        .stroke(OB.border.opacity(1.4), lineWidth: 1)
                }
                .shadow(color: .black.opacity(0.45), radius: 24, y: 16)
        }
    }

    private func receiptLine(index: Int, text: String) -> some View {
        HStack(spacing: 12) {
            Image(systemName: index == 3 ? "bolt.fill" : "checkmark")
                .font(.system(size: 13, weight: .heavy))
                .foregroundStyle(OB.accent)
                .frame(width: 18, height: 18)

            Text(text)
                .font(.system(size: 15, weight: .heavy, design: .monospaced))
                .tracking(0.5)
                .foregroundStyle(OB.fg)

            Spacer()
        }
        .padding(.vertical, 15)
        .opacity(receiptLinesVisible[index] ? 1 : 0)
        .offset(x: receiptLinesVisible[index] ? 0 : -10)
    }

    private func startEntrance() {
        receiptLinesVisible = Array(repeating: false, count: receiptLines.count)
        receiptVisible = false
        taglineVisible = false

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            withAnimation(.easeOut(duration: 0.4)) { headlineVisible = true }
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.45) {
            withAnimation(.spring(response: 0.58, dampingFraction: 0.82)) {
                receiptVisible = true
            }
        }
        for i in 0..<receiptLines.count {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.62 + Double(i) * 0.11) {
                withAnimation(.spring(response: 0.5, dampingFraction: 0.82)) {
                    receiptLinesVisible[i] = true
                }
            }
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.25) {
            withAnimation(.easeOut(duration: 0.4)) { taglineVisible = true }
        }
    }
}

#if DEBUG
#Preview("Pain Cards") {
    OnboardingPainCardsView(onContinue: { _ in })
}

#Preview("Comparison") {
    OnboardingComparisonView(pickupCount: 287, dailyHours: 4.2, brainAge: 38, onContinue: {})
}

#Preview("Social Proof") {
    OnboardingSocialProofView(onContinue: {})
}

#Preview("Differentiation") {
    OnboardingDifferentiationView(onContinue: {})
}
#endif

// MARK: - Linear Congruential RNG
//
// Tiny deterministic RandomNumberGenerator used by PlanRevealBackdrop's
// permuted logo grid. Same seed → same shuffle every render, so SwiftUI
// re-renders the grid identically across frames while still breaking the
// modulo-based row/column patterns. Not crypto-grade — just enough to
// scatter 6 logos across 77 tiles without visible repetition lines.

private struct LinearCongruentialRNG: RandomNumberGenerator {
    private var state: UInt64

    init(seed: UInt64) { self.state = seed == 0 ? 1 : seed }

    mutating func next() -> UInt64 {
        // Numerical Recipes constants — fast, well-distributed.
        state = state &* 6364136223846793005 &+ 1442695040888963407
        return state
    }
}
