import SwiftUI
import SwiftData
import GameKit

struct LeaderboardView: View {
    @Query private var users: [User]
    @Query(sort: \BrainScoreResult.date, order: .reverse) private var brainScores: [BrainScoreResult]
    @Query(sort: \Exercise.completedAt, order: .reverse) private var exercises: [Exercise]
    @Environment(GameCenterService.self) private var gameCenterService
    @Environment(StoreService.self) private var storeService
    @Environment(PaywallTriggerService.self) private var paywallTrigger

    @State private var selectedCategory: LeaderboardCategory = .brainScore
    @State private var selectedFilter: LeaderboardTimeFilter = .allTime
    @State private var entries: [LeaderboardEntryData] = []
    @State private var totalPlayerCount: Int = 0
    @State private var isLoading = false
    @State private var hasLoaded = false

    private var user: User? { users.first }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Category picker
                ScrollView(.horizontal) {
                    HStack(spacing: 8) {
                        ForEach(LeaderboardCategory.allCases) { category in
                            Button {
                                withAnimation(.spring(response: 0.3)) {
                                    selectedCategory = category
                                }
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

                if !storeService.isProUser {
                    proGateView
                } else if !gameCenterService.isAuthenticated {
                    gameCenterRequiredView
                } else if isLoading && entries.isEmpty {
                    skeletonLoadingView
                        .padding(.horizontal)
                        .padding(.top, 8)
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
                if entries.count >= 3 {
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

            Image(systemName: "trophy")
                .font(.system(size: 48))
                .foregroundStyle(AppColors.textTertiary)

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

    // MARK: - Pro Gate

    private var proGateView: some View {
        VStack(spacing: 24) {
            Spacer()

            // Mini podium with metallic avatars
            VStack(spacing: 0) {
                // Mini avatar podium
                HStack(alignment: .bottom, spacing: 8) {
                    // 2nd
                    VStack(spacing: 4) {
                        Circle()
                            .fill(LinearGradient(colors: podiumGradientColors(2), startPoint: .topLeading, endPoint: .bottomTrailing))
                            .frame(width: 28, height: 28)
                            .overlay(Text("2").font(.system(size: 11, weight: .black, design: .rounded)).foregroundStyle(.white))
                        UnevenRoundedRectangle(topLeadingRadius: 6, bottomLeadingRadius: 0, bottomTrailingRadius: 0, topTrailingRadius: 6)
                            .fill(LinearGradient(colors: [podiumColor(2).opacity(0.25), podiumColor(2).opacity(0.10)], startPoint: .top, endPoint: .bottom))
                            .frame(width: 36, height: 36)
                    }
                    // 1st
                    VStack(spacing: 4) {
                        // Trophy centered above 1st
                        ZStack {
                            Circle()
                                .fill(
                                    RadialGradient(
                                        colors: [podiumColor(1).opacity(0.15), .clear],
                                        center: .center,
                                        startRadius: 10,
                                        endRadius: 40
                                    )
                                )
                                .frame(width: 64, height: 64)

                            Image(systemName: "trophy.fill")
                                .font(.system(size: 32))
                                .foregroundStyle(
                                    LinearGradient(
                                        colors: [Color(red: 1.0, green: 0.84, blue: 0.0), Color(red: 0.93, green: 0.65, blue: 0.0)],
                                        startPoint: .top,
                                        endPoint: .bottom
                                    )
                                )
                                .shadow(color: podiumColor(1).opacity(0.4), radius: 8)
                        }

                        Circle()
                            .fill(LinearGradient(colors: podiumGradientColors(1), startPoint: .topLeading, endPoint: .bottomTrailing))
                            .frame(width: 34, height: 34)
                            .overlay(Text("1").font(.system(size: 13, weight: .black, design: .rounded)).foregroundStyle(.white))
                        UnevenRoundedRectangle(topLeadingRadius: 6, bottomLeadingRadius: 0, bottomTrailingRadius: 0, topTrailingRadius: 6)
                            .fill(LinearGradient(colors: [podiumColor(1).opacity(0.30), podiumColor(1).opacity(0.10)], startPoint: .top, endPoint: .bottom))
                            .frame(width: 40, height: 50)
                    }
                    // 3rd
                    VStack(spacing: 4) {
                        Circle()
                            .fill(LinearGradient(colors: podiumGradientColors(3), startPoint: .topLeading, endPoint: .bottomTrailing))
                            .frame(width: 24, height: 24)
                            .overlay(Text("3").font(.system(size: 10, weight: .black, design: .rounded)).foregroundStyle(.white))
                        UnevenRoundedRectangle(topLeadingRadius: 6, bottomLeadingRadius: 0, bottomTrailingRadius: 0, topTrailingRadius: 6)
                            .fill(LinearGradient(colors: [podiumColor(3).opacity(0.25), podiumColor(3).opacity(0.10)], startPoint: .top, endPoint: .bottom))
                            .frame(width: 32, height: 28)
                    }
                }
            }

            VStack(spacing: 8) {
                Text("Compete Globally")
                    .font(.title2.weight(.bold))
                Text("Unlock leaderboards to see how you rank\nagainst players worldwide.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }

            Button {
                paywallTrigger.triggerLeaderboard(isProUser: false)
            } label: {
                HStack(spacing: 8) {
                    Image(systemName: "lock.open.fill")
                        .font(.subheadline.weight(.semibold))
                    Text("Unlock Leaderboards")
                        .font(.headline.weight(.bold))
                }
                .gradientButton(AppColors.premiumGradient)
            }
            .padding(.horizontal, 32)

            Spacer()
        }
    }

    // MARK: - Podium

    private var podiumView: some View {
        VStack(spacing: 0) {
            if entries.count >= 3 {
                // Players floating above pedestals
                HStack(alignment: .bottom, spacing: 6) {
                    podiumPlayer(entries[1], rank: 2)
                        .padding(.bottom, 64)
                    podiumPlayer(entries[0], rank: 1)
                        .padding(.bottom, 88)
                    podiumPlayer(entries[2], rank: 3)
                        .padding(.bottom, 48)
                }

                // Pedestals
                HStack(alignment: .bottom, spacing: 4) {
                    podiumPedestal(rank: 2, height: 64)
                    podiumPedestal(rank: 1, height: 88)
                    podiumPedestal(rank: 3, height: 48)
                }
            }
        }
        .padding(.horizontal, 20)
        .padding(.top, 16)
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

            // Score
            Text(formatScore(entry.score))
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
        .accessibilityLabel("\(rank == 1 ? "First" : rank == 2 ? "Second" : "Third") place, \(entry.isCurrentUser ? "You" : entry.username), score \(formatScore(entry.score))")
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
                Text(formatScore(entry.score))
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
        .accessibilityLabel("Your rank: number \(entry.rank), score \(formatScore(entry.score))")
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

    private func formatScore(_ score: Int) -> String {
        switch selectedCategory {
        case .streak: return "\(score)d"
        case .reactionTime: return "\(score)ms"
        case .colorMatch, .speedMatch:
            // Composite score: accuracy% × 1000 + timeBonus
            let primary = score / 1000
            return "\(primary)%"
        case .visualMemory, .dualNBack: return "Lvl \(score)"
        case .numberMemory: return "\(score) digits"
        case .mathSpeed:
            // Composite score: correctCount × 1000 + timeBonus
            let primary = score / 1000
            return "\(primary)"
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
        .opacity(0.6)
        .animation(.easeInOut(duration: 1).repeatForever(autoreverses: true), value: isLoading)
    }

    private func loadLeaderboard() {
        guard gameCenterService.isAuthenticated else {
            hasLoaded = true
            return
        }

        isLoading = true
        hasLoaded = true

        let category = selectedCategory
        let filter = selectedFilter

        Task {
            let result = await gameCenterService.loadLeaderboardEntries(
                category: category,
                timeFilter: filter
            )
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
