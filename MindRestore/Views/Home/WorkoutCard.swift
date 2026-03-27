import SwiftUI

struct WorkoutCard: View {
    let workout: DailyWorkout
    let onStartGame: (ExerciseType) -> Void
    let onSeeResults: () -> Void

    var body: some View {
        VStack(spacing: 16) {
            if workout.isComplete {
                completeState
            } else {
                activeState
            }
        }
        .glowingCard(color: workout.isComplete ? AppColors.teal : AppColors.accent, intensity: 0.20)
    }

    // MARK: - Complete State

    @ViewBuilder
    private var completeState: some View {
        HStack(spacing: 10) {
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 28, weight: .bold))
                .foregroundStyle(AppColors.teal)

            VStack(alignment: .leading, spacing: 2) {
                Text("Workout Complete!")
                    .font(.system(size: 18, weight: .bold, design: .rounded))
                    .foregroundStyle(AppColors.textPrimary)

                Text("All 3 games finished")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(AppColors.textSecondary)
            }

            Spacer()
        }

        Button {
            onSeeResults()
        } label: {
            Text("See Results")
                .gradientButton()
        }
    }

    // MARK: - Active State (not started or in progress)

    @ViewBuilder
    private var activeState: some View {
        // Header row
        HStack(alignment: .top) {
            VStack(alignment: .leading, spacing: 4) {
                Text("TODAY'S WORKOUT")
                    .font(.system(size: 11, weight: .bold))
                    .tracking(1.5)
                    .foregroundStyle(AppColors.textTertiary)

                if workout.completedCount == 0 {
                    Text("Complete all 3 to update your Brain Score")
                        .font(.system(size: 13, weight: .medium))
                        .foregroundStyle(AppColors.textSecondary)
                } else {
                    Text("\(workout.completedCount) of 3 \u{2014} finish to update Brain Score")
                        .font(.system(size: 13, weight: .medium))
                        .foregroundStyle(AppColors.textSecondary)
                }
            }

            Spacer()

            // Progress ring
            progressRing
        }

        // Game tiles
        VStack(spacing: 8) {
            ForEach(workout.games) { game in
                gameTile(game)
            }
        }

        // Action button
        Button {
            if let next = workout.nextGame {
                onStartGame(next.exerciseType)
            }
        } label: {
            if workout.completedCount == 0 {
                Text("Start Workout")
                    .gradientButton()
            } else if let next = workout.nextGame {
                Text("Continue \u{2192} \(next.exerciseType.displayName)")
                    .gradientButton()
            }
        }
    }

    // MARK: - Progress Ring

    private var progressRing: some View {
        ZStack {
            Circle()
                .stroke(AppColors.cardBorder, lineWidth: 4)

            Circle()
                .trim(from: 0, to: CGFloat(workout.completedCount) / 3.0)
                .stroke(
                    AppColors.accent,
                    style: StrokeStyle(lineWidth: 4, lineCap: .round)
                )
                .rotationEffect(.degrees(-90))
                .animation(.spring(response: 0.5, dampingFraction: 0.8), value: workout.completedCount)

            Text("\(workout.completedCount)/3")
                .font(.system(size: 13, weight: .bold, design: .rounded))
                .foregroundStyle(AppColors.textPrimary)
        }
        .frame(width: 44, height: 44)
    }

    // MARK: - Game Tile

    @ViewBuilder
    private func gameTile(_ game: WorkoutGame) -> some View {
        HStack(spacing: 12) {
            if game.completed {
                // Completed: teal checkmark
                ZStack {
                    Circle()
                        .fill(AppColors.teal.opacity(0.15))
                        .frame(width: 36, height: 36)

                    Image(systemName: "checkmark")
                        .font(.system(size: 14, weight: .bold))
                        .foregroundStyle(AppColors.teal)
                }
            } else {
                // Not completed: domain-colored icon
                ZStack {
                    Circle()
                        .fill(game.domain.color.opacity(0.15))
                        .frame(width: 36, height: 36)

                    Image(systemName: game.exerciseType.icon)
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(game.domain.color)
                }
            }

            VStack(alignment: .leading, spacing: 2) {
                Text(game.exerciseType.displayName)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(AppColors.textPrimary)

                if game.completed, let score = game.score {
                    Text("\(Int(score * 100))%")
                        .font(.system(size: 12, weight: .bold, design: .rounded))
                        .foregroundStyle(AppColors.teal)
                } else {
                    Text(game.reasonTag)
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(AppColors.textTertiary)
                }
            }

            Spacer()

            if game.completed {
                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 16))
                    .foregroundStyle(AppColors.teal)
            }
        }
        .padding(.vertical, 6)
        .padding(.horizontal, 10)
        .background(
            RoundedRectangle(cornerRadius: 10)
                .fill(game.completed ? AppColors.teal.opacity(0.05) : Color.clear)
        )
    }
}

#Preview("Not Started") {
    WorkoutCard(
        workout: DailyWorkout(
            dateString: "2026-03-12",
            games: [
                WorkoutGame(exerciseType: .reactionTime, domain: .speed, reasonTag: "Needs work"),
                WorkoutGame(exerciseType: .sequentialMemory, domain: .memory, reasonTag: "Your goal"),
                WorkoutGame(exerciseType: .visualMemory, domain: .visual, reasonTag: "Mix it up"),
            ]
        ),
        onStartGame: { _ in },
        onSeeResults: {}
    )
    .padding()
    .pageBackground()
}

#Preview("Complete") {
    WorkoutCard(
        workout: {
            var games = [
                WorkoutGame(exerciseType: .reactionTime, domain: .speed, reasonTag: "Needs work"),
                WorkoutGame(exerciseType: .sequentialMemory, domain: .memory, reasonTag: "Your goal"),
                WorkoutGame(exerciseType: .visualMemory, domain: .visual, reasonTag: "Mix it up"),
            ]
            games[0].score = 0.85
            games[0].completed = true
            games[1].score = 0.72
            games[1].completed = true
            games[2].score = 0.91
            games[2].completed = true
            return DailyWorkout(dateString: "2026-03-12", games: games)
        }(),
        onStartGame: { _ in },
        onSeeResults: {}
    )
    .padding()
    .pageBackground()
}
