import SwiftUI

struct ScoreRevealView: View {
    let viewModel: BrainAssessmentViewModel
    let onDone: () -> Void

    @State private var displayedScore: Int = 0
    @State private var shareImage: UIImage?
    @State private var showScore = false
    @State private var showAge = false
    @State private var showType = false
    @State private var showConfetti = false
    @State private var showPercentile = false
    @State private var showActions = false
    @State private var showBreakdown = false
    @State private var scoreTimer: Timer?

    var body: some View {
        ZStack {
            Color(UIColor.systemBackground).ignoresSafeArea()

            ScrollView {
                VStack(spacing: 28) {
                    Spacer(minLength: 40)

                    // Brain Score
                    if showScore {
                        VStack(spacing: 8) {
                            Text("\(displayedScore)")
                                .font(.system(size: 80, weight: .black, design: .rounded))
                                .foregroundStyle(AppColors.accent)
                                .contentTransition(.numericText(value: Double(displayedScore)))

                            Text("Brain Score")
                                .font(.title3.weight(.medium))
                                .foregroundStyle(.secondary)
                        }
                        .transition(.scale.combined(with: .opacity))
                    }

                    // Brain Age
                    if showAge {
                        HStack(spacing: 8) {
                            Image(systemName: "person.fill")
                                .foregroundStyle(.secondary)
                            Text("Brain Age:")
                                .foregroundStyle(.secondary)
                            Text("\(viewModel.brainAge)")
                                .font(.title2.weight(.bold))
                                .foregroundStyle(viewModel.brainAge <= 25 ? AppColors.accent : .orange)
                        }
                        .font(.title3)
                        .transition(.move(edge: .bottom).combined(with: .opacity))
                    }

                    // Brain Type
                    if showType {
                        VStack(spacing: 8) {
                            HStack(spacing: 10) {
                                Image(systemName: viewModel.brainType.icon)
                                    .font(.title2)
                                Text(viewModel.brainType.displayName)
                                    .font(.title2.weight(.bold))
                            }
                            .foregroundStyle(brainTypeColor)

                            Text(viewModel.brainType.description)
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                                .multilineTextAlignment(.center)
                                .padding(.horizontal, 32)
                        }
                        .transition(.scale(scale: 0.8).combined(with: .opacity))
                    }

                    // Percentile
                    if showPercentile {
                        Text("Better than \(viewModel.percentile)% of players")
                            .font(.headline)
                            .foregroundStyle(AppColors.accent)
                            .padding(.horizontal, 20)
                            .padding(.vertical, 10)
                            .background(AppColors.accent.opacity(0.1), in: Capsule())
                            .transition(.opacity)
                    }

                    // Breakdown
                    if showBreakdown {
                        VStack(spacing: 12) {
                            Text("Performance Breakdown")
                                .font(.subheadline.weight(.semibold))
                                .frame(maxWidth: .infinity, alignment: .leading)

                            breakdownRow(
                                icon: "number.circle.fill",
                                label: "Digit Span",
                                value: "\(viewModel.digitMaxCorrect) digits",
                                score: viewModel.digitScore,
                                color: .blue
                            )
                            breakdownRow(
                                icon: "bolt.fill",
                                label: "Reaction Time",
                                value: "\(viewModel.avgReactionMs)ms",
                                score: viewModel.reactionScore,
                                color: .yellow
                            )
                            breakdownRow(
                                icon: "square.grid.3x3.fill",
                                label: "Visual Memory",
                                value: "Level \(viewModel.visualMaxCorrect)",
                                score: viewModel.visualScore,
                                color: .purple
                            )
                        }
                        .appCard()
                        .padding(.horizontal, 20)
                        .transition(.move(edge: .bottom).combined(with: .opacity))
                    }

                    // Actions
                    if showActions {
                        VStack(spacing: 12) {
                            if let shareImage {
                                ShareLink(
                                    item: Image(uiImage: shareImage),
                                    preview: SharePreview("Brain Score: \(viewModel.brainScore)", image: Image(uiImage: shareImage))
                                ) {
                                    HStack {
                                        Image(systemName: "square.and.arrow.up")
                                        Text("Share Your Score")
                                    }
                                    .accentButton()
                                }
                            } else {
                                ShareLink(item: shareText) {
                                    HStack {
                                        Image(systemName: "square.and.arrow.up")
                                        Text("Share Your Score")
                                    }
                                    .accentButton()
                                }
                            }

                            Button(action: onDone) {
                                Text("Done")
                                    .font(.headline)
                                    .foregroundStyle(.secondary)
                            }
                        }
                        .padding(.horizontal, 32)
                        .transition(.opacity)
                    }

                    Spacer(minLength: 32)
                }
            }

            if showConfetti {
                ConfettiView()
            }
        }
        .onAppear { startRevealSequence() }
    }

    private var shareText: String {
        "My Brain Score is \(viewModel.brainScore)/1000 (Brain Age: \(viewModel.brainAge)) 🧠\n\nI'm a \(viewModel.brainType.displayName) — better than \(viewModel.percentile)% of players!\n\nTest yours with MindRestore"
    }

    private var brainTypeColor: Color {
        switch viewModel.brainType {
        case .lightningReflex: return .yellow
        case .numberCruncher: return .blue
        case .patternMaster: return .purple
        case .balancedBrain: return AppColors.accent
        }
    }

    private func breakdownRow(icon: String, label: String, value: String, score: Double, color: Color) -> some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.body)
                .foregroundStyle(color)
                .frame(width: 24)

            VStack(alignment: .leading, spacing: 2) {
                Text(label)
                    .font(.subheadline.weight(.medium))
                Text(value)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            // Score bar
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 4)
                        .fill(color.opacity(0.15))
                    RoundedRectangle(cornerRadius: 4)
                        .fill(color)
                        .frame(width: geo.size.width * score / 100)
                }
            }
            .frame(width: 80, height: 8)

            Text("\(Int(score))")
                .font(.subheadline.weight(.bold).monospacedDigit())
                .frame(width: 30, alignment: .trailing)
        }
    }

    // MARK: - Reveal Sequence

    private func startRevealSequence() {
        withAnimation(.spring(response: 0.5)) { showScore = true }
        startScoreCounter()

        DispatchQueue.main.asyncAfter(deadline: .now() + 2.2) {
            withAnimation(.spring(response: 0.4, dampingFraction: 0.7)) { showAge = true }
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.8) {
            withAnimation(.spring(response: 0.4, dampingFraction: 0.7)) { showType = true }
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 3.2) {
            showConfetti = true
            UINotificationFeedbackGenerator().notificationOccurred(.success)
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 3.8) {
            withAnimation(.easeIn(duration: 0.3)) { showPercentile = true }
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 4.3) {
            withAnimation(.easeIn(duration: 0.4)) { showBreakdown = true }
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 4.5) {
            let card = ShareCardView(
                brainScore: viewModel.brainScore,
                brainAge: viewModel.brainAge,
                brainType: viewModel.brainType,
                percentile: viewModel.percentile,
                digitScore: viewModel.digitScore,
                reactionScore: viewModel.reactionScore,
                visualScore: viewModel.visualScore
            )
            shareImage = card.renderImage()
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 4.8) {
            withAnimation(.easeIn(duration: 0.3)) { showActions = true }
        }
    }

    private func startScoreCounter() {
        let target = viewModel.brainScore
        let duration: Double = 2.0
        let steps = 60
        let stepDuration = duration / Double(steps)
        var currentStep = 0

        scoreTimer = Timer.scheduledTimer(withTimeInterval: stepDuration, repeats: true) { timer in
            currentStep += 1
            let progress = Double(currentStep) / Double(steps)
            let eased = 1.0 - pow(1.0 - progress, 3) // ease-out cubic
            let value = Int(Double(target) * eased)

            Task { @MainActor in
                displayedScore = min(value, target)
                if currentStep >= steps {
                    timer.invalidate()
                    displayedScore = target
                    UIImpactFeedbackGenerator(style: .heavy).impactOccurred()
                }
            }
        }
    }
}
