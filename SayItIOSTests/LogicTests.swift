import XCTest

final class FeedFilterTests: XCTestCase {
    private let posts = [
        Post(id: "1", authorUid: "a", displayName: "Ada", content: "Need a plumber", category: "construction"),
        Post(id: "2", authorUid: "b", displayName: "Bo", content: "Selling trucks", category: "automotive"),
        Post(id: "3", authorUid: "c", content: "hidden", isHidden: true),
        Post(id: "4", authorUid: "d", content: "offensive", contentRating: 6),
        Post(id: "5", authorUid: "e", content: "edgy but allowed", contentRating: 5),
    ]

    func testDropsHiddenAndOffensivePosts() {
        XCTAssertEqual(FeedFilter().apply(to: posts).map(\.id), ["1", "2", "5"])
    }

    func testDropsBlockedAuthors() {
        XCTAssertEqual(FeedFilter(blockedUids: ["a"]).apply(to: posts).map(\.id), ["2", "5"])
    }

    func testCategoryFilter() {
        XCTAssertEqual(FeedFilter(category: "Automotive").apply(to: posts).map(\.id), ["2"])
        XCTAssertEqual(FeedFilter(category: "all").apply(to: posts).count, 3)
    }

    func testSearchMatchesContentAndName() {
        XCTAssertEqual(FeedFilter(searchText: " PLUMBER ").apply(to: posts).map(\.id), ["1"])
        XCTAssertEqual(FeedFilter(searchText: "bo").apply(to: posts).map(\.id), ["2"])
    }
}

final class DraftTests: XCTestCase {
    func testPostLengthLimit() {
        XCTAssertFalse(PostDraft.canPost("   "))
        XCTAssertTrue(PostDraft.canPost(String(repeating: "a", count: 155)))
        XCTAssertFalse(PostDraft.canPost(String(repeating: "a", count: 156)))
        XCTAssertEqual(PostDraft.remaining("  abc  "), 152)
    }

    func testCommentIsTrimmedAndCapped() {
        XCTAssertFalse(CommentDraft.canSend(" \n "))
        XCTAssertEqual(CommentDraft.cleaned(String(repeating: "x", count: 600)).count, 500)
    }
}

final class ModerationTests: XCTestCase {
    func testParsesPlainJSON() {
        let result = Moderation.parse(#"{"displayName":"x","category":"retail","rating":2,"explanation":"Mild"}"#, fallbackCategory: "all")
        XCTAssertEqual(result, Moderation.Result(rating: 2, explanation: "Mild", category: "retail"))
    }

    func testParsesFencedJSONAndClampsRating() {
        let result = Moderation.parse("```json\n{\"rating\": 9, \"category\": \"retail\"}\n```", fallbackCategory: "all")
        XCTAssertEqual(result?.rating, 6)
        XCTAssertEqual(result?.explanation, "No issues detected.")
    }

    func testUnknownCategoryFallsBack() {
        XCTAssertEqual(Moderation.parse(#"{"rating":1,"category":"space-travel"}"#, fallbackCategory: "technology")?.category, "technology")
    }

    func testUnreadableResponseReturnsNil() {
        XCTAssertNil(Moderation.parse("Sorry, I can't help with that.", fallbackCategory: "all"))
    }

    func testPromptIncludesMessageAndCategory() {
        let prompt = Moderation.prompt(content: "Hello\n  world", category: "retail")
        XCTAssertTrue(prompt.contains("The user chose the retail."))
        XCTAssertTrue(prompt.hasSuffix("Message: \"Hello world\"."))
    }
}

final class PostLinksTests: XCTestCase {
    private let base = URL(string: "https://sayit.taliferro.tech")!

    func testBuildsPostURL() {
        XCTAssertEqual(PostLinks.url(forPostId: "abc", base: base).absoluteString, "https://sayit.taliferro.tech/post/abc")
    }

    func testReadsPostLinks() {
        XCTAssertEqual(PostLinks.postId(from: URL(string: "https://sayit.taliferro.tech/post/abc")!), "abc")
        XCTAssertEqual(PostLinks.postId(from: URL(string: "https://todd-sayit.web.app/post/abc?utm=1")!), "abc")
        XCTAssertEqual(PostLinks.postId(from: URL(string: "https://sayit.taliferro.tech/?post=old")!), "old")
    }

    func testIgnoresOtherLinks() {
        XCTAssertNil(PostLinks.postId(from: URL(string: "https://sayit.taliferro.tech/businesses")!))
        XCTAssertNil(PostLinks.postId(from: URL(string: "https://example.com/post/abc")!))
        XCTAssertNil(PostLinks.postId(from: URL(string: "https://sayit.taliferro.tech/post/")!))
    }
}

final class ProfileValidationTests: XCTestCase {
    private func profile(name: String = "Ada", intent: String = "Bookkeeping for trades", website: String = "") -> SayItProfile {
        var profile = SayItProfile(uid: "u")
        profile.displayName = name
        profile.intentText = intent
        profile.websiteURL = website
        return profile
    }

    func testValidProfile() {
        XCTAssertNil(ProfileValidation.validate(profile()))
        XCTAssertTrue(profile().isComplete)
    }

    func testNameAndIntentRules() {
        XCTAssertEqual(ProfileValidation.validate(profile(name: " ")), "Please enter a display name.")
        XCTAssertEqual(ProfileValidation.validate(profile(name: "A")), "Display name must be at least 2 characters.")
        XCTAssertEqual(ProfileValidation.validate(profile(intent: "")), "Please tell people what you do or need.")
        XCTAssertNotNil(ProfileValidation.validate(profile(intent: "short")))
    }

    func testWebsiteNormalization() {
        XCTAssertEqual(ProfileValidation.normalizedWebsite("taliferro.com"), "https://taliferro.com")
        XCTAssertEqual(ProfileValidation.normalizedWebsite("http://a.io/x"), "http://a.io/x")
        XCTAssertEqual(ProfileValidation.normalizedWebsite(""), "")
        XCTAssertNil(ProfileValidation.normalizedWebsite("not a site"))
        XCTAssertNotNil(ProfileValidation.validate(profile(website: "nope")))
    }
}

final class CategoryTests: XCTestCase {
    func testLabels() {
        XCTAssertEqual(PostCategory.label(for: "all"), "Everything")
        XCTAssertEqual(PostCategory.label(for: "trucking-logistics"), "Trucking Logistics")
    }
}
