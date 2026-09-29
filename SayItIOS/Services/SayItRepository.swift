import Foundation
import FirebaseAuth
import FirebaseFirestore

/// Every Firestore read and write the app makes. Paths and field names match
/// web-products/sayit (SayItDataService / SayItService) exactly, so posts,
/// comments and interests from the app and the web are the same records.
final class SayItRepository {
    private let db = Firestore.firestore()
    private let masterTenantId: String

    init(config: AppConfig) {
        masterTenantId = config.masterTenantId
    }

    private var posts: CollectionReference { db.collection("posts") }
    private var interests: CollectionReference { db.collection("post-interests") }
    private var reports: CollectionReference { db.collection("post-reports") }
    private func profileRef(_ uid: String) -> DocumentReference {
        db.collection("tenants").document(masterTenantId).collection("say-it-profiles").document(uid)
    }

    // MARK: Posts

    /// Live feed, newest first - the web board's query, capped so a phone
    /// never downloads the whole history.
    func listenToPosts(limit: Int = 200, onChange: @escaping (Result<[Post], Error>) -> Void) -> ListenerRegistration {
        posts.order(by: "timestamp", descending: true).limit(to: limit).addSnapshotListener { snapshot, error in
            if let error {
                onChange(.failure(error))
                return
            }
            let items = snapshot?.documents.map { Post(id: $0.documentID, data: FirestoreValues.normalize($0.data())) } ?? []
            onChange(.success(items))
        }
    }

    /// When this person posted - drives the post-count awards.
    func postDates(authorUid uid: String) async throws -> [Date] {
        let snapshot = try await posts.whereField("authorUid", isEqualTo: uid).limit(to: 200).getDocuments()
        return snapshot.documents.compactMap { Post(id: $0.documentID, data: FirestoreValues.normalize($0.data())).timestamp }
    }

    func post(id: String) async throws -> Post? {
        let snapshot = try await posts.document(id).getDocument()
        guard snapshot.exists, let data = snapshot.data() else { return nil }
        return Post(id: snapshot.documentID, data: FirestoreValues.normalize(data))
    }

    struct NewPost {
        var content: String
        var category: String
        var displayName: String
        var photoURL: String?
        var authorHandle: String?
        var moderation: Moderation.Result?
    }

    /// Same document shape as SayItService.publishPost on the web,
    /// including the legacy `user`/`userId` author fields older readers use.
    @discardableResult
    func publish(_ draft: NewPost) async throws -> String {
        guard let user = Auth.auth().currentUser else { throw AuthServiceError.notSignedIn }
        let fields = FirestoreValues.compact([
            "user": user.uid,
            "userId": user.uid,
            "authorUid": user.uid,
            "displayName": draft.displayName,
            "imageUrl": draft.photoURL,
            "content": draft.content,
            "timestamp": Timestamp(date: Date()),
            "emailAddress": user.email ?? "",
            "category": draft.moderation?.category ?? draft.category,
            "authorHandle": draft.authorHandle?.lowercased(),
            "contentRating": draft.moderation?.rating,
            "ratingExplanation": draft.moderation?.explanation,
            "source": "ios",
        ])
        let ref = try await posts.addDocument(data: fields)
        return ref.documentID
    }

    func deletePost(_ post: Post) async throws {
        guard let uid = Auth.auth().currentUser?.uid, post.authorUid == uid else {
            throw RepositoryError.notYours
        }
        try await posts.document(post.id).delete()
    }

    // MARK: Comments

    func comments(postId: String) async throws -> [Comment] {
        let snapshot = try await posts.document(postId).collection("comments")
            .order(by: "createdAt").limit(to: 200).getDocuments()
        return snapshot.documents.map { Comment(id: $0.documentID, postId: postId, data: FirestoreValues.normalize($0.data())) }
    }

    func addComment(postId: String, content: String, displayName: String) async throws {
        guard let user = Auth.auth().currentUser else { throw AuthServiceError.notSignedIn }
        let text = CommentDraft.cleaned(content)
        guard !text.isEmpty else { return }
        try await posts.document(postId).collection("comments").addDocument(data: FirestoreValues.compact([
            "postId": postId,
            "authorUid": user.uid,
            "authorDisplayName": displayName,
            "authorPhotoURL": user.photoURL?.absoluteString,
            "content": text,
            "createdAt": ISO8601DateFormatter.sayIt.string(from: Date()),
        ]))
    }

    func deleteComment(_ comment: Comment) async throws {
        guard let uid = Auth.auth().currentUser?.uid, comment.authorUid == uid else {
            throw RepositoryError.notYours
        }
        try await posts.document(comment.postId).collection("comments").document(comment.id).delete()
    }

    // MARK: Interest

    func expressInterest(in post: Post, displayName: String, postURL: URL) async throws {
        guard let user = Auth.auth().currentUser else { throw AuthServiceError.notSignedIn }
        guard let author = post.authorUid else { throw RepositoryError.noAuthor }
        let email = user.email?.lowercased()
        try await interests.addDocument(data: FirestoreValues.compact([
            "postId": post.id,
            "postAuthorUid": author,
            "postCategory": post.category,
            "postPreview": String(post.content.prefix(160)),
            "postUrl": postURL.absoluteString,
            "postAuthorEmail": post.authorEmail,
            "postAuthorHandle": post.authorHandle,
            "postAuthorDisplayName": post.displayName,
            "message": "",
            "interestedUid": user.uid,
            "interestedDisplayName": displayName,
            "interestedHandle": email?.split(separator: "@").first.map(String.init),
            "interestedPhotoURL": user.photoURL?.absoluteString,
            "interestedEmail": email,
            "createdAt": ISO8601DateFormatter.sayIt.string(from: Date()),
            "viewed": false,
        ]))
    }

    func interests(forAuthor uid: String) async throws -> [Interest] {
        let snapshot = try await interests
            .whereField("postAuthorUid", isEqualTo: uid)
            .order(by: "createdAt", descending: true)
            .limit(to: 100)
            .getDocuments()
        return snapshot.documents.map { Interest(id: $0.documentID, data: FirestoreValues.normalize($0.data())) }
    }

    func markViewed(_ interest: Interest) async throws {
        try await interests.document(interest.id).updateData([
            "viewed": true,
            "viewedAt": ISO8601DateFormatter.sayIt.string(from: Date()),
        ])
    }

    // MARK: Profile & safety

    func profile(uid: String) async throws -> SayItProfile? {
        let snapshot = try await profileRef(uid).getDocument()
        guard snapshot.exists, let data = snapshot.data() else { return nil }
        return SayItProfile(uid: uid, data: FirestoreValues.normalize(data))
    }

    /// Blocks are kept on the viewer's own profile doc so they follow the
    /// account to every device (and the web can honor them later).
    func setBlockedUids(_ uids: [String], for uid: String) async throws {
        try await profileRef(uid).setData(["uid": uid, "blockedUids": uids], merge: true)
    }

    /// App Store guideline 1.2: a way to flag objectionable content. Reports
    /// land in `post-reports` for review.
    func report(_ post: Post, reason: String) async throws {
        guard let user = Auth.auth().currentUser else { throw AuthServiceError.notSignedIn }
        try await reports.addDocument(data: FirestoreValues.compact([
            "postId": post.id,
            "postAuthorUid": post.authorUid,
            "postPreview": String(post.content.prefix(300)),
            "reason": reason,
            "reporterUid": user.uid,
            "reporterEmail": user.email,
            "createdAt": ISO8601DateFormatter.sayIt.string(from: Date()),
            "status": "open",
            "source": "ios",
        ]))
    }
}

enum RepositoryError: LocalizedError {
    case notYours
    case noAuthor

    var errorDescription: String? {
        switch self {
        case .notYours: return "You can only delete your own posts and comments."
        case .noAuthor: return "This post has no author to notify."
        }
    }
}

extension ISO8601DateFormatter {
    /// `2026-09-29T12:00:00.000Z` - the format the web's `toISOString()` writes.
    static let sayIt: ISO8601DateFormatter = {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return formatter
    }()
}
