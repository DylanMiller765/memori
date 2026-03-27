import XCTest
@testable import MindRestore

@MainActor
final class DeepLinkRouterTests: XCTestCase {

    // MARK: - Existing Routes

    func testHomeRoute() {
        let router = DeepLinkRouter()
        router.handle(URL(string: "memori://home")!)
        XCTAssertEqual(router.pendingDestination, .home)
    }

    func testTrainRoute() {
        let router = DeepLinkRouter()
        router.handle(URL(string: "memori://train")!)
        XCTAssertEqual(router.pendingDestination, .train)
    }

    func testCompeteRoute() {
        let router = DeepLinkRouter()
        router.handle(URL(string: "memori://compete")!)
        XCTAssertEqual(router.pendingDestination, .compete)
    }

    func testGameRoute() {
        let router = DeepLinkRouter()
        router.handle(URL(string: "memori://game/reactionTime")!)
        XCTAssertEqual(router.pendingDestination, .game(.reactionTime))
    }

    func testDailyChallengeRoute() {
        let router = DeepLinkRouter()
        router.handle(URL(string: "memori://challenge")!)
        XCTAssertEqual(router.pendingDestination, .dailyChallenge)
    }

    // MARK: - Challenge/Duel Routes

    func testDuelRouteParsesChallengeLink() {
        let router = DeepLinkRouter()
        router.handle(URL(string: "memori://duel?game=reactionTime&seed=12345&score=288&name=Dylan")!)

        XCTAssertNotNil(router.pendingChallenge)
        XCTAssertEqual(router.pendingChallenge?.game, .reactionTime)
        XCTAssertEqual(router.pendingChallenge?.seed, 12345)
        XCTAssertEqual(router.pendingChallenge?.score, 288)
        XCTAssertEqual(router.pendingChallenge?.challengerName, "Dylan")

        if case .challenge(let link) = router.pendingDestination {
            XCTAssertEqual(link.game, .reactionTime)
        } else {
            XCTFail("Expected .challenge destination")
        }
    }

    func testDuelRouteWithInvalidParamsFallsBackToTrain() {
        let router = DeepLinkRouter()
        router.handle(URL(string: "memori://duel?game=invalidGame")!)

        XCTAssertNil(router.pendingChallenge)
        XCTAssertEqual(router.pendingDestination, .train)
    }

    func testDuelRouteWithMissingParamsFallsBackToTrain() {
        let router = DeepLinkRouter()
        router.handle(URL(string: "memori://duel")!)

        XCTAssertNil(router.pendingChallenge)
        XCTAssertEqual(router.pendingDestination, .train)
    }

    // MARK: - Invalid URLs

    func testWrongSchemeIgnored() {
        let router = DeepLinkRouter()
        router.handle(URL(string: "https://home")!)
        XCTAssertNil(router.pendingDestination)
    }

    func testUnknownHostGoesToHome() {
        let router = DeepLinkRouter()
        router.handle(URL(string: "memori://unknown")!)
        XCTAssertEqual(router.pendingDestination, .home)
    }
}
