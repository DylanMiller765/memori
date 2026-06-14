import XCTest
@testable import MindRestore

@MainActor
final class DeepLinkRouterTests: XCTestCase {
    func testHomeRoute() {
        let router = DeepLinkRouter()
        router.handle(URL(string: "memo://home")!)
        XCTAssertEqual(router.pendingDestination, .home)
    }

    func testLegacyMemoriSchemeStillRoutesCoreTabs() {
        let router = DeepLinkRouter()
        router.handle(URL(string: "memori://train")!)
        XCTAssertEqual(router.pendingDestination, .train)
    }

    func testCompeteRoute() {
        let router = DeepLinkRouter()
        router.handle(URL(string: "memo://compete")!)
        XCTAssertEqual(router.pendingDestination, .compete)
    }

    func testGameRoute() {
        let router = DeepLinkRouter()
        router.handle(URL(string: "memo://game/reactionTime")!)
        XCTAssertEqual(router.pendingDestination, .game(.reactionTime))
    }

    func testRemovedChallengeRouteFallsBackHome() {
        let router = DeepLinkRouter()
        router.handle(URL(string: "memo://challenge")!)
        XCTAssertEqual(router.pendingDestination, .home)
    }

    func testRemovedDuelRouteFallsBackHome() {
        let router = DeepLinkRouter()
        router.handle(URL(string: "memori://duel?game=reactionTime&seed=12345&score=288&name=Dylan")!)
        XCTAssertEqual(router.pendingDestination, .home)
    }

    func testRemovedReferralRouteFallsBackHome() {
        let router = DeepLinkRouter()
        router.handle(URL(string: "memo://refer?code=ABC123")!)
        XCTAssertEqual(router.pendingDestination, .home)
    }

    func testWrongSchemeIgnored() {
        let router = DeepLinkRouter()
        router.handle(URL(string: "https://home")!)
        XCTAssertNil(router.pendingDestination)
    }

    func testUnknownHostGoesToHome() {
        let router = DeepLinkRouter()
        router.handle(URL(string: "memo://unknown")!)
        XCTAssertEqual(router.pendingDestination, .home)
    }
}
