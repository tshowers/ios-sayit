import Foundation

/// Decides which posts the feed and search show. On top of category, kind
/// and search filters, it drops posts that moderation or an admin hid,
/// posts rated offensive (6), and posts by people the viewer blocked -
/// App Store guideline 1.2 requires both filtering and blocking for
/// user-generated content.
struct FeedFilter: Equatable {
    var category = "all"
    var searchText = ""
    /// Nil shows every kind.
    var kind: PostKind?
    var blockedUids: Set<String> = []

    static let offensiveRating = 6

    func apply(to posts: [Post]) -> [Post] {
        let normalizedCategory = category.trimmingCharacters(in: .whitespaces).lowercased()
        let words = Self.words(in: searchText)

        return posts.filter { post in
            if post.isHidden { return false }
            if (post.contentRating ?? 1) >= Self.offensiveRating { return false }
            if let author = post.authorUid, blockedUids.contains(author) { return false }

            if !normalizedCategory.isEmpty, normalizedCategory != "all",
               post.category.lowercased() != normalizedCategory {
                return false
            }
            if let kind, post.kind != kind { return false }

            if !words.isEmpty {
                let haystack = Self.searchableText(post)
                if !words.allSatisfy({ haystack.contains($0) }) { return false }
            }
            return true
        }
    }

    /// Every word must appear somewhere, in any order ("plumber seattle").
    static func words(in text: String) -> [String] {
        text.lowercased()
            .split(whereSeparator: { $0.isWhitespace })
            .map { $0.trimmingCharacters(in: .punctuationCharacters) }
            .filter { !$0.isEmpty }
    }

    /// Everything a person might search a post by.
    static func searchableText(_ post: Post) -> String {
        [post.content, post.title ?? "", post.caption ?? "", post.displayName, post.orgLabel ?? "",
         post.authorRole ?? "", post.category, PostCategory.label(for: post.category),
         post.kind?.label ?? "", post.price ?? ""]
            .joined(separator: " ")
            .lowercased()
    }

    /// Categories that actually appear in these posts, most common first -
    /// the search page's filter chips.
    static func categories(in posts: [Post]) -> [String] {
        var counts: [String: Int] = [:]
        for post in posts {
            let category = post.category.lowercased()
            guard !category.isEmpty, category != "all" else { continue }
            counts[category, default: 0] += 1
        }
        return counts.sorted { $0.value != $1.value ? $0.value > $1.value : $0.key < $1.key }.map(\.key)
    }
}
