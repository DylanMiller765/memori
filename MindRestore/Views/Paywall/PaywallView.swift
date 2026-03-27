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
            VStack(spacing: 0) {
                Spacer()

                // Hero
                VStack(spacing: 6) {
                    Text("Unlock Your\nFull Brain Power")
                        .font(.system(size: 26, weight: .bold))
                        .multilineTextAlignment(.center)
                        .opacity(appeared ? 1 : 0)
                        .offset(y: appeared ? 0 : 10)

                    Text("Unlimited training. Real cognitive gains.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .opacity(appeared ? 1 : 0)
                }
                .padding(.bottom, 18)

                // Mascot
                Image("mascot-locked-sad")
                    .renderingMode(.original)
                    .resizable()
                    .scaledToFit()
                    .frame(height: 120)
                    .padding(.bottom, 10)

                // Benefits
                HStack(spacing: 10) {
                    benefitCard(
                        icon: "infinity",
                        title: "Unlimited",
                        subtitle: "Daily Games",
                        color: AppColors.accent
                    )
                    benefitCard(
                        icon: "chart.line.uptrend.xyaxis",
                        title: "Score Trends",
                        subtitle: "& Analytics",
                        color: AppColors.violet
                    )
                }
                .padding(.horizontal, 24)
                .padding(.bottom, 18)

                // Plans
                VStack(spacing: 8) {
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

                    PlanCard(
                        title: "Weekly",
                        price: storeService.weeklyProduct?.displayPrice ?? "$1.99/wk",
                        detail: "Billed weekly",
                        trialText: trialLabel(for: storeService.weeklyProduct),
                        badge: nil,
                        isSelected: selectedPlan == StoreService.weeklyProductID,
                        accentColor: AppColors.violet
                    ) {
                        withAnimation(.easeInOut(duration: 0.2)) {
                            selectedPlan = StoreService.weeklyProductID
                        }
                    }
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 20)

                // CTA + footer
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
                    .padding(.horizontal, 20)

                    if let error = storeService.purchaseError {
                        Text(error)
                            .font(.caption)
                            .foregroundStyle(AppColors.error)
                    }

                    Text(ctaDisclaimerLabel)
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                        .multilineTextAlignment(.center)

                    HStack(spacing: 12) {
                        Button("Restore") {
                            Task { await storeService.restorePurchases() }
                        }
                        Text("·").foregroundStyle(.quaternary)
                        Button("Terms") {
                            if let url = URL(string: "https://memori-website-sooty.vercel.app/terms") {
                                UIApplication.shared.open(url)
                            }
                        }
                        Text("·").foregroundStyle(.quaternary)
                        Button("Privacy") {
                            if let url = URL(string: "https://memori-website-sooty.vercel.app/privacy") {
                                UIApplication.shared.open(url)
                            }
                        }
                    }
                    .font(.caption2.weight(.medium))
                    .foregroundStyle(.tertiary)
                }
                .padding(.bottom, 12)

                Spacer()
            }
            .background(
                paywallBackground
                    .ignoresSafeArea()
            )
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        if hasSeenExitOffer || !isHighIntent || exitOfferShownCount >= maxExitOffers {
                            Analytics.paywallDismissed(trigger: isHighIntent ? "highIntent" : "browse")
                            dismiss()
                        } else {
                            showExitOffer = true
                            hasSeenExitOffer = true
                            exitOfferShownCount += 1
                        }
                    } label: {
                        Image(systemName: "xmark")
                            .font(.system(size: 14, weight: .bold))
                            .foregroundStyle(.tertiary)
                            .padding(8)

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
                    Analytics.paywallDismissed(trigger: "exitOffer")
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

    // MARK: - Background

    @Environment(\.colorScheme) private var colorScheme

    @ViewBuilder
    private var paywallBackground: some View {
        if colorScheme == .dark {
            ZStack {
                Color(red: 0.06, green: 0.04, blue: 0.12)
                LinearGradient(
                    colors: [
                        Color(red: 0.16, green: 0.10, blue: 0.30),
                        Color(red: 0.10, green: 0.06, blue: 0.25),
                        Color(red: 0.06, green: 0.04, blue: 0.14),
                        .clear
                    ],
                    startPoint: .top,
                    endPoint: .bottom
                )
                RadialGradient(
                    colors: [AppColors.violet.opacity(0.15), .clear],
                    center: .init(x: 0.5, y: 0.32),
                    startRadius: 20,
                    endRadius: 200
                )
            }
        } else {
            LinearGradient(
                colors: [
                    AppColors.pageBgLight,
                    AppColors.accent.opacity(0.07),
                    AppColors.accent.opacity(0.22)
                ],
                startPoint: .top,
                endPoint: .bottom
            )
        }
    }

    // MARK: - Benefit Card

    private func benefitCard(icon: String, title: String, subtitle: String, color: Color) -> some View {
        VStack(spacing: 6) {
            Image(systemName: icon)
                .font(.system(size: 22, weight: .semibold))
                .foregroundStyle(color)
                .frame(height: 28)

            Text(title)
                .font(.system(size: 13, weight: .bold))
                .foregroundStyle(.primary)
            Text(subtitle)
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 14)
        .background(color.opacity(0.08), in: RoundedRectangle(cornerRadius: 12))
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(color.opacity(0.15), lineWidth: 1)
        )
    }

    // MARK: - Benefit Row

    private func benefitRow(icon: String, text: String) -> some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(AppColors.accent)
                .frame(width: 20)
            Text(text)
                .font(.subheadline.weight(.medium))
        }
    }

    // MARK: - Helpers

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
        return ""
    }

    private var selectedProduct: Product? {
        switch selectedPlan {
        case StoreService.annualProductID: return storeService.annualProduct
        case StoreService.monthlyProductID: return storeService.monthlyProduct
        case StoreService.weeklyProductID: return storeService.weeklyProduct
        default: return storeService.annualProduct
        }
    }

    private var ctaButtonLabel: String {
        let selectedProduct = self.selectedProduct
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
        let selectedProduct = self.selectedProduct
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
        return "Cancel anytime."
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
                        .frame(width: 22, height: 22)

                    if isSelected {
                        Circle()
                            .fill(accentColor)
                            .frame(width: 14, height: 14)
                    }
                }

                VStack(alignment: .leading, spacing: 3) {
                    HStack(spacing: 8) {
                        Text(title)
                            .font(.subheadline.weight(.bold))

                        if let badge {
                            Text(badge)
                                .font(.system(size: 9, weight: .bold))
                                .textCase(.uppercase)
                                .padding(.horizontal, 7)
                                .padding(.vertical, 2)
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
                        .font(.caption2)
                        .foregroundStyle(.secondary)

                    if !trialText.isEmpty {
                        Text(trialText)
                            .font(.caption2.weight(.medium))
                            .foregroundStyle(AppColors.accent)
                    }
                }

                Spacer()

                Text(price)
                    .font(.subheadline.weight(.bold))
                    .foregroundStyle(isSelected ? accentColor : .primary)
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 12)
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

            Image("mascot-locked-sad")
                .renderingMode(.original)
                .resizable()
                .scaledToFit()
                .frame(height: 140)
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
                    Text("Unlock Pro")
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

// MARK: - Preview

#Preview("Paywall") {
    PaywallView()
        .environment(StoreService())
}
