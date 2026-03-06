import SwiftUI
import SwiftData
import Charts

struct ProgressDashboardView: View {
    @Environment(StoreService.self) private var storeService
    @Query private var users: [User]
    @Query(sort: \DailySession.date, order: .reverse) private var sessions: [DailySession]
    @Query(sort: \BrainScoreResult.date, order: .reverse) private var brainScores: [BrainScoreResult]

    @State private var viewModel = ProgressViewModel()
    @State private var showingPaywall = false

    private var user: User? { users.first }
    private var isProUser: Bool { storeService.isProUser || (user?.isProUser ?? false) }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 24) {
                    if let latestScore = brainScores.first {
                        brainScoreProgressCard(latestScore)
                    }
                    streakSection
                    calendarHeatmap
                    basicStats

                    if isProUser {
                        scoreChart
                        memoryScoreCard
                    } else {
                        proUpsell
                    }
                }
                .padding(.horizontal)
                .padding(.top, 8)
                .padding(.bottom, 32)
            }
            .pageBackground()
            .navigationTitle("Progress")
            .onAppear { viewModel.refresh(sessions: sessions) }
            .sheet(isPresented: $showingPaywall) {
                PaywallView()
            }
        }
    }

    // MARK: - Streak Section

    private var streakSection: some View {
        HStack(spacing: 0) {
            statItem(value: "\(user?.currentStreak ?? 0)", label: "Current", icon: "flame.fill", color: AppColors.accent)
            Divider().frame(height: 32)
            statItem(value: "\(user?.longestStreak ?? 0)", label: "Longest", icon: "trophy.fill", color: .orange)
            Divider().frame(height: 32)
            statItem(value: "\(sessions.count)", label: "Sessions", icon: "brain.head.profile", color: .blue)
        }
        .appCard()
    }

    private func statItem(value: String, label: String, icon: String, color: Color) -> some View {
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

    // MARK: - Calendar Heatmap

    private var calendarHeatmap: some View {
        VStack(alignment: .leading, spacing: 12) {
            SectionHeader(title: "Training Calendar")
            HeatmapCalendarView(trainingDays: viewModel.trainingDays)
        }
        .appCard()
    }

    // MARK: - Basic Stats

    private var basicStats: some View {
        VStack(alignment: .leading, spacing: 12) {
            SectionHeader(title: "Overview")

            VStack(spacing: 8) {
                statsRow(label: "Total Sessions", value: "\(sessions.count)")
                Divider()
                statsRow(label: "Total Exercises", value: "\(sessions.reduce(0) { $0 + $1.exercisesCompleted.count })")
                Divider()
                let totalTime = sessions.reduce(0) { $0 + $1.durationSeconds }
                statsRow(label: "Total Training Time", value: totalTime.durationString)
            }
        }
        .appCard()
    }

    private func statsRow(label: String, value: String) -> some View {
        HStack {
            Text(label)
                .font(.subheadline)
                .foregroundStyle(.secondary)
            Spacer()
            Text(value)
                .font(.subheadline.weight(.semibold))
        }
    }

    // MARK: - Score Chart (Pro)

    private var scoreChart: some View {
        VStack(alignment: .leading, spacing: 12) {
            SectionHeader(title: "Score Trends")

            if viewModel.weeklyScores.isEmpty {
                Text("Complete exercises to see trends")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 24)
            } else {
                Chart {
                    ForEach(viewModel.weeklyScores.indices, id: \.self) { index in
                        let item = viewModel.weeklyScores[index]
                        LineMark(
                            x: .value("Date", item.date),
                            y: .value("Score", item.score)
                        )
                        .foregroundStyle(AppColors.accent)
                        .interpolationMethod(.catmullRom)

                        PointMark(
                            x: .value("Date", item.date),
                            y: .value("Score", item.score)
                        )
                        .foregroundStyle(AppColors.accent)
                    }
                }
                .chartYScale(domain: 0...1)
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

    // MARK: - Memory Score (Pro)

    private var memoryScoreCard: some View {
        VStack(spacing: 12) {
            Text("Memory Score")
                .font(.headline)

            Text(viewModel.memoryScore.percentString)
                .font(.system(size: 48, weight: .bold, design: .rounded))
                .foregroundStyle(AppColors.accent)

            Text("7-day weighted average")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .appCard()
    }

    // MARK: - Brain Score Progress

    private func brainScoreProgressCard(_ score: BrainScoreResult) -> some View {
        VStack(spacing: 12) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Brain Score")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                    Text("\(score.brainScore)")
                        .font(.system(size: 36, weight: .bold, design: .rounded))
                        .foregroundStyle(AppColors.accent)
                }

                Spacer()

                VStack(alignment: .trailing, spacing: 4) {
                    HStack(spacing: 6) {
                        Image(systemName: score.brainType.icon)
                        Text(score.brainType.displayName)
                    }
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(AppColors.accent)

                    Text("Brain Age: \(score.brainAge)")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            if brainScores.count > 1 {
                HStack(spacing: 4) {
                    let previous = brainScores[1].brainScore
                    let diff = score.brainScore - previous
                    Image(systemName: diff >= 0 ? "arrow.up.right" : "arrow.down.right")
                        .font(.caption2)
                    Text("\(abs(diff)) points \(diff >= 0 ? "improvement" : "decrease") from last test")
                        .font(.caption)
                }
                .foregroundStyle(score.brainScore >= (brainScores[safe: 1]?.brainScore ?? 0) ? AppColors.accent : .orange)
            }
        }
        .appCard()
    }

    // MARK: - Pro Upsell

    private var proUpsell: some View {
        Button {
            showingPaywall = true
        } label: {
            HStack(spacing: 14) {
                Image(systemName: "chart.line.uptrend.xyaxis")
                    .font(.title2)
                    .foregroundStyle(.white)

                VStack(alignment: .leading, spacing: 2) {
                    Text("Unlock Detailed Analytics")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.white)
                    Text("Score trends, memory score, and more")
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
                LinearGradient(
                    colors: [AppColors.accent, AppColors.accent.opacity(0.85)],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                ),
                in: RoundedRectangle(cornerRadius: 16)
            )
            .shadow(color: AppColors.accent.opacity(0.25), radius: 12, y: 4)
        }
        .buttonStyle(.plain)
    }
}
