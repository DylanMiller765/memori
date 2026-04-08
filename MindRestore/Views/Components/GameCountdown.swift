import SwiftUI

struct GameCountdown: View {
    let onComplete: () -> Void
    @State private var count = 3
    @State private var scale: CGFloat = 2.0
    @State private var opacity: Double = 0

    var body: some View {
        ZStack {
            Color.black.opacity(0.3).ignoresSafeArea()

            if count > 0 {
                Text("\(count)")
                    .font(.system(size: 80, weight: .heavy, design: .rounded))
                    .foregroundStyle(.white)
                    .scaleEffect(scale)
                    .opacity(opacity)
                    .id(count) // Force view recreation for animation
            } else {
                Text("GO!")
                    .font(.system(size: 60, weight: .heavy, design: .rounded))
                    .foregroundStyle(AppColors.accent)
                    .scaleEffect(scale)
                    .opacity(opacity)
                    .id("go")
            }
        }
        .onAppear { startCountdown() }
    }

    private func startCountdown() {
        animateNumber()

        for i in 1...3 {
            DispatchQueue.main.asyncAfter(deadline: .now() + Double(i)) {
                if i < 3 {
                    count = 3 - i
                    animateNumber()
                } else {
                    count = 0
                    animateNumber()
                    // Finish after "GO!" shows
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                        onComplete()
                    }
                }
            }
        }
    }

    private func animateNumber() {
        scale = 2.0
        opacity = 0
        UIImpactFeedbackGenerator(style: count > 0 ? .medium : .heavy).impactOccurred()
        withAnimation(.spring(response: 0.35, dampingFraction: 0.6)) {
            scale = 1.0
            opacity = 1.0
        }
        // Fade out before next number
        withAnimation(.easeOut(duration: 0.3).delay(0.5)) {
            opacity = 0
        }
    }
}
