import SwiftUI

extension Date {
    var startOfDay: Date {
        Calendar.current.startOfDay(for: self)
    }

    var isToday: Bool {
        Calendar.current.isDateInToday(self)
    }

    var isYesterday: Bool {
        Calendar.current.isDateInYesterday(self)
    }

    func daysAgo(_ days: Int) -> Date {
        Calendar.current.date(byAdding: .day, value: -days, to: self) ?? self
    }
}

extension Double {
    var percentString: String {
        "\(Int(self * 100))%"
    }
}

extension Int {
    var durationString: String {
        if self >= 60 {
            let m = self / 60
            let s = self % 60
            return s > 0 ? "\(m)m \(s)s" : "\(m)m"
        }
        return "\(self)s"
    }
}
