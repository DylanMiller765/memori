import SwiftUI

// MARK: - Challenge Type

enum FriendChallengeType {
    case brainScore(brainAge: Int, brainType: BrainType, digitScore: Double, reactionScore: Double, visualScore: Double)
    case dailyChallenge(challengeName: String)
    case duel(exerciseType: String)
}

// MARK: - Challenge View

struct ChallengeView: View {
    @Environment(\.dismiss) private var dismiss
    let challengeType: FriendChallengeType
    let playerScore: Int
    let playerName: String
    let percentile: Int

    @State private var shareImage: UIImage?
    @State private var showShareSheet = false
    @State private var copiedLink = false
    @State private var appearAnimation = false

    private var shareText: String {
        switch challengeType {
        case .brainScore(let brainAge, _, _, _, _):
            return "I scored \(playerScore) on Memori Brain Assessment (Brain Age: \(brainAge))! Can you beat me? Download Memori to try."
        case .dailyChallenge(let challengeName):
            return "I scored \(playerScore) on today's \(challengeName) challenge in Memori! Think you can beat me? Download Memori to try."
        case .duel(let exerciseType):
            return "I just scored \(playerScore) on \(exerciseType) in Memori! Challenge accepted? Download Memori to try."
        }
    }

    private var brainAge: Int {
        if case .brainScore(let age, _, _, _, _) = challengeType {
            return age
        }
        return 0
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 28) {
                    // MARK: Share Card Preview
                    shareCardPreview
                        .opacity(appearAnimation ? 1 : 0)
                        .scaleEffect(appearAnimation ? 1 : 0.8)

                    // MARK: Action Buttons
                    actionButtons
                        .opacity(appearAnimation ? 1 : 0)
                        .offset(y: appearAnimation ? 0 : 30)
                }
                .padding(.horizontal, 20)
                .padding(.top, 8)
                .padding(.bottom, 40)
            }
            .navigationTitle("Challenge a Friend")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        dismiss()
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .font(.title3)
                            .foregroundStyle(.secondary)
                    }
                    .accessibilityLabel("Close")
                }
            }
        }
        .task {
            await renderShareImage()
            withAnimation(.spring(response: 0.7, dampingFraction: 0.8)) {
                appearAnimation = true
            }
        }
    }

    // MARK: - Hero Score Section

    private var heroScoreSection: some View {
        VStack(spacing: 12) {
            Text("YOUR SCORE")
                .font(.caption.weight(.bold))
                .tracking(3)
                .foregroundStyle(.secondary)

            Text("\(playerScore)")
                .font(.system(size: 88, weight: .bold, design: .monospaced))
                .foregroundStyle(AppColors.accent)

            // Percentile badge
            HStack(spacing: 6) {
                Image(systemName: "trophy.fill")
                    .font(.caption)
                    .foregroundStyle(.yellow)
                Text("Top \(max(1, 100 - percentile))%")
                    .font(.subheadline.weight(.bold))
                Text("of all players")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
            .background(
                Capsule()
                    .fill(AppColors.cardSurface)
            )

            // Brain age for brain score challenges
            if case .brainScore(let brainAge, let brainType, _, _, _) = challengeType {
                HStack(spacing: 16) {
                    VStack(spacing: 2) {
                        Text("\(brainAge)")
                            .font(.title2.weight(.bold))
                            .foregroundStyle(brainAge <= 25 ? AppColors.accent : AppColors.coral)
                        Text("Brain Age")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }

                    Rectangle()
                        .fill(.quaternary)
                        .frame(width: 1, height: 28)

                    VStack(spacing: 2) {
                        HStack(spacing: 4) {
                            Image(systemName: brainType.icon)
                                .font(.caption)
                            Text(brainType.displayName)
                                .font(.subheadline.weight(.bold))
                        }
                        .foregroundStyle(brainTypeColor(brainType))
                        Text("Brain Type")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                }
                .padding(.top, 4)
            }
        }
        .padding(.vertical, 24)
        .frame(maxWidth: .infinity)
        .glowingCard(color: AppColors.accent, intensity: 0.2)
    }

    // MARK: - Share Card Preview

    private var shareCardPreview: some View {
        VStack(spacing: 12) {
            Text("SHARE PREVIEW")
                .font(.caption.weight(.bold))
                .tracking(2)
                .foregroundStyle(.secondary)

            Group {
                switch challengeType {
                case .brainScore(let brainAge, let brainType, let digitScore, let reactionScore, let visualScore):
                    TikTokBrainScoreCard(
                        brainScore: playerScore,
                        brainAge: brainAge,
                        brainType: brainType,
                        percentile: percentile,
                        digitScore: digitScore,
                        reactionScore: reactionScore,
                        visualScore: visualScore
                    )
                case .dailyChallenge(let challengeName):
                    TikTokChallengeCard(
                        challengerName: playerName,
                        challengerScore: playerScore,
                        challengeType: challengeName
                    )
                case .duel(let exerciseType):
                    TikTokChallengeCard(
                        challengerName: playerName,
                        challengerScore: playerScore,
                        challengeType: exerciseType
                    )
                }
            }
            .scaleEffect(0.55)
            .frame(height: 350)
            .clipped()
        }
    }

    // MARK: - Action Buttons

    private var actionButtons: some View {
        VStack(spacing: 14) {
            // Share button
            if let shareImage {
                ShareLink(
                    item: shareText,
                    preview: SharePreview(
                        "Memori Challenge",
                        image: Image(uiImage: shareImage)
                    )
                ) {
                    HStack(spacing: 10) {
                        Image(systemName: "square.and.arrow.up.fill")
                            .font(.body.weight(.semibold))
                        Text("Challenge a Friend")
                            .font(.headline)
                    }
                    .gradientButton()
                }
            } else {
                HStack(spacing: 10) {
                    ProgressView()
                        .tint(.white)
                    Text("Preparing share card...")
                        .font(.headline)
                }
                .gradientButton()
                .opacity(0.6)
            }

            // Copy link button
            Button {
                UIPasteboard.general.string = shareText
                withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                    copiedLink = true
                }
                DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                    withAnimation { copiedLink = false }
                }
            } label: {
                HStack(spacing: 10) {
                    Image(systemName: copiedLink ? "checkmark.circle.fill" : "link")
                        .font(.body.weight(.semibold))
                        .contentTransition(.symbolEffect(.replace))
                    Text(copiedLink ? "Link Copied!" : "Copy Link")
                        .font(.headline)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 16)
                .background(
                    RoundedRectangle(cornerRadius: 12)
                        .fill(AppColors.cardSurface)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(copiedLink ? AppColors.accent.opacity(0.4) : Color.clear, lineWidth: 1.5)
                )
                .foregroundStyle(copiedLink ? AppColors.accent : .primary)
            }

            // Motivational text
            Text("Show your friends who has the sharpest mind")
                .font(.caption)
                .foregroundStyle(.tertiary)
                .padding(.top, 4)
        }
    }

    // MARK: - Helpers

    @MainActor
    private func renderShareImage() async {
        let cardView: AnyView
        switch challengeType {
        case .brainScore(let brainAge, let brainType, let digitScore, let reactionScore, let visualScore):
            cardView = AnyView(
                TikTokBrainScoreCard(
                    brainScore: playerScore,
                    brainAge: brainAge,
                    brainType: brainType,
                    percentile: percentile,
                    digitScore: digitScore,
                    reactionScore: reactionScore,
                    visualScore: visualScore
                )
            )
        case .dailyChallenge(let challengeName):
            cardView = AnyView(
                TikTokChallengeCard(
                    challengerName: playerName,
                    challengerScore: playerScore,
                    challengeType: challengeName
                )
            )
        case .duel(let exerciseType):
            cardView = AnyView(
                TikTokChallengeCard(
                    challengerName: playerName,
                    challengerScore: playerScore,
                    challengeType: exerciseType
                )
            )
        }
        shareImage = cardView.renderAsImage(size: CGSize(width: 360, height: 640), scale: 3)
    }

    private func brainTypeColor(_ type: BrainType) -> Color {
        switch type {
        case .lightningReflex: return .yellow
        case .numberCruncher: return AppColors.sky
        case .patternMaster: return AppColors.violet
        case .balancedBrain: return AppColors.accent
        }
    }
}

// MARK: - Challenge Result View

struct ChallengeResultView: View {
    let player1Name: String
    let player1Score: Int
    let player2Name: String
    let player2Score: Int
    let exerciseType: String

    @Environment(\.dismiss) private var dismiss
    @State private var shareImage: UIImage?
    @State private var revealAnimation = false

    private var winnerName: String {
        player1Score >= player2Score ? player1Name : player2Name
    }

    private var scoreDifference: Int {
        abs(player1Score - player2Score)
    }

    private var isTie: Bool {
        player1Score == player2Score
    }

    private var player1Won: Bool {
        player1Score > player2Score
    }

    private var player2Won: Bool {
        player2Score > player1Score
    }

    private var shareText: String {
        if isTie {
            return "It's a tie! We both scored \(player1Score) on \(exerciseType) in Memori! Who will break the tie? Download Memori to challenge us."
        }
        return "\(winnerName) won the \(exerciseType) duel in Memori! \(player1Won ? player1Score : player2Score) vs \(player1Won ? player2Score : player1Score). Think you can beat us? Download Memori to try."
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 28) {
                    // MARK: Results Header
                    resultsHeader
                        .opacity(revealAnimation ? 1 : 0)
                        .scaleEffect(revealAnimation ? 1 : 0.85)

                    // MARK: Score Comparison
                    scoreComparison
                        .opacity(revealAnimation ? 1 : 0)
                        .offset(y: revealAnimation ? 0 : 20)

                    // MARK: Score Difference
                    if !isTie {
                        scoreDifferenceSection
                            .opacity(revealAnimation ? 1 : 0)
                            .offset(y: revealAnimation ? 0 : 20)
                    }

                    // MARK: Action Buttons
                    resultActionButtons
                        .opacity(revealAnimation ? 1 : 0)
                        .offset(y: revealAnimation ? 0 : 30)
                }
                .padding(.horizontal, 20)
                .padding(.top, 8)
                .padding(.bottom, 40)
            }
            .navigationTitle("Duel Results")
            .navigationBarTitleDisplayMode(.inline)
        }
        .task {
            await renderResultShareImage()
            withAnimation(.spring(response: 0.8, dampingFraction: 0.75).delay(0.2)) {
                revealAnimation = true
            }
        }
    }

    // MARK: - Results Header

    private var resultsHeader: some View {
        VStack(spacing: 8) {
            Text("RESULTS")
                .font(.caption.weight(.bold))
                .tracking(4)
                .foregroundStyle(.secondary)

            if isTie {
                HStack(spacing: 8) {
                    Image(systemName: "equal.circle.fill")
                        .font(.title)
                        .foregroundStyle(AppColors.teal)
                    Text("It's a Tie!")
                        .font(.title.weight(.bold))
                }
            } else {
                VStack(spacing: 4) {
                    Image(systemName: "crown.fill")
                        .font(.largeTitle)
                        .foregroundStyle(.yellow)
                    Text("\(winnerName) Wins!")
                        .font(.title.weight(.bold))
                        .foregroundStyle(AppColors.accentGradient)
                }
            }

            Text(exerciseType)
                .font(.subheadline.weight(.medium))
                .foregroundStyle(.secondary)
        }
        .padding(.vertical, 20)
    }

    // MARK: - Score Comparison

    private var scoreComparison: some View {
        HStack(spacing: 0) {
            // Player 1
            playerScoreCard(
                name: player1Name,
                score: player1Score,
                isWinner: player1Won,
                isLoser: player2Won
            )

            // VS divider
            VStack(spacing: 4) {
                Text("VS")
                    .font(.caption.weight(.bold))
                    .tracking(2)
                    .foregroundStyle(.tertiary)
            }
            .frame(width: 44)

            // Player 2
            playerScoreCard(
                name: player2Name,
                score: player2Score,
                isWinner: player2Won,
                isLoser: player1Won
            )
        }
    }

    private func playerScoreCard(name: String, score: Int, isWinner: Bool, isLoser: Bool) -> some View {
        VStack(spacing: 10) {
            if isWinner {
                Image(systemName: "crown.fill")
                    .font(.title3)
                    .foregroundStyle(.yellow)
            } else {
                Color.clear.frame(height: 22)
            }

            Text(name)
                .font(.subheadline.weight(.semibold))
                .lineLimit(1)
                .foregroundStyle(isLoser ? .secondary : .primary)

            Text("\(score)")
                .font(.system(size: 48, weight: .bold, design: .monospaced))
                .foregroundStyle(
                    isWinner
                        ? AnyShapeStyle(AppColors.accentGradient)
                        : isLoser
                            ? AnyShapeStyle(AppColors.coral.opacity(0.6))
                            : AnyShapeStyle(.primary)
                )
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 20)
        .glowingCard(
            color: isWinner ? AppColors.accent : isLoser ? AppColors.coral : .gray,
            intensity: isWinner ? 0.25 : isLoser ? 0.1 : 0.05
        )
    }

    // MARK: - Score Difference

    private var scoreDifferenceSection: some View {
        HStack(spacing: 8) {
            Image(systemName: "arrow.up.right.circle.fill")
                .foregroundStyle(AppColors.accent)
            Text("+\(scoreDifference) points ahead")
                .font(.headline.weight(.bold))
                .foregroundStyle(AppColors.accent)
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 12)
        .background(
            Capsule()
                .fill(AppColors.accent.opacity(0.1))
        )
    }

    // MARK: - Result Action Buttons

    private var resultActionButtons: some View {
        VStack(spacing: 14) {
            // Share Results
            if let shareImage {
                ShareLink(
                    item: shareText,
                    preview: SharePreview(
                        "Memori Duel Results",
                        image: Image(uiImage: shareImage)
                    )
                ) {
                    HStack(spacing: 10) {
                        Image(systemName: "square.and.arrow.up.fill")
                            .font(.body.weight(.semibold))
                        Text("Share Results")
                            .font(.headline)
                    }
                    .gradientButton()
                }
            } else {
                HStack(spacing: 10) {
                    ProgressView()
                        .tint(.white)
                    Text("Preparing results...")
                        .font(.headline)
                }
                .gradientButton()
                .opacity(0.6)
            }

            HStack(spacing: 14) {
                // Play Again
                Button {
                    // Play again action handled by parent
                } label: {
                    HStack(spacing: 8) {
                        Image(systemName: "arrow.counterclockwise")
                            .font(.body.weight(.semibold))
                        Text("Play Again")
                            .font(.headline)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
                    .background(
                        RoundedRectangle(cornerRadius: 12)
                            .fill(AppColors.cardSurface)
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(AppColors.accent.opacity(0.2), lineWidth: 1)
                    )
                }

                // Done
                Button {
                    dismiss()
                } label: {
                    HStack(spacing: 8) {
                        Image(systemName: "checkmark")
                            .font(.body.weight(.semibold))
                        Text("Done")
                            .font(.headline)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
                    .background(
                        RoundedRectangle(cornerRadius: 12)
                            .fill(AppColors.cardSurface)
                    )
                }
            }
        }
    }

    // MARK: - Helpers

    @MainActor
    private func renderResultShareImage() async {
        let card = TikTokDuelResultCard(
            player1Name: player1Name,
            player1Score: player1Score,
            player2Name: player2Name,
            player2Score: player2Score,
            exerciseType: exerciseType
        )
        shareImage = card.renderAsImage(size: CGSize(width: 360, height: 640), scale: 3)
    }
}

// MARK: - Previews

#Preview("Brain Score Challenge") {
    ChallengeView(
        challengeType: .brainScore(
            brainAge: 23,
            brainType: .lightningReflex,
            digitScore: 78,
            reactionScore: 92,
            visualScore: 65
        ),
        playerScore: 847,
        playerName: "Dylan",
        percentile: 89
    )
}

#Preview("Daily Challenge") {
    ChallengeView(
        challengeType: .dailyChallenge(challengeName: "Memory Sprint"),
        playerScore: 520,
        playerName: "Dylan",
        percentile: 72
    )
}

#Preview("Duel Results") {
    ChallengeResultView(
        player1Name: "Dylan",
        player1Score: 847,
        player2Name: "Alex",
        player2Score: 723,
        exerciseType: "Digit Span"
    )
}
