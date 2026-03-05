import SwiftUI

struct StreakBadge: View {
    let count: Int
    @State private var isAnimating = false

    var body: some View {
        HStack(spacing: 6) {
            Image(systemName: "flame.fill")
                .foregroundStyle(count > 0 ? AppColors.accent : .secondary)
                .scaleEffect(isAnimating ? 1.2 : 1.0)

            Text("\(count)")
                .font(.headline.weight(.bold))
                .foregroundStyle(count > 0 ? .primary : .secondary)
        }
        .onAppear {
            if [7, 30, 100].contains(count) {
                withAnimation(.spring(response: 0.5, dampingFraction: 0.3)) {
                    isAnimating = true
                }
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.5)) {
                        isAnimating = false
                    }
                }
            }
        }
    }
}
