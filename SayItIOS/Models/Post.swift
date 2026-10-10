import Foundation

/// Saved on a post by the backend's posts trigger when the post has a link
/// (todd-backend sayit/linkPreview.service.js), so the app shows a card
/// instead of a bare URL.
struct LinkPreview: Equatable, Hashable {
    var title: String?
    var description: String?
    var url: String?
    var image: String?
    /// "YouTube", "ESPN.com"...
    var siteName: String?
    /// YouTube and Vimeo links, which play in place.
    var video: PostVideo?
}

/// A YouTube or Vimeo video a post links to. TikTok isn't played in place;
/// it shows as an ordinary link.
struct PostVideo: Identifiable, Equatable, Hashable {
    enum Provider: String { case youtube, vimeo }

    let provider: Provider
    let id: String

    init(provider: Provider, id: String) {
        self.provider = provider
        self.id = id
    }

    /// Reads the video from a link, as the backend does.
    init?(url string: String?) {
        guard let string, let url = URL(string: string), let rawHost = url.host?.lowercased() else { return nil }
        let host = rawHost.replacingOccurrences(of: #"^(www\.|m\.|music\.)"#, with: "", options: .regularExpression)
        let segments = url.path.split(separator: "/").map(String.init)
        let query = URLComponents(url: url, resolvingAgainstBaseURL: false)?.queryItems ?? []

        if host == "youtu.be", let first = segments.first, Self.isYouTubeId(first) {
            self.init(provider: .youtube, id: first)
        } else if host == "youtube.com" || host == "youtube-nocookie.com" {
            if let v = query.first(where: { $0.name == "v" })?.value, Self.isYouTubeId(v) {
                self.init(provider: .youtube, id: v)
            } else if segments.count > 1, ["shorts", "embed", "live", "v"].contains(segments[0]), Self.isYouTubeId(segments[1]) {
                self.init(provider: .youtube, id: segments[1])
            } else {
                return nil
            }
        } else if host == "vimeo.com" || host == "player.vimeo.com",
                  let id = segments.first(where: { $0.count >= 6 && $0.allSatisfy(\.isNumber) }) {
            self.init(provider: .vimeo, id: id)
        } else {
            return nil
        }
    }

    init?(map: [String: Any]?) {
        guard let map, let provider = (map["provider"] as? String).flatMap(Provider.init(rawValue:)),
              let id = FieldReader.string(map["id"]) else { return nil }
        self.init(provider: provider, id: id)
    }

    private static func isYouTubeId(_ value: String) -> Bool {
        value.count == 11 && value.allSatisfy { $0.isLetter || $0.isNumber || $0 == "-" || $0 == "_" }
    }

    var siteName: String { provider == .youtube ? "YouTube" : "Vimeo" }

    var thumbnailURL: String? { provider == .youtube ? "https://i.ytimg.com/vi/\(id)/hqdefault.jpg" : nil }

    /// The provider's player, for VideoPlayerWebView.
    var embedURL: URL {
        switch provider {
        case .youtube: return URL(string: "https://www.youtube.com/embed/\(id)?autoplay=1&playsinline=1&rel=0")!
        case .vimeo: return URL(string: "https://player.vimeo.com/video/\(id)?autoplay=1&playsinline=1")!
        }
    }
}

/// A document in the top-level `posts` collection - the same records the
/// web board reads (see web-products/sayit SayItService.publishPost).
struct Post: Identifiable, Equatable, Hashable {
    let id: String
    var authorUid: String?
    var displayName: String
    var photoURL: String?
    var content: String
    var category: String
    var timestamp: Date?
    var postImageURL: String?
    var linkPreview: LinkPreview?
    /// 1 = acceptable ... 6 = offensive, set by the AI moderation step.
    var contentRating: Int?
    var ratingExplanation: String?
    var authorHandle: String?
    var authorEmail: String?
    var favoriteCount: Int
    var isHidden: Bool
    /// System posts written by TODD itself rather than a person.
    var isSystemPost: Bool
    /// Set by the new composer; older posts only have `content`.
    var title: String?
    var caption: String?
    var kind: PostKind?
    var price: String?
    var authorRole: String?
    var orgName: String?
    var favoriteUserIds: [String] = []
    /// What the post's photo shows, from the server's image review
    /// (sayit/imageReview.service.js) - searchable, so "coffee" finds a photo of coffee.
    var imageDescription: String?
    var imageKeywords: [String] = []

    init(
        id: String,
        authorUid: String? = nil,
        displayName: String = "User",
        photoURL: String? = nil,
        content: String = "",
        category: String = "all",
        timestamp: Date? = nil,
        postImageURL: String? = nil,
        linkPreview: LinkPreview? = nil,
        contentRating: Int? = nil,
        ratingExplanation: String? = nil,
        authorHandle: String? = nil,
        authorEmail: String? = nil,
        favoriteCount: Int = 0,
        isHidden: Bool = false,
        isSystemPost: Bool = false,
        title: String? = nil,
        caption: String? = nil,
        kind: PostKind? = nil,
        price: String? = nil,
        authorRole: String? = nil,
        orgName: String? = nil,
        favoriteUserIds: [String] = [],
        imageDescription: String? = nil,
        imageKeywords: [String] = []
    ) {
        self.id = id
        self.authorUid = authorUid
        self.displayName = displayName
        self.photoURL = photoURL
        self.content = content
        self.category = category
        self.timestamp = timestamp
        self.postImageURL = postImageURL
        self.linkPreview = linkPreview
        self.contentRating = contentRating
        self.ratingExplanation = ratingExplanation
        self.authorHandle = authorHandle
        self.authorEmail = authorEmail
        self.favoriteCount = favoriteCount
        self.isHidden = isHidden
        self.isSystemPost = isSystemPost
        self.title = title
        self.caption = caption
        self.kind = kind
        self.price = price
        self.authorRole = authorRole
        self.orgName = orgName
        self.favoriteUserIds = favoriteUserIds
        self.imageDescription = imageDescription
        self.imageKeywords = imageKeywords
    }

    /// Builds a post from a Firestore document's data. Mirrors the web's
    /// fallbacks: `authorUid` is preferred, then the legacy `userId` and
    /// `user` fields.
    init(id: String, data: [String: Any]) {
        let legacyUser = FieldReader.string(data["user"])
        let isSystem = legacyUser == "TODD"
        var preview: LinkPreview?
        if let map = data["linkPreview"] as? [String: Any] {
            let candidate = LinkPreview(
                title: FieldReader.string(map["title"]),
                description: FieldReader.string(map["description"]),
                url: FieldReader.string(map["url"]),
                image: FieldReader.string(map["image"]),
                siteName: FieldReader.string(map["siteName"]),
                video: PostVideo(map: map["video"] as? [String: Any])
            )
            if candidate.title != nil || candidate.url != nil || candidate.image != nil {
                preview = candidate
            }
        }

        self.init(
            id: id,
            authorUid: isSystem ? nil : FieldReader.string(data["authorUid"]) ?? FieldReader.string(data["userId"]) ?? legacyUser,
            displayName: FieldReader.string(data["displayName"]) ?? (isSystem ? "TODD" : "User"),
            photoURL: FieldReader.string(data["imageUrl"]),
            content: (data["content"] as? String) ?? "",
            category: FieldReader.string(data["category"]) ?? "all",
            timestamp: FieldReader.date(data["timestamp"]),
            postImageURL: FieldReader.string(data["postImageUrl"]),
            linkPreview: preview,
            contentRating: FieldReader.int(data["contentRating"]),
            ratingExplanation: FieldReader.string(data["ratingExplanation"]),
            authorHandle: FieldReader.string(data["authorHandle"]),
            authorEmail: FieldReader.string(data["emailAddress"]),
            favoriteCount: FieldReader.int(data["favoriteCount"]) ?? 0,
            // `isHidden` is what moderation wrote alone before 2026-10-10.
            isHidden: FieldReader.bool(data["hidden"]) || FieldReader.bool(data["isHidden"]) || FieldReader.bool(data["suspended"]),
            isSystemPost: isSystem,
            title: FieldReader.string(data["title"]),
            caption: FieldReader.string(data["caption"]),
            kind: PostKind(stored: FieldReader.string(data["kind"])),
            price: FieldReader.string(data["price"]),
            authorRole: FieldReader.string(data["authorRole"]),
            orgName: FieldReader.string(data["orgName"]),
            favoriteUserIds: FieldReader.stringArray(data["favoriteUserIds"]),
            imageDescription: FieldReader.string(data["imageDescription"]),
            imageKeywords: FieldReader.stringArray(data["imageKeywords"])
        )
    }

    /// The big line: the composer's title, else the post's words. A post
    /// that's only a link shows the linked page's title instead of the URL.
    var headline: String {
        if let title {
            // The composer's headline can be just a pasted link. Once the link
            // shows as a preview or a playable video, the URL isn't repeated.
            guard showsLinkAsCard else { return title }
            let words = removingCardLink(from: title)
            if !words.isEmpty { return words }
            if let linkTitle = linkPreview?.title, !linkTitle.isEmpty { return linkTitle }
            return title
        }
        let words = textWithoutLink
        if words.isEmpty, let linkTitle = linkPreview?.title, !linkTitle.isEmpty { return linkTitle }
        return words.isEmpty ? content : words
    }

    /// Text under the headline - only posts written with a separate title have one.
    var body: String? {
        guard title != nil, let caption else { return nil }
        guard showsLinkAsCard else { return caption }
        let words = removingCardLink(from: caption)
        return words.isEmpty ? nil : words
    }

    /// The text without the link that's shown as the card; any other link stays.
    private func removingCardLink(from text: String) -> String {
        guard let found = Self.firstURL(in: text) else { return text.trimmingCharacters(in: .whitespacesAndNewlines) }
        let isCard = found == linkURL || (linkVideo != nil && PostVideo(url: found) == linkVideo)
        return isCard ? Self.removingLink(from: text) : text.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    /// The link is shown as a preview card or a playable video, so its URL
    /// can come out of the words.
    private var showsLinkAsCard: Bool { linkPreview != nil || linkVideo != nil }

    /// No photo: the post's words are the visual (the design's quote card).
    var isTextOnly: Bool { imageURL == nil }

    var imageURL: String? { postImageURL ?? linkPreview?.image ?? linkVideo?.thumbnailURL }

    /// The post's link: the saved preview's URL, else the first link in its words.
    var linkURL: String? { linkPreview?.url ?? Self.firstURL(in: content) }

    /// The YouTube or Vimeo video to play in place, if the post links to one.
    var linkVideo: PostVideo? { linkPreview?.video ?? PostVideo(url: linkURL) }

    /// The post's words without its link, once the link shows as a preview.
    var textWithoutLink: String {
        guard linkPreview != nil else { return content.trimmingCharacters(in: .whitespacesAndNewlines) }
        return Self.removingLink(from: content)
    }

    /// The text without its first link, tidied ("Read this (link)." -> "Read this.").
    static func removingLink(from text: String) -> String {
        guard let url = firstURL(in: text) else { return text.trimmingCharacters(in: .whitespacesAndNewlines) }
        var text = text.replacingOccurrences(of: url, with: " ")
        for (pattern, template) in [(#"[(\[]\s*[)\]]"#, ""), (#"[ \t]+([.,!?;:])"#, "$1"), (#"[ \t]{2,}"#, " "), (#"\s*\n\s*\n\s*"#, "\n\n")] {
            text = text.replacingOccurrences(of: pattern, with: template, options: .regularExpression)
        }
        return text.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    /// How much of the text counts toward the composer's limits: links show
    /// as a preview card, not as text, so they don't count.
    static func visibleLength(of text: String) -> Int {
        text.replacingOccurrences(of: #"https?://[^\s<>"']+"#, with: "", options: [.regularExpression, .caseInsensitive])
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .count
    }

    static func firstURL(in text: String) -> String? {
        guard let range = text.range(of: #"https?://[^\s<>"']+"#, options: [.regularExpression, .caseInsensitive]) else { return nil }
        return String(text[range]).replacingOccurrences(of: #"[).,!?;:'"\]]+$"#, with: "", options: .regularExpression)
    }

    /// "Jane Doe" out of "Jane Doe at AT&T" when there's no separate org field.
    var personName: String { displayName.components(separatedBy: " at ").first ?? displayName }

    /// The org shown with the author: the post's org, else " at X" in the name.
    var orgLabel: String? {
        if let orgName, !orgName.isEmpty { return orgName }
        let parts = displayName.components(separatedBy: " at ")
        return parts.count > 1 ? parts.dropFirst().joined(separator: " at ") : nil
    }

    var likeCount: Int { max(favoriteCount, favoriteUserIds.count) }

    /// Posts rated 4+ ("very inappropriate") are shown behind a warning, as
    /// on the web.
    var needsContentWarning: Bool { (contentRating ?? 1) >= 4 }
}
