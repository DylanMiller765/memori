import SwiftUI
import WidgetKit

// MARK: - Timeline Entry

struct MemoriWidgetEntry: TimelineEntry {
    let date: Date
    let streak: Int
    let level: Int
    let levelName: String
    let totalXP: Int
    let xpForNextLevel: Int
    let exercisesToday: Int
    let dailyGoal: Int
    let brainScore: Int
    let trainedToday: Bool
}

// MARK: - Timeline Provider

struct MemoriTimelineProvider: TimelineProvider {

    func placeholder(in context: Context) -> MemoriWidgetEntry {
        MemoriWidgetEntry(
            date: .now,
            streak: 7,
            level: 3,
            levelName: "Explorer",
            totalXP: 1200,
            xpForNextLevel: 2000,
            exercisesToday: 2,
            dailyGoal: 3,
            brainScore: 720,
            trainedToday: true
        )
    }

    func getSnapshot(in context: Context, completion: @escaping (MemoriWidgetEntry) -> Void) {
        completion(entry(from: WidgetDataService.currentSnapshot()))
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<MemoriWidgetEntry>) -> Void) {
        let current = entry(from: WidgetDataService.currentSnapshot())
        // Refresh once per hour or when the app calls reloadAllTimelines
        let nextUpdate = Calendar.current.date(byAdding: .hour, value: 1, to: .now) ?? .now
        completion(Timeline(entries: [current], policy: .after(nextUpdate)))
    }

    private func entry(from snap: WidgetDataService.Snapshot) -> MemoriWidgetEntry {
        MemoriWidgetEntry(
            date: .now,
            streak: snap.streak,
            level: snap.level,
            levelName: snap.levelName,
            totalXP: snap.totalXP,
            xpForNextLevel: snap.xpForNextLevel,
            exercisesToday: snap.exercisesToday,
            dailyGoal: snap.dailyGoal,
            brainScore: snap.brainScore,
            trainedToday: snap.trainedToday
        )
    }
}

// MARK: - Widget Colors (standalone, no dependency on main app DesignSystem)

private enum WidgetColors {
    static let accent = Color(red: 0.22, green: 0.52, blue: 0.96)
    static let teal   = Color(red: 0.0, green: 0.73, blue: 0.68)
    static let flame  = Color(red: 1.0, green: 0.55, blue: 0.2)
}

// MARK: - Small Widget View

struct MemoriSmallWidgetView: View {
    let entry: MemoriWidgetEntry

    private var scoreProgress: Double {
        min(Double(entry.brainScore) / 1000.0, 1.0)
    }

    var body: some View {
        VStack(spacing: 6) {
            // Brain Score Ring
            ZStack {
                Circle()
                    .stroke(WidgetColors.accent.opacity(0.15), lineWidth: 6)
                    .frame(width: 56, height: 56)
                Circle()
                    .trim(from: 0, to: scoreProgress)
                    .stroke(WidgetColors.accent, style: StrokeStyle(lineWidth: 6, lineCap: .round))
                    .frame(width: 56, height: 56)
                    .rotationEffect(.degrees(-90))
                Text("\(entry.brainScore)")
                    .font(.system(size: 16, weight: .bold, design: .rounded))
                    .foregroundStyle(.primary)
            }

            // Streak
            HStack(spacing: 3) {
                Image(systemName: entry.streak > 0 ? "flame.fill" : "flame")
                    .font(.system(size: 12, weight: .bold))
                    .foregroundStyle(
                        entry.streak > 0
                            ? LinearGradient(colors: [WidgetColors.flame, .red], startPoint: .top, endPoint: .bottom)
                            : LinearGradient(colors: [.gray, .gray], startPoint: .top, endPoint: .bottom)
                    )
                Text("\(entry.streak) day streak")
                    .font(.system(size: 11, weight: .semibold, design: .rounded))
                    .foregroundStyle(.secondary)
            }

            if !entry.trainedToday {
                Text("Train today!")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(WidgetColors.accent)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .containerBackground(for: .widget) {
            Color(.systemBackground)
        }
        .widgetURL(URL(string: "memo://train")!)
    }
}

// MARK: - Medium Widget View

struct MemoriMediumWidgetView: View {
    let entry: MemoriWidgetEntry

    private var xpProgress: Double {
        guard entry.xpForNextLevel > 0 else { return 0 }
        return min(Double(entry.totalXP) / Double(entry.xpForNextLevel), 1.0)
    }

    private var goalProgress: Double {
        guard entry.dailyGoal > 0 else { return 0 }
        return min(Double(entry.exercisesToday) / Double(entry.dailyGoal), 1.0)
    }

    var body: some View {
        HStack(spacing: 16) {
            // Left: Brain Score + Streak
            VStack(spacing: 8) {
                // Brain Score
                VStack(spacing: 2) {
                    Text("Brain Score")
                        .font(.system(size: 8, weight: .semibold))
                        .foregroundStyle(.secondary)
                        .textCase(.uppercase)
                    Text("\(entry.brainScore)")
                        .font(.system(size: 22, weight: .bold, design: .rounded))
                        .foregroundStyle(WidgetColors.accent)
                }

                // Streak
                HStack(spacing: 3) {
                    Image(systemName: entry.streak > 0 ? "flame.fill" : "flame")
                        .font(.system(size: 14, weight: .bold))
                        .foregroundStyle(
                            entry.streak > 0
                                ? LinearGradient(colors: [WidgetColors.flame, .red], startPoint: .top, endPoint: .bottom)
                                : LinearGradient(colors: [.gray, .gray], startPoint: .top, endPoint: .bottom)
                        )
                    Text("\(entry.streak)")
                        .font(.system(size: 16, weight: .bold, design: .rounded))
                }
                Text("streak")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
            .frame(width: 70)

            // Right: Stats
            VStack(alignment: .leading, spacing: 8) {
                // Level
                HStack {
                    Image(systemName: "star.fill")
                        .font(.caption)
                        .foregroundStyle(WidgetColors.accent)
                    Text("Lv.\(entry.level) \(entry.levelName)")
                        .font(.subheadline.weight(.semibold))
                        .lineLimit(1)
                }

                // XP Progress
                VStack(alignment: .leading, spacing: 3) {
                    Text("\(entry.totalXP) / \(entry.xpForNextLevel) XP")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                    GeometryReader { geo in
                        ZStack(alignment: .leading) {
                            Capsule()
                                .fill(WidgetColors.accent.opacity(0.15))
                            Capsule()
                                .fill(
                                    LinearGradient(
                                        colors: [WidgetColors.accent, WidgetColors.teal],
                                        startPoint: .leading,
                                        endPoint: .trailing
                                    )
                                )
                                .frame(width: geo.size.width * xpProgress)
                        }
                    }
                    .frame(height: 6)
                }

                // Daily goal
                HStack {
                    Image(systemName: "target")
                        .font(.caption)
                        .foregroundStyle(WidgetColors.teal)
                    Text("\(entry.exercisesToday)/\(entry.dailyGoal) exercises")
                        .font(.caption.weight(.medium))

                    Spacer()

                    if !entry.trainedToday {
                        Text("Train today!")
                            .font(.caption2.weight(.semibold))
                            .foregroundStyle(WidgetColors.accent)
                    }
                }
            }
        }
        .padding(.horizontal, 4)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .containerBackground(for: .widget) {
            Color(.systemBackground)
        }
        .widgetURL(URL(string: "memo://train")!)
    }
}

// MARK: - Widget Entry View

struct MemoriWidgetEntryView: View {
    @Environment(\.widgetFamily) var family
    let entry: MemoriWidgetEntry

    var body: some View {
        switch family {
        case .systemMedium:
            MemoriMediumWidgetView(entry: entry)
        default:
            MemoriSmallWidgetView(entry: entry)
        }
    }
}

// MARK: - Widget Configuration

struct MemoriWidget: Widget {
    let kind = "MemoriWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: MemoriTimelineProvider()) { entry in
            MemoriWidgetEntryView(entry: entry)
        }
        .configurationDisplayName("Memo")
        .description("Track your blocking streak and brain training progress.")
        .supportedFamilies([.systemSmall, .systemMedium])
    }
}

// MARK: - Preview

#Preview("Small", as: .systemSmall) {
    MemoriWidget()
} timeline: {
    MemoriWidgetEntry(
        date: .now, streak: 12, level: 5, levelName: "Scholar",
        totalXP: 3400, xpForNextLevel: 5000,
        exercisesToday: 2, dailyGoal: 3, brainScore: 720, trainedToday: true
    )
    MemoriWidgetEntry(
        date: .now, streak: 0, level: 1, levelName: "Novice",
        totalXP: 0, xpForNextLevel: 500,
        exercisesToday: 0, dailyGoal: 3, brainScore: 0, trainedToday: false
    )
}

#Preview("Medium", as: .systemMedium) {
    MemoriWidget()
} timeline: {
    MemoriWidgetEntry(
        date: .now, streak: 12, level: 5, levelName: "Scholar",
        totalXP: 3400, xpForNextLevel: 5000,
        exercisesToday: 2, dailyGoal: 3, brainScore: 720, trainedToday: true
    )
}
