import Foundation

/// A document in the top-level `post-interests` collection: someone tapped
/// "I'm interested" on one of your posts.
struct Interest: Identifiable, Equatable, Hashable {
    let id: String
    var postId: String
    var postAuthorUid: String
    var postPreview: String?
    var message: String?
    var interestedUid: String
    var interestedDisplayName: String
    var interestedEmail: String?
    var interestedPhotoURL: String?
    var createdAt: Date?
    var viewed: Bool

    init(id: String, data: [String: Any]) {
        self.id = id
        postId = FieldReader.string(data["postId"]) ?? ""
        postAuthorUid = FieldReader.string(data["postAuthorUid"]) ?? ""
        postPreview = FieldReader.string(data["postPreview"])
        message = FieldReader.string(data["message"])
        interestedUid = FieldReader.string(data["interestedUid"]) ?? ""
        interestedDisplayName = FieldReader.string(data["interestedDisplayName"]) ?? "Someone"
        interestedEmail = FieldReader.string(data["interestedEmail"])
        interestedPhotoURL = FieldReader.string(data["interestedPhotoURL"])
        createdAt = FieldReader.date(data["createdAt"])
        viewed = FieldReader.bool(data["viewed"])
    }
}
