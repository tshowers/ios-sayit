import Foundation
import TODDAwardsKit

/// SayIt's awards on the shared, account-synced TODDAwardsKit (backend
/// product "sayit"). The server decides what's newly unlocked, so every
/// device shows the same set and nothing is celebrated twice.
enum SayItAwards {
    static let ladder: [Award] = [
        Award(id: SayItAwardRules.opener, title: "The Opener", copy: "You said it before anyone asked you to.", symbol: "megaphone.fill"),
        Award(id: SayItAwardRules.onTheRecord, title: "On the Record", copy: "Your first post is live. The room heard you.", symbol: "checkmark.bubble.fill"),
        Award(id: SayItAwardRules.openForBusiness, title: "Open for Business", copy: "Name, pitch, done. People know who you are now.", symbol: "storefront.fill"),
        Award(id: SayItAwardRules.connector, title: "The Connector", copy: "You raised your hand for someone else's post.", symbol: "hand.raised.fill"),
        Award(id: SayItAwardRules.conversationalist, title: "The Conversationalist", copy: "You didn't just read it - you joined in.", symbol: "text.bubble.fill"),
        Award(id: SayItAwardRules.wanted, title: "Wanted", copy: "Someone's interested in what you said.", symbol: "star.fill"),
        Award(id: SayItAwardRules.inDemand, title: "In Demand", copy: "Five people raised their hands. That's a line.", symbol: "person.3.fill"),
        Award(id: SayItAwardRules.regular, title: "The Regular", copy: "Three different days, three times you showed up.", symbol: "calendar"),
        Award(id: SayItAwardRules.legend, title: "The Legend", copy: "Twenty-five posts. You're part of the furniture now.", symbol: "crown.fill", hidden: true),
    ]

    @MainActor
    static func makeService(config: AppConfig, authService: AuthService) -> AwardsService {
        AwardsService(
            appName: "Say It",
            ladder: ladder,
            api: AwardsAPI(
                baseURL: config.apiBaseURL,
                product: "sayit",
                idToken: { @MainActor [weak authService] in
                    guard let authService else { throw AuthServiceError.notSignedIn }
                    return try await authService.freshIdToken()
                }
            )
        )
    }
}

extension AwardsService {
    /// Wrote a post in the wizard, before signing in.
    func recordPostDrafted() { unlock(SayItAwardRules.opener) }
    func recordInterestSent() { unlock(SayItAwardRules.connector) }
    func recordCommented() { unlock(SayItAwardRules.conversationalist) }

    /// Everything that follows from real data (posts, interest, profile).
    func record(_ stats: SayItAwardRules.Stats) {
        SayItAwardRules.qualifying(stats).forEach { unlock($0) }
    }
}
