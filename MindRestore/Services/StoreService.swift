import StoreKit
import SwiftUI

@MainActor
@Observable
final class StoreService {
    var isProUser = false
    var isUltraUser = false
    var products: [Product] = []
    var purchaseError: String?
    var isLoading = false

    static let weeklyProductID = "com.memori.pro.weekly"
    static let monthlyProductID = "com.memori.pro.monthly"
    static let annualProductID = "com.memori.pro.annual"

    static let weeklyUltraProductID = "com.memori.ultra.weekly"
    static let monthlyUltraProductID = "com.memori.ultra.monthly"
    static let annualUltraProductID = "com.memori.ultra.annual"

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
                Self.annualUltraProductID
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
                          transaction.productID == Self.annualUltraProductID {
                    hasActiveUltraEntitlement = true
                }
            }
        }

        // Also check referral trial
        let referralExpiry = UserDefaults.standard.object(forKey: "referral_trial_expiry") as? Date
        let hasReferralTrial = referralExpiry.map { $0 > Date.now } ?? false

        isUltraUser = hasActiveUltraEntitlement
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
}

enum StoreServiceError: Error {
    case failedVerification
}
