import Foundation

/// Decides which posts the feed shows. On top of the web board's category
/// and search filters, the app also drops posts that moderation or an admin
/// hid, posts rated offensive (6), and posts by people the viewer blocked -
/// App Store guideline 1.2 requires both filtering and blocking for
/// user-generated content.
struct FeedFilter: Equatable {
    var category = "all"
    var searchText = ""
    var blockedUids: Set<String> = []

    static let offensiveRating = 6

    func apply(to posts: [Post]) -> [Post] {
        let normalizedCategory = category.trimmingCharacters(in: .whitespaces).lowercased()
        let search = searchText.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()

        return posts.filter { post in
            if post.isHidden { return false }
            if (post.contentRating ?? 1) >= Self.offensiveRating { return false }
            if let author = post.authorUid, blockedUids.contains(author) { return false }

            if !normalizedCategory.isEmpty, normalizedCategory != "all",
               post.category.lowercased() != normalizedCategory {
                return false
            }

            if !search.isEmpty {
                let haystack = [post.content, post.displayName, post.category].joined(separator: " ").lowercased()
                if !haystack.contains(search) { return false }
            }
            return true
        }
    }
}
