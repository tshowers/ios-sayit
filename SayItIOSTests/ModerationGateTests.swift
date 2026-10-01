import XCTest

/// App Store guideline 1.2: content is checked before it's posted, and a
/// person can take a post out of their own feed immediately.
final class ModerationGateTests: XCTestCase {
    func testRefusesToPublishWhenTheCheckCannotRun() {
        XCTAssertThrowsError(try ModerationError.check(nil)) { error in
            XCTAssertEqual(error as? ModerationError, .unavailable)
        }
    }

    func testRefusesHighlyInappropriateAndOffensiveContent() {
        for rating in [5, 6] {
            XCTAssertThrowsError(try ModerationError.check(.init(rating: rating, explanation: "slur", category: "all"))) { error in
                XCTAssertEqual(error as? ModerationError, .rejected("slur"))
            }
        }
    }

    func testLetsAcceptableContentThrough() throws {
        for rating in 1...4 {
            XCTAssertEqual(try ModerationError.check(.init(rating: rating, explanation: "", category: "all")).rating, rating)
        }
    }

    func testHiddenPostsLeaveTheFeedImmediately() {
        let posts = [Post(id: "1", authorUid: "a", content: "keep"), Post(id: "2", authorUid: "b", content: "hide me")]
        let visible = FeedFilter(hiddenPostIds: ["2"]).apply(to: posts)
        XCTAssertEqual(visible.map(\.id), ["1"])
    }
}
