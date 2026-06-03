import ManagedSettings
import ManagedSettingsUI
import UIKit
import Foundation

class ShieldConfigurationExtension: ShieldConfigurationDataSource {
    private let sharedDefaults = UserDefaults(suiteName: "group.com.memori.shared")!

    override func configuration(shielding application: Application) -> ShieldConfiguration {
        buildShieldConfig()
    }

    override func configuration(shielding application: Application, in category: ActivityCategory) -> ShieldConfiguration {
        buildShieldConfig()
    }

    override func configuration(shielding webDomain: WebDomain) -> ShieldConfiguration {
        buildShieldConfig()
    }

    override func configuration(shielding webDomain: WebDomain, in category: ActivityCategory) -> ShieldConfiguration {
        buildShieldConfig()
    }

    private func buildShieldConfig() -> ShieldConfiguration {
        // Read attempt count to rotate messages
        let attemptCount = dailyAttemptCount

        let title: String
        let subtitle: String

        if attemptCount <= 2 {
            title = "Train to unlock first!"
            subtitle = "Complete a quick game to unlock this app"
        } else if attemptCount <= 4 {
            title = "Again? That's \(attemptCount) times today"
            subtitle = "Play a brain game or stay focused"
        } else {
            title = "You've tried \(attemptCount) times today"
            subtitle = "Maybe it's time to put the phone down?"
        }

        return ShieldConfiguration(
            backgroundBlurStyle: .systemThickMaterialDark,
            backgroundColor: UIColor(red: 0.04, green: 0.04, blue: 0.06, alpha: 1.0),
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
