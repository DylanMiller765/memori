import SwiftUI

struct BrainScoreMilestoneView: View {
    let milestone: Int
    let onDismiss: () -> Void

    @State private var appeared = false
    @State private var shareImage: UIImage?

    private var milestoneTitle: String {
        switch milestone {
        case 500: return "Breaking Through!"
        case 600: return "Rising Star!"
        case 700: return "Elite Territory!"
        case 800: return "Genius Level!"
        case 900: return "Legendary!"
        case 1000: return "PERFECT SCORE!"
        default: return "Milestone!"
        }
    }

    private var milestoneSubtitle: String {
        switch milestone {
        case 500: return "Top 50%. Your brain is officially warming up."
        case 600: return "Above average. Your training is paying off."
        case 700: return "Top 20%. Most brains never make it here."
        case 800: return "Top 5%. You're operating at peak performance."
        case 900: return "Top 1%. You have an exceptional mind."
        case 1000: return "The summit. Absolute legend."
        default: return "Keep training!"
        }
    }

    private var milestoneColor: Color {
        switch milestone {
        case 500: return AppColors.accent
        case 600: return AppColors.teal
        case 700: return AppColors.violet
        case 800: return AppColors.coral
        case 900: return AppColors.amber
        case 1000: return Color(red: 1.0, green: 0.84, blue: 0.0) // gold
        default: return AppColors.accent
        }
    }

    var body: some View {
        ZStack {
            // Background
            Color.black.opacity(0.85)
                .ignoresSafeArea()

            VStack(spacing: 0) {
                Spacer()

                // Concentric circles + brain icon
                ZStack {
                    ForEach(0..<3, id: \.self) { i in
                        Circle()
                            .fill(milestoneColor.opacity(0.08 - Double(i) * 0.02))
                            .frame(
                                width: CGFloat(120 + i * 50),
                                height: CGFloat(120 + i * 50)
                            )
                            .scaleEffect(appeared ? 1 : 0.3)
                            .animation(
                                .spring(response: 0.6, dampingFraction: 0.6)
                                    .delay(Double(i) * 0.1),
                                value: appeared
                            )
                    }

                    Image(systemName: "brain.fill")
                        .font(.system(size: 64, weight: .bold))
                        .foregroundStyle(milestoneColor)
                        .scaleEffect(appeared ? 1 : 0)
                        .animation(.spring(response: 0.5, dampingFraction: 0.5).delay(0.2), value: appeared)
                }

                Spacer().frame(height: 32)

                // Big milestone number
                Text("\(milestone)")
                    .font(.system(size: 72, weight: .bold, design: .rounded))
                    .foregroundStyle(milestoneColor)
                    .opacity(appeared ? 1 : 0)
                    .offset(y: appeared ? 0 : 20)
                    .animation(.easeOut(duration: 0.5).delay(0.3), value: appeared)

                Text("BRAIN SCORE")
                    .font(.system(size: 14, weight: .heavy))
                    .tracking(4)
                    .foregroundStyle(.white.opacity(0.5))
                    .opacity(appeared ? 1 : 0)
                    .animation(.easeOut(duration: 0.5).delay(0.4), value: appeared)

                Spacer().frame(height: 24)

                // Title & subtitle
                Text(milestoneTitle)
                    .font(.title.weight(.bold))
                    .foregroundStyle(.white)
                    .opacity(appeared ? 1 : 0)
                    .animation(.easeOut(duration: 0.5).delay(0.5), value: appeared)

                Spacer().frame(height: 8)

                Text(milestoneSubtitle)
                    .font(.subheadline)
                    .foregroundStyle(.white.opacity(0.6))
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 40)
                    .opacity(appeared ? 1 : 0)
                    .animation(.easeOut(duration: 0.5).delay(0.6), value: appeared)

                Spacer()

                // Buttons
                VStack(spacing: 12) {
                    if let shareImage {
                        ShareLink(
                            item: Image(uiImage: shareImage),
                            preview: SharePreview("Brain Score Milestone: \(milestone)", image: Image(uiImage: shareImage))
                        ) {
                            HStack(spacing: 8) {
                                Image(systemName: "square.and.arrow.up")
                                    .font(.subheadline.weight(.semibold))
                                Text("Share Achievement")
                                    .font(.headline.weight(.bold))
                            }
                            .gradientButton()
                        }
                    } else {
                        ShareLink(
                            item: "I just hit a Brain Score of \(milestone) on Memori! \(milestoneTitle) \u{1F9E0}\u{1F525}",
                            preview: SharePreview("Brain Score: \(milestone)")
                        ) {
                            HStack(spacing: 8) {
                                Image(systemName: "square.and.arrow.up")
                                    .font(.subheadline.weight(.semibold))
                                Text("Share Achievement")
                                    .font(.headline.weight(.bold))
                            }
                            .gradientButton()
                        }
                    }

                    Button(action: onDismiss) {
                        Text("Keep Training")
                            .font(.subheadline.weight(.medium))
                            .foregroundStyle(.white.opacity(0.6))
                    }
                }
                .padding(.horizontal, 24)
                .padding(.bottom, 48)
                .opacity(appeared ? 1 : 0)
                .offset(y: appeared ? 0 : 30)
                .animation(.easeOut(duration: 0.5).delay(0.7), value: appeared)
            }
        }
        .onAppear {
            appeared = true
            HapticService.streak()
            SoundService.shared.playComplete()
            renderShareCard()
        }
    }

    private func renderShareCard() {
        let card = BSM_ShareCard(milestone: milestone, title: milestoneTitle, color: milestoneColor)
        shareImage = card.renderAsImage(size: CGSize(width: 360, height: 640), scale: 3)
    }
}

// MARK: - Share Card (Cream Style)

private struct BSM_CardBackground: View {
    var body: some View {
        LinearGradient(
            colors: [
                Color(red: 0.969, green: 0.961, blue: 0.941), // #F7F5F0
                Color(red: 0.955, green: 0.945, blue: 0.925),
                Color(red: 0.969, green: 0.961, blue: 0.941)
            ],
            startPoint: .top,
            endPoint: .bottom
        )
    }
}

private struct BSM_BrandingHeader: View {
    var body: some View {
        HStack(spacing: 6) {
            Image(systemName: "brain.fill")
                .font(.system(size: 12, weight: .bold))
                .foregroundStyle(AppColors.accent)
            Text("MEMORI")
                .font(.system(size: 12, weight: .heavy))
                .tracking(3)
                .foregroundStyle(Color(red: 0.45, green: 0.43, blue: 0.40))
        }
    }
}

private struct BSM_BrandingFooter: View {
    var body: some View {
        Text("Train your brain free \u{2014} Memori")
            .font(.system(size: 11, weight: .semibold))
            .foregroundStyle(Color(red: 0.62, green: 0.60, blue: 0.58))
    }
}

private struct BSM_ShareCardSurface<Content: View>: View {
    @ViewBuilder var content: () -> Content

    var body: some View {
        content()
            .padding(20)
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(.white)
                    .shadow(color: .black.opacity(0.06), radius: 12, y: 4)
            )
    }
}

private struct BSM_ShareCard: View {
    let milestone: Int
    let title: String
    let color: Color

    var body: some View {
        ZStack {
            BSM_CardBackground()

            VStack(spacing: 0) {
                Spacer().frame(height: 32)
                BSM_BrandingHeader()
                Spacer().frame(height: 28)

                BSM_ShareCardSurface {
                    VStack(spacing: 16) {
                        // Label
                        HStack(spacing: 8) {
                            Image(systemName: "brain.fill")
                                .font(.system(size: 16, weight: .bold))
                            Text("BRAIN SCORE MILESTONE")
                                .font(.system(size: 13, weight: .heavy))
                                .tracking(3)
                        }
                        .foregroundStyle(color)

                        // Big number
                        Text("\(milestone)")
                            .font(.system(size: 72, weight: .bold, design: .rounded))
                            .foregroundStyle(color)

                        Text("BRAIN SCORE")
                            .font(.system(size: 13, weight: .heavy))
                            .tracking(4)
                            .foregroundStyle(Color(red: 0.62, green: 0.60, blue: 0.58))

                        // Title badge
                        Text(title)
                            .font(.system(size: 20, weight: .bold))
                            .foregroundStyle(color)
                            .padding(.horizontal, 20)
                            .padding(.vertical, 10)
                            .background(
                                Capsule().fill(color.opacity(0.12))
                            )

                        // Decorative divider
                        Divider()

                        // Motivational text
                        Text(milestoneShareText)
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundStyle(.secondary)
                            .multilineTextAlignment(.center)
                    }
                }
                .padding(.horizontal, 24)

                Spacer()

                Text("Can you beat my score?")
                    .font(.system(size: 22, weight: .bold))
                    .foregroundStyle(.primary)

                Spacer().frame(height: 10)
                BSM_BrandingFooter()
                Spacer().frame(height: 28)
            }
        }
        .frame(width: 360, height: 640)
    }

    private var milestoneShareText: String {
        switch milestone {
        case 500: return "Top half of all players"
        case 600: return "Above average cognitive score"
        case 700: return "Top 20% of all players"
        case 800: return "Top 5% — genius level"
        case 900: return "Top 1% — legendary status"
        case 1000: return "Perfect score achieved"
        default: return "Milestone reached"
        }
    }
}

#Preview {
    BrainScoreMilestoneView(milestone: 700) {}
}
