import SwiftUI
import SwiftData

struct HomeView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(StoreService.self) private var storeService
    @Query private var users: [User]
    @Query(sort: \DailySession.date, order: .reverse) private var sessions: [DailySession]
    @Query(sort: \BrainScoreResult.date, order: .reverse) private var brainScores: [BrainScoreResult]

    @Binding var selectedTab: Int
    @State private var viewModel = HomeViewModel()
    @State private var showingPaywall = false
    @State private var showingAssessment = false

    private var user: User? { users.first }
    private var latestBrainScore: BrainScoreResult? { brainScores.first }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 24) {
                    brainScoreCard
                    dailyChallengeCard
                    streakCard
                    todaySessionCard
                    quickStatsRow
                    learnSection
                }
                .padding(.horizontal)
                .padding(.top, 8)
                .padding(.bottom, 32)
            }
            .pageBackground()
            .navigationTitle("MindRestore")
            .sheet(isPresented: $showingPaywall) {
                PaywallView()
            }
            .fullScreenCover(isPresented: $showingAssessment) {
                NavigationStack {
                    BrainAssessmentView()
                        .toolbar {
                            ToolbarItem(placement: .topBarLeading) {
                                Button {
                                    showingAssessment = false
                                } label: {
                                    Image(systemName: "xmark.circle.fill")
                                        .font(.title3)
                                        .foregroundStyle(.secondary)
                                }
                            }
                        }
                }
            }
            .onAppear {
                viewModel.refresh(user: user, sessions: sessions)
            }
        }
    }

    // MARK: - Brain Score Card

    private var brainScoreCard: some View {
        Group {
            if let score = latestBrainScore {
                // Show existing score
                VStack(spacing: 16) {
                    HStack(alignment: .top) {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Brain Score")
                                .font(.subheadline)
                                .foregroundStyle(.secondary)

                            Text("\(score.brainScore)")
                                .font(.system(size: 48, weight: .black, design: .rounded))
                                .foregroundStyle(AppColors.accent)

                            HStack(spacing: 12) {
                                Label("Age \(score.brainAge)", systemImage: "person.fill")
                                    .font(.caption.weight(.medium))
                                    .foregroundStyle(.secondary)

                                Label("Top \(100 - score.percentile)%", systemImage: "chart.bar.fill")
                                    .font(.caption.weight(.medium))
                                    .foregroundStyle(AppColors.accent)
                            }
                        }

                        Spacer()

                        VStack(spacing: 6) {
                            Image(systemName: score.brainType.icon)
                                .font(.title2)
                                .foregroundStyle(brainTypeColor(score.brainType))

                            Text(score.brainType.displayName)
                                .font(.caption2.weight(.bold))
                                .foregroundStyle(brainTypeColor(score.brainType))
                        }
                        .padding(12)
                        .background(brainTypeColor(score.brainType).opacity(0.1), in: RoundedRectangle(cornerRadius: 12))
                    }

                    // Mini score bars
                    HStack(spacing: 8) {
                        miniScoreBar(label: "Memory", score: score.digitSpanScore, color: .blue)
                        miniScoreBar(label: "Speed", score: score.reactionTimeScore, color: .yellow)
                        miniScoreBar(label: "Visual", score: score.visualMemoryScore, color: .purple)
                    }

                    HStack {
                        Button {
                            showingAssessment = true
                        } label: {
                            Text("Retake Test")
                                .font(.subheadline.weight(.semibold))
                                .foregroundStyle(AppColors.accent)
                        }

                        Spacer()

                        ShareLink(item: "My Brain Score is \(score.brainScore)/1000 (Brain Age: \(score.brainAge)) 🧠 — \(score.brainType.displayName)\nTest yours with MindRestore") {
                            Label("Share", systemImage: "square.and.arrow.up")
                                .font(.subheadline.weight(.medium))
                                .foregroundStyle(.secondary)
                        }
                    }
                }
                .appCard()
            } else {
                // CTA to take assessment
                Button {
                    showingAssessment = true
                } label: {
                    VStack(spacing: 16) {
                        HStack(spacing: 14) {
                            Image(systemName: "brain.head.profile")
                                .font(.system(size: 36))
                                .foregroundStyle(.white)

                            VStack(alignment: .leading, spacing: 4) {
                                Text("Discover Your Brain Score")
                                    .font(.headline)
                                    .foregroundStyle(.white)
                                Text("Take a 2-minute assessment")
                                    .font(.subheadline)
                                    .foregroundStyle(.white.opacity(0.8))
                            }

                            Spacer()

                            Image(systemName: "chevron.right")
                                .font(.body.weight(.semibold))
                                .foregroundStyle(.white.opacity(0.6))
                        }

                        HStack(spacing: 16) {
                            assessmentPreviewItem(icon: "number.circle", label: "Memory")
                            assessmentPreviewItem(icon: "bolt", label: "Speed")
                            assessmentPreviewItem(icon: "square.grid.3x3", label: "Visual")
                        }
                    }
                    .padding(20)
                    .background(
                        LinearGradient(colors: [AppColors.accent, AppColors.accent.opacity(0.8)], startPoint: .topLeading, endPoint: .bottomTrailing),
                        in: RoundedRectangle(cornerRadius: 16)
                    )
                    .shadow(color: AppColors.accent.opacity(0.3), radius: 12, y: 4)
                }
                .buttonStyle(.plain)
            }
        }
    }

    private func assessmentPreviewItem(icon: String, label: String) -> some View {
        VStack(spacing: 4) {
            Image(systemName: icon)
                .font(.caption)
            Text(label)
                .font(.caption2)
        }
        .foregroundStyle(.white.opacity(0.7))
        .frame(maxWidth: .infinity)
    }

    private func miniScoreBar(label: String, score: Double, color: Color) -> some View {
        VStack(spacing: 4) {
            ZStack(alignment: .leading) {
                RoundedRectangle(cornerRadius: 3)
                    .fill(color.opacity(0.15))
                    .frame(height: 6)
                RoundedRectangle(cornerRadius: 3)
                    .fill(color)
                    .frame(width: max(4, CGFloat(score) / 100 * 80), height: 6)
            }
            .frame(maxWidth: .infinity)

            Text(label)
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
    }

    private func brainTypeColor(_ type: BrainType) -> Color {
        switch type {
        case .lightningReflex: return .yellow
        case .numberCruncher: return .blue
        case .patternMaster: return .purple
        case .balancedBrain: return AppColors.accent
        }
    }

    // MARK: - Daily Challenge Card

    private var dailyChallengeCard: some View {
        NavigationLink {
            DailyChallengeView()
        } label: {
            HStack(spacing: 14) {
                Image(systemName: "trophy.fill")
                    .font(.title2)
                    .foregroundStyle(.orange)
                    .frame(width: 40, height: 40)
                    .background(Color.orange.opacity(0.15), in: RoundedRectangle(cornerRadius: 10))

                VStack(alignment: .leading, spacing: 2) {
                    Text("Daily Challenge")
                        .font(.subheadline.weight(.semibold))
                    Text("Same challenge for everyone · Compete!")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Spacer()

                Image(systemName: "chevron.right")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.tertiary)
            }
            .appCard()
        }
        .buttonStyle(.plain)
    }

    // MARK: - Streak Card

    private var streakCard: some View {
        HStack(spacing: 20) {
            StreakRingView(current: viewModel.currentStreak, goal: 7, lineWidth: 10, size: 100)

            VStack(alignment: .leading, spacing: 8) {
                Text("Current Streak")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)

                if user?.isStreakActive == true {
                    Label("Streak active", systemImage: "flame.fill")
                        .font(.subheadline.weight(.medium))
                        .foregroundStyle(AppColors.accent)
                } else {
                    Text("Complete an exercise to start")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }

                HStack(spacing: 16) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("\(viewModel.longestStreak)")
                            .font(.headline)
                        Text("Best")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    VStack(alignment: .leading, spacing: 2) {
                        Text("\(viewModel.totalSessions)")
                            .font(.headline)
                        Text("Sessions")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
            }

            Spacer()
        }
        .appCard()
    }

    // MARK: - Today Session Card

    private var todaySessionCard: some View {
        VStack(spacing: 16) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Today's Training")
                        .font(.headline)
                    Text("\(viewModel.todaySessionCount)/\(viewModel.dailyGoal) exercises")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }

                Spacer()

                ProgressRing(
                    progress: viewModel.dailyGoal > 0 ? Double(viewModel.todaySessionCount) / Double(viewModel.dailyGoal) : 0,
                    size: 52,
                    lineWidth: 6
                )
            }

            Button {
                selectedTab = 1
            } label: {
                Text("Start Training")
                    .accentButton()
            }
        }
        .appCard()
    }

    // MARK: - Quick Stats

    private var quickStatsRow: some View {
        HStack(spacing: 12) {
            StatCard(value: "\(viewModel.totalSessions)", label: "Total Sessions", icon: "brain.head.profile", color: AppColors.accent)
            StatCard(value: viewModel.averageScore.percentString, label: "Avg Score", icon: "chart.bar.fill", color: .blue)
        }
    }

    // MARK: - Learn Section

    private var learnSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                SectionHeader(title: "Learn")
                Spacer()
                NavigationLink {
                    EducationFeedView()
                } label: {
                    Text("See All")
                        .font(.subheadline.weight(.medium))
                        .foregroundStyle(AppColors.accent)
                }
            }

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 12) {
                    ForEach(EducationContent.cards.prefix(5)) { card in
                        NavigationLink {
                            EducationDetailView(card: card)
                        } label: {
                            EducationCardView(card: card)
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
        }
    }
}

// MARK: - Education Card View (Horizontal)

struct EducationCardView: View {
    let card: PsychoEducationCard

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Image(systemName: card.category.icon)
                .font(.title2)
                .foregroundStyle(AppColors.accent)

            Text(card.title)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.primary)
                .lineLimit(2)
                .multilineTextAlignment(.leading)

            Text(card.category.displayName)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .frame(width: 160, alignment: .leading)
        .appCard()
    }
}

// MARK: - Stat Card

struct StatCard: View {
    let value: String
    let label: String
    let icon: String
    let color: Color

    var body: some View {
        VStack(spacing: 8) {
            Image(systemName: icon)
                .font(.caption)
                .foregroundStyle(color)
            Text(value)
                .font(.title2.weight(.bold))
            Text(label)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .appCard()
    }
}
