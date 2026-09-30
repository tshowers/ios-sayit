import XCTest

final class FeedPagingTests: XCTestCase {
    func testSixtyPointDragPages() {
        XCTAssertEqual(FeedPaging.index(after: -61, from: 1, count: 5), 2)
        XCTAssertEqual(FeedPaging.index(after: 61, from: 1, count: 5), 0)
        XCTAssertEqual(FeedPaging.index(after: -59, from: 1, count: 5), 1, "Below the threshold snaps back")
    }

    func testStopsAtTheEnds() {
        XCTAssertEqual(FeedPaging.index(after: 200, from: 0, count: 5), 0)
        XCTAssertEqual(FeedPaging.index(after: -200, from: 4, count: 5), 4)
        XCTAssertEqual(FeedPaging.index(after: -200, from: 0, count: 0), 0)
    }

    func testRubberBandsPastTheEnds() {
        XCTAssertEqual(FeedPaging.offset(for: 100, at: 0, count: 5), 30)
        XCTAssertEqual(FeedPaging.offset(for: -100, at: 4, count: 5), -30)
        XCTAssertEqual(FeedPaging.offset(for: -100, at: 2, count: 5), -100)
    }
}

final class FormattingTests: XCTestCase {
    func testCounts() {
        XCTAssertEqual(Formatting.count(999), "999")
        XCTAssertEqual(Formatting.count(1000), "1k")
        XCTAssertEqual(Formatting.count(1250), "1.2k")
        XCTAssertEqual(Formatting.count(12_400), "12k")
    }

    func testNames() {
        XCTAssertEqual(Formatting.firstName("Jane Doe"), "Jane")
        XCTAssertEqual(Formatting.firstName("Morgan at EcoPack Pros"), "Morgan")
        XCTAssertEqual(Formatting.initials("Jane Doe"), "JD")
        XCTAssertEqual(Formatting.initials("Morgan at EcoPack Pros"), "M")
    }

    func testPostKindReadsWebAndLegacyValues() {
        XCTAssertEqual(PostKind(stored: "selling"), .selling)
        XCTAssertEqual(PostKind(stored: "looking_for"), .lookingFor)
        XCTAssertEqual(PostKind(stored: "buying"), .lookingFor)
        XCTAssertNil(PostKind(stored: "event"))
    }
}

final class PostDesignFieldTests: XCTestCase {
    func testNewPostsSplitTitleAndCaption() {
        let post = Post(id: "1", data: ["content": "Free clinic. Bring your phone.", "title": "Free clinic", "caption": "Bring your phone.", "kind": "selling", "price": "$18 each"])
        XCTAssertEqual(post.headline, "Free clinic")
        XCTAssertEqual(post.body, "Bring your phone.")
        XCTAssertEqual(post.kind, .selling)
        XCTAssertEqual(post.price, "$18 each")
    }

    func testOlderPostsUseContentAsTheHeadline() {
        let post = Post(id: "1", data: ["content": "Need a plumber", "displayName": "Morgan at EcoPack Pros"])
        XCTAssertEqual(post.headline, "Need a plumber")
        XCTAssertNil(post.body)
        XCTAssertTrue(post.isTextOnly)
        XCTAssertEqual(post.personName, "Morgan")
        XCTAssertEqual(post.orgLabel, "EcoPack Pros")
    }

    func testOrgFieldWinsAndLikesCountBothFields() {
        let post = Post(id: "1", data: ["displayName": "Jane Doe", "orgName": "AT&T", "favoriteCount": 2, "favoriteUserIds": ["a", "b", "c"], "postImageUrl": "https://x/y.jpg"])
        XCTAssertEqual(post.orgLabel, "AT&T")
        XCTAssertEqual(post.likeCount, 3)
        XCTAssertFalse(post.isTextOnly)
    }

    func testProfileReadsJobTitleAndLayout() {
        let profile = SayItProfile(uid: "u", data: ["jobTitle": "Community Manager", "role": "admin", "feedLayout": "1c", "favoritePostIds": ["p1"]])
        XCTAssertEqual(profile.role, "Community Manager", "The permission `role` field is never used as a job title")
        XCTAssertEqual(profile.feedLayout, .ribbon)
        XCTAssertEqual(profile.favoritePostIds, ["p1"])
    }
}

final class OrgDirectoryTests: XCTestCase {
    private func profile(_ uid: String, _ business: String, city: String = "", category: String = "") -> SayItProfile {
        var p = SayItProfile(uid: uid)
        p.businessName = business
        p.location = city
        p.businessCategory = category
        return p
    }

    func testGroupsPeopleByBusinessName() {
        let orgs = OrgDirectory.orgs(from: [
            profile("a", "AT&T", city: "Dallas, TX", category: "Telecom"),
            profile("b", "at&t "),
            profile("c", "Kettle & Co. Bakery"),
            profile("d", ""),
        ])
        XCTAssertEqual(orgs.map(\.id), ["at-t", "kettle-co-bakery"])
        XCTAssertEqual(orgs[0].memberUids, ["a", "b"])
        XCTAssertEqual(orgs[0].city, "Dallas, TX")
    }

    func testColorIsStablePerName() {
        XCTAssertEqual(OrgDirectory.colorIndex(for: "AT&T"), OrgDirectory.colorIndex(for: " at&t"))
        XCTAssertTrue((0..<OrgDirectory.paletteSize).contains(OrgDirectory.colorIndex(for: "Greenleaf")))
    }

    func testSearchesNameCategoryAndCity() {
        let orgs = OrgDirectory.orgs(from: [profile("a", "Riverbend Coffee", city: "Austin, TX", category: "Food & drink"), profile("b", "Halden Architects", city: "Houston, TX")])
        XCTAssertEqual(OrgDirectory.search(orgs, "austin").map(\.name), ["Riverbend Coffee"])
        XCTAssertEqual(OrgDirectory.search(orgs, "archit").map(\.name), ["Halden Architects"])
        XCTAssertEqual(OrgDirectory.search(orgs, " ").count, 2)
    }
}

final class InboxRulesTests: XCTestCase {
    private func thread(_ id: String, author: String, interested: String, at seconds: TimeInterval, unread: [String: Int] = [:]) -> ChatThread {
        ChatThread(id: id, postId: id, postTitle: "", authorUid: author, interestedUid: interested, lastMessageAt: Date(timeIntervalSince1970: seconds), unread: unread)
    }

    func testFiltersByDirectionNewestFirst() {
        let threads = [thread("a", author: "x", interested: "me", at: 1), thread("b", author: "me", interested: "y", at: 3, unread: ["me": 2]), thread("c", author: "z", interested: "me", at: 2)]
        XCTAssertEqual(InboxRules.filter(threads, .all, me: "me").map(\.id), ["b", "c", "a"])
        XCTAssertEqual(InboxRules.filter(threads, .mine, me: "me").map(\.id), ["c", "a"])
        XCTAssertEqual(InboxRules.filter(threads, .theirs, me: "me").map(\.id), ["b"])
        XCTAssertEqual(InboxRules.unreadThreads(threads, me: "me"), 1)
    }

    func testThreadIdAndDirection() {
        XCTAssertEqual(ChatThread.id(postId: "p1", interestedUid: "bob"), "p1_bob")
        let t = thread("p1_bob", author: "alice", interested: "bob", at: 0)
        XCTAssertTrue(t.isMine(me: "bob"))
        XCTAssertEqual(t.otherUid(me: "bob"), "alice")
        XCTAssertEqual(t.otherUid(me: "alice"), "bob")
    }

    func testDecodesThreadFromFirestore() {
        let t = ChatThread(id: "p1_bob", data: ["postId": "p1", "authorUid": "alice", "interestedUid": "bob", "postKind": "selling",
                                                 "people": ["alice": ["name": "Alice", "org": "Greenleaf"]], "unread": ["bob": 2]])
        XCTAssertEqual(t.postKind, .selling)
        XCTAssertEqual(t.other(me: "bob").org, "Greenleaf")
        XCTAssertEqual(t.unreadCount(for: "bob"), 2)
        XCTAssertTrue(t.interestActive)
    }

    func testEmailsOnlyOnTheFirstUnread() {
        XCTAssertTrue(InboxRules.shouldEmail(recipientUnreadBefore: 0))
        XCTAssertFalse(InboxRules.shouldEmail(recipientUnreadBefore: 1))
    }

    func testTailOnTheLastBubbleOfARun() {
        let messages = [ChatMessage(id: "1", senderUid: "a", text: ""), ChatMessage(id: "2", senderUid: "a", text: ""), ChatMessage(id: "3", senderUid: "b", text: "")]
        XCTAssertFalse(InboxRules.isLastInRun(messages, at: 0))
        XCTAssertTrue(InboxRules.isLastInRun(messages, at: 1))
        XCTAssertTrue(InboxRules.isLastInRun(messages, at: 2))
    }
}
