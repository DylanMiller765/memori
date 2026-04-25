import SwiftUI
import DeviceActivity
import FamilyControls
import UIKit

extension DeviceActivityReport.Context {
    /// Must match the context name declared in the `FocusUnlocksReport` extension target.
    static let unlocks = Self("Unlocks Count")
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
            .font(.system(size: 12, weight: .semibold))
            .tracking(1.4)
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
                .foregroundStyle(FO.onAccent)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 17)
                .background(FO.accent, in: RoundedRectangle(cornerRadius: 14))
        }
        .buttonStyle(.plain)
    }
}

// MARK: - A) Stat Shock (144×)

struct FocusOnboardA: View {
    var onContinue: () -> Void
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            FOEyebrow(text: "FOCUS MODE")
                .padding(.top, 24)
                .padding(.bottom, 16)

            // The number — Monkeytype-coded
            HStack(alignment: .firstTextBaseline, spacing: 0) {
                Text("144")
                    .font(.system(size: 132, weight: .bold, design: .monospaced))
                    .kerning(-7)
                    .foregroundStyle(FO.fg)
                Text("×")
                    .font(.system(size: 132, weight: .bold, design: .monospaced))
                    .kerning(-7)
                    .foregroundStyle(FO.accent)
            }
            .lineLimit(1)
            .minimumScaleFactor(0.7)

            Text("avg phone unlocks / day")
                .font(.system(size: 12, weight: .semibold))
                .tracking(0.5)
                .foregroundStyle(FO.fg3)
                .textCase(.uppercase)
                .padding(.top, 10)

            // Emotional hook — italic quote callout with accent left border
            HStack(spacing: 0) {
                Rectangle().fill(FO.accent).frame(width: 2)
                (Text("Most of those ")
                 + Text("weren't your idea").underline(color: FO.accent).fontWeight(.semibold)
                 + Text("."))
                    .font(.system(size: 19, weight: .medium).italic())
                    .kerning(-0.2)
                    .foregroundStyle(FO.fg)
                    .lineSpacing(4)
                    .padding(.leading, 14)
                    .padding(.vertical, 2)
            }
            .fixedSize(horizontal: false, vertical: true)
            .frame(maxWidth: 320, alignment: .leading)
            .padding(.top, 22)

            Spacer()

            // Memo confident
            HStack {
                Image("mascot-goal")
                    .resizable()
                    .scaledToFit()
                    .frame(width: 200, height: 200)
                    .offset(x: -12, y: 12)
                Spacer()
            }

            // Big headline
            (Text("Take back\nyour ") + Text("attention").foregroundColor(FO.accent) + Text("."))
                .font(.system(size: 30, weight: .bold))
                .kerning(-0.9)
                .foregroundStyle(FO.fg)
                .lineSpacing(1)
                .padding(.bottom, 8)
        }
        .padding(.horizontal, 28)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .background(FO.bg.ignoresSafeArea())
        .safeAreaInset(edge: .bottom) {
            FOContinueButton(title: "Continue", action: onContinue)
                .padding(.horizontal, 24)
                .padding(.bottom, 12)
        }
        .preferredColorScheme(.dark)
    }
}

// MARK: - How It Works

struct FocusOnboardHowItWorks: View {
    var onContinue: () -> Void

    private struct Step: Identifiable {
        let id = UUID()
        let icon: String
        let label: String
        let desc: String
        let tint: Color
    }

    private let steps: [Step] = [
        Step(icon: "shield.fill", label: "Pick your distractions", desc: "Choose which apps to block.", tint: FO.accent),
        Step(icon: "brain.head.profile", label: "Memo locks them", desc: "Tap a blocked app → Memo blocks you.", tint: FO.memoPurple),
        Step(icon: "gamecontroller.fill", label: "Play to unlock", desc: "Win a brain game → earn 15 min.", tint: FO.success)
    ]

    var body: some View {
        ZStack(alignment: .bottomTrailing) {
            VStack(alignment: .leading, spacing: 0) {
                FOEyebrow(text: "HOW IT WORKS")
                    .padding(.top, 20)
                    .padding(.bottom, 12)

                (Text("How Memori blocks\nyour ") + Text("brain rot").foregroundColor(FO.accent) + Text("."))
                    .font(.system(size: 30, weight: .bold))
                    .kerning(-0.9)
                    .foregroundStyle(FO.fg)
                    .lineSpacing(1)
                    .padding(.bottom, 28)

                // Steps with connecting dashed line
                ZStack(alignment: .topLeading) {
                    // connecting dashed line
                    Rectangle()
                        .strokeBorder(style: StrokeStyle(lineWidth: 2, dash: [4, 5]))
                        .foregroundStyle(FO.accent.opacity(0.55))
                        .frame(width: 2)
                        .padding(.leading, 27)
                        .padding(.vertical, 54)

                    VStack(alignment: .leading, spacing: 26) {
                        ForEach(Array(steps.enumerated()), id: \.element.id) { index, step in
                            stepRow(index: index, step: step)
                        }
                    }
                }

                Spacer()
            }
            .padding(.horizontal, 28)

            // Memo thinking in bottom-right
            Image("mascot-thinking")
                .resizable()
                .scaledToFit()
                .frame(width: 130, height: 130)
                .rotationEffect(.degrees(-8))
                .offset(x: 28, y: 20)
                .allowsHitTesting(false)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .background(FO.bg.ignoresSafeArea())
        .safeAreaInset(edge: .bottom) {
            FOContinueButton(title: "Continue", action: onContinue)
                .padding(.horizontal, 24)
                .padding(.bottom, 12)
        }
        .preferredColorScheme(.dark)
    }

    private func stepRow(index: Int, step: Step) -> some View {
        HStack(alignment: .top, spacing: 18) {
            ZStack(alignment: .topTrailing) {
                RoundedRectangle(cornerRadius: 16)
                    .fill(FO.surface)
                    .frame(width: 56, height: 56)
                    .overlay(RoundedRectangle(cornerRadius: 16).stroke(FO.border2, lineWidth: 1))
                    .overlay(RoundedRectangle(cornerRadius: 16).strokeBorder(FO.bg, lineWidth: 4).padding(-4))
                    .overlay(Image(systemName: step.icon).font(.system(size: 20, weight: .semibold)).foregroundStyle(step.tint))

                // number badge
                Text("\(index + 1)")
                    .font(.system(size: 11, weight: .bold, design: .monospaced))
                    .foregroundStyle(FO.onAccent)
                    .frame(width: 22, height: 22)
                    .background(Circle().fill(step.tint))
                    .overlay(Circle().strokeBorder(FO.bg, lineWidth: 2))
                    .offset(x: 6, y: -6)
            }

            VStack(alignment: .leading, spacing: 4) {
                Text(step.label)
                    .font(.system(size: 17, weight: .bold))
                    .kerning(-0.2)
                    .foregroundStyle(FO.fg)
                Text(step.desc)
                    .font(.system(size: 14))
                    .foregroundStyle(FO.fg2)
                    .lineSpacing(2)
            }
            .padding(.top, 4)
            Spacer()
        }
    }
}

// MARK: - B) Bouncer

struct FocusOnboardB: View {
    var onContinue: () -> Void

    var body: some View {
        ZStack(alignment: .bottomLeading) {
            // aura behind memo
            RadialGradient(
                colors: [FO.accent.opacity(0.30), FO.memoPurple.opacity(0.12), .clear],
                center: .center, startRadius: 0, endRadius: 200
            )
            .frame(width: 360, height: 360)
            .blur(radius: 8)
            .offset(y: -80)

            // Apps queueing on the right
            VStack(spacing: 10) {
                ForEach(Array(apps.enumerated()), id: \.offset) { i, a in
                    appBadge(a, index: i)
                }
            }
            .frame(maxWidth: .infinity, alignment: .trailing)
            .padding(.trailing, 8)
            .padding(.top, 140)

            // Velvet rope
            HStack {
                Spacer()
                ZStack {
                    Capsule()
                        .fill(LinearGradient(colors: [FO.memoPurple, FO.accent], startPoint: .top, endPoint: .bottom))
                        .frame(width: 3)
                        .shadow(color: FO.accent.opacity(0.5), radius: 4)
                    VStack {
                        Circle().fill(FO.amber).frame(width: 9, height: 9)
                            .shadow(color: FO.amber, radius: 3)
                        Spacer()
                        Circle().fill(FO.amber).frame(width: 9, height: 9)
                            .shadow(color: FO.amber, radius: 3)
                    }
                }
                .frame(height: 280)
                .padding(.trailing, 70)
                .padding(.top, 100)
            }

            // Memo the bouncer
            HStack {
                Spacer()
                Image("mascot-goal")
                    .resizable()
                    .scaledToFit()
                    .frame(width: 280, height: 280)
                    .shadow(color: FO.accent.opacity(0.45), radius: 30, y: 16)
                    .padding(.trailing, 60)
                    .padding(.top, 60)
                Spacer()
            }

            // Bottom text block
            VStack(alignment: .leading, spacing: 0) {
                FOEyebrow(text: "FOCUS MODE")
                    .padding(.bottom, 12)

                (Text("Your apps just\ngot a ")
                 + Text("bouncer").foregroundColor(FO.accent).underline(color: FO.accent)
                 + Text("."))
                    .font(.system(size: 36, weight: .bold))
                    .kerning(-1.3)
                    .foregroundStyle(FO.fg)
                    .lineSpacing(-4)
                    .padding(.bottom, 14)

                Text("Memo only lets apps through if you beat a brain game. Earn your scroll.")
                    .font(.system(size: 15))
                    .foregroundStyle(FO.fg2)
                    .lineSpacing(3)
                    .frame(maxWidth: 340, alignment: .leading)
                    .padding(.bottom, 16)
            }
            .padding(.horizontal, 28)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(FO.bg.ignoresSafeArea())
        .safeAreaInset(edge: .bottom) {
            FOContinueButton(title: "Continue", action: onContinue)
                .padding(.horizontal, 24)
                .padding(.bottom, 12)
        }
        .preferredColorScheme(.dark)
    }

    private struct BouncerApp {
        let glyph: String
        let bg: AnyShapeStyle
        let denied: Bool
    }

    private var apps: [BouncerApp] {
        [
            BouncerApp(glyph: "IG", bg: AnyShapeStyle(LinearGradient(colors: [FO.speed, FO.memoPurple], startPoint: .topLeading, endPoint: .bottomTrailing)), denied: true),
            BouncerApp(glyph: "TT", bg: AnyShapeStyle(Color.black), denied: true),
            BouncerApp(glyph: "YT", bg: AnyShapeStyle(Color(red: 1.0, green: 0.0, blue: 0.2)), denied: false),
            BouncerApp(glyph: "X",  bg: AnyShapeStyle(Color.black), denied: false)
        ]
    }

    @ViewBuilder
    private func appBadge(_ a: BouncerApp, index: Int) -> some View {
        let rotations: [Double] = [3, -2, 4, -1]
        ZStack(alignment: .topTrailing) {
            RoundedRectangle(cornerRadius: 16)
                .fill(a.bg)
                .frame(width: 58, height: 58)
                .shadow(color: .black.opacity(0.5), radius: 8, y: 6)
                .overlay(
                    Text(a.glyph)
                        .font(.system(size: 18, weight: .heavy))
                        .foregroundStyle(.white)
                )
                .opacity(0.55)
                .saturation(0.7)
                .rotationEffect(.degrees(rotations[index % rotations.count]))

            if a.denied {
                Text("DENIED")
                    .font(.system(size: 9, weight: .heavy, design: .monospaced))
                    .tracking(1)
                    .foregroundStyle(FO.speed)
                    .padding(.horizontal, 6).padding(.vertical, 2)
                    .background(RoundedRectangle(cornerRadius: 3).strokeBorder(FO.speed, lineWidth: 2))
                    .rotationEffect(.degrees(-12))
                    .offset(x: 16, y: -8)
            }
        }
    }
}

// MARK: - C) Demo (apps locking)

struct FocusOnboardC: View {
    var onContinue: () -> Void

    private struct DemoApp: Identifiable {
        let id = UUID()
        let name: String
        let glyph: String
        let bg: AnyShapeStyle
        let fg: Color
        let locked: Bool
    }

    private let apps: [DemoApp] = [
        DemoApp(name: "Insta",   glyph: "IG", bg: AnyShapeStyle(LinearGradient(colors: [FO.speed, FO.memoPurple], startPoint: .topLeading, endPoint: .bottomTrailing)), fg: .white, locked: true),
        DemoApp(name: "TikTok",  glyph: "TT", bg: AnyShapeStyle(Color.black), fg: .white, locked: true),
        DemoApp(name: "X",       glyph: "X",  bg: AnyShapeStyle(Color.black), fg: .white, locked: true),
        DemoApp(name: "YT",      glyph: "YT", bg: AnyShapeStyle(Color(red: 1.0, green: 0.0, blue: 0.2)), fg: .white, locked: true),
        DemoApp(name: "Reddit",  glyph: "RD", bg: AnyShapeStyle(Color(red: 1.0, green: 0.27, blue: 0.0)), fg: .white, locked: false),
        DemoApp(name: "Snap",    glyph: "SC", bg: AnyShapeStyle(Color(red: 1.0, green: 0.99, blue: 0.0)), fg: FO.onAccent, locked: true),
        DemoApp(name: "Spotify", glyph: "SP", bg: AnyShapeStyle(Color(red: 0.114, green: 0.725, blue: 0.329)), fg: .white, locked: false),
        DemoApp(name: "Maps",    glyph: "M",  bg: AnyShapeStyle(Color(red: 0.247, green: 0.612, blue: 0.980)), fg: .white, locked: false)
    ]

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            FOEyebrow(text: "FOCUS MODE")
                .padding(.top, 20)
                .padding(.bottom, 10)

            Text("Pick your\ndistraction list.")
                .font(.system(size: 32, weight: .bold))
                .kerning(-0.96)
                .foregroundStyle(FO.fg)
                .lineSpacing(-2)
                .padding(.bottom, 10)

            Text("These apps stay locked until you earn 5 minutes by winning a brain game.")
                .font(.system(size: 14))
                .foregroundStyle(FO.fg2)
                .lineSpacing(3)
                .padding(.bottom, 18)

            // Mock home-screen panel
            ZStack(alignment: .bottomLeading) {
                RoundedRectangle(cornerRadius: 22)
                    .fill(LinearGradient(colors: [FO.memoIndigo, FO.surface], startPoint: .top, endPoint: .bottom))
                    .overlay(RoundedRectangle(cornerRadius: 22).stroke(FO.border2, lineWidth: 1))

                VStack(spacing: 0) {
                    // wallpaper time
                    VStack(spacing: 2) {
                        Text("WED · APR 24")
                            .font(.system(size: 11, weight: .semibold))
                            .tracking(1.1)
                            .foregroundStyle(Color.white.opacity(0.5))
                        Text("9:41")
                            .font(.system(size: 38, weight: .light))
                            .kerning(-0.76)
                            .foregroundStyle(Color.white.opacity(0.95))
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.top, 20)
                    .padding(.bottom, 14)

                    // grid
                    LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 14), count: 4), spacing: 12) {
                        ForEach(apps) { appTile($0) }
                    }
                    .padding(.horizontal, 18)
                    Spacer()
                }

                // Memo peeking
                Image("mascot-goal")
                    .resizable()
                    .scaledToFit()
                    .frame(width: 150, height: 150)
                    .rotationEffect(.degrees(-8))
                    .offset(x: 32, y: 28)
                    .allowsHitTesting(false)

                // Counter chip
                HStack(spacing: 6) {
                    Circle().fill(FO.accent).frame(width: 6, height: 6).shadow(color: FO.accent, radius: 3)
                    Text("5 LOCKED")
                        .font(.system(size: 12, weight: .bold, design: .monospaced))
                        .foregroundStyle(FO.fg)
                }
                .padding(.horizontal, 12).padding(.vertical, 6)
                .background(
                    Capsule()
                        .fill(FO.bg.opacity(0.7))
                        .overlay(Capsule().stroke(FO.border2, lineWidth: 1))
                )
                .padding(16)
            }
            .clipShape(RoundedRectangle(cornerRadius: 22))

            Spacer()
        }
        .padding(.horizontal, 28)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .background(FO.bg.ignoresSafeArea())
        .safeAreaInset(edge: .bottom) {
            FOContinueButton(title: "Continue", action: onContinue)
                .padding(.horizontal, 24)
                .padding(.bottom, 12)
        }
        .preferredColorScheme(.dark)
    }

    private func appTile(_ app: DemoApp) -> some View {
        VStack(spacing: 4) {
            ZStack {
                RoundedRectangle(cornerRadius: 14)
                    .fill(app.bg)
                    .frame(width: 52, height: 52)
                    .overlay(
                        Text(app.glyph)
                            .font(.system(size: 17, weight: .heavy))
                            .foregroundStyle(app.fg)
                    )
                    .shadow(color: .black.opacity(0.4), radius: 6, y: 4)

                if app.locked {
                    RoundedRectangle(cornerRadius: 14)
                        .fill(FO.bg.opacity(0.62))
                        .frame(width: 52, height: 52)
                        .overlay(
                            RoundedRectangle(cornerRadius: 14)
                                .strokeBorder(FO.accent, lineWidth: 1.5)
                        )
                        .shadow(color: FO.accent.opacity(0.5), radius: 8)
                        .overlay(
                            Image(systemName: "lock.fill")
                                .font(.system(size: 18, weight: .bold))
                                .foregroundStyle(FO.accent)
                        )
                }
            }
            Text(app.name)
                .font(.system(size: 10, weight: .medium))
                .foregroundStyle(app.locked ? Color.white.opacity(0.5) : Color.white.opacity(0.92))
        }
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

    private var minsBetween: Int { max(1, Int((1440.0 / Double(count)).rounded())) }

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
            FOEyebrow(text: "TURNS OUT…")
                .padding(.top, 24)
                .padding(.bottom, 14)

            Text("Actually, you unlocked your phone")
                .font(.system(size: 16, weight: .medium))
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

            // quote or auth prompt
            Group {
                if authorized {
                    HStack(spacing: 0) {
                        Rectangle().fill(FO.accent).frame(width: 2)
                        (Text("That's one unlock every ")
                         + Text("\(minsBetween) \(minsBetween == 1 ? "minute" : "minutes")")
                            .underline(color: FO.accent)
                            .fontWeight(.semibold)
                         + Text("."))
                            .font(.system(size: 19, weight: .medium).italic())
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

            // Memo (judgy) + headline
            ZStack(alignment: .bottomTrailing) {
                VStack(alignment: .leading, spacing: 0) {
                    Spacer()
                    (Text("Let's ") + Text("fix that").foregroundColor(FO.accent) + Text("."))
                        .font(.system(size: 36, weight: .bold))
                        .kerning(-1.1)
                        .foregroundStyle(FO.fg)
                        .padding(.bottom, 8)
                }

                Image("mascot-thinking")
                    .resizable()
                    .scaledToFit()
                    .frame(width: 88, height: 88)
                    .scaleEffect(x: -1, y: 1)
                    .shadow(color: .black.opacity(0.5), radius: 12, y: 8)
                    .offset(x: 12, y: -60)
            }
            .frame(height: 140)
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
        if authorized { return "Continue" }
        if previouslyDenied { return "Open Settings" }
        return "Unlock the Real Numbers"
    }

    private func ctaAction() {
        if !authorized && previouslyDenied {
            if let url = URL(string: UIApplication.openSettingsURLString) {
                UIApplication.shared.open(url)
            }
            return
        }
        onContinue()
    }
}

// MARK: - Previews

#if DEBUG
#Preview("A · 144×") {
    FocusOnboardA(onContinue: {})
        .preferredColorScheme(.dark)
}

#Preview("A2 · How It Works") {
    FocusOnboardHowItWorks(onContinue: {})
        .preferredColorScheme(.dark)
}

#Preview("B · Bouncer") {
    FocusOnboardB(onContinue: {})
        .preferredColorScheme(.dark)
}

#Preview("C · Demo") {
    FocusOnboardC(onContinue: {})
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
