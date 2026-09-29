import XCTest

final class PostDecodingTests: XCTestCase {
    func testPrefersAuthorUidThenLegacyFields() {
        XCTAssertEqual(Post(id: "1", data: ["authorUid": "a", "userId": "b", "user": "c"]).authorUid, "a")
        XCTAssertEqual(Post(id: "1", data: ["userId": "b", "user": "c"]).authorUid, "b")
        XCTAssertEqual(Post(id: "1", data: ["user": "c"]).authorUid, "c")
    }

    func testTODDPostsAreSystemPostsWithNoAuthor() {
        let post = Post(id: "1", data: ["user": "TODD", "content": "Hello"])
        XCTAssertTrue(post.isSystemPost)
        XCTAssertNil(post.authorUid)
        XCTAssertEqual(post.displayName, "TODD")
    }

    func testDefaultsForMissingFields() {
        let post = Post(id: "1", data: [:])
        XCTAssertEqual(post.displayName, "User")
        XCTAssertEqual(post.category, "all")
        XCTAssertEqual(post.favoriteCount, 0)
        XCTAssertNil(post.linkPreview)
        XCTAssertFalse(post.needsContentWarning)
    }

    func testHiddenOrSuspendedPostsAreHidden() {
        XCTAssertTrue(Post(id: "1", data: ["hidden": true]).isHidden)
        XCTAssertTrue(Post(id: "1", data: ["suspended": true]).isHidden)
    }

    func testContentWarningFromRatingFourUp() {
        XCTAssertFalse(Post(id: "1", data: ["contentRating": 3]).needsContentWarning)
        XCTAssertTrue(Post(id: "1", data: ["contentRating": 4]).needsContentWarning)
        XCTAssertTrue(Post(id: "1", data: ["contentRating": "5"]).needsContentWarning)
    }

    func testLinkPreviewIgnoredWhenEmpty() {
        XCTAssertNil(Post(id: "1", data: ["linkPreview": ["description": "only"]]).linkPreview)
        XCTAssertEqual(Post(id: "1", data: ["linkPreview": ["url": "https://a.com", "title": "A"]]).linkPreview?.title, "A")
    }

    func testTimestampFormats() {
        let date = Date(timeIntervalSince1970: 1_700_000_000)
        XCTAssertEqual(Post(id: "1", data: ["timestamp": date]).timestamp, date)
        XCTAssertEqual(Post(id: "1", data: ["timestamp": "2023-11-14T22:13:20.000Z"]).timestamp, date)
        XCTAssertEqual(Post(id: "1", data: ["timestamp": "2023-11-14T22:13:20Z"]).timestamp, date)
        XCTAssertEqual(Post(id: "1", data: ["timestamp": 1_700_000_000_000]).timestamp, date)
        XCTAssertEqual(Post(id: "1", data: ["timestamp": ["seconds": 1_700_000_000]]).timestamp, date)
    }
}

final class OtherModelTests: XCTestCase {
    func testCommentFallsBackToParentPostId() {
        let comment = Comment(id: "c", postId: "p", data: ["content": "Hi", "authorUid": "u"])
        XCTAssertEqual(comment.postId, "p")
        XCTAssertEqual(comment.authorDisplayName, "User")
    }

    func testInterestDecoding() {
        let interest = Interest(id: "i", data: ["postId": "p", "interestedDisplayName": "Ada", "viewed": false, "createdAt": "2026-01-01T00:00:00.000Z"])
        XCTAssertEqual(interest.interestedDisplayName, "Ada")
        XCTAssertFalse(interest.viewed)
        XCTAssertNotNil(interest.createdAt)
    }

    func testProfileReadsLegacyFieldNames() {
        let profile = SayItProfile(uid: "u", data: ["companyName": "Acme", "industry": "Retail", "sellText": "We sell things", "blockedUids": ["x", "y"]])
        XCTAssertEqual(profile.businessName, "Acme")
        XCTAssertEqual(profile.businessCategory, "Retail")
        XCTAssertEqual(profile.intentText, "We sell things")
        XCTAssertEqual(profile.blockedUids, ["x", "y"])
    }
}
