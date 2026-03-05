import SwiftUI
import StoreKit

struct PaywallView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(StoreService.self) private var storeService

    @State private var selectedPlan: String = StoreService.annualProductID

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 28) {
                    heroSection
                    featuresSection
                    plansSection
                    purchaseButton
                    footerSection
                }
                .padding(.bottom, 32)
            }
            .pageBackground()
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        dismiss()
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .font(.title3)
                            .foregroundStyle(.secondary)
                    }
                }
            }
        }
    }

    // MARK: - Hero

    private var heroSection: some View {
        VStack(spacing: 12) {
            Image(systemName: "star.circle.fill")
                .font(.system(size: 56))
                .foregroundStyle(AppColors.accent)

            Text("Unlock Your Full Potential")
                .font(.title.weight(.bold))

            Text("All exercises, detailed analytics,\nand unlimited training")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .padding(.top, 24)
    }

    // MARK: - Features

    private var featuresSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            proFeatureRow(text: "All 5 spaced repetition categories")
            proFeatureRow(text: "Adaptive Dual N-Back (N=1-5)")
            proFeatureRow(text: "Unlimited active recall challenges")
            proFeatureRow(text: "Score trends & memory score")
            proFeatureRow(text: "Detailed progress analytics")
        }
        .padding(.horizontal, 24)
    }

    private func proFeatureRow(text: String) -> some View {
        HStack(spacing: 12) {
            Image(systemName: "checkmark.circle.fill")
                .foregroundStyle(AppColors.accent)
                .frame(width: 20)
            Text(text)
                .font(.subheadline)
            Spacer()
        }
    }

    // MARK: - Plans

    private var plansSection: some View {
        VStack(spacing: 10) {
            PlanCard(
                title: "Yearly",
                price: storeService.annualProduct?.displayPrice ?? "$39.99/yr",
                detail: "7-day free trial · Save 52%",
                badge: "Best Value",
                isSelected: selectedPlan == StoreService.annualProductID,
                accentColor: AppColors.accent
            ) {
                selectedPlan = StoreService.annualProductID
            }

            PlanCard(
                title: "Monthly",
                price: storeService.monthlyProduct?.displayPrice ?? "$6.99/mo",
                detail: "7-day free trial · Cancel anytime",
                badge: nil,
                isSelected: selectedPlan == StoreService.monthlyProductID,
                accentColor: AppColors.accent
            ) {
                selectedPlan = StoreService.monthlyProductID
            }

            PlanCard(
                title: "Lifetime",
                price: storeService.lifetimeProduct?.displayPrice ?? "$14.99",
                detail: "One-time purchase · Forever",
                badge: nil,
                isSelected: selectedPlan == StoreService.lifetimeProductID,
                accentColor: AppColors.accent
            ) {
                selectedPlan = StoreService.lifetimeProductID
            }
        }
        .padding(.horizontal, 20)
    }

    // MARK: - Purchase

    private var purchaseButton: some View {
        VStack(spacing: 12) {
            Button {
                Task { await purchase() }
            } label: {
                Group {
                    if storeService.isLoading {
                        ProgressView()
                            .tint(.white)
                    } else {
                        Text(selectedPlan == StoreService.lifetimeProductID ? "Purchase" : "Start 7-Day Free Trial")
                    }
                }
                .accentButton()
            }
            .disabled(storeService.isLoading)
            .padding(.horizontal, 20)

            if let error = storeService.purchaseError {
                Text(error)
                    .font(.caption)
                    .foregroundStyle(.red)
            }
        }
    }

    // MARK: - Footer

    private var footerSection: some View {
        VStack(spacing: 8) {
            Button("Restore Purchases") {
                Task { await storeService.restorePurchases() }
            }
            .font(.subheadline)
            .foregroundStyle(.secondary)

            Text("Cancel anytime. Your data stays on your device regardless.")
                .font(.caption)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .padding(.horizontal, 24)
    }

    private func purchase() async {
        let productID = selectedPlan
        if let product = storeService.products.first(where: { $0.id == productID }) {
            await storeService.purchase(product)
            if storeService.isProUser {
                dismiss()
            }
        } else {
            await storeService.loadProducts()
            if let product = storeService.products.first(where: { $0.id == productID }) {
                await storeService.purchase(product)
                if storeService.isProUser {
                    dismiss()
                }
            }
        }
    }
}

// MARK: - Plan Card

struct PlanCard: View {
    let title: String
    let price: String
    let detail: String
    let badge: String?
    let isSelected: Bool
    var accentColor: Color = AppColors.accent
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    HStack(spacing: 8) {
                        Text(title)
                            .font(.subheadline.weight(.semibold))
                        if let badge {
                            Text(badge)
                                .font(.caption2.weight(.semibold))
                                .padding(.horizontal, 8)
                                .padding(.vertical, 2)
                                .background(accentColor, in: Capsule())
                                .foregroundStyle(.white)
                        }
                    }
                    Text(detail)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Spacer()

                Text(price)
                    .font(.subheadline.weight(.semibold))

                Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                    .foregroundStyle(isSelected ? accentColor : Color.gray.opacity(0.3))
                    .font(.title3)
            }
            .padding(16)
            .background(
                Color(UIColor.secondarySystemGroupedBackground),
                in: RoundedRectangle(cornerRadius: 14)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 14)
                    .stroke(isSelected ? accentColor : Color.clear, lineWidth: 2)
            )
            .shadow(color: .black.opacity(0.04), radius: 8, y: 2)
        }
        .buttonStyle(.plain)
    }
}
