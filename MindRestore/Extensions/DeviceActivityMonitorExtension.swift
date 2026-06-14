import DeviceActivity
import FamilyControls
import ManagedSettings
import Foundation

class DeviceActivityMonitorExtension: DeviceActivityMonitor {
    private static let focusActivity = DeviceActivityName("com.memori.focus")
    private static let relockActivity = DeviceActivityName("com.memori.focus.relock")

    private let sharedDefaults = UserDefaults(suiteName: "group.com.memori.shared")!
    private let store = ManagedSettingsStore()

    override func intervalDidStart(for activity: DeviceActivityName) {
        if activity == Self.relockActivity {
            handleRelockInterval()
            return
        }

        guard activity == Self.focusActivity else { return }

        // Schedule started — apply shields, but ONLY if today is in the user's chosen days.
        // DeviceActivitySchedule is interval-based and has no native day-of-week filter, so
        // we enforce it here in the extension callback (which fires whether or not the host
        // app is running).
        guard sharedDefaults.bool(forKey: "focus_mode_enabled") else { return }
        guard isTodayScheduledDay() else {
            // Wrong day — ensure shields are down in case a previous run left them up.
            removeShields()
            return
        }

        applyPersistedShields()
    }

    override func intervalDidEnd(for activity: DeviceActivityName) {
        guard activity == Self.focusActivity else { return }
        // Schedule ended — remove shields
        removeShields()
    }

    private func handleRelockInterval() {
        guard sharedDefaults.bool(forKey: "focus_mode_enabled") else {
            removeShields()
            return
        }

        if let unlockUntil = sharedDefaults.object(forKey: "focus_unlock_until") as? Date,
           unlockUntil > Date() {
            removeShields()
            return
        }

        sharedDefaults.removeObject(forKey: "focus_unlock_until")
        if shouldApplyShieldsNow() {
            applyPersistedShields()
        } else {
            removeShields()
        }
    }

    private func applyPersistedShields() {
        guard let data = sharedDefaults.data(forKey: "focus_activity_selection"),
              let selection = try? JSONDecoder().decode(FamilyActivitySelection.self, from: data) else {
            removeShields()
            return
        }

        store.shield.applications = selection.applicationTokens.isEmpty ? nil : selection.applicationTokens
        let categories = selection.categoryTokens
        store.shield.applicationCategories = categories.isEmpty ? nil : .specific(categories)
        store.shield.webDomains = selection.webDomainTokens.isEmpty ? nil : selection.webDomainTokens
        beginBlockedMinutesIfNeeded()
    }

    private func removeShields() {
        store.shield.applications = nil
        store.shield.applicationCategories = nil
        store.shield.webDomains = nil
        flushBlockedMinutes()
    }

    private func beginBlockedMinutesIfNeeded(at date: Date = Date()) {
        rolloverFocusCountersIfNeeded(at: date)
        if let existing = sharedDefaults.object(forKey: "focus_last_block_start") as? Date,
           existing <= date {
            return
        }
        sharedDefaults.set(date, forKey: "focus_last_block_start")
    }

    private func flushBlockedMinutes(at date: Date = Date()) {
        guard let start = sharedDefaults.object(forKey: "focus_last_block_start") as? Date else { return }
        let minutes = Int(date.timeIntervalSince(start) / 60)
        sharedDefaults.removeObject(forKey: "focus_last_block_start")
        guard minutes > 0 else { return }

        rolloverFocusCountersIfNeeded(at: date)
        sharedDefaults.set(
            sharedDefaults.integer(forKey: "focus_daily_minutes") + minutes,
            forKey: "focus_daily_minutes"
        )
        sharedDefaults.set(
            sharedDefaults.integer(forKey: "focus_weekly_minutes") + minutes,
            forKey: "focus_weekly_minutes"
        )
        sharedDefaults.set(
            sharedDefaults.integer(forKey: "focus_monthly_minutes") + minutes,
            forKey: "focus_monthly_minutes"
        )
    }

    private func rolloverFocusCountersIfNeeded(at date: Date = Date()) {
        let calendar = Calendar.current
        let dayStart = calendar.startOfDay(for: date)
        if let saved = sharedDefaults.object(forKey: "focus_day_start") as? Date,
           !calendar.isDate(saved, inSameDayAs: dayStart) {
            sharedDefaults.set(0, forKey: "focus_daily_minutes")
        }
        if sharedDefaults.object(forKey: "focus_day_start") == nil ||
            !(calendar.isDate(sharedDefaults.object(forKey: "focus_day_start") as? Date ?? .distantPast, inSameDayAs: dayStart)) {
            sharedDefaults.set(dayStart, forKey: "focus_day_start")
        }

        if let weekStart = calendar.dateInterval(of: .weekOfYear, for: date)?.start {
            if let saved = sharedDefaults.object(forKey: "focus_week_start") as? Date,
               !calendar.isDate(saved, equalTo: weekStart, toGranularity: .weekOfYear) {
                sharedDefaults.set(0, forKey: "focus_weekly_minutes")
            }
            if sharedDefaults.object(forKey: "focus_week_start") == nil ||
                !(calendar.isDate(sharedDefaults.object(forKey: "focus_week_start") as? Date ?? .distantPast, equalTo: weekStart, toGranularity: .weekOfYear)) {
                sharedDefaults.set(weekStart, forKey: "focus_week_start")
            }
        }

        if let monthStart = calendar.dateInterval(of: .month, for: date)?.start {
            if let saved = sharedDefaults.object(forKey: "focus_month_start") as? Date,
               !calendar.isDate(saved, equalTo: monthStart, toGranularity: .month) {
                sharedDefaults.set(0, forKey: "focus_monthly_minutes")
            }
            if sharedDefaults.object(forKey: "focus_month_start") == nil ||
                !(calendar.isDate(sharedDefaults.object(forKey: "focus_month_start") as? Date ?? .distantPast, equalTo: monthStart, toGranularity: .month)) {
                sharedDefaults.set(monthStart, forKey: "focus_month_start")
            }
        }
    }

    /// Reads the persisted scheduleDays set (1=Sun…7=Sat). Empty/missing means every day.
    private func isTodayScheduledDay() -> Bool {
        // If schedule isn't explicitly enabled, treat the interval-fire as authoritative.
        guard sharedDefaults.bool(forKey: "focus_schedule_enabled") else { return true }
        guard let saved = sharedDefaults.array(forKey: "focus_schedule_days") as? [Int],
              !saved.isEmpty else {
            return true
        }
        let days = Set(saved)
        // For overnight windows the interval fires on the start day; the end-of-day day boundary
        // is handled by the interval itself, so checking today's weekday is correct here.
        let today = Calendar.current.component(.weekday, from: Date())
        return days.contains(today)
    }

    private func shouldApplyShieldsNow(at date: Date = Date()) -> Bool {
        guard sharedDefaults.bool(forKey: "focus_mode_enabled") else { return false }
        guard sharedDefaults.bool(forKey: "focus_schedule_enabled") else { return true }

        if let manualUntil = sharedDefaults.object(forKey: "focus_manual_schedule_override_until") as? Date,
           manualUntil > date {
            return true
        }

        return isWithinScheduledWindow(at: date)
    }

    private func isWithinScheduledWindow(at date: Date) -> Bool {
        guard let scheduleStart = sharedDefaults.object(forKey: "focus_schedule_start") as? Date,
              let scheduleEnd = sharedDefaults.object(forKey: "focus_schedule_end") as? Date else {
            return true
        }

        let cal = Calendar.current
        let startComponents = cal.dateComponents([.hour, .minute], from: scheduleStart)
        let endComponents = cal.dateComponents([.hour, .minute], from: scheduleEnd)
        let nowComponents = cal.dateComponents([.hour, .minute], from: date)
        let startMinutes = (startComponents.hour ?? 0) * 60 + (startComponents.minute ?? 0)
        let endMinutes = (endComponents.hour ?? 0) * 60 + (endComponents.minute ?? 0)
        let nowMinutes = (nowComponents.hour ?? 0) * 60 + (nowComponents.minute ?? 0)
        let todayWeekday = cal.component(.weekday, from: date)
        let yesterdayWeekday = ((todayWeekday - 2 + 7) % 7) + 1
        let activeDays = scheduledDays()

        if startMinutes <= endMinutes {
            return activeDays.contains(todayWeekday) &&
                nowMinutes >= startMinutes &&
                nowMinutes < endMinutes
        }

        if nowMinutes >= startMinutes {
            return activeDays.contains(todayWeekday)
        } else if nowMinutes < endMinutes {
            return activeDays.contains(yesterdayWeekday)
        }
        return false
    }

    private func scheduledDays() -> Set<Int> {
        guard let saved = sharedDefaults.array(forKey: "focus_schedule_days") as? [Int],
              !saved.isEmpty else {
            return Set(1...7)
        }
        return Set(saved)
    }
}
