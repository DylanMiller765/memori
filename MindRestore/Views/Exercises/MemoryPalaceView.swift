//
//  MemoryPalaceView.swift
//  MindRestore
//
//  Memory Palace (Method of Loci) exercise.
//
//  Research basis:
//  - Dresler et al. 2017 (Neuron) — 6 weeks of method of loci training
//    produced durable improvements in memory performance.
//  - Maguire et al. 2003 — 90% of memory champions use this technique.
//  - The method of loci is the single most effective memory training
//    technique in the literature, leveraging the brain's powerful
//    spatial memory system.
//

import SwiftUI
import SwiftData

// MARK: - Data Models

struct PalaceLocation: Identifiable, Equatable {
    let id = UUID()
    let name: String
    let icon: String
    let description: String
}

struct Palace: Identifiable, Equatable {
    let id = UUID()
    let name: String
    let icon: String
    let tagline: String
    let color: Color
    let locations: [PalaceLocation]

    static func == (lhs: Palace, rhs: Palace) -> Bool {
        lhs.id == rhs.id
    }
}

struct ItemList: Identifiable {
    let id = UUID()
    let theme: String
    let icon: String
    let items: [String]
}

struct PlacedItem: Identifiable {
    let id = UUID()
    let location: PalaceLocation
    let item: String
    let vividImage: String
}

// MARK: - Phase

enum MemoryPalacePhase: Equatable {
    case choosePalace
    case learnRoute
    case placeItems
    case recall
    case results
}

// MARK: - ViewModel

@MainActor @Observable
final class MemoryPalaceViewModel {

    // MARK: - State

    var phase: MemoryPalacePhase = .choosePalace
    var selectedPalace: Palace?
    var learnIndex: Int = 0
    var placingIndex: Int = 0
    var recallIndex: Int = 0
    var placedItems: [PlacedItem] = []
    var userAnswers: [String] = []
    var selectedAnswer: String? = nil
    var answerOptions: [String] = []
    var showFeedback: Bool = false
    var lastAnswerCorrect: Bool = false
    var correctCount: Int = 0
    var totalCount: Int = 0
    var itemCountToUse: Int = 5
    var currentItemList: ItemList?
    var strategyTip: StrategyTip?
    var startTime: Date = .now
    var placingTimeRemaining: Double = 5.0
    var placingTimer: Timer?
    var durationSeconds: Int = 0

    // Track which palaces the user has learned
    private let learnedPalacesKey = "memoryPalace_learnedPalaces"

    // MARK: - Content

    static let palaces: [Palace] = [
        Palace(
            name: "Your Home",
            icon: "house.fill",
            tagline: "8 rooms you know by heart",
            color: AppColors.accent,
            locations: [
                PalaceLocation(name: "Entrance", icon: "door.left.hand.open", description: "You push open your front door. Feel the familiar handle, hear the creak of the hinges. The welcome mat is underfoot, scuffed from years of use."),
                PalaceLocation(name: "Kitchen", icon: "refrigerator.fill", description: "The kitchen hums with the sound of the refrigerator. Bright countertops gleam under the light. The faint smell of this morning's coffee lingers in the air."),
                PalaceLocation(name: "Living Room", icon: "sofa.fill", description: "Sunlight streams across the living room couch. A soft throw blanket is draped over one arm. The TV remote sits on the coffee table, slightly crooked."),
                PalaceLocation(name: "Bedroom", icon: "bed.double.fill", description: "Your bedroom is quiet and dim. The pillow still has the indent from last night. A stack of books teeters on the nightstand, threatening to topple."),
                PalaceLocation(name: "Bathroom", icon: "shower.fill", description: "Steam fogs the bathroom mirror. The tile floor is cool underfoot. Your toothbrush stands at attention in its holder by the sink."),
                PalaceLocation(name: "Dining Room", icon: "fork.knife", description: "The dining table is set with a single placemat. A vase of flowers sits in the center, petals just starting to curl. The chairs are tucked in neatly."),
                PalaceLocation(name: "Office", icon: "desktopcomputer", description: "Your desk is scattered with sticky notes. The monitor glows softly in standby mode. A half-empty coffee mug has left a ring stain on the wood."),
                PalaceLocation(name: "Garage", icon: "car.fill", description: "The garage smells like motor oil and old cardboard. Tools hang on the pegboard wall. A bicycle leans against stacked storage boxes in the corner.")
            ]
        ),
        Palace(
            name: "School Route",
            icon: "figure.walk",
            tagline: "8 stops on a familiar walk",
            color: AppColors.sky,
            locations: [
                PalaceLocation(name: "Front Door", icon: "door.left.hand.open", description: "You step out your front door into the crisp morning air. The porch light is still on from last night. Your neighbor's dog barks a lazy greeting."),
                PalaceLocation(name: "Sidewalk", icon: "road.lanes", description: "The sidewalk stretches ahead, cracked in the same spot it always is. Dandelions push through the gaps. Your shoes scuff against the familiar concrete."),
                PalaceLocation(name: "Park", icon: "tree.fill", description: "The park opens up with its wide green lawn. A rusty swing set creaks in the breeze. Dew still clings to the grass, soaking through your shoes."),
                PalaceLocation(name: "Bridge", icon: "bridge.fill", description: "The old wooden bridge arches over a lazy stream. Boards creak with each step. You can see minnows darting below through the gaps in the planks."),
                PalaceLocation(name: "Main Street", icon: "building.2.fill", description: "Main Street is waking up. Shop owners flip their signs to OPEN. The bakery exhales warm, yeasty air through its propped-open door."),
                PalaceLocation(name: "Cafe", icon: "cup.and.saucer.fill", description: "The corner cafe has its chalkboard menu out front. Steam rises from the espresso machine inside. The barista waves through the window as you pass."),
                PalaceLocation(name: "School Gate", icon: "building.columns.fill", description: "The tall iron school gate stands ahead, slightly ajar. Backpacks bob past in a stream of students. The morning bell echoes across the courtyard."),
                PalaceLocation(name: "Classroom", icon: "graduationcap.fill", description: "Your classroom smells like dry-erase markers and wood. Chairs scrape against linoleum as students settle in. The clock on the wall ticks steadily.")
            ]
        ),
        Palace(
            name: "Beach Walk",
            icon: "beach.umbrella.fill",
            tagline: "8 stops along the coast",
            color: AppColors.teal,
            locations: [
                PalaceLocation(name: "Parking Lot", icon: "car.fill", description: "The beach parking lot is half-full. Heat shimmers off the asphalt. Seagulls patrol between cars, hunting for dropped french fries."),
                PalaceLocation(name: "Boardwalk", icon: "figure.walk", description: "Wooden planks thump beneath your feet on the boardwalk. Salt air fills your lungs. A vendor sells ice cream from a cart with a jingling bell."),
                PalaceLocation(name: "Sand Dunes", icon: "mountain.2.fill", description: "The sand dunes rise like golden hills. Sea grass sways on top, whispering in the wind. Your feet sink deep with each step upward."),
                PalaceLocation(name: "Shoreline", icon: "water.waves", description: "Waves lick at the shoreline, leaving bubbling foam. Shells and sea glass glitter in the wet sand. The ocean stretches endlessly before you."),
                PalaceLocation(name: "Pier", icon: "ferry.fill", description: "The old pier extends into the sea on barnacle-crusted pillars. Fishermen lean on the railing with lazy patience. Waves crash rhythmically below."),
                PalaceLocation(name: "Lighthouse", icon: "light.beacon.max.fill", description: "The red-and-white lighthouse towers above, its paint peeling from sea spray. A spiral staircase is visible through the open door. The beacon gleams."),
                PalaceLocation(name: "Tide Pools", icon: "drop.fill", description: "The tide pools are little worlds unto themselves. A starfish clings to a rock. Tiny crabs scuttle sideways as your shadow falls over the water."),
                PalaceLocation(name: "Cliff", icon: "triangle.fill", description: "The cliff overlooks the entire coastline. Wind whips your hair. Far below, waves explode against ancient rocks in towers of white spray.")
            ]
        ),
        Palace(
            name: "City Tour",
            icon: "building.2.crop.circle.fill",
            tagline: "8 stops through the city",
            color: AppColors.indigo,
            locations: [
                PalaceLocation(name: "Subway", icon: "tram.fill", description: "The subway station echoes with footsteps and distant music. Warm air rushes up from the tunnels. A busker plays saxophone by the turnstiles."),
                PalaceLocation(name: "Plaza", icon: "square.grid.2x2.fill", description: "The open plaza is paved with old cobblestones. Pigeons strut between cafe tables. A street artist sketches portraits in charcoal under a red umbrella."),
                PalaceLocation(name: "Fountain", icon: "drop.circle.fill", description: "The grand fountain sprays arcs of water that catch the sunlight in tiny rainbows. Coins glitter at the bottom. Children chase each other around its rim."),
                PalaceLocation(name: "Museum", icon: "building.columns.fill", description: "The museum's marble steps are wide and imposing. Inside, cool air and hushed voices. A dinosaur skeleton looms in the entrance hall, frozen mid-stride."),
                PalaceLocation(name: "Garden", icon: "leaf.fill", description: "The city garden is an oasis of green. Roses climb iron trellises. A stone path winds past a koi pond where orange fish drift like living flames."),
                PalaceLocation(name: "Tower", icon: "building.fill", description: "The observation tower's glass elevator rises above the skyline. The city shrinks below. You can see the river snaking through downtown like a silver ribbon."),
                PalaceLocation(name: "Market", icon: "cart.fill", description: "The open-air market bursts with color and noise. Vendors shout prices over piles of fruit. Spices in open sacks release clouds of fragrance."),
                PalaceLocation(name: "Rooftop", icon: "sun.horizon.fill", description: "The rooftop bar glows with string lights. The city hums below. A warm breeze carries the scent of grilled food and distant laughter.")
            ]
        ),
        Palace(
            name: "Forest Trail",
            icon: "leaf.circle.fill",
            tagline: "8 stops on a nature hike",
            color: AppColors.accent,
            locations: [
                PalaceLocation(name: "Trailhead", icon: "signpost.right.fill", description: "A wooden sign marks the trailhead. The map under scratched plexiglass shows the winding path ahead. Pine needles crunch underfoot as you step onto the trail."),
                PalaceLocation(name: "Creek", icon: "water.waves", description: "A clear creek babbles over smooth stones. You hop across on flat rocks, arms out for balance. Dragonflies hover over the surface like tiny helicopters."),
                PalaceLocation(name: "Clearing", icon: "sun.max.fill", description: "The trees part to reveal a sun-drenched clearing. Wildflowers blanket the ground in purple and gold. A butterfly lands on your shoulder, then lifts away."),
                PalaceLocation(name: "Old Oak", icon: "tree.fill", description: "The ancient oak is enormous, its trunk wider than a car. Initials are carved into the bark from decades ago. Its roots form natural seats around the base."),
                PalaceLocation(name: "Mossy Rock", icon: "fossil.shell.fill", description: "A mossy boulder sits trailside like a sleeping giant. The moss is thick and soft as velvet. A tiny salamander disappears into a crack as you approach."),
                PalaceLocation(name: "Cave Entrance", icon: "mountain.2.fill", description: "A dark cave mouth opens in the hillside. Cool air breathes out from within. Water drips somewhere deep inside, each drop echoing in the darkness."),
                PalaceLocation(name: "Waterfall", icon: "humidity.fill", description: "The waterfall thunders into a misty pool. Spray catches rainbows in the afternoon light. The roar is so loud you can feel it in your chest."),
                PalaceLocation(name: "Summit", icon: "flag.fill", description: "The summit opens to a panoramic view. Rolling green hills stretch to the horizon. The wind is strong and clean. You can see the entire trail winding below.")
            ]
        )
    ]

    static let itemLists: [ItemList] = [
        ItemList(theme: "Grocery", icon: "cart.fill", items: [
            "milk", "bread", "eggs", "bananas", "chicken",
            "rice", "tomatoes", "cheese", "olive oil", "coffee"
        ]),
        ItemList(theme: "Travel", icon: "suitcase.fill", items: [
            "passport", "charger", "sunscreen", "toothbrush", "wallet",
            "headphones", "jacket", "water bottle", "camera", "snacks"
        ]),
        ItemList(theme: "Presentation", icon: "chart.bar.fill", items: [
            "introduction", "market size", "competitor analysis", "product demo",
            "pricing", "timeline", "team", "Q&A"
        ]),
        ItemList(theme: "Vocabulary", icon: "textformat.abc", items: [
            "ephemeral", "ubiquitous", "pragmatic", "juxtapose",
            "eloquent", "resilient", "paradigm", "catalyst"
        ]),
        ItemList(theme: "Historical", icon: "clock.fill", items: [
            "1776 Independence", "1969 Moon Landing", "1989 Berlin Wall",
            "1945 WW2 End", "1492 Columbus", "1865 Slavery Abolished",
            "1903 First Flight", "1991 Internet Public"
        ])
    ]

    // MARK: - Vivid Image Generator

    /// Pre-built vivid images keyed by "\(locationName)|\(item)" for deterministic lookups,
    /// with a dynamic fallback that combines location + item creatively.
    private static let vividImages: [String: String] = [
        // Grocery
        "Entrance|milk": "A massive milk carton blocks the doorway — you have to squeeze past it, and it moos at you as you brush by.",
        "Kitchen|bread": "A loaf of bread is rising on the counter like a balloon, slowly inflating until it bumps against the ceiling.",
        "Living Room|eggs": "Eggs are lined up on the couch watching TV, each wearing tiny sunglasses. One cracks up at a joke.",
        "Bedroom|bananas": "Your pillow has been replaced by a giant banana. You lay your head on it and it squishes comfortably.",
        "Bathroom|chicken": "A live chicken is taking a shower, clucking happily and using your shampoo. Feathers cover the floor.",
        "Dining Room|rice": "Rice grains are raining from the ceiling fan onto the table like a tiny blizzard. They ping off the plates.",
        "Office|tomatoes": "Your keyboard keys have been replaced by cherry tomatoes. Each one squirts juice when you type.",
        "Garage|cheese": "The car tires are made of giant wheels of cheese. They leave a yellow trail wherever you drive.",

        "Entrance|coffee": "A waterfall of hot coffee pours through the mail slot, filling the entrance with a rich aroma.",
        "Kitchen|olive oil": "The kitchen floor is flooded with olive oil — you slide from the door to the fridge like an ice skater.",
        "Living Room|milk": "The TV is pouring out milk instead of light. It cascades off the screen and pools on the carpet.",
        "Bedroom|bread": "The bed is made entirely of toast. The sheets are warm and smell of butter.",
        "Bathroom|eggs": "Eggs are balanced on every surface — the sink, the toilet lid, the soap dish. One wrong move and they all crack.",
        "Dining Room|bananas": "The chandelier is made of bananas. They glow yellow, lighting the room in a warm tropical hue.",
        "Office|chicken": "A chicken is sitting in your office chair, wearing reading glasses, pecking at the keyboard with purpose.",
        "Garage|rice": "The garage floor is knee-deep in rice. You wade through it to reach the car, grains spilling everywhere.",

        // Travel
        "Entrance|passport": "Your passport is nailed to the front door like a mezuzah. You have to peel it off each time you leave.",
        "Kitchen|charger": "A phone charger is plugged into the toaster, and the toaster is glowing with charged-up energy.",
        "Living Room|sunscreen": "The couch is coated in sunscreen — it's so slippery you slide right off when you try to sit.",
        "Bedroom|toothbrush": "A giant toothbrush is tucked into bed under the covers, bristles on the pillow, handle poking out.",
        "Bathroom|wallet": "Your wallet floats in the bathtub like a little leather boat, credit cards fanned out as sails.",
        "Dining Room|headphones": "The chairs all wear headphones, nodding to music only they can hear. The table vibrates with bass.",
        "Office|jacket": "Your jacket is draped over the monitor like a superhero cape, sleeves typing on the keyboard.",
        "Garage|water bottle": "A water bottle the size of a fire hydrant stands by the garage door, spraying mist like a fountain.",

        // Presentation
        "Entrance|introduction": "A red carpet rolls out from the door with 'WELCOME' in gold letters — your grand introduction.",
        "Kitchen|market size": "The refrigerator door shows a giant pie chart of market share. Each shelf is a different market segment.",
        "Living Room|competitor analysis": "Rival companies are sitting on your couch arguing. Their logos clash like sports teams on game day.",
        "Bedroom|product demo": "Your bed transforms into a product demo stage with spotlights. The pillow is the featured product.",
        "Bathroom|pricing": "Price tags hang from the shower head like ornaments. Each water droplet has a dollar sign in it.",
        "Dining Room|timeline": "A timeline stretches across the dining table like a runner. Each plate marks a milestone date.",
        "Office|team": "Your desk drawers each contain a tiny team member. They pop out like a cuckoo clock on the hour.",
        "Garage|Q&A": "Giant question marks are parked in the garage where cars should be. They honk when you approach.",

        // Vocabulary
        "Entrance|ephemeral": "The door is made of soap bubbles — ephemeral, it pops the moment you touch it and reforms behind you.",
        "Kitchen|ubiquitous": "Every single object in the kitchen is a banana. Ubiquitous bananas — the toaster, the cups, the faucet.",
        "Living Room|pragmatic": "A pragmatic robot sits on the couch, organizing remotes by frequency of use with mechanical efficiency.",
        "Bedroom|juxtapose": "Half the bedroom is a tropical beach, half is the Arctic — juxtaposed side by side. You sleep on the border.",
        "Bathroom|eloquent": "The mirror speaks to you in eloquent, Shakespearean prose every time you look at your reflection.",
        "Dining Room|resilient": "The dining table is made of rubber — resilient, it bounces back no matter how hard you slam your fist.",
        "Office|paradigm": "Your computer boots into a completely different paradigm — instead of a desktop, it shows a 3D world you walk through.",
        "Garage|catalyst": "A chemistry beaker sits on the car hood. One drop of catalyst and the engine roars to life instantly.",

        // Historical
        "Entrance|1776 Independence": "Fireworks explode over your doorway — it's 1776 and the Declaration of Independence is nailed to your front door.",
        "Kitchen|1969 Moon Landing": "An astronaut floats in your kitchen in zero gravity. The fridge door drifts open and food orbits slowly.",
        "Living Room|1989 Berlin Wall": "A concrete wall splits your living room in two. You chip away at it with a remote control and it crumbles.",
        "Bedroom|1945 WW2 End": "Confetti rains from the bedroom ceiling. A newspaper headline on the pillow reads 'WAR IS OVER — 1945.'",
        "Bathroom|1492 Columbus": "Three tiny ships sail in your bathtub. Columbus stands at the bow of the rubber duck, pointing ahead.",
        "Dining Room|1865 Slavery Abolished": "Broken chains decorate the table centerpiece. A candle of freedom burns in the middle, dated 1865.",
        "Office|1903 First Flight": "A paper airplane the size of the Wright Flyer soars across your office, trailing a banner that reads '1903.'",
        "Garage|1991 Internet Public": "Your garage is filled with glowing browser windows floating in mid-air. A dial-up modem screams to life.",

        // School Route
        "Front Door|milk": "A milk truck is parked on your porch, its horn honking a dairy jingle as you step outside.",
        "Sidewalk|bread": "The sidewalk is paved with slices of bread. Each step leaves a toasty footprint behind you.",
        "Park|eggs": "The park swings are giant eggs in nest-seats. They crack gently as you push them, yolks swaying.",
        "Bridge|bananas": "The bridge handrails are made of bananas. They bend under your grip but somehow hold your weight.",
        "Main Street|chicken": "A chicken in a business suit walks down Main Street with a briefcase, late for a meeting.",
        "Cafe|rice": "The cafe serves coffee in bowls of rice. Grains float in your latte like tiny life rafts.",
        "School Gate|tomatoes": "Tomatoes are stacked on the gate posts like sentries. They squirt juice at anyone who arrives late.",
        "Classroom|cheese": "The blackboard is a giant slab of Swiss cheese. The teacher writes through the holes.",

        "Front Door|passport": "Your doormat IS a giant passport. It stamps your feet 'APPROVED' as you step out.",
        "Sidewalk|charger": "Phone charger cables grow from the sidewalk cracks like vines, sparking with green energy.",
        "Park|sunscreen": "The park fountain sprays sunscreen instead of water. Dogs roll in the SPF 50 puddles.",
        "Bridge|toothbrush": "A giant toothbrush is wedged under the bridge like a support beam, bristles dripping into the creek.",
        "Main Street|wallet": "Every shop sign on Main Street is a different credit card from a giant wallet displayed overhead.",
        "Cafe|headphones": "Everyone in the cafe wears headphones — they all sway to different rhythms, completely in their own worlds.",
        "School Gate|jacket": "The school gate is draped in jackets like a lost-and-found explosion. Sleeves wave in the wind.",
        "Classroom|water bottle": "A water bottle sits in the teacher's chair, lecturing through its flip-top lid with surprising authority.",

        // Beach Walk
        "Parking Lot|milk": "Seagulls are drinking milk from cartons left on car hoods. One gull wears a tiny milk mustache.",
        "Boardwalk|bread": "The boardwalk planks have been replaced by baguettes. They crunch and crumble under your sandals.",
        "Sand Dunes|eggs": "Ostrich eggs are half-buried in the dunes. One cracks open and a tiny dinosaur peers out.",
        "Shoreline|bananas": "Banana peels wash up with each wave, creating a yellow fringe along the entire shoreline.",
        "Pier|chicken": "A chicken in a sailor hat stands at the end of the pier, fishing. It reels in a rubber boot.",
        "Lighthouse|rice": "Rice pours from the lighthouse beacon like a spotlight of grains, raining white across the beach.",
        "Tide Pools|tomatoes": "Cherry tomatoes bob in the tide pools among the anemones, turning the pools into gazpacho.",
        "Cliff|cheese": "The cliff face is layered like a cheese wheel. Mice with climbing gear scale its yellow surface.",

        // City Tour
        "Subway|milk": "The subway train is filled with milk. It sloshes out the doors at every stop, flooding the platform.",
        "Plaza|bread": "A bread sculptor in the plaza carves baguettes into famous statues. Pigeons attempt heists.",
        "Fountain|eggs": "The fountain shoots eggs into the air instead of water. They land soft-boiled in catching nets.",
        "Museum|bananas": "The museum's featured exhibit is a single banana duct-taped to a wall. A guard stands watch.",
        "Garden|chicken": "Chickens roam the garden paths like peacocks, their feathers replaced with flower petals.",
        "Tower|rice": "Rice streams from the observation deck like confetti at a parade, visible from blocks away.",
        "Market|tomatoes": "The entire market is a tomato fight. Vendors and customers hurl heirloom tomatoes with glee.",
        "Rooftop|cheese": "The rooftop is hosting a fondue party. A cheese fountain bubbles in the center as the city twinkles.",

        // Forest Trail
        "Trailhead|milk": "The trail map dispenser has been replaced with a milk vending machine. Hikers sip cartons as they start.",
        "Creek|bread": "Bread ducks float on the creek — loaves shaped like ducks, bobbing downstream in a carby flotilla.",
        "Clearing|eggs": "Painted Easter eggs are scattered across the clearing. Each one contains a tiny forest animal surprise.",
        "Old Oak|bananas": "The oak's branches drip with bananas instead of acorns. Squirrels peel them with practiced paws.",
        "Mossy Rock|chicken": "A chicken perches on the mossy rock like a nature guide, clucking directions to passing hikers.",
        "Cave Entrance|rice": "Rice grains trickle from the cave ceiling like sand in an hourglass, forming a white mound at the entrance.",
        "Waterfall|tomatoes": "The waterfall runs red with tomato juice. It smells like a giant Italian kitchen. Basil floats by.",
        "Summit|cheese": "The summit marker is a wheel of aged cheddar. Hikers slice victory pieces with pocket knives."
    ]

    // MARK: - Public API

    func selectPalace(_ palace: Palace) {
        selectedPalace = palace
        let learned = hasLearnedPalace(palace)
        if learned {
            phase = .placeItems
            beginPlacing()
        } else {
            phase = .learnRoute
            learnIndex = 0
        }
    }

    func advanceLearnRoute() {
        guard let palace = selectedPalace else { return }
        if learnIndex < palace.locations.count - 1 {
            learnIndex += 1
        } else {
            markPalaceLearned(palace)
            phase = .placeItems
            beginPlacing()
        }
    }

    func relearnRoute() {
        learnIndex = 0
        phase = .learnRoute
    }

    func advancePlacing() {
        placingTimer?.invalidate()
        if placingIndex < placedItems.count - 1 {
            placingIndex += 1
            startPlacingTimer()
        } else {
            phase = .recall
            recallIndex = 0
            prepareRecallOptions()
        }
    }

    func submitAnswer(_ answer: String) {
        guard recallIndex < placedItems.count else { return }
        let correct = answer.lowercased().trimmingCharacters(in: .whitespaces) ==
            placedItems[recallIndex].item.lowercased().trimmingCharacters(in: .whitespaces)

        if recallIndex < userAnswers.count {
            userAnswers[recallIndex] = answer
        } else {
            userAnswers.append(answer)
        }

        lastAnswerCorrect = correct
        if correct { correctCount += 1 }
        showFeedback = true
    }

    func advanceRecall() {
        showFeedback = false
        selectedAnswer = nil
        if recallIndex < placedItems.count - 1 {
            recallIndex += 1
            prepareRecallOptions()
        } else {
            finishExercise()
        }
    }

    var score: Double {
        guard totalCount > 0 else { return 0 }
        return Double(correctCount) / Double(totalCount)
    }

    var difficultyLevel: Int {
        AdaptiveDifficultyEngine.shared.currentLevel(for: .locations)
    }

    // MARK: - Private

    private func beginPlacing() {
        guard let palace = selectedPalace else { return }

        let params = AdaptiveDifficultyEngine.shared.parameters(for: .locations)
        itemCountToUse = min(params.locationCount, palace.locations.count)

        // Pick a random item list
        guard let list = Self.itemLists.randomElement() else { return }
        currentItemList = list

        // Shuffle and pick items
        let shuffledItems = list.items.shuffled()
        let selectedItems = Array(shuffledItems.prefix(itemCountToUse))

        // Pair items with palace locations
        placedItems = []
        for (index, item) in selectedItems.enumerated() {
            let location = palace.locations[index]
            let vivid = Self.vividImageFor(location: location.name, item: item)
            placedItems.append(PlacedItem(location: location, item: item, vividImage: vivid))
        }

        placingIndex = 0
        totalCount = placedItems.count
        correctCount = 0
        userAnswers = Array(repeating: "", count: totalCount)
        startTime = .now
        startPlacingTimer()
    }

    private func startPlacingTimer() {
        placingTimeRemaining = 5.0
        placingTimer?.invalidate()
        placingTimer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { [weak self] timer in
            guard let self else { timer.invalidate(); return }
            DispatchQueue.main.async {
                if self.placingTimeRemaining > 0.1 {
                    self.placingTimeRemaining -= 0.1
                } else {
                    self.placingTimeRemaining = 0
                    timer.invalidate()
                    self.advancePlacing()
                }
            }
        }
    }

    private func prepareRecallOptions() {
        guard recallIndex < placedItems.count else { return }
        let correctItem = placedItems[recallIndex].item

        // Build 4 options: correct + 3 distractors from the same list
        var options: Set<String> = [correctItem]
        let allItems = currentItemList?.items ?? []
        let distractors = allItems.filter { $0 != correctItem }.shuffled()
        for d in distractors {
            if options.count >= 4 { break }
            options.insert(d)
        }
        // If not enough distractors, pad from other lists
        if options.count < 4 {
            let otherItems = Self.itemLists.flatMap { $0.items }.filter { !options.contains($0) }.shuffled()
            for d in otherItems {
                if options.count >= 4 { break }
                options.insert(d)
            }
        }
        answerOptions = Array(options).shuffled()
    }

    private func finishExercise() {
        placingTimer?.invalidate()
        durationSeconds = Int(Date.now.timeIntervalSince(startTime))
        AdaptiveDifficultyEngine.shared.recordBlock(domain: .locations, correct: correctCount, total: totalCount)
        strategyTip = StrategyTipService.shared.freshTip(for: .locations)
        phase = .results
        SoundService.shared.playComplete()
    }

    func restart() {
        phase = .choosePalace
        selectedPalace = nil
        learnIndex = 0
        placingIndex = 0
        recallIndex = 0
        placedItems = []
        userAnswers = []
        selectedAnswer = nil
        answerOptions = []
        showFeedback = false
        lastAnswerCorrect = false
        correctCount = 0
        totalCount = 0
        strategyTip = nil
        placingTimer?.invalidate()
    }

    func tryAgainSamePalace() {
        guard let palace = selectedPalace else { return }
        placingIndex = 0
        recallIndex = 0
        placedItems = []
        userAnswers = []
        selectedAnswer = nil
        answerOptions = []
        showFeedback = false
        lastAnswerCorrect = false
        correctCount = 0
        totalCount = 0
        strategyTip = nil
        placingTimer?.invalidate()
        selectedPalace = palace
        phase = .placeItems
        beginPlacing()
    }

    // MARK: - Palace Learning Persistence

    private func hasLearnedPalace(_ palace: Palace) -> Bool {
        let learned = UserDefaults.standard.stringArray(forKey: learnedPalacesKey) ?? []
        return learned.contains(palace.name)
    }

    private func markPalaceLearned(_ palace: Palace) {
        var learned = UserDefaults.standard.stringArray(forKey: learnedPalacesKey) ?? []
        if !learned.contains(palace.name) {
            learned.append(palace.name)
            UserDefaults.standard.set(learned, forKey: learnedPalacesKey)
        }
    }

    // MARK: - Vivid Image Lookup

    static func vividImageFor(location: String, item: String) -> String {
        let key = "\(location)|\(item)"
        if let found = vividImages[key] {
            return found
        }
        // Dynamic fallback
        return "Imagine a giant, glowing \(item) sitting right in the middle of the \(location.lowercased()). It's so vivid and out of place that everyone stops to stare at it."
    }
}

// MARK: - Main View

struct MemoryPalaceView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @Environment(AchievementService.self) private var achievementService
    @Environment(TrainingSessionManager.self) private var trainingManager
    @Environment(PaywallTriggerService.self) private var paywallTrigger
    @Environment(StoreService.self) private var storeService
    @Environment(GameCenterService.self) private var gameCenterService
    @Query private var users: [User]

    @State private var viewModel = MemoryPalaceViewModel()
    @State private var challengeStarted = false
    @State private var showingPaywall = false

    private var user: User? { users.first }
    private var isProUser: Bool { storeService.isProUser }

    var body: some View {
        VStack(spacing: 0) {
            if !challengeStarted {
                startView
            } else {
                switch viewModel.phase {
                case .choosePalace:
                    choosePalaceView
                case .learnRoute:
                    learnRouteView
                case .placeItems:
                    placeItemsView
                case .recall:
                    recallView
                case .results:
                    resultsView
                }
            }
        }
        .navigationTitle("Memory Palace")
        .navigationBarTitleDisplayMode(.inline)
        .sheet(isPresented: $showingPaywall) {
            PaywallView(isHighIntent: true)
        }
    }

    // MARK: - Start View

    private var startView: some View {
        VStack(spacing: 32) {
            Spacer()

            ZStack {
                Circle()
                    .fill(AppColors.cardBorder)
                    .frame(width: 120, height: 120)
                Image(systemName: "building.columns.fill")
                    .font(.system(size: 52, weight: .medium))
                    .foregroundStyle(AppColors.accent)
            }

            VStack(spacing: 12) {
                Text("Memory Palace")
                    .font(.title.weight(.bold))

                Text("The #1 technique used by memory champions")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)

                Text("Place items along a familiar route, then walk through to recall them all.")
                    .font(.footnote)
                    .foregroundStyle(.tertiary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 32)
            }

            Spacer()

            Button {
                challengeStarted = true
            } label: {
                Text("Build Your Palace")
                    .gradientButton(AppColors.coolGradient)
            }
            .accessibilityHint("Starts the exercise")
            .padding(.horizontal, 32)
        }
        .padding(.vertical, 24)
    }

    // MARK: - Choose Palace View

    private var choosePalaceView: some View {
        ScrollView {
            VStack(spacing: 20) {
                VStack(spacing: 8) {
                    Text("Choose Your Palace")
                        .font(.title2.weight(.bold))
                    Text("Pick a place you can vividly imagine walking through.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                }
                .padding(.top, 24)

                ForEach(MemoryPalaceViewModel.palaces) { palace in
                    Button {
                        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                        viewModel.selectPalace(palace)
                    } label: {
                        HStack(spacing: 16) {
                            Image(systemName: palace.icon)
                                .font(.title2)
                                .foregroundStyle(.white)
                                .frame(width: 52, height: 52)
                                .background(
                                    LinearGradient(
                                        colors: [palace.color, palace.color.opacity(0.7)],
                                        startPoint: .topLeading,
                                        endPoint: .bottomTrailing
                                    ),
                                    in: RoundedRectangle(cornerRadius: 12)
                                )

                            VStack(alignment: .leading, spacing: 4) {
                                Text(palace.name)
                                    .font(.headline)
                                    .foregroundStyle(.primary)
                                Text(palace.tagline)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }

                            Spacer()

                            Image(systemName: "chevron.right")
                                .font(.caption.weight(.semibold))
                                .foregroundStyle(.tertiary)
                        }
                        .appCard()
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal)
            .padding(.bottom, 32)
        }
    }

    // MARK: - Learn Route View

    private var learnRouteView: some View {
        VStack(spacing: 0) {
            if let palace = viewModel.selectedPalace {
                let location = palace.locations[viewModel.learnIndex]

                // Progress
                HStack {
                    Text("Learning: \(palace.name)")
                        .font(.subheadline.weight(.medium))
                    Spacer()
                    Text("\(viewModel.learnIndex + 1) / \(palace.locations.count)")
                        .font(.subheadline.monospacedDigit())
                        .foregroundStyle(.secondary)
                }
                .padding(.horizontal)
                .padding(.top, 16)

                ProgressView(value: Double(viewModel.learnIndex + 1), total: Double(palace.locations.count))
                    .tint(palace.color)
                    .padding(.horizontal)
                    .padding(.top, 8)

                Spacer()

                // Location Card
                VStack(spacing: 20) {
                    Image(systemName: location.icon)
                        .font(.system(size: 56))
                        .foregroundStyle(palace.color)

                    Text(location.name)
                        .font(.title.weight(.bold))

                    Text(location.description)
                        .font(.body)
                        .lineSpacing(4)
                        .multilineTextAlignment(.center)
                        .foregroundStyle(.secondary)
                        .padding(.horizontal, 8)
                }
                .appCard()
                .padding(.horizontal, 24)

                Spacer()

                // Navigation
                Button {
                    UIImpactFeedbackGenerator(style: .light).impactOccurred()
                    withAnimation(.easeInOut(duration: 0.3)) {
                        viewModel.advanceLearnRoute()
                    }
                } label: {
                    Text(viewModel.learnIndex < palace.locations.count - 1 ? "Next Stop" : "Start Placing Items")
                        .gradientButton(AppColors.coolGradient)
                }
                .padding(.horizontal, 32)
                .padding(.bottom, 24)
            }
        }
    }

    // MARK: - Place Items View

    private var placeItemsView: some View {
        VStack(spacing: 0) {
            if viewModel.placingIndex < viewModel.placedItems.count {
                let placed = viewModel.placedItems[viewModel.placingIndex]

                // Header
                HStack {
                    Text("Place Items")
                        .font(.subheadline.weight(.medium))
                    Spacer()
                    Text("\(viewModel.placingIndex + 1) / \(viewModel.placedItems.count)")
                        .font(.subheadline.monospacedDigit())
                        .foregroundStyle(.secondary)
                }
                .padding(.horizontal)
                .padding(.top, 16)

                // Timer bar
                ProgressView(value: viewModel.placingTimeRemaining, total: 5.0)
                    .tint(viewModel.placingTimeRemaining > 2 ? AppColors.teal : AppColors.coral)
                    .padding(.horizontal)
                    .padding(.top, 8)
                    .animation(.linear(duration: 0.1), value: viewModel.placingTimeRemaining)

                Spacer()

                // Location + Item Card
                VStack(spacing: 16) {
                    // Location
                    HStack(spacing: 12) {
                        Image(systemName: placed.location.icon)
                            .font(.title3)
                            .foregroundStyle(AppColors.indigo)
                        Text(placed.location.name)
                            .font(.title3.weight(.semibold))
                    }

                    Divider()

                    // Item
                    HStack(spacing: 12) {
                        Image(systemName: "cube.fill")
                            .font(.title3)
                            .foregroundStyle(AppColors.coral)
                        Text(placed.item.capitalized)
                            .font(.title2.weight(.bold))
                    }

                    Divider()

                    // Vivid Image
                    Text(placed.vividImage)
                        .font(.callout)
                        .italic()
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                        .lineSpacing(3)
                        .padding(.horizontal, 4)
                }
                .appCard()
                .padding(.horizontal, 24)

                Spacer()

                Button {
                    UIImpactFeedbackGenerator(style: .light).impactOccurred()
                    viewModel.advancePlacing()
                } label: {
                    Text("Next")
                        .accentButton(color: AppColors.teal)
                }
                .padding(.horizontal, 32)
                .padding(.bottom, 24)
            }
        }
    }

    // MARK: - Recall View

    private var recallView: some View {
        VStack(spacing: 0) {
            if viewModel.recallIndex < viewModel.placedItems.count {
                let placed = viewModel.placedItems[viewModel.recallIndex]

                // Header
                HStack {
                    Text("Recall")
                        .font(.subheadline.weight(.medium))
                    Spacer()
                    Text("\(viewModel.recallIndex + 1) / \(viewModel.placedItems.count)")
                        .font(.subheadline.monospacedDigit())
                        .foregroundStyle(.secondary)
                }
                .padding(.horizontal)
                .padding(.top, 16)

                ProgressView(value: Double(viewModel.recallIndex + 1), total: Double(viewModel.placedItems.count))
                    .tint(AppColors.violet)
                    .padding(.horizontal)
                    .padding(.top, 8)

                Spacer()

                // Location prompt
                VStack(spacing: 16) {
                    Image(systemName: placed.location.icon)
                        .font(.system(size: 48))
                        .foregroundStyle(AppColors.indigo)

                    Text(placed.location.name)
                        .font(.title2.weight(.bold))

                    Text("What item did you place here?")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                .padding(.bottom, 8)

                if viewModel.showFeedback {
                    // Feedback
                    feedbackCard(for: placed)
                        .padding(.horizontal, 24)
                        .transition(.scale.combined(with: .opacity))
                } else {
                    // Answer options
                    VStack(spacing: 12) {
                        ForEach(viewModel.answerOptions, id: \.self) { option in
                            Button {
                                viewModel.selectedAnswer = option
                            } label: {
                                HStack {
                                    Text(option.capitalized)
                                        .font(.headline)
                                        .foregroundStyle(viewModel.selectedAnswer == option ? .white : .primary)
                                    Spacer()
                                    if viewModel.selectedAnswer == option {
                                        Image(systemName: "checkmark.circle.fill")
                                            .foregroundStyle(.white)
                                    }
                                }
                                .padding()
                                .background(
                                    RoundedRectangle(cornerRadius: 12)
                                        .fill(viewModel.selectedAnswer == option
                                              ? AnyShapeStyle(AppColors.violet)
                                              : AnyShapeStyle(AppColors.cardSurface))
                                )
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(.horizontal, 24)
                }

                Spacer()

                if viewModel.showFeedback {
                    Button {
                        withAnimation(.easeInOut(duration: 0.3)) {
                            viewModel.advanceRecall()
                        }
                    } label: {
                        Text(viewModel.recallIndex < viewModel.placedItems.count - 1 ? "Next Location" : "See Results")
                            .accentButton(color: AppColors.violet)
                    }
                    .padding(.horizontal, 32)
                    .padding(.bottom, 24)
                } else {
                    Button {
                        guard let answer = viewModel.selectedAnswer else { return }
                        let isCorrect = answer.lowercased() == placed.item.lowercased()
                        if isCorrect {
                            SoundService.shared.playCorrect()
                        } else {
                            UINotificationFeedbackGenerator().notificationOccurred(.error)
                            SoundService.shared.playWrong()
                        }
                        withAnimation(.easeInOut(duration: 0.3)) {
                            viewModel.submitAnswer(answer)
                        }
                    } label: {
                        Text("Submit")
                            .accentButton(color: AppColors.violet)
                    }
                    .padding(.horizontal, 32)
                    .padding(.bottom, 24)
                    .disabled(viewModel.selectedAnswer == nil)
                    .opacity(viewModel.selectedAnswer == nil ? 0.5 : 1.0)
                }
            }
        }
    }

    private func feedbackCard(for placed: PlacedItem) -> some View {
        VStack(spacing: 12) {
            Image(systemName: viewModel.lastAnswerCorrect ? "checkmark.circle.fill" : "xmark.circle.fill")
                .font(.system(size: 36))
                .foregroundStyle(viewModel.lastAnswerCorrect ? AppColors.accent : AppColors.coral)

            Text(viewModel.lastAnswerCorrect ? "Correct!" : "Not quite")
                .font(.headline)

            if !viewModel.lastAnswerCorrect {
                Text("The answer was **\(placed.item.capitalized)**")
                    .font(.subheadline)
            }

            Text(placed.vividImage)
                .font(.caption)
                .italic()
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .lineSpacing(2)
                .padding(.top, 4)
        }
        .appCard()
    }

    // MARK: - Results View

    private var resultsView: some View {
        ScrollView {
            VStack(spacing: 24) {
                // Score Header
                VStack(spacing: 12) {
                    ZStack {
                        Circle()
                            .fill(AppColors.cardBorder)
                            .frame(width: 90, height: 90)
                        Image(systemName: viewModel.score >= 0.7 ? "building.columns.fill" : "building.columns")
                            .font(.system(size: 48, weight: .medium))
                            .foregroundStyle(viewModel.score >= 0.7 ? AppColors.accent : AppColors.warning)
                    }

                    Text(viewModel.score >= 0.9 ? "Palace Master!" : viewModel.score >= 0.7 ? "Well Done!" : "Keep Building!")
                        .font(.title.weight(.bold))

                    Text("\(viewModel.correctCount) / \(viewModel.totalCount) correct")
                        .font(.title3)
                        .foregroundStyle(.secondary)

                    Text("Your palace is growing stronger with each visit!")
                        .font(.subheadline)
                        .foregroundStyle(AppColors.teal)
                        .multilineTextAlignment(.center)
                }
                .padding(.top, 24)

                // Score Ring
                ZStack {
                    Circle()
                        .stroke(AppColors.indigo.opacity(0.15), lineWidth: 10)
                    Circle()
                        .trim(from: 0, to: viewModel.score)
                        .stroke(
                            LinearGradient(
                                colors: [AppColors.indigo, AppColors.violet],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ),
                            style: StrokeStyle(lineWidth: 10, lineCap: .round)
                        )
                        .rotationEffect(.degrees(-90))
                        .animation(.spring(response: 0.8, dampingFraction: 0.7), value: viewModel.score)
                    Text(viewModel.score.percentString)
                        .font(.title.weight(.bold).monospacedDigit())
                        .foregroundStyle(AppColors.accent)
                }
                .frame(width: 100, height: 100)
                .accessibilityLabel("Score: \(viewModel.score.percentString)")

                // Missed Items
                if viewModel.placedItems.contains(where: { placed in
                    let idx = viewModel.placedItems.firstIndex(where: { $0.id == placed.id }) ?? 0
                    let answer = viewModel.userAnswers[safe: idx] ?? ""
                    return answer.lowercased() != placed.item.lowercased()
                }) {
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Items to review")
                            .font(.headline)

                        ForEach(Array(viewModel.placedItems.enumerated()), id: \.element.id) { index, placed in
                            let answer = viewModel.userAnswers[safe: index] ?? ""
                            let isCorrect = answer.lowercased() == placed.item.lowercased()

                            if !isCorrect {
                                HStack(spacing: 12) {
                                    Image(systemName: placed.location.icon)
                                        .font(.body)
                                        .foregroundStyle(AppColors.coral)
                                        .frame(width: 28)

                                    VStack(alignment: .leading, spacing: 2) {
                                        Text("\(placed.location.name): **\(placed.item.capitalized)**")
                                            .font(.subheadline)
                                        Text(placed.vividImage)
                                            .font(.caption)
                                            .foregroundStyle(.secondary)
                                            .lineLimit(2)
                                    }
                                }
                                if index < viewModel.placedItems.count - 1 {
                                    Divider()
                                }
                            }
                        }
                    }
                    .glowingCard(color: AppColors.indigo, intensity: 0.08)
                    .padding(.horizontal)
                }

                // Strategy Tip
                if let tip = viewModel.strategyTip {
                    VStack(alignment: .leading, spacing: 8) {
                        Label(tip.title, systemImage: "lightbulb.fill")
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(AppColors.violet)

                        Text(tip.body)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .lineSpacing(2)

                        Text(tip.researchNote)
                            .font(.caption2)
                            .foregroundStyle(.tertiary)
                            .lineSpacing(1)
                    }
                    .glowingCard(color: AppColors.violet, intensity: 0.1)
                    .padding(.horizontal)
                }

                LeaderboardRankCard(
                    exerciseType: .memoryPalace,
                    userScore: Int(viewModel.score * 100),
                )
                .padding(.horizontal)

                // Actions
                VStack(spacing: 12) {
                    Button {
                        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                        viewModel.tryAgainSamePalace()
                    } label: {
                        Text("Try Again")
                            .gradientButton(AppColors.coolGradient)
                    }

                    Button {
                        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                        viewModel.restart()
                    } label: {
                        Text("Different Palace")
                            .accentButton(color: AppColors.teal)
                    }

                    Button {
                        saveExercise()
                        dismiss()
                    } label: {
                        Text("Done")
                            .font(.headline)
                            .foregroundStyle(.secondary)
                    }
                }
                .padding(.horizontal, 32)
                .padding(.bottom, 32)
            }
        }
    }

    // MARK: - Save Exercise

    private func saveExercise() {
        paywallTrigger.recordExerciseCompleted()
        trainingManager.addTrainingTime(viewModel.durationSeconds)

        let exercise = Exercise(
            type: .memoryPalace,
            difficulty: viewModel.difficultyLevel,
            score: viewModel.score,
            durationSeconds: viewModel.durationSeconds
        )
        modelContext.insert(exercise)

        let descriptor = FetchDescriptor<DailySession>(
            sortBy: [SortDescriptor(\.date, order: .reverse)]
        )
        let allSessions = (try? modelContext.fetch(descriptor)) ?? []
        let session: DailySession
        if let existing = allSessions.first(where: { Calendar.current.isDateInToday($0.date) }) {
            session = existing
        } else {
            session = DailySession()
            modelContext.insert(session)
        }
        session.addExercise(exercise)
        user?.updateStreak()
        NotificationService.shared.cancelStreakRisk()
        if let streak = user?.currentStreak {
            NotificationService.shared.scheduleMilestone(streak: streak)
        }

        if let user {
            _ = ContentView.awardXP(
                user: user,
                score: viewModel.score,
                difficulty: viewModel.difficultyLevel,
                achievementService: achievementService,
                modelContext: modelContext,
                gameCenterService: gameCenterService,
                exerciseType: .memoryPalace
            )
        }
    }
}
