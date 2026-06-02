import XCTest
@testable import MindRestore

final class PlanBuildBeatContentTests: XCTestCase {

    func test_goalBeat_bubbleAndLine() {
        let c = PlanBuildBeatContent(
            beat: .goals,
            goals: [.screenTimeFrying],
            protectedPriority: .sleep,
            dangerWindow: .lateNight,
            age: 24,
            dailyScreenTimeHours: 4.2,
            isEstimate: false
        )
        XCTAssertEqual(c.bubble, "Hours back. That's the mission.")
        XCTAssertEqual(c.newLine?.label, "Goal")
        XCTAssertEqual(c.newLine?.value, "hours back")
    }

    func test_ageBeat_interpolatesYearsAhead() {
        let c = PlanBuildBeatContent(
            beat: .age, goals: [], protectedPriority: .school, dangerWindow: .morning,
            age: 24, dailyScreenTimeHours: 4, isEstimate: false
        )
        XCTAssertEqual(c.bubble, "24? You've got ~56 years of phone ahead.")
        XCTAssertEqual(c.newLine?.label, "Age")
        XCTAssertEqual(c.newLine?.value, "24 · ~56 yrs ahead")
    }

    func test_screenTimeBeat_computesDaysPerYear() {
        // 4.2h/day * 365 / 24 = 63.875 → rounds to 64
        let c = PlanBuildBeatContent(
            beat: .screenTime, goals: [], protectedPriority: .mentalClarity, dangerWindow: .afterStress,
            age: 24, dailyScreenTimeHours: 4.2, isEstimate: false
        )
        XCTAssertEqual(c.bubble, "4.2h a day... that's ~64 days a year gone.")
        XCTAssertEqual(c.newLine?.value, "4.2h/day")
    }

    func test_screenTimeBeat_estimateAtOrAboveEightClampsTo8Plus() {
        let c = PlanBuildBeatContent(
            beat: .screenTime, goals: [], protectedPriority: .creativeWork, dangerWindow: .allDay,
            age: 30, dailyScreenTimeHours: 9.0, isEstimate: true
        )
        XCTAssertEqual(c.newLine?.value, "8h+/day")
        XCTAssertTrue(c.bubble.contains("8h+"))
    }

    func test_finalBeat_hasNoNewLine_andPresentingCopy() {
        let c = PlanBuildBeatContent(
            beat: .final, goals: [.doomscrolling], protectedPriority: .sleep, dangerWindow: .lateNight,
            age: 24, dailyScreenTimeHours: 4, isEstimate: false
        )
        XCTAssertNil(c.newLine)
        XCTAssertEqual(c.bubble, "Your counterattack's ready.")
    }

    func test_cumulativeLines_includesEveryBeatUpToCurrent() {
        let lines = PlanBuildBeatContent.cumulativeLines(
            upTo: .screenTime,
            goals: [.screenTimeFrying],
            protectedPriority: .work,
            dangerWindow: .workBreaks,
            age: 24,
            dailyScreenTimeHours: 4.2,
            isEstimate: false
        )
        XCTAssertEqual(lines.map(\.label), ["Goal", "Protect", "Danger window", "Age", "Screen time"])
        XCTAssertEqual(lines.map(\.value), ["hours back", "work", "work/class breaks", "24 · ~56 yrs ahead", "4.2h/day"])
    }

    func test_goalSummary_fallsBackWhenNoKnownGoal() {
        let c = PlanBuildBeatContent(
            beat: .goals, goals: [], protectedPriority: nil, dangerWindow: nil,
            age: 24, dailyScreenTimeHours: 4, isEstimate: false
        )
        XCTAssertEqual(c.newLine?.value, "hours back")
    }

    func test_personalizationBeats_echoProtectedPriorityAndDangerWindow() {
        let protect = PlanBuildBeatContent(
            beat: .protect,
            goals: [.attentionShot],
            protectedPriority: .relationships,
            dangerWindow: .boredom,
            age: 29,
            dailyScreenTimeHours: 5,
            isEstimate: false
        )
        XCTAssertEqual(protect.bubble, "Protect relationships. That changes the plan.")
        XCTAssertEqual(protect.newLine, .init(label: "Protect", value: "relationships"))

        let window = PlanBuildBeatContent(
            beat: .dangerWindow,
            goals: [.attentionShot],
            protectedPriority: .relationships,
            dangerWindow: .boredom,
            age: 29,
            dailyScreenTimeHours: 5,
            isEstimate: false
        )
        XCTAssertEqual(window.bubble, "Boredom is where the feed gets loud.")
        XCTAssertEqual(window.newLine, .init(label: "Danger window", value: "boredom"))
    }
}
