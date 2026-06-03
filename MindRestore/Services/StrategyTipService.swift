//
//  StrategyTipService.swift
//  MindRestore
//
//  Provides post-exercise memory strategy tips grounded in cognitive science.
//  Tips teach real techniques used by memory champions and backed by research.
//

import Foundation

// MARK: - Strategy Tip

struct StrategyTip: Identifiable, Equatable {
    let id = UUID()
    let title: String
    let body: String
    let technique: MemoryTechnique
    let researchNote: String
}

// MARK: - Memory Technique

enum MemoryTechnique: String, CaseIterable {
    case chunking
    case methodOfLoci
    case faceNameAssociation
    case visualization
    case activeRetrieval
    case spacedPractice
    case elaborativeEncoding
    case dualCoding
}

// MARK: - Strategy Tip Service

@MainActor @Observable
final class StrategyTipService {

    // MARK: - Singleton

    static let shared = StrategyTipService()

    // MARK: - State

    private(set) var lastTip: StrategyTip?

    // MARK: - Tip Database

    private let tipsByDomain: [ExerciseDomain: [StrategyTip]] = [

        // MARK: Digits — Chunking & Number Systems

        .digits: [
            StrategyTip(
                title: "Chunking",
                body: "Try grouping numbers into meaningful chunks — phone numbers, dates, ages. Memory champions use this to remember 100+ digits.",
                technique: .chunking,
                researchNote: "Research shows our working memory holds about 4 chunks at a time (Cowan, 2001). By grouping digits into larger chunks, you multiply your capacity."
            ),
            StrategyTip(
                title: "Number-Shape System",
                body: "Give each digit a shape: 1 is a candle, 2 is a swan, 3 is a heart on its side. Turn number sequences into vivid stories with these shapes.",
                technique: .visualization,
                researchNote: "Research shows that converting abstract information into visual images dramatically improves recall — our brains evolved to remember scenes, not strings of digits."
            ),
            StrategyTip(
                title: "Rhythm & Grouping",
                body: "Say the numbers aloud in groups of 3-4 with a rhythm, like a phone number. Auditory patterns create an extra memory trace beyond the visual one.",
                technique: .dualCoding,
                researchNote: "Research on dual coding shows that encoding information through multiple senses (visual + auditory) creates redundant memory pathways, making recall more reliable."
            ),
            StrategyTip(
                title: "Personal Connections",
                body: "Turn numbers into personally meaningful data — 1987 is a birth year, 42 is the answer to everything, 314 is pi. Meaning makes memories stick.",
                technique: .elaborativeEncoding,
                researchNote: "Research shows that connecting new information to existing knowledge (elaborative encoding) produces significantly stronger memories than rote repetition."
            ),
            StrategyTip(
                title: "Major System Preview",
                body: "Advanced memorizers convert digits to consonant sounds, then add vowels to make words: 7-2 becomes 'cane' (c=7, n=2). Even partial use of this helps.",
                technique: .chunking,
                researchNote: "Research shows the Major System, used since the 1600s, lets trained memorizers encode 80+ digits per minute by leveraging verbal memory alongside numerical memory."
            )
        ],

        // MARK: Words — Method of Loci & Story Method

        .words: [
            StrategyTip(
                title: "Method of Loci",
                body: "Place each word at a location in your home. Walk through mentally to recall. This technique is used by 90% of memory champions.",
                technique: .methodOfLoci,
                researchNote: "Research shows the Method of Loci can improve recall by 2-3x after just 30 minutes of practice (Maguire et al., 2003). It leverages your brain's powerful spatial memory system."
            ),
            StrategyTip(
                title: "Story Chaining",
                body: "Link each word to the next in a vivid, bizarre story. 'Apple' then 'rocket'? An apple launches like a rocket. The weirder, the stickier.",
                technique: .elaborativeEncoding,
                researchNote: "Research shows that creating narrative connections between items improves free recall by 6-7x compared to simple repetition — stories give structure to otherwise random information."
            ),
            StrategyTip(
                title: "Vivid Imagery",
                body: "Don't just read each word — see it. Make the image huge, colorful, moving, or absurd. A tiny gray 'elephant' is forgettable; a neon-pink one dancing is not.",
                technique: .visualization,
                researchNote: "Research on the bizarreness effect shows that unusual, vivid mental images are remembered significantly better than ordinary ones, especially in mixed lists."
            ),
            StrategyTip(
                title: "Emotional Anchoring",
                body: "Connect each word to a feeling or personal memory. 'Bridge' might remind you of a specific bridge you crossed on vacation. Emotion supercharges encoding.",
                technique: .elaborativeEncoding,
                researchNote: "Research shows that emotionally-tagged memories activate the amygdala during encoding, leading to significantly stronger consolidation during sleep."
            )
        ],

        // MARK: Faces — Name-Feature Association

        .faces: [
            StrategyTip(
                title: "Feature-Name Link",
                body: "Link the name to a visual feature. 'Sandy has sandy-colored hair.' Exaggerate the link — bizarre associations stick better.",
                technique: .faceNameAssociation,
                researchNote: "Research shows that creating a visual bridge between a name and a facial feature improves name recall by over 80% compared to simple repetition (Morris et al., 2005)."
            ),
            StrategyTip(
                title: "Name Repetition Strategy",
                body: "When you learn a name, use it immediately: 'Nice to meet you, Sarah.' Then think of someone you know with that name. Two anchors beat one.",
                technique: .elaborativeEncoding,
                researchNote: "Research shows that generating associations to known people with the same name creates retrieval cues that make later recall significantly more likely."
            ),
            StrategyTip(
                title: "Caricature Method",
                body: "Mentally exaggerate the most distinctive facial feature — big nose gets bigger, unique eyebrows become bushier. This sharpens your mental model of the face.",
                technique: .visualization,
                researchNote: "Research on face recognition shows that focusing on distinctive features (rather than trying to memorize the whole face) produces the strongest encoding for later identification."
            ),
            StrategyTip(
                title: "Name-Meaning Decoding",
                body: "Many names have hidden meanings: 'Craig' means rock, 'Donna' means lady. Picture a rock with Craig's face on it. Meaning gives the name a visual hook.",
                technique: .faceNameAssociation,
                researchNote: "Research shows that transforming abstract information (like names) into concrete, imageable forms dramatically improves recall — a core principle of mnemonic systems."
            )
        ],

        // MARK: Locations — Spatial Memory

        .locations: [
            StrategyTip(
                title: "Mental Journey",
                body: "Place each word at a location in your home. Walk through mentally to recall. This technique is used by 90% of memory champions.",
                technique: .methodOfLoci,
                researchNote: "Research shows our spatial memory is remarkably powerful — even after a single walkthrough, people can remember over 90% of locations they visited."
            ),
            StrategyTip(
                title: "Landmark Anchoring",
                body: "For each location in the path, pick one vivid landmark and imagine interacting with it. Don't just see the park — imagine sitting on a specific bench.",
                technique: .visualization,
                researchNote: "Research on cognitive maps shows that interactive mental imagery creates stronger place-memory associations than passive observation."
            ),
            StrategyTip(
                title: "Route Narration",
                body: "Narrate the path as a story: 'I leave the library, turn left past the fountain, and arrive at the red cafe.' Verbal and spatial encoding together are powerful.",
                technique: .dualCoding,
                researchNote: "Research shows that narrating spatial information engages both the hippocampus (spatial) and language networks, creating richer, more retrievable memory traces."
            )
        ],

        // MARK: Patterns — Visual-Motor Encoding

        .patterns: [
            StrategyTip(
                title: "Trace & Draw",
                body: "Don't just look at patterns — trace them with your eyes and imagine drawing them. Visual-motor encoding creates stronger memories.",
                technique: .visualization,
                researchNote: "Research shows that motor imagery activates overlapping brain regions as actual movement, creating an additional encoding pathway beyond pure visual memory."
            ),
            StrategyTip(
                title: "Shape Recognition",
                body: "Look for familiar shapes within the pattern — does it look like an L? A zigzag? A house? Naming the shape compresses the pattern into a single chunk.",
                technique: .chunking,
                researchNote: "Research shows that expert chess players remember board positions not as individual pieces but as familiar patterns — chunking visual information works the same way."
            ),
            StrategyTip(
                title: "Spatial Coordinates",
                body: "Try encoding patterns as coordinates: 'top-left, middle-center, bottom-right.' Verbal labels give your spatial memory a backup system.",
                technique: .dualCoding,
                researchNote: "Research shows that verbally labeling spatial positions provides a secondary retrieval route, improving accuracy especially for complex patterns."
            )
        ],

        // MARK: N-Back — Working Memory Strategies

        .nBack: [
            StrategyTip(
                title: "Subvocal Rehearsal",
                body: "Quietly repeat the last few items to yourself in a loop. This keeps them fresh in your phonological loop — your brain's short-term audio buffer.",
                technique: .activeRetrieval,
                researchNote: "Research on working memory shows the phonological loop can maintain about 2 seconds of speech. Subvocal rehearsal refreshes this buffer, keeping items accessible."
            ),
            StrategyTip(
                title: "Focus on the Flow",
                body: "Don't try to remember everything — focus on the rhythm of matches. With practice, your brain starts detecting matches automatically. Trust the process.",
                technique: .activeRetrieval,
                researchNote: "Research shows that N-Back training transfers to improved fluid intelligence and working memory capacity. Consistent practice matters more than perfection."
            ),
            StrategyTip(
                title: "Minimize Distractions",
                body: "N-Back taxes your working memory to its limit. A quiet environment with no interruptions can improve your score significantly. Every bit of focus counts.",
                technique: .activeRetrieval,
                researchNote: "Research shows that working memory performance is highly sensitive to cognitive load — even background noise can reduce N-Back accuracy by 10-15%."
            )
        ],

        // MARK: Active Recall — Retrieval Practice

        .activeRecall: [
            StrategyTip(
                title: "Retrieval Practice",
                body: "Testing yourself beats re-reading 3x over. Every time you struggle to recall, the memory gets stronger.",
                technique: .activeRetrieval,
                researchNote: "Research shows that retrieval practice produces 50% better long-term retention than re-studying the same material (Roediger & Karpicke, 2006)."
            ),
            StrategyTip(
                title: "Desirable Difficulty",
                body: "If recall feels effortful, that's a good sign. Easy retrieval doesn't strengthen memories much — it's the struggle that builds durable learning.",
                technique: .activeRetrieval,
                researchNote: "Research on desirable difficulties (Bjork, 1994) shows that conditions making learning feel harder often produce better long-term retention."
            ),
            StrategyTip(
                title: "Self-Explanation",
                body: "After reading, don't just try to list facts. Explain the 'why' behind them. Deeper processing creates more retrieval routes to the same memory.",
                technique: .elaborativeEncoding,
                researchNote: "Research shows that self-explanation during study produces deeper understanding and better retention than passive review, even when study time is equal."
            ),
            StrategyTip(
                title: "Pre-Test Effect",
                body: "Trying to answer before you know the answer primes your brain to learn it better when revealed. Failed retrieval attempts are not wasted — they set the stage.",
                technique: .activeRetrieval,
                researchNote: "Research shows that unsuccessful retrieval attempts enhance subsequent learning of the correct answer — the pre-testing effect (Kornell et al., 2009)."
            )
        ],

        // MARK: General Training

        .generalTraining: [
            StrategyTip(
                title: "Spaced Practice",
                body: "Reviewing just before you forget is the sweet spot. That's why we schedule your reviews — trust the timing.",
                technique: .spacedPractice,
                researchNote: "Research shows that spaced repetition can make memories last months or years with minimal review sessions — the spacing effect is one of the most robust findings in memory science."
            ),
            StrategyTip(
                title: "Interleaving",
                body: "Mixing different exercise types in one session feels harder but produces better learning than doing the same type repeatedly. Variety builds flexibility.",
                technique: .activeRetrieval,
                researchNote: "Research shows that interleaved practice improves the ability to discriminate between problem types and select appropriate strategies — key skills for real-world memory use."
            ),
            StrategyTip(
                title: "Sleep & Memory",
                body: "Your brain consolidates memories during sleep. A training session before bed can be especially effective — let your brain do the heavy lifting overnight.",
                technique: .spacedPractice,
                researchNote: "Research shows that memories practiced before sleep show significantly better retention than those practiced in the morning, due to sleep-dependent memory consolidation."
            ),
            StrategyTip(
                title: "Consistency Over Intensity",
                body: "10 minutes daily beats an hour once a week. Your brain builds memory skills through regular, modest practice — not marathon sessions.",
                technique: .spacedPractice,
                researchNote: "Research shows that distributed practice produces substantially better long-term retention than massed practice, even when total study time is identical."
            )
        ]
    ]

    // MARK: - Init

    private init() {}

    private var fallbackTip: StrategyTip {
        StrategyTip(
            title: "Practice Makes Progress",
            body: "Consistent practice is the single most effective way to improve memory.",
            technique: .spacedPractice,
            researchNote: "Ebbinghaus (1885) — spaced repetition strengthens long-term retention."
        )
    }

    // MARK: - Public API

    /// Returns a random relevant strategy tip for the exercise type just completed.
    func tip(for domain: ExerciseDomain) -> StrategyTip {
        let tips = tipsByDomain[domain] ?? tipsByDomain[.generalTraining] ?? []
        guard let selected = tips.randomElement() else {
            return fallbackTip
        }
        lastTip = selected
        return selected
    }

    /// Returns a tip for a specific memory technique, if available for the domain.
    func tip(for domain: ExerciseDomain, technique: MemoryTechnique) -> StrategyTip? {
        let tips = tipsByDomain[domain] ?? []
        let filtered = tips.filter { $0.technique == technique }
        let selected = filtered.randomElement()
        if let selected {
            lastTip = selected
        }
        return selected
    }

    /// Returns all tips available for a domain.
    func allTips(for domain: ExerciseDomain) -> [StrategyTip] {
        return tipsByDomain[domain] ?? []
    }

    /// Returns a general tip about memory and learning (not domain-specific).
    func generalTip() -> StrategyTip {
        let generalTips = tipsByDomain[.generalTraining] ?? []
        guard let selected = generalTips.randomElement() else {
            return fallbackTip
        }
        lastTip = selected
        return selected
    }

    /// Returns a tip that the user hasn't seen recently, for the given domain.
    /// Tracks shown tip IDs in memory (resets on app restart — intentionally lightweight).
    private var recentlyShownIDs: Set<UUID> = []

    func freshTip(for domain: ExerciseDomain) -> StrategyTip {
        let tips = tipsByDomain[domain] ?? tipsByDomain[.generalTraining] ?? []
        let unseen = tips.filter { !recentlyShownIDs.contains($0.id) }

        let selected: StrategyTip
        if let fresh = unseen.randomElement() {
            selected = fresh
        } else {
            // All tips seen — reset and pick any
            recentlyShownIDs.removeAll()
            selected = tips.randomElement() ?? fallbackTip
        }

        recentlyShownIDs.insert(selected.id)
        lastTip = selected
        return selected
    }
}
