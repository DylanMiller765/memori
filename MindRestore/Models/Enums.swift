import Foundation

// MARK: - Subscription Status

enum SubscriptionStatus: String, Codable {
    case free, trial, subscribed, lifetime
}

// MARK: - Exercise Type

enum ExerciseType: String, Codable, CaseIterable, Identifiable {
    case spacedRepetition, dualNBack, activeRecall
    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .spacedRepetition: return "Spaced Repetition"
        case .dualNBack: return "Dual N-Back"
        case .activeRecall: return "Active Recall"
        }
    }

    var icon: String {
        switch self {
        case .spacedRepetition: return "rectangle.on.rectangle.angled"
        case .dualNBack: return "square.grid.3x3"
        case .activeRecall: return "brain.head.profile"
        }
    }

    var description: String {
        switch self {
        case .spacedRepetition: return "Adaptive flashcard system"
        case .dualNBack: return "Working memory training"
        case .activeRecall: return "Real-world memory challenges"
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
    case forgetThings = "forget"
    case cantFocus = "focus"
    case gettingWorse = "worse"
    case staySharp = "sharp"
    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .forgetThings: return "I forget things people tell me"
        case .cantFocus: return "I can't focus or concentrate"
        case .gettingWorse: return "I feel like my memory is getting worse"
        case .staySharp: return "I want to stay sharp"
        }
    }

    var icon: String {
        switch self {
        case .forgetThings: return "bubble.left.and.exclamationmark.bubble.right"
        case .cantFocus: return "eye.slash"
        case .gettingWorse: return "arrow.down.right"
        case .staySharp: return "bolt.fill"
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
