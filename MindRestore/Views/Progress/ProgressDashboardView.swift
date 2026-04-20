import SwiftUI
import SwiftData
import Charts

// MARK: - Time Range

private enum TimeRange: String, CaseIterable {
    case week = "7D"
    case month = "30D"
    case year = "1Y"

    var days: Int {
        switch self {
        case .week: return 7
        case .month: return 30
        case .year: return 365
        }
    }
}

// MARK: - Insights Dashboard

struct ProgressDashboardView: View {
    @Environment(StoreService.self) private var storeService
    @Query private var users: [User]
    @Query(sort: \DailySession.date, order: .reverse) private var sessions: [DailySession]
    @Query(sort: \BrainScoreResult.date, order: .reverse) private var brainScores: [BrainScoreResult]
    @Query private var achievements: [Achievement]
    @Query(sort: \Exercise.completedAt, order: .reverse) private var exercises: [Exercise]

    @State private var selectedRange: TimeRange = .month
    @State private var showingPaywall = false

    private var user: User? { users.first }
    private var isProUser: Bool { storeService.isProUser }

    // MARK: - Filtered Data

    private var cutoffDate: Date {
        Calendar.current.date(byAdding: .day, value: -selectedRange.days, to: Date()) ?? Date()
    }

    private var filteredScores: [BrainScoreResult] {
        brainScores.filter { $0.date >= cutoffDate }
    }

    private var filteredExercises: [Exercise] {
        exercises.filter { $0.completedAt >= cutoffDate }
    }

    /// Current (latest) brain score
    private var currentScore: BrainScoreResult? {
        brainScores.first
    }

    /// Brain score at the start of the selected period (or earliest in range)
    private var periodStartScore: BrainScoreResult? {
        filteredScores.last
    }

    /// Delta: current brain score minus score at start of period
    private var scoreDelta: Int {
        guard let current = currentScore, let start = periodStartScore,
              current.id != start.id else { return 0 }
        return current.brainScore - start.brainScore
    }

    /// Delta for brain age (lower is better)
    private var brainAgeDelta: Int {
        guard let current = currentScore, let start = periodStartScore,
              current.id != start.id else { return 0 }
        return current.brainAge - start.brainAge
    }

    // MARK: - Body

    var body: some View {
        NavigationStack {
            ScrollView {
                if sessions.isEmpty && brainScores.isEmpty {
                    emptyState
                } else {
                    VStack(spacing: 28) {
                        trendlineSection
                        statsTableSection
                        cognitiveDomainsSection

                        if isProUser {
                            personalBestsSection
                            trainingHeatmapSection
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
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    if isProUser {
                        timeRangePicker
                    }
                }
            }
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

            Image("mascot-bored")
                .renderingMode(.original)
                .resizable()
                .scaledToFit()
                .frame(height: 160)

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

    // MARK: - 1. Brain Score Trendline

    private var trendlineSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            // Header label
            Text("BRAIN SCORE \u{00B7} \(selectedRange.rawValue)")
                .font(.system(size: 11, weight: .bold))
                .tracking(2)
                .foregroundStyle(.secondary)
                .textCase(.uppercase)

            // Large score + delta
            if let score = currentScore {
                HStack(alignment: .firstTextBaseline, spacing: 8) {
                    Text("\(score.brainScore)")
                        .font(.system(size: 48, weight: .black, design: .rounded))
                        .foregroundStyle(.primary)

                    if isProUser, scoreDelta != 0 {
                        deltaLabel(value: scoreDelta, inverted: false)
                    }
                }
            }

            // Chart — Pro gets full chart, free gets blurred teaser
            if isProUser {
                if filteredScores.count >= 2 {
                    trendlineChart
                        .frame(height: 160)
                } else {
                    Text("Not enough data for this period")
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                        .frame(maxWidth: .infinity, minHeight: 80)
                }
            } else {
                // Free user: blurred chart teaser
                chartProTeaser
            }
        }
    }

    private var chartProTeaser: some View {
        ZStack {
            // Show actual chart if data exists, otherwise placeholder bars
            if filteredScores.count >= 2 {
                trendlineChart
                    .frame(height: 160)
                    .blur(radius: 8)
            } else {
                // Placeholder bars for visual effect
                HStack(alignment: .bottom, spacing: 8) {
                    ForEach(0..<12, id: \.self) { i in
                        RoundedRectangle(cornerRadius: 4)
                            .fill(AppColors.accent.opacity(0.3))
                            .frame(height: CGFloat([40, 60, 50, 80, 70, 90, 85, 65, 95, 75, 55, 100][i]))
                    }
                }
                .frame(height: 160)
                .blur(radius: 8)
            }

            // Overlay
            VStack(spacing: 12) {
                Image(systemName: "lock.fill")
                    .font(.system(size: 24))
                    .foregroundStyle(.secondary)

                Text("Unlock detailed insights")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(.primary)

                Button {
                    showingPaywall = true
                } label: {
                    Text("Go Pro")
                        .font(.system(size: 14, weight: .bold, design: .rounded))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 24)
                        .padding(.vertical, 10)
                        .background(AppColors.accent, in: Capsule())
                }
            }
        }
        .frame(height: 160)
    }

    private var timeRangePicker: some View {
        HStack(spacing: 0) {
            ForEach(TimeRange.allCases, id: \.self) { range in
                Button {
                    withAnimation(.easeInOut(duration: 0.2)) {
                        selectedRange = range
                    }
                } label: {
                    Text(range.rawValue)
                        .font(.system(size: 12, weight: .bold, design: .rounded))
                        .foregroundStyle(selectedRange == range ? .white : .secondary)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background {
                            if selectedRange == range {
                                Capsule()
                                    .fill(AppColors.accent)
                            }
                        }
                }
                .buttonStyle(.plain)
            }
        }
        .padding(2)
        .background(AppColors.cardSurface, in: Capsule())
    }

    private var trendlineChart: some View {
        let chartData = filteredScores.sorted { $0.date < $1.date }
        let scores = chartData.map(\.brainScore)
        let minScore = max(0, (scores.min() ?? 0) - 30)
        let maxScore = min(1000, (scores.max() ?? 1000) + 30)

        return Chart {
            ForEach(chartData, id: \.id) { item in
                AreaMark(
                    x: .value("Date", item.date),
                    y: .value("Score", item.brainScore)
                )
                .foregroundStyle(
                    LinearGradient(
                        colors: [AppColors.accent.opacity(0.25), AppColors.accent.opacity(0.02)],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
                .interpolationMethod(.catmullRom)

                LineMark(
                    x: .value("Date", item.date),
                    y: .value("Score", item.brainScore)
                )
                .foregroundStyle(AppColors.accent)
                .interpolationMethod(.catmullRom)
                .lineStyle(StrokeStyle(lineWidth: 2.5))
            }
        }
        .chartYScale(domain: minScore...maxScore)
        .chartXAxis {
            AxisMarks(values: .automatic(desiredCount: 3)) { value in
                AxisValueLabel {
                    if let date = value.as(Date.self) {
                        Text(date, format: .dateTime.month(.abbreviated).day())
                            .font(.system(size: 10, weight: .medium))
                            .foregroundStyle(.tertiary)
                    }
                }
            }
        }
        .chartYAxis {
            AxisMarks(position: .leading, values: .automatic(desiredCount: 3)) { value in
                AxisValueLabel {
                    if let v = value.as(Int.self) {
                        Text("\(v)")
                            .font(.system(size: 10, weight: .medium, design: .rounded))
                            .foregroundStyle(.tertiary)
                    }
                }
            }
        }
        .chartPlotStyle { plotArea in
            plotArea
                .padding(.top, 8)
                .padding(.trailing, 8)
                .padding(.bottom, 4)
        }
        .clipped()
    }

    // MARK: - 2. Stats Table

    private var statsTableSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Column headers
            HStack {
                Text("METRIC")
                    .font(.system(size: 11, weight: .bold))
                    .tracking(2)
                    .foregroundStyle(.secondary)
                    .textCase(.uppercase)

                Spacer()

                if isProUser {
                    Text("VALUE \u{00B7} \u{0394}\(selectedRange.rawValue)")
                        .font(.system(size: 11, weight: .bold))
                        .tracking(2)
                        .foregroundStyle(.secondary)
                        .textCase(.uppercase)
                } else {
                    Text("VALUE")
                        .font(.system(size: 11, weight: .bold))
                        .tracking(2)
                        .foregroundStyle(.secondary)
                        .textCase(.uppercase)
                }
            }

            Divider().opacity(0.3)

            // Rows
            VStack(spacing: 0) {
                // Brain Score
                if let score = currentScore {
                    statsRow(
                        label: "Brain Score",
                        value: "\(score.brainScore) / 1000",
                        delta: isProUser ? scoreDelta : nil,
                        inverted: false
                    )
                    thinDivider
                }

                // Brain Age
                if let score = currentScore {
                    statsRow(
                        label: "Brain Age",
                        value: "\(score.brainAge) yrs",
                        delta: isProUser ? brainAgeDelta : nil,
                        inverted: true
                    )
                    thinDivider
                }

                // Best Rank (Pro only)
                if isProUser, let bestRank = bestPersonalRecord {
                    statsRow(
                        label: "Best Rank",
                        value: "\(bestRank.type.displayName) \u{00B7} \(personalBestDisplay(type: bestRank.type, value: bestRank.best))",
                        delta: nil,
                        inverted: false
                    )
                    thinDivider
                }

                // Streak
                if let user = user {
                    statsRow(
                        label: "Streak",
                        value: "\(user.currentStreak) days",
                        delta: nil,
                        inverted: false,
                        suffix: "best \(user.longestStreak)"
                    )
                    thinDivider
                }

                // Games Played
                statsRow(
                    label: "Games Played",
                    value: "\(user?.totalExercises ?? exercises.count)",
                    delta: nil,
                    inverted: false
                )

                // Time Trained (Pro only)
                if isProUser {
                    thinDivider
                    statsRow(
                        label: "Time Trained",
                        value: formatTotalTime(),
                        delta: nil,
                        inverted: false
                    )
                }
            }
        }
    }

    private func statsRow(label: String, value: String, delta: Int? = nil, inverted: Bool, suffix: String? = nil) -> some View {
        HStack {
            Text(label)
                .font(.system(size: 15, weight: .medium))
                .foregroundStyle(.secondary)

            Spacer()

            HStack(spacing: 8) {
                Text(value)
                    .font(.system(size: 15, weight: .bold, design: .rounded))
                    .foregroundStyle(.primary)

                if let delta = delta, delta != 0 {
                    deltaLabel(value: delta, inverted: inverted)
                }

                if let suffix = suffix {
                    Text(suffix)
                        .font(.system(size: 12, weight: .medium, design: .rounded))
                        .foregroundStyle(.tertiary)
                }
            }
        }
        .padding(.vertical, 10)
    }

    private var thinDivider: some View {
        Divider().opacity(0.15)
    }

    // MARK: - 3. Cognitive Domains

    private var cognitiveDomainsSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("COGNITIVE DOMAINS")
                .font(.system(size: 11, weight: .bold))
                .tracking(2)
                .foregroundStyle(.secondary)
                .textCase(.uppercase)

            if let score = currentScore {
                VStack(spacing: 12) {
                    domainBar(label: "Memory", score: score.digitSpanScore, color: AppColors.violet)
                    domainBar(label: "Speed", score: score.reactionTimeScore, color: AppColors.coral)
                    domainBar(label: "Visual", score: score.visualMemoryScore, color: AppColors.sky)
                }
            } else {
                Text("Complete a brain assessment to see your domain scores")
                    .font(.caption)
                    .foregroundStyle(.tertiary)
                    .frame(maxWidth: .infinity, minHeight: 60)
            }
        }
    }

    private func domainBar(label: String, score: Double, color: Color) -> some View {
        HStack(spacing: 12) {
            Text(label)
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(.secondary)
                .frame(width: 60, alignment: .leading)

            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 5)
                        .fill(color.opacity(0.12))

                    RoundedRectangle(cornerRadius: 5)
                        .fill(color)
                        .frame(width: geo.size.width * min(1, score / 100))
                }
            }
            .frame(height: 10)

            Text("\(Int(score))")
                .font(.system(size: 14, weight: .bold, design: .rounded))
                .foregroundStyle(.primary)
                .frame(width: 28, alignment: .trailing)

            Text("/ 100")
                .font(.system(size: 11, weight: .medium, design: .rounded))
                .foregroundStyle(.tertiary)
        }
    }

    // MARK: - 4. Personal Bests (Pro only)

    private var personalBestsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("PERSONAL BESTS")
                .font(.system(size: 11, weight: .bold))
                .tracking(2)
                .foregroundStyle(.secondary)
                .textCase(.uppercase)

            Divider().opacity(0.3)

            let bests = allPersonalBests
            if bests.isEmpty {
                Text("Play some games to see your personal bests")
                    .font(.caption)
                    .foregroundStyle(.tertiary)
                    .frame(maxWidth: .infinity, minHeight: 60)
            } else {
                VStack(spacing: 0) {
                    ForEach(Array(bests.enumerated()), id: \.offset) { index, record in
                        statsRow(
                            label: record.type.displayName,
                            value: personalBestDisplay(type: record.type, value: record.best),
                            delta: nil,
                            inverted: false
                        )
                        if index < bests.count - 1 {
                            thinDivider
                        }
                    }
                }
            }
        }
    }

    // MARK: - 5. Training Heatmap (Pro only)

    private var trainingHeatmapSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("TRAINING ACTIVITY")
                .font(.system(size: 11, weight: .bold))
                .tracking(2)
                .foregroundStyle(.secondary)
                .textCase(.uppercase)

            let days = heatmapDays
            let columns = Array(repeating: GridItem(.flexible(), spacing: 4), count: 7)

            // Day-of-week headers
            HStack(spacing: 4) {
                ForEach(["M", "T", "W", "T", "F", "S", "S"], id: \.self) { day in
                    Text(day)
                        .font(.system(size: 10, weight: .medium))
                        .foregroundStyle(.tertiary)
                        .frame(maxWidth: .infinity)
                }
            }

            LazyVGrid(columns: columns, spacing: 4) {
                // Leading spacers for alignment to correct day of week
                ForEach(0..<leadingSpacerCount, id: \.self) { _ in
                    Color.clear
                        .aspectRatio(1, contentMode: .fit)
                }

                ForEach(days, id: \.date) { day in
                    RoundedRectangle(cornerRadius: 3)
                        .fill(heatmapColor(for: day.count))
                        .aspectRatio(1, contentMode: .fit)
                }
            }
        }
    }

    private struct HeatmapDay {
        let date: Date
        let count: Int
    }

    private var heatmapDays: [HeatmapDay] {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())

        // Build exercise counts per day for last 30 days
        var countsByDay: [Date: Int] = [:]
        let thirtyDaysAgo = calendar.date(byAdding: .day, value: -29, to: today) ?? today

        for exercise in exercises {
            let day = calendar.startOfDay(for: exercise.completedAt)
            if day >= thirtyDaysAgo && day <= today {
                countsByDay[day, default: 0] += 1
            }
        }

        // Generate all 30 days
        return (0..<30).compactMap { offset in
            guard let date = calendar.date(byAdding: .day, value: offset, to: thirtyDaysAgo) else { return nil }
            return HeatmapDay(date: date, count: countsByDay[date] ?? 0)
        }
    }

    /// Number of empty cells before the first day to align with correct weekday column (Mon=0)
    private var leadingSpacerCount: Int {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        guard let firstDay = calendar.date(byAdding: .day, value: -29, to: today) else { return 0 }
        // weekday: 1=Sun, 2=Mon, ... 7=Sat -> convert to Mon=0
        let weekday = calendar.component(.weekday, from: firstDay)
        // Mon=0, Tue=1, Wed=2, Thu=3, Fri=4, Sat=5, Sun=6
        return (weekday + 5) % 7
    }

    private func heatmapColor(for count: Int) -> Color {
        if count == 0 {
            return AppColors.cardSurface
        } else if count <= 2 {
            return AppColors.accent.opacity(0.3)
        } else {
            return AppColors.accent
        }
    }

    // MARK: - Helpers

    private func deltaLabel(value: Int, inverted: Bool) -> some View {
        let isPositive = value > 0
        // For inverted metrics (brain age), negative = good
        let isGood = inverted ? !isPositive : isPositive
        let color = isGood
            ? Color(red: 0.13, green: 0.80, blue: 0.0)
            : AppColors.coral
        let prefix = isPositive ? "+" : ""
        let suffix = inverted ? "y" : ""

        return Text("\(prefix)\(value)\(suffix)")
            .font(.system(size: 14, weight: .bold, design: .rounded))
            .foregroundStyle(color)
    }

    private static let availableGames: [ExerciseType] = [
        .reactionTime, .colorMatch, .speedMatch, .visualMemory,
        .sequentialMemory, .mathSpeed, .dualNBack, .chunkingTraining,
        .chimpTest, .verbalMemory
    ]

    private var bestPersonalRecord: (type: ExerciseType, best: Int)? {
        // Find the game with the highest personal best (normalized by checking all)
        let records: [(type: ExerciseType, best: Int)] = Self.availableGames.compactMap { type in
            let best = PersonalBestTracker.shared.best(for: type)
            guard best > 0 else { return nil }
            return (type: type, best: best)
        }
        // Just return the first non-zero record (most recently set tends to be top)
        return records.first
    }

    /// All personal bests for games the user has played (score > 0)
    private var allPersonalBests: [(type: ExerciseType, best: Int)] {
        Self.availableGames.compactMap { type in
            let best = PersonalBestTracker.shared.best(for: type)
            guard best > 0 else { return nil }
            return (type: type, best: best)
        }
    }

    private func personalBestDisplay(type: ExerciseType, value: Int) -> String {
        switch type {
        case .reactionTime: return "\(1000 - value)ms"
        case .dualNBack: return "N=\(value)"
        case .sequentialMemory: return "\(value) digits"
        case .visualMemory: return "Level \(value)"
        case .mathSpeed: return "\(value) solved"
        case .colorMatch, .speedMatch: return "\(value)%"
        case .chunkingTraining: return "\(value)"
        case .chimpTest: return "Level \(value)"
        case .verbalMemory: return "\(value) words"
        case .wordScramble: return "\(value)/10 words"
        case .memoryChain: return "Chain \(value)"
        default: return "\(value)"
        }
    }

    private func formatTotalTime() -> String {
        let totalSeconds = exercises.reduce(0) { $0 + $1.durationSeconds }
        let hours = totalSeconds / 3600
        let minutes = (totalSeconds % 3600) / 60
        if hours > 0 {
            return "\(hours)h \(minutes)m"
        }
        return "\(minutes)m"
    }
}
