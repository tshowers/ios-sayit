import Foundation

/// Seeded posts: the backend's scheduled generator
/// (todd-backend/functions/sayit-random-post.service.js) posts AI personas -
/// "Morgan at GreenBox Supplies" - as the master account, so they all share
/// one author uid. Blocking one must hide that persona, never the master
/// account, or every seeded post (and the owner's own posts) disappears.
enum SeededPosts {
    /// The master account / tenant id the generator posts as.
    static let masterUid = "yH3nWanUv0RqDCNfwXBOXLWuxt52"
    private static let personaPrefix = "seed:"

    /// The block-list entry for an author: their uid, or for the master
    /// account the persona's name ("seed:Morgan at GreenBox Supplies").
    static func blockKey(authorUid: String, displayName: String) -> String {
        guard authorUid == masterUid else { return authorUid }
        return personaPrefix + displayName.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    static func blockKey(for post: Post) -> String? {
        post.authorUid.map { blockKey(authorUid: $0, displayName: post.displayName) }
    }

    /// The persona name in a block-list entry, if it is one.
    static func personaName(inBlockKey key: String) -> String? {
        key.hasPrefix(personaPrefix) ? String(key.dropFirst(personaPrefix.count)) : nil
    }
}
