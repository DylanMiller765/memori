import SwiftUI
import StoreKit

enum SubscriptionTier {
    case pro, ultra
}

struct PaywallView: View {
    var isHighIntent: Bool = false
    var currentStreak: Int = 0
    var todayScoreGain: Int = 0
    var isPersonalBest: Bool = false
    var gamesPlayedToday: Int = 0
    var triggerSource: String = "unknown"

    @Environment(\.dismiss) private var dismiss
    @Environment(StoreService.self) private var storeService
    @Environment(\.colorScheme) private var colorScheme

    @State private var selectedTier: SubscriptionTier = .ultra
    @State private var selectedPlan: String = StoreService.annualUltraProductID
    @State private var showExitOffer = false
    @State private var hasSeenExitOffer = false
    @State private var appeared = false
    @AppStorage("exitOfferShownCount") private var exitOfferShownCount: Int = 0
    private let maxExitOffers = 3

    private var selectedAccentColor: Color {
        selectedTier == .ultra ? AppColors.violet : AppColors.accent
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Hero — compact
                VStack(spacing: 10) {
                    Image("mascot-cool")
                        .renderingMode(.original)
                        .resizable()
                        .scaledToFit()
                        .frame(height: 70)
                        .opacity(appeared ? 1 : 0)
                        .scaleEffect(appeared ? 1 : 0.8)

                    Text(heroHeadline)
                        .font(.system(size: 24, weight: .bold))
                        .multilineTextAlignment(.center)
                        .opacity(appeared ? 1 : 0)

                    Text(heroSubtitle)
                        .font(.system(size: 13))
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 32)
                        .opacity(appeared ? 1 : 0)
                }
                .padding(.top, 4)
                .padding(.bottom, 14)

                // Tier Toggle — glass pill
                tierToggle
                    .padding(.horizontal, 40)
                    .padding(.bottom, 14)

                // Benefits
                benefitsList
                    .padding(.horizontal, 24)
                    .padding(.bottom, 14)

                Spacer()

                // Plans
                planCards
                    .padding(.horizontal, 20)
                    .padding(.bottom, 12)

                // CTA
                ctaSection
                    .padding(.horizontal, 20)
                    .padding(.bottom, 8)
            }
            .background(paywallBackground.ignoresSafeArea())
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
                            .font(.system(size: 13, weight: .bold))
                            .foregroundStyle(.secondary)
                            .frame(width: 34, height: 34)
                            .background(Circle().fill(.ultraThinMaterial))
                    }
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
            Analytics.paywallShown(trigger: triggerSource)
        }
    }

    // MARK: - Tier Toggle

    private var tierToggle: some View {
        HStack(spacing: 3) {
            tierPill("Pro", isSelected: selectedTier == .pro) {
                withAnimation(.spring(response: 0.25, dampingFraction: 0.8)) {
                    selectedTier = .pro
                    selectedPlan = StoreService.annualProductID
                }
            }

            tierPill("Ultra", isSelected: selectedTier == .ultra) {
                withAnimation(.spring(response: 0.25, dampingFraction: 0.8)) {
                    selectedTier = .ultra
                    selectedPlan = StoreService.annualUltraProductID
                }
            }
        }
        .padding(3)
        .background(.ultraThinMaterial, in: Capsule())
        .overlay(Capsule().stroke(Color.white.opacity(0.1), lineWidth: 1))
    }

    private func tierPill(_ title: String, isSelected: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(title)
                .font(.system(size: 13, weight: .bold))
                .foregroundStyle(isSelected ? .white : .secondary)
                .padding(.horizontal, 24)
                .padding(.vertical, 8)
                .background(
                    isSelected
                        ? AnyShapeStyle(
                            selectedTier == .ultra && title == "Ultra"
                                ? LinearGradient(colors: [AppColors.violet, AppColors.indigo], startPoint: .leading, endPoint: .trailing)
                                : AppColors.accentGradient
                        )
                        : AnyShapeStyle(Color.clear),
                    in: Capsule()
                )
        }
        .buttonStyle(.plain)
        .contentShape(Capsule())
    }

    // MARK: - Benefits

    private var benefitsList: some View {
        VStack(spacing: 0) {
            if selectedTier == .pro {
                benefitRow(icon: "infinity", text: "Unlimited daily games", color: AppColors.accent)
                benefitRow(icon: "chart.line.uptrend.xyaxis", text: "Full progress insights", color: AppColors.teal)
                benefitRow(icon: "trophy.fill", text: "Compete on leaderboards", color: AppColors.amber)
                benefitRow(icon: "brain.head.profile", text: "Track your Brain Age", color: AppColors.violet, isLast: true)
            } else {
                benefitRow(icon: "infinity", text: "Everything in Pro", color: AppColors.accent)
                benefitRow(icon: "shield.fill", text: "Block distracting apps", color: AppColors.violet)
                benefitRow(icon: "gamecontroller.fill", text: "Play to earn screen time", color: AppColors.coral)
                benefitRow(icon: "chart.bar.fill", text: "Screen time insights", color: AppColors.teal, isLast: true)
            }
        }
    }

    private func benefitRow(icon: String, text: String, color: Color, isLast: Bool = false) -> some View {
        VStack(spacing: 0) {
            HStack(spacing: 14) {
                Image(systemName: icon)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(color)
                    .frame(width: 32, height: 32)
                    .background(color.opacity(0.12), in: RoundedRectangle(cornerRadius: 8))

                Text(text)
                    .font(.system(size: 15, weight: .medium))

                Spacer()

                Image(systemName: "checkmark")
                    .font(.system(size: 12, weight: .bold))
                    .foregroundStyle(selectedAccentColor)
            }
            .padding(.vertical, 12)

            if !isLast {
                Divider().opacity(0.3)
            }
        }
    }

    // MARK: - Plan Cards

    private var planCards: some View {
        VStack(spacing: 6) {
            if selectedTier == .pro {
                planRow(
                    title: "Annual",
                    price: storeService.annualProduct?.displayPrice ?? "$19.99/yr",
                    detail: annualPerMonthDetail,
                    trial: trialLabel(for: storeService.annualProduct),
                    badge: "SAVE \(annualSavingsPercent)%",
                    id: StoreService.annualProductID
                )
                planRow(
                    title: "Monthly",
                    price: storeService.monthlyProduct?.displayPrice ?? "$3.99/mo",
                    detail: "Billed monthly",
                    trial: trialLabel(for: storeService.monthlyProduct),
                    badge: nil,
                    id: StoreService.monthlyProductID
                )
                planRow(
                    title: "Weekly",
                    price: storeService.weeklyProduct?.displayPrice ?? "$1.99/wk",
                    detail: "Billed weekly",
                    trial: trialLabel(for: storeService.weeklyProduct),
                    badge: nil,
                    id: StoreService.weeklyProductID
                )
            } else {
                planRow(
                    title: "Annual",
                    price: storeService.annualUltraProduct?.displayPrice ?? "$39.99/yr",
                    detail: ultraAnnualPerMonthDetail,
                    trial: trialLabel(for: storeService.annualUltraProduct),
                    badge: "SAVE \(ultraAnnualSavingsPercent)%",
                    id: StoreService.annualUltraProductID
                )
                planRow(
                    title: "Monthly",
                    price: storeService.monthlyUltraProduct?.displayPrice ?? "$6.99/mo",
                    detail: "Billed monthly",
                    trial: trialLabel(for: storeService.monthlyUltraProduct),
                    badge: nil,
                    id: StoreService.monthlyUltraProductID
                )
                planRow(
                    title: "Weekly",
                    price: storeService.weeklyUltraProduct?.displayPrice ?? "$3.99/wk",
                    detail: "Billed weekly",
                    trial: trialLabel(for: storeService.weeklyUltraProduct),
                    badge: nil,
                    id: StoreService.weeklyUltraProductID
                )
            }
        }
    }

    private func planRow(title: String, price: String, detail: String, trial: String, badge: String?, id: String) -> some View {
        let isSelected = selectedPlan == id
        return Button {
            withAnimation(.easeInOut(duration: 0.2)) { selectedPlan = id }
        } label: {
            HStack(spacing: 12) {
                // Radio
                ZStack {
                    Circle()
                        .stroke(isSelected ? selectedAccentColor : Color.white.opacity(0.2), lineWidth: 2)
                        .frame(width: 22, height: 22)
                    if isSelected {
                        Circle()
                            .fill(selectedAccentColor)
                            .frame(width: 14, height: 14)
                    }
                }

                VStack(alignment: .leading, spacing: 3) {
                    HStack(spacing: 8) {
                        Text(title)
                            .font(.system(size: 16, weight: .bold))

                        if let badge {
                            Text(badge)
                                .font(.system(size: 9, weight: .black))
                                .foregroundStyle(.white)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 3)
                                .background(selectedAccentColor, in: Capsule())
                        }
                    }

                    Text(detail)
                        .font(.caption)
                        .foregroundStyle(.secondary)

                    if !trial.isEmpty {
                        Text(trial)
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(AppColors.mint)
                    }
                }

                Spacer()

                Text(price)
                    .font(.system(size: 16, weight: .bold))
                    .foregroundStyle(isSelected ? selectedAccentColor : .primary)
            }
            .padding(14)
            .background(
                RoundedRectangle(cornerRadius: 14)
                    .fill(Color.white.opacity(isSelected ? 0.06 : 0.03))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 14)
                    .stroke(isSelected ? selectedAccentColor : Color.white.opacity(0.08), lineWidth: isSelected ? 2 : 1)
            )
        }
        .buttonStyle(.plain)
    }

    // MARK: - CTA

    private var ctaSection: some View {
        VStack(spacing: 10) {
            Button {
                Task { await purchase() }
            } label: {
                Group {
                    if storeService.isLoading {
                        ProgressView().tint(.white)
                    } else {
                        Text(ctaButtonLabel)
                            .font(.headline.weight(.bold))
                    }
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 16)
                .background(
                    selectedTier == .ultra
                        ? LinearGradient(colors: [AppColors.violet, AppColors.indigo], startPoint: .leading, endPoint: .trailing)
                        : AppColors.accentGradient,
                    in: RoundedRectangle(cornerRadius: 14)
                )
                .foregroundStyle(.white)
            }
            .disabled(storeService.isLoading)

            if let error = storeService.purchaseError {
                Text(error)
                    .font(.caption)
                    .foregroundStyle(AppColors.error)
            }

            Text(ctaDisclaimerLabel)
                .font(.caption)
                .foregroundStyle(.tertiary)

            HStack(spacing: 12) {
                Button("Restore") {
                    Task { await storeService.restorePurchases() }
                }
                Text("·").foregroundStyle(.quaternary)
                Button("Terms") {
                    if let url = URL(string: "https://getmemoriapp.com/terms") {
                        UIApplication.shared.open(url)
                    }
                }
                Text("·").foregroundStyle(.quaternary)
                Button("Privacy") {
                    if let url = URL(string: "https://getmemoriapp.com/privacy") {
                        UIApplication.shared.open(url)
                    }
                }
            }
            .font(.caption2.weight(.medium))
            .foregroundStyle(.tertiary)
        }
    }

    // MARK: - Background

    @ViewBuilder
    private var paywallBackground: some View {
        ZStack {
            AppColors.pageBgDark

            LinearGradient(
                colors: [
                    selectedAccentColor.opacity(0.15),
                    selectedAccentColor.opacity(0.05),
                    .clear
                ],
                startPoint: .top,
                endPoint: .center
            )

            RadialGradient(
                colors: [selectedAccentColor.opacity(0.1), .clear],
                center: .init(x: 0.5, y: 0.15),
                startRadius: 20,
                endRadius: 250
            )
        }
        .animation(.easeInOut(duration: 0.3), value: selectedTier)
    }

    // MARK: - Copy

    private var heroHeadline: String {
        selectedTier == .ultra ? "Block the noise" : "Train without limits"
    }

    private var heroSubtitle: String {
        selectedTier == .ultra
            ? "Block distracting apps.\nEarn screen time with brain games."
            : "Unlimited games, insights, and leaderboards."
    }

    // MARK: - Helpers

    private var annualSavingsPercent: Int {
        guard let annual = storeService.annualProduct, let monthly = storeService.monthlyProduct else { return 58 }
        let monthlyFromAnnual = annual.price / 12
        let diff = NSDecimalNumber(decimal: monthly.price - monthlyFromAnnual)
        let total = NSDecimalNumber(decimal: monthly.price)
        return Int((diff.doubleValue / total.doubleValue * 100).rounded())
    }

    private var ultraAnnualSavingsPercent: Int {
        guard let annual = storeService.annualUltraProduct, let monthly = storeService.monthlyUltraProduct else { return 58 }
        let monthlyFromAnnual = annual.price / 12
        let diff = NSDecimalNumber(decimal: monthly.price - monthlyFromAnnual)
        let total = NSDecimalNumber(decimal: monthly.price)
        return Int((diff.doubleValue / total.doubleValue * 100).rounded())
    }

    private var annualPerMonthDetail: String {
        if let annual = storeService.annualProduct {
            let monthly = annual.price / 12
            let formatted = monthly.formatted(.currency(code: annual.priceFormatStyle.currencyCode ?? "USD"))
            return "Just \(formatted)/month"
        }
        return "Just $1.67/month"
    }

    private var ultraAnnualPerMonthDetail: String {
        if let annual = storeService.annualUltraProduct {
            let monthly = annual.price / 12
            let formatted = monthly.formatted(.currency(code: annual.priceFormatStyle.currencyCode ?? "USD"))
            return "Just \(formatted)/month"
        }
        return "Just $3.33/month"
    }

    private func purchase() async {
        let productID = selectedPlan
        if let product = storeService.products.first(where: { $0.id == productID }) {
            await storeService.purchase(product)
            if storeService.isProUser {
                Analytics.paywallConverted(plan: productID, price: NSDecimalNumber(decimal: product.price).doubleValue)
                UINotificationFeedbackGenerator().notificationOccurred(.success)
                SoundService.shared.playComplete()
                dismiss()
            }
        } else {
            await storeService.loadProducts()
            if let product = storeService.products.first(where: { $0.id == productID }) {
                await storeService.purchase(product)
                if storeService.isProUser {
                    Analytics.paywallConverted(plan: productID, price: NSDecimalNumber(decimal: product.price).doubleValue)
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

    private var ctaButtonLabel: String {
        let product = selectedProduct
        if let product,
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
        let product = selectedProduct
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
            return "No charge for \(value) \(unit). Cancel anytime."
        }
        return "Cancel anytime."
    }

    private var selectedProduct: Product? {
        switch selectedPlan {
        case StoreService.annualProductID:       return storeService.annualProduct
        case StoreService.monthlyProductID:      return storeService.monthlyProduct
        case StoreService.weeklyProductID:       return storeService.weeklyProduct
        case StoreService.annualUltraProductID:  return storeService.annualUltraProduct
        case StoreService.monthlyUltraProductID: return storeService.monthlyUltraProduct
        case StoreService.weeklyUltraProductID:  return storeService.weeklyUltraProduct
        default:                                 return storeService.annualProduct
        }
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

// MARK: - Plan Card (reused by OnboardingPaywallView)

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
            .background(RoundedRectangle(cornerRadius: 12).fill(AppColors.cardElevated))
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(isSelected ? accentColor.opacity(0.6) : Color.clear, lineWidth: 2)
            )
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Preview

#Preview("Paywall") {
    PaywallView()
        .environment(StoreService())
}
