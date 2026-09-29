import Foundation

/// Answers from the pre-sign-in wizard: a first post plus who's posting it.
/// Persisted in UserDefaults so quitting mid-wizard resumes where it left
/// off and a failed save after sign-in retries on the next launch. Mirrors
/// the web's SayItOnboardingService (web-products/sayit).
struct OnboardingDraft: Codable, Equatable {
    enum Intent: String, Codable, CaseIterable {
        case looking, offering

        var label: String {
            switch self {
            case .looking: return "I'm looking for something"
            case .offering: return "I'm offering something"
            }
        }

        var topicQuestion: String {
            self == .looking ? "What are you looking for?" : "What are you offering?"
        }

        var topicOptions: [String] {
            switch self {
            case .looking: return ["A supplier", "A contractor", "A service provider", "Referrals", "A business partner"]
            case .offering: return ["My services", "My products", "Help with projects", "A partnership", "Referrals"]
            }
        }
    }

    var intent: Intent = .looking
    var topic: String = Intent.looking.topicOptions[0]
    var category = "all"
    var postText = ""
    /// Once they edit the post we stop rewriting it from their answers.
    var postTextEdited = false
    var firstName = ""
    var lastName = ""
    var businessName = ""
    /// Set on reaching the sign-in step - an abandoned draft is never submitted.
    var isReadyToSubmit = false
    /// Set as each post-sign-in step succeeds, so a retry never repeats it.
    var profileSaved = false
    var publishedPostId: String?

    init() {
        postText = suggestedPost
    }

    var hasCustomTopic: Bool { !intent.topicOptions.contains(topic) }

    /// "Looking for a supplier in retail. Any recommendations?"
    var suggestedPost: String {
        let raw = topic.trimmingCharacters(in: .whitespacesAndNewlines)
        let fallback = intent == .looking ? "help" : "my services"
        let what = raw.isEmpty ? fallback : raw.prefix(1).lowercased() + raw.dropFirst()
        let industry = category == "all" ? "" : " in \(PostCategory.label(for: category).lowercased())"
        let text = intent == .looking
            ? "Looking for \(what)\(industry). Any recommendations?"
            : "Offering \(what)\(industry). Happy to help - reach out!"
        return String(text.prefix(PostDraft.maxLength))
    }

    /// Call after changing intent, topic, or category.
    mutating func refreshSuggestedPost() {
        if !postTextEdited { postText = suggestedPost }
    }

    mutating func select(intent newIntent: Intent) {
        guard newIntent != intent else { return }
        intent = newIntent
        topic = newIntent.topicOptions[0]
        refreshSuggestedPost()
    }

    /// "Ada at Analytical Co", else "Ada Lovelace" - the feed's style.
    var displayName: String {
        let first = firstName.trimmingCharacters(in: .whitespaces)
        let business = businessName.trimmingCharacters(in: .whitespaces)
        if !first.isEmpty && !business.isEmpty { return "\(first) at \(business)" }
        let full = [first, lastName.trimmingCharacters(in: .whitespaces)].filter { !$0.isEmpty }.joined(separator: " ")
        return full.isEmpty ? "User" : full
    }

    /// The SayIt profile this draft fills in for a brand-new member.
    func profile(uid: String) -> SayItProfile {
        var profile = SayItProfile(uid: uid)
        profile.displayName = displayName
        profile.intentText = PostDraft.cleaned(postText)
        profile.businessName = businessName.trimmingCharacters(in: .whitespaces)
        if category != "all" { profile.businessCategory = PostCategory.label(for: category) }
        return profile
    }

    /// Body for `POST /api/onboarding/profile` (fills blank TODD profile fields only).
    var toddProfileRequestBody: [String: Any] {
        [
            "source": "sayit-ios",
            "profile": [
                "firstName": firstName.trimmingCharacters(in: .whitespaces),
                "lastName": lastName.trimmingCharacters(in: .whitespaces),
                "companyName": businessName.trimmingCharacters(in: .whitespaces),
            ],
        ]
    }

    // MARK: Persistence

    static let storageKey = "sayit.onboardingDraft"

    static func load(from defaults: UserDefaults = .standard) -> OnboardingDraft {
        guard let data = defaults.data(forKey: storageKey),
              let draft = try? JSONDecoder().decode(OnboardingDraft.self, from: data) else {
            return OnboardingDraft()
        }
        return draft
    }

    func save(to defaults: UserDefaults = .standard) {
        if let data = try? JSONEncoder().encode(self) {
            defaults.set(data, forKey: Self.storageKey)
        }
    }

    static func clear(from defaults: UserDefaults = .standard) {
        defaults.removeObject(forKey: storageKey)
    }
}
