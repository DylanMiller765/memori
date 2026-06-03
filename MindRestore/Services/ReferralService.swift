import Foundation
import SwiftData

@MainActor
@Observable
final class ReferralService {
    var hasActiveReferralTrial: Bool { false }
    var trialDaysRemaining: Int { 0 }
    var referralCount: Int { 0 }

    func getReferralCode(modelContext: ModelContext) -> String? { nil }
    func getReferralURL(modelContext: ModelContext) -> URL? { nil }
    func getReferralDeepLink(modelContext: ModelContext) -> URL? { nil }
    func grantReferralTrial() {}
    func recordReferrer(code: String) {}
    var wasReferred: Bool { false }
    func incrementReferralCount() {}
    func notifyReferrer(referrerCode: String) {}
    func checkForPendingRewards(myCode: String) {}
    func shareReferralLink(modelContext: ModelContext) {}
}
