import Foundation

enum Constants {
    enum ProductIDs {
        static let weekly = "com.memori.ultra.weekly"
        static let annual = "com.memori.ultra.annual"
    }

    enum Defaults {
        static let dailyGoal = 3
        static let reminderHour = 9
        static let reminderMinute = 0
    }

    enum Exercise {
        static let spacedRepetitionSessionSize = 15
        static let dualNBackTrialInterval: TimeInterval = 2.5
        static let activeRecallDisplayDuration: TimeInterval = 30
    }
}
