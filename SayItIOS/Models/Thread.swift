import Foundation

/// `sayit-threads/{postId}_{interestedUid}`: the one-on-one conversation
/// "I'm interested" starts between the interested person and the post's
/// author. Only its two participants can read it (Firestore rules).
struct ChatThread: Identifiable, Equatable, Hashable {
    struct Person: Equatable, Hashable {
        var name: String
        var org: String
        var role: String
        var photoURL: String?
        var email: String?
    }

    let id: String
    var postId: String
    var postTitle: String
    var postKind: PostKind?
    var postPrice: String?
    var postImageURL: String?
    var authorUid: String
    var interestedUid: String
    var people: [String: Person]
    var lastMessage: String
    var lastMessageAt: Date?
    var lastSenderUid: String?
    var unread: [String: Int]
    /// False once the interested person taps "I'm interested" off - the
    /// conversation itself stays.
    var interestActive: Bool

    static func id(postId: String, interestedUid: String) -> String { "\(postId)_\(interestedUid)" }

    init(id: String, postId: String, postTitle: String, postKind: PostKind? = nil, postPrice: String? = nil, postImageURL: String? = nil,
         authorUid: String, interestedUid: String, people: [String: Person] = [:], lastMessage: String = "",
         lastMessageAt: Date? = nil, lastSenderUid: String? = nil, unread: [String: Int] = [:], interestActive: Bool = true) {
        self.id = id
        self.postId = postId
        self.postTitle = postTitle
        self.postKind = postKind
        self.postPrice = postPrice
        self.postImageURL = postImageURL
        self.authorUid = authorUid
        self.interestedUid = interestedUid
        self.people = people
        self.lastMessage = lastMessage
        self.lastMessageAt = lastMessageAt
        self.lastSenderUid = lastSenderUid
        self.unread = unread
        self.interestActive = interestActive
    }

    init(id: String, data: [String: Any]) {
        var people: [String: Person] = [:]
        for (uid, raw) in (data["people"] as? [String: Any]) ?? [:] {
            guard let map = raw as? [String: Any] else { continue }
            people[uid] = Person(name: FieldReader.string(map["name"]) ?? "Someone",
                                 org: FieldReader.string(map["org"]) ?? "",
                                 role: FieldReader.string(map["role"]) ?? "",
                                 photoURL: FieldReader.string(map["photoURL"]),
                                 email: FieldReader.string(map["email"]))
        }
        var unread: [String: Int] = [:]
        for (uid, value) in (data["unread"] as? [String: Any]) ?? [:] { unread[uid] = FieldReader.int(value) ?? 0 }

        self.init(
            id: id,
            postId: FieldReader.string(data["postId"]) ?? "",
            postTitle: FieldReader.string(data["postTitle"]) ?? "",
            postKind: PostKind(stored: FieldReader.string(data["postKind"])),
            postPrice: FieldReader.string(data["postPrice"]),
            postImageURL: FieldReader.string(data["postImageUrl"]),
            authorUid: FieldReader.string(data["authorUid"]) ?? "",
            interestedUid: FieldReader.string(data["interestedUid"]) ?? "",
            people: people,
            lastMessage: FieldReader.string(data["lastMessage"]) ?? "",
            lastMessageAt: FieldReader.date(data["lastMessageAt"]),
            lastSenderUid: FieldReader.string(data["lastSenderUid"]),
            unread: unread,
            interestActive: data["interestActive"] == nil ? true : FieldReader.bool(data["interestActive"])
        )
    }

    func otherUid(me: String) -> String { me == authorUid ? interestedUid : authorUid }
    func other(me: String) -> Person { people[otherUid(me: me)] ?? Person(name: "Someone", org: "", role: "") }
    func unreadCount(for uid: String) -> Int { unread[uid] ?? 0 }

    /// "You're interested" vs "Interested in yours" - the design's direction tag.
    func isMine(me: String) -> Bool { me == interestedUid }
}

struct ChatMessage: Identifiable, Equatable, Hashable {
    let id: String
    var senderUid: String
    var text: String
    var createdAt: Date?
    /// "You tapped I'm interested" style line, centered, not a bubble.
    var isSystem: Bool

    init(id: String, senderUid: String, text: String, createdAt: Date? = nil, isSystem: Bool = false) {
        self.id = id
        self.senderUid = senderUid
        self.text = text
        self.createdAt = createdAt
        self.isSystem = isSystem
    }

    init(id: String, data: [String: Any]) {
        self.init(id: id,
                  senderUid: FieldReader.string(data["senderUid"]) ?? "",
                  text: (data["text"] as? String) ?? "",
                  createdAt: FieldReader.date(data["createdAt"]),
                  isSystem: FieldReader.bool(data["system"]))
    }
}
