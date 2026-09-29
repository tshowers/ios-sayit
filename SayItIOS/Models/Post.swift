import Foundation

struct LinkPreview: Equatable, Hashable {
    var title: String?
    var description: String?
    var url: String?
    var image: String?
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
        isSystemPost: Bool = false
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
                image: FieldReader.string(map["image"])
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
            isHidden: FieldReader.bool(data["hidden"]) || FieldReader.bool(data["suspended"]),
            isSystemPost: isSystem
        )
    }

    /// Posts rated 4+ ("very inappropriate") are shown behind a warning, as
    /// on the web.
    var needsContentWarning: Bool { (contentRating ?? 1) >= 4 }
}
