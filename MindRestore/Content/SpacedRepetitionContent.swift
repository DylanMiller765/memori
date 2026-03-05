import Foundation

enum SpacedRepetitionContent {

    static func generateNumberCards() -> [(prompt: String, answer: String)] {
        [
            ("Remember: 4 7 2 9", "4 7 2 9"),
            ("Remember: 8 3 1 5", "8 3 1 5"),
            ("Remember: 6 0 9 2", "6 0 9 2"),
            ("Remember: 1 5 8 3 7", "1 5 8 3 7"),
            ("Remember: 9 2 4 6 1", "9 2 4 6 1"),
            ("Remember: 3 7 0 5 8", "3 7 0 5 8"),
            ("Remember: 7 1 4 9 2 6", "7 1 4 9 2 6"),
            ("Remember: 5 8 3 0 7 1", "5 8 3 0 7 1"),
            ("Remember: 2 6 9 4 1 8", "2 6 9 4 1 8"),
            ("Remember: 4 0 7 3 8 5 2", "4 0 7 3 8 5 2"),
            ("Remember: 1 9 6 2 5 0 7", "1 9 6 2 5 0 7"),
            ("Remember: 8 3 5 1 7 4 9", "8 3 5 1 7 4 9"),
            ("Remember: 3 6 1 9 4 7 2 5", "3 6 1 9 4 7 2 5"),
            ("Remember: 7 2 8 0 5 3 9 1", "7 2 8 0 5 3 9 1"),
            ("Remember: 5 9 2 6 1 8 4 0", "5 9 2 6 1 8 4 0"),
            ("Remember: 2 4 7 1 9 3 6 8", "2 4 7 1 9 3 6 8"),
            ("Remember: 6 1 3 8 0 5 7 2", "6 1 3 8 0 5 7 2"),
            ("Remember: 9 5 0 4 2 7 1 8", "9 5 0 4 2 7 1 8"),
            ("Remember: 1 8 4 6 3 0 9 5", "1 8 4 6 3 0 9 5"),
            ("Remember: 0 3 7 9 5 2 8 4", "0 3 7 9 5 2 8 4"),
        ]
    }

    static func generateWordCards() -> [(prompt: String, answer: String)] {
        [
            ("Remember these words in order:\nApple, River, Clock, Mountain, Paper", "Apple, River, Clock, Mountain, Paper"),
            ("Remember these words in order:\nBridge, Candle, Forest, Guitar, Shadow", "Bridge, Candle, Forest, Guitar, Shadow"),
            ("Remember these words in order:\nOcean, Pencil, Rabbit, Sunset, Violin", "Ocean, Pencil, Rabbit, Sunset, Violin"),
            ("Remember these words in order:\nChair, Diamond, Eagle, Flame, Garden", "Chair, Diamond, Eagle, Flame, Garden"),
            ("Remember these words in order:\nHammer, Island, Jacket, Kettle, Lantern", "Hammer, Island, Jacket, Kettle, Lantern"),
            ("Remember these words in order:\nMirror, Notebook, Olive, Piano, Quilt", "Mirror, Notebook, Olive, Piano, Quilt"),
            ("Remember these words in order:\nRocket, Sphere, Tunnel, Umbrella, Window", "Rocket, Sphere, Tunnel, Umbrella, Window"),
            ("Remember these words in order:\nAnchor, Basket, Compass, Dragon, Emerald, Feather", "Anchor, Basket, Compass, Dragon, Emerald, Feather"),
            ("Remember these words in order:\nGlobe, Harbor, Ivory, Jasmine, Kingdom, Lighthouse", "Globe, Harbor, Ivory, Jasmine, Kingdom, Lighthouse"),
            ("Remember these words in order:\nMarble, Neptune, Orchid, Pyramid, Sapphire, Thunder", "Marble, Neptune, Orchid, Pyramid, Sapphire, Thunder"),
            ("Remember these words in order:\nVelvet, Willow, Crystal, Dolphin, Eclipse, Falcon", "Velvet, Willow, Crystal, Dolphin, Eclipse, Falcon"),
            ("Remember these words in order:\nGranite, Horizon, Indigo, Juniper, Kaleidoscope, Labyrinth", "Granite, Horizon, Indigo, Juniper, Kaleidoscope, Labyrinth"),
            ("Remember these words in order:\nMagnolia, Nebula, Obsidian, Phoenix, Quartz, Raven, Summit", "Magnolia, Nebula, Obsidian, Phoenix, Quartz, Raven, Summit"),
            ("Remember these words in order:\nTrident, Utopia, Vortex, Wanderer, Zenith, Aurora, Basalt", "Trident, Utopia, Vortex, Wanderer, Zenith, Aurora, Basalt"),
            ("Remember these words in order:\nCascade, Driftwood, Ember, Fjord, Glacier, Heather, Iris, Jade", "Cascade, Driftwood, Ember, Fjord, Glacier, Heather, Iris, Jade"),
            ("Remember these words in order:\nKeystone, Lunar, Meadow, Nimbus, Opal, Pebble, Quarry, Ravine", "Keystone, Lunar, Meadow, Nimbus, Opal, Pebble, Quarry, Ravine"),
            ("Remember these words in order:\nSilver, Tundra, Umber, Valley, Whirlpool, Xenon, Yarrow, Zephyr", "Silver, Tundra, Umber, Valley, Whirlpool, Xenon, Yarrow, Zephyr"),
            ("Remember these words in order:\nAmethyst, Blizzard, Canyon, Delta, Estuary, Falcon, Garnet, Hazel", "Amethyst, Blizzard, Canyon, Delta, Estuary, Falcon, Garnet, Hazel"),
            ("Remember these words in order:\nIceberg, Jupiter, Kestrel, Lava, Mercury, Narwhal, Osprey, Platinum", "Iceberg, Jupiter, Kestrel, Lava, Mercury, Narwhal, Osprey, Platinum"),
            ("Remember these words in order:\nQuasar, Ridge, Sequoia, Tempest, Uranium, Vesper, Wisteria, Xylem", "Quasar, Ridge, Sequoia, Tempest, Uranium, Vesper, Wisteria, Xylem"),
        ]
    }

    static func generateFaceCards() -> [(prompt: String, answer: String)] {
        [
            ("Sarah — Tall with curly red hair, wears glasses, works as a teacher", "Sarah"),
            ("Marcus — Short beard, blue eyes, always wears a watch, works in finance", "Marcus"),
            ("Elena — Long black hair, small scar on chin, plays violin", "Elena"),
            ("David — Bald, green eyes, has a tattoo of a compass on his wrist", "David"),
            ("Priya — Shoulder-length brown hair, dimples, studies medicine", "Priya"),
            ("James — Blonde, freckles, tall, plays basketball on weekends", "James"),
            ("Mei — Short pixie cut, brown eyes, always carries a sketchbook", "Mei"),
            ("Omar — Dark curly hair, thick eyebrows, runs a coffee shop", "Omar"),
            ("Sofia — Auburn hair in a bun, hazel eyes, yoga instructor", "Sofia"),
            ("Tyler — Buzz cut, scar above left eyebrow, mechanic", "Tyler"),
            ("Aisha — Braids, round glasses, PhD student in neuroscience", "Aisha"),
            ("Connor — Red beard, blue eyes, woodworker, always smells like pine", "Connor"),
            ("Luna — Silver streak in black hair, nose ring, graphic designer", "Luna"),
            ("Raj — Salt-and-pepper hair, warm smile, retired professor", "Raj"),
            ("Zoe — Blonde bob, green eyes, marathon runner, nutritionist", "Zoe"),
            ("Nathan — Dreadlocks, deep voice, jazz musician, plays saxophone", "Nathan"),
            ("Clara — Wire-rim glasses, keeps succulents, works in a library", "Clara"),
            ("Andre — Muscular build, shaved head, gentle personality, veterinarian", "Andre"),
            ("Iris — Heterochromia (one blue, one brown eye), photographer", "Iris"),
            ("Felix — Handlebar mustache, bow ties, history teacher", "Felix"),
        ]
    }

    static func generateLocationCards() -> [(prompt: String, answer: String)] {
        [
            ("Path: Library -> Park -> Cafe -> Bank", "Library, Park, Cafe, Bank"),
            ("Path: School -> Hospital -> Market -> Museum", "School, Hospital, Market, Museum"),
            ("Path: Airport -> Hotel -> Beach -> Restaurant", "Airport, Hotel, Beach, Restaurant"),
            ("Path: Office -> Gym -> Pharmacy -> Home", "Office, Gym, Pharmacy, Home"),
            ("Path: Station -> Bridge -> Cathedral -> Square", "Station, Bridge, Cathedral, Square"),
            ("Path: Post Office -> Bakery -> Bookstore -> Cinema -> Garden", "Post Office, Bakery, Bookstore, Cinema, Garden"),
            ("Path: Harbor -> Lighthouse -> Tavern -> Chapel -> Market", "Harbor, Lighthouse, Tavern, Chapel, Market"),
            ("Path: University -> Lab -> Cafeteria -> Dormitory -> Stadium", "University, Lab, Cafeteria, Dormitory, Stadium"),
            ("Path: Mall -> Fountain -> Theater -> Gallery -> Rooftop", "Mall, Fountain, Theater, Gallery, Rooftop"),
            ("Path: Subway -> Tower -> Garden -> Pier -> Arcade -> Hotel", "Subway, Tower, Garden, Pier, Arcade, Hotel"),
            ("Path: Warehouse -> River -> Mill -> Farm -> Vineyard -> Cottage", "Warehouse, River, Mill, Farm, Vineyard, Cottage"),
            ("Path: Plaza -> Alley -> Courtyard -> Terrace -> Balcony -> Attic", "Plaza, Alley, Courtyard, Terrace, Balcony, Attic"),
            ("Path: Lobby -> Elevator -> Office -> Boardroom -> Cafeteria -> Garage -> Exit", "Lobby, Elevator, Office, Boardroom, Cafeteria, Garage, Exit"),
            ("Path: Gate -> Path -> Greenhouse -> Pond -> Gazebo -> Orchard -> Bench", "Gate, Path, Greenhouse, Pond, Gazebo, Orchard, Bench"),
            ("Path: Dock -> Ferry -> Island -> Cave -> Summit -> Waterfall -> Camp", "Dock, Ferry, Island, Cave, Summit, Waterfall, Camp"),
            ("Path: Entrance -> Hall -> Kitchen -> Dining -> Study -> Bedroom -> Attic -> Cellar", "Entrance, Hall, Kitchen, Dining, Study, Bedroom, Attic, Cellar"),
            ("Path: Station -> Platform -> Train -> Countryside -> Village -> Inn -> Castle -> Tower", "Station, Platform, Train, Countryside, Village, Inn, Castle, Tower"),
            ("Path: Trailhead -> Creek -> Ridge -> Meadow -> Forest -> Clearing -> Cabin", "Trailhead, Creek, Ridge, Meadow, Forest, Clearing, Cabin"),
            ("Path: Parking -> Lobby -> Pool -> Spa -> Sauna -> Lounge -> Terrace -> Garden", "Parking, Lobby, Pool, Spa, Sauna, Lounge, Terrace, Garden"),
            ("Path: Runway -> Terminal -> Lounge -> Gate -> Plane -> Aisle -> Window -> Cloud", "Runway, Terminal, Lounge, Gate, Plane, Aisle, Window, Cloud"),
        ]
    }

    static func generateScenarioCards() -> [(prompt: String, answer: String)] {
        [
            ("At the meeting, remember:\n1. Budget is $45,000\n2. Deadline is March 15\n3. Lead designer is Rachel\n4. Client is Vertex Corp", "Budget: $45,000, Deadline: March 15, Lead: Rachel, Client: Vertex Corp"),
            ("Your friend tells you:\n1. Party is Saturday at 7pm\n2. Address is 242 Oak Street\n3. Bring a dessert\n4. Theme is 80s", "Saturday 7pm, 242 Oak Street, bring dessert, 80s theme"),
            ("Doctor's instructions:\n1. Take medication twice daily\n2. Avoid dairy for 48 hours\n3. Follow-up appointment Thursday\n4. Call if fever exceeds 101F", "Twice daily, no dairy 48hrs, Thursday follow-up, call if fever >101F"),
            ("New coworker introduction:\n1. Name is Jordan Park\n2. From Seattle\n3. Previously at Google\n4. Specialty is data analytics", "Jordan Park, from Seattle, ex-Google, data analytics"),
            ("Grocery list from roommate:\n1. Oat milk\n2. Sourdough bread\n3. Avocados (3)\n4. Cherry tomatoes\n5. Hummus", "Oat milk, sourdough bread, 3 avocados, cherry tomatoes, hummus"),
            ("Travel details:\n1. Flight UA 847\n2. Gate B12\n3. Boards at 3:45pm\n4. Seat 14C\n5. Connecting in Denver", "UA 847, Gate B12, boards 3:45pm, seat 14C, connecting Denver"),
            ("Boss's requests:\n1. Email the Q3 report to Sarah\n2. Book conference room for Tuesday 2pm\n3. Update the project timeline\n4. Call vendor about shipping delay", "Email Q3 to Sarah, book room Tue 2pm, update timeline, call vendor re shipping"),
            ("Neighbor introduces herself:\n1. Name is Diana Chen\n2. Unit 4B\n3. Has a golden retriever named Max\n4. Works from home\n5. Allergic to cats", "Diana Chen, unit 4B, dog Max (golden retriever), works from home, allergic to cats"),
            ("Recipe from a friend:\n1. Preheat oven to 375F\n2. Mix flour, sugar, and butter\n3. Add 2 eggs and vanilla\n4. Bake for 25 minutes\n5. Let cool for 10 minutes", "375F, mix flour/sugar/butter, 2 eggs + vanilla, bake 25 min, cool 10 min"),
            ("Car mechanic says:\n1. Oil change needed in 2000 miles\n2. Left rear tire pressure low\n3. Brake pads at 40%\n4. Cabin filter replaced\n5. Total bill is $287", "Oil change in 2000mi, left rear tire low, brakes 40%, filter replaced, $287"),
            ("Landlord's message:\n1. Maintenance on Thursday between 10am-2pm\n2. Water will be shut off\n3. Elevator inspection next Monday\n4. Rent increase of $50 starting April", "Maintenance Thu 10-2, water off, elevator Mon, rent +$50 April"),
            ("Study group plan:\n1. Meet at the library 3rd floor\n2. Saturday at 1pm\n3. Cover chapters 7-9\n4. Bring laptops\n5. Quiz each other on key terms", "Library 3rd floor, Sat 1pm, chapters 7-9, bring laptops, quiz key terms"),
            ("Wedding details:\n1. Ceremony at St. Mark's at 4pm\n2. Reception at The Grand Hotel\n3. Dress code is cocktail\n4. Gift registry at Crate & Barrel\n5. RSVP by March 1st", "St. Mark's 4pm, reception Grand Hotel, cocktail dress, Crate & Barrel registry, RSVP Mar 1"),
            ("Trainer's instructions:\n1. Warm up 5 minutes\n2. 3 sets of 12 squats\n3. 3 sets of 10 push-ups\n4. 2-minute plank\n5. Cool down stretch\n6. Drink 20oz water after", "5min warmup, 3x12 squats, 3x10 pushups, 2min plank, cooldown, 20oz water"),
            ("Phone message from mom:\n1. Dad's birthday is next Sunday\n2. Dinner at Olive Garden at 6pm\n3. Aunt Carol is coming from Portland\n4. She got him a watch\n5. Bring a card", "Dad bday next Sun, Olive Garden 6pm, Aunt Carol from Portland, got him watch, bring card"),
            ("Tech support steps:\n1. Restart the router\n2. Wait 30 seconds\n3. Check if light turns green\n4. Connect to 'Home_5G' network\n5. Password is BlueSky2024\n6. Run speed test", "Restart router, wait 30s, green light, Home_5G, BlueSky2024, speed test"),
            ("Project kickoff notes:\n1. Sprint starts Monday\n2. Daily standup at 9:15am\n3. Use Jira board 'Phoenix'\n4. Design review Friday\n5. MVP due in 3 weeks", "Sprint Mon, standup 9:15am, Jira Phoenix, design review Fri, MVP 3 weeks"),
            ("Apartment viewing:\n1. Address: 88 Elm Court, Apt 3A\n2. Tomorrow at 11am\n3. Ask about parking\n4. $1,850/month\n5. 1 bedroom, pets allowed", "88 Elm Ct Apt 3A, tomorrow 11am, ask parking, $1850/mo, 1BR pets ok"),
            ("Conference schedule:\n1. Keynote at 9am in Hall A\n2. Workshop at 11am Room 204\n3. Lunch at 12:30pm\n4. Panel discussion 2pm Hall B\n5. Networking event 5pm rooftop", "Keynote 9am Hall A, workshop 11am Rm 204, lunch 12:30, panel 2pm Hall B, networking 5pm roof"),
            ("Friend's new info:\n1. New phone number: 555-0147\n2. Moved to Brooklyn\n3. Started a podcast about cooking\n4. Got engaged to Alex\n5. New job at a startup called Nova", "555-0147, Brooklyn, cooking podcast, engaged to Alex, works at Nova"),
        ]
    }

    static func createInitialCards(for category: CardCategory) -> [SpacedRepetitionCard] {
        let data: [(prompt: String, answer: String)]

        switch category {
        case .numbers: data = generateNumberCards()
        case .words: data = generateWordCards()
        case .faces: data = generateFaceCards()
        case .locations: data = generateLocationCards()
        case .sequences: data = generateScenarioCards()
        }

        return data.map { SpacedRepetitionCard(category: category, prompt: $0.prompt, answer: $0.answer) }
    }
}
