import Foundation

/// The AI moderation step the web runs before every post
/// (SayItService.buildModerationPrompt / parseJsonFromAIResponse), so posts
/// from the app get the same rating, explanation, and category.
enum Moderation {
    struct Result: Equatable {
        var rating: Int
        var explanation: String
        var category: String
    }

    static func prompt(content: String, category: String) -> String {
        let safeCategory = category.trimmingCharacters(in: .whitespaces).isEmpty ? "all" : category.trimmingCharacters(in: .whitespaces)
        let categories = PostCategory.all.map { "\"\($0)\"" }.joined(separator: ",\n")
        let message = content.split(whereSeparator: { $0.isWhitespace }).joined(separator: " ")
        return """
        Analyze the following message to determine its appropriateness for public consumption. Generate a random display name (handle-style like 'dodgebox' or 'supersavvy'). Note that 1=Acceptable, 2=Slightly Inappropriate, 3=Inappropriate, 4=Very Inappropriate, 5=Highly Inappropriate, 6=Offensive. The difference between inappropriate and offensive is that offensive is more directly hurtful/disrespectful (often toward protected groups), while inappropriate is simply not suitable for the context. Also ensure the message is categorized correctly. The user chose the \(safeCategory).
        Categories are:
        \(categories).
        Respond in this exact JSON format: {"displayName": <user name>, "category": <selectedCategory>, "rating": <1-6>, "explanation": "<brief explanation>"}. Message: "\(message)".
        """
    }

    /// Parses the model's reply: plain JSON or a ```json fenced block.
    /// Returns nil when it can't be read, in which case the post goes out
    /// unrated (the web does the same - moderation never blocks posting).
    static func parse(_ response: String, fallbackCategory: String) -> Result? {
        var text = response.trimmingCharacters(in: .whitespacesAndNewlines)
        if text.hasPrefix("```") {
            text = text
                .replacingOccurrences(of: "```json", with: "")
                .replacingOccurrences(of: "```", with: "")
                .trimmingCharacters(in: .whitespacesAndNewlines)
        }
        guard let data = text.data(using: .utf8),
              let json = (try? JSONSerialization.jsonObject(with: data)) as? [String: Any] else {
            return nil
        }

        let rating = FieldReader.int(json["rating"]) ?? 1
        let category = FieldReader.string(json["category"]).flatMap { PostCategory.all.contains($0.lowercased()) ? $0.lowercased() : nil } ?? fallbackCategory
        return Result(
            rating: min(max(rating, 1), 6),
            explanation: FieldReader.string(json["explanation"]) ?? "No issues detected.",
            category: category
        )
    }
}
