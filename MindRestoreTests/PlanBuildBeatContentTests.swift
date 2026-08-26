import XCTest
@testable import MindRestore

final class PlanBuildBeatContentTests: XCTestCase {

    func test_goalBeat_bubbleAndLine() {
        let c = PlanBuildBeatContent(
            beat: .goals,
            goals: [.screenTimeFrying],
            age: 24,
            dailyScreenTimeHours: 4.2,
            isEstimate: false
        )
        XCTAssertEqual(c.bubble, "Hours back. That's the mission.")
        XCTAssertEqual(c.newLine?.label, "Goal")
        XCTAssertEqual(c.newLine?.value, "hours back")
    }

    func test_goalBeat_bubbleUsesSelectedGoalMission() {
        let c = PlanBuildBeatContent(
            beat: .goals,
            goals: [.attentionShot],
            age: 24,
            dailyScreenTimeHours: 4.2,
            isEstimate: false
        )

        XCTAssertEqual(c.bubble, "Attention guarded. That's the mission.")
        XCTAssertEqual(c.newLine?.value, "attention guarded")
    }

    func test_goalBeat_usesFirstSelectedGoalWhenMultipleGoalsWerePicked() {
        let c = PlanBuildBeatContent(
            beat: .goals,
            goals: [.screenTimeFrying, .getSharper],
            selectedGoalOrder: [.getSharper, .screenTimeFrying],
            age: 24,
            dailyScreenTimeHours: 4.2,
            isEstimate: false
        )

        XCTAssertEqual(c.bubble, "A sharper brain. That's the mission.")
        XCTAssertEqual(c.newLine?.value, "a sharper brain")
    }

    func test_memoPlanPhrase_usesFirstSelectedGoalWhenMultipleGoalsWerePicked() {
        let phrase = PlanBuildBeatContent.memoPlanPhrase(
            [.screenTimeFrying, .getSharper],
            selectedGoalOrder: [.getSharper, .screenTimeFrying]
        )

        XCTAssertEqual(phrase, "brain getting sharper")
    }

    func test_ageBeat_interpolatesYearsAhead() {
        let c = PlanBuildBeatContent(
            beat: .age, goals: [], age: 24, dailyScreenTimeHours: 4, isEstimate: false
        )
        XCTAssertEqual(c.bubble, "24? You've got ~56 years of phone ahead.")
        XCTAssertEqual(c.newLine?.label, "Age")
        XCTAssertEqual(c.newLine?.value, "24 · ~56 yrs ahead")
    }

    func test_screenTimeBeat_computesDaysPerYear() {
        // 4.2h/day * 365 / 24 = 63.875 → rounds to 64
        let c = PlanBuildBeatContent(
            beat: .screenTime, goals: [], age: 24, dailyScreenTimeHours: 4.2, isEstimate: false
        )
        XCTAssertEqual(c.bubble, "4.2h a day… that's ~64 days a year gone.")
        XCTAssertEqual(c.newLine?.value, "4.2h/day")
    }

    func test_screenTimeBeat_estimateAtOrAboveEightClampsTo8Plus() {
        let c = PlanBuildBeatContent(
            beat: .screenTime, goals: [], age: 30, dailyScreenTimeHours: 9.0, isEstimate: true
        )
        XCTAssertEqual(c.newLine?.value, "8h+/day")
        XCTAssertTrue(c.bubble.contains("8h+"))
    }

    func test_finalBeat_hasNoNewLine_andPresentingCopy() {
        let c = PlanBuildBeatContent(
            beat: .final, goals: [.doomscrolling], age: 24, dailyScreenTimeHours: 4, isEstimate: false
        )
        XCTAssertNil(c.newLine)
        XCTAssertEqual(c.bubble, "Your counterattack's ready.")
    }

    func test_cumulativeLines_includesEveryBeatUpToCurrent() {
        let lines = PlanBuildBeatContent.cumulativeLines(
            upTo: .screenTime,
            goals: [.screenTimeFrying], age: 24, dailyScreenTimeHours: 4.2, isEstimate: false
        )
        XCTAssertEqual(lines.map(\.label), ["Goal", "Age", "Screen time"])
        XCTAssertEqual(lines.map(\.value), ["hours back", "24 · ~56 yrs ahead", "4.2h/day"])
    }

    func test_cumulativeLines_includesPersonalizationAnswersWhenProvided() {
        let lines = PlanBuildBeatContent.cumulativeLines(
            upTo: .personalization,
            goals: [.screenTimeFrying],
            selectedGoalOrder: [.screenTimeFrying],
            age: 24,
            dailyScreenTimeHours: 4.2,
            isEstimate: false,
            protectTarget: .sleep,
            feedWinMoment: .lateNight
        )

        XCTAssertEqual(lines.map(\.label), ["Goal", "Age", "Screen time", "Protecting", "Weak spot"])
        XCTAssertEqual(lines.map(\.value), ["hours back", "24 · ~56 yrs ahead", "4.2h/day", "Sleep", "Late night"])
    }

    func test_personalizationBeat_showsBothPersonalAnswersInOneBeat() {
        let c = PlanBuildBeatContent(
            beat: .personalization,
            goals: [.doomscrolling],
            age: 22,
            dailyScreenTimeHours: 7.1,
            isEstimate: false,
            protectTarget: .school,
            feedWinMoment: .afterStress
        )

        XCTAssertEqual(c.bubble, "Got it. We'll build around what you're protecting and when the feed hits hardest.")
        XCTAssertNil(c.newLine)
    }

    func test_goalSummary_fallsBackWhenNoKnownGoal() {
        let c = PlanBuildBeatContent(
            beat: .goals, goals: [], age: 24, dailyScreenTimeHours: 4, isEstimate: false
        )
        XCTAssertEqual(c.newLine?.value, "hours back")
    }
}

final class PaywallPersonalizationContentTests: XCTestCase {
    func test_paywallPersonalizationEchoesProtectAndFeedTimingAnswers() {
        let content = PaywallPersonalizationContent(
            protectTarget: .school,
            feedWinMoment: .lateNight
        )

        XCTAssertEqual(content.protectTitle, "Block the feed")
        XCTAssertEqual(content.protectValue, "Protect school")
        XCTAssertEqual(content.protectIcon, "graduationcap.fill")
        XCTAssertEqual(content.feedTimingTitle, "Guard addictive apps")
        XCTAssertEqual(content.feedTimingValue, "Late night")
        XCTAssertEqual(content.feedTimingIcon, "moon.stars.fill")
    }

    func test_paywallPersonalizationHasFallbackCopyForNonOnboardingPaywalls() {
        let content = PaywallPersonalizationContent(
            protectTarget: nil,
            feedWinMoment: nil
        )

        XCTAssertEqual(content.protectValue, "Protect your time")
        XCTAssertEqual(content.feedTimingValue, "Your weakest moment")
        XCTAssertEqual(content.protectIcon, "lock.shield.fill")
        XCTAssertEqual(content.feedTimingIcon, "bell.badge.fill")
    }

    func test_planCardLayoutKeepsFullSizeCardsCentered() {
        let layout = PaywallPlanCardLayout(containerWidth: 349, compact: false)

        XCTAssertEqual(layout.spacing, 12)
        XCTAssertEqual(layout.cardWidth, 168, accuracy: 0.001)
        XCTAssertEqual(layout.groupWidth, 348, accuracy: 0.001)
        XCTAssertEqual(layout.sideInset, 0.5, accuracy: 0.001)
        XCTAssertEqual(layout.groupOffsetX, 0, accuracy: 0.001)
    }

    func test_planCardLayoutUsesFullScreenshotRowWidth() {
        let layout = PaywallPlanCardLayout(containerWidth: 324, compact: false)

        XCTAssertEqual(layout.cardWidth, 156, accuracy: 0.001)
        XCTAssertEqual(layout.groupWidth, 324, accuracy: 0.001)
        XCTAssertEqual(layout.sideInset, 0, accuracy: 0.001)
        XCTAssertEqual(layout.groupOffsetX, 0, accuracy: 0.001)
    }

    func test_planCardLayoutCapsWidthOnWiderScreens() {
        let layout = PaywallPlanCardLayout(containerWidth: 386, compact: false)

        XCTAssertEqual(layout.cardWidth, 168, accuracy: 0.001)
        XCTAssertEqual(layout.groupWidth, 348, accuracy: 0.001)
        XCTAssertEqual(layout.sideInset, 19, accuracy: 0.001)
        XCTAssertEqual(layout.groupOffsetX, 0, accuracy: 0.001)
    }

}
