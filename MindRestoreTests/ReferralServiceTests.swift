import XCTest
@testable import MindRestore

@MainActor
final class RemovedReferralServiceTests: XCTestCase {
    func testReferralTrialStateIsInactive() {
        UserDefaults.standard.set(Date.now.addingTimeInterval(7 * 24 * 60 * 60), forKey: "referral_trial_expiry")

        let service = ReferralService()

        XCTAssertFalse(service.hasActiveReferralTrial)
        XCTAssertEqual(service.trialDaysRemaining, 0)
    }

    func testReferralDeepLinksNoLongerRoute() {
        let router = DeepLinkRouter()
        router.handle(URL(string: "memo://refer?code=ABC123")!)
        XCTAssertEqual(router.pendingDestination, .home)
    }
}
