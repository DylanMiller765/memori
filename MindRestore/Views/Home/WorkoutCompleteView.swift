import SwiftUI

struct WorkoutCompleteView: View {
    let oldBrainScore: Int
    let newBrainScore: Int
    let oldBrainAge: Int
    let newBrainAge: Int
    let streak: Int
    var userAge: Int = 0
    let onDone: () -> Void

    @State private var displayedScore: Int = 0
    @State private var showDelta: Bool = false
    @State private var showDetails: Bool = false
    @State private var showConfetti: Bool = false
    @State private var shareImage: UIImage?
    @AppStorage("celebratedBrainAgeBelow") private var celebratedBrainAgeBelow = false

    private var scoreDelta: Int { newBrainScore - oldBrainScore }
    private var ageDelta: Int { newBrainAge - oldBrainAge }

    var body: some View {
        ZStack {
            AppColors.pageBg.ignoresSafeArea()

            VStack(spacing: 28) {
                Spacer()

                // Title
                Text("Workout Complete!")
                    .font(.system(size: 28, weight: .black, design: .rounded))
                    .foregroundStyle(AppColors.textPrimary)

                // Score ring
                scoreRing

                // Delta pop-in
                if showDelta {
                    deltaLabel
                        .transition(.scale.combined(with: .opacity))
                }

                // Details: brain age + streak
                if showDetails {
                    detailsSection
                        .transition(.opacity.combined(with: .move(edge: .bottom)))
                }

                // First-time brain age below real age celebration
                if showDetails && userAge > 0 && newBrainAge < userAge && !celebratedBrainAgeBelow {
                    VStack(spacing: 8) {
                        Text("Your brain is younger than you!")
                            .font(.headline.weight(.bold))
                            .foregroundStyle(AppColors.teal)

                        ShareLink(
                            item: "My Brain Age is \(newBrainAge) — that's \(userAge - newBrainAge) years younger than my real age! \u{1F9E0}\u{1F525}\n\nTest yours with Memo"
                        ) {
                            HStack(spacing: 6) {
                                Image(systemName: "square.and.arrow.up")
                                    .font(.caption.weight(.semibold))
                                Text("Share This")
                                    .font(.subheadline.weight(.bold))
                            }
                            .foregroundStyle(.white)
                            .padding(.horizontal, 20)
                            .padding(.vertical, 10)
                            .background(AppColors.teal, in: Capsule())
                        }
                    }
                    .transition(.scale.combined(with: .opacity))
                    .onAppear {
                        celebratedBrainAgeBelow = true
                    }
                }

                Spacer()

                // Bottom buttons
                VStack(spacing: 12) {
                    if let shareImage {
                        ShareLink(
                            item: Image(uiImage: shareImage),
                            preview: SharePreview("Brain Score: \(newBrainScore)", image: Image(uiImage: shareImage))
                        ) {
                            HStack(spacing: 8) {
                                Image(systemName: "square.and.arrow.up")
                                    .font(.system(size: 15, weight: .semibold))
                                Text("Share Results")
                            }
                            .gradientButton()
                        }
                    }

                    Button(action: onDone) {
                        Text("Done")
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundStyle(AppColors.textSecondary)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 14)
                    }
                }
                .padding(.horizontal, 24)
                .padding(.bottom, 16)
            }

            // Confetti overlay
            if showConfetti {
                ConfettiView()
                    .allowsHitTesting(false)
            }
        }
        .onAppear {
            renderShareImage()
            startAnimationSequence()
        }
    }

    // MARK: - Score Ring

    private var scoreRing: some View {
        ZStack {
            // Background track
            Circle()
                .stroke(AppColors.cardBorder, lineWidth: 10)

            // Progress arc
            Circle()
                .trim(from: 0, to: min(CGFloat(displayedScore) / 100.0, 1.0))
                .stroke(
                    AppColors.accent,
                    style: StrokeStyle(lineWidth: 10, lineCap: .round)
                )
                .rotationEffect(.degrees(-90))

            // Score number
            VStack(spacing: 4) {
                Text("\(displayedScore)")
                    .font(.system(size: 52, weight: .bold, design: .rounded))
                    .foregroundStyle(AppColors.textPrimary)
                    .contentTransition(.numericText())

                Text("BRAIN SCORE")
                    .font(.system(size: 11, weight: .bold))
                    .tracking(2)
                    .foregroundStyle(AppColors.textTertiary)
            }
        }
        .frame(width: 160, height: 160)
    }

    // MARK: - Delta Label

    private var deltaLabel: some View {
        HStack(spacing: 4) {
            if scoreDelta >= 0 {
                Image(systemName: "arrow.up")
                    .font(.system(size: 14, weight: .bold))
                Text("+\(scoreDelta) points")
                    .font(.system(size: 18, weight: .bold, design: .rounded))
            } else {
                Image(systemName: "arrow.down")
                    .font(.system(size: 14, weight: .bold))
                Text("\(scoreDelta) points")
                    .font(.system(size: 18, weight: .bold, design: .rounded))
            }
        }
        .foregroundStyle(scoreDelta >= 0 ? AppColors.teal : AppColors.coral)
    }

    // MARK: - Details Section

    private var detailsSection: some View {
        HStack(spacing: 24) {
            // Brain Age
            VStack(spacing: 6) {
                Image(systemName: "brain.head.profile")
                    .font(.system(size: 20, weight: .semibold))
                    .foregroundStyle(AppColors.accent)

                Text("Brain Age")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(AppColors.textTertiary)

                HStack(spacing: 2) {
                    Text("\(newBrainAge)")
                        .font(.system(size: 22, weight: .bold, design: .rounded))
                        .foregroundStyle(AppColors.textPrimary)
                        .contentTransition(.numericText())

                    if ageDelta != 0 {
                        Text(ageDelta < 0 ? "\(ageDelta)" : "+\(ageDelta)")
                            .font(.system(size: 12, weight: .bold, design: .rounded))
                            .foregroundStyle(ageDelta < 0 ? AppColors.teal : AppColors.coral)
                    }
                }

                if userAge > 0 {
                    let diff = userAge - newBrainAge
                    if diff != 0 {
                        Text(diff > 0 ? "\(diff) yrs younger than you" : "\(abs(diff)) yrs older than you")
                            .font(.system(size: 10, weight: .bold, design: .rounded))
                            .foregroundStyle(diff > 0 ? AppColors.teal : AppColors.coral)
                    }
                }
            }

            // Divider
            Rectangle()
                .fill(AppColors.cardBorder)
                .frame(width: 1, height: 50)

            // Streak
            VStack(spacing: 6) {
                Image(systemName: "flame.fill")
                    .font(.system(size: 20, weight: .semibold))
                    .foregroundStyle(AppColors.coral)

                Text("Day Streak")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(AppColors.textTertiary)

                Text("\(streak)")
                    .font(.system(size: 22, weight: .bold, design: .rounded))
                    .foregroundStyle(AppColors.textPrimary)
            }
        }
        .padding(.vertical, 16)
        .padding(.horizontal, 32)
        .background(
            RoundedRectangle(cornerRadius: 14)
                .fill(AppColors.cardSurface)
                .shadow(color: .black.opacity(0.06), radius: 8, y: 2)
        )
    }

    // MARK: - Animation Sequence

    private func renderShareImage() {
        let card = WorkoutShareCard(
            brainScore: newBrainScore,
            scoreDelta: scoreDelta,
            brainAge: newBrainAge,
            streak: streak,
            userAge: userAge
        )
        let renderer = ImageRenderer(content: card)
        renderer.scale = 3
        shareImage = renderer.uiImage
    }

    private func startAnimationSequence() {
        displayedScore = oldBrainScore

        // Confetti fires at 0.8s
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.8) {
            withAnimation {
                showConfetti = true
            }
        }

        // Score ticker from old to new over 1.2s
        let totalDuration: Double = 1.2
        let steps = max(abs(newBrainScore - oldBrainScore), 1)
        let stepDuration = totalDuration / Double(steps)

        for i in 1...steps {
            DispatchQueue.main.asyncAfter(deadline: .now() + stepDuration * Double(i)) {
                let progress = Double(i) / Double(steps)
                let interpolated = Double(oldBrainScore) + progress * Double(newBrainScore - oldBrainScore)
                withAnimation(.linear(duration: stepDuration)) {
                    displayedScore = Int(interpolated)
                }
            }
        }

        // Delta pops in at 1.3s
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.3) {
            withAnimation(.spring(response: 0.4, dampingFraction: 0.6)) {
                showDelta = true
            }
        }

        // Details fade in at 1.6s
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.6) {
            withAnimation(.easeOut(duration: 0.4)) {
                showDetails = true
            }
        }
    }
}

#Preview {
    WorkoutCompleteView(
        oldBrainScore: 62,
        newBrainScore: 71,
        oldBrainAge: 28,
        newBrainAge: 26,
        streak: 5,
        userAge: 30,
        onDone: {}
    )
}
