import Foundation
import FirebaseFirestore
import TODDAwardsKit

/// Every page the app pushes. Nothing is presented as a sheet or popup
/// (playbook: "No popups. Pages push").
enum AppRoute: Hashable {
    case post(String)
    case compose
    case report(Post)
    case signIn
    case guidelines
    case profileEditor
    case account
    case blocked
    case awards
}

enum AppTab: Hashable {
    case feed, interest, me
}

/// App-wide state shared by every tab: the live feed, the signed-in
/// person's SayIt profile and blocks, awards, the pre-sign-in wizard's
/// draft, and navigation for links opened from outside the app.
@MainActor
final class AppModel: ObservableObject {
    let config: AppConfig
    let auth: AuthService
    let repository: SayItRepository
    let backend: BackendClient
    let awards: AwardsService

    @Published private(set) var posts: [Post] = []
    @Published private(set) var feedError: String?
    @Published private(set) var isFeedLoading = true
    @Published private(set) var profile: SayItProfile?
    @Published private(set) var blockedUids: Set<String> = []
    @Published private(set) var unreadInterestCount = 0
    /// Signed-out visitors see the wizard first; "Just browse" skips to the feed.
    @Published var isBrowsingAsGuest: Bool {
        didSet { UserDefaults.standard.set(isBrowsingAsGuest, forKey: Self.browseKey) }
    }
    @Published var selectedTab: AppTab = .feed
    @Published var feedPath: [AppRoute] = []
    /// True while the wizard's post is being saved right after sign-in.
    @Published private(set) var isPublishingDraft = false

    private static let browseKey = "sayit.browsingAsGuest"
    private static let termsKey = "sayit.communityGuidelinesAccepted.v1"
    private var feedListener: ListenerRegistration?

    init(config: AppConfig, auth: AuthService) {
        self.config = config
        self.auth = auth
        self.repository = SayItRepository(config: config)
        self.backend = BackendClient(config: config, idToken: { [weak auth] in
            guard let auth else { throw AuthServiceError.notSignedIn }
            return try await auth.freshIdToken()
        })
        self.awards = SayItAwards.makeService(config: config, authService: auth)
        self.isBrowsingAsGuest = UserDefaults.standard.bool(forKey: Self.browseKey)
    }

    // MARK: Feed

    func startFeed() {
        guard feedListener == nil else { return }
        feedListener = repository.listenToPosts { [weak self] result in
            Task { @MainActor in
                guard let self else { return }
                self.isFeedLoading = false
                switch result {
                case .success(let posts):
                    self.posts = posts
                    self.feedError = nil
                case .failure(let error):
                    self.feedError = error.localizedDescription
                }
            }
        }
    }

    /// Opens a post on the Feed tab - from a Universal Link or right after
    /// the wizard's post goes live.
    func openPost(_ id: String) {
        // A shared link should show the post, not the wizard.
        if !auth.isSignedIn { isBrowsingAsGuest = true }
        selectedTab = .feed
        feedPath = [.post(id)]
    }

    func postURL(for post: Post) -> URL {
        PostLinks.url(forPostId: post.id, base: config.webBaseURL)
    }

    // MARK: Signed-in person

    /// The name posts and comments go out under: the SayIt profile's display
    /// name, else the account's name or email.
    var displayName: String {
        let name = profile?.displayName.trimmingCharacters(in: .whitespaces) ?? ""
        return name.isEmpty ? auth.fallbackDisplayName : name
    }

    var canParticipate: Bool { auth.isSignedIn }

    /// Signing in shows the community guidelines agreement (SignInView), so
    /// every sign-in records acceptance.
    func recordGuidelinesAccepted() {
        UserDefaults.standard.set(true, forKey: Self.termsKey)
    }

    /// Runs at launch and whenever the signed-in account changes.
    func refreshAccount() async {
        guard let uid = auth.userId else {
            profile = nil
            blockedUids = []
            unreadInterestCount = 0
            return
        }
        if let loaded = try? await repository.profile(uid: uid) {
            profile = loaded
            blockedUids = Set(loaded.blockedUids)
        } else {
            profile = SayItProfile(uid: uid)
        }
        // Server awards first, so nothing already earned elsewhere is re-celebrated.
        await awards.sync()
        await submitOnboardingDraftIfNeeded()
        await refreshUnreadInterests()
        await refreshAwardStats()
    }

    func refreshUnreadInterests() async {
        guard let uid = auth.userId, let interests = try? await repository.interests(forAuthor: uid) else { return }
        unreadInterestCount = interests.filter { !$0.viewed }.count
    }

    func profileSaved(_ saved: SayItProfile) {
        var updated = saved
        updated.blockedUids = Array(blockedUids)
        profile = updated
        Task { await refreshAwardStats() }
    }

    /// Checks the data-driven awards (posts, interest received, profile).
    func refreshAwardStats() async {
        guard let uid = auth.userId else { return }
        let dates = (try? await repository.postDates(authorUid: uid)) ?? []
        let interestCount = (try? await repository.interests(forAuthor: uid).count) ?? 0
        awards.record(.init(postDates: dates, interestReceived: interestCount, profileComplete: profile?.isComplete == true))
    }

    // MARK: Pre-sign-in wizard

    /// Saves what the wizard built once its author has signed in: the TODD
    /// profile (blank fields only), the SayIt profile (only if not already
    /// complete), then the post itself - which then opens. Each finished
    /// step is recorded, so a failure retries on the next launch without
    /// repeating anything. Never throws.
    func submitOnboardingDraftIfNeeded() async {
        var draft = OnboardingDraft.load()
        guard draft.isReadyToSubmit, let uid = auth.userId, !isPublishingDraft else { return }
        isPublishingDraft = true
        defer { isPublishingDraft = false }

        do {
            if !draft.profileSaved {
                // The shared TODD profile must not hold up the SayIt profile or post.
                try? await backend.submitOnboardingProfile(draft.toddProfileRequestBody)
                if profile?.isComplete != true {
                    let newProfile = draft.profile(uid: uid)
                    try await backend.saveProfile(newProfile, email: auth.currentUser?.email)
                    profileSaved(newProfile)
                }
                draft.profileSaved = true
                draft.save()
            }

            if draft.publishedPostId == nil {
                let content = PostDraft.cleaned(draft.postText)
                if !content.isEmpty {
                    let moderation = await backend.moderate(content: content, category: draft.category)
                    draft.publishedPostId = try await repository.publish(.init(
                        content: content,
                        category: draft.category,
                        displayName: displayName,
                        photoURL: profile?.photoURL ?? auth.currentUser?.photoURL?.absoluteString,
                        authorHandle: profile?.handle,
                        moderation: moderation
                    ))
                    draft.save()
                }
            }

            OnboardingDraft.clear()
            isBrowsingAsGuest = false
            if let postId = draft.publishedPostId { openPost(postId) }
        } catch {
            // Draft kept (with finished steps marked); retried next launch.
        }
    }

    // MARK: Blocking

    func block(_ uid: String) async throws {
        try await updateBlocks(blockedUids.union([uid]))
    }

    func unblock(_ uid: String) async throws {
        try await updateBlocks(blockedUids.subtracting([uid]))
    }

    private func updateBlocks(_ updated: Set<String>) async throws {
        guard let me = auth.userId else { throw AuthServiceError.notSignedIn }
        let previous = blockedUids
        blockedUids = updated
        do {
            try await repository.setBlockedUids(updated.sorted(), for: me)
        } catch {
            blockedUids = previous
            throw error
        }
    }
}
