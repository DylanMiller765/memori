import SwiftUI
import SwiftData
import UIKit

struct OnboardingView: View {
    @Environment(\.modelContext) private var modelContext
    @Query private var users: [User]
    @State private var currentPage = 0
    @State private var selectedGoals: Set<UserFocusGoal> = []

    var onComplete: () -> Void

    private let totalPages = 3

    var body: some View {
        ZStack {
            Color(UIColor.systemBackground).ignoresSafeArea()

            VStack(spacing: 0) {
                TabView(selection: $currentPage) {
                    welcomePage.tag(0)
                    goalsPage.tag(1)
                    privacyPage.tag(2)
                }
                .tabViewStyle(.page(indexDisplayMode: .never))
                .scrollDisabled(true)
                .animation(.easeInOut, value: currentPage)

                HStack(spacing: 8) {
                    ForEach(0..<totalPages, id: \.self) { index in
                        Circle()
                            .fill(index == currentPage ? AppColors.accent : Color.gray.opacity(0.3))
                            .frame(width: index == currentPage ? 8 : 6, height: index == currentPage ? 8 : 6)
                            .animation(.easeInOut(duration: 0.2), value: currentPage)
                    }
                }
                .padding(.bottom, 16)
            }
        }
    }

    private var welcomePage: some View {
        VStack(spacing: 40) {
            Spacer()

            VStack(spacing: 16) {
                Image(systemName: "brain.head.profile")
                    .font(.system(size: 72, weight: .light))
                    .foregroundStyle(AppColors.accent)

                Text("MindRestore")
                    .font(.largeTitle.bold())

                Text("Your memory is a muscle.\nLet's train it.")
                    .font(.title3)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }

            VStack(alignment: .leading, spacing: 20) {
                FeatureRow(icon: "rectangle.on.rectangle.angled", color: AppColors.accent, title: "Spaced Repetition", subtitle: "Adaptive review at optimal intervals")
                FeatureRow(icon: "square.grid.3x3", color: .blue, title: "Dual N-Back", subtitle: "Working memory training")
                FeatureRow(icon: "brain.head.profile", color: .purple, title: "Active Recall", subtitle: "Real-world memory challenges")
                FeatureRow(icon: "chart.line.uptrend.xyaxis", color: .orange, title: "Track Progress", subtitle: "See your improvement over time")
            }
            .padding(.horizontal, 40)

            Spacer()

            continueButton { currentPage = 1 }
        }
        .padding(.bottom, 8)
    }

    private var goalsPage: some View {
        VStack(spacing: 32) {
            Spacer()

            VStack(spacing: 8) {
                Text("Pick your focus")
                    .font(.title.bold())
                Text("Select 1-3 goals")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }

            VStack(spacing: 12) {
                ForEach(UserFocusGoal.allCases) { goal in
                    GoalCard(goal: goal, isSelected: selectedGoals.contains(goal)) {
                        withAnimation(.easeInOut(duration: 0.2)) {
                            if selectedGoals.contains(goal) {
                                selectedGoals.remove(goal)
                            } else if selectedGoals.count < 3 {
                                selectedGoals.insert(goal)
                            }
                        }
                    }
                }
            }
            .padding(.horizontal, 24)

            Spacer()

            continueButton { currentPage = 2 }
                .disabled(selectedGoals.isEmpty)
                .opacity(selectedGoals.isEmpty ? 0.4 : 1)
        }
        .padding(.bottom, 8)
    }

    private var privacyPage: some View {
        VStack(spacing: 32) {
            Spacer()

            Image(systemName: "lock.shield.fill")
                .font(.system(size: 72))
                .foregroundStyle(AppColors.accent)

            VStack(spacing: 8) {
                Text("Your data stays on\nyour device. Always.")
                    .font(.title.bold())
                    .multilineTextAlignment(.center)
                Text("No accounts. No cloud. No tracking.\nEverything runs locally.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }

            Spacer()

            Button {
                completeOnboarding()
            } label: {
                Text("Get Started")
                    .accentButton()
            }
            .padding(.horizontal, 32)
        }
        .padding(.bottom, 8)
    }

    private func continueButton(action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text("Continue")
                .accentButton()
        }
        .padding(.horizontal, 32)
    }

    private func completeOnboarding() {
        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
        let user: User
        if let existing = users.first {
            user = existing
        } else {
            user = User()
            modelContext.insert(user)
        }

        user.hasCompletedOnboarding = true
        user.focusGoals = Array(selectedGoals)

        onComplete()
    }
}

// MARK: - Feature Row

struct FeatureRow: View {
    let icon: String
    let color: Color
    let title: String
    let subtitle: String

    var body: some View {
        HStack(spacing: 16) {
            Image(systemName: icon)
                .font(.title3)
                .foregroundStyle(color)
                .frame(width: 28)

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.subheadline.weight(.semibold))
                Text(subtitle)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()
        }
    }
}

// MARK: - Goal Card

struct GoalCard: View {
    let goal: UserFocusGoal
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 16) {
                RoundedRectangle(cornerRadius: 2)
                    .fill(isSelected ? AppColors.accent : Color.clear)
                    .frame(width: 4, height: 40)

                Image(systemName: goal.icon)
                    .font(.title3)
                    .foregroundStyle(isSelected ? AppColors.accent : .secondary)
                    .frame(width: 32)

                Text(goal.displayName)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.primary)
                    .multilineTextAlignment(.leading)

                Spacer()

                if isSelected {
                    Image(systemName: "checkmark")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(AppColors.accent)
                }
            }
            .padding(.vertical, 14)
            .padding(.horizontal, 12)
            .background(Color(UIColor.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 14))
            .shadow(color: .black.opacity(0.04), radius: 8, y: 2)
        }
        .buttonStyle(.plain)
    }
}
