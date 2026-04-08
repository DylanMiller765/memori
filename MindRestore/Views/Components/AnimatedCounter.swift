import SwiftUI

struct AnimatedCounter: View {
    let value: Int
    var duration: Double = 1.0
    var font: Font = .title.bold()
    var color: Color = .primary

    @State private var displayValue: Int = 0
    @State private var hasAppeared = false

    var body: some View {
        Text("\(displayValue)")
            .font(font)
            .foregroundStyle(color)
            .contentTransition(.numericText())
            .onAppear {
                guard !hasAppeared else { return }
                hasAppeared = true
                animateCount()
            }
    }

    private func animateCount() {
        let steps = min(value, 60) // Max 60 animation steps
        let stepDuration = duration / Double(steps)

        for i in 1...steps {
            DispatchQueue.main.asyncAfter(deadline: .now() + stepDuration * Double(i)) {
                withAnimation(.easeOut(duration: 0.05)) {
                    displayValue = Int(Double(value) * Double(i) / Double(steps))
                }
            }
        }
        // Ensure final value is exact
        DispatchQueue.main.asyncAfter(deadline: .now() + duration + 0.05) {
            withAnimation { displayValue = value }
        }
    }
}
