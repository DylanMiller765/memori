import XCTest
@testable import MindRestore

// MARK: - ChallengeLink v1.5 Tests

final class ChallengeLinkV15Tests: XCTestCase {

    // MARK: - vercelURL Generation

    func testVercelURLScheme() {
        let link = ChallengeLink(game: .reactionTime, seed: 12345, score: 288, challengerName: "Dylan")
        let url = link.vercelURL!

        XCTAssertEqual(url.scheme, "https")
    }

    func testVercelURLHost() {
        let link = ChallengeLink(game: .reactionTime, seed: 12345, score: 288, challengerName: "Dylan")
        let url = link.vercelURL!

        XCTAssertEqual(url.host, "memori-website-sooty.vercel.app")
    }

    func testVercelURLPath() {
        let link = ChallengeLink(game: .reactionTime, seed: 12345, score: 288, challengerName: "Dylan")
        let url = link.vercelURL!

        XCTAssertEqual(url.path, "/challenge")
    }

    func testVercelURLQueryParams() {
        let link = ChallengeLink(game: .colorMatch, seed: 54321, score: 92, challengerName: "TestUser")
        let url = link.vercelURL!
        let components = URLComponents(url: url, resolvingAgainstBaseURL: false)!
        let params = components.queryItems!

        XCTAssertEqual(params.first(where: { $0.name == "game" })?.value, "colorMatch")
        XCTAssertEqual(params.first(where: { $0.name == "seed" })?.value, "54321")
        XCTAssertEqual(params.first(where: { $0.name == "score" })?.value, "92")
        XCTAssertEqual(params.first(where: { $0.name == "name" })?.value, "TestUser")
    }

    func testVercelURLWithSpacesInName() {
        let link = ChallengeLink(game: .mathSpeed, seed: 11111, score: 15, challengerName: "Dylan Miller")
        let url = link.vercelURL!
        let components = URLComponents(url: url, resolvingAgainstBaseURL: false)!

        XCTAssertEqual(components.queryItems?.first(where: { $0.name == "name" })?.value, "Dylan Miller")
    }

    // MARK: - shareMessage()

    func testShareMessageIncludesDisplayText() {
        let link = ChallengeLink(game: .reactionTime, seed: 12345, score: 288, challengerName: "Dylan")
        let message = link.shareMessage()

        XCTAssertTrue(message.contains("288ms"), "Share message should include the game display text '288ms'")
    }

    func testShareMessageIncludesGameName() {
        let link = ChallengeLink(game: .reactionTime, seed: 12345, score: 288, challengerName: "Dylan")
        let message = link.shareMessage()

        XCTAssertTrue(message.contains("Reaction Time"), "Share message should include the game name")
    }

    func testShareMessageIncludesVercelURL() {
        let link = ChallengeLink(game: .reactionTime, seed: 12345, score: 288, challengerName: "Dylan")
        let message = link.shareMessage()
        let expectedURL = link.vercelURL!.absoluteString

        XCTAssertTrue(message.contains(expectedURL), "Share message should include the vercel URL")
    }

    func testShareMessageEmojiForReactionTime() {
        let link = ChallengeLink(game: .reactionTime, seed: 1, score: 250, challengerName: "A")
        XCTAssertTrue(link.shareMessage().contains("⚡"))
    }

    func testShareMessageEmojiForColorMatch() {
        let link = ChallengeLink(game: .colorMatch, seed: 1, score: 95, challengerName: "A")
        XCTAssertTrue(link.shareMessage().contains("🎨"))
    }

    func testShareMessageEmojiForVisualMemory() {
        let link = ChallengeLink(game: .visualMemory, seed: 1, score: 8, challengerName: "A")
        XCTAssertTrue(link.shareMessage().contains("🟦"))
    }

    func testShareMessageEmojiForChimpTest() {
        let link = ChallengeLink(game: .chimpTest, seed: 1, score: 12, challengerName: "A")
        XCTAssertTrue(link.shareMessage().contains("🐵"))
    }

    func testShareMessageEmojiForVerbalMemory() {
        let link = ChallengeLink(game: .verbalMemory, seed: 1, score: 50, challengerName: "A")
        XCTAssertTrue(link.shareMessage().contains("📝"))
    }

    func testShareMessageEmojiForMathSpeed() {
        let link = ChallengeLink(game: .mathSpeed, seed: 1, score: 15, challengerName: "A")
        XCTAssertTrue(link.shareMessage().contains("🧮"))
    }

    func testShareMessageEmojiForDualNBack() {
        let link = ChallengeLink(game: .dualNBack, seed: 1, score: 3, challengerName: "A")
        XCTAssertTrue(link.shareMessage().contains("🧠"))
    }

    func testShareMessageEmojiForChunkingTraining() {
        let link = ChallengeLink(game: .chunkingTraining, seed: 1, score: 10, challengerName: "A")
        XCTAssertTrue(link.shareMessage().contains("📦"))
    }

    func testShareMessageEmojiForSequentialMemory() {
        let link = ChallengeLink(game: .sequentialMemory, seed: 1, score: 7, challengerName: "A")
        XCTAssertTrue(link.shareMessage().contains("🔢"))
    }

    func testShareMessageEmojiForSpeedMatch() {
        let link = ChallengeLink(game: .speedMatch, seed: 1, score: 88, challengerName: "A")
        XCTAssertTrue(link.shareMessage().contains("⚡"))
    }
}

// MARK: - ExerciseType Challenge Extensions Tests

final class ExerciseTypeChallengeTests: XCTestCase {

    // MARK: - challengeEmoji

    func testChallengeEmojiReactionTime() {
        XCTAssertEqual(ExerciseType.reactionTime.challengeEmoji, "⚡")
    }

    func testChallengeEmojiColorMatch() {
        XCTAssertEqual(ExerciseType.colorMatch.challengeEmoji, "🎨")
    }

    func testChallengeEmojiSpeedMatch() {
        XCTAssertEqual(ExerciseType.speedMatch.challengeEmoji, "⚡")
    }

    func testChallengeEmojiVisualMemory() {
        XCTAssertEqual(ExerciseType.visualMemory.challengeEmoji, "🟦")
    }

    func testChallengeEmojiSequentialMemory() {
        XCTAssertEqual(ExerciseType.sequentialMemory.challengeEmoji, "🔢")
    }

    func testChallengeEmojiMathSpeed() {
        XCTAssertEqual(ExerciseType.mathSpeed.challengeEmoji, "🧮")
    }

    func testChallengeEmojiDualNBack() {
        XCTAssertEqual(ExerciseType.dualNBack.challengeEmoji, "🧠")
    }

    func testChallengeEmojiChunkingTraining() {
        XCTAssertEqual(ExerciseType.chunkingTraining.challengeEmoji, "📦")
    }

    func testChallengeEmojiChimpTest() {
        XCTAssertEqual(ExerciseType.chimpTest.challengeEmoji, "🐵")
    }

    func testChallengeEmojiVerbalMemory() {
        XCTAssertEqual(ExerciseType.verbalMemory.challengeEmoji, "📝")
    }

    // MARK: - challengeDisplayText

    func testDisplayTextReactionTime() {
        XCTAssertEqual(ExerciseType.reactionTime.challengeDisplayText(score: 288), "288ms")
    }

    func testDisplayTextColorMatch() {
        XCTAssertEqual(ExerciseType.colorMatch.challengeDisplayText(score: 92), "92%")
    }

    func testDisplayTextSpeedMatch() {
        XCTAssertEqual(ExerciseType.speedMatch.challengeDisplayText(score: 85), "85%")
    }

    func testDisplayTextVisualMemory() {
        XCTAssertEqual(ExerciseType.visualMemory.challengeDisplayText(score: 8), "Level 8")
    }

    func testDisplayTextSequentialMemory() {
        XCTAssertEqual(ExerciseType.sequentialMemory.challengeDisplayText(score: 7), "7 digits")
    }

    func testDisplayTextMathSpeed() {
        XCTAssertEqual(ExerciseType.mathSpeed.challengeDisplayText(score: 15), "15 solved")
    }

    func testDisplayTextDualNBack() {
        XCTAssertEqual(ExerciseType.dualNBack.challengeDisplayText(score: 3), "N=3")
    }

    func testDisplayTextChunkingTraining() {
        XCTAssertEqual(ExerciseType.chunkingTraining.challengeDisplayText(score: 10), "10 correct")
    }

    func testDisplayTextChimpTest() {
        XCTAssertEqual(ExerciseType.chimpTest.challengeDisplayText(score: 12), "Level 12")
    }

    func testDisplayTextVerbalMemory() {
        XCTAssertEqual(ExerciseType.verbalMemory.challengeDisplayText(score: 50), "50 words")
    }
}

// MARK: - PaywallTriggerService Try-Each-Game-Once Tests

@MainActor
final class PaywallTriggerServiceTryOnceTests: XCTestCase {

    private var service: PaywallTriggerService!
    private let suiteName = "PaywallTriggerServiceTests"

    override func setUp() {
        super.setUp()
        // Use a fresh UserDefaults suite to avoid polluting real defaults
        let testDefaults = UserDefaults(suiteName: suiteName)!
        testDefaults.removePersistentDomain(forName: suiteName)

        service = PaywallTriggerService()
        // Clear the keys used by the service in standard defaults
        UserDefaults.standard.removeObject(forKey: "tried_game_types")
        UserDefaults.standard.removeObject(forKey: "daily_exercise_count")
        UserDefaults.standard.removeObject(forKey: "daily_exercise_date")
    }

    override func tearDown() {
        UserDefaults.standard.removeObject(forKey: "tried_game_types")
        UserDefaults.standard.removeObject(forKey: "daily_exercise_count")
        UserDefaults.standard.removeObject(forKey: "daily_exercise_date")
        service = nil
        super.tearDown()
    }

    // MARK: - isFirstTimeGame

    func testIsFirstTimeGameReturnsTrueForNeverPlayedGame() {
        XCTAssertTrue(service.isFirstTimeGame(.reactionTime),
                      "A game type that has never been played should return true for isFirstTimeGame")
    }

    func testIsFirstTimeGameReturnsTrueForAllGamesInitially() {
        let gameTypes: [ExerciseType] = [
            .reactionTime, .colorMatch, .speedMatch, .visualMemory,
            .sequentialMemory, .mathSpeed, .dualNBack, .chunkingTraining,
            .chimpTest, .verbalMemory
        ]
        for gameType in gameTypes {
            XCTAssertTrue(service.isFirstTimeGame(gameType),
                          "\(gameType.rawValue) should be first time initially")
        }
    }

    func testIsFirstTimeGameReturnsFalseAfterRecording() {
        service.recordExerciseCompleted(gameType: .reactionTime)

        XCTAssertFalse(service.isFirstTimeGame(.reactionTime),
                       "After recording reactionTime, isFirstTimeGame should return false")
    }

    func testIsFirstTimeGameOnlyAffectsRecordedType() {
        service.recordExerciseCompleted(gameType: .reactionTime)

        XCTAssertFalse(service.isFirstTimeGame(.reactionTime))
        XCTAssertTrue(service.isFirstTimeGame(.colorMatch),
                      "Recording reactionTime should not affect colorMatch")
        XCTAssertTrue(service.isFirstTimeGame(.mathSpeed),
                      "Recording reactionTime should not affect mathSpeed")
    }

    // MARK: - Daily Exercise Count

    func testFirstTimeGameDoesNotIncreaseDailyCount() {
        let countBefore = service.exercisesToday
        service.recordExerciseCompleted(gameType: .reactionTime)
        let countAfter = service.exercisesToday

        XCTAssertEqual(countBefore, 0, "Count should start at 0")
        XCTAssertEqual(countAfter, 0,
                       "First-time game play should NOT increase the daily exercise count")
    }

    func testSecondPlayOfSameGameCountsTowardDailyLimit() {
        // First play: try-once free pass
        service.recordExerciseCompleted(gameType: .reactionTime)
        XCTAssertEqual(service.exercisesToday, 0, "First play should not count")

        // Second play: should count
        service.recordExerciseCompleted(gameType: .reactionTime)
        XCTAssertEqual(service.exercisesToday, 1,
                       "Second play of the same game should count toward daily limit")
    }

    func testMultipleFirstTimeGamesDoNotCount() {
        service.recordExerciseCompleted(gameType: .reactionTime)
        service.recordExerciseCompleted(gameType: .colorMatch)
        service.recordExerciseCompleted(gameType: .visualMemory)

        XCTAssertEqual(service.exercisesToday, 0,
                       "Playing 3 different games for the first time should not increase daily count")
    }

    func testMixOfFirstTimeAndRepeatGames() {
        // First-time plays (free)
        service.recordExerciseCompleted(gameType: .reactionTime)
        service.recordExerciseCompleted(gameType: .colorMatch)

        // Repeat play (counts)
        service.recordExerciseCompleted(gameType: .reactionTime)
        XCTAssertEqual(service.exercisesToday, 1)

        // Another first-time (free)
        service.recordExerciseCompleted(gameType: .mathSpeed)
        XCTAssertEqual(service.exercisesToday, 1, "New first-time game should not increase count")

        // Another repeat (counts)
        service.recordExerciseCompleted(gameType: .colorMatch)
        XCTAssertEqual(service.exercisesToday, 2)
    }

    // MARK: - UserDefaults Persistence

    func testTriedGameTypesPersistInUserDefaults() {
        service.recordExerciseCompleted(gameType: .reactionTime)
        service.recordExerciseCompleted(gameType: .colorMatch)

        // Read directly from UserDefaults
        let stored = UserDefaults.standard.stringArray(forKey: "tried_game_types") ?? []
        let storedSet = Set(stored)

        XCTAssertTrue(storedSet.contains("reactionTime"),
                      "reactionTime should be persisted in UserDefaults")
        XCTAssertTrue(storedSet.contains("colorMatch"),
                      "colorMatch should be persisted in UserDefaults")
    }

    func testNewServiceInstanceReadsPersistedTriedGames() {
        service.recordExerciseCompleted(gameType: .reactionTime)

        // Create a new service instance (simulating app restart)
        let newService = PaywallTriggerService()

        XCTAssertFalse(newService.isFirstTimeGame(.reactionTime),
                       "New service instance should read persisted tried games")
        XCTAssertTrue(newService.isFirstTimeGame(.colorMatch),
                      "Games not yet tried should still be first-time in new instance")
    }

    // MARK: - recordExerciseCompleted without gameType

    func testRecordWithoutGameTypeAlwaysCountsTowardDaily() {
        service.recordExerciseCompleted()
        XCTAssertEqual(service.exercisesToday, 1,
                       "Calling recordExerciseCompleted without a gameType should always count")
    }
}
