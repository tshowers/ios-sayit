import Foundation

/// The categories the web composer and AI moderation prompt use.
enum PostCategory {
    static let all: [String] = [
        "all", "construction", "trucking-logistics", "manufacturing", "retail", "ecommerce",
        "real-estate", "food-beverage", "hospitality", "professional-services", "marketing",
        "technology", "healthcare", "finance", "education", "automotive", "energy",
        "government-contracting", "nonprofit", "agriculture",
    ]

    /// "trucking-logistics" -> "Trucking Logistics", "all" -> "Everything".
    static func label(for category: String) -> String {
        let normalized = category.trimmingCharacters(in: .whitespaces).lowercased()
        if normalized.isEmpty || normalized == "all" { return "Everything" }
        return normalized
            .split(separator: "-")
            .map { $0.prefix(1).uppercased() + $0.dropFirst() }
            .joined(separator: " ")
    }
}
