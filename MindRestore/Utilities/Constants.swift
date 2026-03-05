import Foundation

enum Constants {
    enum ProductIDs {
        static let monthly = "com.mindrestore.pro.monthly"
        static let annual = "com.mindrestore.pro.annual"
        static let lifetime = "com.mindrestore.pro.lifetime"
    }

    enum Defaults {
        static let dailyGoal = 3
        static let reminderHour = 9
        static let reminderMinute = 0
        static let trialDays = 7
    }

    enum Exercise {
        static let spacedRepetitionSessionSize = 15
        static let dualNBackTrialInterval: TimeInterval = 2.5
        static let activeRecallDisplayDuration: TimeInterval = 30
    }
}
