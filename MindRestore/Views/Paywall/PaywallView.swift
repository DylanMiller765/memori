import SwiftUI
import StoreKit

struct PaywallView: View {
    /// Only show the exit offer on high-intent triggers (daily limit, post-assessment)
    var isHighIntent: Bool = false

    @Environment(\.dismiss) private var dismiss
    @Environment(StoreService.self) private var storeService

    @State private var selectedPlan: String = StoreService.annualProductID
    @State private var showExitOffer = false
    @State private var hasSeenExitOffer = false
    @State private var appeared = false
    @AppStorage("exitOfferShownCount") private var exitOfferShownCount: Int = 0
    private let maxExitOffers = 3

    var body: some View {
        NavigationStack {
            ZStack(alignment: .bottom) {
                ScrollView(.vertical) {
                    VStack(spacing: 0) {
                        heroSection
                        benefitsStrip
                            .padding(.top, 24)
                        plansSection
                            .padding(.top, 28)
                        guaranteeRow
                            .padding(.top, 20)
                        footerSection
                            .padding(.top, 16)
                    }
                    .padding(.bottom, 120)
                }
                .pageBackground()

                // Sticky CTA at bottom
                stickyPurchaseButton
            }
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        if hasSeenExitOffer || !isHighIntent || exitOfferShownCount >= maxExitOffers {
                            dismiss()
                        } else {
                            showExitOffer = true
                            hasSeenExitOffer = true
                            exitOfferShownCount += 1
                        }
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .font(.title2)
                            .symbolRenderingMode(.hierarchical)
                            .foregroundStyle(.secondary)
                    }
                    .accessibilityLabel("Close")
                }
            }
            .sheet(isPresented: $showExitOffer) {
                ExitOfferSheet {
                    showExitOffer = false
                    Task { await purchase() }
                } onDismiss: {
                    showExitOffer = false
                    dismiss()
                }
                .presentationDetents([.medium])
                .presentationDragIndicator(.visible)
            }
        }
        .onAppear {
            withAnimation(.easeOut(duration: 0.6)) { appeared = true }
            Analytics.paywallShown()
        }
    }

    // MARK: - Hero

    private var heroSection: some View {
        VStack(spacing: 20) {
            VStack(spacing: 16) {
                ZStack {
                    Circle()
                        .fill(AppColors.cardBorder)
                        .frame(width: 100, height: 100)
                        .scaleEffect(appeared ? 1 : 0.6)

                    Image(systemName: "brain.head.profile")
                        .font(.system(size: 44, weight: .medium))
                        .foregroundStyle(AppColors.accent)
                        .symbolEffect(.pulse, isActive: true)
                }

                VStack(spacing: 6) {
                    Text("Unlock Your\nFull Brain Power")
                        .font(.system(size: 28, weight: .bold))
                        .multilineTextAlignment(.center)
                        .opacity(appeared ? 1 : 0)
                        .offset(y: appeared ? 0 : 10)

                    Text("Unlimited training. Real cognitive gains.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .opacity(appeared ? 1 : 0)
                }
            }
            .padding(.top, 16)
        }
    }

    // MARK: - Benefits Strip

    private var benefitsStrip: some View {
        VStack(spacing: 16) {
            // Free vs Pro comparison
            VStack(spacing: 0) {
                // Header row
                HStack(spacing: 0) {
                    Text("")
                        .frame(maxWidth: .infinity, alignment: .leading)
                    Text("Free")
                        .font(.system(size: 13, weight: .bold))
                        .foregroundStyle(.secondary)
                        .frame(width: 56)
                    Text("Pro")
                        .font(.system(size: 13, weight: .bold))
                        .foregroundStyle(AppColors.accent)
                        .frame(width: 56)
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 10)

                Divider()

                comparisonRow("Daily games", free: "3/day", pro: true)
                Divider().padding(.leading, 16)
                comparisonRow("All 8 exercises", free: nil, pro: true)
                Divider().padding(.leading, 16)
                comparisonRow("Personal records", free: nil, pro: true)
                Divider().padding(.leading, 16)
                comparisonRow("Score trends & analytics", free: nil, pro: true, freeHas: false)
                Divider().padding(.leading, 16)
                comparisonRow("Performance sparklines", free: nil, pro: true, freeHas: false)
                Divider().padding(.leading, 16)
                comparisonRow("Leaderboards", free: nil, pro: true)
            }
            .background(
                RoundedRectangle(cornerRadius: 14)
                    .fill(AppColors.cardSurface)
                    .shadow(color: .black.opacity(0.06), radius: 8, y: 2)
            )
        }
        .padding(.horizontal, 20)
    }

    private func comparisonRow(_ feature: String, free: String? = nil, pro: Bool, freeHas: Bool = true) -> some View {
        HStack(spacing: 0) {
            Text(feature)
                .font(.subheadline)
                .frame(maxWidth: .infinity, alignment: .leading)

            Group {
                if let free {
                    Text(free)
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(.secondary)
                } else if freeHas {
                    Image(systemName: "checkmark")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundStyle(.secondary.opacity(0.5))
                } else {
                    Image(systemName: "xmark")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundStyle(.secondary.opacity(0.3))
                }
            }
            .frame(width: 56)

            Group {
                if pro {
                    Image(systemName: "checkmark")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundStyle(AppColors.accent)
                }
            }
            .frame(width: 56)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 11)
    }

    // MARK: - Plans

    private var plansSection: some View {
        VStack(spacing: 10) {
            PlanCard(
                title: "Annual",
                price: storeService.annualProduct?.displayPrice ?? "$19.99/yr",
                detail: annualPerMonthDetail,
                trialText: trialLabel(for: storeService.annualProduct),
                badge: "Best Value",
                isSelected: selectedPlan == StoreService.annualProductID,
                accentColor: AppColors.violet
            ) {
                withAnimation(.easeInOut(duration: 0.2)) {
                    selectedPlan = StoreService.annualProductID
                }
            }

            PlanCard(
                title: "Monthly",
                price: storeService.monthlyProduct?.displayPrice ?? "$3.99/mo",
                detail: "Billed monthly",
                trialText: trialLabel(for: storeService.monthlyProduct),
                badge: nil,
                isSelected: selectedPlan == StoreService.monthlyProductID,
                accentColor: AppColors.violet
            ) {
                withAnimation(.easeInOut(duration: 0.2)) {
                    selectedPlan = StoreService.monthlyProductID
                }
            }
        }
        .padding(.horizontal, 20)
    }

    private var annualPerMonthDetail: String {
        if let annualProduct = storeService.annualProduct,
           let monthlyProduct = storeService.monthlyProduct {
            let monthlyFromAnnual = annualProduct.price / 12
            let formatted = monthlyFromAnnual.formatted(.currency(code: annualProduct.priceFormatStyle.currencyCode ?? "USD"))
            let diff = NSDecimalNumber(decimal: monthlyProduct.price - monthlyFromAnnual)
            let total = NSDecimalNumber(decimal: monthlyProduct.price)
            let savings = Int((diff.doubleValue / total.doubleValue * 100).rounded())
            return "Just \(formatted)/month — Save \(savings)%"
        }
        return "Just $1.67/month — Save 58%"
    }

    // MARK: - Sticky Purchase Button

    private var stickyPurchaseButton: some View {
        VStack(spacing: 8) {
            Button {
                Task { await purchase() }
            } label: {
                Group {
                    if storeService.isLoading {
                        ProgressView()
                            .tint(.white)
                    } else {
                        HStack(spacing: 8) {
                            Image(systemName: "lock.open.fill")
                                .font(.subheadline.weight(.semibold))
                            Text(ctaButtonLabel)
                                .font(.headline.weight(.bold))
                        }
                    }
                }
                .gradientButton(AppColors.premiumGradient)
            }
            .disabled(storeService.isLoading)
            .accessibilityHint("Subscribe to the selected plan")
            .padding(.horizontal, 20)

            Text(ctaDisclaimerLabel)
                .font(.caption2)
                .foregroundStyle(.tertiary)
                .multilineTextAlignment(.center)

            if let error = storeService.purchaseError {
                Text(error)
                    .font(.caption)
                    .foregroundStyle(AppColors.error)
            }
        }
        .padding(.top, 12)
        .padding(.bottom, 16)
        .background(
            Rectangle()
                .fill(AppColors.cardSurface)
                .ignoresSafeArea(edges: .bottom)
        )
    }

    // MARK: - Guarantee

    private var guaranteeRow: some View {
        HStack(spacing: 10) {
            Image(systemName: "shield.checkered")
                .font(.body)
                .foregroundStyle(AppColors.accent)

            Text("Cancel anytime.")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding(.horizontal, 24)
    }

    // MARK: - Footer

    private var footerSection: some View {
        VStack(spacing: 8) {
            Button("Restore Purchases") {
                Task { await storeService.restorePurchases() }
            }
            .font(.caption.weight(.medium))
            .foregroundStyle(.secondary)

            HStack(spacing: 16) {
                Button("Terms of Use") {
                    if let url = URL(string: "https://memori-website-sooty.vercel.app/terms") {
                        UIApplication.shared.open(url)
                    }
                }
                .font(.caption2)
                .foregroundStyle(.tertiary)

                Text("|")
                    .font(.caption2)
                    .foregroundStyle(.quaternary)

                Button("Privacy Policy") {
                    if let url = URL(string: "https://memori-website-sooty.vercel.app/privacy") {
                        UIApplication.shared.open(url)
                    }
                }
                .font(.caption2)
                .foregroundStyle(.tertiary)
            }
        }
        .padding(.horizontal, 24)
    }

    // MARK: - Actions

    private func purchase() async {
        let productID = selectedPlan
        if let product = storeService.products.first(where: { $0.id == productID }) {
            await storeService.purchase(product)
            if storeService.isProUser {
                Analytics.paywallConverted(plan: productID)
                UINotificationFeedbackGenerator().notificationOccurred(.success)
                SoundService.shared.playComplete()
                dismiss()
            }
        } else {
            await storeService.loadProducts()
            if let product = storeService.products.first(where: { $0.id == productID }) {
                await storeService.purchase(product)
                if storeService.isProUser {
                    Analytics.paywallConverted(plan: productID)
                    UINotificationFeedbackGenerator().notificationOccurred(.success)
                    SoundService.shared.playComplete()
                    dismiss()
                }
            }
        }
    }

    private func trialLabel(for product: Product?) -> String {
        if let product,
           let sub = product.subscription,
           let intro = sub.introductoryOffer,
           intro.paymentMode == .freeTrial {
            let value = intro.period.value
            let unit: String
            switch intro.period.unit {
            case .day:   unit = value == 1 ? "day" : "days"
            case .week:  unit = value == 1 ? "week" : "weeks"
            case .month: unit = value == 1 ? "month" : "months"
            case .year:  unit = value == 1 ? "year" : "years"
            @unknown default: unit = "days"
            }
            return "\(value)-\(unit) free trial"
        }
        return "Start Pro"
    }

    private var ctaButtonLabel: String {
        let selectedProduct = selectedPlan == StoreService.annualProductID
            ? storeService.annualProduct
            : storeService.monthlyProduct
        if let product = selectedProduct,
           let sub = product.subscription,
           let intro = sub.introductoryOffer,
           intro.paymentMode == .freeTrial {
            let value = intro.period.value
            let unit: String
            switch intro.period.unit {
            case .day:   unit = value == 1 ? "Day" : "Day"
            case .week:  unit = value == 1 ? "Week" : "Week"
            case .month: unit = value == 1 ? "Month" : "Month"
            case .year:  unit = value == 1 ? "Year" : "Year"
            @unknown default: unit = "Day"
            }
            return "Start \(value)-\(unit) Free Trial"
        }
        return "Subscribe Now"
    }

    private var ctaDisclaimerLabel: String {
        let selectedProduct = selectedPlan == StoreService.annualProductID
            ? storeService.annualProduct
            : storeService.monthlyProduct
        if let product = selectedProduct,
           let sub = product.subscription,
           let intro = sub.introductoryOffer,
           intro.paymentMode == .freeTrial {
            let value = intro.period.value
            let unit: String
            switch intro.period.unit {
            case .day:   unit = value == 1 ? "day" : "days"
            case .week:  unit = value == 1 ? "week" : "weeks"
            case .month: unit = value == 1 ? "month" : "months"
            case .year:  unit = value == 1 ? "year" : "years"
            @unknown default: unit = "days"
            }
            return "No charge for \(value) \(unit). Cancel anytime."
        }
        return "Cancel anytime. Manage subscription in Settings."
    }
}

// MARK: - Plan Card

struct PlanCard: View {
    let title: String
    let price: String
    let detail: String
    var trialText: String = ""
    let badge: String?
    let isSelected: Bool
    var accentColor: Color = AppColors.violet
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 14) {
                ZStack {
                    Circle()
                        .stroke(isSelected ? accentColor : Color.gray.opacity(0.3), lineWidth: 2)
                        .frame(width: 24, height: 24)

                    if isSelected {
                        Circle()
                            .fill(accentColor)
                            .frame(width: 16, height: 16)
                    }
                }

                VStack(alignment: .leading, spacing: 4) {
                    HStack(spacing: 8) {
                        Text(title)
                            .font(.headline.weight(.bold))

                        if let badge {
                            Text(badge)
                                .font(.caption2.weight(.bold))
                                .textCase(.uppercase)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 3)
                                .background(
                                    LinearGradient(
                                        colors: [AppColors.violet, AppColors.indigo],
                                        startPoint: .leading,
                                        endPoint: .trailing
                                    ),
                                    in: Capsule()
                                )
                                .foregroundStyle(.white)
                        }
                    }

                    Text(detail)
                        .font(.caption)
                        .foregroundStyle(.secondary)

                    if !trialText.isEmpty {
                        Text(trialText)
                            .font(.caption2.weight(.medium))
                            .foregroundStyle(AppColors.accent)
                    }
                }

                Spacer()

                Text(price)
                    .font(.headline.weight(.bold))
                    .foregroundStyle(isSelected ? accentColor : .primary)
            }
            .padding(16)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(AppColors.cardElevated)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(
                        isSelected ? accentColor.opacity(0.6) : Color.clear,
                        lineWidth: 2
                    )
            )
        }
        .buttonStyle(.plain)
        .accessibilityLabel("\(title) plan, \(price)\(isSelected ? ", selected" : "")")
    }
}

// MARK: - Exit Offer Sheet

struct ExitOfferSheet: View {
    let onSubscribe: () -> Void
    let onDismiss: () -> Void

    @State private var appeared = false

    var body: some View {
        VStack(spacing: 24) {
            Spacer()

            ZStack {
                Circle()
                    .fill(AppColors.cardBorder)
                    .frame(width: 100, height: 100)
                Image(systemName: "brain.head.profile")
                    .font(.system(size: 44))
                    .foregroundStyle(AppColors.accent)
            }
            .scaleEffect(appeared ? 1 : 0.5)
            .opacity(appeared ? 1 : 0)

            VStack(spacing: 8) {
                Text("Don't lose your\nmomentum!")
                    .font(.title2.weight(.bold))
                    .multilineTextAlignment(.center)

                Text("Pro members train unlimited — no daily\nlimits holding you back.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }
            .opacity(appeared ? 1 : 0)
            .offset(y: appeared ? 0 : 10)

            VStack(spacing: 12) {
                Button(action: onSubscribe) {
                    Text("Start Free Trial")
                        .gradientButton()
                }

                Button(action: onDismiss) {
                    Text("No thanks")
                        .font(.subheadline.weight(.medium))
                        .foregroundStyle(.secondary)
                }
            }
            .padding(.horizontal, 32)
            .opacity(appeared ? 1 : 0)
            .offset(y: appeared ? 0 : 20)

            Spacer()
        }
        .onAppear {
            withAnimation(.spring(response: 0.6, dampingFraction: 0.8)) {
                appeared = true
            }
        }
    }
}
