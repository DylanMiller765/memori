import Foundation

enum EducationContent {
    static let cards: [PsychoEducationCard] = [
        // Social Media
        PsychoEducationCard(
            title: "Your Brain Thinks Your Phone Is Its Memory",
            body: "Researchers have found that we increasingly treat our devices as external memory banks — a phenomenon called 'cognitive offloading.' A 2021 study published in Memory & Cognition showed that people who relied on their phones to store information were significantly worse at remembering that information later, even when they tried.\n\nThis isn't laziness — it's your brain being efficient. When it knows information is stored somewhere accessible, it literally doesn't bother encoding it deeply. The problem? This creates a dependency loop. The less you practice remembering, the weaker those neural pathways become.\n\nSpaced repetition training reverses this by forcing your brain to retrieve information actively, strengthening the exact pathways that cognitive offloading weakens.",
            category: .socialMedia,
            sortOrder: 1
        ),
        PsychoEducationCard(
            title: "Why You Can't Remember What You Just Scrolled Past",
            body: "Social media feeds are designed for shallow processing. You scroll, glance, react, and move on — rarely spending more than 2-3 seconds on any single piece of content. Research from Stanford's Communication Lab shows this rapid-fire consumption trains your brain to process information at the shallowest possible level.\n\nDeep encoding — the kind that creates lasting memories — requires sustained attention, elaboration, and connection to existing knowledge. When you scroll through 300 posts in 20 minutes, your brain is doing none of that. It's in 'skim mode.'\n\nThe result? You can spend an hour on social media and remember almost nothing specific. Active recall training teaches your brain to shift back into deep processing mode.",
            category: .socialMedia,
            sortOrder: 2
        ),
        PsychoEducationCard(
            title: "TikTok Brain: How Short-Form Video Rewires Attention",
            body: "A 2023 study in Nature Communications found that heavy short-form video users showed measurably reduced working memory capacity — the ability to hold and manipulate information in your mind. Participants who watched over 2 hours of short-form video daily performed 15-20% worse on working memory tasks.\n\nThe mechanism is straightforward: your brain adapts to whatever demands you place on it. If you spend hours consuming content in 15-60 second bursts, your attention system literally recalibrates to that timeframe. Sustaining focus for longer periods becomes harder because your brain has been trained not to.\n\nDual N-Back training directly targets this by requiring sustained, focused attention over minutes at a time, gradually rebuilding working memory capacity.",
            category: .socialMedia,
            sortOrder: 3
        ),
        PsychoEducationCard(
            title: "The Mood-Memory Connection",
            body: "Multiple studies have linked heavy social media use to increased anxiety, depression, and negative self-comparison. What's less discussed is how these mood states directly impair memory. Research from Harvard's Department of Psychology shows that elevated cortisol levels — common during anxiety and stress — literally interfere with the hippocampus's ability to form new memories.\n\nWhen you're doom-scrolling and feeling increasingly anxious about the world, your brain is simultaneously becoming worse at remembering. It's a double hit: the scrolling prevents deep encoding, and the mood state it creates actively disrupts the memory hardware.\n\nEven 10 minutes of focused cognitive training can reduce cortisol levels while simultaneously strengthening memory circuits.",
            category: .socialMedia,
            sortOrder: 4
        ),
        PsychoEducationCard(
            title: "Your Brain at 13 vs. Your Brain on Social Media at 13",
            body: "The ABCD Study — the largest long-term study of brain development in the United States — has been tracking over 11,000 children since 2018. Early findings published in JAMA Pediatrics show that adolescents who frequently check social media show distinct patterns of brain development, particularly in areas responsible for cognitive control and memory.\n\nSpecifically, regions associated with self-regulation and sustained attention show different development trajectories in heavy social media users. For young adults (18-25), this means your brain may have literally developed differently because of social media use during critical developmental periods.\n\nThe good news: neuroplasticity means your brain can still change. Consistent cognitive training creates new neural pathways regardless of how your brain developed.",
            category: .socialMedia,
            sortOrder: 5
        ),

        // Cannabis
        PsychoEducationCard(
            title: "What THC Actually Does to Your Hippocampus",
            body: "THC — the primary psychoactive compound in cannabis — binds to CB1 receptors that are densely concentrated in the hippocampus, your brain's memory encoding center. When THC activates these receptors, it directly disrupts the process of transferring information from short-term to long-term memory.\n\nA 2022 study in Biological Psychiatry: Cognitive Neuroscience and Neuroimaging showed that regular cannabis users had significantly reduced hippocampal volume compared to non-users, with the degree of reduction correlating with frequency of use.\n\nCritically, the hippocampus is also where spaced repetition training has its strongest effect. By regularly challenging your memory encoding and retrieval, you're essentially providing targeted exercise for the exact brain region that THC impacts.",
            category: .cannabis,
            sortOrder: 6
        ),
        PsychoEducationCard(
            title: "63% of Heavy Users Show Reduced Brain Activity",
            body: "A landmark 2025 study published in JAMA Network Open examined brain imaging data from over 1,000 cannabis users and found that 63% of heavy users (daily or near-daily) showed significantly reduced activity in brain regions responsible for memory, attention, and executive function.\n\nThe study used functional MRI to measure brain activity during memory tasks and found that heavy users required notably more neural effort to achieve the same memory performance as non-users — their brains were working harder but achieving less.\n\nHowever, the study also found that users who engaged in regular cognitive training showed less severe deficits, suggesting that active memory training may partially compensate for cannabis-related changes.",
            category: .cannabis,
            sortOrder: 7
        ),
        PsychoEducationCard(
            title: "The Sleep-Memory-Weed Triangle",
            body: "Research from UT Dallas published in 2024 revealed a critical three-way connection: cannabis use disrupts sleep architecture (specifically REM sleep), and disrupted sleep severely impairs memory consolidation — the process by which your brain converts short-term memories into long-term ones during sleep.\n\nCannabis users often report that they 'don't dream' or dream less. This is because THC suppresses REM sleep, the exact sleep stage during which memory consolidation is most active. Even if you feel like you slept well, your brain may not have completed its nightly memory processing.\n\nAfter reducing or stopping cannabis use, sleep architecture typically normalizes within 2-4 weeks, and memory consolidation improves accordingly. Cognitive training accelerates this recovery.",
            category: .cannabis,
            sortOrder: 8
        ),
        PsychoEducationCard(
            title: "Good News: Your Brain Can Recover",
            body: "Perhaps the most encouraging finding in cannabis and memory research: cognitive deficits are largely reversible. A 2023 meta-analysis in Neuropsychology Review examined 43 studies and found that most memory impairments associated with cannabis use showed significant improvement after 72 hours of abstinence, with near-complete recovery for most users within 30 days.\n\nEven more promising: users who actively trained their memory during the recovery period showed faster and more complete recovery than those who simply abstained. The combination of reduced use and targeted cognitive training produced the best outcomes.\n\nThe brain's hippocampus is one of the few brain regions capable of neurogenesis — growing new neurons — throughout adulthood. With the right training, you can literally rebuild.",
            category: .cannabis,
            sortOrder: 9
        ),
        PsychoEducationCard(
            title: "CBD vs THC: Different Effects on Memory",
            body: "Not all cannabinoids affect memory equally. While THC impairs memory encoding by disrupting hippocampal function, CBD (cannabidiol) appears to have a more nuanced — and potentially protective — relationship with memory.\n\nA 2022 review in Frontiers in Pharmacology found that CBD may actually counteract some of THC's memory-impairing effects. Products with higher CBD-to-THC ratios were associated with less severe memory impairment than high-THC, low-CBD products.\n\nThis doesn't mean CBD enhances memory — it means the specific composition of cannabis products matters significantly. High-THC concentrates and extracts, which have become increasingly popular, may pose greater memory risks than balanced or CBD-dominant products.\n\nRegardless of what you use, consistent memory training helps maintain cognitive function.",
            category: .cannabis,
            sortOrder: 10
        ),

        // Techniques
        PsychoEducationCard(
            title: "Spaced Repetition: The Only Proven Memory Hack",
            body: "In 1885, Hermann Ebbinghaus discovered the 'forgetting curve' — the predictable rate at which memories decay without reinforcement. His insight led to spaced repetition: reviewing information at strategically increasing intervals to move it from short-term to long-term memory.\n\nA comprehensive 2013 review by John Dunlosky in Psychological Science in the Public Interest rated spaced repetition as one of only two study techniques with 'high utility' across all conditions tested. It works for all types of information, all ages, and all skill levels.\n\nThe key insight is timing. Reviewing too soon wastes time; reviewing too late means you've forgotten. The SM-2 algorithm (used in this app) calculates the optimal review moment — right at the edge of forgetting — to maximize memory strengthening with minimum effort.",
            category: .techniques,
            sortOrder: 11
        ),
        PsychoEducationCard(
            title: "Active Recall: Why Testing Yourself Beats Re-Reading",
            body: "In a landmark 2006 study, researchers Roediger and Karpicke demonstrated something counterintuitive: students who tested themselves on material remembered 50% more after one week than students who spent the same time re-reading the material.\n\nThis is the 'testing effect' — the act of retrieving information from memory actually strengthens that memory more than reviewing or re-studying does. Every time you successfully recall something, the neural pathway for that memory becomes stronger and faster.\n\nThis is why MindRestore's active recall challenges present you with information and then ask you to retrieve it, rather than simply having you review flashcards passively. The struggle of trying to remember is literally the workout your memory needs.",
            category: .techniques,
            sortOrder: 12
        ),
        PsychoEducationCard(
            title: "The Dual N-Back: Training Fluid Intelligence",
            body: "The Dual N-Back task is one of the most studied working memory training exercises in cognitive science. A 2008 study by Jaeggi et al., published in PNAS, showed that consistent Dual N-Back training improved fluid intelligence — the ability to reason and solve novel problems.\n\nWorking memory is like your brain's RAM: it determines how much information you can hold and manipulate at once. When you train with Dual N-Back, you're expanding this capacity, which has cascading effects on attention, comprehension, and memory encoding.\n\nThe task is intentionally challenging. If it feels hard, that's the point — you're pushing your cognitive limits, just like lifting heavier weights pushes your physical limits. Most people see measurable improvement within 2-3 weeks of consistent training.",
            category: .techniques,
            sortOrder: 13
        ),
        PsychoEducationCard(
            title: "Why Consistency Beats Intensity",
            body: "A 2019 study in the Journal of Experimental Psychology compared two groups: one trained their memory for 2 hours once per week, and another trained for 15 minutes daily. After 8 weeks, the daily group showed 40% greater improvement despite spending less total time training.\n\nThis is because memory consolidation — the process of strengthening neural connections — happens during sleep and rest periods between training sessions. More frequent sessions give your brain more consolidation opportunities.\n\nAdditionally, the 'spacing effect' applies to training itself: distributed practice (little and often) consistently outperforms massed practice (long, infrequent sessions) across virtually all learning domains.\n\nThat's why MindRestore is designed around short daily sessions of 5-10 minutes. Show up every day, and your brain does the rest.",
            category: .techniques,
            sortOrder: 14
        ),
        PsychoEducationCard(
            title: "Your Memory in 30 Days: What to Expect",
            body: "Based on research across multiple cognitive training studies, here's a realistic timeline of what to expect:\n\nDays 1-7: You'll likely feel challenged, especially by Dual N-Back. Scores may be low. This is normal — you're establishing a baseline and your brain is beginning to adapt.\n\nDays 8-14: Most people notice the first improvements in working memory tasks. Spaced repetition cards start coming back more easily. You might notice slightly better focus in daily life.\n\nDays 15-21: Training starts feeling less effortful. Dual N-Back levels begin increasing. Active recall scores improve noticeably. Many users report better conversational recall.\n\nDays 22-30: Measurable improvements in memory tests typically appear around this time. The habit is solidifying. Users often report remembering names, appointments, and conversations more easily.\n\nBeyond 30 days: Continued training maintains and extends gains. Without training, improvements gradually fade over 2-3 months — which is why consistency matters.",
            category: .techniques,
            sortOrder: 15
        ),
    ]
}
