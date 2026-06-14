import SwiftUI

struct TypewriterText: View {
    let fullText: String
    var speed: Double = 0.08 // seconds per character
    var hapticEnabled: Bool = true
    /// Increment from the parent to finish the line instantly (tap-to-skip).
    var skipToken: Int = 0
    var onComplete: (() -> Void)? = nil

    @State private var displayedCount: Int = 0
    @State private var timer: Timer?

    var body: some View {
        Text(String(fullText.prefix(displayedCount)))
            .onAppear {
                startTyping()
            }
            .onChange(of: fullText) { _, _ in
                startTyping()
            }
            .onChange(of: skipToken) { _, _ in
                finishInstantly()
            }
            .onDisappear {
                timer?.invalidate()
            }
    }

    private func finishInstantly() {
        guard displayedCount < fullText.count else { return }
        timer?.invalidate()
        displayedCount = fullText.count
        if hapticEnabled {
            UIImpactFeedbackGenerator(style: .light).impactOccurred(intensity: 0.34)
        }
        onComplete?()
    }

    private func startTyping() {
        displayedCount = 0
        timer?.invalidate()
        timer = Timer.scheduledTimer(withTimeInterval: speed, repeats: true) { t in
            if displayedCount < fullText.count {
                displayedCount += 1
                if hapticEnabled, shouldTickHaptic(at: displayedCount) {
                    let character = character(at: displayedCount - 1)
                    let intensity: CGFloat = isPunctuation(character) ? 0.46 : 0.22
                    UIImpactFeedbackGenerator(style: .light).impactOccurred(intensity: intensity)
                }
            } else {
                t.invalidate()
                if hapticEnabled {
                    UIImpactFeedbackGenerator(style: .light).impactOccurred(intensity: 0.34)
                }
                onComplete?()
            }
        }
    }

    private func shouldTickHaptic(at count: Int) -> Bool {
        guard count > 0 else { return false }
        if let character = character(at: count - 1), isPunctuation(character) {
            return true
        }
        return count % 5 == 0
    }

    private func character(at index: Int) -> Character? {
        guard index >= 0, index < fullText.count else { return nil }
        return Array(fullText)[index]
    }

    private func isPunctuation(_ character: Character?) -> Bool {
        guard let character else { return false }
        return character == "." || character == "!" || character == "?" || character == "," || character == ":"
    }
}
