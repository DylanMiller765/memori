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
    @State private var showingDebugBrainAge = false
    @State private var showingDebugAssessment = false
    @State private var showingDebugGoodBrainAge = false
    @State private var showingDebugBadBrainAge = false
    @State private var editingName = false
    @State private var editedName = ""
    @State private var showingAgePicker = false

    private var user: User? { users.first }
    private var isProUser: Bool { storeService.isProUser }
    private var latestScore: BrainScoreResult? { brainScores.first }

    private var profileMascotMood: MascotRiveMood {
        guard let lastSession = user?.lastSessionDate else { return .neutral }
        if Calendar.current.isDateInToday(lastSession) {
            return .happy
        } else if Calendar.current.isDateInYesterday(lastSession) {
            return .neutral
        } else {
            return .sad
        }
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    // 1. Player Card Hero
                    playerCardHero

                    // 2. Stats Grid
                    statsGrid

                    // 2.5 Referral Stats
                    referralCard

                    // 3. Achievements Preview
                    achievementsPreview

                    // 4. Pro Card
                    proCard

                    // 5. Settings Section
                    settingsCard

                    // 6. About/Legal Section
                    aboutCard

                    // 7. Reset Data (standalone red button)
                    resetDataButton

                    // Debug (7-tap easter egg)
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
            .fullScreenCover(isPresented: $showingDebugBrainAge) {
                NavigationStack {
                    debugBrainAgeReveal
                        .toolbar {
                            ToolbarItem(placement: .topBarLeading) {
                                Button { showingDebugBrainAge = false } label: {
                                    Image(systemName: "xmark.circle.fill")
                                        .font(.title3)
                                        .foregroundStyle(.secondary)
                                }
                            }
                        }
                }
            }
            .fullScreenCover(isPresented: $showingDebugAssessment) {
                NavigationStack {
                    BrainAssessmentView()
                        .toolbar {
                            ToolbarItem(placement: .topBarLeading) {
                                Button { showingDebugAssessment = false } label: {
                                    Image(systemName: "xmark.circle.fill")
                                        .font(.title3)
                                        .foregroundStyle(.secondary)
                                }
                            }
                        }
                }
            }
            .fullScreenCover(isPresented: $showingDebugGoodBrainAge) {
                NavigationStack {
                    debugGoodBrainAgeReveal
                        .toolbar {
                            ToolbarItem(placement: .topBarLeading) {
                                Button { showingDebugGoodBrainAge = false } label: {
                                    Image(systemName: "xmark.circle.fill")
                                        .font(.title3)
                                        .foregroundStyle(.secondary)
                                }
                            }
                        }
                }
            }
            .fullScreenCover(isPresented: $showingDebugBadBrainAge) {
                NavigationStack {
                    debugBadBrainAgeReveal
                        .toolbar {
                            ToolbarItem(placement: .topBarLeading) {
                                Button { showingDebugBadBrainAge = false } label: {
                                    Image(systemName: "xmark.circle.fill")
                                        .font(.title3)
                                        .foregroundStyle(.secondary)
                                }
                            }
                        }
                }
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

    // MARK: - 1. Player Card Hero

    private var playerCardHero: some View {
        VStack(spacing: 8) {
            // Compact mascot
            RiveMascotView(
                mood: profileMascotMood,
                size: 100
            )
            .frame(height: 90)
            .clipped()

            // Name + level
            VStack(spacing: 4) {
                HStack(spacing: 8) {
                    Text(user?.username.isEmpty == false ? user!.username : "Player")
                        .font(.title2.weight(.bold))
                    if isProUser {
                        Text("PRO")
                            .font(.system(size: 9, weight: .black))
                            .foregroundStyle(.white)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 3)
                            .background(
                                LinearGradient(colors: [AppColors.amber, AppColors.coral], startPoint: .leading, endPoint: .trailing),
                                in: Capsule()
                            )
                    }
                }
                Text("Level \(user?.level ?? 1) · \(user?.levelName ?? "")")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }

            // XP bar
            VStack(spacing: 4) {
                ProgressView(value: Double(user?.totalXP ?? 0) / Double(max(1, user?.xpForNextLevel ?? 100)))
                    .tint(AppColors.accent)
                Text("\(user?.totalXP ?? 0) / \(user?.xpForNextLevel ?? 100) XP")
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
            }
            .padding(.horizontal, 40)
        }
        .padding(.vertical, 20)
        .frame(maxWidth: .infinity)
        .appCard()
    }

    // MARK: - 2. Stats Grid

    private var statsGrid: some View {
        HStack(spacing: 12) {
            statCard(value: "\(user?.totalExercises ?? 0)", label: "Games", icon: "gamecontroller.fill", color: AppColors.accent)
            statCard(value: formatTotalTime(), label: "Trained", icon: "clock.fill", color: AppColors.teal)
            statCard(value: "\(achievements.count)", label: "Awards", icon: "trophy.fill", color: AppColors.amber)
        }
    }

    private func statCard(value: String, label: String, icon: String, color: Color) -> some View {
        VStack(spacing: 6) {
            Image(systemName: icon)
                .font(.system(size: 16))
                .foregroundStyle(color)
            Text(value)
                .font(.system(size: 20, weight: .bold, design: .rounded))
            Text(label)
                .font(.caption2.weight(.medium))
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 12)
        .background(AppColors.cardSurface, in: RoundedRectangle(cornerRadius: 12))
        .overlay(RoundedRectangle(cornerRadius: 12).stroke(AppColors.cardBorder, lineWidth: 1))
    }

    // MARK: - 2.5 Referral Card

    private var referralCard: some View {
        let service = ReferralService()
        let count = service.referralCount
        let daysLeft = service.trialDaysRemaining

        return VStack(spacing: 8) {
            ReferralBannerView()

            if count > 0 || daysLeft > 0 {
                HStack {
                    if count > 0 {
                        Label("\(count) friend\(count == 1 ? "" : "s") invited", systemImage: "person.2.fill")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    Spacer()
                    if daysLeft > 0 {
                        Text("\(daysLeft)d Pro remaining")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(AppColors.teal)
                    }
                }
                .padding(.horizontal, 4)
            }
        }
    }

    private func formatTotalTime() -> String {
        let totalSeconds = sessions.reduce(0) { $0 + $1.durationSeconds }
        let totalMinutes = totalSeconds / 60
        if totalMinutes < 60 { return "\(totalMinutes)m" }
        let hours = totalMinutes / 60
        return "\(hours)h"
    }

    // MARK: - 3. Achievements Preview

    private var achievementsPreview: some View {
        NavigationLink(destination: AchievementsView()) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Achievements")
                        .font(.headline.weight(.bold))
                    Text("\(achievements.count) of \(AchievementType.allCases.count) unlocked")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.tertiary)
            }
            .padding(16)
            .background(AppColors.cardSurface, in: RoundedRectangle(cornerRadius: 14))
            .overlay(RoundedRectangle(cornerRadius: 14).stroke(AppColors.cardBorder, lineWidth: 1))
        }
        .buttonStyle(.plain)
    }

    // MARK: - 4. Pro Card

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
            }
        }
    }

    // MARK: - 5. Settings Section

    private var settingsCard: some View {
        VStack(spacing: 0) {
            // Name
            settingsRow(icon: "person.fill", color: AppColors.accent, title: "Name") {
                if editingName {
                    TextField("Your name", text: $editedName)
                        .font(.subheadline)
                        .multilineTextAlignment(.trailing)
                        .submitLabel(.done)
                        .onSubmit {
                            user?.username = editedName.trimmingCharacters(in: .whitespacesAndNewlines)
                            editingName = false
                        }
                } else {
                    Button {
                        editedName = user?.username ?? ""
                        editingName = true
                    } label: {
                        Text(user?.username.isEmpty == false ? user!.username : "Not set")
                            .font(.subheadline)
                            .foregroundStyle(user?.username.isEmpty == false ? .primary : .secondary)
                    }
                }
            }
            Divider().padding(.leading, 44)

            // Notifications
            settingsRow(icon: "bell.fill", color: AppColors.coral, title: "Notifications") {
                if let user {
                    Toggle("", isOn: Binding(
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
                    ))
                    .tint(AppColors.accent)
                    .labelsHidden()
                }
            }
            Divider().padding(.leading, 44)

            // Appearance
            settingsRow(icon: "circle.lefthalf.filled", color: AppColors.violet, title: "Appearance") {
                Picker("", selection: $appTheme) {
                    ForEach(AppTheme.allCases, id: \.rawValue) { theme in
                        Text(theme.displayName).tag(theme.rawValue)
                    }
                }
                .pickerStyle(.menu)
                .labelsHidden()
            }
            Divider().padding(.leading, 44)

            // Sounds
            settingsRow(icon: "speaker.wave.2.fill", color: AppColors.teal, title: "Sounds") {
                if let user {
                    Toggle("", isOn: Binding(
                        get: { user.soundEnabled },
                        set: { user.soundEnabled = $0 }
                    ))
                    .tint(AppColors.accent)
                    .labelsHidden()
                }
            }
            Divider().padding(.leading, 44)

            // Daily Goal
            settingsRow(icon: "target", color: AppColors.amber, title: "Daily Goal") {
                if let user {
                    Stepper("\(user.dailyGoal) games", value: Binding(
                        get: { user.dailyGoal },
                        set: { user.dailyGoal = $0 }
                    ), in: 1...10)
                    .font(.subheadline)
                }
            }
            Divider().padding(.leading, 44)

            // Your Age
            Button {
                showingAgePicker = true
            } label: {
                settingsRow(icon: "birthday.cake.fill", color: AppColors.coral, title: "Your Age") {
                    HStack(spacing: 4) {
                        Text(user?.userAge ?? 0 > 0 ? "\(user!.userAge)" : "Not set")
                            .font(.subheadline)
                            .foregroundStyle(user?.userAge ?? 0 > 0 ? .primary : .secondary)
                        Image(systemName: "chevron.right")
                            .font(.caption2.weight(.semibold))
                            .foregroundStyle(.tertiary)
                    }
                }
            }
            .buttonStyle(.plain)
        }
        .appCard(padding: 0)
        .sheet(isPresented: $showingAgePicker) {
            NavigationStack {
                VStack(spacing: 16) {
                    Text("Select your age")
                        .font(.headline)

                    if let user {
                        Picker("Age", selection: Binding(
                            get: { user.userAge > 0 ? user.userAge : 25 },
                            set: { user.userAge = $0 }
                        )) {
                            ForEach(18...99, id: \.self) { age in
                                Text("\(age)").tag(age)
                            }
                        }
                        .pickerStyle(.wheel)
                        .frame(height: 150)
                    }

                    HStack(spacing: 6) {
                        Image(systemName: "lock.fill")
                            .font(.caption2)
                        Text("Stored on your device only. Never shared.")
                            .font(.caption)
                    }
                    .foregroundStyle(.secondary)
                }
                .padding()
                .toolbar {
                    ToolbarItem(placement: .confirmationAction) {
                        Button("Done") { showingAgePicker = false }
                    }
                    ToolbarItem(placement: .cancellationAction) {
                        Button("Remove") {
                            user?.userAge = 0
                            showingAgePicker = false
                        }
                        .foregroundStyle(.red)
                    }
                }
            }
            .presentationDetents([.medium])
        }
    }

    private func settingsRow<Trailing: View>(icon: String, color: Color, title: String, @ViewBuilder trailing: () -> Trailing) -> some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(.white)
                .frame(width: 28, height: 28)
                .background(color, in: RoundedRectangle(cornerRadius: 7))

            Text(title)
                .font(.subheadline)

            Spacer()

            trailing()
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 13)
    }

    // MARK: - 6. About/Legal Section

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
            Link(destination: URL(string: "https://getmemoriapp.com/privacy")!) {
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
            Link(destination: URL(string: "https://getmemoriapp.com/terms")!) {
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
            Link(destination: URL(string: "mailto:dylanjaws@icloud.com")!) {
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
                    .foregroundStyle(.primary)

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

    // MARK: - 7. Reset Data Button

    private var resetDataButton: some View {
        Button {
            showingResetConfirmation = true
        } label: {
            Text("Reset All Data")
                .font(.subheadline.weight(.medium))
                .foregroundStyle(.red)
        }
        .padding(.top, 8)
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

            // Jump to Brain Age Reveal
            debugRow(icon: "brain.head.profile.fill", color: AppColors.violet, title: "Brain Age Reveal", subtitle: "Jump directly to score reveal screen") {
                showingDebugBrainAge = true
            }

            // Good Brain Age (25)
            debugRow(icon: "brain.head.profile.fill", color: AppColors.teal, title: "Good Brain Age (25)", subtitle: "Score 820 · Age 25 · 90th percentile") {
                showingDebugGoodBrainAge = true
            }

            // Bad Brain Age (67)
            debugRow(icon: "brain.head.profile.fill", color: AppColors.coral, title: "Bad Brain Age (67)", subtitle: "Score 180 · Age 67 · 12th percentile") {
                showingDebugBadBrainAge = true
            }

            // Jump to assessment
            debugRow(icon: "list.clipboard.fill", color: AppColors.teal, title: "Start Assessment", subtitle: "Skip to brain assessment flow") {
                showingDebugAssessment = true
            }

            // Reset onboarding
            debugRow(icon: "arrow.counterclockwise.circle.fill", color: .orange, title: "Reset Onboarding", subtitle: "Re-show onboarding on next launch") {
                if let user {
                    user.hasCompletedOnboarding = false
                }
            }

            // Set mascot mood
            debugRow(icon: "face.smiling.fill", color: AppColors.teal, title: "Memo Happy", subtitle: "Add 3 exercises today") {
                if let user {
                    user.lastSessionDate = Date()
                    for _ in 0..<3 {
                        let ex = Exercise(type: .reactionTime, difficulty: 1, score: 50, durationSeconds: 30)
                        modelContext.insert(ex)
                    }
                }
            }

            debugRow(icon: "face.smiling.inverse", color: AppColors.amber, title: "Memo Neutral", subtitle: "Clear today's exercises") {
                if let user {
                    user.lastSessionDate = Calendar.current.date(byAdding: .day, value: -1, to: Date())
                }
                // Delete today's exercises so todayExerciseCount = 0
                let startOfDay = Calendar.current.startOfDay(for: Date())
                let descriptor = FetchDescriptor<Exercise>(predicate: #Predicate { $0.completedAt >= startOfDay })
                if let todayExercises = try? modelContext.fetch(descriptor) {
                    for ex in todayExercises { modelContext.delete(ex) }
                }
            }

            debugRow(icon: "face.dashed.fill", color: AppColors.coral, title: "Memo Sad", subtitle: "Clear exercises + set 3 days ago") {
                if let user {
                    user.lastSessionDate = Calendar.current.date(byAdding: .day, value: -3, to: Date())
                }
                let startOfDay = Calendar.current.startOfDay(for: Date())
                let descriptor = FetchDescriptor<Exercise>(predicate: #Predicate { $0.completedAt >= startOfDay })
                if let todayExercises = try? modelContext.fetch(descriptor) {
                    for ex in todayExercises { modelContext.delete(ex) }
                }
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

    // Debug row helper
    private func debugRow(icon: String, color: Color, title: String, subtitle: String, action: @escaping () -> Void) -> some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(.white)
                .frame(width: 28, height: 28)
                .background(color, in: RoundedRectangle(cornerRadius: 7))

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.subheadline.weight(.medium))
                Text(subtitle)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            Image(systemName: "chevron.right")
                .font(.caption2.weight(.semibold))
                .foregroundStyle(.tertiary)
        }
        .contentShape(Rectangle())
        .onTapGesture { action() }
    }

    // Debug Brain Age Reveal — skips assessment, shows reveal directly
    private var debugBrainAgeReveal: some View {
        let vm = BrainAssessmentViewModel()
        let _ = {
            vm.brainScore = 420
            vm.brainAge = 35
            vm.brainType = .balancedBrain
            vm.percentile = 62
            vm.digitScore = 55
            vm.reactionScore = 48
            vm.visualScore = 65
        }()
        return ScoreRevealView(
            viewModel: vm,
            previousScore: brainScores.first,
            userAge: user?.userAge ?? 25,
            onDone: { showingDebugBrainAge = false }
        )
    }

    // Debug Good Brain Age Reveal — brain age 25, score 820
    private var debugGoodBrainAgeReveal: some View {
        let vm = BrainAssessmentViewModel()
        let _ = {
            vm.brainScore = 820
            vm.brainAge = 25
            vm.brainType = .balancedBrain
            vm.percentile = 90
            vm.digitScore = 85
            vm.reactionScore = 78
            vm.visualScore = 90
            vm.digitMaxCorrect = 9
            vm.avgReactionMs = 220
            vm.visualMaxCorrect = 7
        }()
        return ScoreRevealView(
            viewModel: vm,
            previousScore: brainScores.first,
            userAge: user?.userAge ?? 25,
            onDone: { showingDebugGoodBrainAge = false }
        )
    }

    // Debug Bad Brain Age Reveal — brain age 67, score 180
    private var debugBadBrainAgeReveal: some View {
        let vm = BrainAssessmentViewModel()
        let _ = {
            vm.brainScore = 180
            vm.brainAge = 67
            vm.brainType = .lightningReflex
            vm.percentile = 12
            vm.digitScore = 25
            vm.reactionScore = 35
            vm.visualScore = 20
            vm.digitMaxCorrect = 5
            vm.avgReactionMs = 380
            vm.visualMaxCorrect = 3
        }()
        return ScoreRevealView(
            viewModel: vm,
            previousScore: brainScores.first,
            userAge: user?.userAge ?? 25,
            onDone: { showingDebugBadBrainAge = false }
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
