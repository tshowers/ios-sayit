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
}
