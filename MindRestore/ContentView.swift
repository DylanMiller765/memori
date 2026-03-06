import SwiftUI
import SwiftData

struct ContentView: View {
    @Environment(\.modelContext) private var modelContext
    @Query private var users: [User]
    @State private var showOnboarding = false
    @State private var selectedTab = 0
    @State private var storeService = StoreService()

    private var user: User? { users.first }

    var body: some View {
        Group {
            if user?.hasCompletedOnboarding == true {
                mainTabView
            } else {
                OnboardingView {
                    withAnimation {
                        showOnboarding = false
                    }
                }
            }
        }
        .environment(storeService)
        .onAppear {
            if users.isEmpty {
                let newUser = User()
                modelContext.insert(newUser)
            }
            scheduleStreakRiskIfNeeded()
        }
    }

    private var mainTabView: some View {
        TabView(selection: $selectedTab) {
            HomeView(selectedTab: $selectedTab)
                .tabItem {
                    Label("Home", systemImage: "house.fill")
                }
                .tag(0)

            TrainingView()
                .tabItem {
                    Label("Train", systemImage: "brain.head.profile")
                }
                .tag(1)

            ProgressDashboardView()
                .tabItem {
                    Label("Progress", systemImage: "chart.line.uptrend.xyaxis")
                }
                .tag(2)

            SettingsView()
                .tabItem {
                    Label("Settings", systemImage: "gearshape.fill")
                }
                .tag(3)
        }
        .tint(AppColors.accent)
    }

    private func scheduleStreakRiskIfNeeded() {
        guard let user, user.notificationsEnabled, user.currentStreak > 0 else { return }
        let trainedToday = user.lastSessionDate.map { Calendar.current.isDateInToday($0) } ?? false
        if !trainedToday {
            NotificationService.shared.scheduleStreakRisk(streak: user.currentStreak)
        }
    }
}

struct TrainingView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(StoreService.self) private var storeService
    @Query private var users: [User]
    @State private var showingPaywall = false

    private var user: User? { users.first }
    private var isProUser: Bool { storeService.isProUser || (user?.isProUser ?? false) }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 16) {
                    SectionHeader(title: "Exercises")
                        .padding(.horizontal)

                    ForEach(ExerciseType.allCases) { type in
                        NavigationLink {
                            exerciseDestination(for: type)
                        } label: {
                            ExerciseCard(type: type, isLocked: false)
                        }
                        .buttonStyle(.plain)
                        .padding(.horizontal)
                    }

                    SectionHeader(title: "Categories")
                        .padding(.horizontal)
                        .padding(.top, 8)

                    SectionHeader(title: "Learn")
                        .padding(.horizontal)
                        .padding(.top, 8)

                    NavigationLink {
                        EducationFeedView()
                    } label: {
                        ExerciseCard(
                            title: "Psychoeducation",
                            subtitle: "\(EducationContent.cards.count) articles",
                            icon: "book.fill",
                            isLocked: false
                        )
                    }
                    .buttonStyle(.plain)
                    .padding(.horizontal)

                    SectionHeader(title: "Categories")
                        .padding(.horizontal)
                        .padding(.top, 8)

                    ForEach(CardCategory.allCases) { category in
                        if category.isPro && !isProUser {
                            Button {
                                showingPaywall = true
                            } label: {
                                ExerciseCard(
                                    title: category.displayName,
                                    subtitle: "PRO",
                                    icon: category.icon,
                                    isLocked: true
                                )
                            }
                            .buttonStyle(.plain)
                            .padding(.horizontal)
                        } else {
                            NavigationLink {
                                SpacedRepetitionView(category: category)
                            } label: {
                                ExerciseCard(
                                    title: category.displayName,
                                    subtitle: "Spaced Repetition",
                                    icon: category.icon,
                                    isLocked: false
                                )
                            }
                            .buttonStyle(.plain)
                            .padding(.horizontal)
                        }
                    }
                }
                .padding(.top, 8)
                .padding(.bottom, 32)
            }
            .pageBackground()
            .navigationTitle("Train")
            .sheet(isPresented: $showingPaywall) {
                PaywallView()
            }
        }
    }

    @ViewBuilder
    private func exerciseDestination(for type: ExerciseType) -> some View {
        switch type {
        case .spacedRepetition:
            SpacedRepetitionView(category: .numbers)
        case .dualNBack:
            DualNBackView()
        case .activeRecall:
            ActiveRecallView()
        }
    }
}
