import SwiftUI

struct FocusModeCard: View {
    @Environment(FocusModeService.self) private var focusModeService
    @State private var showingSettings = false
    @State private var showingSetup = false
    @State private var showingUnlockGame = false
    @State private var now = Date.now

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
            if isUnlocked { now = .now }
        }
    }

    // MARK: - Active State

    private var activeCard: some View {
        VStack(spacing: 14) {
            // Header
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("FOCUS MODE")
                        .font(.system(size: 11, weight: .bold))
                        .tracking(1.5)
                        .foregroundStyle(AppColors.textTertiary)

                    HStack(spacing: 5) {
                        Image(systemName: "shield.fill")
                            .font(.system(size: 11, weight: .bold))
                            .foregroundStyle(AppColors.violet)
                        Text("Shielding \(focusModeService.blockedAppCount) app\(focusModeService.blockedAppCount == 1 ? "" : "s") · \(focusModeService.unlockDuration) min unlock")
                            .font(.system(size: 13, weight: .medium))
                            .foregroundStyle(AppColors.textSecondary)
                    }
                }

                Spacer()

                // Settings gear
                Button {
                    showingSettings = true
                } label: {
                    Image(systemName: "gearshape.fill")
                        .font(.system(size: 14))
                        .foregroundStyle(AppColors.textTertiary)
                }
                .buttonStyle(.plain)
            }

            // Play to unlock CTA
            Button {
                showingUnlockGame = true
            } label: {
                HStack(spacing: 8) {
                    Image(systemName: "play.fill")
                        .font(.system(size: 12, weight: .bold))
                    Text("Play to Unlock")
                        .font(.system(size: 14, weight: .bold, design: .rounded))
                }
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 12)
                .background(AppColors.violet, in: RoundedRectangle(cornerRadius: 10))
            }
            .buttonStyle(.plain)
        }
        .glowingCard(color: AppColors.violet, intensity: 0.20)
        .overlay(
            RoundedRectangle(cornerRadius: 14)
                .stroke(AppColors.violet.opacity(0.30), lineWidth: 1)
        )
        .shadow(color: AppColors.violet.opacity(0.18), radius: 12, x: 0, y: 4)
    }

    // MARK: - Unlocked State

    private var unlockedCard: some View {
        Button {
            showingSettings = true
        } label: {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("FOCUS MODE")
                        .font(.system(size: 11, weight: .bold))
                        .tracking(1.5)
                        .foregroundStyle(AppColors.textTertiary)

                    HStack(spacing: 5) {
                        Image(systemName: "lock.open.fill")
                            .font(.system(size: 11, weight: .bold))
                            .foregroundStyle(AppColors.amber)
                        Text("Unlocked · \(unlockTimeFormatted) left")
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundStyle(AppColors.amber)
                    }
                }

                Spacer()

                // Countdown ring
                ZStack {
                    Circle()
                        .stroke(AppColors.amber.opacity(0.20), lineWidth: 3)
                        .frame(width: 36, height: 36)

                    Circle()
                        .trim(from: 0, to: countdownProgress)
                        .stroke(AppColors.amber, style: StrokeStyle(lineWidth: 3, lineCap: .round))
                        .rotationEffect(.degrees(-90))
                        .frame(width: 36, height: 36)

                    Text("\(countdownMinutes)")
                        .font(.system(size: 13, weight: .bold, design: .rounded))
                        .foregroundStyle(AppColors.amber)
                }
            }
        }
        .buttonStyle(.plain)
        .glowingCard(color: AppColors.amber, intensity: 0.20)
        .overlay(
            RoundedRectangle(cornerRadius: 14)
                .stroke(AppColors.amber.opacity(0.25), lineWidth: 1)
        )
        .shadow(color: AppColors.amber.opacity(0.15), radius: 10, x: 0, y: 4)
    }

    // MARK: - Not Set Up

    private var notSetUpCard: some View {
        Button {
            showingSetup = true
        } label: {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("FOCUS MODE")
                        .font(.system(size: 11, weight: .bold))
                        .tracking(1.5)
                        .foregroundStyle(AppColors.textTertiary)

                    Text("Block distracting apps · play to unlock")
                        .font(.system(size: 13, weight: .medium))
                        .foregroundStyle(AppColors.textSecondary)
                }

                Spacer()

                HStack(spacing: 4) {
                    Text("Set Up")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(AppColors.violet)
                    Image(systemName: "chevron.right")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(AppColors.violet.opacity(0.6))
                }
            }
        }
        .buttonStyle(.plain)
        .glowingCard(color: AppColors.violet, intensity: 0.15)
        .overlay(
            RoundedRectangle(cornerRadius: 14)
                .stroke(AppColors.violet.opacity(0.20), lineWidth: 1)
        )
        .shadow(color: AppColors.violet.opacity(0.12), radius: 8, x: 0, y: 3)
    }

    // MARK: - Helpers

    private var unlockTimeFormatted: String {
        guard let until = focusModeService.unlockUntil else { return "0:00" }
        let remaining = max(0, Int(until.timeIntervalSince(now)))
        let min = remaining / 60
        let sec = remaining % 60
        return "\(min):\(String(format: "%02d", sec))"
    }

    private var countdownProgress: CGFloat {
        guard let until = focusModeService.unlockUntil else { return 0 }
        let total = CGFloat(focusModeService.unlockDuration * 60)
        guard total > 0 else { return 0 }
        return CGFloat(max(0, until.timeIntervalSince(now))) / total
    }

    private var countdownMinutes: Int {
        guard let until = focusModeService.unlockUntil else { return 0 }
        let remaining = max(0, Int(until.timeIntervalSince(now)))
        return (remaining + 59) / 60
    }
}
