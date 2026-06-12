import StoreKit
import SwiftUI
import RevenueCat

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
    //   • `com.memori.ultra.*` — CANONICAL weekly + annual plans. All
    //                            new paywalls must charge these. They are kept under the
    //                            "ultra" name in App Store Connect even though Ultra-as-tier
    //                            no longer exists in the app — both families now grant the
    //                            same Pro entitlement (see updateSubscriptionStatus below).
    //
    // Renaming the App Store Connect SKUs would invalidate active subscriptions, so the
    // "ultra" suffix is permanent. Any callsite reading these constants is correct in
    // semantics — only the name is misleading.
    nonisolated static let weeklyProductID = "com.memori.pro.weekly"
    nonisolated static let monthlyProductID = "com.memori.pro.monthly"
    nonisolated static let annualProductID = "com.memori.pro.annual"

    nonisolated static let weeklyUltraProductID = "com.memori.ultra.weekly"
    nonisolated static let monthlyUltraProductID = "com.memori.ultra.monthly"
    nonisolated static let annualUltraProductID = "com.memori.ultra.annual"
    // Founder annual SKU: pay today and renew at the founder price while the subscription
    // remains active. Kept under the existing product ID because the SKU is already approved.
    nonisolated static let annualUltraExitOfferProductID = "com.memori.ultra.annual.firstyear"

    private var updateListenerTask: Task<Void, Error>?
    private var revenueCatCustomerInfoTask: Task<Void, Never>?

    init(loadProductsOnInit: Bool = true) {
        // Ensure install date is persisted on first launch
        if UserDefaults.standard.object(forKey: "installDate") == nil {
            UserDefaults.standard.set(Date.now, forKey: "installDate")
        }
        guard loadProductsOnInit else { return }
        updateListenerTask = listenForTransactions()
        revenueCatCustomerInfoTask = listenForRevenueCatCustomerInfo()
        Task { await loadProducts() }
        Task { await updateSubscriptionStatus() }
    }

    func loadProducts() async {
        isLoading = true
        defer { isLoading = false }

        // One flaky request at launch used to leave the paywall permanently
        // dead ("offer is not ready yet" on every plan). Retry with backoff;
        // only surface an error if all attempts come back empty.
        let requestIDs: Set<String> = [
            Self.weeklyProductID,
            Self.annualProductID,
            Self.weeklyUltraProductID,
            Self.monthlyUltraProductID,
            Self.annualUltraProductID,
            Self.annualUltraExitOfferProductID
        ]

        var lastError: Error?
        for attempt in 0..<3 {
            if attempt > 0 {
                try? await Task.sleep(nanoseconds: UInt64(attempt) * 1_200_000_000)
            }
            do {
                let loaded = try await Product.products(for: requestIDs)
                if !loaded.isEmpty {
                    products = loaded.sorted { $0.price < $1.price }
                    return
                }
            } catch {
                lastError = error
            }
        }

        if products.isEmpty {
            purchaseError = lastError != nil
                ? "Can't reach the App Store. Check your connection and try again."
                : "Plans are still loading. Try again in a moment."
        }
    }

    @discardableResult
    func purchase(_ product: Product) async -> StorePurchaseOutcome {
        isLoading = true
        purchaseError = nil
        defer { isLoading = false }

        do {
            let result = try await product.purchase()
            switch result {
            case .success(let verification):
                let transaction = try checkVerified(verification)
                await recordRevenueCatPurchase(result, productID: transaction.productID)
                await transaction.finish()
                await updateSubscriptionStatus(source: "storekit_purchase_success")
                return .success(productID: transaction.productID)
            case .userCancelled:
                return .userCancelled
            case .pending:
                purchaseError = "Purchase is pending approval."
                return .pending
            @unknown default:
                return .failed(reason: "Unknown purchase result.")
            }
        } catch {
            let reason = error.localizedDescription
            purchaseError = "Purchase failed: \(reason)"
            return .failed(reason: reason)
        }
    }

    @discardableResult
    func restorePurchases() async -> Bool {
        isLoading = true
        defer { isLoading = false }
        do {
            try await AppStore.sync()
        } catch {
            purchaseError = "Restore failed: \(error.localizedDescription)"
        }
        await updateSubscriptionStatus(source: "storekit_restore")
        return isProUser
    }

    func updateSubscriptionStatus(source: String = "storekit_current_entitlements") async {
        var hasActiveProEntitlement = false
        var hasActiveUltraEntitlement = false
        var activeProductIDs: [String] = []
        let previousStatus = isProUser

        for await result in Transaction.currentEntitlements {
            if let transaction = try? checkVerified(result) {
                if transaction.productID == Self.weeklyProductID ||
                   transaction.productID == Self.monthlyProductID ||
                   transaction.productID == Self.annualProductID {
                    hasActiveProEntitlement = true
                    activeProductIDs.append(transaction.productID)
                } else if transaction.productID == Self.weeklyUltraProductID ||
                          transaction.productID == Self.monthlyUltraProductID ||
                          transaction.productID == Self.annualUltraProductID ||
                          transaction.productID == Self.annualUltraExitOfferProductID {
                    hasActiveUltraEntitlement = true
                    activeProductIDs.append(transaction.productID)
                }
            }
        }

        // Single tier: any active sub (legacy Pro OR new Pro/formerly-Ultra) grants full Pro.
        isProUser = hasActiveProEntitlement || hasActiveUltraEntitlement
        Analytics.subscriptionStatusSynced(
            source: source,
            isMember: isProUser,
            activeProductIDs: activeProductIDs.sorted(),
            didChange: previousStatus != isProUser
        )
    }

    private func listenForTransactions() -> Task<Void, Error> {
        Task.detached { [weak self] in
            for await result in Transaction.updates {
                guard let self else { return }
                if let transaction = try? await self.checkVerified(result) {
                    await transaction.finish()
                    await self.updateSubscriptionStatus(source: "storekit_transaction_update")
                }
            }
        }
    }

    private func listenForRevenueCatCustomerInfo() -> Task<Void, Never> {
        Task { [weak self] in
            for await customerInfo in Purchases.shared.customerInfoStream {
                guard let self else { return }
                let activeSubscriptions = Array(customerInfo.activeSubscriptions).sorted()
                let previousStatus = isProUser
                if !activeSubscriptions.isEmpty {
                    isProUser = true
                }
                Analytics.subscriptionStatusSynced(
                    source: "revenuecat_customer_info_stream",
                    isMember: isProUser,
                    activeProductIDs: activeSubscriptions,
                    didChange: previousStatus != isProUser
                )
            }
        }
    }

    private func recordRevenueCatPurchase(_ result: Product.PurchaseResult, productID: String) async {
        do {
            _ = try await Purchases.shared.recordPurchase(result)
            Analytics.revenueCatPurchaseRecorded(productID: productID)
        } catch {
            Analytics.revenueCatPurchaseRecordFailed(productID: productID, reason: error.localizedDescription)
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

enum StorePurchaseOutcome: Equatable {
    case success(productID: String)
    case userCancelled
    case pending
    case failed(reason: String)
}
