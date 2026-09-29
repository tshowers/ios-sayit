import Foundation

/// Validation for a new post, matching the web composer (155 characters).
enum PostDraft {
    static let maxLength = 155

    static func cleaned(_ text: String) -> String {
        text.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    static func canPost(_ text: String) -> Bool {
        let content = cleaned(text)
        return !content.isEmpty && content.count <= maxLength
    }

    static func remaining(_ text: String) -> Int {
        maxLength - cleaned(text).count
    }
}

/// Validation for a comment, matching SayItService.addComment (500 max).
enum CommentDraft {
    static let maxLength = 500

    static func cleaned(_ text: String) -> String {
        String(text.trimmingCharacters(in: .whitespacesAndNewlines).prefix(maxLength))
    }

    static func canSend(_ text: String) -> Bool {
        !cleaned(text).isEmpty
    }
}
