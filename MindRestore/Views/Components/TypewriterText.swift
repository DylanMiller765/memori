import SwiftUI

struct TypewriterText: View {
    let fullText: String
    var speed: Double = 0.08 // seconds per character
    var hapticEnabled: Bool = true
    var onComplete: (() -> Void)? = nil

    @State private var displayedCount: Int = 0
    @State private var timer: Timer?

    var body: some View {
        Text(String(fullText.prefix(displayedCount)))
            .onAppear {
                startTyping()
            }
            .onDisappear {
                timer?.invalidate()
            }
    }

    private func startTyping() {
        displayedCount = 0
        timer?.invalidate()
        timer = Timer.scheduledTimer(withTimeInterval: speed, repeats: true) { t in
            if displayedCount < fullText.count {
                displayedCount += 1
                if hapticEnabled && displayedCount % 2 == 0 {
                    UIImpactFeedbackGenerator(style: .light).impactOccurred(intensity: 0.3)
                }
            } else {
                t.invalidate()
                onComplete?()
            }
        }
    }
}
