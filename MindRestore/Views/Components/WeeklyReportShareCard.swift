import SwiftUI

// MARK: - Weekly Report Share Card (Cream Style)

struct WeeklyReportShareCard: View {
    let weekStart: Date
    let weekEnd: Date
    let brainScore: Int
    let previousBrainScore: Int
    let brainAge: Int
    let previousBrainAge: Int
    let streakLength: Int
    let bestGameName: String
    let gamesPlayed: Int

    private var scoreDelta: Int { brainScore - previousBrainScore }
    private var ageDelta: Int { brainAge - previousBrainAge }

    private var dateRangeText: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMM d"
        return "\(formatter.string(from: weekStart)) - \(formatter.string(from: weekEnd))"
    }

    var body: some View {
        ZStack {
            WRCardBackground()

            VStack(spacing: 0) {
                Spacer().frame(height: 32)
                WRBrandingHeader()
                Spacer().frame(height: 24)

                WRShareCardSurface {
                    VStack(spacing: 16) {
                        // Header
                        Text("WEEKLY BRAIN REPORT")
                            .font(.system(size: 13, weight: .heavy))
                            .tracking(3)
                            .foregroundStyle(AppColors.accent)

                        // Date range
                        Text(dateRangeText)
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundStyle(Color(red: 0.62, green: 0.60, blue: 0.58))

                        Divider()

                        // Brain Score + Delta
                        VStack(spacing: 6) {
                            Text("\(brainScore)")
                                .font(.system(size: 64, weight: .bold, design: .rounded))
                                .foregroundStyle(AppColors.accent)

                            Text("BRAIN SCORE")
                                .font(.system(size: 11, weight: .heavy))
                                .tracking(3)
                                .foregroundStyle(Color(red: 0.62, green: 0.60, blue: 0.58))

                            if previousBrainScore > 0 {
                                HStack(spacing: 4) {
                                    Image(systemName: scoreDelta >= 0 ? "arrow.up.right" : "arrow.down.right")
                                        .font(.system(size: 14, weight: .bold))
                                    Text(scoreDelta >= 0 ? "+\(scoreDelta)" : "\(scoreDelta)")
                                        .font(.system(size: 16, weight: .bold, design: .rounded))
                                }
                                .foregroundStyle(scoreDelta >= 0 ? Color(red: 0.34, green: 0.85, blue: 0.74) : AppColors.coral)
                            }
                        }

                        Divider()

                        // Stats Grid
                        VStack(spacing: 12) {
                            // Brain Age
                            HStack {
                                HStack(spacing: 6) {
                                    Image(systemName: "brain.head.profile")
                                        .font(.system(size: 13, weight: .bold))
                                        .foregroundStyle(AppColors.violet)
                                    Text("Brain Age")
                                        .font(.system(size: 13, weight: .semibold))
                                        .foregroundStyle(.secondary)
                                }
                                Spacer()
                                HStack(spacing: 4) {
                                    Text("\(brainAge)")
                                        .font(.system(size: 15, weight: .bold, design: .rounded))
                                    if previousBrainAge > 0 && ageDelta != 0 {
                                        Text(ageDelta < 0 ? "\(ageDelta)yr" : "+\(ageDelta)yr")
                                            .font(.system(size: 11, weight: .bold))
                                            .foregroundStyle(ageDelta < 0 ? Color(red: 0.34, green: 0.85, blue: 0.74) : AppColors.coral)
                                    }
                                }
                            }

                            // Streak
                            HStack {
                                HStack(spacing: 6) {
                                    Image(systemName: "flame.fill")
                                        .font(.system(size: 13, weight: .bold))
                                        .foregroundStyle(AppColors.coral)
                                    Text("Streak")
                                        .font(.system(size: 13, weight: .semibold))
                                        .foregroundStyle(.secondary)
                                }
                                Spacer()
                                Text("\(streakLength) day\(streakLength == 1 ? "" : "s")")
                                    .font(.system(size: 15, weight: .bold, design: .rounded))
                            }

                            // Best Game
                            if !bestGameName.isEmpty {
                                HStack {
                                    HStack(spacing: 6) {
                                        Image(systemName: "trophy.fill")
                                            .font(.system(size: 13, weight: .bold))
                                            .foregroundStyle(AppColors.amber)
                                        Text("Best Game")
                                            .font(.system(size: 13, weight: .semibold))
                                            .foregroundStyle(.secondary)
                                    }
                                    Spacer()
                                    Text(bestGameName)
                                        .font(.system(size: 15, weight: .bold, design: .rounded))
                                        .lineLimit(1)
                                }
                            }

                            // Games Played
                            HStack {
                                HStack(spacing: 6) {
                                    Image(systemName: "gamecontroller.fill")
                                        .font(.system(size: 13, weight: .bold))
                                        .foregroundStyle(AppColors.teal)
                                    Text("Games Played")
                                        .font(.system(size: 13, weight: .semibold))
                                        .foregroundStyle(.secondary)
                                }
                                Spacer()
                                Text("\(gamesPlayed)")
                                    .font(.system(size: 15, weight: .bold, design: .rounded))
                            }
                        }
                    }
                }
                .padding(.horizontal, 24)

                Spacer()

                Text("Train your brain free")
                    .font(.system(size: 20, weight: .bold))
                    .foregroundStyle(.primary)

                Spacer().frame(height: 10)
                WRBrandingFooter()
                Spacer().frame(height: 28)
            }
        }
        .frame(width: 360, height: 640)
    }
}

// MARK: - Private Share Card Helpers (duplicated from TikTokShareCard for encapsulation)

private struct WRCardBackground: View {
    var body: some View {
        LinearGradient(
            colors: [
                Color(red: 0.969, green: 0.961, blue: 0.941),
                Color(red: 0.955, green: 0.945, blue: 0.925),
                Color(red: 0.969, green: 0.961, blue: 0.941)
            ],
            startPoint: .top,
            endPoint: .bottom
        )
    }
}

private struct WRBrandingHeader: View {
    var body: some View {
        HStack(spacing: 6) {
            Image(systemName: "brain.fill")
                .font(.system(size: 12, weight: .bold))
                .foregroundStyle(AppColors.accent)
            Text("MEMORI")
                .font(.system(size: 12, weight: .heavy))
                .tracking(3)
                .foregroundStyle(Color(red: 0.45, green: 0.43, blue: 0.40))
        }
    }
}

private struct WRBrandingFooter: View {
    var body: some View {
        Text("Train your brain free \u{2014} Memori")
            .font(.system(size: 11, weight: .semibold))
            .foregroundStyle(Color(red: 0.62, green: 0.60, blue: 0.58))
    }
}

private struct WRShareCardSurface<Content: View>: View {
    @ViewBuilder var content: () -> Content

    var body: some View {
        content()
            .padding(20)
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(.white)
                    .shadow(color: .black.opacity(0.06), radius: 12, y: 4)
            )
    }
}

// MARK: - Preview

#Preview("Weekly Report Share Card") {
    WeeklyReportShareCard(
        weekStart: Calendar.current.date(byAdding: .day, value: -7, to: .now)!,
        weekEnd: Date.now,
        brainScore: 620,
        previousBrainScore: 574,
        brainAge: 24,
        previousBrainAge: 26,
        streakLength: 12,
        bestGameName: "Dual N-Back",
        gamesPlayed: 28
    )
}
