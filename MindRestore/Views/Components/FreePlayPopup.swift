import SwiftUI

struct FreePlayPopup: View {
    let onDismiss: () -> Void
    @State private var appeared = false

    var body: some View {
        VStack(spacing: 0) {
            Spacer()

            ZStack(alignment: .top) {
                // Card body
                VStack(spacing: 16) {
                    // Space for mascot overflow
                    Spacer().frame(height: 50)

                    Text("Every game is free\nto try!")
                        .font(.system(size: 22, weight: .bold, design: .rounded))
                        .multilineTextAlignment(.center)
                        .opacity(appeared ? 1 : 0)
                        .offset(y: appeared ? 0 : 10)

                    Text("Your first play of each game doesn't\ncount toward your daily limit.\nGo explore!")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                        .opacity(appeared ? 1 : 0)
                        .offset(y: appeared ? 0 : 10)

                    Button(action: onDismiss) {
                        Text("Let's go!")
                            .gradientButton()
                    }
                    .padding(.horizontal, 24)
                    .opacity(appeared ? 1 : 0)
                    .offset(y: appeared ? 0 : 20)
                }
                .padding(.horizontal, 24)
                .padding(.bottom, 28)
                .padding(.top, 8)
                .background(
                    RoundedRectangle(cornerRadius: 28)
                        .fill(.ultraThickMaterial)
                )

                // Mascot breaking out of the top
                Image("mascot-celebrate")
                    .renderingMode(.original)
                    .resizable()
                    .scaledToFit()
                    .frame(height: 110)
                    .offset(y: -55)
                    .scaleEffect(appeared ? 1 : 0.3)
                    .opacity(appeared ? 1 : 0)
            }
            .padding(.horizontal, 32)

            Spacer()
        }
        .onAppear {
            withAnimation(.spring(response: 0.5, dampingFraction: 0.7)) {
                appeared = true
            }
        }
    }
}
