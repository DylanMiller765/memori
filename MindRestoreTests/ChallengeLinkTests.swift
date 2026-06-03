import XCTest
@testable import MindRestore

@MainActor
final class RemovedSocialLinkTests: XCTestCase {
    func testOldDuelLinksDoNotParseIntoProductState() {
        let router = DeepLinkRouter()
        router.handle(URL(string: "memori://duel?game=reactionTime&seed=12345&score=288&name=Dylan")!)
        XCTAssertEqual(router.pendingDestination, .home)
    }
}
