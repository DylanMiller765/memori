import Foundation

/// Pure, UI-free content for the onboarding "Memo building your plan" beats.
/// Given the data collected so far, produces Memo's speech bubble and the
/// clipboard line items. No SwiftUI — fully unit-testable.
struct PlanBuildBeatContent {
    enum Beat: CaseIterable {
        case goals, age, screenTime, personalization, final
    }

    enum ProtectTarget: String, CaseIterable, Identifiable {
        case school
        case work
        case sleep
        case creativeWork
        case relationships
        case mentalClarity

        var id: String { rawValue }

        var emoji: String {
            switch self {
            case .school: return "🎓"
            case .work: return "💼"
            case .sleep: return "😴"
            case .creativeWork: return "🎨"
            case .relationships: return "❤️"
            case .mentalClarity: return "🧠"
            }
        }

        var title: String {
            switch self {
            case .school: return "School"
            case .work: return "Work"
            case .sleep: return "Sleep"
            case .creativeWork: return "Creative work"
            case .relationships: return "Relationships"
            case .mentalClarity: return "Mental clarity"
            }
        }
    }

    enum FeedWinMoment: String, CaseIterable, Identifiable {
        case lateNight
        case morning
        case betweenWorkOrClass
        case afterStress
        case whenBored
        case allDay

        var id: String { rawValue }

        var emoji: String {
            switch self {
            case .lateNight: return "🌙"
            case .morning: return "☀️"
            case .betweenWorkOrClass: return "🏫"
            case .afterStress: return "😵"
            case .whenBored: return "🥱"
            case .allDay: return "📱"
            }
        }

        var title: String {
            switch self {
            case .lateNight: return "Late night"
            case .morning: return "Morning"
            case .betweenWorkOrClass: return "Between work or class"
            case .afterStress: return "After stress"
            case .whenBored: return "When bored"
            case .allDay: return "All day"
            }
        }
    }

    struct Line: Equatable {
        let label: String
        let value: String
    }

    let beat: Beat
    let goals: Set<UserFocusGoal>
    let selectedGoalOrder: [UserFocusGoal]
    let age: Int
    let dailyScreenTimeHours: Double
    let isEstimate: Bool
    let protectTarget: ProtectTarget?
    let feedWinMoment: FeedWinMoment?

    init(
        beat: Beat,
        goals: Set<UserFocusGoal>,
        selectedGoalOrder: [UserFocusGoal] = [],
        age: Int,
        dailyScreenTimeHours: Double,
        isEstimate: Bool,
        protectTarget: ProtectTarget? = nil,
        feedWinMoment: FeedWinMoment? = nil
    ) {
        self.beat = beat
        self.goals = goals
        self.selectedGoalOrder = selectedGoalOrder
        self.age = age
        self.dailyScreenTimeHours = dailyScreenTimeHours
        self.isEstimate = isEstimate
        self.protectTarget = protectTarget
        self.feedWinMoment = feedWinMoment
    }

    private static let lifeExpectancy = 80

    private var yearsAhead: Int { max(0, Self.lifeExpectancy - age) }

    /// Human-readable hours/day, clamped to "8h+" for high estimates (mirrors
    /// the existing screen-time presentation rule).
    private var hoursLabel: String {
        if dailyScreenTimeHours >= 8 && isEstimate { return "8h+" }
        // Trim trailing ".0" so 4.0 → "4", 4.2 → "4.2".
        let rounded = (dailyScreenTimeHours * 10).rounded() / 10
        if rounded == rounded.rounded() {
            return "\(Int(rounded))h"
        }
        return "\(rounded)h"
    }

    /// Days per year spent on screen = hours/day * 365 / 24, rounded.
    private var daysPerYear: Int {
        Int((dailyScreenTimeHours * 365 / 24).rounded())
    }

    /// Goal phrase, reusing the same mapping as `onboardingPlanGoalSummary`.
    static func goalSummary(_ goals: Set<UserFocusGoal>, selectedGoalOrder: [UserFocusGoal] = []) -> String {
        switch primaryGoal(in: goals, selectedGoalOrder: selectedGoalOrder) {
        case .attentionShot: return "attention guarded"
        case .screenTimeFrying: return "hours back"
        case .doomscrolling: return "sleep protected"
        case .loseFocus: return "focus that holds"
        case .forgetInstantly: return "memory that sticks"
        case .getSharper: return "a sharper brain"
        case nil: break
        }
        return "hours back"
    }

    static func memoPlanPhrase(_ goals: Set<UserFocusGoal>, selectedGoalOrder: [UserFocusGoal] = []) -> String {
        switch primaryGoal(in: goals, selectedGoalOrder: selectedGoalOrder) {
        case .attentionShot: return "attention back"
        case .screenTimeFrying: return "hours back"
        case .doomscrolling: return "sleep back"
        case .loseFocus: return "focus back"
        case .forgetInstantly: return "memory back"
        case .getSharper: return "brain getting sharper"
        case nil: break
        }
        return "time back"
    }

    private static func primaryGoal(
        in goals: Set<UserFocusGoal>,
        selectedGoalOrder: [UserFocusGoal]
    ) -> UserFocusGoal? {
        if let selectedFirst = selectedGoalOrder.first(where: { goals.contains($0) }) {
            return selectedFirst
        }

        return [.attentionShot, .screenTimeFrying, .doomscrolling, .loseFocus, .forgetInstantly, .getSharper]
            .first { goals.contains($0) }
    }

    private static func mission(_ summary: String) -> String {
        return "\(summary.prefix(1).uppercased())\(summary.dropFirst()). That's the mission."
    }

    var bubble: String {
        switch beat {
        case .goals:
            return Self.mission(Self.goalSummary(goals, selectedGoalOrder: selectedGoalOrder))
        case .age:
            return "\(age)? You've got ~\(yearsAhead) years of phone ahead."
        case .screenTime:
            return "\(hoursLabel) a day… that's ~\(daysPerYear) days a year gone."
        case .personalization:
            return "Got it. We'll build around what you're protecting and when the feed hits hardest."
        case .final:
            return "Your counterattack's ready."
        }
    }

    /// The single line THIS beat adds (nil for the final beat, which adds none).
    var newLine: Line? {
        switch beat {
        case .goals:
            return Line(label: "Goal", value: Self.goalSummary(goals, selectedGoalOrder: selectedGoalOrder))
        case .age:
            return Line(label: "Age", value: "\(age) · ~\(yearsAhead) yrs ahead")
        case .screenTime:
            return Line(label: "Screen time", value: "\(hoursLabel)/day")
        case .personalization:
            return nil
        case .final:
            return nil
        }
    }

    /// Every line earned up to AND including `upTo`, in beat order.
    static func cumulativeLines(
        upTo: Beat,
        goals: Set<UserFocusGoal>,
        selectedGoalOrder: [UserFocusGoal] = [],
        age: Int,
        dailyScreenTimeHours: Double,
        isEstimate: Bool,
        protectTarget: ProtectTarget? = nil,
        feedWinMoment: FeedWinMoment? = nil
    ) -> [Line] {
        let order: [Beat] = [.goals, .age, .screenTime, .personalization]
        let cutoff = (upTo == .final) ? order.count : (order.firstIndex(of: upTo).map { $0 + 1 } ?? 0)
        return order.prefix(cutoff).flatMap { b -> [Line] in
            if b == .personalization {
                return [
                    protectTarget.map { Line(label: "Protecting", value: $0.title) },
                    feedWinMoment.map { Line(label: "Weak spot", value: $0.title) }
                ].compactMap { $0 }
            }

            return PlanBuildBeatContent(
                beat: b, goals: goals, selectedGoalOrder: selectedGoalOrder, age: age,
                dailyScreenTimeHours: dailyScreenTimeHours, isEstimate: isEstimate,
                protectTarget: protectTarget, feedWinMoment: feedWinMoment
            ).newLine.map { [$0] } ?? []
        }
    }
}
