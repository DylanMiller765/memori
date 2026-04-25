import DeviceActivity
import FamilyControls
import ManagedSettings
import Foundation

class DeviceActivityMonitorExtension: DeviceActivityMonitor {
    private let sharedDefaults = UserDefaults(suiteName: "group.com.memori.shared")!
    private let store = ManagedSettingsStore()

    override func intervalDidStart(for activity: DeviceActivityName) {
        // Schedule started — apply shields, but ONLY if today is in the user's chosen days.
        // DeviceActivitySchedule is interval-based and has no native day-of-week filter, so
        // we enforce it here in the extension callback (which fires whether or not the host
        // app is running).
        guard sharedDefaults.bool(forKey: "focus_mode_enabled") else { return }
        guard isTodayScheduledDay() else {
            // Wrong day — ensure shields are down in case a previous run left them up.
            store.shield.applications = nil
            store.shield.applicationCategories = nil
            store.shield.webDomains = nil
            return
        }

        if let data = sharedDefaults.data(forKey: "focus_activity_selection"),
           let selection = try? JSONDecoder().decode(FamilyActivitySelection.self, from: data) {
            store.shield.applications = selection.applicationTokens.isEmpty ? nil : selection.applicationTokens
            let categories = selection.categoryTokens
            store.shield.applicationCategories = categories.isEmpty ? nil : .specific(categories)
        }
    }

    override func intervalDidEnd(for activity: DeviceActivityName) {
        // Schedule ended — remove shields
        store.shield.applications = nil
        store.shield.applicationCategories = nil
        store.shield.webDomains = nil
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
}
