import SwiftUI

struct StreakCelebrationView: View {
    let streak: Int
    let onDismiss: () -> Void

    @State private var appeared = false
    @State private var showShare = false

    private var milestoneTitle: String {
        switch streak {
        case 7: return "One Week!"
        case 14: return "Two Weeks!"
        case 30: return "One Month!"
        case 60: return "Two Months!"
        case 100: return "100 Days!"
        default: return "\(streak) Days!"
        }
    }

    private var milestoneSubtitle: String {
        switch streak {
        case 7: return "You've outlasted 97% of starters. Most quit by day 3."
        case 14: return "Two weeks strong. Your brain is measurably sharper."
        case 30: return "A full month of training. You're in the top 5% of Memo players."
        case 60: return "60 days of dedication. Your neural pathways have literally rewired."
        case 100: return "Triple digits. You're one of the rarest players on Memo."
        default: return "Incredible consistency. Keep training!"
        }
    }

    private var milestoneColor: Color {
        switch streak {
        case 7: return AppColors.accent
        case 14: return AppColors.violet
        case 30: return AppColors.coral
        case 60: return AppColors.amber
        case 100: return Color(red: 1.0, green: 0.84, blue: 0.0)
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

                // Streak flame
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

                    Image("mascot-streak-fire")
                        .renderingMode(.original)
                        .resizable()
                        .scaledToFit()
                        .frame(height: 140)
                        .scaleEffect(appeared ? 1 : 0)
                        .animation(.spring(response: 0.5, dampingFraction: 0.5).delay(0.2), value: appeared)
                }

                Spacer().frame(height: 32)

                // Streak number
                Text("\(streak)")
                    .font(.system(size: 72, weight: .bold, design: .rounded))
                    .foregroundStyle(milestoneColor)
                    .opacity(appeared ? 1 : 0)
                    .offset(y: appeared ? 0 : 20)
                    .animation(.easeOut(duration: 0.5).delay(0.3), value: appeared)

                Text("DAY STREAK")
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
                    ShareLink(
                        item: "I just hit a \(streak)-day streak on Memo! My brain is getting sharper every day 🧠🔥",
                        preview: SharePreview("Memo Streak: \(streak) days")
                    ) {
                        HStack(spacing: 8) {
                            Image(systemName: "square.and.arrow.up")
                                .font(.subheadline.weight(.semibold))
                            Text("Share Achievement")
                                .font(.headline.weight(.bold))
                        }
                        .gradientButton()
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
        }
    }
}
