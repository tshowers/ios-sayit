import Foundation
import FirebaseAuth
import FirebaseFirestore
import FirebaseStorage

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
        var title: String? = nil
        var caption: String? = nil
        var kind: PostKind? = nil
        var price: String? = nil
        var imageURL: String? = nil
        var imagePath: String? = nil
        var authorRole: String? = nil
        var orgName: String? = nil
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
            "title": draft.title,
            "caption": draft.caption,
            "kind": draft.kind?.rawValue,
            "price": draft.price,
            "postImageUrl": draft.imageURL,
            "postImagePath": draft.imagePath,
            "authorRole": draft.authorRole,
            "orgName": draft.orgName,
            "favoriteCount": 0,
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

    /// Posts by any of these people (an org's members), newest first.
    func posts(byAuthors uids: [String]) async throws -> [Post] {
        guard !uids.isEmpty else { return [] }
        var results: [Post] = []
        for chunk in stride(from: 0, to: uids.count, by: 30).map({ Array(uids[$0..<min($0 + 30, uids.count)]) }) {
            let snapshot = try await posts.whereField("authorUid", in: chunk).limit(to: 100).getDocuments()
            results += snapshot.documents.map { Post(id: $0.documentID, data: FirestoreValues.normalize($0.data())) }
        }
        return results.filter { !$0.isHidden }.sorted { ($0.timestamp ?? .distantPast) > ($1.timestamp ?? .distantPast) }
    }

    /// Photo for a new post, under the owner's `sayit/posts/{uid}/` folder
    /// (storage.rules). Returns the public download URL and storage path.
    func uploadPostImage(_ jpeg: Data) async throws -> (url: String, path: String) {
        guard let uid = Auth.auth().currentUser?.uid else { throw AuthServiceError.notSignedIn }
        let path = "sayit/posts/\(uid)/\(UUID().uuidString).jpg"
        let ref = Storage.storage().reference(withPath: path)
        let metadata = StorageMetadata()
        metadata.contentType = "image/jpeg"
        _ = try await ref.putDataAsync(jpeg, metadata: metadata)
        return (try await ref.downloadURL().absoluteString, path)
    }

    // MARK: Likes

    /// Likes live on the post (`favoriteUserIds` / `favoriteCount`, the only
    /// fields other people may change) and on the liker's profile
    /// (`favoritePostIds`) - the same fields the web board uses.
    func setLiked(_ liked: Bool, post: Post, uid: String) async throws {
        try await posts.document(post.id).updateData([
            "favoriteUserIds": liked ? FieldValue.arrayUnion([uid]) : FieldValue.arrayRemove([uid]),
            "favoriteCount": FieldValue.increment(Int64(liked ? 1 : -1)),
        ])
        try await profileRef(uid).setData([
            "uid": uid,
            "favoritePostIds": liked ? FieldValue.arrayUnion([post.id]) : FieldValue.arrayRemove([post.id]),
        ], merge: true)
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

    @discardableResult
    func expressInterest(in post: Post, displayName: String, postURL: URL) async throws -> String {
        guard let user = Auth.auth().currentUser else { throw AuthServiceError.notSignedIn }
        guard let author = post.authorUid else { throw RepositoryError.noAuthor }
        let email = user.email?.lowercased()
        let ref = try await interests.addDocument(data: FirestoreValues.compact([
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
        return ref.documentID
    }

    /// Post id -> interest doc id for everything this person is interested in.
    func myInterests(uid: String) async throws -> [String: String] {
        let snapshot = try await interests.whereField("interestedUid", isEqualTo: uid).limit(to: 500).getDocuments()
        var byPost: [String: String] = [:]
        for doc in snapshot.documents {
            if let postId = FieldReader.string(doc.data()["postId"]) { byPost[postId] = doc.documentID }
        }
        return byPost
    }

    func withdrawInterest(docId: String) async throws {
        try await interests.document(docId).delete()
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

    // MARK: Conversations

    private var threads: CollectionReference { db.collection("sayit-threads") }

    /// Every conversation this person is part of, live.
    func listenToThreads(uid: String, onChange: @escaping ([ChatThread]) -> Void) -> ListenerRegistration {
        threads.whereField("participants", arrayContains: uid).addSnapshotListener { snapshot, _ in
            onChange(snapshot?.documents.map { ChatThread(id: $0.documentID, data: FirestoreValues.normalize($0.data())) } ?? [])
        }
    }

    func listenToMessages(threadId: String, onChange: @escaping ([ChatMessage]) -> Void) -> ListenerRegistration {
        threads.document(threadId).collection("messages").order(by: "createdAt").limit(toLast: 300).addSnapshotListener { snapshot, _ in
            onChange(snapshot?.documents.map { ChatMessage(id: $0.documentID, data: FirestoreValues.normalize($0.data())) } ?? [])
        }
    }

    /// Opens (or reopens) the conversation about `postId` between its author
    /// and the interested person. Either of them can create it - the author
    /// does when replying to interest sent from the web.
    func ensureThread(_ thread: ChatThread, systemNote: String?) async throws {
        let ref = threads.document(thread.id)
        if try await ref.getDocument().exists {
            try await ref.updateData(["interestActive": true])
            return
        }
        var people: [String: Any] = [:]
        for (uid, person) in thread.people {
            people[uid] = FirestoreValues.compact(["name": person.name, "org": person.org, "role": person.role, "photoURL": person.photoURL, "email": person.email])
        }
        let now = Timestamp(date: Date())
        try await ref.setData(FirestoreValues.compact([
            "postId": thread.postId,
            "postTitle": thread.postTitle,
            "postKind": thread.postKind?.rawValue,
            "postPrice": thread.postPrice,
            "postImageUrl": thread.postImageURL,
            "authorUid": thread.authorUid,
            "interestedUid": thread.interestedUid,
            "participants": [thread.authorUid, thread.interestedUid],
            "people": people,
            "lastMessage": systemNote ?? "",
            "lastMessageAt": now,
            "unread": [thread.authorUid: systemNote == nil ? 0 : 1, thread.interestedUid: 0],
            "interestActive": true,
            "createdAt": now,
        ]))
        if let systemNote, let me = Auth.auth().currentUser?.uid {
            try await ref.collection("messages").addDocument(data: ["senderUid": me, "text": systemNote, "system": true, "createdAt": now])
        }
    }

    func setInterestActive(_ active: Bool, threadId: String) async throws {
        let ref = threads.document(threadId)
        guard try await ref.getDocument().exists else { return }
        try await ref.updateData(["interestActive": active])
    }

    /// Sends a message and bumps the other person's unread count. Returns
    /// how many unread messages they had before this one.
    @discardableResult
    func send(_ text: String, in thread: ChatThread, layout: FeedLayout?) async throws -> Int {
        guard let me = Auth.auth().currentUser?.uid else { throw AuthServiceError.notSignedIn }
        let body = InboxRules.cleaned(text)
        guard !body.isEmpty else { return 0 }
        let other = thread.otherUid(me: me)
        let ref = threads.document(thread.id)
        let unreadBefore = (try? await ref.getDocument().data()?["unread"] as? [String: Any])?[other].flatMap { FieldReader.int($0) } ?? 0
        let now = Timestamp(date: Date())
        try await ref.collection("messages").addDocument(data: FirestoreValues.compact([
            "senderUid": me, "text": body, "createdAt": now, "layout": layout?.rawValue,
        ]))
        try await ref.updateData([
            "lastMessage": body,
            "lastMessageAt": now,
            "lastSenderUid": me,
            "unread.\(other)": FieldValue.increment(Int64(1)),
        ])
        return unreadBefore
    }

    func markRead(threadId: String, uid: String) async throws {
        try await threads.document(threadId).updateData(["unread.\(uid)": 0])
    }

    // MARK: Orgs

    /// Public SayIt profiles, grouped into orgs by OrgDirectory. Reading
    /// profiles needs a signed-in account (Firestore rules).
    func publicProfiles() async throws -> [SayItProfile] {
        let snapshot = try await db.collection("tenants").document(masterTenantId).collection("say-it-profiles")
            .whereField("publicProfile", isEqualTo: true).limit(to: 500).getDocuments()
        return snapshot.documents.map { SayItProfile(uid: $0.documentID, data: FirestoreValues.normalize($0.data())) }
    }

    /// Profile fields the member edits directly (layout, job title).
    func updateProfile(uid: String, fields: [String: Any]) async throws {
        var data = fields
        data["uid"] = uid
        try await profileRef(uid).setData(data, merge: true)
    }

    /// Which layout a like, interest, or message came from.
    func logLayoutEvent(uid: String, layout: FeedLayout, action: String, postId: String) {
        db.collection("sayit-layout-events").addDocument(data: [
            "uid": uid, "layout": layout.rawValue, "action": action, "postId": postId, "createdAt": Timestamp(date: Date()),
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
