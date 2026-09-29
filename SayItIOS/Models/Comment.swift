import Foundation

/// A document in `posts/{postId}/comments`.
struct Comment: Identifiable, Equatable, Hashable {
    let id: String
    var postId: String
    var authorUid: String
    var authorDisplayName: String
    var authorPhotoURL: String?
    var content: String
    var createdAt: Date?

    init(id: String, postId: String, authorUid: String, authorDisplayName: String, authorPhotoURL: String? = nil, content: String, createdAt: Date? = nil) {
        self.id = id
        self.postId = postId
        self.authorUid = authorUid
        self.authorDisplayName = authorDisplayName
        self.authorPhotoURL = authorPhotoURL
        self.content = content
        self.createdAt = createdAt
    }

    init(id: String, postId: String, data: [String: Any]) {
        self.init(
            id: id,
            postId: FieldReader.string(data["postId"]) ?? postId,
            authorUid: FieldReader.string(data["authorUid"]) ?? "",
            authorDisplayName: FieldReader.string(data["authorDisplayName"]) ?? "User",
            authorPhotoURL: FieldReader.string(data["authorPhotoURL"]),
            content: (data["content"] as? String) ?? "",
            createdAt: FieldReader.date(data["createdAt"])
        )
    }
}
