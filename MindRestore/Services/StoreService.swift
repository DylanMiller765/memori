import StoreKit
import SwiftUI

@MainActor
@Observable
final class StoreService {
    var isProUser = false
    /// Legacy alias — prefer `isProUser`. Kept temporarily so call sites compile during the
    /// tier-collapse refactor. Both legacy Pro and new Pro (formerly Ultra) subscribers get
    /// full features now.
    var isUltraUser: Bool {
        get { isProUser }
        set { isProUser = newValue }
    }
    var products: [Product] = []
    var purchaseError: String?
    var isLoading = false

    // MARK: Product IDs
    //
    // Two SKU families exist due to the v2.0 single-tier pivot:
    //   • `com.memori.pro.*`   — LEGACY ($3.99 / $19.99). Grandfathered for old subscribers.
    //                            DO NOT use these for new purchases.
    //   • `com.memori.ultra.*` — CANONICAL ($6.99 / $39.99 + 3-day annual trial). All
    //                            new paywalls must charge these. They are kept under the
    //                            "ultra" name in App Store Connect even though Ultra-as-tier
    //                            no longer exists in the app — both families now grant the
    //                            same Pro entitlement (see updateSubscriptionStatus below).
    //
    // Renaming the App Store Connect SKUs would invalidate active subscriptions, so the
    // "ultra" suffix is permanent. Any callsite reading these constants is correct in
    // semantics — only the name is misleading.
    static let weeklyProductID = "com.memori.pro.weekly"
    static let monthlyProductID = "com.memori.pro.monthly"
    static let annualProductID = "com.memori.pro.annual"

    static let weeklyUltraProductID = "com.memori.ultra.weekly"
    static let monthlyUltraProductID = "com.memori.ultra.monthly"
    static let annualUltraProductID = "com.memori.ultra.annual"
    static let annualUltraExitOfferProductID = "com.memori.ultra.annual.firstyear"

    private var updateListenerTask: Task<Void, Error>?

    init() {
        // Ensure install date is persisted on first launch
        if UserDefaults.standard.object(forKey: "installDate") == nil {
            UserDefaults.standard.set(Date.now, forKey: "installDate")
        }
        updateListenerTask = listenForTransactions()
        Task { await loadProducts() }
        Task { await updateSubscriptionStatus() }
    }

    func loadProducts() async {
        isLoading = true
        do {
            products = try await Product.products(for: [
                Self.weeklyProductID,
                Self.monthlyProductID,
                Self.annualProductID,
                Self.weeklyUltraProductID,
                Self.monthlyUltraProductID,
                Self.annualUltraProductID,
                Self.annualUltraExitOfferProductID
            ])
            products.sort { $0.price < $1.price }
        } catch {
            purchaseError = "Failed to load products: \(error.localizedDescription)"
        }
        isLoading = false
    }

    func purchase(_ product: Product) async {
        isLoading = true
        purchaseError = nil

        do {
            let result = try await product.purchase()
            switch result {
            case .success(let verification):
                let transaction = try checkVerified(verification)
                await transaction.finish()
                await updateSubscriptionStatus()
            case .userCancelled:
                break
            case .pending:
                purchaseError = "Purchase is pending approval."
            @unknown default:
                break
            }
        } catch {
            purchaseError = "Purchase failed: \(error.localizedDescription)"
        }
        isLoading = false
    }

    func restorePurchases() async {
        isLoading = true
        try? await AppStore.sync()
        await updateSubscriptionStatus()
        isLoading = false
    }

    func updateSubscriptionStatus() async {
        var hasActiveProEntitlement = false
        var hasActiveUltraEntitlement = false

        for await result in Transaction.currentEntitlements {
            if let transaction = try? checkVerified(result) {
                if transaction.productID == Self.weeklyProductID ||
                   transaction.productID == Self.monthlyProductID ||
                   transaction.productID == Self.annualProductID {
                    hasActiveProEntitlement = true
                } else if transaction.productID == Self.weeklyUltraProductID ||
                          transaction.productID == Self.monthlyUltraProductID ||
                          transaction.productID == Self.annualUltraProductID ||
                          transaction.productID == Self.annualUltraExitOfferProductID {
                    hasActiveUltraEntitlement = true
                }
            }
        }

        // Also check referral trial
        let referralExpiry = UserDefaults.standard.object(forKey: "referral_trial_expiry") as? Date
        let hasReferralTrial = referralExpiry.map { $0 > Date.now } ?? false

        // Single tier: any active sub (legacy Pro OR new Pro/formerly-Ultra) grants full Pro.
        isProUser = hasActiveProEntitlement || hasActiveUltraEntitlement || hasReferralTrial
    }

    private func listenForTransactions() -> Task<Void, Error> {
        Task.detached { [weak self] in
            for await result in Transaction.updates {
                guard let self else { return }
                if let transaction = try? await self.checkVerified(result) {
                    await transaction.finish()
                    await self.updateSubscriptionStatus()
                }
            }
        }
    }

    private func checkVerified<T>(_ result: StoreKit.VerificationResult<T>) throws -> T {
        switch result {
        case .unverified:
            throw StoreServiceError.failedVerification
        case .verified(let item):
            return item
        }
    }

    var weeklyProduct: Product? {
        products.first { $0.id == Self.weeklyProductID }
    }

    var monthlyProduct: Product? {
        products.first { $0.id == Self.monthlyProductID }
    }

    var annualProduct: Product? {
        products.first { $0.id == Self.annualProductID }
    }

    var weeklyUltraProduct: Product? { products.first { $0.id == Self.weeklyUltraProductID } }
    var monthlyUltraProduct: Product? { products.first { $0.id == Self.monthlyUltraProductID } }
    var annualUltraProduct: Product? { products.first { $0.id == Self.annualUltraProductID } }
    var annualUltraExitOfferProduct: Product? { products.first { $0.id == Self.annualUltraExitOfferProductID } }
}

enum StoreServiceError: Error {
    case failedVerification
}
