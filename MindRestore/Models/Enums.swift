import Foundation

// MARK: - Subscription Status

enum SubscriptionStatus: String, Codable {
    case free, trial, subscribed
}

// MARK: - Exercise Type

enum ExerciseType: String, Codable, CaseIterable, Identifiable {
    case spacedRepetition, dualNBack, activeRecall, chunkingTraining, prospectiveMemory
    case memoryPalace, reactionTime, sequentialMemory, mathSpeed, speedMatch, visualMemory, colorMatch
    case wordScramble
    case memoryChain
    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .spacedRepetition: return "Spaced Repetition"
        case .dualNBack: return "Dual N-Back"
        case .activeRecall: return "Active Recall"
        case .chunkingTraining: return "Chunking Training"
        case .prospectiveMemory: return "Prospective Memory"
        case .memoryPalace: return "Memory Palace"
        case .reactionTime: return "Reaction Time"
        case .sequentialMemory: return "Number Memory"
        case .mathSpeed: return "Math Speed"
        case .speedMatch: return "Speed Match"
        case .visualMemory: return "Visual Memory"
        case .colorMatch: return "Color Match"
        case .wordScramble: return "Word Scramble"
        case .memoryChain: return "Memory Chain"
        }
    }

    var icon: String {
        switch self {
        case .spacedRepetition: return "rectangle.on.rectangle.angled"
        case .dualNBack: return "square.grid.3x3"
        case .activeRecall: return "brain.head.profile"
        case .chunkingTraining: return "square.grid.4x3.fill"
        case .prospectiveMemory: return "clock.badge.checkmark"
        case .memoryPalace: return "building.columns.fill"
        case .reactionTime: return "bolt.fill"
        case .sequentialMemory: return "number.circle.fill"
        case .mathSpeed: return "multiply.circle.fill"
        case .speedMatch: return "bolt.square.fill"
        case .visualMemory: return "square.grid.3x3.fill"
        case .colorMatch: return "paintpalette.fill"
        case .wordScramble: return "textformat.abc.dottedunderline"
        case .memoryChain: return "link.circle.fill"
        }
    }

    var description: String {
        switch self {
        case .spacedRepetition: return "Adaptive flashcard system"
        case .dualNBack: return "Working memory training"
        case .activeRecall: return "Real-world memory challenges"
        case .chunkingTraining: return "Multiply memory capacity with chunking"
        case .prospectiveMemory: return "Remember to do things in the future"
        case .memoryPalace: return "Method of loci spatial memory"
        case .reactionTime: return "Test and improve processing speed"
        case .sequentialMemory: return "Remember digits shown one at a time"
        case .mathSpeed: return "Solve multiplication problems fast"
        case .speedMatch: return "Match symbols as fast as you can"
        case .visualMemory: return "Remember the pattern of highlighted tiles"
        case .colorMatch: return "Stroop effect color-word challenge"
        case .wordScramble: return "Unscramble words against the clock"
        case .memoryChain: return "Remember growing sequences of items"
        }
    }
}

// MARK: - Card Category

enum CardCategory: String, Codable, CaseIterable, Identifiable {
    case numbers, words, sequences, faces, locations
    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .numbers: return "Number Sequences"
        case .words: return "Word Lists"
        case .sequences: return "Daily Scenarios"
        case .faces: return "Face-Name Pairs"
        case .locations: return "Location Sequences"
        }
    }

    var icon: String {
        switch self {
        case .numbers: return "number"
        case .words: return "textformat.abc"
        case .sequences: return "person.2"
        case .faces: return "face.smiling"
        case .locations: return "map"
        }
    }

    var isPro: Bool {
        self != .numbers
    }
}

// MARK: - Education Category

enum EduCategory: String, Codable, CaseIterable, Identifiable {
    case socialMedia, cannabis, sleep, neuroplasticity, techniques
    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .socialMedia: return "Social Media"
        case .cannabis: return "Cannabis"
        case .sleep: return "Sleep"
        case .neuroplasticity: return "Neuroplasticity"
        case .techniques: return "Techniques"
        }
    }

    var icon: String {
        switch self {
        case .socialMedia: return "iphone"
        case .cannabis: return "leaf"
        case .sleep: return "moon.zzz"
        case .neuroplasticity: return "brain"
        case .techniques: return "lightbulb"
        }
    }
}

// MARK: - Challenge Type

enum ChallengeType: String, Codable, CaseIterable, Identifiable {
    case storyRecall, instructionRecall, patternRecognition, conversationRecall
    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .storyRecall: return "Story Recall"
        case .instructionRecall: return "Instruction Recall"
        case .patternRecognition: return "Pattern Recognition"
        case .conversationRecall: return "Conversation Recall"
        }
    }
}

// MARK: - User Focus Goal

enum UserFocusGoal: String, Codable, CaseIterable, Identifiable {
    case attentionShot = "attention"
    case loseFocus = "focus"
    case forgetInstantly = "forget"
    case getSharper = "sharper"
    case screenTimeFrying = "screentime"
    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .attentionShot: return "I can't focus like I used to"
        case .loseFocus: return "I lose my train of thought easily"
        case .forgetInstantly: return "I forget things too quickly"
        case .getSharper: return "I want to stay mentally sharp"
        case .screenTimeFrying: return "My screen time is out of control"
        }
    }

    var icon: String {
        switch self {
        case .attentionShot: return "brain.head.profile"
        case .loseFocus: return "eye.slash"
        case .forgetInstantly: return "wind"
        case .getSharper: return "bolt.fill"
        case .screenTimeFrying: return "iphone.gen3.slash"
        }
    }

    var emoji: String {
        switch self {
        case .attentionShot: return "🧠"
        case .loseFocus: return "💭"
        case .forgetInstantly: return "💨"
        case .getSharper: return "⚡️"
        case .screenTimeFrying: return "📱"
        }
    }
}

// MARK: - Self Rating

enum SelfRating: Int, CaseIterable {
    case again = 0, hard = 1, good = 2, easy = 3

    var displayName: String {
        switch self {
        case .again: return "Again"
        case .hard: return "Hard"
        case .good: return "Good"
        case .easy: return "Easy"
        }
    }
}

// MARK: - User Level

enum UserLevel {
    static let maxLevel = 20

    static func name(for level: Int) -> String {
        switch level {
        case 1: return "Beginner Brain"
        case 2: return "Curious Mind"
        case 3: return "Quick Thinker"
        case 4: return "Memory Apprentice"
        case 5: return "Focus Fighter"
        case 6: return "Pattern Spotter"
        case 7: return "Recall Rookie"
        case 8: return "Brain Builder"
        case 9: return "Mind Sharpener"
        case 10: return "Cognitive Climber"
        case 11: return "Neural Navigator"
        case 12: return "Synapse Surfer"
        case 13: return "Memory Machine"
        case 14: return "Brain Storm"
        case 15: return "Mind Master"
        case 16: return "Cortex Commander"
        case 17: return "Neuron King"
        case 18: return "Memory Titan"
        case 19: return "Cognitive Legend"
        case 20: return "Brain God"
        default: return level > 20 ? "Brain God" : "Beginner Brain"
        }
    }

    static func xpRequired(for level: Int) -> Int {
        guard level > 1 else { return 0 }
        // Exponential curve: each level takes ~40% more XP
        return Int(200 * pow(1.4, Double(level - 2)))
    }

    static func level(for xp: Int) -> Int {
        var lvl = 1
        while lvl < maxLevel && xp >= xpRequired(for: lvl + 1) {
            lvl += 1
        }
        return lvl
    }
}
