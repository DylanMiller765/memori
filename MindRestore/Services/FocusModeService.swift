import Foundation
import FamilyControls
import ManagedSettings
import DeviceActivity

// MARK: - Shared UserDefaults Keys

private enum FocusKey {
    static let enabled          = "focus_mode_enabled"
    static let unlockUntil      = "focus_unlock_until"
    static let unlockDuration   = "focus_unlock_duration"
    static let scheduleEnabled  = "focus_schedule_enabled"
    static let scheduleStart    = "focus_schedule_start"
    static let scheduleEnd      = "focus_schedule_end"
    static let dailyAttemptCount = "focus_daily_attempt_count"
    static let dailyAttemptDate  = "focus_daily_attempt_date"
    static let cooldownUntil    = "focus_cooldown_until"
    static let activitySelection = "focus_activity_selection"
}

// MARK: - FocusModeService

@MainActor
@Observable
final class FocusModeService {

    // MARK: Published state

    /// Whether Focus Mode is currently active (shields applied).
    var isEnabled: Bool = false

    /// Date until which a temporary unlock is active (nil = not unlocked).
    var unlockUntil: Date?

    /// Duration in minutes for a temporary unlock (default 15).
    var unlockDuration: Int = 15

    /// Whether a schedule is active.
    var scheduleEnabled: Bool = false

    /// Schedule window start time (hour/minute only; day ignored).
    var scheduleStart: Date = Calendar.current.date(bySettingHour: 22, minute: 0, second: 0, of: Date()) ?? Date()

    /// Schedule window end time (hour/minute only; day ignored).
    var scheduleEnd: Date = Calendar.current.date(bySettingHour: 8, minute: 0, second: 0, of: Date()) ?? Date()

    /// Number of times the user has attempted to disable Focus Mode today.
    var dailyAttemptCount: Int = 0

    /// Date until which the disable cooldown is active (nil = no cooldown).
    var cooldownUntil: Date?

    /// The user-selected set of apps/categories to block.
    var activitySelection: FamilyActivitySelection = FamilyActivitySelection()

    /// Authorization status for FamilyControls.
    var authorizationStatus: AuthorizationStatus = .notDetermined

    // MARK: Derived state

    /// True when a temporary unlock window is currently active.
    var isTemporarilyUnlocked: Bool {
        guard let until = unlockUntil else { return false }
        return Date.now < until
    }

    /// True when the disable cooldown is still running.
    var isInCooldown: Bool {
        guard let until = cooldownUntil else { return false }
        return Date.now < until
    }

    /// Number of seconds remaining in the current temporary unlock.
    var secondsUntilRelockNeeded: TimeInterval {
        guard let until = unlockUntil, isTemporarilyUnlocked else { return 0 }
        return until.timeIntervalSinceNow
    }

    /// Number of apps/categories currently being blocked.
    var blockedAppCount: Int {
        activitySelection.applicationTokens.count +
        activitySelection.categoryTokens.count +
        activitySelection.webDomainTokens.count
    }

    // MARK: Private

    private let sharedDefaults: UserDefaults
    private let store = ManagedSettingsStore()
    private var relockTask: Task<Void, Never>?
    private let cooldownMinutes: Int = 10

    // MARK: Init

    init() {
        sharedDefaults = UserDefaults(suiteName: "group.com.memori.shared") ?? .standard
        loadPersistedState()
        Task { await checkAuthorizationStatus() }
        reconcileShieldState()
    }

    // MARK: - Authorization

    func requestAuthorization() async {
        do {
            try await AuthorizationCenter.shared.requestAuthorization(for: .individual)
            authorizationStatus = AuthorizationCenter.shared.authorizationStatus
        } catch {
            authorizationStatus = .denied
        }
    }

    func checkAuthorizationStatus() async {
        authorizationStatus = AuthorizationCenter.shared.authorizationStatus
    }

    // MARK: - Activity Selection

    /// Persist a new FamilyActivitySelection chosen by the picker.
    func updateActivitySelection(_ selection: FamilyActivitySelection) {
        activitySelection = selection
        persist(selection: selection)
        if isEnabled && !isTemporarilyUnlocked {
            applyShields()
        }
    }

    // MARK: - Enable / Disable

    /// Enable Focus Mode and apply shields immediately.
    func enable() {
        isEnabled = true
        persist(bool: true, forKey: FocusKey.enabled)
        clearUnlock()
        clearCooldown()
        applyShields()
    }

    /// Disable Focus Mode (subject to cooldown).
    /// Returns false if cooldown is still active.
    @discardableResult
    func disable() -> Bool {
        if isInCooldown { return false }

        // Increment daily attempt count
        incrementDailyAttemptCount()

        // Apply cooldown
        let cooldownEnd = Date.now.addingTimeInterval(TimeInterval(cooldownMinutes * 60))
        cooldownUntil = cooldownEnd
        persist(date: cooldownEnd, forKey: FocusKey.cooldownUntil)

        isEnabled = false
        persist(bool: false, forKey: FocusKey.enabled)
        clearUnlock()
        removeShields()
        return true
    }

    // MARK: - Temporary Unlock

    /// Temporarily remove shields for `durationMinutes` minutes, then re-apply.
    func temporaryUnlock(durationMinutes: Int? = nil) {
        let minutes = durationMinutes ?? unlockDuration
        let unlockEnd = Date.now.addingTimeInterval(TimeInterval(minutes * 60))
        unlockUntil = unlockEnd
        persist(date: unlockEnd, forKey: FocusKey.unlockUntil)
        removeShields()
        scheduleRelock(at: unlockEnd)
    }

    /// Cancel an active temporary unlock and re-apply shields immediately.
    func cancelTemporaryUnlock() {
        clearUnlock()
        if isEnabled {
            applyShields()
        }
    }

    // MARK: - Shield Management

    private func applyShields() {
        store.shield.applications = activitySelection.applicationTokens.isEmpty
            ? nil
            : activitySelection.applicationTokens
        store.shield.applicationCategories = activitySelection.categoryTokens.isEmpty
            ? nil
            : ShieldSettings.ActivityCategoryPolicy.specific(activitySelection.categoryTokens)
        store.shield.webDomains = activitySelection.webDomainTokens.isEmpty
            ? nil
            : activitySelection.webDomainTokens
    }

    private func removeShields() {
        store.shield.applications = nil
        store.shield.applicationCategories = nil
        store.shield.webDomains = nil
    }

    // MARK: - Relock scheduling

    private func scheduleRelock(at date: Date) {
        relockTask?.cancel()
        relockTask = Task { [weak self] in
            let delay = max(0, date.timeIntervalSinceNow)
            try? await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))
            guard !Task.isCancelled else { return }
            await MainActor.run {
                guard let self, self.isEnabled else { return }
                self.clearUnlock()
                self.applyShields()
            }
        }
    }

    // MARK: - Schedule

    func updateSchedule(enabled: Bool, start: Date, end: Date) {
        scheduleEnabled = enabled
        scheduleStart = start
        scheduleEnd = end
        persist(bool: enabled, forKey: FocusKey.scheduleEnabled)
        persist(date: start, forKey: FocusKey.scheduleStart)
        persist(date: end, forKey: FocusKey.scheduleEnd)
    }

    // MARK: - Helpers

    private func reconcileShieldState() {
        if isEnabled && !isTemporarilyUnlocked {
            applyShields()
        } else if isTemporarilyUnlocked, let until = unlockUntil {
            removeShields()
            scheduleRelock(at: until)
        } else {
            removeShields()
        }
    }

    private func incrementDailyAttemptCount() {
        let today = Date.now
        if let saved = sharedDefaults.object(forKey: FocusKey.dailyAttemptDate) as? Date,
           Calendar.current.isDateInToday(saved) {
            dailyAttemptCount += 1
        } else {
            dailyAttemptCount = 1
            persist(date: today, forKey: FocusKey.dailyAttemptDate)
        }
        sharedDefaults.set(dailyAttemptCount, forKey: FocusKey.dailyAttemptCount)
    }

    private func clearUnlock() {
        unlockUntil = nil
        sharedDefaults.removeObject(forKey: FocusKey.unlockUntil)
        relockTask?.cancel()
        relockTask = nil
    }

    private func clearCooldown() {
        cooldownUntil = nil
        sharedDefaults.removeObject(forKey: FocusKey.cooldownUntil)
    }

    // MARK: - Persistence

    private func loadPersistedState() {
        isEnabled      = sharedDefaults.bool(forKey: FocusKey.enabled)
        unlockDuration = sharedDefaults.integer(forKey: FocusKey.unlockDuration).nonZeroOrDefault(15)
        scheduleEnabled = sharedDefaults.bool(forKey: FocusKey.scheduleEnabled)
        unlockUntil    = sharedDefaults.object(forKey: FocusKey.unlockUntil) as? Date
        cooldownUntil  = sharedDefaults.object(forKey: FocusKey.cooldownUntil) as? Date

        if let start = sharedDefaults.object(forKey: FocusKey.scheduleStart) as? Date {
            scheduleStart = start
        }
        if let end = sharedDefaults.object(forKey: FocusKey.scheduleEnd) as? Date {
            scheduleEnd = end
        }

        let savedCount = sharedDefaults.integer(forKey: FocusKey.dailyAttemptCount)
        if let savedDate = sharedDefaults.object(forKey: FocusKey.dailyAttemptDate) as? Date,
           Calendar.current.isDateInToday(savedDate) {
            dailyAttemptCount = savedCount
        } else {
            dailyAttemptCount = 0
        }

        if let data = sharedDefaults.data(forKey: FocusKey.activitySelection),
           let selection = try? JSONDecoder().decode(FamilyActivitySelection.self, from: data) {
            activitySelection = selection
        }
    }

    private func persist(bool value: Bool, forKey key: String) {
        sharedDefaults.set(value, forKey: key)
    }

    private func persist(date value: Date, forKey key: String) {
        sharedDefaults.set(value, forKey: key)
    }

    private func persist(selection: FamilyActivitySelection) {
        if let data = try? JSONEncoder().encode(selection) {
            sharedDefaults.set(data, forKey: FocusKey.activitySelection)
        }
    }
}

// MARK: - Helpers

private extension Int {
    func nonZeroOrDefault(_ fallback: Int) -> Int {
        self == 0 ? fallback : self
    }
}
