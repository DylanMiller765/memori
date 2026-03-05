import SwiftUI
import SwiftData

struct SettingsView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(StoreService.self) private var storeService
    @Query private var users: [User]
    @Query(sort: \DailySession.date, order: .reverse) private var sessions: [DailySession]

    @AppStorage("appTheme") private var appTheme: String = AppTheme.system.rawValue

    @State private var showingPaywall = false
    @State private var showingResetConfirmation = false

    private var user: User? { users.first }
    private var isProUser: Bool { storeService.isProUser || (user?.isProUser ?? false) }

    private var selectedTheme: AppTheme {
        AppTheme(rawValue: appTheme) ?? .system
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    profileHeader
                    proCard
                    notificationsCard
                    appearanceCard
                    preferencesCard
                    privacyCard
                    aboutCard
                }
                .padding(.horizontal)
                .padding(.top, 8)
                .padding(.bottom, 32)
            }
            .pageBackground()
            .navigationTitle("Settings")
            .sheet(isPresented: $showingPaywall) {
                PaywallView()
            }
            .alert("Reset All Data", isPresented: $showingResetConfirmation) {
                Button("Reset", role: .destructive) { resetAllData() }
                Button("Cancel", role: .cancel) {}
            } message: {
                Text("This will permanently delete all your training data, streaks, and progress. This cannot be undone.")
            }
        }
    }

    // MARK: - Profile Header

    private var profileHeader: some View {
        VStack(spacing: 16) {
            StreakRingView(current: user?.currentStreak ?? 0, goal: 7, lineWidth: 6, size: 88)

            VStack(spacing: 4) {
                HStack(spacing: 6) {
                    Text("MindRestore")
                        .font(.title3.weight(.semibold))
                    if isProUser {
                        Text("PRO")
                            .font(.caption2.weight(.bold))
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(AppColors.accent, in: Capsule())
                            .foregroundStyle(.white)
                    }
                }
            }

            HStack(spacing: 0) {
                quickStat(value: "\(user?.currentStreak ?? 0)", label: "Streak", icon: "flame.fill", color: AppColors.accent)
                Divider().frame(height: 32)
                quickStat(value: "\(sessions.count)", label: "Sessions", icon: "brain.head.profile", color: .blue)
                Divider().frame(height: 32)
                let weekCount = sessions.filter { $0.date > Date().daysAgo(7) }.count
                quickStat(value: "\(weekCount)", label: "This Week", icon: "calendar", color: .purple)
            }
        }
        .padding(.vertical, 8)
        .appCard()
    }

    private func quickStat(value: String, label: String, icon: String, color: Color) -> some View {
        VStack(spacing: 6) {
            Image(systemName: icon)
                .font(.caption)
                .foregroundStyle(color)
            Text(value)
                .font(.headline)
            Text(label)
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
    }

    // MARK: - Pro Card

    private var proCard: some View {
        Group {
            if isProUser {
                HStack(spacing: 14) {
                    Image(systemName: "star.fill")
                        .font(.title3)
                        .foregroundStyle(.yellow)
                        .frame(width: 40, height: 40)
                        .background(Color.yellow.opacity(0.15), in: RoundedRectangle(cornerRadius: 10))

                    VStack(alignment: .leading, spacing: 2) {
                        Text("Pro Member")
                            .font(.subheadline.weight(.semibold))
                        Text("All features unlocked")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    Spacer()
                    Button("Restore") {
                        Task { await storeService.restorePurchases() }
                    }
                    .font(.caption.weight(.medium))
                    .foregroundStyle(.secondary)
                }
                .appCard()
            } else {
                Button { showingPaywall = true } label: {
                    HStack(spacing: 14) {
                        Image(systemName: "sparkles")
                            .font(.title2)
                            .foregroundStyle(.white)

                        VStack(alignment: .leading, spacing: 2) {
                            Text("Upgrade to Pro")
                                .font(.subheadline.weight(.semibold))
                                .foregroundStyle(.white)
                            Text("All exercises, detailed analytics")
                                .font(.caption)
                                .foregroundStyle(.white.opacity(0.8))
                        }

                        Spacer()

                        Image(systemName: "chevron.right")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(.white.opacity(0.6))
                    }
                    .padding(16)
                    .background(
                        LinearGradient(colors: [AppColors.accent, AppColors.accent.opacity(0.85)], startPoint: .topLeading, endPoint: .bottomTrailing),
                        in: RoundedRectangle(cornerRadius: 16)
                    )
                    .shadow(color: AppColors.accent.opacity(0.25), radius: 12, y: 4)
                }
                .buttonStyle(.plain)
            }
        }
    }

    // MARK: - Notifications

    private var notificationsCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            SectionHeader(title: "Notifications")

            if let user {
                Toggle(isOn: Binding(
                    get: { user.notificationsEnabled },
                    set: { newValue in
                        user.notificationsEnabled = newValue
                        if newValue {
                            Task {
                                let granted = await NotificationService.shared.requestPermission()
                                if granted {
                                    NotificationService.shared.scheduleDailyReminder(
                                        hour: user.reminderHour,
                                        minute: user.reminderMinute,
                                        streak: user.currentStreak
                                    )
                                } else {
                                    user.notificationsEnabled = false
                                }
                            }
                        } else {
                            NotificationService.shared.cancelAll()
                        }
                    }
                )) {
                    HStack(spacing: 12) {
                        Image(systemName: "bell.fill")
                            .foregroundStyle(AppColors.accent)
                            .frame(width: 20)
                        Text("Daily Reminder")
                            .font(.subheadline)
                    }
                }
                .tint(AppColors.accent)

                if user.notificationsEnabled {
                    Divider()
                    DatePicker(
                        "Reminder Time",
                        selection: Binding(
                            get: {
                                var components = DateComponents()
                                components.hour = user.reminderHour
                                components.minute = user.reminderMinute
                                return Calendar.current.date(from: components) ?? Date()
                            },
                            set: { date in
                                let components = Calendar.current.dateComponents([.hour, .minute], from: date)
                                user.reminderHour = components.hour ?? 9
                                user.reminderMinute = components.minute ?? 0
                                NotificationService.shared.scheduleDailyReminder(
                                    hour: user.reminderHour,
                                    minute: user.reminderMinute,
                                    streak: user.currentStreak
                                )
                            }
                        ),
                        displayedComponents: .hourAndMinute
                    )
                    .font(.subheadline)
                }
            }
        }
        .appCard()
    }

    // MARK: - Appearance

    private var appearanceCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            SectionHeader(title: "Appearance")

            HStack(spacing: 8) {
                ForEach(AppTheme.allCases, id: \.rawValue) { theme in
                    Button {
                        withAnimation(.easeInOut(duration: 0.2)) {
                            appTheme = theme.rawValue
                        }
                    } label: {
                        VStack(spacing: 8) {
                            themePreview(for: theme)
                            Text(theme.displayName)
                                .font(.caption.weight(.medium))
                                .foregroundStyle(selectedTheme == theme ? AppColors.accent : Color.secondary)
                        }
                    }
                    .buttonStyle(.plain)
                    .frame(maxWidth: .infinity)
                }
            }
        }
        .appCard()
    }

    @ViewBuilder
    private func themePreview(for theme: AppTheme) -> some View {
        let isSelected = selectedTheme == theme
        let strokeColor: Color = isSelected ? AppColors.accent : Color.gray.opacity(0.2)
        let strokeWidth: CGFloat = isSelected ? 2 : 1

        Group {
            switch theme {
            case .dark:
                RoundedRectangle(cornerRadius: 10).fill(Color.black)
            case .light:
                RoundedRectangle(cornerRadius: 10).fill(Color.white)
            case .system:
                RoundedRectangle(cornerRadius: 10).fill(
                    LinearGradient(colors: [.white, .black], startPoint: .leading, endPoint: .trailing)
                )
            }
        }
        .frame(height: 48)
        .overlay(RoundedRectangle(cornerRadius: 10).stroke(strokeColor, lineWidth: strokeWidth))
        .overlay {
            Image(systemName: theme.icon)
                .font(.body)
                .foregroundStyle(theme == .dark ? Color.white : Color.primary)
        }
    }

    // MARK: - Preferences

    private var preferencesCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            SectionHeader(title: "Preferences")

            if let user {
                HStack {
                    Image(systemName: "target")
                        .foregroundStyle(AppColors.accent)
                        .frame(width: 20)
                    Text("Daily Goal")
                        .font(.subheadline)
                    Spacer()
                    Stepper("\(user.dailyGoal) exercises", value: Binding(
                        get: { user.dailyGoal },
                        set: { user.dailyGoal = $0 }
                    ), in: 1...10)
                    .font(.subheadline)
                }

                Divider()

                Toggle(isOn: Binding(
                    get: { user.soundEnabled },
                    set: { user.soundEnabled = $0 }
                )) {
                    HStack(spacing: 12) {
                        Image(systemName: "speaker.wave.2.fill")
                            .foregroundStyle(.blue)
                            .frame(width: 20)
                        Text("Exercise Sounds")
                            .font(.subheadline)
                    }
                }
                .tint(AppColors.accent)
            }
        }
        .appCard()
    }

    // MARK: - Privacy

    private var privacyCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            SectionHeader(title: "Privacy")

            VStack(spacing: 12) {
                privacyRow(icon: "internaldrive.fill", color: .green, title: "Your Data", detail: "All data stays on your device. No cloud, no accounts.")
                Divider().padding(.leading, 44)
                privacyRow(icon: "hand.raised.fill", color: .purple, title: "No Tracking", detail: "Zero analytics, no third-party SDKs.")
            }
        }
        .appCard()
    }

    private func privacyRow(icon: String, color: Color, title: String, detail: String) -> some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.caption)
                .foregroundStyle(.white)
                .frame(width: 26, height: 26)
                .background(color, in: RoundedRectangle(cornerRadius: 6))

            VStack(alignment: .leading, spacing: 2) {
                Text(title).font(.subheadline.weight(.medium))
                Text(detail).font(.caption).foregroundStyle(.secondary)
            }
            Spacer()
        }
    }

    // MARK: - About

    private var aboutCard: some View {
        VStack(spacing: 0) {
            aboutRow(icon: "info.circle.fill", color: .gray, title: "Version", trailing: Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0")
            Divider().padding(.leading, 44)
            if isProUser {
                aboutRow(icon: "creditcard.fill", color: .blue, title: "Manage Subscription", isLink: true) {
                    if let url = URL(string: "https://apps.apple.com/account/subscriptions") {
                        UIApplication.shared.open(url)
                    }
                }
            } else {
                aboutRow(icon: "arrow.clockwise", color: .teal, title: "Restore Purchases", isLink: true) {
                    Task { await storeService.restorePurchases() }
                }
            }
            Divider().padding(.leading, 44)
            aboutRow(icon: "trash.fill", color: .red, title: "Reset All Data", isLink: true) {
                showingResetConfirmation = true
            }
        }
        .appCard(padding: 0)
    }

    private func aboutRow(icon: String, color: Color, title: String, trailing: String? = nil, isLink: Bool = false, action: (() -> Void)? = nil) -> some View {
        Button {
            action?()
        } label: {
            HStack(spacing: 12) {
                Image(systemName: icon)
                    .font(.caption)
                    .foregroundStyle(.white)
                    .frame(width: 26, height: 26)
                    .background(color, in: RoundedRectangle(cornerRadius: 6))

                Text(title)
                    .font(.subheadline)
                    .foregroundStyle(color == .red ? .red : .primary)

                Spacer()

                if let trailing {
                    Text(trailing).font(.subheadline).foregroundStyle(.secondary)
                } else if isLink {
                    Image(systemName: "chevron.right").font(.caption2.weight(.semibold)).foregroundStyle(.tertiary)
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
        }
        .buttonStyle(.plain)
        .disabled(action == nil)
    }

    // MARK: - Reset

    private func resetAllData() {
        do {
            try modelContext.delete(model: Exercise.self)
            try modelContext.delete(model: SpacedRepetitionCard.self)
            try modelContext.delete(model: DailySession.self)
            if let user {
                user.currentStreak = 0
                user.longestStreak = 0
                user.lastSessionDate = nil
            }
            NotificationService.shared.cancelAll()
        } catch {
            // Silent fail — data will be inconsistent but app won't crash
        }
    }
}
