import XCTest

final class OnboardingDraftTests: XCTestCase {
    func testStartsWithEverythingPreselected() {
        let draft = OnboardingDraft()
        XCTAssertEqual(draft.intent, .looking)
        XCTAssertEqual(draft.topic, "A supplier")
        XCTAssertEqual(draft.category, "all")
        XCTAssertEqual(draft.postText, "Looking for a supplier. Any recommendations?")
        XCTAssertFalse(draft.isReadyToSubmit)
    }

    func testPostFollowsTheAnswersUntilEdited() {
        var draft = OnboardingDraft()
        draft.select(intent: .offering)
        XCTAssertEqual(draft.topic, "My services")
        draft.category = "trucking-logistics"
        draft.refreshSuggestedPost()
        XCTAssertEqual(draft.postText, "Offering my services in trucking logistics. Happy to help - reach out!")

        draft.postText = "My own words"
        draft.postTextEdited = true
        draft.topic = "Referrals"
        draft.refreshSuggestedPost()
        XCTAssertEqual(draft.postText, "My own words")
    }

    func testCustomTopicAndLengthCap() {
        var draft = OnboardingDraft()
        draft.topic = String(repeating: "x", count: 300)
        XCTAssertTrue(draft.hasCustomTopic)
        XCTAssertEqual(draft.suggestedPost.count, PostDraft.maxLength)
    }

    func testDisplayNameAndProfile() {
        var draft = OnboardingDraft()
        draft.firstName = "Ada"
        draft.lastName = "Lovelace"
        XCTAssertEqual(draft.displayName, "Ada Lovelace")
        draft.businessName = "Analytical Co"
        draft.category = "retail"
        XCTAssertEqual(draft.displayName, "Ada at Analytical Co")

        let profile = draft.profile(uid: "u1")
        XCTAssertEqual(profile.displayName, "Ada at Analytical Co")
        XCTAssertEqual(profile.businessName, "Analytical Co")
        XCTAssertEqual(profile.businessCategory, "Retail")
        XCTAssertTrue(profile.isComplete)
    }

    func testToddProfileBodyNeverWritesRole() {
        var draft = OnboardingDraft()
        draft.firstName = " Ada "
        let profile = draft.toddProfileRequestBody["profile"] as? [String: String]
        XCTAssertEqual(profile?["firstName"], "Ada")
        XCTAssertNil(profile?["role"])
        XCTAssertEqual(draft.toddProfileRequestBody["source"] as? String, "sayit-ios")
    }

    func testPersistsAcrossLaunches() {
        let defaults = UserDefaults(suiteName: "OnboardingDraftTests")!
        defaults.removePersistentDomain(forName: "OnboardingDraftTests")
        var draft = OnboardingDraft()
        draft.topic = "Referrals"
        draft.isReadyToSubmit = true
        draft.save(to: defaults)
        XCTAssertEqual(OnboardingDraft.load(from: defaults), draft)
        OnboardingDraft.clear(from: defaults)
        XCTAssertEqual(OnboardingDraft.load(from: defaults), OnboardingDraft())
    }
}

final class SayItAwardRulesTests: XCTestCase {
    private let calendar = Calendar(identifier: .gregorian)
    private func day(_ n: Int, hour: Int = 12) -> Date {
        calendar.date(from: DateComponents(year: 2026, month: 9, day: n, hour: hour))!
    }

    func testNothingForANewAccount() {
        XCTAssertEqual(SayItAwardRules.qualifying(.init(), calendar: calendar), [])
    }

    func testFirstPostProfileAndInterest() {
        let stats = SayItAwardRules.Stats(postDates: [day(1)], interestReceived: 1, profileComplete: true)
        XCTAssertEqual(SayItAwardRules.qualifying(stats, calendar: calendar), ["on-the-record", "open-for-business", "wanted"])
    }

    func testInDemandAtFiveInterested() {
        let ids = SayItAwardRules.qualifying(.init(postDates: [day(1)], interestReceived: 5), calendar: calendar)
        XCTAssertTrue(ids.contains("in-demand"))
    }

    func testRegularNeedsThreeDifferentDays() {
        let sameDay = [day(1, hour: 9), day(1, hour: 15), day(1, hour: 20)]
        XCTAssertFalse(SayItAwardRules.qualifying(.init(postDates: sameDay), calendar: calendar).contains("regular"))
        let threeDays = [day(1), day(3), day(9)]
        XCTAssertTrue(SayItAwardRules.qualifying(.init(postDates: threeDays), calendar: calendar).contains("regular"))
    }

    func testLegendAtTwentyFivePosts() {
        let posts = (1...25).map { _ in day(2) }
        XCTAssertTrue(SayItAwardRules.qualifying(.init(postDates: posts), calendar: calendar).contains("legend"))
    }
}
