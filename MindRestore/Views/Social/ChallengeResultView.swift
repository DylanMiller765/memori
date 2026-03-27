import SwiftUI
import GameKit

struct FriendChallengeResultView: View {
    let challenge: ChallengeLink
    let playerScore: Int
    let onShareResult: () -> Void
    let onChallengeAnother: () -> Void
    let onDone: () -> Void

    private var playerWon: Bool {
        if challenge.game == .reactionTime {
            return playerScore < challenge.score  // Lower is better
        }
        return playerScore > challenge.score
    }

    private var isTie: Bool {
        playerScore == challenge.score
    }

    var body: some View {
        VStack(spacing: 24) {
            Spacer()

            // Result header
            if isTie {
                Text("It's a Tie!")
                    .font(.title.weight(.bold))
                    .foregroundStyle(AppColors.amber)
            } else {
                Text(playerWon ? "You Won!" : "They Got You!")
                    .font(.title.weight(.bold))
                    .foregroundStyle(playerWon ? AppColors.mint : AppColors.coral)
            }

            // Side-by-side scores
            HStack(spacing: 0) {
                // Challenger
                VStack(spacing: 8) {
                    Text(challenge.challengerName)
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.secondary)
                    Text("\(challenge.score)")
                        .font(.system(size: 36, weight: .bold, design: .rounded))
                        .foregroundStyle(!playerWon && !isTie ? AppColors.mint : .primary)
                }
                .frame(maxWidth: .infinity)

                Text("vs")
                    .font(.title3.weight(.bold))
                    .foregroundStyle(.secondary)

                // Player
                VStack(spacing: 8) {
                    Text("You")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.secondary)
                    Text("\(playerScore)")
                        .font(.system(size: 36, weight: .bold, design: .rounded))
                        .foregroundStyle(playerWon ? AppColors.mint : .primary)
                }
                .frame(maxWidth: .infinity)
            }
            .padding(.vertical, 20)
            .appCard()
            .padding(.horizontal)

            Spacer()

            // Action buttons
            VStack(spacing: 12) {
                Button { onShareResult() } label: {
                    HStack(spacing: 8) {
                        Image(systemName: "square.and.arrow.up")
                        Text("Share Result")
                    }
                    .accentButton()
                }
                .padding(.horizontal, 32)

                Button { onChallengeAnother() } label: {
                    Text("Challenge Someone Else")
                        .gradientButton()
                }
                .padding(.horizontal, 32)

                Button { onDone() } label: {
                    Text("Done")
                        .font(.headline)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .padding(.vertical, 32)
    }
}
