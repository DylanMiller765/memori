import SwiftUI

struct ChallengeAcceptView: View {
    let challenge: ChallengeLink
    let onAccept: () -> Void
    let onDismiss: () -> Void

    var body: some View {
        VStack(spacing: 32) {
            Spacer()

            // Icon
            ZStack {
                Circle()
                    .fill(AppColors.accent.opacity(0.12))
                    .frame(width: 120, height: 120)
                Image(systemName: "figure.fencing")
                    .font(.system(size: 48))
                    .foregroundStyle(AppColors.accent)
            }

            // Challenge info
            VStack(spacing: 8) {
                Text(challenge.challengerName)
                    .font(.title.weight(.bold))
                Text("challenged you to")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                Text(challenge.game.displayName)
                    .font(.title2.weight(.bold))
                    .foregroundStyle(AppColors.accent)
            }

            Spacer()

            // Buttons
            VStack(spacing: 12) {
                Button { onAccept() } label: {
                    Text("Accept Challenge")
                        .accentButton()
                }
                .padding(.horizontal, 32)

                Button { onDismiss() } label: {
                    Text("Not Now")
                        .font(.headline)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .padding(.vertical, 32)
        .pageBackground()
    }
}
