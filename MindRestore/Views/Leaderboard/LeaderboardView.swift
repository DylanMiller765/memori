import SwiftUI
import SwiftData
import GameKit

struct LeaderboardView: View {
    @Query private var users: [User]
    @Query(sort: \BrainScoreResult.date, order: .reverse) private var brainScores: [BrainScoreResult]
    @Query(sort: \Exercise.completedAt, order: .reverse) private var exercises: [Exercise]
    @Environment(GameCenterService.self) private var gameCenterService

    @State private var selectedCategory: LeaderboardCategory = .brainScore
    @State private var selectedFilter: LeaderboardTimeFilter = .allTime
    @State private var entries: [LeaderboardEntryData] = []
    @State private var totalPlayerCount: Int = 0
    @State private var isLoading = false
    @State private var hasLoaded = false
    @State private var podiumAppeared = false
    @State private var loadError: Error?

    private var user: User? { users.first }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Category picker
                ScrollView(.horizontal) {
                    HStack(spacing: 8) {
                        ForEach(LeaderboardCategory.allCases.filter { $0 != .wordScramble && $0 != .memoryChain }) { category in
                            Button {
                                withAnimation(.spring(response: 0.3)) {
                                    selectedCategory = category
                                }
                                Analytics.leaderboardViewed(category: category.rawValue)
                                loadLeaderboard()
                            } label: {
                                HStack(spacing: 6) {
                                    Image(systemName: category.icon)
                                        .font(.caption)
                                    Text(category.rawValue)
                                        .font(.subheadline.weight(.semibold))
                                }
                                .padding(.horizontal, 14)
                                .padding(.vertical, 8)
                                .background {
                                    if selectedCategory == category {
                                        Capsule().fill(AppColors.accentGradient)
                                    } else {
                                        Capsule().fill(AppColors.cardSurface)
                                            .overlay(
                                                Capsule().stroke(AppColors.cardBorder, lineWidth: 1)
                                            )
                                    }
                                }
                                .foregroundStyle(selectedCategory == category ? .white : .primary)
                            }
                            .accessibilityLabel("\(category.rawValue)\(selectedCategory == category ? ", selected" : "")")
                        }
                    }
                    .padding(.horizontal)
                }
                .scrollIndicators(.hidden)
                .padding(.vertical, 12)

                // Time filter
                Picker("Filter", selection: $selectedFilter) {
                    ForEach(LeaderboardTimeFilter.allCases) { filter in
                        Text(filter.rawValue).tag(filter)
                    }
                }
                .pickerStyle(.segmented)
                .padding(.horizontal)
                .onChange(of: selectedFilter) {
                    loadLeaderboard()
                }

                // Score explanation
                Text(selectedCategory.scoreDescription)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .padding(.horizontal)
                    .padding(.bottom, 12)

                if !gameCenterService.isAuthenticated {
                    gameCenterRequiredView
                } else if isLoading && entries.isEmpty {
                    skeletonLoadingView
                        .padding(.horizontal)
                        .padding(.top, 8)
                } else if !isLoading && entries.isEmpty && loadError != nil {
                    errorLeaderboardView
                } else if !isLoading && entries.isEmpty {
                    emptyLeaderboardView
                } else {
                    leaderboardList
                        .opacity(isLoading ? 0.5 : 1)
                        .animation(.easeInOut(duration: 0.2), value: isLoading)
                }
            }
            .pageBackground()
            .navigationTitle("Rankings")
            .toolbar {
                if gameCenterService.isAuthenticated {
                    ToolbarItem(placement: .topBarTrailing) {
                        Button {
                            let leaderboardID = GameCenterService.leaderboardID(for: selectedCategory)
                            gameCenterService.showLeaderboard(leaderboardID: leaderboardID)
                        } label: {
                            HStack(spacing: 4) {
                                Image(systemName: "gamecontroller.fill")
                                Text("Game Center")
                                    .font(.caption.weight(.semibold))
                            }
                        }
                    }
                }
            }
            .onAppear {
                guard !hasLoaded else { return }
                Analytics.leaderboardViewed(category: selectedCategory.rawValue)
                loadLeaderboard()
            }
        }
    }

    // MARK: - Leaderboard List

    private var leaderboardList: some View {
        ScrollView {
            VStack(spacing: 0) {
                // Player count
                if totalPlayerCount > 0 {
                    Text("\(totalPlayerCount) player\(totalPlayerCount == 1 ? "" : "s") ranked")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity, alignment: .center)
                        .padding(.bottom, 8)
                }

                // Top 3 podium
                if !entries.isEmpty {
                    podiumView
                        .padding(.bottom, 16)
                }

                // Current user position
                if let userEntry = entries.first(where: { $0.isCurrentUser }) {
                    yourRankCard(userEntry)
                        .padding(.horizontal)
                        .padding(.bottom, 12)
                }

                // Full list
                LazyVStack(spacing: 0) {
                    ForEach(Array(entries.enumerated()), id: \.element.id) { index, entry in
                        leaderboardRow(entry, index: index)
                    }
                }
                .appCard(padding: 0)
                .padding(.horizontal)
                .padding(.bottom, 32)
            }
            .responsiveContent()
            .frame(maxWidth: .infinity)
        }
    }

    // MARK: - Empty State

    private var emptyLeaderboardView: some View {
        VStack(spacing: 20) {
            Spacer()

            Image("mascot-podium")
                .renderingMode(.original)
                .resizable()
                .scaledToFit()
                .frame(height: 160)

            Text("No Rankings Yet")
                .font(.title3.weight(.semibold))

            Text("Be the first to set a score!\nComplete exercises to appear on the leaderboard.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)

            Spacer()
        }
    }

    // MARK: - Error State

    private var errorLeaderboardView: some View {
        VStack(spacing: 20) {
            Spacer()

            Image(systemName: "wifi.exclamationmark")
                .font(.system(size: 48))
                .foregroundStyle(AppColors.textTertiary)

            Text("Couldn't Load Rankings")
                .font(.title3.weight(.semibold))

            Text("Check your connection and try again.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)

            Button {
                loadLeaderboard()
            } label: {
                HStack(spacing: 8) {
                    Image(systemName: "arrow.clockwise")
                    Text("Retry")
                }
                .font(.headline.weight(.semibold))
                .padding(.horizontal, 24)
                .padding(.vertical, 12)
                .background(AppColors.accent, in: Capsule())
                .foregroundStyle(.white)
            }

            Spacer()
        }
    }

    // MARK: - Game Center Required

    private var gameCenterRequiredView: some View {
        VStack(spacing: 20) {
            Spacer()

            Image(systemName: "gamecontroller.fill")
                .font(.system(size: 48))
                .foregroundStyle(AppColors.violet)

            Text("Game Center Required")
                .font(.title3.weight(.semibold))

            Text("Sign in via Settings \u{2192} Game Center to compete on leaderboards")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)

            Spacer()
        }
    }

    // MARK: - Podium

    private var podiumView: some View {
        let count = min(entries.count, 3)
        return VStack(spacing: 0) {
            // Players floating above pedestals
            HStack(alignment: .bottom, spacing: 6) {
                if count >= 2 {
                    podiumPlayer(entries[1], rank: 2)
                        .padding(.bottom, 64)
                        .opacity(podiumAppeared ? 1 : 0)
                        .offset(y: podiumAppeared ? 0 : 20)
                        .animation(.spring(response: 0.5, dampingFraction: 0.7).delay(0.3), value: podiumAppeared)
                } else {
                    Color.clear.frame(maxWidth: .infinity)
                }
                if count >= 1 {
                    podiumPlayer(entries[0], rank: 1)
                        .padding(.bottom, 88)
                        .opacity(podiumAppeared ? 1 : 0)
                        .offset(y: podiumAppeared ? 0 : 20)
                        .animation(.spring(response: 0.5, dampingFraction: 0.7).delay(0.5), value: podiumAppeared)
                }
                if count >= 3 {
                    podiumPlayer(entries[2], rank: 3)
                        .padding(.bottom, 48)
                        .opacity(podiumAppeared ? 1 : 0)
                        .offset(y: podiumAppeared ? 0 : 20)
                        .animation(.spring(response: 0.5, dampingFraction: 0.7).delay(0.15), value: podiumAppeared)
                } else {
                    Color.clear.frame(maxWidth: .infinity)
                }
            }

            // Pedestals
            HStack(alignment: .bottom, spacing: 4) {
                if count >= 2 {
                    podiumPedestal(rank: 2, height: podiumAppeared ? 64 : 0)
                        .animation(.spring(response: 0.5, dampingFraction: 0.7).delay(0.2), value: podiumAppeared)
                } else {
                    Color.clear.frame(maxWidth: .infinity, maxHeight: 1)
                }
                if count >= 1 {
                    podiumPedestal(rank: 1, height: podiumAppeared ? 88 : 0)
                        .animation(.spring(response: 0.5, dampingFraction: 0.7).delay(0.35), value: podiumAppeared)
                }
                if count >= 3 {
                    podiumPedestal(rank: 3, height: podiumAppeared ? 48 : 0)
                        .animation(.spring(response: 0.5, dampingFraction: 0.7).delay(0.1), value: podiumAppeared)
                } else {
                    Color.clear.frame(maxWidth: .infinity, maxHeight: 1)
                }
            }
        }
        .padding(.horizontal, 20)
        .padding(.top, 16)
        .onAppear {
            podiumAppeared = false
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                podiumAppeared = true
            }
        }
    }

    private func podiumPlayer(_ entry: LeaderboardEntryData, rank: Int) -> some View {
        let color = podiumColor(rank)
        let isFirst = rank == 1

        return VStack(spacing: 6) {
            // Crown for 1st
            if isFirst {
                Image(systemName: "crown.fill")
                    .font(.system(size: 22))
                    .foregroundStyle(
                        LinearGradient(
                            colors: [Color(red: 1.0, green: 0.84, blue: 0.0), Color(red: 1.0, green: 0.65, blue: 0.0)],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
                    .shadow(color: Color(red: 1.0, green: 0.84, blue: 0.0).opacity(0.6), radius: 6)
            }

            // Avatar circle
            ZStack {
                Circle()
                    .fill(
                        LinearGradient(
                            colors: podiumGradientColors(rank),
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: isFirst ? 56 : 46, height: isFirst ? 56 : 46)
                    .shadow(color: color.opacity(0.4), radius: isFirst ? 8 : 4)

                // Initials
                Text(String((entry.isCurrentUser ? "You" : entry.username).prefix(1)).uppercased())
                    .font(.system(size: isFirst ? 22 : 17, weight: .black, design: .rounded))
                    .foregroundStyle(.white)

                // Medal badge
                Circle()
                    .fill(Color(.systemBackground))
                    .frame(width: 22, height: 22)
                    .overlay(
                        Text("\(rank)")
                            .font(.system(size: 12, weight: .black, design: .rounded))
                            .foregroundStyle(color)
                    )
                    .offset(x: isFirst ? 20 : 16, y: isFirst ? 20 : 16)
            }

            // Score (compact for podium — no wrapping)
            Text(formatScoreCompact(entry.score))
                .font(.system(size: isFirst ? 20 : 15, weight: .black, design: .rounded).monospacedDigit())
                .foregroundStyle(color)

            // Username
            Text(entry.isCurrentUser ? "You" : entry.username)
                .font(.system(size: isFirst ? 12 : 10, weight: .semibold))
                .foregroundStyle(.secondary)
                .lineLimit(1)
        }
        .frame(maxWidth: .infinity)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(rank == 1 ? "First" : rank == 2 ? "Second" : "Third") place, \(entry.isCurrentUser ? "You" : entry.username), score \(formatScoreCompact(entry.score))")
    }

    private func podiumPedestal(rank: Int, height: CGFloat) -> some View {
        let color = podiumColor(rank)
        let isFirst = rank == 1

        return ZStack {
            UnevenRoundedRectangle(topLeadingRadius: 12, bottomLeadingRadius: 0, bottomTrailingRadius: 0, topTrailingRadius: 12)
                .fill(
                    LinearGradient(
                        colors: [
                            color.opacity(0.30),
                            color.opacity(0.15),
                            color.opacity(0.08)
                        ],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
                .overlay(
                    UnevenRoundedRectangle(topLeadingRadius: 12, bottomLeadingRadius: 0, bottomTrailingRadius: 0, topTrailingRadius: 12)
                        .stroke(
                            LinearGradient(
                                colors: [color.opacity(0.5), color.opacity(0.15)],
                                startPoint: .top,
                                endPoint: .bottom
                            ),
                            lineWidth: 1.5
                        )
                )

            // Shine highlight at top
            VStack {
                UnevenRoundedRectangle(topLeadingRadius: 12, bottomLeadingRadius: 0, bottomTrailingRadius: 0, topTrailingRadius: 12)
                    .fill(
                        LinearGradient(
                            colors: [color.opacity(isFirst ? 0.25 : 0.15), .clear],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
                    .frame(height: 16)
                Spacer()
            }

            // Rank number watermark
            Text("\(rank)")
                .font(.system(size: height * 0.55, weight: .black, design: .rounded))
                .foregroundStyle(color.opacity(0.12))
        }
        .frame(maxWidth: .infinity)
        .frame(height: height)
    }

    private func podiumColor(_ rank: Int) -> Color {
        switch rank {
        case 1: return Color(red: 1.0, green: 0.76, blue: 0.03) // Gold
        case 2: return Color(red: 0.65, green: 0.68, blue: 0.72) // Silver
        case 3: return Color(red: 0.80, green: 0.50, blue: 0.20) // Bronze
        default: return .secondary
        }
    }

    private func podiumGradientColors(_ rank: Int) -> [Color] {
        switch rank {
        case 1: return [Color(red: 1.0, green: 0.84, blue: 0.0), Color(red: 0.93, green: 0.65, blue: 0.0)]
        case 2: return [Color(red: 0.75, green: 0.78, blue: 0.82), Color(red: 0.55, green: 0.58, blue: 0.62)]
        case 3: return [Color(red: 0.85, green: 0.55, blue: 0.25), Color(red: 0.65, green: 0.38, blue: 0.15)]
        default: return [.gray, .gray]
        }
    }

    // MARK: - Your Rank Card

    private func yourRankCard(_ entry: LeaderboardEntryData) -> some View {
        HStack(spacing: 14) {
            ZStack {
                Circle()
                    .fill(AppColors.accent.opacity(0.12))
                    .frame(width: 56, height: 56)
                Text("#\(entry.rank)")
                    .font(.system(size: 24, weight: .black, design: .rounded).monospacedDigit())
                    .foregroundStyle(AppColors.accent)
            }

            VStack(alignment: .leading, spacing: 2) {
                Text("YOUR RANK")
                    .font(.caption2.weight(.bold))
                    .foregroundStyle(.secondary)
                    .tracking(1)
                Text(entry.username)
                    .font(.subheadline.weight(.semibold))
            }

            Spacer()

            VStack(alignment: .trailing, spacing: 2) {
                Text(formatScoreCompact(entry.score))
                    .font(.headline.weight(.bold).monospacedDigit())
                if totalPlayerCount > 0, entry.rank > 0 {
                    let percentile = min(100, max(1, Int(ceil(Double(entry.rank) / Double(totalPlayerCount) * 100))))
                    Text("Top \(percentile)%")
                        .font(.caption2.weight(.semibold))
                        .foregroundStyle(AppColors.accent)
                }
            }
        }
        .padding(16)
        .background {
            RoundedRectangle(cornerRadius: 14)
                .fill(AppColors.cardSurface)
                .shadow(color: AppColors.accent.opacity(0.10), radius: 8, y: 2)
        }
        .overlay(
            RoundedRectangle(cornerRadius: 14)
                .stroke(AppColors.accent.opacity(0.15), lineWidth: 1.5)
        )
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Your rank: number \(entry.rank), score \(formatScoreCompact(entry.score))")
    }

    // MARK: - Row

    private func leaderboardRow(_ entry: LeaderboardEntryData, index: Int) -> some View {
        HStack(spacing: 12) {
            Text("\(entry.rank)")
                .font(.subheadline.weight(.bold).monospacedDigit())
                .foregroundStyle(entry.rank <= 3 ? medalColor("\(entry.rank)") : .secondary)
                .frame(width: 30, alignment: .center)

            VStack(alignment: .leading, spacing: 1) {
                Text(entry.isCurrentUser ? "You" : entry.username)
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(entry.isCurrentUser ? AppColors.accent : .primary)
            }

            Spacer()

            Text(formatScore(entry.score))
                .font(.subheadline.weight(.semibold).monospacedDigit())
                .foregroundStyle(entry.isCurrentUser ? AppColors.accent : .primary)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .background {
            if entry.isCurrentUser {
                // Accent left border for current user
                HStack(spacing: 0) {
                    RoundedRectangle(cornerRadius: 2)
                        .fill(AppColors.accent)
                        .frame(width: 3)
                    Spacer()
                }
                .background(AppColors.accent.opacity(0.06))
            } else if index % 2 == 0 {
                // Alternating row background
                AppColors.pageBg.opacity(0.5)
            }
        }
        .overlay(alignment: .bottom) {
            if entry.rank < entries.count {
                Divider().padding(.leading, 56)
            }
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Rank \(entry.rank), \(entry.isCurrentUser ? "You" : entry.username), score \(formatScore(entry.score))\(entry.isCurrentUser ? ", you" : "")")
    }

    private func medalColor(_ medal: String) -> Color {
        switch medal {
        case "1": return AppColors.amber
        case "2": return Color.gray
        case "3": return AppColors.coral
        default: return .secondary
        }
    }

    // MARK: - Helpers

    private func formatScoreCompact(_ score: Int) -> String {
        switch selectedCategory {
        case .colorMatch, .speedMatch:
            let accuracy = score / 1000
            return "\(accuracy)%"
        case .mathSpeed:
            let correct = score / 1000
            return "\(correct)/20"
        default:
            return formatScore(score)
        }
    }

    private func formatScore(_ score: Int) -> String {
        switch selectedCategory {
        case .streak: return "\(score)d"
        case .reactionTime: return "\(score)ms"
        case .colorMatch, .speedMatch:
            // Composite score: accuracy% × 1000 + timeBonus
            let accuracy = score / 1000
            if accuracy == 0 { return "0%" }
            let timeBonus = score % 1000
            let seconds = max(0, 999 - timeBonus)
            return "\(accuracy)% · \(seconds)s"
        case .visualMemory, .dualNBack: return "Lvl \(score)"
        case .numberMemory: return "\(score) digits"
        case .mathSpeed:
            // Composite score: correctCount × 1000 + speedBonus
            let correct = score / 1000
            let speedBonus = score % 1000
            let avgTime = max(1, Int((10.0 - Double(speedBonus) / 999.0 * 9.0)))
            return "\(correct)/20 · \(avgTime)s"
        case .wordScramble:
            // Composite score: wordsCorrect × 1000 + timeBonus
            let primary = score / 1000
            return "\(primary)/10"
        case .memoryChain:
            return "\(score)"
        case .dailyChallenge:
            return "\(score)"
        default:
            if score >= 1000 {
                return String(format: "%.1fk", Double(score) / 1000.0)
            }
            return "\(score)"
        }
    }

    // MARK: - Skeleton Loading

    private var skeletonLoadingView: some View {
        VStack(spacing: 0) {
            ForEach(0..<5, id: \.self) { index in
                HStack(spacing: 12) {
                    RoundedRectangle(cornerRadius: 6)
                        .fill(Color.gray.opacity(0.15))
                        .frame(width: 28, height: 28)

                    VStack(alignment: .leading, spacing: 4) {
                        RoundedRectangle(cornerRadius: 4)
                            .fill(Color.gray.opacity(0.15))
                            .frame(width: [100, 120, 90, 140, 80][index], height: 14)
                        RoundedRectangle(cornerRadius: 4)
                            .fill(Color.gray.opacity(0.1))
                            .frame(width: 60, height: 10)
                    }

                    Spacer()

                    RoundedRectangle(cornerRadius: 4)
                        .fill(Color.gray.opacity(0.15))
                        .frame(width: 50, height: 16)
                }
                .padding(.vertical, 10)
                .padding(.horizontal, 14)

                if index < 4 {
                    Divider().padding(.leading, 54)
                }
            }
        }
        .background {
            RoundedRectangle(cornerRadius: 14)
                .fill(AppColors.cardSurface)
                .shadow(color: .black.opacity(0.05), radius: 6, y: 2)
        }
        .shimmer()
    }

    private func loadLeaderboard() {
        guard gameCenterService.isAuthenticated else {
            hasLoaded = true
            return
        }

        isLoading = true
        hasLoaded = true
        loadError = nil

        let category = selectedCategory
        let filter = selectedFilter

        Task {
            let result = await gameCenterService.loadLeaderboardEntries(
                category: category,
                timeFilter: filter
            )
            loadError = result.error
            var loadedEntries = result.entries

            // Update local player's score if our local best is higher (GC can be stale)
            if let localBest = localScore(for: category), localBest > 0,
               let idx = loadedEntries.firstIndex(where: { $0.isCurrentUser }),
               category != .reactionTime ? loadedEntries[idx].score < localBest : loadedEntries[idx].score > localBest {
                loadedEntries[idx] = LeaderboardEntryData(
                    rank: loadedEntries[idx].rank,
                    username: loadedEntries[idx].username,
                    score: localBest,
                    avatarEmoji: loadedEntries[idx].avatarEmoji,
                    level: loadedEntries[idx].level,
                    isCurrentUser: true
                )
            }

            // If the local player isn't in the results yet, inject their local score
            let hasLocalPlayer = loadedEntries.contains { $0.isCurrentUser }
            if !hasLocalPlayer, let localScore = localScore(for: category), localScore > 0 {
                let localEntry = LeaderboardEntryData(
                    rank: 0,
                    username: GKLocalPlayer.local.displayName,
                    score: localScore,
                    avatarEmoji: "",
                    level: 0,
                    isCurrentUser: true
                )
                loadedEntries.append(localEntry)

                // Re-sort based on category (reaction time = low to high, others = high to low)
                if category == .reactionTime {
                    loadedEntries.sort { $0.score < $1.score }
                } else {
                    loadedEntries.sort { $0.score > $1.score }
                }

                // Re-assign ranks
                loadedEntries = loadedEntries.enumerated().map { index, entry in
                    LeaderboardEntryData(
                        rank: index + 1,
                        username: entry.username,
                        score: entry.score,
                        avatarEmoji: entry.avatarEmoji,
                        level: entry.level,
                        isCurrentUser: entry.isCurrentUser
                    )
                }
            }

            // Filter out zero-score entries (meaningless for all games)
            loadedEntries = loadedEntries.filter { $0.score > 0 || $0.isCurrentUser }
            // Re-assign ranks after filtering
            loadedEntries = loadedEntries.enumerated().map { index, entry in
                LeaderboardEntryData(
                    rank: index + 1,
                    username: entry.username,
                    score: entry.score,
                    avatarEmoji: entry.avatarEmoji,
                    level: entry.level,
                    isCurrentUser: entry.isCurrentUser
                )
            }
            // Remove current user if their score is 0 (they haven't played this game)
            if let userEntry = loadedEntries.first(where: { $0.isCurrentUser }), userEntry.score <= 0 {
                loadedEntries = loadedEntries.filter { !$0.isCurrentUser }
            }

            entries = loadedEntries
            totalPlayerCount = max(result.totalPlayerCount, loadedEntries.count)
            isLoading = false
        }
    }

    /// Get the user's local best score for a leaderboard category
    private func localScore(for category: LeaderboardCategory) -> Int? {
        switch category {
        case .brainScore:
            return brainScores.first?.brainScore
        case .weeklyXP:
            return user?.totalXP
        case .streak:
            return user?.longestStreak
        case .reactionTime:
            // PersonalBestTracker stores inverted (1000-ms), but leaderboard is raw ms now
            let inverted = PersonalBestTracker.shared.best(for: .reactionTime)
            return inverted > 0 ? (1000 - inverted) : nil
        case .colorMatch:
            return PersonalBestTracker.shared.best(for: .colorMatch)
        case .speedMatch:
            return PersonalBestTracker.shared.best(for: .speedMatch)
        case .visualMemory:
            return PersonalBestTracker.shared.best(for: .visualMemory)
        case .numberMemory:
            return PersonalBestTracker.shared.best(for: .sequentialMemory)
        case .mathSpeed:
            return PersonalBestTracker.shared.best(for: .mathSpeed)
        case .dualNBack:
            return PersonalBestTracker.shared.best(for: .dualNBack)
        case .wordScramble:
            return PersonalBestTracker.shared.best(for: .wordScramble)
        case .memoryChain:
            return PersonalBestTracker.shared.best(for: .memoryChain)
        case .dailyChallenge:
            return nil
        }
    }
}
