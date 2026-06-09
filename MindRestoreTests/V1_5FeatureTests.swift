import XCTest
@testable import MindRestore

@MainActor
final class RemovedV15ChallengeFeatureTests: XCTestCase {
    func testPaywallTrainingCountDoesNotGateGames() {
        UserDefaults.standard.removeObject(forKey: "training_exercise_count")
        UserDefaults.standard.removeObject(forKey: "training_exercise_date")

        let service = PaywallTriggerService()

        for _ in 0..<10 {
            service.recordExerciseCompleted(gameType: .reactionTime)
        }

        XCTAssertEqual(service.exercisesToday, 10)
        XCTAssertFalse(service.shouldShowPaywall)
    }
}

final class AnalyticsFunnelTests: XCTestCase {
    func testOnboardingStepPropertiesIncludeFunnelContext() {
        let properties = Analytics.onboardingStepProperties(
            step: "screenTimeAccessApproved",
            stepIndex: 7,
            totalSteps: 15,
            secondsSinceStart: 91.4,
            secondsOnStep: 12.8,
            goals: ["doomscrolling", "loseFocus"],
            selectedAge: 22,
            screenTimeHours: 5.25,
            screenTimeIsEstimate: false,
            brainAge: 29,
            brainScore: 612,
            receiptCount: 3
        )

        XCTAssertEqual(properties["step"] as? String, "screenTimeAccessApproved")
        XCTAssertEqual(properties["step_index"] as? Int, 7)
        XCTAssertEqual(properties["total_steps"] as? Int, 15)
        XCTAssertEqual(properties["progress_percent"] as? Int, 53)
        XCTAssertEqual(properties["seconds_since_onboarding_start"] as? Int, 91)
        XCTAssertEqual(properties["seconds_on_step"] as? Int, 13)
        XCTAssertEqual(properties["goal_count"] as? Int, 2)
        XCTAssertEqual(properties["goals"] as? String, "doomscrolling,loseFocus")
        XCTAssertEqual(properties["selected_age"] as? Int, 22)
        XCTAssertEqual(properties["screen_time_hours"] as? Double, 5.25)
        XCTAssertEqual(properties["screen_time_is_estimate"] as? Bool, false)
        XCTAssertEqual(properties["brain_age"] as? Int, 29)
        XCTAssertEqual(properties["brain_score"] as? Int, 612)
        XCTAssertEqual(properties["brain_age_delta"] as? Int, 7)
        XCTAssertEqual(properties["receipt_count"] as? Int, 3)
    }

    func testPaywallPurchasePropertiesIncludeConversionContext() {
        let properties = Analytics.paywallPurchaseProperties(
            productID: "com.memori.ultra.annual",
            plan: "annual",
            trigger: "onboarding",
            isHighIntent: true,
            isExitOffer: false,
            price: 39.99,
            errorReason: nil
        )

        XCTAssertEqual(properties["product_id"] as? String, "com.memori.ultra.annual")
        XCTAssertEqual(properties["plan"] as? String, "annual")
        XCTAssertEqual(properties["trigger"] as? String, "onboarding")
        XCTAssertEqual(properties["is_high_intent"] as? Bool, true)
        XCTAssertEqual(properties["is_exit_offer"] as? Bool, false)
        XCTAssertEqual(properties["$revenue"] as? Double, 39.99)
        XCTAssertNil(properties["error_reason"])
    }

    func testExitOfferPropertiesIncludeDiscountContext() {
        let properties = Analytics.paywallExitOfferProperties(
            trigger: "onboarding",
            selectedPlan: "annual",
            offerProductID: "com.memori.ultra.annual.firstyear",
            displayedPrice: 29.99,
            regularPrice: 39.99,
            discountLabel: "first_year_offer",
            displayedPriceText: "$29.99",
            regularPriceText: "$39.99"
        )

        XCTAssertEqual(properties["trigger"] as? String, "onboarding")
        XCTAssertEqual(properties["selected_plan"] as? String, "annual")
        XCTAssertEqual(properties["offer_product_id"] as? String, "com.memori.ultra.annual.firstyear")
        XCTAssertEqual(properties["displayed_price"] as? Double, 29.99)
        XCTAssertEqual(properties["regular_price"] as? Double, 39.99)
        XCTAssertEqual(properties["discount_label"] as? String, "first_year_offer")
        XCTAssertEqual(properties["displayed_price_text"] as? String, "$29.99")
        XCTAssertEqual(properties["regular_price_text"] as? String, "$39.99")
        XCTAssertEqual(properties["is_exit_offer"] as? Bool, true)
    }
}

final class OnboardingLifetimeProjectionTests: XCTestCase {
    func testLifetimeReceiptQuestionUsesFreeYearsAndPhoneYears() {
        let projection = OnboardingLifetimeProjection(age: 25, dailyScreenTimeHours: 4)

        XCTAssertEqual(projection.freeYearsBeforePhoneText, "24.8")
        XCTAssertEqual(projection.phoneYearsText, "9.2 years")
        XCTAssertEqual(
            projection.finalQuestion,
            "You have about 24.8 free years left. At this pace, your phone takes 9.2 years of them (37%). Do you really want that?"
        )
    }

    func testLifetimeReceiptQuestionUsesMeasuredWeeklyScreenTimeAverage() {
        let measuredWeeklyHours = 50.2
        let projection = OnboardingLifetimeProjection(age: 25, dailyScreenTimeHours: measuredWeeklyHours / 7)

        XCTAssertEqual(projection.freeYearsBeforePhoneText, "24.8")
        XCTAssertEqual(projection.phoneYearsText, "16.4 years")
        XCTAssertEqual(
            projection.finalQuestion,
            "You have about 24.8 free years left. At this pace, your phone takes 16.4 years of them (66%). Do you really want that?"
        )
    }

    func testLifeReceiptDoublesMemoProtectedPhoneYears() {
        let projection = OnboardingLifetimeProjection(age: 25, dailyScreenTimeHours: 50.2 / 7)
        let model = OnboardingLifeReceiptSquareModel(projection: projection)

        XCTAssertGreaterThanOrEqual(
            Double(model.protectedPhoneCount) / Double(model.phoneCount),
            0.50
        )
    }

    func testScreenTimeProjectionWaitsForAuthorizedDataBeforeUsingEstimateLabel() {
        let pending = OnboardingScreenTimeProjectionState(
            isAuthorized: true,
            useEstimate: false,
            hasMeasuredHours: false,
            estimateFallbackAllowed: false
        )

        XCTAssertTrue(pending.isWaitingForScreenTime)
        XCTAssertFalse(pending.isEstimate)
        XCTAssertFalse(pending.canContinueFromScreenTime)
        XCTAssertEqual(pending.receiptSourceLine, "Reading your Screen Time")

        let measured = OnboardingScreenTimeProjectionState(
            isAuthorized: true,
            useEstimate: false,
            hasMeasuredHours: true,
            estimateFallbackAllowed: false
        )

        XCTAssertFalse(measured.isWaitingForScreenTime)
        XCTAssertFalse(measured.isEstimate)
        XCTAssertTrue(measured.canContinueFromScreenTime)
        XCTAssertEqual(measured.receiptSourceLine, "Using your Screen Time")

        let authorizedTimeout = OnboardingScreenTimeProjectionState(
            isAuthorized: true,
            useEstimate: false,
            hasMeasuredHours: false,
            estimateFallbackAllowed: true
        )

        XCTAssertTrue(authorizedTimeout.isWaitingForScreenTime)
        XCTAssertFalse(authorizedTimeout.isEstimate)
        XCTAssertFalse(authorizedTimeout.canContinueFromScreenTime)
        XCTAssertEqual(authorizedTimeout.receiptSourceLine, "Reading your Screen Time")

        let confirmedEstimate = OnboardingScreenTimeProjectionState(
            isAuthorized: true,
            useEstimate: true,
            hasMeasuredHours: false,
            estimateFallbackAllowed: true
        )

        XCTAssertFalse(confirmedEstimate.isWaitingForScreenTime)
        XCTAssertTrue(confirmedEstimate.isEstimate)
        XCTAssertTrue(confirmedEstimate.canContinueFromScreenTime)
        XCTAssertEqual(confirmedEstimate.receiptSourceLine, "Using your estimate")
    }

    func testScreenTimeAccessCTAAllowsAuthorizedUsersToContinueWhileCacheCatchesUp() {
        let cta = OnboardingScreenTimeAccessButtonState(
            isRequestingAccess: false,
            isPreparingProjection: false,
            isAuthorized: true,
            isWaitingForMeasuredHours: false
        )

        XCTAssertEqual(cta.title, "Show my lifetime cost")
        XCTAssertFalse(cta.isDisabled)
    }

    func testScreenTimeAccessCTABlocksAuthorizedUsersUntilMeasuredHoursArrive() {
        let cta = OnboardingScreenTimeAccessButtonState(
            isRequestingAccess: false,
            isPreparingProjection: false,
            isAuthorized: true,
            isWaitingForMeasuredHours: true
        )

        XCTAssertEqual(cta.title, "Checking Screen Time...")
        XCTAssertTrue(cta.isDisabled)
    }

    func testAuthorizedFallbackStillPollsForMeasuredScreenTime() {
        let state = OnboardingScreenTimeMeasurementState(
            isAuthorized: true,
            useEstimate: false,
            hasMeasuredHours: false
        )

        XCTAssertTrue(state.shouldContinuePollingForMeasuredHours)
    }

    func testManualEstimateDoesNotPollForMeasuredScreenTime() {
        let state = OnboardingScreenTimeMeasurementState(
            isAuthorized: true,
            useEstimate: true,
            hasMeasuredHours: false
        )

        XCTAssertFalse(state.shouldContinuePollingForMeasuredHours)
    }

    func testScreenTimeSnapshotUsesWeeklyAverageBeforeDailyCacheForLifetimeReceipt() {
        let daily = OnboardingScreenTimeSnapshot(dailyHours: 6.25, weeklyHours: 50.2)
        XCTAssertEqual(daily.effectiveDailyHours(fallbackEstimate: 4), 50.2 / 7.0, accuracy: 0.0001)
        XCTAssertFalse(daily.isEstimate)
        XCTAssertEqual(daily.source, .weekly)

        let weeklyOnly = OnboardingScreenTimeSnapshot(dailyHours: nil, weeklyHours: 50.2)
        XCTAssertEqual(weeklyOnly.effectiveDailyHours(fallbackEstimate: 4), 50.2 / 7.0, accuracy: 0.0001)
        XCTAssertFalse(weeklyOnly.isEstimate)
        XCTAssertEqual(weeklyOnly.source, .weekly)

        let staleLatestDayCache = OnboardingScreenTimeSnapshot(dailyHours: 1.2, weeklyHours: 50.2)
        XCTAssertEqual(staleLatestDayCache.effectiveDailyHours(fallbackEstimate: 4), 50.2 / 7.0, accuracy: 0.0001)
        XCTAssertEqual(staleLatestDayCache.source, .weekly)

        let empty = OnboardingScreenTimeSnapshot(dailyHours: nil, weeklyHours: nil)
        XCTAssertEqual(empty.effectiveDailyHours(fallbackEstimate: 4), 4)
        XCTAssertTrue(empty.isEstimate)
        XCTAssertEqual(empty.source, .estimate)
    }

    func testMeasuredWeeklyScreenTimeFormatsDailyAverageInHoursAndMinutes() {
        let measuredWeeklyHours = 50.2

        XCTAssertEqual(
            OnboardingScreenTimeHoursFormatter.dailyLabel(
                hours: measuredWeeklyHours / 7,
                isEstimate: false
            ),
            "7h 10m"
        )
    }

    func testLifetimeReceiptCanContinueOnlyAfterFinalLineFinishes() {
        XCTAssertFalse(OnboardingLifeReceiptProgress.canContinue(stage: 5, receiptFinished: false))
        XCTAssertFalse(OnboardingLifeReceiptProgress.canContinue(stage: 6, receiptFinished: false))
        XCTAssertFalse(OnboardingLifeReceiptProgress.canContinue(stage: OnboardingLifeReceiptBeat.phoneTruth.rawValue, receiptFinished: true))
        XCTAssertFalse(OnboardingLifeReceiptProgress.canContinue(stage: OnboardingLifeReceiptBeat.rescue.rawValue, receiptFinished: false))
        XCTAssertTrue(OnboardingLifeReceiptProgress.canContinue(stage: OnboardingLifeReceiptBeat.rescue.rawValue, receiptFinished: true))
    }

    func testLifeReceiptSquareModelKeepsCostsContiguousAndConserved() {
        let projection = OnboardingLifetimeProjection(age: 25, dailyScreenTimeHours: 50.2 / 7.0)
        let model = OnboardingLifeReceiptSquareModel(projection: projection)

        XCTAssertEqual(model.totalYearsCount, 80)
        XCTAssertEqual(model.yearsAheadCount, 55)
        XCTAssertEqual(
            model.livedCount + model.sleepCount + model.workSchoolCount + model.yourTimeAfterPhoneCount + model.phoneCount,
            model.totalYearsCount
        )
        XCTAssertEqual(model.yourTimeBeforePhoneCount, model.yourTimeAfterPhoneCount + model.phoneCount)

        let costRoles = model.finalCostRoles
        XCTAssertEqual(costRoles.count, 80)
        XCTAssertTrue(costRoles.isContiguous(.lived))
        XCTAssertTrue(costRoles.isContiguous(.sleep))
        XCTAssertTrue(costRoles.isContiguous(.workSchool))
        XCTAssertTrue(costRoles.isContiguous(.yourTime))
        XCTAssertTrue(costRoles.isContiguous(.phone))

        XCTAssertEqual(model.roles(for: .allLife).count, 80)
        XCTAssertTrue(model.roles(for: .yearsAhead).contains(.lived))
        XCTAssertTrue(model.roles(for: .yourTime).contains(.sleep))
        XCTAssertTrue(model.roles(for: .yourTime).contains(.workSchool))
        XCTAssertFalse(model.roles(for: .yourTime).contains(.phone))
        XCTAssertEqual(model.roles(for: .phoneTakeover).filter { $0 == .phone }.count, model.phoneCount)
        XCTAssertEqual(model.roles(for: .phoneTruth).filter { $0 == .phone }.count, model.phoneCount)
        XCTAssertEqual(model.roles(for: .rescue).count, 80)
        XCTAssertEqual(model.roles(for: .rescue).filter { $0 == .phone }.count, model.remainingPhoneCountAfterProtection)
        XCTAssertEqual(model.roles(for: .rescue).filter { $0 == .protectedPhone }.count, model.protectedPhoneCount)
    }

    func testLifeReceiptViewportShrinksToRemainingYearsAfterAge() {
        let projection = OnboardingLifetimeProjection(age: 20, dailyScreenTimeHours: 50.2 / 7.0)
        let model = OnboardingLifeReceiptSquareModel(projection: projection)

        XCTAssertEqual(model.viewportRoles(for: .allLife).count, 80)
        XCTAssertEqual(model.viewportRoles(for: .yearsAhead).count, 60)
        XCTAssertFalse(model.viewportRoles(for: .yearsAhead).contains(.lived))
        XCTAssertEqual(model.viewportRoles(for: .sleepLocked).count, 60)
        XCTAssertLessThan(model.viewportRoles(for: .workSchoolLocked).count, model.viewportRoles(for: .sleepLocked).count)
        XCTAssertEqual(model.viewportRoles(for: .yourTime).count, model.yourTimeBeforePhoneCount)
        XCTAssertEqual(model.viewportRoles(for: .phoneTakeover).count, model.yourTimeBeforePhoneCount)
        XCTAssertEqual(model.viewportRoles(for: .rescue).count, model.yourTimeBeforePhoneCount)
    }

    func testOnboardingMonetizationFlowPlacesTrialBridgeBeforeFinalPlanAndPaywall() {
        XCTAssertEqual(OnboardingFlowOrder.monetizationPages, [.trialTrustBridge, .trialReminderBridge, .planPersonalizing])
        XCTAssertEqual(OnboardingFlowOrder.page(afterScreenTimeAccess: true), .lifetimeShock)
        XCTAssertEqual(OnboardingFlowOrder.page(afterLifetimeShock: true), .lifeSquaresReceipt)
        XCTAssertEqual(OnboardingFlowOrder.page(afterLifeSquaresReceipt: true), .protectTarget)
        XCTAssertEqual(OnboardingFlowOrder.page(afterProtectTarget: true), .feedWinMoment)
        XCTAssertEqual(OnboardingFlowOrder.page(afterFeedWinMoment: true), .personalizationBeat)
        XCTAssertEqual(OnboardingFlowOrder.page(afterPersonalizationBeat: true), .memoPlan)
        XCTAssertEqual(OnboardingFlowOrder.page(afterMemoPlan: true), .trialTrustBridge)
        XCTAssertEqual(OnboardingFlowOrder.page(afterTrialTrustBridge: true), .trialReminderBridge)
        XCTAssertEqual(OnboardingFlowOrder.page(afterTrialReminderBridge: true), .planPersonalizing)
        XCTAssertEqual(OnboardingFlowOrder.page(afterPaywallConverted: true), .focusMode)
        XCTAssertEqual(Analytics.onboardingStepName(for: OnboardingPage.protectTarget.rawValue), "protectTarget")
        XCTAssertEqual(Analytics.onboardingStepName(for: OnboardingPage.feedWinMoment.rawValue), "feedWinMoment")
        XCTAssertEqual(Analytics.onboardingStepName(for: OnboardingPage.personalizationBeat.rawValue), "personalizationBeat")
        XCTAssertEqual(Analytics.onboardingStepName(for: OnboardingPage.lifetimeShock.rawValue), "lifetimeShock")
        XCTAssertEqual(Analytics.onboardingStepName(for: OnboardingPage.trialTrustBridge.rawValue), "trialTrustBridge")
        XCTAssertEqual(Analytics.onboardingStepName(for: OnboardingPage.trialReminderBridge.rawValue), "trialReminderBridge")
        XCTAssertEqual(Analytics.onboardingStepName(for: OnboardingPage.planPersonalizing.rawValue), "planPersonalizing")
    }
}

private extension Array where Element == OnboardingLifeReceiptSquareRole {
    func isContiguous(_ role: OnboardingLifeReceiptSquareRole) -> Bool {
        let matchingIndices = indices.filter { self[$0] == role }
        guard let first = matchingIndices.first, let last = matchingIndices.last else { return true }
        return matchingIndices == Swift.Array(first...last)
    }
}

final class FocusUnlockSlotTests: XCTestCase {
    func testFocusUnlockSlotCopyStaysShortAndNative() {
        XCTAssertEqual(FocusUnlockSlotCopy.eyebrow, "BLOCKED APP TRIED IT")
        XCTAssertEqual(FocusUnlockSlotCopy.headline, "NO FEED TIL YOU TRAIN")
        XCTAssertEqual(FocusUnlockSlotCopy.subhead, "spin for your brain game.")
        XCTAssertEqual(FocusUnlockSlotCopy.idleStatus, "tap when you're ready")
        XCTAssertEqual(FocusUnlockSlotCopy.spinningStatus, "MEMO'S PICKING")
        XCTAssertEqual(FocusUnlockSlotCopy.footer, "one spin. one game. back in.")
        XCTAssertEqual(FocusUnlockSlotCopy.landedStatus(for: TrainingGameCatalog.focusUnlockGames.first), "NUMBER MEMORY. YOU'RE COOKED.")
    }

    func testFocusUnlockCatalogMatchesVisibleTrainGames() {
        let games = TrainingGameCatalog.focusUnlockGames

        XCTAssertEqual(games.map(\.type), [
            .sequentialMemory,
            .visualMemory,
            .chunkingTraining,
            .verbalMemory,
            .reactionTime,
            .mathSpeed,
            .speedMatch,
            .colorMatch,
            .dualNBack,
            .chimpTest,
        ])
        XCTAssertEqual(games.map(\.title), [
            "Number Memory",
            "Visual Memory",
            "Chunking",
            "Verbal Memory",
            "Reaction Time",
            "Math Speed",
            "Speed Match",
            "Color Match",
            "Dual N-Back",
            "Chimp Test",
        ])
    }

    func testFocusUnlockCompletionGateOnlyGrantsForSelectedGame() {
        XCTAssertTrue(
            FocusUnlockCompletionGate.shouldGrant(
                completedGameRawValue: ExerciseType.colorMatch.rawValue,
                expectedGame: .colorMatch
            )
        )

        XCTAssertFalse(
            FocusUnlockCompletionGate.shouldGrant(
                completedGameRawValue: ExerciseType.reactionTime.rawValue,
                expectedGame: .colorMatch
            )
        )

        XCTAssertFalse(
            FocusUnlockCompletionGate.shouldGrant(
                completedGameRawValue: ExerciseType.colorMatch.rawValue,
                expectedGame: nil
            )
        )

        XCTAssertFalse(
            FocusUnlockCompletionGate.shouldGrant(
                completedGameRawValue: "not-a-game",
                expectedGame: .colorMatch
            )
        )
    }
}
