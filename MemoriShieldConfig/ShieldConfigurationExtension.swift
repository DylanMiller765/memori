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

        let (title, subtitle) = pickMessage(attemptCount: attemptCount, appName: name)

        // ShieldConfiguration caps layout, so render the mascot larger before passing it in.
        let mascotIcon: UIImage? = {
            guard let original = UIImage(named: "shield-mascot") else { return nil }
            let targetSize = CGSize(width: 168, height: 168)
            let renderer = UIGraphicsImageRenderer(size: targetSize)
            return renderer.image { _ in
                original.draw(in: CGRect(origin: .zero, size: targetSize))
            }
        }()

        return ShieldConfiguration(
            backgroundBlurStyle: .light,
            backgroundColor: UIColor(red: 0.94, green: 0.91, blue: 0.82, alpha: 1.0),
            icon: mascotIcon,
            title: ShieldConfiguration.Label(text: title, color: UIColor(red: 0.04, green: 0.04, blue: 0.05, alpha: 1.0)),
            subtitle: ShieldConfiguration.Label(text: subtitle, color: UIColor(white: 0.28, alpha: 1.0)),
            primaryButtonLabel: ShieldConfiguration.Label(text: "Train to unlock", color: .white),
            primaryButtonBackgroundColor: UIColor(red: 0.29, green: 0.50, blue: 0.90, alpha: 1.0),
            secondaryButtonLabel: ShieldConfiguration.Label(text: "Stay focused", color: UIColor(white: 0.36, alpha: 1.0))
        )
    }

    /// Rotating Gen Z shield messages that escalate with attempt count.
    /// Designed to be screenshot-worthy and shareable.
    private func pickMessage(attemptCount: Int, appName: String) -> (String, String) {
        // Tier 1 (0-2 attempts) — friendly callout
        let tier1: [(String, String)] = [
            ("bruh enough \(appName)", "train to unlock?"),
            ("\(appName)? not yet", "one game first."),
            ("nice try", "train to unlock \(appName)."),
            ("Memo says no", "earn it with a brain game."),
        ]

        // Tier 2 (3-5 attempts) — pointed callout
        let tier2: [(String, String)] = [
            ("again with \(appName)?", "\(attemptCount) tries today."),
            ("be so for real", "one game and you're back in."),
            ("Memo is watching", "\(attemptCount) attempts and counting."),
        ]

        // Tier 3 (6+ attempts) — intervention mode
        let tier3: [(String, String)] = [
            ("\(attemptCount) tries. cooked.", "train or stay out."),
            ("put the phone down", "or earn \(appName) back."),
            ("we need to talk", "\(attemptCount) attempts today."),
        ]

        let pool: [(String, String)]
        switch attemptCount {
        case 0...2: pool = tier1
        case 3...5: pool = tier2
        default:    pool = tier3
        }

        return pool.randomElement() ?? pool[0]
    }

    private var dailyAttemptCount: Int {
        let savedDate = sharedDefaults.object(forKey: "focus_daily_attempt_date") as? Date
        if let savedDate, Calendar.current.isDateInToday(savedDate) {
            return sharedDefaults.integer(forKey: "focus_daily_attempt_count")
        }
        return 0
    }
}
