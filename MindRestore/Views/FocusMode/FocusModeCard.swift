import SwiftUI

struct FocusModeCard: View {
    @Environment(FocusModeService.self) private var focusModeService
    @State private var showingSettings = false
    @State private var showingSetup = false
    @State private var showingUnlockGame = false
    @State private var shimmerOffset: CGFloat = -200
    @State private var now = Date.now

    // Convenience
    private var isActive: Bool { focusModeService.isEnabled }
    private var isUnlocked: Bool { focusModeService.isTemporarilyUnlocked }

    var body: some View {
        Group {
            if isActive {
                if isUnlocked {
                    unlockedCard
                } else {
                    activeCard
                }
            } else {
                notSetUpCard
            }
        }
        .padding(.horizontal)
        .sheet(isPresented: $showingSettings) {
            FocusModeSettingsView()
        }
        .sheet(isPresented: $showingSetup) {
            FocusModeSetupView()
        }
        .fullScreenCover(isPresented: $showingUnlockGame) {
            QuickGameView(
                unlockDurationMinutes: focusModeService.unlockDuration,
                onComplete: { showingUnlockGame = false }
            )
        }
        .onReceive(Timer.publish(every: 1, on: .main, in: .common).autoconnect()) { _ in
            if isUnlocked {
                now = .now
            }
        }
    }

    // MARK: - Active State (apps blocked)

    private var activeCard: some View {
        ZStack(alignment: .topTrailing) {
            // Background + violet gradient overlay
            RoundedRectangle(cornerRadius: 20)
                .fill(AppColors.cardSurface)
                .overlay(
                    RoundedRectangle(cornerRadius: 20)
                        .fill(
                            LinearGradient(
                                colors: [AppColors.violet.opacity(0.15), AppColors.indigo.opacity(0.15)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                )

            // Gradient border
            RoundedRectangle(cornerRadius: 20)
                .stroke(
                    LinearGradient(
                        colors: [AppColors.violet.opacity(0.55), AppColors.violet.opacity(0.18)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    lineWidth: 1.5
                )

            // Main content row
            VStack(spacing: 0) {
                HStack(spacing: 14) {
                    // Left: Mascot with violet glow
                    ZStack {
                        Circle()
                            .fill(AppColors.violet.opacity(0.20))
                            .frame(width: 40, height: 40)

                        Image("mascot-streak-fire")
                            .renderingMode(.original)
                            .resizable()
                            .scaledToFit()
                            .frame(height: 60)
                    }

                    // Center: text column
                    VStack(alignment: .leading, spacing: 5) {
                        Text("Focus Mode")
                            .font(.system(size: 17, weight: .bold, design: .rounded))
                            .foregroundStyle(.primary)

                        Label {
                            Text("Shielding \(focusModeService.blockedAppCount) app\(focusModeService.blockedAppCount == 1 ? "" : "s")")
                                .font(.system(size: 12, weight: .semibold))
                                .foregroundStyle(AppColors.violet)
                        } icon: {
                            Image(systemName: "shield.fill")
                                .font(.system(size: 10, weight: .bold))
                                .foregroundStyle(AppColors.violet)
                        }

                        Text("Play a brain game for \(focusModeService.unlockDuration) min of free time")
                            .font(.system(size: 11))
                            .foregroundStyle(.secondary)
                            .lineLimit(2)
                    }

                    Spacer(minLength: 4)

                    // Right: Play button
                    Button {
                        showingUnlockGame = true
                    } label: {
                        Text("Play")
                            .font(.system(size: 13, weight: .bold, design: .rounded))
                            .foregroundStyle(.white)
                            .padding(.horizontal, 16)
                            .padding(.vertical, 8)
                            .background(
                                LinearGradient(
                                    colors: [AppColors.violet, AppColors.indigo],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                ),
                                in: Capsule()
                            )
                    }
                    .buttonStyle(.plain)
                }
                .padding(.horizontal, 16)
                .padding(.top, 18)
                .padding(.bottom, 14)

                // Bottom shimmer line
                shimmerLine
            }

            // Top-right gear icon
            Button {
                showingSettings = true
            } label: {
                Image(systemName: "gearshape.fill")
                    .font(.system(size: 12))
                    .foregroundStyle(.tertiary)
                    .padding(12)
            }
            .buttonStyle(.plain)
        }
        .clipShape(RoundedRectangle(cornerRadius: 20))
        .shadow(color: AppColors.violet.opacity(0.25), radius: 16, x: 0, y: 6)
        .frame(minHeight: 140)
        .onAppear { startShimmer() }
    }

    // MARK: - Unlocked State (temporary access)

    private var unlockedCard: some View {
        Button {
            showingSettings = true
        } label: {
            ZStack(alignment: .topTrailing) {
                // Background + amber tint
                RoundedRectangle(cornerRadius: 20)
                    .fill(AppColors.cardSurface)
                    .overlay(
                        RoundedRectangle(cornerRadius: 20)
                            .fill(AppColors.amber.opacity(0.10))
                    )

                // Amber gradient border
                RoundedRectangle(cornerRadius: 20)
                    .stroke(
                        LinearGradient(
                            colors: [AppColors.amber.opacity(0.45), AppColors.amber.opacity(0.15)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        lineWidth: 1.5
                    )

                // Main row
                HStack(spacing: 14) {
                    // Left: Mascot
                    Image("mascot-thinking")
                        .renderingMode(.original)
                        .resizable()
                        .scaledToFit()
                        .frame(height: 60)

                    // Center: text column
                    VStack(alignment: .leading, spacing: 5) {
                        Text("Focus Mode")
                            .font(.system(size: 17, weight: .bold, design: .rounded))
                            .foregroundStyle(.primary)

                        Label {
                            Text("Unlocked · \(unlockTimeRemainingFormatted) left")
                                .font(.system(size: 12, weight: .semibold))
                                .foregroundStyle(AppColors.amber)
                        } icon: {
                            Image(systemName: "lock.open.fill")
                                .font(.system(size: 10, weight: .bold))
                                .foregroundStyle(AppColors.amber)
                        }
                    }

                    Spacer(minLength: 4)

                    // Right: Countdown ring
                    countdownRing
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 18)
            }
        }
        .buttonStyle(.plain)
        .clipShape(RoundedRectangle(cornerRadius: 20))
        .shadow(color: AppColors.amber.opacity(0.20), radius: 12, x: 0, y: 4)
        .frame(minHeight: 140)
    }

    // MARK: - Not Set Up State

    private var notSetUpCard: some View {
        Button {
            showingSetup = true
        } label: {
            ZStack {
                // Background
                RoundedRectangle(cornerRadius: 20)
                    .fill(AppColors.cardSurface)

                // Subtle border
                RoundedRectangle(cornerRadius: 20)
                    .stroke(Color.white.opacity(0.10), lineWidth: 1)

                // Main row
                HStack(spacing: 14) {
                    Image("mascot-goal")
                        .renderingMode(.original)
                        .resizable()
                        .scaledToFit()
                        .frame(height: 50)

                    VStack(alignment: .leading, spacing: 4) {
                        Text("Focus Mode")
                            .font(.system(size: 17, weight: .bold, design: .rounded))
                            .foregroundStyle(.primary)

                        Text("Block distracting apps · earn screen time")
                            .font(.system(size: 12, weight: .medium))
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                            .minimumScaleFactor(0.8)
                    }

                    Spacer(minLength: 4)

                    // Set Up pill
                    Text("Set Up")
                        .font(.system(size: 12, weight: .semibold, design: .rounded))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 14)
                        .padding(.vertical, 7)
                        .background(
                            LinearGradient(
                                colors: [AppColors.violet, AppColors.indigo],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ),
                            in: Capsule()
                        )
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 14)
            }
        }
        .buttonStyle(.plain)
        .clipShape(RoundedRectangle(cornerRadius: 20))
        .frame(minHeight: 80)
    }

    // MARK: - Countdown Ring

    private var countdownRing: some View {
        let progress = countdownProgress
        let minutesLeft = countdownMinutesLeft

        return ZStack {
            // Background circle
            Circle()
                .fill(AppColors.amber.opacity(0.15))
                .frame(width: 36, height: 36)

            // Progress arc
            Circle()
                .trim(from: 0, to: progress)
                .stroke(AppColors.amber, style: StrokeStyle(lineWidth: 3, lineCap: .round))
                .rotationEffect(.degrees(-90))
                .frame(width: 36, height: 36)

            // Minutes text
            Text("\(minutesLeft)")
                .font(.system(size: 13, weight: .bold, design: .rounded))
                .foregroundStyle(AppColors.amber)
        }
    }

    // MARK: - Shimmer Line

    private var shimmerLine: some View {
        Rectangle()
            .fill(
                LinearGradient(
                    stops: [
                        .init(color: .clear, location: 0.0),
                        .init(color: AppColors.violet.opacity(0.6), location: 0.5),
                        .init(color: .clear, location: 1.0)
                    ],
                    startPoint: .leading,
                    endPoint: .trailing
                )
            )
            .frame(height: 2)
            .offset(x: shimmerOffset)
            .mask(Rectangle().frame(height: 2))
    }

    // MARK: - Helpers

    private var unlockTimeRemainingFormatted: String {
        guard let until = focusModeService.unlockUntil else { return "0:00" }
        let remaining = max(0, Int(until.timeIntervalSince(now)))
        let min = remaining / 60
        let sec = remaining % 60
        return "\(min):\(String(format: "%02d", sec))"
    }

    private var countdownProgress: CGFloat {
        guard let until = focusModeService.unlockUntil else { return 0 }
        let totalSeconds = CGFloat(focusModeService.unlockDuration * 60)
        guard totalSeconds > 0 else { return 0 }
        let remaining = CGFloat(max(0, until.timeIntervalSince(now)))
        return remaining / totalSeconds
    }

    private var countdownMinutesLeft: Int {
        guard let until = focusModeService.unlockUntil else { return 0 }
        let remaining = max(0, Int(until.timeIntervalSince(now)))
        return (remaining + 59) / 60 // round up
    }

    private func startShimmer() {
        withAnimation(
            .linear(duration: 2.5)
            .repeatForever(autoreverses: false)
        ) {
            shimmerOffset = 200
        }
    }
}
