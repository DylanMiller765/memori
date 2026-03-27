import XCTest
@testable import MindRestore

final class ChallengeLinkTests: XCTestCase {

    // MARK: - URL Generation

    func testURLGeneration() {
        let link = ChallengeLink(game: .reactionTime, seed: 12345, score: 288, challengerName: "Dylan")
        let url = link.url!

        XCTAssertEqual(url.scheme, "memori")
        XCTAssertEqual(url.host, "duel")

        let components = URLComponents(url: url, resolvingAgainstBaseURL: false)!
        let params = components.queryItems!

        XCTAssertEqual(params.first(where: { $0.name == "game" })?.value, "reactionTime")
        XCTAssertEqual(params.first(where: { $0.name == "seed" })?.value, "12345")
        XCTAssertEqual(params.first(where: { $0.name == "score" })?.value, "288")
        XCTAssertEqual(params.first(where: { $0.name == "name" })?.value, "Dylan")
    }

    func testURLGenerationWithSpacesInName() {
        let link = ChallengeLink(game: .colorMatch, seed: 99999, score: 95940, challengerName: "Dylan Miller")
        let url = link.url!

        // Name with space should be URL-encoded
        let components = URLComponents(url: url, resolvingAgainstBaseURL: false)!
        XCTAssertEqual(components.queryItems?.first(where: { $0.name == "name" })?.value, "Dylan Miller")
    }

    // MARK: - URL Parsing

    func testParsingValidURL() {
        let url = URL(string: "memori://duel?game=reactionTime&seed=12345&score=288&name=Dylan")!
        let link = ChallengeLink(url: url)

        XCTAssertNotNil(link)
        XCTAssertEqual(link?.game, .reactionTime)
        XCTAssertEqual(link?.seed, 12345)
        XCTAssertEqual(link?.score, 288)
        XCTAssertEqual(link?.challengerName, "Dylan")
    }

    func testParsingURLWithEncodedSpaces() {
        let url = URL(string: "memori://duel?game=colorMatch&seed=55555&score=100&name=Dylan%20Miller")!
        let link = ChallengeLink(url: url)

        XCTAssertNotNil(link)
        XCTAssertEqual(link?.challengerName, "Dylan Miller")
    }

    func testParsingInvalidScheme() {
        let url = URL(string: "https://duel?game=reactionTime&seed=12345&score=288&name=Dylan")!
        let link = ChallengeLink(url: url)

        XCTAssertNil(link)
    }

    func testParsingInvalidHost() {
        let url = URL(string: "memori://home?game=reactionTime&seed=12345&score=288&name=Dylan")!
        let link = ChallengeLink(url: url)

        XCTAssertNil(link)
    }

    func testParsingMissingParameters() {
        let url = URL(string: "memori://duel?game=reactionTime&seed=12345")!
        let link = ChallengeLink(url: url)

        XCTAssertNil(link)
    }

    func testParsingInvalidGameType() {
        let url = URL(string: "memori://duel?game=invalidGame&seed=12345&score=288&name=Dylan")!
        let link = ChallengeLink(url: url)

        XCTAssertNil(link)
    }

    // MARK: - Round-trip

    func testRoundTrip() {
        let original = ChallengeLink(game: .mathSpeed, seed: 42000, score: 18905, challengerName: "TestUser")
        let url = original.url!
        let parsed = ChallengeLink(url: url)

        XCTAssertEqual(original, parsed)
    }

    func testRoundTripAllGameTypes() {
        let gameTypes: [ExerciseType] = [
            .reactionTime, .colorMatch, .speedMatch, .visualMemory,
            .sequentialMemory, .mathSpeed, .dualNBack, .chunkingTraining,
            .wordScramble, .memoryChain
        ]

        for gameType in gameTypes {
            let original = ChallengeLink(game: gameType, seed: 11111, score: 500, challengerName: "Test")
            let url = original.url!
            let parsed = ChallengeLink(url: url)

            XCTAssertEqual(original, parsed, "Round-trip failed for \(gameType.rawValue)")
        }
    }

    // MARK: - Random Seed

    func testRandomSeedRange() {
        for _ in 0..<100 {
            let seed = ChallengeLink.randomSeed()
            XCTAssertGreaterThanOrEqual(seed, 10000)
            XCTAssertLessThanOrEqual(seed, 99999)
        }
    }
}
