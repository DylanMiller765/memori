import SwiftUI
import FamilyControls

struct FocusModeSettingsView: View {
    @Environment(FocusModeService.self) private var focusModeService
    @Environment(StoreService.self) private var storeService
    @Environment(\.dismiss) private var dismiss
    @State private var showingAppPicker = false
    @State private var showingProPaywall = false

    private var currentSelectionExceedsFreeLimit: Bool {
        focusModeService.activitySelection.applicationTokens.count > 1 ||
        !focusModeService.activitySelection.categoryTokens.isEmpty ||
        !focusModeService.activitySelection.webDomainTokens.isEmpty
    }

    var body: some View {
        NavigationStack {
            List {
                // MARK: Status
                Section {
                    HStack {
                        Text("Focus Mode")
                        Spacer()
                        Text(focusStatusLabel)
                            .foregroundStyle(focusStatusColor)
                    }

                    if focusModeService.isTemporarilyUnlocked, let until = focusModeService.unlockUntil {
                        TimelineView(.periodic(from: .now, by: 1)) { _ in
                            HStack {
                                Text("Currently unlocked")
                                Spacer()
                                Text(unlockTimeRemaining(until: until))
                                    .foregroundStyle(.secondary)
                                    .monospacedDigit()
                            }
                        }
                    }
                }

                // MARK: Blocked Apps
                Section("Blocked Apps") {
                    if focusModeService.isBlockingNow {
                        if storeService.isProUser {
                            Button {
                                showingAppPicker = true
                            } label: {
                                HStack {
                                    Image(systemName: "plus.circle.fill")
                                        .foregroundStyle(AppColors.accent)
                                    Text("Add apps")
                                }
                            }
                        } else {
                            HStack {
                                Image(systemName: "lock.fill")
                                    .foregroundStyle(.secondary)
                                Text("Locked while Focus is active")
                                    .foregroundStyle(.secondary)
                            }
                        }
                    } else {
                        Button("Edit blocked apps") {
                            showingAppPicker = true
                        }
                    }

                    HStack {
                        Text("Apps blocked")
                        Spacer()
                        Text("\(focusModeService.blockedAppCount)")
                            .foregroundStyle(.secondary)
                    }

                    if !storeService.isProUser {
                        HStack(spacing: 8) {
                            Image(systemName: currentSelectionExceedsFreeLimit ? "lock.fill" : "checkmark.circle.fill")
                                .foregroundStyle(currentSelectionExceedsFreeLimit ? AppColors.amber : AppColors.accent)
                            Text(currentSelectionExceedsFreeLimit ? "Reduce to 1 app or unlock full access" : "Starter access blocks 1 app")
                                .foregroundStyle(currentSelectionExceedsFreeLimit ? AppColors.amber : .secondary)
                        }
                    }
                }

                // MARK: Schedule
                Section("Schedule") {
                    Toggle("Use schedule", isOn: Binding(
                        get: { focusModeService.scheduleEnabled },
                        set: { newValue in
                            focusModeService.updateSchedule(
                                enabled: newValue,
                                start: focusModeService.scheduleStart,
                                end: focusModeService.scheduleEnd
                            )
                        }
                    ))

                    if focusModeService.scheduleEnabled {
                        if focusModeService.shouldShowScheduledOffNow {
                            Button {
                                focusModeService.blockNowUntilNextSchedule()
                            } label: {
                                HStack {
                                    Image(systemName: "bolt.shield.fill")
                                        .foregroundStyle(AppColors.amber)
                                    Text("Block now until next shift")
                                }
                            }
                        }

                        DatePicker("Start", selection: Binding(
                            get: { focusModeService.scheduleStart },
                            set: { newValue in
                                focusModeService.updateSchedule(
                                    enabled: focusModeService.scheduleEnabled,
                                    start: newValue,
                                    end: focusModeService.scheduleEnd
                                )
                            }
                        ), displayedComponents: .hourAndMinute)

                        DatePicker("End", selection: Binding(
                            get: { focusModeService.scheduleEnd },
                            set: { newValue in
                                focusModeService.updateSchedule(
                                    enabled: focusModeService.scheduleEnabled,
                                    start: focusModeService.scheduleStart,
                                    end: newValue
                                )
                            }
                        ), displayedComponents: .hourAndMinute)
                    }
                }

                // MARK: Unlock Window
                Section("Unlock Window") {
                    HStack {
                        Text("Your spin decides")
                        Spacer()
                        Text("5–20 min")
                            .foregroundStyle(.secondary)
                    }
                }

                // MARK: Today's Stats
                Section("Today") {
                    HStack {
                        Text("Disable attempts")
                        Spacer()
                        Text("\(focusModeService.dailyAttemptCount)")
                            .foregroundStyle(.secondary)
                    }
                }

                // MARK: Disable / Cooldown
                Section {
                    if focusModeService.isInCooldown, let cooldownEnd = focusModeService.cooldownUntil {
                        TimelineView(.periodic(from: .now, by: 1)) { _ in
                            HStack {
                                Text("Cooldown — \(cooldownTimeRemaining(until: cooldownEnd))")
                                    .foregroundStyle(.secondary)
                                    .monospacedDigit()
                                Spacer()
                            }
                        }
                    } else if focusModeService.isEnabled {
                        Text("Train for a short pass back in.")
                            .foregroundStyle(.secondary)
                    }
                }
            }
            .navigationTitle("Focus Mode")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { dismiss() }
                }
            }
            .familyActivityPicker(isPresented: $showingAppPicker, selection: Binding(
                get: { focusModeService.activitySelection },
                set: { newSelection in
                    let exceedsLimit = newSelection.applicationTokens.count > 1 ||
                        !newSelection.categoryTokens.isEmpty ||
                        !newSelection.webDomainTokens.isEmpty
                    if !storeService.isProUser && exceedsLimit {
                        showingProPaywall = true
                    } else {
                        focusModeService.updateActivitySelection(newSelection)
                    }
                }
            ))
            .sheet(isPresented: $showingProPaywall) {
                PaywallView(triggerSource: "focus_mode_limit")
            }
        }
    }

    // MARK: - Helpers

    private var focusStatusLabel: String {
        if focusModeService.isTemporarilyUnlocked { return "Pass active" }
        if focusModeService.isBlockingNow { return "Blocking" }
        if focusModeService.shouldShowScheduledOffNow { return "Scheduled" }
        return focusModeService.isEnabled ? "Ready" : "Off"
    }

    private var focusStatusColor: Color {
        if focusModeService.isBlockingNow { return AppColors.accent }
        if focusModeService.shouldShowScheduledOffNow { return AppColors.amber }
        return .secondary
    }

    private func unlockTimeRemaining(until date: Date) -> String {
        let remaining = max(0, Int(date.timeIntervalSinceNow))
        let min = remaining / 60
        let sec = remaining % 60
        return "\(min):\(String(format: "%02d", sec)) left"
    }

    private func cooldownTimeRemaining(until date: Date) -> String {
        let remaining = max(0, Int(date.timeIntervalSinceNow))
        let min = remaining / 60
        let sec = remaining % 60
        return "\(min):\(String(format: "%02d", sec))"
    }
}
