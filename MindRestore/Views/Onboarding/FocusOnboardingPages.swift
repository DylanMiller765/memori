import SwiftUI
import DeviceActivity
import FamilyControls
import UIKit

extension DeviceActivityReport.Context {
    /// Must match the context name declared in the `FocusUnlocksReport` extension target.
    static let unlocks = Self("Unlocks Count")
    static let screenTimeAverage = Self("Screen Time Daily Average")
}

// Design tokens for Focus Mode onboarding pages (matches Claude Design spec)
private enum FO {
    static let bg = Color(red: 0.039, green: 0.039, blue: 0.059)         // #0A0A0F
    static let surface = Color(red: 0.078, green: 0.078, blue: 0.122)    // #14141F
    static let surface2 = Color(red: 0.110, green: 0.110, blue: 0.165)   // #1C1C2A
    static let border = Color.white.opacity(0.06)
    static let border2 = Color.white.opacity(0.10)
    static let fg = Color.white.opacity(0.92)
    static let fg2 = Color.white.opacity(0.55)
    static let fg3 = Color.white.opacity(0.35)
    static let accent = Color(red: 0.408, green: 0.565, blue: 0.996)     // #6890FE
    static let onAccent = Color(red: 0.039, green: 0.039, blue: 0.059)   // #0A0A0F
    static let memoPurple = Color(red: 0.722, green: 0.341, blue: 0.961) // #B857F5
    static let speed = Color(red: 0.980, green: 0.420, blue: 0.349)      // #FA6B59
    static let success = Color(red: 0.0, green: 0.820, blue: 0.620)      // #00D19E
    static let amber = Color(red: 1.0, green: 0.761, blue: 0.278)        // #FFC247
    static let memoIndigo = Color(red: 0.082, green: 0.047, blue: 0.180) // #150C2E
}

// MARK: - Shared atoms

private struct FOEyebrow: View {
    let text: String
    var color: Color = FO.accent
    var body: some View {
        Text(text)
            .font(.brand(size: 13, weight: .bold))
            .tracking(1.0)
            .foregroundStyle(color)
    }
}

private struct FOContinueButton: View {
    let title: String
    let action: () -> Void
    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.system(size: 17, weight: .bold))
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 17)
                .background(FO.accent, in: RoundedRectangle(cornerRadius: 14))
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Industry Scare ($57B engineering spend)
//
// Case-file lineup. Pain Cards = your receipts (confessions). Industry Scare
// = their receipts (crimes). Sequel to "memo found the receipts" — same
// metaphor extended, different target. Five visible elements: case slug,
// headline, caution-tape divider, four-row suspect lineup, $57B aggregate.
// Total entrance arc ~3.0s.

private struct SuspectRow: View {
    let logoAsset: String
    let suspect: String
    let parent: String
    let role: String
    let visible: Bool
    let isLast: Bool

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 12) {
                Image(logoAsset)
                    .resizable()
                    .scaledToFit()
                    .frame(width: 40, height: 40)
                    .clipShape(RoundedRectangle(cornerRadius: 9, style: .continuous))

                VStack(alignment: .leading, spacing: 2) {
                    Text(suspect)
                        .font(.brand(size: 13, weight: .heavy))
                        .foregroundStyle(OB.fg)
                    Text(parent)
                        .font(.system(size: 9, weight: .heavy, design: .monospaced))
                        .tracking(0.8)
                        .foregroundStyle(OB.fg2)
                }
                .frame(maxWidth: .infinity, alignment: .leading)

                Text(role)
                    .font(.system(size: 9, weight: .heavy, design: .monospaced))
                    .tracking(0.8)
                    .foregroundStyle(OB.coral)
            }
            .padding(.vertical, 10)

            if !isLast {
                Rectangle()
                    .fill(Color.white.opacity(0.10))
                    .frame(height: 1)
            }
        }
        .opacity(visible ? 1 : 0)
        .offset(y: visible ? 0 : 8)
    }
}

struct FocusOnboardIndustryScare: View {
    var onContinue: () -> Void

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    @State private var headlineVisible = false
    @State private var tapeProgress: CGFloat = 0
    @State private var rowsVisible: [Bool] = Array(repeating: false, count: 4)
    @State private var dividerVisible = false
    @State private var displayedNumber: Int = 0
    @State private var captionVisible = false
    @State private var mascotVisible = false
    @State private var ctaVisible = false
    @State private var sequenceTask: Task<Void, Never>?

    private let suspects: [(asset: String, name: String, parent: String, role: String)] = [
        (asset: "logo-tiktok", name: "TikTok", parent: "BYTEDANCE", role: "FYP"),
        (asset: "logo-instagram", name: "Instagram", parent: "META", role: "REELS"),
        (asset: "logo-youtube", name: "YouTube", parent: "GOOGLE", role: "SHORTS"),
        (asset: "logo-snapchat", name: "Snap", parent: "SNAP INC", role: "SPOTLIGHT")
    ]

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Headline + detective Memo side by side — Memo is examining the case file.
            HStack(alignment: .top, spacing: 12) {
                Text("memo found\nthe suspects.")
                    .font(.brand(size: 24, weight: .heavy))
                    .kerning(-0.5)
                    .lineSpacing(2)
                    .foregroundStyle(OB.fg)
                    .fixedSize(horizontal: false, vertical: true)
                    .opacity(headlineVisible ? 1 : 0)
                    .offset(y: headlineVisible ? 0 : 8)

                Spacer(minLength: 0)

                Image("mascot-detective")
                    .resizable()
                    .scaledToFit()
                    .frame(width: 96, height: 96)
                    .shadow(color: OB.accent.opacity(0.32), radius: 16, x: 0, y: 6)
                    .opacity(mascotVisible ? 1 : 0)
                    .scaleEffect(mascotVisible ? 1 : 0.88, anchor: .center)
                    .accessibilityHidden(true)
            }
            .padding(.top, 24)

            // Caution-tape divider (full-bleed via negative horizontal margins)
            cautionTape
                .padding(.top, 16)

            // Suspect lineup
            VStack(spacing: 0) {
                ForEach(Array(suspects.enumerated()), id: \.offset) { index, suspect in
                    SuspectRow(
                        logoAsset: suspect.asset,
                        suspect: suspect.name,
                        parent: suspect.parent,
                        role: suspect.role,
                        visible: index < rowsVisible.count && rowsVisible[index],
                        isLast: index == suspects.count - 1
                    )
                }
            }
            .padding(.top, 4)

            // Top divider above the totals block
            Rectangle()
                .fill(Color.white.opacity(0.18))
                .frame(height: 1.5)
                .padding(.top, 12)
                .opacity(dividerVisible ? 1 : 0)

            // Totals block
            VStack(alignment: .leading, spacing: 6) {
                Text("COMBINED R&D · ANNUAL")
                    .font(.system(size: 9, weight: .heavy, design: .monospaced))
                    .tracking(1.6)
                    .foregroundStyle(OB.fg3)

                Text("$\(displayedNumber)B")
                    .font(.system(size: 56, weight: .black, design: .monospaced))
                    .kerning(-3)
                    .foregroundStyle(OB.fg)
                    .monospacedDigit()
                    .contentTransition(.numericText(value: Double(displayedNumber)))
                    .lineLimit(1)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.bottom, 4)

                Text("spent every year engineering\nyour feed against you.")
                    .font(.brand(size: 12, weight: .semibold))
                    .foregroundStyle(OB.fg2)
                    .lineSpacing(2)
                    .fixedSize(horizontal: false, vertical: true)
                    .opacity(captionVisible ? 1 : 0)
                    .offset(y: captionVisible ? 0 : 8)
            }
            .padding(.top, 14)

            Spacer(minLength: 0)
        }
        .padding(.horizontal, 24)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .background(FO.bg.ignoresSafeArea())
        .safeAreaInset(edge: .bottom) {
            FOContinueButton(title: "i'm in. fight back.", action: onContinue)
                .padding(.horizontal, 24)
                .padding(.bottom, 12)
                .opacity(ctaVisible ? 1 : 0)
        }
        .preferredColorScheme(.dark)
        .onAppear { startSequence() }
        .onDisappear {
            sequenceTask?.cancel()
            sequenceTask = nil
        }
    }

    private var cautionTape: some View {
        Canvas { ctx, size in
            let stripeWidth: CGFloat = 14
            let slant = size.height
            let count = Int(ceil((size.width + slant + stripeWidth) / stripeWidth)) + 1
            for i in 0..<count {
                let x = CGFloat(i) * stripeWidth - slant
                let isAmber = i % 2 == 0
                var path = Path()
                path.move(to: CGPoint(x: x, y: 0))
                path.addLine(to: CGPoint(x: x + stripeWidth, y: 0))
                path.addLine(to: CGPoint(x: x + stripeWidth - slant, y: size.height))
                path.addLine(to: CGPoint(x: x - slant, y: size.height))
                path.closeSubpath()
                ctx.fill(path, with: .color(isAmber ? OB.amber : FO.bg))
            }
        }
        .frame(height: 10)
        .frame(maxWidth: .infinity)
        .padding(.horizontal, -24) // full-bleed past the page's 24pt margin
        .scaleEffect(x: tapeProgress, y: 1, anchor: .leading)
    }

    private func startSequence() {
        // Reset every appearance so re-entry replays the cinema.
        headlineVisible = false
        tapeProgress = 0
        rowsVisible = Array(repeating: false, count: 4)
        dividerVisible = false
        displayedNumber = 0
        captionVisible = false
        mascotVisible = false
        ctaVisible = false

        sequenceTask?.cancel()
        sequenceTask = Task { @MainActor in
            if reduceMotion {
                // Reduce Motion path — single 0.18s opacity fade, $57B set immediately.
                displayedNumber = 57
                withAnimation(.easeOut(duration: 0.18)) {
                    headlineVisible = true
                    tapeProgress = 1
                    rowsVisible = Array(repeating: true, count: 4)
                    dividerVisible = true
                    captionVisible = true
                    mascotVisible = true
                    ctaVisible = true
                }
                try? await Task.sleep(for: .milliseconds(300))
                guard !Task.isCancelled else { return }
                UIImpactFeedbackGenerator(style: .light).impactOccurred(intensity: 0.6)
                return
            }

            // Standard cinematic path (~3.0s total).
            try? await Task.sleep(for: .milliseconds(100))
            guard !Task.isCancelled else { return }
            withAnimation(.easeOut(duration: 0.40)) {
                headlineVisible = true
            }
            withAnimation(.spring(response: 0.55, dampingFraction: 0.78)) {
                mascotVisible = true
            }

            try? await Task.sleep(for: .milliseconds(450))
            guard !Task.isCancelled else { return }
            withAnimation(.easeOut(duration: 0.50)) {
                tapeProgress = 1
            }

            try? await Task.sleep(for: .milliseconds(500))
            guard !Task.isCancelled else { return }

            // Suspect rows stagger 0.10s apart, light haptic per row.
            let lightImpact = UIImpactFeedbackGenerator(style: .light)
            lightImpact.prepare()
            for i in 0..<rowsVisible.count {
                guard !Task.isCancelled else { return }
                withAnimation(.easeOut(duration: 0.30)) {
                    if i < rowsVisible.count { rowsVisible[i] = true }
                }
                lightImpact.impactOccurred(intensity: 0.4)
                try? await Task.sleep(for: .milliseconds(100))
            }

            try? await Task.sleep(for: .milliseconds(50))
            guard !Task.isCancelled else { return }
            withAnimation(.easeOut(duration: 0.30)) {
                dividerVisible = true
            }

            try? await Task.sleep(for: .milliseconds(150))
            guard !Task.isCancelled else { return }

            // $57B count-up over ~1.2s.
            await runCountUp()
            guard !Task.isCancelled else { return }

            UIImpactFeedbackGenerator(style: .medium).impactOccurred()

            try? await Task.sleep(for: .milliseconds(100))
            guard !Task.isCancelled else { return }
            withAnimation(.easeOut(duration: 0.40)) {
                captionVisible = true
                ctaVisible = true
            }
        }
    }

    @MainActor
    private func runCountUp() async {
        let target = 57
        let steps = target
        let stepMs = 21 // ~1.2s total
        let lightImpact = UIImpactFeedbackGenerator(style: .light)
        lightImpact.prepare()

        for step in 1...steps {
            guard !Task.isCancelled else { return }
            displayedNumber = step
            if step % 7 == 0 {
                lightImpact.impactOccurred(intensity: 0.3)
            }
            try? await Task.sleep(for: .milliseconds(stepMs))
        }
        displayedNumber = target
    }
}

// MARK: - D) Personal Unlocks reveal (287×)

struct FocusOnboardPersonalUnlocks: View {
    var onContinue: () -> Void
    var authorized: Bool = true
    var count: Int = 287  // fallback for preview / declined
    /// When the user previously denied auth, iOS won't re-prompt. We surface an
    /// "Open Settings" deep-link instead of the standard "Unlock" CTA.
    var previouslyDenied: Bool = false

    /// Filter to yesterday 00:00 → today 00:00 for pickup count.
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

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            FOEyebrow(text: "PATTERN FOUND")
                .padding(.top, 24)
                .padding(.bottom, 14)

            Text("You unlocked your phone")
                .font(.system(size: 19, weight: .semibold))
                .foregroundStyle(FO.fg2)
                .lineSpacing(3)
                .padding(.bottom, 12)

            // THE NUMBER — real data from DeviceActivityReport extension when authorized
            Group {
                if authorized {
                    DeviceActivityReport(.unlocks, filter: yesterdayFilter)
                        .frame(height: 140)
                } else {
                    HStack(alignment: .firstTextBaseline, spacing: 0) {
                        Text("???")
                            .font(.system(size: 140, weight: .bold, design: .monospaced))
                            .kerning(-7)
                            .foregroundStyle(FO.fg3.opacity(0.6))
                        Text("×")
                            .font(.system(size: 140, weight: .bold, design: .monospaced))
                            .kerning(-7)
                            .foregroundStyle(FO.accent.opacity(0.3))
                    }
                    .lineLimit(1)
                    .minimumScaleFactor(0.6)
                }
            }

            Text("yesterday.")
                .font(.system(size: 12, weight: .semibold))
                .tracking(0.5)
                .foregroundStyle(FO.fg3)
                .textCase(.uppercase)
                .padding(.top, 12)

            if authorized {
                Text("Most people call it \"a few checks.\" Your phone kept receipts.")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(FO.fg2)
                    .lineSpacing(3)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.top, 14)
            }

            // quote or auth prompt
            Group {
                if authorized {
                    HStack(spacing: 0) {
                        Rectangle().fill(FO.accent).frame(width: 2)
                        Text("Every unlock is another opening for the feed to pull you back.")
                            .font(.system(size: 18, weight: .semibold))
                            .kerning(-0.2)
                            .foregroundStyle(FO.fg)
                            .lineSpacing(4)
                            .padding(.leading, 14)
                            .padding(.vertical, 2)
                    }
                } else if previouslyDenied {
                    HStack(spacing: 0) {
                        Rectangle().fill(FO.speed).frame(width: 2)
                        (Text("Permission was denied earlier. ")
                         + Text("Open Settings").foregroundColor(FO.fg).fontWeight(.semibold)
                         + Text(" to enable Screen Time access."))
                            .font(.system(size: 15))
                            .foregroundStyle(FO.fg2)
                            .lineSpacing(3)
                            .padding(.leading, 14)
                            .padding(.vertical, 2)
                    }
                } else {
                    HStack(spacing: 0) {
                        Rectangle().fill(FO.border2).frame(width: 2)
                        (Text("We need ")
                         + Text("Screen Time access").foregroundColor(FO.fg).fontWeight(.semibold)
                         + Text(" to show your real number. Apple-private, never leaves your phone."))
                            .font(.system(size: 15))
                            .foregroundStyle(FO.fg2)
                            .lineSpacing(3)
                            .padding(.leading, 14)
                            .padding(.vertical, 2)
                    }
                }
            }
            .fixedSize(horizontal: false, vertical: true)
            .frame(maxWidth: 320, alignment: .leading)
            .padding(.top, 24)

            Spacer()

            // Memo + bridge into the assessment.
            ZStack(alignment: .topTrailing) {
                VStack(alignment: .leading, spacing: 0) {
                    (Text("Now let's check\nwhat it's doing\nto your brain."))
                        .font(.system(size: 32, weight: .heavy, design: .rounded))
                        .kerning(-0.8)
                        .lineSpacing(2)
                        .foregroundStyle(FO.fg)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .frame(maxWidth: .infinity, alignment: .leading)

                Image("mascot-detective")
                    .resizable()
                    .scaledToFit()
                    .frame(width: 96, height: 96)
                    .shadow(color: FO.accent.opacity(0.28), radius: 18, y: 8)
                    .offset(x: 8, y: -14)
                    .accessibilityHidden(true)
            }
            .frame(height: 150)
        }
        .padding(.horizontal, 28)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .background(FO.bg.ignoresSafeArea())
        .safeAreaInset(edge: .bottom) {
            FOContinueButton(title: ctaTitle, action: ctaAction)
                .padding(.horizontal, 24)
                .padding(.bottom, 12)
        }
        .preferredColorScheme(.dark)
    }

    private var ctaTitle: String {
        if authorized { return "Test my Brain Age" }
        if previouslyDenied { return "Keep going" }
        return "Unlock the Real Numbers"
    }

    private func ctaAction() {
        if !authorized && previouslyDenied {
            onContinue()
            return
        }
        onContinue()
    }
}

// MARK: - Previews

#if DEBUG
#Preview("Industry Scare · $57B") {
    FocusOnboardIndustryScare(onContinue: {})
        .preferredColorScheme(.dark)
}

#Preview("D · Personal (287)") {
    FocusOnboardPersonalUnlocks(onContinue: {})
        .preferredColorScheme(.dark)
}

#Preview("D2 · Personal (declined)") {
    FocusOnboardPersonalUnlocks(onContinue: {}, authorized: false)
        .preferredColorScheme(.dark)
}
#endif
