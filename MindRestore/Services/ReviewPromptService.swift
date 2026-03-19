import StoreKit
import UIKit

enum ReviewPromptService {
    @MainActor
    static func requestIfAppropriate(totalExercises: Int, streak: Int) {
        let defaults = UserDefaults.standard
        let lastPrompt = defaults.double(forKey: "lastReviewPromptDate")
        let daysSincePrompt = (Date.now.timeIntervalSince1970 - lastPrompt) / 86400

        guard totalExercises >= 10, streak >= 3, daysSincePrompt > 30 else { return }

        defaults.set(Date.now.timeIntervalSince1970, forKey: "lastReviewPromptDate")

        if let scene = UIApplication.shared.connectedScenes
            .first(where: { $0.activationState == .foregroundActive }) as? UIWindowScene {
            AppStore.requestReview(in: scene)
        }
    }
}
