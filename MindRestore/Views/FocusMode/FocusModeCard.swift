import SwiftUI

struct FocusModeCard: View {
    @Environment(FocusModeService.self) private var focusModeService
    @State private var showingSettings = false

    var body: some View {
        Button {
            showingSettings = true
        } label: {
            HStack(spacing: 14) {
                // Mascot image
                Image(focusModeService.isEnabled ? "mascot-goal" : "mascot-bored")
                    .renderingMode(.original)
                    .resizable()
                    .scaledToFit()
                    .frame(height: 44)

                VStack(alignment: .leading, spacing: 3) {
                    Text("Focus Mode")
                        .font(.system(size: 15, weight: .bold, design: .rounded))
                        .foregroundStyle(.primary)

                    if focusModeService.isEnabled {
                        if focusModeService.isTemporarilyUnlocked {
                            // Show time remaining on unlock
                            Text("Unlocked — \(unlockTimeRemaining)")
                                .font(.system(size: 12, weight: .medium))
                                .foregroundStyle(AppColors.accent)
                        } else {
                            Text("\(focusModeService.blockedAppCount) app\(focusModeService.blockedAppCount == 1 ? "" : "s") blocked")
                                .font(.system(size: 12, weight: .medium))
                                .foregroundStyle(.secondary)
                        }
                    } else {
                        Text("Tap to set up")
                            .font(.system(size: 12, weight: .medium))
                            .foregroundStyle(.secondary)
                    }
                }

                Spacer()

                // Toggle or chevron
                if focusModeService.isEnabled {
                    Circle()
                        .fill(AppColors.accent)
                        .frame(width: 10, height: 10)
                } else {
                    Image(systemName: "chevron.right")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(.tertiary)
                }
            }
            .padding(14)
            .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 16))
            .overlay(
                RoundedRectangle(cornerRadius: 16)
                    .stroke(focusModeService.isEnabled ? AppColors.accent.opacity(0.2) : .white.opacity(0.06), lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
        .sheet(isPresented: $showingSettings) {
            FocusModeSetupView()
        }
        .padding(.horizontal)
    }

    private var unlockTimeRemaining: String {
        guard let until = focusModeService.unlockUntil else { return "" }
        let remaining = max(0, Int(until.timeIntervalSince(.now)))
        let min = remaining / 60
        let sec = remaining % 60
        return "\(min):\(String(format: "%02d", sec)) left"
    }
}
