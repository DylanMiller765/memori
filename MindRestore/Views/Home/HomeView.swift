import SwiftUI
import SwiftData

struct HomeView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(StoreService.self) private var storeService
    @Query private var users: [User]
    @Query(sort: \DailySession.date, order: .reverse) private var sessions: [DailySession]

    @Binding var selectedTab: Int
    @State private var viewModel = HomeViewModel()
    @State private var showingPaywall = false

    private var user: User? { users.first }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 24) {
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
            .onAppear {
                viewModel.refresh(user: user, sessions: sessions)
            }
        }
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
            SectionHeader(title: "Learn")

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
