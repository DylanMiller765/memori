import SwiftUI
import SwiftData

struct SettingsView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(StoreService.self) private var storeService
    @Environment(GameCenterService.self) private var gameCenterService
    @Query private var users: [User]
    @Query(sort: \DailySession.date, order: .reverse) private var sessions: [DailySession]
    @Query(sort: \BrainScoreResult.date, order: .reverse) private var brainScores: [BrainScoreResult]
    @Query private var achievements: [Achievement]

    @AppStorage("appTheme") private var appTheme: String = AppTheme.light.rawValue
    @State private var showingPaywall = false
    @State private var showingResetConfirmation = false
    @State private var showingScreenshotDataConfirmation = false
    @State private var screenshotDataLoaded = false
    @State private var debugTapCount = 0
    @State private var editingName = false
    @State private var editedName = ""

    private var user: User? { users.first }
    private var isProUser: Bool { storeService.isProUser || (user?.isProUser ?? false) }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    profileHeader
                    proCard
                    notificationsCard
                    preferencesCard
                    streakFreezeCard
                    privacyCard
                    aboutCard

                    debugCard
                }
                .padding(.horizontal)
                .padding(.top, 8)
                .padding(.bottom, 32)
                .responsiveContent()
                .frame(maxWidth: .infinity)
            }
            .pageBackground()
            .navigationTitle("Profile")
            .sheet(isPresented: $showingPaywall) {
                PaywallView()
            }
            .alert("Reset All Data", isPresented: $showingResetConfirmation) {
                Button("Reset Everything", role: .destructive) { resetAllData() }
                Button("Cancel", role: .cancel) {}
            } message: {
                Text("Are you sure? This will delete all your progress, scores, and settings.")
            }
            .alert("Load Screenshot Data", isPresented: $showingScreenshotDataConfirmation) {
                Button("Load Demo Data", role: .destructive) { loadScreenshotData() }
                Button("Cancel", role: .cancel) {}
            } message: {
                Text("This replaces ALL your data with demo data for App Store screenshots. Your real progress will be lost.")
            }
        }
    }

    // MARK: - Profile Header

    private var latestBrainScore: BrainScoreResult? { brainScores.first }
    private var unlockedAchievements: [Achievement] { achievements }

    private var totalTrainingMinutes: Int {
        let totalSeconds = sessions.reduce(0) { $0 + $1.durationSeconds }
        return totalSeconds / 60
    }

    private var trainingTimeString: String {
        let mins = totalTrainingMinutes
        if mins > 60 {
            return "\(mins / 60)h \(mins % 60)m"
        }
        return "\(mins)m"
    }

    private var profileHeader: some View {
        VStack(spacing: 16) {
            // Dark gradient player card
            profilePlayerCard

            // Stats row — glowing cards like exercise results
            profileGlowingStats
        }
    }

    private var profilePlayerCard: some View {
        VStack(spacing: 0) {
            // Dark hero section
            ZStack {
                // Cream card bg
                RoundedRectangle(cornerRadius: 20)
                    .fill(AppColors.cardSurface)
                    .shadow(color: .black.opacity(0.06), radius: 12, y: 4)

                // Subtle accent glow behind brain score
                if latestBrainScore != nil {
                    Circle()
                        .fill(AppColors.accent.opacity(0.06))
                        .frame(width: 200, height: 200)
                        .blur(radius: 40)
                        .offset(y: -10)
                }

                VStack(spacing: 16) {
                    // Name + level badge row
                    HStack {
                        VStack(alignment: .leading, spacing: 4) {
                            HStack(spacing: 8) {
                                let name = (user?.username.isEmpty == false) ? user!.username : "Player"
                                Text(name)
                                    .font(.title2.weight(.bold))
                                    .foregroundStyle(AppColors.textPrimary)
                                if isProUser {
                                    Text("PRO")
                                        .font(.system(size: 9, weight: .black))
                                        .foregroundStyle(AppColors.textPrimary)
                                        .padding(.horizontal, 7)
                                        .padding(.vertical, 3)
                                        .background(
                                            LinearGradient(colors: [AppColors.amber, AppColors.coral], startPoint: .leading, endPoint: .trailing),
                                            in: Capsule()
                                        )
                                }
                            }
                            let levelName = user?.levelName ?? "Beginner"
                            Text(levelName)
                                .font(.caption.weight(.semibold))
                                .foregroundStyle(AppColors.textTertiary)
                        }

                        Spacer()

                        // Level badge
                        VStack(spacing: 2) {
                            Text("LV")
                                .font(.system(size: 9, weight: .black, design: .rounded))
                                .foregroundStyle(AppColors.accent.opacity(0.7))
                            Text("\(user?.level ?? 1)")
                                .font(.system(size: 24, weight: .black, design: .rounded))
                                .foregroundStyle(AppColors.accent)
                        }
                        .frame(width: 52, height: 52)
                        .background(
                            RoundedRectangle(cornerRadius: 14)
                                .fill(AppColors.accent.opacity(0.08))
                                .overlay(
                                    RoundedRectangle(cornerRadius: 14)
                                        .stroke(AppColors.accent.opacity(0.15), lineWidth: 1)
                                )
                        )
                    }

                    // Brain Score hero
                    profileBrainScoreHero

                    // XP bar
                    profileXPBar
                }
                .padding(20)
            }
            .clipShape(RoundedRectangle(cornerRadius: 20))

            // Brain type + badges row below card
            if latestBrainScore != nil {
                profileBadgeRow
                    .padding(.top, 10)
            }
        }
    }

    @ViewBuilder
    private var profileBrainScoreHero: some View {
        if let score = latestBrainScore {
            BrainScoreCard(score: score, compact: true)
        } else {
            // No brain score yet
            VStack(spacing: 8) {
                Image(systemName: "brain.head.profile")
                    .font(.system(size: 32))
                    .foregroundStyle(AppColors.textTertiary)
                Text("Take your first Brain Assessment")
                    .font(.caption.weight(.medium))
                    .foregroundStyle(AppColors.textTertiary)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 12)
        }
    }

    @ViewBuilder
    private var profileXPBar: some View {
        if let user {
            VStack(spacing: 4) {
                GeometryReader { geo in
                    ZStack(alignment: .leading) {
                        RoundedRectangle(cornerRadius: 3)
                            .fill(AppColors.accent.opacity(0.08))
                        RoundedRectangle(cornerRadius: 3)
                            .fill(AppColors.accentGradient)
                            .frame(width: max(4, geo.size.width * user.xpProgress))
                    }
                }
                .frame(height: 4)

                HStack {
                    Text("\(user.totalXP) XP")
                        .font(.system(size: 10, weight: .bold, design: .rounded))
                        .foregroundStyle(AppColors.textTertiary)
                    Spacer()
                    Text("\(user.xpForNextLevel) XP")
                        .font(.system(size: 10, weight: .bold, design: .rounded))
                        .foregroundStyle(AppColors.textTertiary)
                }
            }
        }
    }

    private var profileBadgeRow: some View {
        HStack(spacing: 8) {
            if let score = latestBrainScore {
                let btColor = brainTypeProfileColor(score.brainType)
                HStack(spacing: 4) {
                    Image(systemName: score.brainType.icon)
                        .font(.system(size: 10, weight: .bold))
                    Text(score.brainType.displayName)
                        .font(.system(size: 12, weight: .bold))
                }
                .foregroundStyle(btColor)
                .padding(.horizontal, 10)
                .padding(.vertical, 5)
                .background(btColor.opacity(0.10), in: Capsule())
            }

            if !achievements.isEmpty {
                HStack(spacing: 4) {
                    Image(systemName: "trophy.fill")
                        .font(.system(size: 10, weight: .bold))
                    Text("\(achievements.count) achievements")
                        .font(.system(size: 12, weight: .bold))
                }
                .foregroundStyle(AppColors.amber)
                .padding(.horizontal, 10)
                .padding(.vertical, 5)
                .background(AppColors.amber.opacity(0.10), in: Capsule())
            }
        }
    }

    private var profileGlowingStats: some View {
        HStack(spacing: 10) {
            profileGlowStat(
                value: "\(user?.currentStreak ?? 0)",
                label: "Day Streak",
                icon: "flame.fill",
                color: AppColors.coral
            )
            profileGlowStat(
                value: "\(sessions.count)",
                label: "Sessions",
                icon: "brain.head.profile",
                color: AppColors.violet
            )
            profileGlowStat(
                value: trainingTimeString,
                label: "Trained",
                icon: "clock.fill",
                color: AppColors.teal
            )
        }
    }

    private func profileGlowStat(value: String, label: String, icon: String, color: Color) -> some View {
        VStack(spacing: 6) {
            Image(systemName: icon)
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(color)
            Text(value)
                .font(.system(size: 20, weight: .bold, design: .rounded))
            Text(label)
                .font(.system(size: 10, weight: .medium))
                .foregroundStyle(AppColors.textTertiary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 14)
        .glowingCard(color: color, intensity: 0.15)
    }

    private func brainTypeProfileColor(_ type: BrainType) -> Color {
        switch type {
        case .lightningReflex: return AppColors.coral
        case .numberCruncher: return AppColors.sky
        case .patternMaster: return AppColors.violet
        case .balancedBrain: return AppColors.accent
        }
    }

    // MARK: - Quick Stats Row

    private var quickStatsRow: some View {
        HStack(spacing: 10) {
            miniStatCard(
                value: "\(user?.currentStreak ?? 0)",
                label: "Streak",
                icon: "flame.fill",
                color: AppColors.coral
            )
            miniStatCard(
                value: "\(sessions.count)",
                label: "Sessions",
                icon: "brain.head.profile",
                color: AppColors.indigo
            )
            let weekCount = sessions.filter { $0.date > Date.now.daysAgo(7) }.count
            miniStatCard(
                value: "\(weekCount)",
                label: "This Week",
                icon: "calendar",
                color: AppColors.violet
            )
        }
    }

    private func miniStatCard(value: String, label: String, icon: String, color: Color) -> some View {
        VStack(spacing: 6) {
            Image(systemName: icon)
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(color)

            Text(value)
                .font(.system(size: 22, weight: .bold, design: .rounded))

            Text(label)
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(AppColors.textTertiary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 14)
        .background {
            RoundedRectangle(cornerRadius: 14)
                .fill(color.opacity(0.08))
        }
        .overlay {
            RoundedRectangle(cornerRadius: 14)
                .stroke(color.opacity(0.12), lineWidth: 1)
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(label): \(value)")
    }

    // MARK: - Pro Card

    private var proCard: some View {
        Group {
            if isProUser {
                HStack(spacing: 14) {
                    Image(systemName: "star.fill")
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundStyle(AppColors.amber)
                        .frame(width: 40, height: 40)
                        .background(AppColors.amber.opacity(0.12), in: RoundedRectangle(cornerRadius: 10))

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
                .padding(16)
                .background {
                    RoundedRectangle(cornerRadius: 14)
                        .fill(AppColors.cardSurface)
                        .overlay {
                            RoundedRectangle(cornerRadius: 14)
                                .stroke(
                                    LinearGradient(
                                        colors: [
                                            AppColors.amber.opacity(0.5),
                                            AppColors.amber.opacity(0.2),
                                            AppColors.amber.opacity(0.5)
                                        ],
                                        startPoint: .topLeading,
                                        endPoint: .bottomTrailing
                                    ),
                                    lineWidth: 1.5
                                )
                        }
                        .shadow(color: AppColors.amber.opacity(0.1), radius: 8, y: 2)
                }
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
                        AppColors.premiumGradient,
                        in: RoundedRectangle(cornerRadius: 14)
                    )
                }
                .buttonStyle(.plain)

                Button {
                    Task { await storeService.restorePurchases() }
                } label: {
                    Text("Restore Purchases")
                        .font(.caption.weight(.medium))
                        .foregroundStyle(.secondary)
                }
                .padding(.top, 4)
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
                        settingIcon("bell.fill", color: AppColors.coral)
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

    // MARK: - Preferences

    private var preferencesCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            SectionHeader(title: "Preferences")

            if let user {
                HStack(spacing: 12) {
                    settingIcon("person.fill", color: AppColors.accent)
                    Text("Name")
                        .font(.subheadline)
                    Spacer()
                    if editingName {
                        TextField("Your name", text: $editedName)
                            .font(.subheadline)
                            .multilineTextAlignment(.trailing)
                            .submitLabel(.done)
                            .onSubmit {
                                user.username = editedName.trimmingCharacters(in: .whitespacesAndNewlines)
                                editingName = false
                            }
                    } else {
                        Button {
                            editedName = user.username
                            editingName = true
                        } label: {
                            Text(user.username.isEmpty ? "Not set" : user.username)
                                .font(.subheadline)
                                .foregroundStyle(user.username.isEmpty ? .secondary : .primary)
                        }
                    }
                }

                Divider()

                HStack(spacing: 12) {
                    settingIcon("target", color: AppColors.teal)
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
                        settingIcon("speaker.wave.2.fill", color: AppColors.sky)
                        Text("Exercise Sounds")
                            .font(.subheadline)
                    }
                }
                .tint(AppColors.accent)

                Divider()

                HStack(spacing: 12) {
                    settingIcon("circle.lefthalf.filled", color: AppColors.violet)
                    Text("Appearance")
                        .font(.subheadline)
                    Spacer()
                }

                Picker("", selection: $appTheme) {
                    ForEach(AppTheme.allCases, id: \.rawValue) { theme in
                        Label(theme.displayName, systemImage: theme.icon)
                            .tag(theme.rawValue)
                    }
                }
                .pickerStyle(.segmented)
            }
        }
        .appCard()
    }

    // MARK: - Streak Freeze

    private var streakFreezeCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            SectionHeader(title: "Streak Protection")

            HStack(spacing: 14) {
                ZStack {
                    Circle()
                        .fill(AppColors.sky.opacity(0.12))
                        .frame(width: 48, height: 48)

                    Image(systemName: "shield.fill")
                        .font(.system(size: 22, weight: .semibold))
                        .foregroundStyle(AppColors.sky)
                }

                VStack(alignment: .leading, spacing: 4) {
                    HStack(spacing: 6) {
                        Text("Streak Freezes:")
                            .font(.subheadline.weight(.medium))

                        Text("\(user?.streakFreezes ?? 0)/\(user?.maxStreakFreezes ?? 2) available")
                            .font(.subheadline.weight(.bold))
                            .foregroundStyle(AppColors.accent)
                    }

                    Text("Protects your streak if you miss a day. Earn 1 every 7 days of training.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }

            // Freeze slots — larger and more visual
            HStack(spacing: 10) {
                ForEach(0..<(user?.maxStreakFreezes ?? 2), id: \.self) { index in
                    let isFilled = index < (user?.streakFreezes ?? 0)
                    HStack(spacing: 8) {
                        Image(systemName: isFilled ? "shield.fill" : "shield")
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundStyle(isFilled ? AppColors.sky : .secondary.opacity(0.4))
                        Text(isFilled ? "Ready" : "Empty")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(isFilled ? .primary : .secondary)
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 10)
                    .frame(maxWidth: .infinity)
                    .background(
                        RoundedRectangle(cornerRadius: 12)
                            .fill(isFilled
                                  ? AppColors.sky.opacity(0.10)
                                  : Color.secondary.opacity(0.05))
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(isFilled
                                    ? AppColors.sky.opacity(0.25)
                                    : Color.secondary.opacity(0.1), lineWidth: 1)
                    )
                }
            }

            // Next freeze progress indicator
            if let user {
                let daysIntoStreak = user.currentStreak % 7
                let daysUntilFreeze = daysIntoStreak == 0 && user.currentStreak > 0 ? 0 : 7 - daysIntoStreak
                let freezeProgress = Double(daysIntoStreak) / 7.0

                if user.streakFreezes < user.maxStreakFreezes {
                    VStack(alignment: .leading, spacing: 6) {
                        HStack {
                            Text("Next freeze in \(daysUntilFreeze) day\(daysUntilFreeze == 1 ? "" : "s")")
                                .font(.caption.weight(.medium))
                                .foregroundStyle(AppColors.textTertiary)
                            Spacer()
                            Text("\(daysIntoStreak)/7")
                                .font(.caption2.weight(.bold))
                                .foregroundStyle(AppColors.sky)
                        }

                        GeometryReader { geo in
                            ZStack(alignment: .leading) {
                                RoundedRectangle(cornerRadius: 3)
                                    .fill(AppColors.sky.opacity(0.12))
                                    .frame(height: 4)
                                RoundedRectangle(cornerRadius: 3)
                                    .fill(AppColors.sky)
                                    .frame(width: max(3, geo.size.width * freezeProgress), height: 4)
                            }
                        }
                        .frame(height: 4)
                    }
                    .padding(.top, 2)
                }
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
                privacyRow(icon: "hand.raised.fill", color: .purple, title: "Privacy First", detail: "No personal data collected.")
            }
        }
        .appCard()
    }

    private func privacyRow(icon: String, color: Color, title: String, detail: String) -> some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.caption)
                .foregroundStyle(.white)
                .frame(width: 28, height: 28)
                .background(color, in: RoundedRectangle(cornerRadius: 7))

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
                .onTapGesture { debugTapCount += 1 }
            Divider().padding(.leading, 52)
            if isProUser {
                aboutRow(icon: "creditcard.fill", color: .blue, title: "Manage Subscription", isLink: true) {
                    if let url = URL(string: "https://apps.apple.com/account/subscriptions") {
                        UIApplication.shared.open(url)
                    }
                }
                Divider().padding(.leading, 52)
            }
            if isProUser {
                aboutRow(icon: "xmark.circle.fill", color: .gray, title: "How to Cancel", isLink: true) {
                    if let url = URL(string: "https://apps.apple.com/account/subscriptions") {
                        UIApplication.shared.open(url)
                    }
                }
                Divider().padding(.leading, 52)
            }
            aboutRow(icon: "arrow.clockwise", color: .teal, title: "Restore Purchases", isLink: true) {
                Task { await storeService.restorePurchases() }
            }
            Divider().padding(.leading, 52)
            Link(destination: URL(string: "https://memori-website-sooty.vercel.app/privacy")!) {
                HStack(spacing: 12) {
                    Image(systemName: "hand.raised.fill")
                        .font(.caption)
                        .foregroundStyle(.white)
                        .frame(width: 28, height: 28)
                        .background(Color.purple, in: RoundedRectangle(cornerRadius: 7))

                    Text("Privacy Policy")
                        .font(.subheadline)
                        .foregroundStyle(.primary)

                    Spacer()

                    Image(systemName: "arrow.up.right")
                        .font(.caption2.weight(.semibold))
                        .foregroundStyle(.tertiary)
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 13)
            }
            Divider().padding(.leading, 52)
            Link(destination: URL(string: "https://memori-website-sooty.vercel.app/terms")!) {
                HStack(spacing: 12) {
                    Image(systemName: "doc.text.fill")
                        .font(.caption)
                        .foregroundStyle(.white)
                        .frame(width: 28, height: 28)
                        .background(Color.gray, in: RoundedRectangle(cornerRadius: 7))

                    Text("Terms of Use")
                        .font(.subheadline)
                        .foregroundStyle(.primary)

                    Spacer()

                    Image(systemName: "arrow.up.right")
                        .font(.caption2.weight(.semibold))
                        .foregroundStyle(.tertiary)
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 13)
            }
            Divider().padding(.leading, 52)
            Button {
                if let url = URL(string: "itms-apps://itunes.apple.com/app/id6760178716") {
                    UIApplication.shared.open(url)
                }
            } label: {
                HStack(spacing: 12) {
                    Image(systemName: "star.fill")
                        .font(.caption)
                        .foregroundStyle(.white)
                        .frame(width: 28, height: 28)
                        .background(Color.orange, in: RoundedRectangle(cornerRadius: 7))

                    Text("Rate Memori")
                        .font(.subheadline)
                        .foregroundStyle(.primary)

                    Spacer()

                    Image(systemName: "arrow.up.right")
                        .font(.caption2.weight(.semibold))
                        .foregroundStyle(.tertiary)
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 13)
            }
            .buttonStyle(.plain)
            Divider().padding(.leading, 52)
            Link(destination: URL(string: "https://memori-website-sooty.vercel.app/privacy")!) {
                HStack(spacing: 12) {
                    Image(systemName: "questionmark.circle.fill")
                        .font(.caption)
                        .foregroundStyle(.white)
                        .frame(width: 28, height: 28)
                        .background(Color.blue, in: RoundedRectangle(cornerRadius: 7))

                    Text("Support")
                        .font(.subheadline)
                        .foregroundStyle(.primary)

                    Spacer()

                    Image(systemName: "arrow.up.right")
                        .font(.caption2.weight(.semibold))
                        .foregroundStyle(.tertiary)
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 13)
            }
            Divider().padding(.leading, 52)
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
                    .frame(width: 28, height: 28)
                    .background(color, in: RoundedRectangle(cornerRadius: 7))

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
            .padding(.vertical, 13)
        }
        .buttonStyle(.plain)
        .disabled(action == nil)
    }

    // MARK: - Setting Icon Helper

    private func settingIcon(_ name: String, color: Color) -> some View {
        Image(systemName: name)
            .font(.system(size: 12, weight: .semibold))
            .foregroundStyle(color)
            .frame(width: 28, height: 28)
            .background(color.opacity(0.10), in: RoundedRectangle(cornerRadius: 7))
    }

    // MARK: - Debug (hidden behind 7-tap on version)

    @ViewBuilder
    private var debugCard: some View {
        if debugTapCount >= 7 {
            debugCardContent
        }
    }

    private var debugCardContent: some View {
        VStack(alignment: .leading, spacing: 14) {
            SectionHeader(title: "Debug")

            // Pro toggle
            HStack(spacing: 12) {
                Image(systemName: "star.fill")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(.white)
                    .frame(width: 28, height: 28)
                    .background(AppColors.amber, in: RoundedRectangle(cornerRadius: 7))

                VStack(alignment: .leading, spacing: 2) {
                    Text("Debug Pro Mode")
                        .font(.subheadline.weight(.medium))
                        .foregroundStyle(.primary)
                    Text(storeService.isProUser ? "Pro ON — tap to disable" : "Pro OFF — tap to enable")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Spacer()

                Circle()
                    .fill(storeService.isProUser ? Color.green : Color.gray.opacity(0.3))
                    .frame(width: 12, height: 12)
            }
            .contentShape(Rectangle())
            .onTapGesture {
                storeService.isProUser.toggle()
            }

            // Reset daily limit
            HStack(spacing: 12) {
                Image(systemName: "arrow.counterclockwise")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(.white)
                    .frame(width: 28, height: 28)
                    .background(AppColors.coral, in: RoundedRectangle(cornerRadius: 7))

                VStack(alignment: .leading, spacing: 2) {
                    Text("Reset Daily Limit")
                        .font(.subheadline.weight(.medium))
                        .foregroundStyle(.primary)
                    Text("Resets the 3/day exercise counter")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Spacer()
            }
            .contentShape(Rectangle())
            .onTapGesture {
                UserDefaults.standard.removeObject(forKey: "daily_exercise_count")
                UserDefaults.standard.removeObject(forKey: "daily_exercise_date")
            }

            // Load screenshot data
            Button {
                showingScreenshotDataConfirmation = true
            } label: {
                HStack(spacing: 12) {
                    Image(systemName: "camera.fill")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(.white)
                        .frame(width: 28, height: 28)
                        .background(AppColors.accent, in: RoundedRectangle(cornerRadius: 7))

                    VStack(alignment: .leading, spacing: 2) {
                        Text("Load Screenshot Data")
                            .font(.subheadline.weight(.medium))
                            .foregroundStyle(.primary)
                        Text("Fills app with demo data for App Store screenshots")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }

                    Spacer()

                    if screenshotDataLoaded {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundStyle(.green)
                    } else {
                        Image(systemName: "chevron.right")
                            .font(.caption2.weight(.semibold))
                            .foregroundStyle(.tertiary)
                    }
                }
            }
            .buttonStyle(.plain)
        }
        .appCard()
        .overlay(
            RoundedRectangle(cornerRadius: 14)
                .stroke(AppColors.accent.opacity(0.3), lineWidth: 1)
        )
    }

    private func loadScreenshotData() {
        #if DEBUG
        guard let user else { return }
        ScreenshotDataGenerator.generate(modelContext: modelContext, user: user, gameCenterService: gameCenterService)
        screenshotDataLoaded = true
        #endif
    }

    // MARK: - Reset

    private func resetAllData() {
        do {
            try modelContext.delete(model: Exercise.self)
            try modelContext.delete(model: SpacedRepetitionCard.self)
            try modelContext.delete(model: DailySession.self)
            try modelContext.delete(model: BrainScoreResult.self)
            try modelContext.delete(model: Achievement.self)
            if let user {
                user.currentStreak = 0
                user.longestStreak = 0
                user.lastSessionDate = nil
                user.streakFreezes = 1
                user.streakFreezeUsedDate = nil
                user.streakFreezeLastAwardDate = nil
                user.totalXP = 0
                user.level = 1
                user.totalExercises = 0
                user.totalPerfectScores = 0
            }
            NotificationService.shared.cancelAll()
        } catch {
            // Silent fail — data will be inconsistent but app won't crash
        }
    }
}
