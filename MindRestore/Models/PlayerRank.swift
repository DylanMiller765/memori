import SwiftUI

// MARK: - Player Rank

enum PlayerRank: Int, CaseIterable, Comparable {
    case bronze = 0
    case silver = 1
    case gold = 2
    case platinum = 3
    case diamond = 4
    case champion = 5

    static func < (lhs: PlayerRank, rhs: PlayerRank) -> Bool {
        lhs.rawValue < rhs.rawValue
    }

    /// Determine rank from Brain Score (0-1000).
    static func from(brainScore: Int) -> PlayerRank {
        switch brainScore {
        case 900...: return .champion
        case 800..<900: return .diamond
        case 650..<800: return .platinum
        case 500..<650: return .gold
        case 300..<500: return .silver
        default: return .bronze
        }
    }

    var displayName: String {
        switch self {
        case .bronze: return "Bronze"
        case .silver: return "Silver"
        case .gold: return "Gold"
        case .platinum: return "Platinum"
        case .diamond: return "Diamond"
        case .champion: return "Champion"
        }
    }

    var icon: String {
        switch self {
        case .bronze: return "shield.fill"
        case .silver: return "shield.fill"
        case .gold: return "shield.fill"
        case .platinum: return "star.fill"
        case .diamond: return "diamond.fill"
        case .champion: return "crown.fill"
        }
    }

    var color: Color {
        switch self {
        case .bronze: return Color(red: 0.72, green: 0.45, blue: 0.20)
        case .silver: return Color(red: 0.65, green: 0.68, blue: 0.72)
        case .gold: return Color(red: 0.85, green: 0.65, blue: 0.13)
        case .platinum: return Color(red: 0.40, green: 0.75, blue: 0.78)
        case .diamond: return Color(red: 0.55, green: 0.60, blue: 0.95)
        case .champion: return Color(red: 0.90, green: 0.35, blue: 0.45)
        }
    }

    var gradient: LinearGradient {
        switch self {
        case .bronze:
            return LinearGradient(colors: [Color(red: 0.72, green: 0.45, blue: 0.20), Color(red: 0.55, green: 0.35, blue: 0.15)], startPoint: .topLeading, endPoint: .bottomTrailing)
        case .silver:
            return LinearGradient(colors: [Color(red: 0.75, green: 0.78, blue: 0.82), Color(red: 0.55, green: 0.58, blue: 0.62)], startPoint: .topLeading, endPoint: .bottomTrailing)
        case .gold:
            return LinearGradient(colors: [Color(red: 0.95, green: 0.75, blue: 0.20), Color(red: 0.75, green: 0.55, blue: 0.10)], startPoint: .topLeading, endPoint: .bottomTrailing)
        case .platinum:
            return LinearGradient(colors: [Color(red: 0.45, green: 0.85, blue: 0.88), Color(red: 0.30, green: 0.60, blue: 0.65)], startPoint: .topLeading, endPoint: .bottomTrailing)
        case .diamond:
            return LinearGradient(colors: [Color(red: 0.60, green: 0.65, blue: 1.0), Color(red: 0.40, green: 0.45, blue: 0.85)], startPoint: .topLeading, endPoint: .bottomTrailing)
        case .champion:
            return LinearGradient(colors: [Color(red: 0.95, green: 0.40, blue: 0.50), Color(red: 0.80, green: 0.25, blue: 0.35), Color(red: 0.95, green: 0.65, blue: 0.20)], startPoint: .topLeading, endPoint: .bottomTrailing)
        }
    }

    /// Brain Score threshold to reach this rank.
    var minScore: Int {
        switch self {
        case .bronze: return 0
        case .silver: return 300
        case .gold: return 500
        case .platinum: return 650
        case .diamond: return 800
        case .champion: return 900
        }
    }

    /// Brain Score needed for next rank (nil if Champion).
    var nextRankScore: Int? {
        switch self {
        case .bronze: return 300
        case .silver: return 500
        case .gold: return 650
        case .platinum: return 800
        case .diamond: return 900
        case .champion: return nil
        }
    }

    /// Progress toward next rank (0.0 - 1.0).
    func progress(brainScore: Int) -> Double {
        guard let next = nextRankScore else { return 1.0 }
        let range = next - minScore
        guard range > 0 else { return 1.0 }
        return min(1.0, max(0.0, Double(brainScore - minScore) / Double(range)))
    }
}

// MARK: - Rank Badge View (text-only with glow)

struct RankBadge: View {
    let rank: PlayerRank
    var size: CGFloat = 24

    var body: some View {
        Text(rank.displayName.uppercased())
            .font(.system(size: size * 0.45, weight: .black))
            .tracking(0.5)
            .foregroundStyle(rank.color)
            .shadow(color: rank.color.opacity(0.5), radius: 4)
    }
}

// MARK: - Rank Pill (text pill with glow)

struct RankPill: View {
    let rank: PlayerRank
    var showName: Bool = true

    var body: some View {
        Text(rank.displayName.uppercased())
            .font(.system(size: 11, weight: .black))
            .tracking(1)
            .foregroundStyle(rank.color)
            .shadow(color: rank.color.opacity(0.6), radius: 3)
            .padding(.horizontal, 10)
            .padding(.vertical, 4)
            .background(rank.color.opacity(0.12), in: Capsule())
            .overlay(Capsule().stroke(rank.color.opacity(0.25), lineWidth: 1))
    }
}

// MARK: - Rank Progress Bar

struct RankProgressView: View {
    let rank: PlayerRank
    let brainScore: Int

    var body: some View {
        VStack(spacing: 6) {
            HStack {
                RankPill(rank: rank)

                Spacer()

                if let next = nextRank {
                    HStack(spacing: 4) {
                        Text("→")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                        RankPill(rank: next)
                    }
                } else {
                    Text("MAX RANK")
                        .font(.system(size: 9, weight: .black))
                        .tracking(1)
                        .foregroundStyle(rank.color)
                }
            }

            ProgressView(value: rank.progress(brainScore: brainScore))
                .tint(rank.color)

            if let nextScore = rank.nextRankScore {
                Text("\(brainScore) / \(nextScore) Brain Score")
                    .font(.system(size: 10, weight: .medium, design: .rounded))
                    .foregroundStyle(.secondary)
            }
        }
    }

    private var nextRank: PlayerRank? {
        let all = PlayerRank.allCases
        guard let idx = all.firstIndex(of: rank), idx + 1 < all.count else { return nil }
        return all[idx + 1]
    }
}
