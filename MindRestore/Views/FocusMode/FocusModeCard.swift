import SwiftUI
import FamilyControls
import ManagedSettings
import DeviceActivity

extension DeviceActivityReport.Context {
    /// Mirrors the context declared in the FocusUnlocksReport extension target.
    static let screenTime = Self("Screen Time")
}

// MARK: - Design tokens (matches Claude Design spec for Focus Mode)

private enum FM {
    // Surface / strokes
    static let surface = Color(red: 0.078, green: 0.078, blue: 0.122)    // #14141F
    static let border = Color.white.opacity(0.06)
    static let border2 = Color.white.opacity(0.10)

    // Text
    static let fg = Color.white.opacity(0.92)
    static let fg2 = Color.white.opacity(0.55)
    static let fg3 = Color.white.opacity(0.35)

    // Brand
    static let accent = Color(red: 0.408, green: 0.565, blue: 0.996)     // #6890FE
    static let onAccent = Color(red: 0.039, green: 0.039, blue: 0.059)   // #0A0A0F
    static let memoPurple = Color(red: 0.722, green: 0.341, blue: 0.961) // #B857F5

    // Semantic
    static let speed = Color(red: 0.980, green: 0.420, blue: 0.349)      // #FA6B59 — coral / warning
    static let success = Color(red: 0.0, green: 0.820, blue: 0.620)      // #00D19E
    static let amber = Color(red: 1.0, green: 0.761, blue: 0.278)        // #FFC247
}

// MARK: - FocusModeCard

struct FocusModeCard: View {
    @Environment(FocusModeService.self) private var focusModeService
    @Environment(DeepLinkRouter.self) private var deepLinkRouter
    @Environment(StoreService.self) private var storeService

    @State private var showingSettings = false
    @State private var showingSetup = false
    @State private var showingAppPicker = false
    @State private var showingProPaywall = false

    private enum CardState { case notSetUp, idle, active, cooldown, unlocked, scheduled }

    private var cardState: CardState {
        if focusModeService.isTemporarilyUnlocked { return .unlocked }
        if focusModeService.isInCooldown { return .cooldown }
        if focusModeService.blockedAppCount == 0 { return .notSetUp }
        if !focusModeService.isEnabled { return .idle }
        if focusModeService.scheduleEnabled && !isWithinSchedule { return .scheduled }
        return .active
    }

    var body: some View {
        // Re-evaluate state once per second so cooldown / unlock / schedule
        // transitions take effect when their deadlines pass (Date.now isn't observable on its own).
        TimelineView(.periodic(from: .now, by: 1)) { _ in
            Group {
                switch cardState {
                case .notSetUp:  notSetUpCard
                case .idle:      idleCard
                case .active:    activeCard
                case .cooldown:  cooldownCard
                case .unlocked:  unlockedCard
                case .scheduled: scheduledCard
                }
            }
        }
        // The `FM` token palette (surfaces, halos, fg opacities, glows) is composed for a dark
        // background — re-skinning each variant for light mode would compromise the cinematic feel
        // and require redoing every gradient/shadow. Pin the card to dark so it reads as a
        // deliberate "focus mode island" no matter the global appearance.
        .environment(\.colorScheme, .dark)
        .sheet(isPresented: $showingSettings) { FocusModeSettingsView() }
        .sheet(isPresented: $showingSetup)    { FocusModeSetupView() }
    }

    // MARK: - 00 · Not Set Up

    private var notSetUpCard: some View {
        Button { showingSetup = true } label: {
            VStack(alignment: .leading, spacing: 0) {
                // eyebrow + step pill
                HStack {
                    HStack(spacing: 8) {
                        PulsingDot(color: FM.accent, period: 1.6)
                        eyebrow("MEMO'S WAITING", color: FM.accent)
                    }
                    Spacer()
                    HStack(spacing: 4) {
                        Text("1").font(.system(size: 11, weight: .bold, design: .monospaced))
                        Text("step left").font(.system(size: 11, weight: .semibold)).opacity(0.7)
                    }
                    .foregroundStyle(FM.accent)
                    .padding(.horizontal, 10).padding(.vertical, 4)
                    .background(FM.accent.opacity(0.14), in: Capsule())
                }
                .padding(.bottom, 14)

                // hero copy
                Text("Pick your poison.")
                    .font(.system(size: 26, weight: .bold, design: .rounded))
                    .kerning(-0.5)
                    .foregroundStyle(FM.fg)
                    .padding(.bottom, 6)

                (Text("Choose the apps you want to block. ")
                 + Text("Memo handles the rest.").foregroundColor(FM.fg).fontWeight(.semibold))
                    .font(.system(size: 13, design: .rounded))
                    .foregroundStyle(FM.fg2)
                    .lineSpacing(2)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.bottom, 18)

                // ghost app row — 5 empty slots since no apps picked yet
                HStack(spacing: 8) {
                    ForEach(0..<5, id: \.self) { _ in ghostSlot() }
                    Spacer()
                    Text("0 PICKED")
                        .font(.system(size: 11, weight: .semibold))
                        .tracking(0.6)
                        .foregroundStyle(FM.fg3)
                }
                .padding(14)
                .background(
                    RoundedRectangle(cornerRadius: 14)
                        .fill(Color.white.opacity(0.025))
                        .overlay(RoundedRectangle(cornerRadius: 14).strokeBorder(style: StrokeStyle(lineWidth: 1, dash: [4, 3])).foregroundStyle(Color.white.opacity(0.10)))
                )
                .padding(.bottom, 16)

                // CTA
                ctaButton(title: "Hire Memo", showArrow: true) { showingSetup = true }

                Text("Takes 30 seconds · You can change it anytime")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(FM.fg3)
                    .frame(maxWidth: .infinity)
                    .padding(.top, 10)
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 18)
        }
        .buttonStyle(.plain)
        .background(
            cardBackground(halo: FM.accent, haloOpacity: 0.18, top: -30)
                .clipShape(RoundedRectangle(cornerRadius: 26))
        )
    }

    // MARK: - 01 · Idle (off — tension)

    private var idleCard: some View {
        Button { focusModeService.enable() } label: {
            VStack(alignment: .leading, spacing: 0) {
                // eyebrow
                HStack(spacing: 8) {
                    PulsingDot(color: FM.speed, period: 2.0)
                    eyebrow("MEMO'S OFF DUTY", color: FM.speed)
                    Spacer()
                }
                .padding(.bottom, 12)

                // Hero stat — real screen time pulled via DeviceActivityReport extension when authorized.
                Group {
                    if focusModeService.authorizationStatus == .approved {
                        DeviceActivityReport(.screenTime, filter: yesterdayFilter)
                            .frame(height: 64)
                    } else {
                        // Fallback when Screen Time access wasn't granted — clearly mark this as the
                        // industry average (not the user's data) so a quick reader doesn't mistake it
                        // for their own stat. The "AVG" eyebrow + "~" prefix make the framing explicit.
                        HStack(alignment: .firstTextBaseline, spacing: 8) {
                            VStack(alignment: .leading, spacing: 2) {
                                Text("AVG")
                                    .font(.system(size: 10, weight: .bold, design: .rounded))
                                    .tracking(0.9)
                                    .foregroundStyle(FM.fg3)
                                HStack(alignment: .firstTextBaseline, spacing: 6) {
                                    Text("~4.3")
                                        .font(.system(size: 56, weight: .bold, design: .monospaced))
                                        .kerning(-1.5)
                                        .foregroundStyle(FM.fg)
                                    Text("HRS")
                                        .font(.system(size: 22, weight: .bold, design: .monospaced))
                                        .kerning(-0.3)
                                        .foregroundStyle(FM.fg2)
                                }
                            }
                        }
                    }
                }
                .padding(.bottom, 4)

                Text(idleSubtitle)
                    .font(.system(size: 13, design: .rounded))
                    .foregroundStyle(FM.fg2)
                    .lineSpacing(2)
                    .padding(.bottom, 18)

                ctaButton(title: "Put Memo to Work", showArrow: true) {
                    focusModeService.enable()
                }
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 18)
        }
        .buttonStyle(.plain)
        .background(
            ZStack {
                cardBackground()
                // amber/coral pulse behind number
                Circle()
                    .fill(FM.speed.opacity(0.14))
                    .frame(width: 220, height: 220)
                    .blur(radius: 40)
                    .offset(x: -100, y: -20)
                    .allowsHitTesting(false)
            }
            .clipShape(RoundedRectangle(cornerRadius: 26))
        )
    }

    /// DeviceActivity filter for yesterday's data.
    private var yesterdayFilter: DeviceActivityFilter {
        let cal = Calendar.current
        let todayStart = cal.startOfDay(for: Date())
        let yesterdayStart = cal.date(byAdding: .day, value: -1, to: todayStart) ?? todayStart
        return DeviceActivityFilter(
            segment: .daily(during: DateInterval(start: yesterdayStart, end: todayStart)),
            users: .all,
            devices: .init([.iPhone])
        )
    }

    // MARK: - 02 · Active (locked)

    private var activeCard: some View {
        VStack(alignment: .leading, spacing: 0) {
            VStack(alignment: .leading, spacing: 0) {
                // eyebrow row
                HStack {
                    HStack(spacing: 8) {
                        PulsingDot(color: FM.success, period: 2.0)
                        eyebrow("MEMO ON PATROL", color: FM.success)
                    }
                    Spacer()
                    Button { focusModeService.disable() } label: {
                        HStack(spacing: 4) {
                            Image(systemName: "arrow.uturn.backward")
                                .font(.system(size: 10, weight: .bold))
                            Text("End")
                                .font(.system(size: 11, weight: .semibold))
                        }
                        .foregroundStyle(FM.fg2)
                        .padding(.horizontal, 10).padding(.vertical, 4)
                        .background(Color.white.opacity(0.05), in: Capsule())
                        .overlay(Capsule().strokeBorder(FM.border2, lineWidth: 1))
                    }
                    .buttonStyle(.plain)
                }
                .padding(.bottom, 14)

                // live big timer
                TimelineView(.periodic(from: .now, by: 1)) { context in
                    let secondsLocked = Int(max(0, context.date.timeIntervalSince(focusModeService.currentBlockStartDate ?? context.date)))
                    let intro = Text("Memo's been guarding since \(focusModeService.currentBlockStartDate.map(formatClockTime) ?? "now").")
                    // Past 60min the headline already reads "Xh Xm", so the
                    // "Saved you Xh Xm." trailer would just repeat it. Drop it.
                    let trailer: Text = secondsLocked < 3600
                        ? Text(" Saved you ") + Text(fmtHrsMin(secondsLocked)).foregroundColor(FM.fg).fontWeight(.semibold) + Text(".")
                        : Text("")
                    VStack(alignment: .leading, spacing: 4) {
                        Text(fmtElapsedAdaptive(secondsLocked))
                            .font(.system(size: 56, weight: .bold, design: .monospaced))
                            .kerning(-1.5)
                            .foregroundStyle(FM.fg)
                            .contentTransition(.numericText())

                        (intro + trailer)
                            .font(.system(size: 13, design: .rounded))
                            .foregroundStyle(FM.fg2)
                            .lineSpacing(2)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
                .padding(.bottom, 16)

                // blocked apps — tappable to add apps mid-patrol (Pro only;
                // Free tap shows the Pro paywall as the upsell moment).
                Button {
                    if storeService.isProUser {
                        showingAppPicker = true
                    } else {
                        showingProPaywall = true
                    }
                } label: {
                    HStack {
                        VStack(alignment: .leading, spacing: 4) {
                            HStack(spacing: 6) {
                                Text("Memo's blocklist")
                                    .font(.system(size: 12, design: .rounded))
                                    .foregroundStyle(FM.fg2)
                                if storeService.isProUser {
                                    Image(systemName: "plus.circle.fill")
                                        .font(.system(size: 12, weight: .semibold))
                                        .foregroundStyle(FM.accent)
                                }
                            }
                            blockedAppsRow(locked: true)
                        }
                        Spacer()
                        Text("\(focusModeService.blockedAppCount)")
                            .font(.system(size: 22, weight: .bold, design: .monospaced))
                            .kerning(-0.3)
                            .foregroundStyle(FM.fg)
                    }
                    .padding(12)
                    .background(
                        RoundedRectangle(cornerRadius: 14)
                            .fill(Color.white.opacity(0.03))
                            .overlay(RoundedRectangle(cornerRadius: 14).stroke(FM.border, lineWidth: 1))
                    )
                }
                .buttonStyle(.plain)
                .padding(.bottom, 14)

                ctaButton(title: "bribe memo · \(focusModeService.unlockDuration)m") {
                    deepLinkRouter.pendingDestination = .focusUnlock
                }
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 18)
        }
        .background(
            ZStack {
                cardBackground()
                LinearGradient(colors: [FM.accent.opacity(0.20), .clear], startPoint: .top, endPoint: .bottom)
                    .allowsHitTesting(false)
            }
            .clipShape(RoundedRectangle(cornerRadius: 26))
        )
        .familyActivityPicker(isPresented: $showingAppPicker, selection: Binding(
            get: { focusModeService.activitySelection },
            set: { newSelection in
                // Active session + Pro: additions only — discard removals so users
                // can't unblock apps mid-patrol to escape the commitment.
                guard storeService.isProUser else { return }
                var merged = focusModeService.activitySelection
                merged.applicationTokens.formUnion(newSelection.applicationTokens)
                merged.categoryTokens.formUnion(newSelection.categoryTokens)
                merged.webDomainTokens.formUnion(newSelection.webDomainTokens)
                focusModeService.updateActivitySelection(merged)
            }
        ))
        .sheet(isPresented: $showingProPaywall) {
            PaywallView(triggerSource: "focus_mode_add_apps")
        }
    }

    // MARK: - 03 · Cooldown

    private var cooldownCard: some View {
        VStack(alignment: .leading, spacing: 0) {
            // eyebrow
            HStack(spacing: 8) {
                PulsingDot(color: FM.amber, period: 2.0)
                eyebrow("MEMO'S WINDED", color: FM.amber)
                Spacer()
            }
            .padding(.bottom, 16)

            // hero ring + text
            HStack(alignment: .center, spacing: 18) {
                TimelineView(.periodic(from: .now, by: 1)) { context in
                    let remaining = max(0, Int(focusModeService.cooldownUntil?.timeIntervalSince(context.date) ?? 0))
                    let total = 600 // 10 min cooldown (matches service default)
                    let pct = 1 - (Double(remaining) / Double(total))
                    ZStack {
                        Circle()
                            .stroke(Color.white.opacity(0.06), lineWidth: 9)
                        Circle()
                            .trim(from: 0, to: CGFloat(min(1, max(0, pct))))
                            .stroke(FM.amber, style: StrokeStyle(lineWidth: 9, lineCap: .round))
                            .rotationEffect(.degrees(-90))
                            .shadow(color: FM.amber.opacity(0.5), radius: 6)
                        VStack(spacing: 3) {
                            Text(fmtMMSS(remaining))
                                .font(.system(size: 22, weight: .bold, design: .monospaced))
                                .kerning(-0.3)
                                .foregroundStyle(FM.fg)
                            Text("TIL READY")
                                .font(.system(size: 9, weight: .semibold))
                                .tracking(0.9)
                                .foregroundStyle(FM.fg3)
                        }
                    }
                    .frame(width: 110, height: 110)
                }

                VStack(alignment: .leading, spacing: 6) {
                    Text("Memo's catching their breath")
                        .font(.system(size: 18, weight: .bold, design: .rounded))
                        .kerning(-0.2)
                        .foregroundStyle(FM.fg)
                        .lineSpacing(2)
                    Text("Apps stay open until Memo's back. Bribe them with a brain game to skip the wait.")
                        .font(.system(size: 13, design: .rounded))
                        .foregroundStyle(FM.fg2)
                        .lineSpacing(2)
                }
            }
            .padding(.bottom, 18)

            HStack(spacing: 8) {
                Button {
                    deepLinkRouter.pendingDestination = .focusUnlock
                } label: {
                    Text("bribe memo · \(focusModeService.unlockDuration)m")
                        .font(.system(size: 14, weight: .bold, design: .rounded))
                        .foregroundStyle(FM.fg)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 13)
                        .background(FM.accent, in: RoundedRectangle(cornerRadius: 12))
                        .shadow(color: FM.accent.opacity(0.28), radius: 12, x: 0, y: 6)
                }
                .buttonStyle(.plain)

                // Passive acknowledgment — during cooldown there's nothing actionable to do
                // (disable button is hidden until cooldown ends), so this is just a "Got it"
                // dismiss that visually does nothing but lets the user feel like they've handled it.
                // Kept as a non-destructive button so the layout matches the bribe CTA.
                Button {
                    // No-op — cooldown will end on its own. Rely on TimelineView (1Hz) to
                    // re-render the card into its post-cooldown state.
                } label: {
                    Text("Got it")
                        .font(.system(size: 14, weight: .semibold, design: .rounded))
                        .foregroundStyle(FM.fg)
                        .padding(.horizontal, 16).padding(.vertical, 13)
                        .background(
                            RoundedRectangle(cornerRadius: 12)
                                .strokeBorder(FM.border2, lineWidth: 1)
                        )
                }
                .buttonStyle(.plain)
            }
        }
        .padding(20)
        .background(
            ZStack {
                cardBackground()
                LinearGradient(colors: [FM.amber.opacity(0.12), .clear], startPoint: .top, endPoint: .bottom)
                    .allowsHitTesting(false)
            }
            .clipShape(RoundedRectangle(cornerRadius: 26))
        )
    }

    // MARK: - 04 · Unlocked (window open)

    private var unlockedCard: some View {
        VStack(alignment: .leading, spacing: 0) {
            VStack(alignment: .leading, spacing: 0) {
                HStack {
                    HStack(spacing: 8) {
                        PulsingDot(color: FM.speed, period: 1.4)
                        eyebrow("MEMO'S CHILL", color: FM.speed)
                    }
                    Spacer()
                    Button { focusModeService.cancelTemporaryUnlock() } label: {
                        Text("Lock Early")
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundStyle(FM.fg2)
                            .padding(.horizontal, 10).padding(.vertical, 4)
                            .background(Color.white.opacity(0.05), in: Capsule())
                            .overlay(Capsule().strokeBorder(FM.border2, lineWidth: 1))
                    }
                    .buttonStyle(.plain)
                }
                .padding(.bottom, 14)

                // live countdown
                TimelineView(.periodic(from: .now, by: 1)) { context in
                    let remaining = max(0, Int(focusModeService.unlockUntil?.timeIntervalSince(context.date) ?? 0))
                    HStack(alignment: .firstTextBaseline, spacing: 8) {
                        Text(fmtMMSS(remaining))
                            .font(.system(size: 56, weight: .bold, design: .monospaced))
                            .kerning(-1.5)
                            .foregroundStyle(FM.fg)
                            .contentTransition(.numericText())
                        Text("to scroll")
                            .font(.system(size: 13, weight: .medium))
                            .foregroundStyle(FM.fg2)
                    }
                }
                .padding(.bottom, 4)

                Text("Memo locks the door at 0:00. Make it count.")
                    .font(.system(size: 13, design: .rounded))
                    .foregroundStyle(FM.fg2)
                    .padding(.bottom, 14)

                // Open apps row
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Memo's letting through")
                            .font(.system(size: 12, design: .rounded))
                            .foregroundStyle(FM.fg2)
                        blockedAppsRow(locked: false)
                    }
                    Spacer()
                }
                .padding(12)
                .background(
                    RoundedRectangle(cornerRadius: 14)
                        .fill(Color.white.opacity(0.03))
                        .overlay(RoundedRectangle(cornerRadius: 14).stroke(FM.border, lineWidth: 1))
                )
                .padding(.bottom, 12)

                // Earn more CTA (secondary style)
                Button {
                    deepLinkRouter.pendingDestination = .focusUnlock
                } label: {
                    HStack(spacing: 8) {
                        Image(systemName: "bolt.fill").font(.system(size: 13, weight: .bold))
                        Text("bribe memo · +\(focusModeService.unlockDuration)m")
                            .font(.system(size: 14, weight: .bold, design: .rounded))
                    }
                    .foregroundStyle(FM.fg)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 13)
                    .background(
                        RoundedRectangle(cornerRadius: 12)
                            .fill(Color.white.opacity(0.05))
                            .overlay(RoundedRectangle(cornerRadius: 12).strokeBorder(FM.border2, lineWidth: 1))
                    )
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 18)
        }
        .background(
            ZStack {
                RoundedRectangle(cornerRadius: 26).fill(FM.surface)
                LinearGradient(colors: [FM.speed.opacity(0.24), .clear], startPoint: .top, endPoint: .bottom)
                    .allowsHitTesting(false)
            }
            .clipShape(RoundedRectangle(cornerRadius: 26))
        )
    }

    // MARK: - 05 · Scheduled Off

    private var scheduledCard: some View {
        let resume = nextResumeDate()
        let resumeLabel = formatClockTime(resume)
        let dayLabel = resumeDayLabel(for: resume)
        return VStack(alignment: .leading, spacing: 0) {
            // eyebrow + pill
            HStack {
                HStack(spacing: 8) {
                    PulsingDot(color: FM.amber, period: 2.4)
                    eyebrow("MEMO'S OFF THE CLOCK", color: FM.amber)
                }
                Spacer()
                HStack(spacing: 4) {
                    Image(systemName: "clock.fill").font(.system(size: 9, weight: .bold))
                    Text("Off until \(resumeLabel)")
                        .font(.system(size: 11, weight: .semibold))
                }
                .foregroundStyle(FM.amber)
                .padding(.horizontal, 10).padding(.vertical, 4)
                .background(FM.amber.opacity(0.15), in: Capsule())
            }
            .padding(.bottom, 14)

            // hero row
            HStack(alignment: .center, spacing: 14) {
                ZStack {
                    Image(systemName: "moon.zzz.fill")
                        .font(.system(size: 56))
                        .foregroundStyle(FM.amber.opacity(0.9))
                        .saturation(0.7)
                }
                .frame(width: 96, height: 96)

                VStack(alignment: .leading, spacing: 4) {
                    Text("Memo's off the clock")
                        .font(.system(size: 19, weight: .bold, design: .rounded))
                        .kerning(-0.2)
                        .foregroundStyle(FM.fg)
                    Text("Memo clocks back in at \(resumeLabel) \(dayLabel).")
                        .font(.system(size: 13, design: .rounded))
                        .foregroundStyle(FM.fg2)
                        .lineSpacing(2)
                }
                Spacer()
            }
            .padding(.bottom, 18)

            Button { focusModeService.activateNow() } label: {
                Text("Wake Memo Up")
                    .font(.system(size: 14, weight: .bold, design: .rounded))
                    .foregroundStyle(FM.amber)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                    .background(
                        RoundedRectangle(cornerRadius: 12)
                            .strokeBorder(FM.amber, lineWidth: 1.5)
                    )
            }
            .buttonStyle(.plain)
        }
        .padding(20)
        .background(
            ZStack {
                cardBackground()
                LinearGradient(colors: [FM.amber.opacity(0.12), .clear], startPoint: .top, endPoint: .bottom)
                    .allowsHitTesting(false)
            }
            .clipShape(RoundedRectangle(cornerRadius: 26))
        )
    }

    // MARK: - Helpers

    private func eyebrow(_ text: String, color: Color) -> some View {
        Text(text)
            .font(.system(size: 11, weight: .semibold, design: .rounded))
            .tracking(1.3)
            .foregroundStyle(color)
    }


    private func ctaButton(title: String, icon: String? = nil, showArrow: Bool = false, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 8) {
                if let icon {
                    Image(systemName: icon).font(.system(size: 13, weight: .bold))
                }
                Text(title).font(.system(size: 15, weight: .bold, design: .rounded))
                if showArrow {
                    Image(systemName: "arrow.right").font(.system(size: 12, weight: .bold))
                }
            }
            .foregroundStyle(FM.fg)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 14)
            .background(FM.accent, in: RoundedRectangle(cornerRadius: 12))
            .shadow(color: FM.accent.opacity(0.30), radius: 14, x: 0, y: 6)
        }
        .buttonStyle(.plain)
    }

    private func cardBackground(halo: Color? = nil, haloOpacity: Double = 0.0, top: CGFloat = 0) -> some View {
        ZStack {
            RoundedRectangle(cornerRadius: 26).fill(FM.surface)
            if let halo {
                LinearGradient(colors: [halo.opacity(haloOpacity), .clear], startPoint: .top, endPoint: .bottom)
                    .allowsHitTesting(false)
            }
        }
    }

    private func appGlyph<Background: ShapeStyle>(_ glyph: String, bg: Background, dim: Bool) -> some View {
        Text(glyph)
            .font(.system(size: 12, weight: .bold))
            .foregroundStyle(.white)
            .frame(width: 32, height: 32)
            .background(bg, in: RoundedRectangle(cornerRadius: 8))
            .opacity(dim ? 0.45 : 1)
            .saturation(dim ? 0.7 : 1)
            .shadow(color: .black.opacity(0.3), radius: 2, y: 2)
    }

    private func ghostSlot() -> some View {
        Text("?")
            .font(.system(size: 14, weight: .bold, design: .monospaced))
            .foregroundStyle(Color.white.opacity(0.22))
            .frame(width: 32, height: 32)
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .strokeBorder(style: StrokeStyle(lineWidth: 1.5, dash: [3, 2]))
                    .foregroundStyle(Color.white.opacity(0.14))
            )
    }

    /// Real app icons rendered via FamilyControls `Label(token)`. Shows actual Instagram/TikTok/etc. icons
    /// for whatever apps the user has blocked via the FamilyActivityPicker.
    private func blockedAppsRow(locked: Bool) -> some View {
        let tokens = Array(focusModeService.activitySelection.applicationTokens)
        let catTokens = Array(focusModeService.activitySelection.categoryTokens)
        let maxShown = 5
        let totalCount = tokens.count + catTokens.count
        return HStack(spacing: 6) {
            ForEach(Array(tokens.prefix(maxShown)), id: \.self) { token in
                ZStack {
                    Label(token)
                        .labelStyle(.iconOnly)
                        .frame(width: 26, height: 26)
                        .clipShape(RoundedRectangle(cornerRadius: 7))
                        .shadow(color: .black.opacity(0.4), radius: 2, y: 2)
                    if locked {
                        RoundedRectangle(cornerRadius: 7)
                            .fill(Color(red: 0.039, green: 0.039, blue: 0.059).opacity(0.55))
                            .frame(width: 26, height: 26)
                        Image(systemName: "lock.fill")
                            .font(.system(size: 10, weight: .bold))
                            .foregroundStyle(.white)
                    }
                }
            }
            // If user picked categories but no/few specific apps, show category tokens to fill the row
            let catSlots = max(0, maxShown - tokens.prefix(maxShown).count)
            ForEach(Array(catTokens.prefix(catSlots)), id: \.self) { token in
                ZStack {
                    Label(token)
                        .labelStyle(.iconOnly)
                        .frame(width: 26, height: 26)
                        .clipShape(RoundedRectangle(cornerRadius: 7))
                        .shadow(color: .black.opacity(0.4), radius: 2, y: 2)
                    if locked {
                        RoundedRectangle(cornerRadius: 7)
                            .fill(Color(red: 0.039, green: 0.039, blue: 0.059).opacity(0.55))
                            .frame(width: 26, height: 26)
                        Image(systemName: "folder.fill")
                            .font(.system(size: 10, weight: .bold))
                            .foregroundStyle(.white)
                    }
                }
            }
            if totalCount > maxShown {
                Text("+\(totalCount - maxShown)")
                    .font(.system(size: 11, weight: .bold))
                    .foregroundStyle(FM.fg2)
                    .frame(width: 26, height: 26)
                    .background(Color.white.opacity(0.06), in: RoundedRectangle(cornerRadius: 7))
            }
        }
    }

    // MARK: - Computed

    private var isWithinSchedule: Bool {
        guard focusModeService.scheduleEnabled else { return true }
        let cal = Calendar.current
        let now = Date.now
        let startC = cal.dateComponents([.hour, .minute], from: focusModeService.scheduleStart)
        let endC = cal.dateComponents([.hour, .minute], from: focusModeService.scheduleEnd)
        let nowC = cal.dateComponents([.hour, .minute], from: now)
        let startMins = (startC.hour ?? 0) * 60 + (startC.minute ?? 0)
        let endMins = (endC.hour ?? 0) * 60 + (endC.minute ?? 0)
        let nowMins = (nowC.hour ?? 0) * 60 + (nowC.minute ?? 0)
        let todayWeekday = cal.component(.weekday, from: now)
        let yesterdayWeekday = ((todayWeekday - 2 + 7) % 7) + 1 // 1-based weekday for yesterday

        if startMins <= endMins {
            // same-day window
            guard focusModeService.scheduleDays.contains(todayWeekday) else { return false }
            return nowMins >= startMins && nowMins < endMins
        } else {
            // overnight window (e.g. 22:00 → 08:00):
            // - If now is past start (e.g. 23:00), it counts toward today's scheduled day.
            // - If now is before end (e.g. 03:00), it counts toward YESTERDAY's scheduled day
            //   because that's when this active interval began.
            if nowMins >= startMins {
                return focusModeService.scheduleDays.contains(todayWeekday)
            } else if nowMins < endMins {
                return focusModeService.scheduleDays.contains(yesterdayWeekday)
            }
            return false
        }
    }

    /// The next moment Focus Mode will resume blocking (when card is in `.scheduled` state).
    /// Handles three cases:
    ///   1. Same-day window (e.g. 09→17), now outside it: next start is the next scheduled `start` time.
    ///   2. Overnight window (e.g. 22→08), now in the daytime gap: next start is today at `start`.
    ///   3. Overnight active that crossed midnight but today isn't a scheduled day: returns next valid start.
    private func nextResumeDate() -> Date {
        let cal = Calendar.current
        let now = Date.now
        let startC = cal.dateComponents([.hour, .minute], from: focusModeService.scheduleStart)
        let startHour = startC.hour ?? 0
        let startMinute = startC.minute ?? 0
        let days = focusModeService.scheduleDays.isEmpty ? Set(1...7) : focusModeService.scheduleDays

        // Probe up to 8 days ahead to find the next scheduled start that's strictly in the future.
        for offset in 0..<8 {
            guard let candidateDay = cal.date(byAdding: .day, value: offset, to: now) else { continue }
            let weekday = cal.component(.weekday, from: candidateDay)
            guard days.contains(weekday) else { continue }
            var comps = cal.dateComponents([.year, .month, .day], from: candidateDay)
            comps.hour = startHour
            comps.minute = startMinute
            guard let candidate = cal.date(from: comps), candidate > now else { continue }
            return candidate
        }
        return focusModeService.scheduleStart
    }

    /// Friendly day label for the next resume time ("today", "tomorrow", or weekday name).
    private func resumeDayLabel(for date: Date) -> String {
        let cal = Calendar.current
        if cal.isDateInToday(date) { return "today" }
        if cal.isDateInTomorrow(date) { return "tomorrow" }
        let f = DateFormatter()
        f.dateFormat = "EEEE"
        return "on \(f.string(from: date))"
    }

    /// Idle subtitle. When Screen Time access is granted the stat above is real (yesterday's screen time);
    /// otherwise we fall back to the industry average and the copy reflects that.
    private var idleSubtitle: String {
        if focusModeService.authorizationStatus == .approved {
            return "yesterday. Memo's ready when you are."
        }
        return "industry average. Memo can do better."
    }

    // MARK: - Formatters

    private func fmtMMSS(_ secs: Int) -> String {
        let m = max(0, secs) / 60
        let s = max(0, secs) % 60
        return String(format: "%02d:%02d", m, s)
    }

    private func fmtHrsMin(_ secs: Int) -> String {
        let h = max(0, secs) / 3600
        let m = (max(0, secs) % 3600) / 60
        if h > 0 { return "\(h)h \(m)m" }
        return "\(m)m"
    }

    /// Headline elapsed-time format for active patrols: MM:SS until the first hour,
    /// then switches to "Xh Ym" so triple-digit minutes never display.
    private func fmtElapsedAdaptive(_ secs: Int) -> String {
        secs < 3600 ? fmtMMSS(secs) : fmtHrsMin(secs)
    }

    private func formatClockTime(_ date: Date) -> String {
        let f = DateFormatter()
        f.dateFormat = "h:mm a"
        return f.string(from: date)
    }
}

// MARK: - PulsingDot

private struct PulsingDot: View {
    let color: Color
    var period: Double = 1.6
    @State private var pulse = false

    var body: some View {
        Circle()
            .fill(color)
            .frame(width: 8, height: 8)
            .shadow(color: color.opacity(0.8), radius: pulse ? 6 : 2)
            .scaleEffect(pulse ? 1.2 : 0.9)
            .opacity(pulse ? 1 : 0.7)
            .onAppear {
                withAnimation(.easeInOut(duration: period / 2).repeatForever(autoreverses: true)) {
                    pulse = true
                }
            }
    }
}

// MARK: - FocusModeService extension — block start time

extension FocusModeService {
    /// The Date when the current contiguous block window started (nil if not currently blocking).
    var currentBlockStartDate: Date? {
        let defaults = UserDefaults(suiteName: "group.com.memori.shared") ?? .standard
        return defaults.object(forKey: "focus_last_block_start") as? Date
    }
}
