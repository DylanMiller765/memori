import SwiftUI
import SwiftData
import Charts

struct ProgressDashboardView: View {
    @Environment(StoreService.self) private var storeService
    @Query private var users: [User]
    @Query(sort: \DailySession.date, order: .reverse) private var sessions: [DailySession]
    @Query(sort: \BrainScoreResult.date, order: .reverse) private var brainScores: [BrainScoreResult]
    @Query private var achievements: [Achievement]

    @State private var viewModel = ProgressViewModel()
    @State private var showingPaywall = false
    @Query(sort: \Exercise.completedAt, order: .reverse) private var exercises: [Exercise]

    private var user: User? { users.first }
    private var isProUser: Bool { storeService.isProUser || (user?.isProUser ?? false) }

    /// The 8 games available on the Train tab
    private static let availableGames: [ExerciseType] = [
        .reactionTime, .colorMatch, .speedMatch, .visualMemory,
        .sequentialMemory, .mathSpeed, .dualNBack, .chunkingTraining
    ]

    private var triedExerciseTypes: Set<ExerciseType> {
        Set(exercises.map(\.type)).intersection(Self.availableGames)
    }

    private var consistencyPercent: Int {
        let calendar = Calendar.current
        let now = Date.now
        guard let monthStart = calendar.date(from: calendar.dateComponents([.year, .month], from: now)) else { return 0 }
        let dayOfMonth = calendar.component(.day, from: now)
        let daysTrainedThisMonth = viewModel.trainingDays.filter { $0 >= monthStart }.count
        guard dayOfMonth > 0 else { return 0 }
        return Int(Double(daysTrainedThisMonth) / Double(dayOfMonth) * 100)
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                if sessions.isEmpty && brainScores.isEmpty {
                    emptyState
                } else {
                    VStack(spacing: 24) {
                        if let latestScore = brainScores.first {
                            brainScoreProgressCard(latestScore)
                        }

                        // Brain Score History Chart
                        if brainScores.count >= 2 {
                            VStack(alignment: .leading, spacing: 12) {
                                SectionHeader(title: "Brain Score History")
                                BrainScoreChart(scores: brainScores, height: 200, showHeader: false)
                            }
                            .appCard()
                        }

                        // Level & XP Card
                        if let user {
                            levelProgressCard(user)
                        }

                        streakSection
                        calendarHeatmap

                        // NEW: Consistency + Exercise Library
                        consistencyAndLibrary

                        // NEW: Personal Records (free)
                        personalRecordsSection

                        // Achievements summary
                        achievementsSummary

                        if isProUser {
                            exerciseScoreTrends
                            scoreChart
                        } else {
                            proUpsell
                        }
                    }
                    .padding(.horizontal)
                    .padding(.top, 8)
                    .padding(.bottom, 32)
                    .responsiveContent()
                    .frame(maxWidth: .infinity)
                }
            }
            .pageBackground()
            .navigationTitle("Insights")
            .onAppear { viewModel.refresh(sessions: sessions) }
            .sheet(isPresented: $showingPaywall) {
                PaywallView()
            }
        }
    }

    // MARK: - Empty State

    private var emptyState: some View {
        VStack(spacing: 20) {
            Spacer()
                .frame(height: 40)

            // Mini illustration: faded placeholder chart bars
            HStack(alignment: .bottom, spacing: 6) {
                ForEach([0.3, 0.5, 0.25, 0.65, 0.4, 0.55, 0.35], id: \.self) { height in
                    RoundedRectangle(cornerRadius: 4)
                        .fill(AppColors.cardBorder.opacity(0.5))
                        .frame(width: 18, height: 60 * height)
                }
            }
            .frame(height: 60)
            .padding(.bottom, 4)

            Text("No Progress Yet")
                .font(.title3.weight(.semibold))

            Text("Complete your first exercise to see your progress here")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)

            Spacer()
                .frame(height: 20)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 20)
        .appCard()
        .padding(.horizontal)
        .padding(.top, 8)
    }

    // MARK: - Brain Score Progress Card

    private func brainScoreProgressCard(_ score: BrainScoreResult) -> some View {
        BrainScoreCard(score: score, compact: false)
            .heroCard(color: AppColors.accent)
    }

    // MARK: - Level Progress Card

    private func levelProgressCard(_ user: User) -> some View {
        HStack(spacing: 14) {
            ZStack {
                Circle()
                    .fill(AppColors.cardBorder)
                    .frame(width: 68, height: 68)
                Circle()
                    .fill(AppColors.accent)
                    .frame(width: 52, height: 52)

                Text("\(user.level)")
                    .font(.title2.weight(.bold).monospacedDigit())
                    .foregroundStyle(.white)
            }

            VStack(alignment: .leading, spacing: 6) {
                Text(user.levelName)
                    .font(.subheadline.weight(.bold))

                GeometryReader { geo in
                    ZStack(alignment: .leading) {
                        RoundedRectangle(cornerRadius: 4)
                            .fill(AppColors.accent.opacity(0.15))
                            .frame(height: 8)

                        RoundedRectangle(cornerRadius: 4)
                            .fill(AppColors.accent)
                            .frame(width: max(4, geo.size.width * user.xpProgress), height: 8)
                    }
                }
                .frame(height: 8)

                HStack {
                    Text("\(user.totalXP) XP")
                        .font(.caption.weight(.medium))
                        .foregroundStyle(AppColors.accent)
                    Spacer()
                    Text("\(Int(user.xpProgress * 100))%")
                        .font(.system(size: 12, weight: .bold, design: .rounded))
                        .foregroundStyle(AppColors.accent)
                }
            }
        }
        .appCard()
    }

    // MARK: - Achievements Summary

    private var achievementsSummary: some View {
        NavigationLink {
            AchievementsView()
        } label: {
            HStack(spacing: 12) {
                ColoredIconBadge(icon: "medal.fill", color: AppColors.violet, size: 40)

                VStack(alignment: .leading, spacing: 2) {
                    Text("Achievements")
                        .font(.subheadline.weight(.semibold))
                    Text("\(achievements.count) of \(AchievementType.allCases.count) unlocked")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Spacer()

                // Mini progress
                Text("\(Int(Double(achievements.count) / Double(AchievementType.allCases.count) * 100))%")
                    .font(.headline.weight(.bold))
                    .foregroundStyle(AppColors.violet)

                Image(systemName: "chevron.right")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.tertiary)
            }
            .appCard()
        }
        .buttonStyle(.plain)
    }

    // MARK: - Streak Section

    private var streakSection: some View {
        HStack(spacing: 10) {
            streakMiniCard(
                value: "\(user?.currentStreak ?? 0)",
                unit: "streak",
                icon: "flame.fill",
                color: AppColors.coral,
                detail: "Best: \(user?.longestStreak ?? 0)"
            )
            streakMiniCard(
                value: "\(sessions.count)",
                unit: "sessions",
                icon: "brain.head.profile",
                color: AppColors.indigo
            )
            let totalMins = sessions.reduce(0) { $0 + $1.durationSeconds } / 60
            streakMiniCard(
                value: totalMins > 60 ? "\(totalMins / 60)h" : "\(totalMins)m",
                unit: "trained",
                icon: "clock.fill",
                color: AppColors.teal
            )
        }
    }

    private func streakMiniCard(value: String, unit: String, icon: String, color: Color, detail: String? = nil) -> some View {
        VStack(spacing: 6) {
            ZStack {
                Circle()
                    .fill(color.opacity(0.12))
                    .frame(width: 36, height: 36)
                Image(systemName: icon)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(color)
            }

            Text(value)
                .font(.system(size: 28, weight: .bold, design: .rounded))
                .foregroundStyle(AppColors.textPrimary)
                .frame(height: 34)

            Text(unit)
                .font(.system(size: 10, weight: .semibold))
                .foregroundStyle(AppColors.textTertiary)
                .textCase(.uppercase)
                .tracking(0.5)

            if let detail {
                Text(detail)
                    .font(.system(size: 10, weight: .medium))
                    .foregroundStyle(AppColors.textTertiary)
            } else {
                Text(" ")
                    .font(.system(size: 10, weight: .medium))
                    .foregroundStyle(.clear)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 14)
        .background {
            RoundedRectangle(cornerRadius: 14)
                .fill(AppColors.cardSurface)
                .shadow(color: .black.opacity(0.05), radius: 6, y: 2)
        }
        .overlay(alignment: .top) {
            RoundedRectangle(cornerRadius: 14)
                .fill(color)
                .frame(height: 3)
                .padding(.horizontal, 12)
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(unit): \(value)")
    }

    // MARK: - Calendar Heatmap

    private var calendarHeatmap: some View {
        HeatmapCalendarView(trainingDays: viewModel.trainingDays)
            .appCard()
    }

    // MARK: - Consistency + Exercise Library

    private var consistencyAndLibrary: some View {
        HStack(spacing: 10) {
            // Consistency Score
            VStack(spacing: 10) {
                ZStack {
                    Circle()
                        .stroke(AppColors.cardBorder, lineWidth: 6)
                        .frame(width: 56, height: 56)
                    Circle()
                        .trim(from: 0, to: CGFloat(consistencyPercent) / 100.0)
                        .stroke(AppColors.teal, style: StrokeStyle(lineWidth: 6, lineCap: .round))
                        .frame(width: 56, height: 56)
                        .rotationEffect(.degrees(-90))
                    Text("\(consistencyPercent)%")
                        .font(.system(size: 14, weight: .bold, design: .rounded))
                }
                Text("Consistency")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(AppColors.textTertiary)
                Text("this month")
                    .font(.system(size: 9))
                    .foregroundStyle(.tertiary)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 14)
            .background {
                RoundedRectangle(cornerRadius: 14)
                    .fill(AppColors.cardSurface)
                    .shadow(color: .black.opacity(0.05), radius: 6, y: 2)
            }
            .accessibilityElement(children: .combine)
            .accessibilityLabel("Consistency: \(consistencyPercent) percent this month")

            // Exercise Library Progress
            VStack(spacing: 10) {
                ZStack {
                    Circle()
                        .stroke(AppColors.cardBorder, lineWidth: 6)
                        .frame(width: 56, height: 56)
                    Circle()
                        .trim(from: 0, to: CGFloat(triedExerciseTypes.count) / CGFloat(Self.availableGames.count))
                        .stroke(AppColors.indigo, style: StrokeStyle(lineWidth: 6, lineCap: .round))
                        .frame(width: 56, height: 56)
                        .rotationEffect(.degrees(-90))
                    Text("\(triedExerciseTypes.count)/\(Self.availableGames.count)")
                        .font(.system(size: 14, weight: .bold, design: .rounded))
                }
                Text("Games Tried")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(AppColors.textTertiary)
                Text("keep exploring!")
                    .font(.system(size: 9))
                    .foregroundStyle(.tertiary)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 14)
            .background {
                RoundedRectangle(cornerRadius: 14)
                    .fill(AppColors.cardSurface)
                    .shadow(color: .black.opacity(0.05), radius: 6, y: 2)
            }
            .accessibilityElement(children: .combine)
            .accessibilityLabel("\(triedExerciseTypes.count) of \(Self.availableGames.count) games tried")
        }
    }

    // MARK: - Personal Records

    private var personalRecordsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            SectionHeader(title: "Personal Records")

            let records = Self.availableGames.compactMap { type -> (type: ExerciseType, best: Int)? in
                let best = PersonalBestTracker.shared.best(for: type)
                guard best > 0 else { return nil }
                return (type: type, best: best)
            }

            if records.isEmpty {
                VStack(spacing: 12) {
                    Image(systemName: "trophy")
                        .font(.system(size: 32))
                        .foregroundStyle(AppColors.amber.opacity(0.4))
                    Text("No records yet")
                        .font(.subheadline.weight(.semibold))
                    Text("Play some games to set your first records!")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 24)
                .background {
                    RoundedRectangle(cornerRadius: 14)
                        .fill(AppColors.cardSurface)
                        .shadow(color: .black.opacity(0.05), radius: 6, y: 2)
                }
            } else {
                VStack(spacing: 0) {
                    ForEach(Array(records.enumerated()), id: \.offset) { index, record in
                        HStack(spacing: 12) {
                            Image(systemName: record.type.icon)
                                .font(.system(size: 14, weight: .semibold))
                                .foregroundStyle(.white)
                                .frame(width: 32, height: 32)
                                .background(exerciseColor(record.type), in: RoundedRectangle(cornerRadius: 8))

                            Text(record.type.displayName)
                                .font(.subheadline.weight(.medium))

                            Spacer()

                            Text(personalBestDisplay(type: record.type, value: record.best))
                                .font(.subheadline.weight(.bold).monospacedDigit())
                                .foregroundStyle(exerciseColor(record.type))

                            Image(systemName: "trophy.fill")
                                .font(.system(size: 10))
                                .foregroundStyle(AppColors.amber)
                        }
                        .padding(.vertical, 10)
                        .padding(.horizontal, 14)

                        if index < records.count - 1 {
                            Divider().padding(.leading, 58)
                        }
                    }
                }
                .background {
                    RoundedRectangle(cornerRadius: 14)
                        .fill(AppColors.cardSurface)
                        .shadow(color: .black.opacity(0.05), radius: 6, y: 2)
                }
            }
        }
    }

    private func personalBestDisplay(type: ExerciseType, value: Int) -> String {
        switch type {
        case .reactionTime: return "\(1000 - value)ms"
        case .dualNBack: return "N=\(value)"
        case .sequentialMemory: return "\(value) digits"
        case .visualMemory: return "Level \(value)"
        default: return "\(value)"
        }
    }

    private func exerciseColor(_ type: ExerciseType) -> Color {
        switch type {
        case .reactionTime: return AppColors.coral
        case .colorMatch: return AppColors.violet
        case .speedMatch: return AppColors.sky
        case .visualMemory: return AppColors.indigo
        case .sequentialMemory: return AppColors.teal
        case .mathSpeed: return AppColors.amber
        case .dualNBack: return AppColors.sky
        case .chunkingTraining: return AppColors.teal
        default: return AppColors.accent
        }
    }

    // MARK: - Exercise Score Trends (Pro)

    private var exerciseScoreTrends: some View {
        VStack(alignment: .leading, spacing: 12) {
            SectionHeader(title: "Performance by Exercise")

            let recentExercises = exercises.prefix(100)
            let grouped = Dictionary(grouping: recentExercises) { $0.type }
            let matchedGames = Self.availableGames.filter { grouped[$0] != nil }

            if matchedGames.isEmpty {
                VStack(spacing: 12) {
                    Image(systemName: "chart.bar.xaxis")
                        .font(.system(size: 32))
                        .foregroundStyle(AppColors.indigo.opacity(0.4))
                    Text("No performance data yet")
                        .font(.subheadline.weight(.semibold))
                    Text("Complete some exercises to track your performance")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 24)
                .background {
                    RoundedRectangle(cornerRadius: 14)
                        .fill(AppColors.cardSurface)
                        .shadow(color: .black.opacity(0.05), radius: 6, y: 2)
                }
            } else {

            VStack(spacing: 0) {
                ForEach(Array(matchedGames.enumerated()), id: \.element) { index, type in
                    let typeExercises = grouped[type]!.sorted(by: { $0.completedAt < $1.completedAt }).suffix(7)
                    let scores = Array(typeExercises.map(\.score))
                    let avg = scores.isEmpty ? 0.0 : scores.reduce(0, +) / Double(scores.count)
                    let trend = scores.count >= 2 ? (scores.last! - scores.first!) : 0.0

                    HStack(spacing: 12) {
                        Image(systemName: type.icon)
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundStyle(.white)
                            .frame(width: 32, height: 32)
                            .background(exerciseColor(type), in: RoundedRectangle(cornerRadius: 8))

                        VStack(alignment: .leading, spacing: 2) {
                            Text(type.displayName)
                                .font(.subheadline.weight(.medium))
                            Text("\(scores.count) session\(scores.count == 1 ? "" : "s")")
                                .font(.system(size: 10))
                                .foregroundStyle(.tertiary)
                        }

                        Spacer()

                        // Mini sparkline
                        if scores.count >= 2 {
                            miniSparkline(scores: scores, color: exerciseColor(type))
                                .frame(width: 50, height: 20)
                        }

                        VStack(alignment: .trailing, spacing: 2) {
                            Text(avg.percentString)
                                .font(.system(size: 13, weight: .bold, design: .rounded))
                            if trend != 0 {
                                Text("\(trend > 0 ? "+" : "")\(Int(trend * 100))%")
                                    .font(.system(size: 10, weight: .bold))
                                    .foregroundStyle(trend > 0 ? Color.green : AppColors.coral)
                            }
                        }
                    }
                    .padding(.vertical, 10)
                    .padding(.horizontal, 14)

                    if index < matchedGames.count - 1 {
                        Divider().padding(.leading, 58)
                    }
                }
            }
            .background {
                RoundedRectangle(cornerRadius: 14)
                    .fill(AppColors.cardSurface)
                    .shadow(color: .black.opacity(0.05), radius: 6, y: 2)
            }

            } // else
        }
    }

    private func miniSparkline(scores: [Double], color: Color) -> some View {
        GeometryReader { geo in
            let maxVal = max(scores.max() ?? 1, 0.01)
            let minVal = scores.min() ?? 0
            let range = max(maxVal - minVal, 0.01)
            Path { path in
                for (index, score) in scores.enumerated() {
                    let x = geo.size.width * CGFloat(index) / CGFloat(max(scores.count - 1, 1))
                    let y = geo.size.height * (1 - CGFloat((score - minVal) / range))
                    if index == 0 {
                        path.move(to: CGPoint(x: x, y: y))
                    } else {
                        path.addLine(to: CGPoint(x: x, y: y))
                    }
                }
            }
            .stroke(color, style: StrokeStyle(lineWidth: 1.5, lineCap: .round, lineJoin: .round))
        }
    }

    // MARK: - Score Chart (Pro)

    private var scoreChart: some View {
        VStack(alignment: .leading, spacing: 12) {
            SectionHeader(title: "Score Trends")

            if viewModel.weeklyScores.isEmpty {
                VStack(spacing: 12) {
                    Image(systemName: "chart.line.uptrend.xyaxis")
                        .font(.system(size: 32))
                        .foregroundStyle(AppColors.accent.opacity(0.4))
                    Text("No trends yet")
                        .font(.subheadline.weight(.semibold))
                    Text("Complete a few sessions to see your progress over time")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 24)
            } else {
                Chart {
                    ForEach(viewModel.weeklyScores.indices, id: \.self) { index in
                        let item = viewModel.weeklyScores[index]
                        AreaMark(
                            x: .value("Date", item.date),
                            y: .value("Score", item.score)
                        )
                        .foregroundStyle(
                            LinearGradient(
                                colors: [AppColors.accent.opacity(0.3), AppColors.accent.opacity(0.05)],
                                startPoint: .top,
                                endPoint: .bottom
                            )
                        )
                        .interpolationMethod(.catmullRom)

                        LineMark(
                            x: .value("Date", item.date),
                            y: .value("Score", item.score)
                        )
                        .foregroundStyle(AppColors.accent)
                        .interpolationMethod(.catmullRom)
                        .lineStyle(StrokeStyle(lineWidth: 2.5))

                        PointMark(
                            x: .value("Date", item.date),
                            y: .value("Score", item.score)
                        )
                        .foregroundStyle(AppColors.accent)
                        .symbolSize(30)
                    }
                }
                .chartYScale(domain: 0...1)
                .chartXAxis {
                    AxisMarks(values: .automatic(desiredCount: 4)) { value in
                        AxisValueLabel {
                            if let date = value.as(Date.self) {
                                Text(date, format: .dateTime.month(.abbreviated).day())
                                    .font(.caption2)
                            }
                        }
                    }
                }
                .chartYAxis {
                    AxisMarks(values: [0, 0.25, 0.5, 0.75, 1.0]) { value in
                        AxisValueLabel {
                            if let v = value.as(Double.self) {
                                Text(v.percentString)
                                    .font(.caption2)
                            }
                        }
                    }
                }
                .frame(height: 200)
            }
        }
        .appCard()
    }

    // MARK: - Pro Upsell

    private var proUpsell: some View {
        Button {
            showingPaywall = true
        } label: {
            VStack(alignment: .leading, spacing: 12) {
                HStack(spacing: 10) {
                    Image(systemName: "chart.line.uptrend.xyaxis")
                        .font(.title2)
                        .foregroundStyle(.white)

                    VStack(alignment: .leading, spacing: 2) {
                        Text("Unlock Pro Analytics")
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(.white)
                        Text("See where you're improving")
                            .font(.caption)
                            .foregroundStyle(.white.opacity(0.8))
                    }

                    Spacer()

                    Image(systemName: "chevron.right")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.white.opacity(0.6))
                }

                // What you get
                HStack(spacing: 16) {
                    proFeaturePill(icon: "chart.xyaxis.line", text: "Trends")
                    proFeaturePill(icon: "arrow.up.right", text: "+/- Stats")
                    proFeaturePill(icon: "sparkles", text: "Sparklines")
                }
            }
            .padding(16)
            .background(
                AppColors.premiumGradient,
                in: RoundedRectangle(cornerRadius: 12)
            )
        }
        .buttonStyle(.plain)
    }

    private func proFeaturePill(icon: String, text: String) -> some View {
        HStack(spacing: 4) {
            Image(systemName: icon)
                .font(.system(size: 9, weight: .bold))
            Text(text)
                .font(.system(size: 10, weight: .semibold))
        }
        .foregroundStyle(.white.opacity(0.8))
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(.white.opacity(0.15), in: Capsule())
    }
}
