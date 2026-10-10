import XCTest

final class LinkPreviewTests: XCTestCase {
    func testReadsYouTubeAndVimeoLinks() {
        XCTAssertEqual(PostVideo(url: "https://youtu.be/qYIL-F9XvGg?is=6dYc_NrowHKswR_j"), PostVideo(provider: .youtube, id: "qYIL-F9XvGg"))
        XCTAssertEqual(PostVideo(url: "https://m.youtube.com/watch?v=qYIL-F9XvGg&t=3"), PostVideo(provider: .youtube, id: "qYIL-F9XvGg"))
        XCTAssertEqual(PostVideo(url: "https://www.youtube.com/shorts/qYIL-F9XvGg"), PostVideo(provider: .youtube, id: "qYIL-F9XvGg"))
        XCTAssertEqual(PostVideo(url: "https://vimeo.com/1084537"), PostVideo(provider: .vimeo, id: "1084537"))
    }

    func testDoesNotPlayTikTokOrOtherLinks() {
        XCTAssertNil(PostVideo(url: "https://www.tiktok.com/@a/video/7234567890123456789"))
        XCTAssertNil(PostVideo(url: "https://www.espn.com/nfl/story/_/id/50136406/x"))
        XCTAssertNil(PostVideo(url: nil))
    }

    func testReadsTheServersPreview() {
        let post = Post(id: "p", data: [
            "content": "https://youtu.be/qYIL-F9XvGg",
            "linkPreview": ["url": "https://youtu.be/qYIL-F9XvGg", "title": "Why the deal worries us", "siteName": "YouTube",
                            "video": ["provider": "youtube", "id": "qYIL-F9XvGg"]],
        ])
        XCTAssertEqual(post.linkPreview?.siteName, "YouTube")
        XCTAssertEqual(post.linkVideo, PostVideo(provider: .youtube, id: "qYIL-F9XvGg"))
        XCTAssertEqual(post.headline, "Why the deal worries us", "A bare link shows the page's title")
        XCTAssertEqual(post.imageURL, "https://i.ytimg.com/vi/qYIL-F9XvGg/hqdefault.jpg", "Falls back to the video thumbnail")
    }

    func testKeepsWhatThePersonWroteWithoutTheLink() {
        let preview = LinkPreview(title: "Bucs win", url: "https://espn.com/a")
        XCTAssertEqual(Post(id: "p", content: "Go Bucs! https://espn.com/a", linkPreview: preview).headline, "Go Bucs!")
        XCTAssertEqual(Post(id: "p", content: "Read this (https://espn.com/a).", linkPreview: preview).textWithoutLink, "Read this.")
        XCTAssertEqual(Post(id: "p", content: "https://espn.com/a").headline, "https://espn.com/a", "Unchanged until the preview arrives")
    }

    func testHeadlineThatIsOnlyALinkShowsTheVideoTitle() {
        // The composer saves a separate title; pasting a YouTube link there
        // used to show the raw URL above its own preview card.
        let link = "https://youtu.be/XsIG1Dp2fNs?si=tqidJ0pqYWIvea07"
        let post = Post(id: "p", data: [
            "content": link, "title": link,
            "linkPreview": ["url": link, "title": "Barack Obama Being Hilarious", "siteName": "YouTube",
                            "image": "https://i.ytimg.com/vi/XsIG1Dp2fNs/hqdefault.jpg",
                            "video": ["provider": "youtube", "id": "XsIG1Dp2fNs"]],
        ])
        XCTAssertEqual(post.headline, "Barack Obama Being Hilarious")
        XCTAssertEqual(post.imageURL, "https://i.ytimg.com/vi/XsIG1Dp2fNs/hqdefault.jpg")
    }

    func testHeadlineKeepsTheWordsAroundALink() {
        let post = Post(id: "p", data: [
            "content": "Watch this https://youtu.be/XsIG1Dp2fNs", "title": "Watch this https://youtu.be/XsIG1Dp2fNs",
            "caption": "Details at https://espn.com/a",
        ])
        XCTAssertEqual(post.headline, "Watch this", "A playable video hides the URL even before the preview arrives")
        XCTAssertEqual(post.body, "Details at https://espn.com/a", "Only the first link is a card; others stay")
    }

    func testPlainLinkStaysVisibleUntilItHasAPreview() {
        let post = Post(id: "p", data: ["content": "See https://espn.com/a", "title": "See https://espn.com/a"])
        XCTAssertEqual(post.headline, "See https://espn.com/a")
    }

    func testLinksDontCountTowardTheComposerLimits() {
        let longLink = "https://www.usatoday.com/story/entertainment/celebrities/2026/10/09/halle-berry-daughter/92173323007/"
        XCTAssertEqual(Post.visibleLength(of: longLink), 0)
        XCTAssertEqual(Post.visibleLength(of: "Worth a read \(longLink)"), "Worth a read".count)
        XCTAssertEqual(Post.visibleLength(of: "No link here"), 12)
    }

    func testSearchFindsALinkPostByItsPreviewTitle() {
        let post = Post(id: "p", content: "https://youtu.be/XsIG1Dp2fNs",
                        linkPreview: LinkPreview(title: "Barack Obama Being Hilarious", url: "https://youtu.be/XsIG1Dp2fNs", siteName: "YouTube"))
        XCTAssertEqual(FeedFilter(searchText: "obama").apply(to: [post]).map(\.id), ["p"])
        XCTAssertEqual(FeedFilter(searchText: "youtube").apply(to: [post]).map(\.id), ["p"])
    }

    func testSearchFindsAPhotoByWhatsInIt() {
        let post = Post(id: "p", data: ["content": "The morning Start", "title": "The morning Start",
                                        "postImageUrl": "https://example.com/a.jpg",
                                        "imageDescription": "A cup of coffee topped with whipped cream.",
                                        "imageKeywords": ["coffee", "beverage"]])
        XCTAssertEqual(FeedFilter(searchText: "coffee").apply(to: [post]).map(\.id), ["p"])
        XCTAssertEqual(FeedFilter(searchText: "beverage").apply(to: [post]).map(\.id), ["p"])
    }

    func testPostsRemovedByModerationAreHidden() {
        // Moderation wrote only `isHidden` before 2026-10-10.
        XCTAssertTrue(Post(id: "p", data: ["content": "x", "isHidden": true]).isHidden)
        XCTAssertTrue(Post(id: "p", data: ["content": "x", "hidden": true]).isHidden)
        XCTAssertTrue(FeedFilter().apply(to: [Post(id: "p", data: ["content": "x", "isHidden": true])]).isEmpty)
    }
}
