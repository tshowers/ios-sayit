import Foundation

/// The web profile form's rules (ProfileIntentCardComponent.save), so a
/// profile saved from the app is accepted by the same backend endpoint.
enum ProfileValidation {
    static func validate(_ profile: SayItProfile) -> String? {
        let name = profile.displayName.trimmingCharacters(in: .whitespacesAndNewlines)
        if name.isEmpty { return "Please enter a display name." }
        if name.count < 2 { return "Display name must be at least 2 characters." }

        let intent = profile.intentText.trimmingCharacters(in: .whitespacesAndNewlines)
        if intent.isEmpty { return "Please tell people what you do or need." }
        if intent.count < 6 { return "Add a little more detail so people understand what you are trying to do." }

        let website = profile.websiteURL.trimmingCharacters(in: .whitespaces)
        if !website.isEmpty, normalizedWebsite(website) == nil {
            return "Enter a valid business website like taliferro.com, or leave it blank."
        }
        return nil
    }

    /// "taliferro.com" -> "https://taliferro.com"; nil if it isn't a
    /// plausible website. Empty input stays empty.
    static func normalizedWebsite(_ raw: String) -> String? {
        let trimmed = raw.trimmingCharacters(in: .whitespaces)
        if trimmed.isEmpty { return "" }
        let withScheme = trimmed.range(of: "^https?://", options: [.regularExpression, .caseInsensitive]) != nil ? trimmed : "https://\(trimmed)"
        guard let url = URL(string: withScheme), let host = url.host, host.contains("."),
              !host.hasPrefix("."), !host.hasSuffix("."), !host.contains(" ") else {
            return nil
        }
        return withScheme
    }
}
