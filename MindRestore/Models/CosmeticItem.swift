import SwiftUI
import SwiftData

// MARK: - Rarity

enum CosmeticRarity: String, Codable, CaseIterable {
    case common
    case rare
    case epic
    case legendary

    var displayName: String {
        rawValue.capitalized
    }

    var color: Color {
        switch self {
        case .common: return Color(red: 0.65, green: 0.68, blue: 0.72)
        case .rare: return AppColors.accent
        case .epic: return AppColors.violet
        case .legendary: return AppColors.amber
        }
    }

    /// Drop weight (higher = more likely).
    var weight: Int {
        switch self {
        case .common: return 60
        case .rare: return 25
        case .epic: return 12
        case .legendary: return 3
        }
    }
}

// MARK: - Cosmetic Type

enum CosmeticType: String, Codable, CaseIterable {
    case mascotSkin
    case profileBorder
    case titleCard

    var displayName: String {
        switch self {
        case .mascotSkin: return "Mascot Skin"
        case .profileBorder: return "Profile Border"
        case .titleCard: return "Title"
        }
    }

    var icon: String {
        switch self {
        case .mascotSkin: return "teddybear.fill"
        case .profileBorder: return "circle.hexagongrid.fill"
        case .titleCard: return "textformat"
        }
    }
}

// MARK: - Cosmetic Item Definition

struct CosmeticItemDef: Identifiable {
    let id: String
    let name: String
    let type: CosmeticType
    let rarity: CosmeticRarity
    /// Asset name for mascot skins, color name for borders, display text for titles.
    let value: String

    /// All available cosmetic items in the game.
    static let allItems: [CosmeticItemDef] = {
        var items: [CosmeticItemDef] = []

        // Mascot Skins (asset names — you'll create these)
        let skins: [(String, String, CosmeticRarity)] = [
            ("skin_default", "Classic Memo", .common),
            ("skin_sunglasses", "Cool Memo", .common),
            ("skin_headband", "Sporty Memo", .common),
            ("skin_wizard", "Wizard Memo", .rare),
            ("skin_ninja", "Ninja Memo", .rare),
            ("skin_astronaut", "Astro Memo", .rare),
            ("skin_pirate", "Pirate Memo", .epic),
            ("skin_robot", "Robo Memo", .epic),
            ("skin_golden", "Golden Memo", .legendary),
            ("skin_galaxy", "Galaxy Memo", .legendary),
        ]
        for (id, name, rarity) in skins {
            items.append(CosmeticItemDef(id: id, name: name, type: .mascotSkin, rarity: rarity, value: id))
        }

        // Profile Borders
        let borders: [(String, String, CosmeticRarity, String)] = [
            ("border_blue", "Ocean", .common, "blue"),
            ("border_green", "Forest", .common, "green"),
            ("border_red", "Ember", .common, "red"),
            ("border_pulse", "Pulse", .rare, "pulse"),
            ("border_neon", "Neon", .rare, "neon"),
            ("border_aurora", "Aurora", .epic, "aurora"),
            ("border_holographic", "Holographic", .epic, "holographic"),
            ("border_flames", "Inferno", .legendary, "flames"),
        ]
        for (id, name, rarity, value) in borders {
            items.append(CosmeticItemDef(id: id, name: name, type: .profileBorder, rarity: rarity, value: value))
        }

        // Title Cards
        let titles: [(String, String, CosmeticRarity, String)] = [
            ("title_thinker", "Thinker", .common, "Thinker"),
            ("title_learner", "Eager Learner", .common, "Eager Learner"),
            ("title_grinder", "Grinder", .common, "Grinder"),
            ("title_speed_demon", "Speed Demon", .rare, "Speed Demon"),
            ("title_big_brain", "Big Brain", .rare, "Big Brain"),
            ("title_no_lifer", "No Lifer", .rare, "No Lifer"),
            ("title_memory_king", "Memory King", .epic, "Memory King"),
            ("title_brain_surgeon", "Brain Surgeon", .epic, "Brain Surgeon"),
            ("title_the_architect", "The Architect", .legendary, "The Architect"),
            ("title_galaxy_brain", "Galaxy Brain", .legendary, "Galaxy Brain"),
        ]
        for (id, name, rarity, value) in titles {
            items.append(CosmeticItemDef(id: id, name: name, type: .titleCard, rarity: rarity, value: value))
        }

        return items
    }()

    static func find(_ id: String) -> CosmeticItemDef? {
        allItems.first { $0.id == id }
    }
}

// MARK: - Unlocked Cosmetic (SwiftData)

@Model
final class UnlockedCosmetic {
    var id: UUID = UUID()
    var itemId: String
    var unlockedAt: Date
    var isNew: Bool

    init(itemId: String) {
        self.id = UUID()
        self.itemId = itemId
        self.unlockedAt = .now
        self.isNew = true
    }

    var definition: CosmeticItemDef? {
        CosmeticItemDef.find(itemId)
    }

    func markSeen() {
        isNew = false
    }
}

// MARK: - Loot Drop Service

@MainActor
@Observable
final class LootDropService {
    /// Drop chance after completing a game (0.0 - 1.0).
    private let dropChance: Double = 0.15

    /// Roll for a loot drop. Returns nil if no drop, or the item definition if dropped.
    func rollDrop(unlockedIds: Set<String>) -> CosmeticItemDef? {
        // 15% chance to get a drop at all
        guard Double.random(in: 0...1) < dropChance else { return nil }

        // Filter to items not yet unlocked
        let available = CosmeticItemDef.allItems.filter { !unlockedIds.contains($0.id) }
        guard !available.isEmpty else { return nil }

        // Weighted random by rarity
        let totalWeight = available.reduce(0) { $0 + $1.rarity.weight }
        var roll = Int.random(in: 0..<totalWeight)

        for item in available {
            roll -= item.rarity.weight
            if roll < 0 {
                return item
            }
        }

        return available.last
    }
}
