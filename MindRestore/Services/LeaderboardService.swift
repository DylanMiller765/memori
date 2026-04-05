import Foundation

// MARK: - Enums

enum LeaderboardCategory: String, CaseIterable, Identifiable {
    case brainScore = "Brain Score"
    case xp = "XP"
    case streak = "Streak"
    // Per-game leaderboards
    case reactionTime = "Reaction Time"
    case colorMatch = "Color Match"
    case speedMatch = "Speed Match"
    case visualMemory = "Visual Memory"
    case numberMemory = "Number Memory"
    case mathSpeed = "Math Speed"
    case dualNBack = "Dual N-Back"
    case wordScramble = "Word Scramble"
    case memoryChain = "Memory Chain"
    case dailyChallenge = "Daily Challenge"

    var id: String { rawValue }

    var icon: String {
        switch self {
        case .brainScore: return "brain.head.profile"
        case .xp: return "star.fill"
        case .streak: return "flame.fill"
        case .reactionTime: return "bolt.fill"
        case .colorMatch: return "paintpalette.fill"
        case .speedMatch: return "bolt.square.fill"
        case .visualMemory: return "square.grid.3x3.fill"
        case .numberMemory: return "number.circle.fill"
        case .mathSpeed: return "multiply.circle.fill"
        case .dualNBack: return "square.grid.3x3"
        case .wordScramble: return "textformat.abc.dottedunderline"
        case .memoryChain: return "link.circle.fill"
        case .dailyChallenge: return "star.circle.fill"
        }
    }

    var scoreDescription: String {
        switch self {
        case .brainScore: return "Overall cognitive score out of 1000"
        case .xp: return "Total XP earned from exercises"
        case .streak: return "Longest consecutive days trained"
        case .reactionTime: return "Fastest average reaction time — lower is better"
        case .colorMatch: return "Highest color matching accuracy %"
        case .speedMatch: return "Highest speed matching accuracy %"
        case .visualMemory: return "Highest grid level completed"
        case .numberMemory: return "Longest digit sequence recalled"
        case .mathSpeed: return "Correct answers weighted by speed — faster + accurate wins"
        case .dualNBack: return "Highest N-back level reached"
        case .wordScramble: return "Most words unscrambled out of 10"
        case .memoryChain: return "Longest sequence chain recalled"
        case .dailyChallenge: return "Highest daily challenge score"
        }
    }
}

enum LeaderboardTimeFilter: String, CaseIterable, Identifiable {
    case today = "Today"
    case thisWeek = "This Week"
    case allTime = "All Time"

    var id: String { rawValue }
}

// MARK: - Display Data

struct LeaderboardEntryData: Identifiable, Sendable {
    let id = UUID()
    let rank: Int
    let username: String
    let score: Int
    let avatarEmoji: String
    let level: Int
    let isCurrentUser: Bool
}
