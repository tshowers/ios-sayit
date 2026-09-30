import Foundation

/// What a post is for. Nil is a plain thought, event, or update.
enum PostKind: String, Codable, CaseIterable {
    case selling
    case lookingFor = "looking-for"

    var label: String {
        switch self {
        case .selling: return "Selling"
        case .lookingFor: return "Looking for"
        }
    }

    init?(stored: String?) {
        switch stored?.lowercased().replacingOccurrences(of: "_", with: "-") {
        case "selling", "offering": self = .selling
        case "looking-for", "lookingfor", "buying", "looking": self = .lookingFor
        default: return nil
        }
    }
}

enum Formatting {
    /// 999 -> "999", 1200 -> "1.2k", 12400 -> "12k".
    static func count(_ value: Int) -> String {
        guard value >= 1000 else { return "\(value)" }
        let thousands = Double(value) / 1000
        if thousands >= 10 { return "\(Int(thousands))k" }
        let rounded = (thousands * 10).rounded(.down) / 10
        return rounded == rounded.rounded() ? "\(Int(rounded))k" : String(format: "%.1fk", rounded)
    }

    static func firstName(_ name: String) -> String {
        let trimmed = name.trimmingCharacters(in: .whitespaces)
        let beforeAt = trimmed.components(separatedBy: " at ").first ?? trimmed
        return beforeAt.split(separator: " ").first.map(String.init) ?? (trimmed.isEmpty ? "them" : trimmed)
    }

    static func initials(_ name: String) -> String {
        let beforeAt = name.components(separatedBy: " at ").first ?? name
        let letters = beforeAt.split(separator: " ").prefix(2).compactMap { $0.first }.map { String($0).uppercased() }
        return letters.isEmpty ? "?" : letters.joined()
    }
}
