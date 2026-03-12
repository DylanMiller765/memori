import SwiftUI

struct BrainScoreExplainerSheet: View {
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    // Header
                    VStack(spacing: 8) {
                        Image(systemName: "brain.head.profile")
                            .font(.system(size: 40))
                            .foregroundStyle(AppColors.accent)
                        Text("How Brain Score Works")
                            .font(.title2.weight(.bold))
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.top, 8)

                    // Formula
                    Text("Your brain score (0–1000) combines three cognitive tests, each scored individually then weighted:")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)

                    // Domain rows
                    VStack(spacing: 16) {
                        domainRow(
                            color: AppColors.violet,
                            label: "Memory",
                            weight: "35%",
                            description: "How many digits you can hold in sequence (digit span)"
                        )
                        domainRow(
                            color: AppColors.coral,
                            label: "Speed",
                            weight: "30%",
                            description: "How fast you react to visual stimuli (reaction time)"
                        )
                        domainRow(
                            color: AppColors.sky,
                            label: "Visual",
                            weight: "35%",
                            description: "How many cells you recall in a pattern grid"
                        )
                    }
                    .appCard()

                    // Brain Age
                    VStack(alignment: .leading, spacing: 6) {
                        HStack(spacing: 8) {
                            Image(systemName: "calendar.circle.fill")
                                .font(.title3)
                                .foregroundStyle(AppColors.accent)
                            Text("Brain Age")
                                .font(.headline)
                        }
                        Text("Estimates your cognitive age based on your overall score. A lower brain age means sharper performance. Range: 18–75.")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }

                    // Percentile
                    VStack(alignment: .leading, spacing: 6) {
                        HStack(spacing: 8) {
                            Image(systemName: "chart.bar.fill")
                                .font(.title3)
                                .foregroundStyle(AppColors.accent)
                            Text("Percentile")
                                .font(.headline)
                        }
                        Text("Shows how you compare to all users. \"Top 10%\" means you scored higher than 90% of people.")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }

                    // Science note
                    VStack(alignment: .leading, spacing: 6) {
                        HStack(spacing: 8) {
                            Image(systemName: "book.closed.fill")
                                .font(.title3)
                                .foregroundStyle(.secondary)
                            Text("The Science")
                                .font(.headline)
                        }
                        Text("Scoring is based on cognitive science norms: Miller's Law for digit span (7±2), average simple reaction time (~250ms for young adults), and pattern recall benchmarks.")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 32)
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { dismiss() }
                        .font(.subheadline.weight(.semibold))
                }
            }
        }
        .presentationDetents([.medium, .large])
        .presentationDragIndicator(.visible)
    }

    private func domainRow(color: Color, label: String, weight: String, description: String) -> some View {
        HStack(alignment: .top, spacing: 12) {
            Circle()
                .fill(color)
                .frame(width: 10, height: 10)
                .padding(.top, 5)

            VStack(alignment: .leading, spacing: 2) {
                HStack {
                    Text(label)
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(color)
                    Spacer()
                    Text(weight)
                        .font(.caption.weight(.bold))
                        .foregroundStyle(AppColors.textTertiary)
                }
                Text(description)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }
}
