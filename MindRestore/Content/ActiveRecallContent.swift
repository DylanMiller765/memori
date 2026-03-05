import Foundation

enum ActiveRecallContent {

    static let challenges: [ActiveRecallChallenge] = storyRecallChallenges + instructionRecallChallenges + conversationRecallChallenges

    static let storyRecallChallenges: [ActiveRecallChallenge] = [
        ActiveRecallChallenge(
            type: .storyRecall,
            title: "The Coffee Shop",
            displayContent: "Maria walked into the Blue Moon cafe at exactly 2:15pm. She ordered a large oat milk latte and a blueberry scone. The barista, whose name tag read 'Jake', mentioned they were closing early at 5pm today due to a private event. Maria sat at the window table and opened her laptop to work on her thesis about marine biology.",
            displayDuration: 30,
            questions: [
                RecallQuestion(question: "What was the name of the cafe?", answer: "Blue Moon"),
                RecallQuestion(question: "What time did Maria arrive?", answer: "2:15pm"),
                RecallQuestion(question: "What was the barista's name?", answer: "Jake"),
                RecallQuestion(question: "What did Maria order to eat?", answer: "Blueberry scone"),
                RecallQuestion(question: "What was her thesis about?", answer: "Marine biology"),
            ],
            difficulty: 1
        ),
        ActiveRecallChallenge(
            type: .storyRecall,
            title: "The Meeting",
            displayContent: "Tom arrived at the Vertex Corp headquarters on 5th Avenue at 9:30am for a meeting with the CEO, Patricia Wells. The meeting room was on the 14th floor, Room 1402. There were 6 people in attendance. The main topic was the Q2 budget, which had been set at $2.3 million. Patricia mentioned that the next review would be on April 8th.",
            displayDuration: 30,
            questions: [
                RecallQuestion(question: "What street was the headquarters on?", answer: "5th Avenue"),
                RecallQuestion(question: "What was the CEO's name?", answer: "Patricia Wells"),
                RecallQuestion(question: "What floor was the meeting on?", answer: "14th"),
                RecallQuestion(question: "How many people attended?", answer: "6"),
                RecallQuestion(question: "What was the budget amount?", answer: "$2.3 million"),
            ],
            difficulty: 2
        ),
        ActiveRecallChallenge(
            type: .storyRecall,
            title: "The Trip",
            displayContent: "Sarah and her roommate Kenji booked a flight to Lisbon on TAP Air Portugal, departing from JFK on March 22nd. Their hotel, the Bairro Alto, was a 3-star place near Rossio Square. They planned to visit the Belem Tower on day two and eat at a restaurant called Time Out Market. The total trip cost was $1,400 per person for 5 nights.",
            displayDuration: 30,
            questions: [
                RecallQuestion(question: "What airline did they book?", answer: "TAP Air Portugal"),
                RecallQuestion(question: "What was the roommate's name?", answer: "Kenji"),
                RecallQuestion(question: "What was the hotel name?", answer: "Bairro Alto"),
                RecallQuestion(question: "What landmark did they plan to visit on day two?", answer: "Belem Tower"),
                RecallQuestion(question: "How much was the trip per person?", answer: "$1,400"),
            ],
            difficulty: 2
        ),
        ActiveRecallChallenge(
            type: .storyRecall,
            title: "The Neighborhood",
            displayContent: "Detective Lin surveyed the scene at 47 Maple Drive. The red Toyota Camry had a dent on the passenger side. The neighbor, Mrs. Hoffman in unit 49, reported hearing a loud noise at approximately 11:45pm. She described seeing a tall man in a dark green jacket leaving quickly. The security camera at the corner store, Pete's Deli, was pointed in the wrong direction.",
            displayDuration: 30,
            questions: [
                RecallQuestion(question: "What was the address?", answer: "47 Maple Drive"),
                RecallQuestion(question: "What color was the car?", answer: "Red"),
                RecallQuestion(question: "What was the neighbor's name?", answer: "Mrs. Hoffman"),
                RecallQuestion(question: "What time did she hear the noise?", answer: "11:45pm"),
                RecallQuestion(question: "What color was the jacket?", answer: "Dark green"),
            ],
            difficulty: 3
        ),
        ActiveRecallChallenge(
            type: .storyRecall,
            title: "The Birthday",
            displayContent: "Last Saturday, we threw a surprise party for Olivia's 28th birthday at the rooftop bar called Skyline on 8th Street. About 15 people showed up. Her boyfriend Mateo organized the whole thing and ordered a 3-tier chocolate cake from Sweet Surrender bakery. The DJ played her favorite song, 'Dancing Queen' by ABBA, right when she walked in at 8pm.",
            displayDuration: 30,
            questions: [
                RecallQuestion(question: "How old was Olivia turning?", answer: "28"),
                RecallQuestion(question: "What was the venue name?", answer: "Skyline"),
                RecallQuestion(question: "Who organized the party?", answer: "Mateo"),
                RecallQuestion(question: "Where was the cake from?", answer: "Sweet Surrender"),
                RecallQuestion(question: "What was her favorite song?", answer: "Dancing Queen"),
            ],
            difficulty: 2
        ),
    ]

    static let instructionRecallChallenges: [ActiveRecallChallenge] = [
        ActiveRecallChallenge(
            type: .instructionRecall,
            title: "Pasta Carbonara",
            displayContent: "Step 1: Boil a large pot of salted water\nStep 2: Cook 400g spaghetti for 8 minutes\nStep 3: Fry 200g guanciale until crispy\nStep 4: Whisk 4 egg yolks with pecorino cheese\nStep 5: Toss hot pasta with guanciale\nStep 6: Remove from heat and stir in egg mixture",
            displayDuration: 25,
            questions: [
                RecallQuestion(question: "What is step 1?", answer: "Boil a large pot of salted water"),
                RecallQuestion(question: "How long do you cook the spaghetti?", answer: "8 minutes"),
                RecallQuestion(question: "What do you fry until crispy?", answer: "Guanciale"),
                RecallQuestion(question: "What do you whisk the egg yolks with?", answer: "Pecorino cheese"),
                RecallQuestion(question: "What is the last step?", answer: "Remove from heat and stir in egg mixture"),
            ],
            difficulty: 1
        ),
        ActiveRecallChallenge(
            type: .instructionRecall,
            title: "Flat Tire Change",
            displayContent: "Step 1: Pull over safely and turn on hazard lights\nStep 2: Get the jack, wrench, and spare from the trunk\nStep 3: Loosen the lug nuts slightly before jacking up\nStep 4: Place the jack under the frame near the flat tire\nStep 5: Raise the vehicle until the tire is 6 inches off the ground\nStep 6: Remove the lug nuts and pull off the flat tire",
            displayDuration: 25,
            questions: [
                RecallQuestion(question: "What should you turn on first?", answer: "Hazard lights"),
                RecallQuestion(question: "What three things do you get from the trunk?", answer: "Jack, wrench, and spare"),
                RecallQuestion(question: "What do you do before jacking up?", answer: "Loosen the lug nuts slightly"),
                RecallQuestion(question: "How high should you raise the vehicle?", answer: "6 inches off the ground"),
                RecallQuestion(question: "What is step 6?", answer: "Remove the lug nuts and pull off the flat tire"),
            ],
            difficulty: 2
        ),
        ActiveRecallChallenge(
            type: .instructionRecall,
            title: "CPR Instructions",
            displayContent: "Step 1: Check if the person is responsive by tapping shoulders\nStep 2: Call 911 or have someone call\nStep 3: Place the heel of your hand on the center of the chest\nStep 4: Push hard and fast — 2 inches deep, 100-120 per minute\nStep 5: Give 30 compressions then 2 rescue breaths\nStep 6: Continue until help arrives or an AED is available",
            displayDuration: 25,
            questions: [
                RecallQuestion(question: "How do you check if someone is responsive?", answer: "Tap their shoulders"),
                RecallQuestion(question: "Where do you place your hand?", answer: "Center of the chest"),
                RecallQuestion(question: "How deep should compressions be?", answer: "2 inches"),
                RecallQuestion(question: "What is the compression rate?", answer: "100-120 per minute"),
                RecallQuestion(question: "What is the ratio of compressions to breaths?", answer: "30 to 2"),
            ],
            difficulty: 2
        ),
        ActiveRecallChallenge(
            type: .instructionRecall,
            title: "Plant Repotting",
            displayContent: "Step 1: Choose a pot 2 inches wider than the current one\nStep 2: Add drainage rocks to the bottom of the new pot\nStep 3: Fill 1/3 of the pot with fresh potting soil\nStep 4: Gently remove the plant and shake off old soil\nStep 5: Place plant in center and fill around with soil\nStep 6: Water thoroughly and place in indirect sunlight for 3 days",
            displayDuration: 25,
            questions: [
                RecallQuestion(question: "How much bigger should the new pot be?", answer: "2 inches wider"),
                RecallQuestion(question: "What goes at the bottom of the new pot?", answer: "Drainage rocks"),
                RecallQuestion(question: "How much soil do you add first?", answer: "1/3 of the pot"),
                RecallQuestion(question: "What do you do after removing the plant?", answer: "Shake off old soil"),
                RecallQuestion(question: "How long should it be in indirect sunlight?", answer: "3 days"),
            ],
            difficulty: 1
        ),
        ActiveRecallChallenge(
            type: .instructionRecall,
            title: "Home Security Setup",
            displayContent: "Step 1: Install the base station near the router using ethernet\nStep 2: Download the SafeHome app and create an account\nStep 3: Scan the QR code on the base station to pair\nStep 4: Place door sensors on all exterior doors — 3 total\nStep 5: Mount the motion detector in the hallway at 7 feet high\nStep 6: Set your 4-digit PIN and arm the system in 'Away' mode",
            displayDuration: 25,
            questions: [
                RecallQuestion(question: "Where should the base station be installed?", answer: "Near the router"),
                RecallQuestion(question: "What app do you download?", answer: "SafeHome"),
                RecallQuestion(question: "How do you pair the base station?", answer: "Scan the QR code"),
                RecallQuestion(question: "How many door sensors are needed?", answer: "3"),
                RecallQuestion(question: "How high should the motion detector be mounted?", answer: "7 feet"),
            ],
            difficulty: 3
        ),
    ]

    static let conversationRecallChallenges: [ActiveRecallChallenge] = [
        ActiveRecallChallenge(
            type: .conversationRecall,
            title: "Dinner Plans",
            displayContent: "Alex: Hey want to grab dinner tonight?\nJordan: Sure! What about that new Thai place on Cedar Ave?\nAlex: Siam Garden? I heard it's good. 7pm work?\nJordan: Can we do 7:30? I have a meeting until 6:45\nAlex: Perfect. I'll make a reservation for 3 — Sam is coming too\nJordan: Nice! Tell Sam to try the pad see ew, it's apparently amazing",
            displayDuration: 25,
            questions: [
                RecallQuestion(question: "What type of restaurant was suggested?", answer: "Thai"),
                RecallQuestion(question: "What street is the restaurant on?", answer: "Cedar Ave"),
                RecallQuestion(question: "What time did they agree on?", answer: "7:30"),
                RecallQuestion(question: "How many people is the reservation for?", answer: "3"),
                RecallQuestion(question: "What dish was recommended?", answer: "Pad see ew"),
            ],
            difficulty: 1
        ),
        ActiveRecallChallenge(
            type: .conversationRecall,
            title: "Moving Day",
            displayContent: "Casey: I'm moving next Saturday. Can you help?\nRiley: What time?\nCasey: We're starting at 8am. The truck comes at 9\nRiley: Which apartment are you moving to?\nCasey: 12B in the Oakwood complex on Vine Street\nRiley: I'll bring my dolly. Should I pick up boxes from Home Depot?\nCasey: That'd be great — we need about 15 medium boxes",
            displayDuration: 25,
            questions: [
                RecallQuestion(question: "What day is the move?", answer: "Saturday"),
                RecallQuestion(question: "What time does the truck arrive?", answer: "9am"),
                RecallQuestion(question: "What apartment number?", answer: "12B"),
                RecallQuestion(question: "What will Riley bring?", answer: "A dolly"),
                RecallQuestion(question: "How many boxes are needed?", answer: "15"),
            ],
            difficulty: 2
        ),
        ActiveRecallChallenge(
            type: .conversationRecall,
            title: "Job Update",
            displayContent: "Taylor: I got the job at Meridian Tech!\nMorgan: No way! What's the role?\nTaylor: Senior UX designer. Start date is April 14th\nMorgan: That's awesome! What's the salary like?\nTaylor: $95k base plus a $5k signing bonus\nMorgan: Are you still going to work remote?\nTaylor: Hybrid — 3 days in office, 2 from home. Office is in the Pearl District",
            displayDuration: 25,
            questions: [
                RecallQuestion(question: "What company did Taylor get hired at?", answer: "Meridian Tech"),
                RecallQuestion(question: "What is the job title?", answer: "Senior UX designer"),
                RecallQuestion(question: "What is the start date?", answer: "April 14th"),
                RecallQuestion(question: "How much is the signing bonus?", answer: "$5k"),
                RecallQuestion(question: "How many days in office?", answer: "3"),
            ],
            difficulty: 2
        ),
        ActiveRecallChallenge(
            type: .conversationRecall,
            title: "Weekend Trip",
            displayContent: "Nora: Road trip to Big Sur this weekend?\nEthan: I'm in! My car or yours?\nNora: Mine — the Honda gets better mileage. It's about 340 miles\nEthan: Should we stop in Paso Robles for wine tasting?\nNora: Yes! I know a place called Eberle Winery. Let's leave Friday at 6am\nEthan: I'll bring the camping gear. We have that spot at Pfeiffer reserved right?\nNora: Yep, campsite 23. Two nights, Friday and Saturday",
            displayDuration: 25,
            questions: [
                RecallQuestion(question: "Where are they going?", answer: "Big Sur"),
                RecallQuestion(question: "What kind of car are they taking?", answer: "Honda"),
                RecallQuestion(question: "Where will they stop for wine?", answer: "Paso Robles"),
                RecallQuestion(question: "What winery did Nora suggest?", answer: "Eberle Winery"),
                RecallQuestion(question: "What is the campsite number?", answer: "23"),
            ],
            difficulty: 3
        ),
        ActiveRecallChallenge(
            type: .conversationRecall,
            title: "Doctor's Advice",
            displayContent: "Dr. Kim: Your blood work came back mostly normal\nPatient: Mostly?\nDr. Kim: Your vitamin D is low — 18 ng/mL. We want it above 30\nPatient: What should I do?\nDr. Kim: Take 2000 IU of vitamin D3 daily with a meal\nPatient: Anything else?\nDr. Kim: Your cholesterol is borderline — 210. Try reducing saturated fat. Let's recheck in 3 months, so book a follow-up for June",
            displayDuration: 25,
            questions: [
                RecallQuestion(question: "What was the vitamin D level?", answer: "18"),
                RecallQuestion(question: "What is the target vitamin D level?", answer: "Above 30"),
                RecallQuestion(question: "How much vitamin D3 should be taken daily?", answer: "2000 IU"),
                RecallQuestion(question: "What was the cholesterol level?", answer: "210"),
                RecallQuestion(question: "When is the follow-up?", answer: "June"),
            ],
            difficulty: 3
        ),
    ]
}
