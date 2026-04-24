import ManagedSettings
import ManagedSettingsUI
import UIKit

class ShieldConfigurationExtension: ShieldConfigurationDataSource {
    private let sharedDefaults = UserDefaults(suiteName: "group.com.memori.shared")!

    override func configuration(shielding application: Application) -> ShieldConfiguration {
        buildShieldConfig(appName: application.localizedDisplayName)
    }

    override func configuration(shielding application: Application, in category: ActivityCategory) -> ShieldConfiguration {
        buildShieldConfig(appName: application.localizedDisplayName ?? category.localizedDisplayName)
    }

    override func configuration(shielding webDomain: WebDomain) -> ShieldConfiguration {
        buildShieldConfig(appName: webDomain.domain)
    }

    override func configuration(shielding webDomain: WebDomain, in category: ActivityCategory) -> ShieldConfiguration {
        buildShieldConfig(appName: webDomain.domain ?? category.localizedDisplayName)
    }

    private func buildShieldConfig(appName: String? = nil) -> ShieldConfiguration {
        let attemptCount = dailyAttemptCount
        let name = appName ?? "this app"

        let title: String
        let subtitle: String

        if attemptCount <= 2 {
            title = "Train your brain first!"
            subtitle = "Play a quick game to unlock \(name)"
        } else if attemptCount <= 4 {
            title = "Again? That's \(attemptCount) times today"
            subtitle = "Play a brain game to unlock \(name)"
        } else {
            title = "You've tried \(attemptCount) times today"
            subtitle = "Maybe it's time to put the phone down?"
        }

        // Load mascot and scale it up for a larger display
        let mascotIcon: UIImage? = {
            guard let original = UIImage(named: "shield-mascot") else { return nil }
            let targetSize = CGSize(width: 120, height: 120)
            let renderer = UIGraphicsImageRenderer(size: targetSize)
            return renderer.image { _ in
                original.draw(in: CGRect(origin: .zero, size: targetSize))
            }
        }()

        return ShieldConfiguration(
            backgroundBlurStyle: .dark,
            backgroundColor: UIColor(red: 0.039, green: 0.039, blue: 0.059, alpha: 1.0),
            icon: mascotIcon,
            title: ShieldConfiguration.Label(text: title, color: .white),
            subtitle: ShieldConfiguration.Label(text: subtitle, color: UIColor(white: 0.6, alpha: 1.0)),
            primaryButtonLabel: ShieldConfiguration.Label(text: "Play a game", color: .white),
            primaryButtonBackgroundColor: UIColor(red: 0.29, green: 0.50, blue: 0.90, alpha: 1.0),
            secondaryButtonLabel: ShieldConfiguration.Label(text: "Stay focused", color: UIColor(white: 0.5, alpha: 1.0))
        )
    }

    private var dailyAttemptCount: Int {
        let savedDate = sharedDefaults.object(forKey: "focus_daily_attempt_date") as? Date
        if let savedDate, Calendar.current.isDateInToday(savedDate) {
            return sharedDefaults.integer(forKey: "focus_daily_attempt_count")
        }
        return 0
    }
}
