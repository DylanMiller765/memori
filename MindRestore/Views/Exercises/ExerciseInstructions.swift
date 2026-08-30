import SwiftUI

// MARK: - First-run tracking
//
// A game explains itself once. After that the player already knows it, and a
// forced instruction screen is friction on a loop they're doing to earn an
// unlock — so the gate only fires on the very first play of each game.

enum ExerciseFirstRun {
    private static let prefix = "exercise.hasPlayed."

    static func hasPlayed(_ type: ExerciseType) -> Bool {
        UserDefaults.standard.bool(forKey: prefix + type.rawValue)
    }

    static func markPlayed(_ type: ExerciseType) {
        UserDefaults.standard.set(true, forKey: prefix + type.rawValue)
    }

    #if DEBUG
    /// Lets QA replay the first-run path without deleting the app.
    static func resetAll() {
        for type in ExerciseType.allCases {
            UserDefaults.standard.removeObject(forKey: prefix + type.rawValue)
        }
    }
    #endif
}

// MARK: - How to play

extension ExerciseType {
    /// Two or three lines, second person, describing the actual mechanic.
    /// Deliberately short — this sits between a blocked app and the rep.
    var howToPlay: [String] {
        switch self {
        case .spacedRepetition:
            return ["Cards you get wrong come back sooner.",
                    "Answer honestly — guessing teaches you nothing."]
        case .dualNBack:
            return ["Watch the square and listen to the letter.",
                    "Tap when either matches what came N steps back.",
                    "It feels impossible at first. That's the point."]
        case .activeRecall:
            return ["Read the scenario, then recall it from memory.",
                    "No peeking back — retrieval is the exercise."]
        case .chunkingTraining:
            return ["Digits appear in small groups.",
                    "Remember them as chunks, not single numbers.",
                    "Then type the whole string back."]
        case .prospectiveMemory:
            return ["You'll be given something to do later.",
                    "Carry on with the task, then do it at the right moment."]
        case .memoryPalace:
            return ["Place each item somewhere in the room.",
                    "Walk the route back to recall them in order."]
        case .reactionTime:
            return ["Wait for the colour to change.",
                    "Tap the instant it does. Tap early and it resets."]
        case .sequentialMemory:
            return ["Digits appear one at a time.",
                    "Type them back in the same order.",
                    "Each round adds one more."]
        case .mathSpeed:
            return ["Solve as many as you can before time runs out.",
                    "Speed matters more than perfection."]
        case .speedMatch:
            return ["Does this shape match the one before it?",
                    "Answer yes or no as fast as you can."]
        case .visualMemory:
            return ["Tiles flash on the grid.",
                    "Tap the ones that lit up.",
                    "The grid grows as you go."]
        case .colorMatch:
            return ["The word and its colour may disagree.",
                    "Answer about the colour, not the word."]
        case .wordScramble:
            return ["Unscramble the letters into a real word.",
                    "Longer words score more."]
        case .memoryChain:
            return ["Each round adds an item to the chain.",
                    "Repeat the whole chain back in order."]
        case .chimpTest:
            return ["Numbers appear on screen, then hide.",
                    "Tap them in order from lowest to highest.",
                    "Chimps beat most humans at this."]
        case .verbalMemory:
            return ["You'll see one word at a time.",
                    "Say whether you've seen it before in this round."]
        }
    }
}

// MARK: - Instructions screen

struct ExerciseInstructionsView: View {
    let type: ExerciseType
    let onStart: () -> Void

    @State private var appeared = false

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Spacer().frame(height: 12)

            HStack(spacing: 8) {
                Image(systemName: "sparkles")
                    .font(.system(size: 11, weight: .bold))
                Text("FIRST TIME")
                    .font(.system(size: 11, weight: .heavy, design: .monospaced))
                    .tracking(1.4)
            }
            .foregroundStyle(AppColors.accent)

            Text(type.displayName)
                .font(.brand(size: 36, weight: .heavy))
                .foregroundStyle(AppColors.textPrimary)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.top, 8)

            Text(type.description)
                .font(.system(size: 16, weight: .semibold, design: .rounded))
                .foregroundStyle(AppColors.textSecondary)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.top, 6)

            VStack(alignment: .leading, spacing: 16) {
                ForEach(Array(type.howToPlay.enumerated()), id: \.offset) { index, line in
                    HStack(alignment: .top, spacing: 13) {
                        Text("\(index + 1)")
                            .font(.system(size: 13, weight: .heavy, design: .monospaced))
                            .foregroundStyle(AppColors.accent)
                            .frame(width: 26, height: 26)
                            .background(Circle().fill(AppColors.accent.opacity(0.14)))

                        Text(line)
                            .font(.system(size: 16, weight: .semibold, design: .rounded))
                            .foregroundStyle(AppColors.textPrimary)
                            .fixedSize(horizontal: false, vertical: true)
                            .padding(.top, 3)
                    }
                }
            }
            .padding(.top, 30)
            .opacity(appeared ? 1 : 0)
            .offset(y: appeared ? 0 : 10)

            Spacer(minLength: 20)

            Button(action: onStart) {
                Text("I'm ready")
                    .gradientButton()
            }

            Text("You'll only see this once")
                .font(.system(size: 12, weight: .semibold, design: .rounded))
                .foregroundStyle(AppColors.textTertiary)
                .frame(maxWidth: .infinity, alignment: .center)
                .padding(.top, 10)
        }
        .padding(.horizontal, 28)
        .padding(.bottom, 20)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
        .background(AppColors.pageBg.ignoresSafeArea())
        .onAppear {
            withAnimation(.easeOut(duration: 0.4).delay(0.1)) { appeared = true }
        }
    }
}

// MARK: - Gate

/// Shows the instructions before `content` the first time a game is played,
/// then never again. Wraps every launch path — Train tab and focus unlock —
/// because both resolve through the same exercise destination.
struct ExerciseFirstRunGate<Content: View>: View {
    let type: ExerciseType
    @ViewBuilder let content: () -> Content

    @State private var showingInstructions: Bool

    init(type: ExerciseType, @ViewBuilder content: @escaping () -> Content) {
        self.type = type
        self.content = content
        _showingInstructions = State(initialValue: !ExerciseFirstRun.hasPlayed(type))
    }

    var body: some View {
        if showingInstructions {
            ExerciseInstructionsView(type: type) {
                ExerciseFirstRun.markPlayed(type)
                withAnimation(.easeInOut(duration: 0.25)) {
                    showingInstructions = false
                }
            }
        } else {
            content()
        }
    }
}
