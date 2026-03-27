import SwiftUI
import Charts

struct BrainScoreChart: View {
    let scores: [BrainScoreResult]
    var height: CGFloat = 150
    var showHeader: Bool = true

    /// Scores sorted oldest-first, limited to last 30 days
    private var chartScores: [BrainScoreResult] {
        let cutoff = Calendar.current.date(byAdding: .day, value: -30, to: Date.now) ?? Date.now
        let filtered = scores.filter { $0.date >= cutoff }
        let data = filtered.isEmpty ? scores : filtered
        return data.sorted { $0.date < $1.date }
    }

    private var trendText: String {
        let sorted = scores.sorted { $0.date < $1.date }
        guard let latest = sorted.last else { return "" }

        let sevenDaysAgo = Calendar.current.date(byAdding: .day, value: -7, to: Date.now) ?? Date.now
        let weekAgoScore = sorted.last(where: { $0.date <= sevenDaysAgo })

        if let previous = weekAgoScore {
            let diff = latest.brainScore - previous.brainScore
            if diff > 5 {
                return "\u{2191} \(diff) points this week"
            } else if diff < -5 {
                return "\u{2193} \(abs(diff)) points this week"
            } else {
                return "\u{2192} Steady this week"
            }
        } else if sorted.count >= 2 {
            let previous = sorted[sorted.count - 2]
            let diff = latest.brainScore - previous.brainScore
            if diff > 5 {
                return "\u{2191} \(diff) points since last test"
            } else if diff < -5 {
                return "\u{2193} \(abs(diff)) points since last test"
            } else {
                return "\u{2192} Steady"
            }
        }
        return ""
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            if showHeader {
                Text("SCORE TREND")
                    .font(.caption.weight(.bold))
                    .foregroundStyle(.secondary)
                    .tracking(0.8)
            }

            if chartScores.count < 2 {
                singlePointView
            } else {
                chartView
            }

            if !trendText.isEmpty {
                Text(trendText)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(
                        trendText.hasPrefix("\u{2191}") ? AppColors.accent :
                        trendText.hasPrefix("\u{2193}") ? AppColors.coral :
                        .secondary
                    )
            }
        }
    }

    // MARK: - Single Point View

    private var singlePointView: some View {
        VStack(spacing: 8) {
            if let score = chartScores.first {
                HStack {
                    Spacer()
                    Circle()
                        .fill(AppColors.accent)
                        .frame(width: 12, height: 12)
                    Text("\(score.brainScore)")
                        .font(.headline.weight(.bold))
                        .foregroundStyle(AppColors.accent)
                    Spacer()
                }
            }
            Text("Take more assessments to see your trend")
                .font(.caption)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .frame(height: height)
        .frame(maxWidth: .infinity)
    }

    // MARK: - Chart View

    private var chartView: some View {
        Chart {
            ForEach(Array(chartScores.enumerated()), id: \.offset) { index, score in
                // Gradient area under the line
                AreaMark(
                    x: .value("Date", score.date),
                    y: .value("Score", score.brainScore)
                )
                .foregroundStyle(
                    LinearGradient(
                        colors: [AppColors.accent.opacity(0.25), AppColors.accent.opacity(0.02)],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
                .interpolationMethod(.catmullRom)

                // Line
                LineMark(
                    x: .value("Date", score.date),
                    y: .value("Score", score.brainScore)
                )
                .foregroundStyle(AppColors.accent)
                .interpolationMethod(.catmullRom)
                .lineStyle(StrokeStyle(lineWidth: 2.5))

                // Data point circles
                PointMark(
                    x: .value("Date", score.date),
                    y: .value("Score", score.brainScore)
                )
                .foregroundStyle(AppColors.accent)
                .symbolSize(index == chartScores.count - 1 ? 50 : 20)
            }
        }
        .chartYScale(domain: yAxisDomain)
        .chartYAxis {
            AxisMarks(position: .leading, values: yAxisValues) { value in
                AxisGridLine(stroke: StrokeStyle(lineWidth: 0.5, dash: [4, 4]))
                    .foregroundStyle(.secondary.opacity(0.3))
                AxisValueLabel {
                    if let v = value.as(Int.self) {
                        Text("\(v)")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                }
            }
        }
        .chartXAxis {
            if chartScores.count > 2 {
                AxisMarks(values: .stride(by: .day, count: xAxisStride)) { _ in
                    AxisGridLine(stroke: StrokeStyle(lineWidth: 0.5, dash: [4, 4]))
                        .foregroundStyle(.secondary.opacity(0.2))
                    AxisValueLabel(format: xAxisDateFormat, centered: true)
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
            } else {
                AxisMarks { _ in }
            }
        }
        .chartPlotStyle { plotArea in
            plotArea.frame(height: height - 32)
        }
        .frame(height: height)
        .clipped()
    }

    // MARK: - Axis Helpers

    private var yAxisDomain: ClosedRange<Int> {
        let allScores = chartScores.map(\.brainScore)
        let rawMin = allScores.min() ?? 0
        let rawMax = allScores.max() ?? 1000
        // Always give at least 50pt headroom above and below, or 40% of span
        let span = max(rawMax - rawMin, 1)
        let padding = max(50, span * 2 / 5)
        let minScore = max(0, rawMin - padding)
        let maxScore = min(1000, rawMax + padding)
        return minScore...maxScore
    }

    private var yAxisValues: [Int] {
        let range = yAxisDomain
        let span = range.upperBound - range.lowerBound
        let step: Int
        if span <= 200 { step = 50 }
        else if span <= 500 { step = 100 }
        else { step = 250 }

        var values: [Int] = []
        var current = (range.lowerBound / step) * step
        while current <= range.upperBound {
            if current >= range.lowerBound {
                values.append(current)
            }
            current += step
        }
        return values
    }

    private var dateSpanDays: Int {
        guard let first = chartScores.first, let last = chartScores.last else { return 0 }
        return max(1, Calendar.current.dateComponents([.day], from: first.date, to: last.date).day ?? 1)
    }

    private var xAxisStride: Int {
        let span = dateSpanDays
        if span <= 7 { return 1 }
        if span <= 14 { return 2 }
        if span <= 30 { return 5 }
        return 7
    }

    private var xAxisDateFormat: Date.FormatStyle {
        let span = dateSpanDays
        if span <= 7 {
            return .dateTime.weekday(.abbreviated)
        }
        return .dateTime.month(.narrow).day()
    }
}
