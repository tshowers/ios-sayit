import Foundation
import FirebaseFirestore

/// App-wide state shared by every tab: the signed-in person's SayIt profile,
/// who they've blocked, whether they've accepted the community guidelines,
/// the live feed, and a post opened from a link.
@MainActor
final class AppModel: ObservableObject {
    let config: AppConfig
    let auth: AuthService
    let repository: SayItRepository
    let backend: BackendClient

    @Published private(set) var posts: [Post] = []
    @Published private(set) var feedError: String?
    @Published private(set) var isFeedLoading = true
    @Published private(set) var profile: SayItProfile?
    @Published private(set) var blockedUids: Set<String> = []
    @Published private(set) var unreadInterestCount = 0
    @Published var termsAccepted: Bool {
        didSet { UserDefaults.standard.set(termsAccepted, forKey: Self.termsKey) }
    }
    /// Set when a sayit.taliferro.tech/post/<id> link opens the app.
    @Published var linkedPostId: String?

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
        self.termsAccepted = UserDefaults.standard.bool(forKey: Self.termsKey)
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

    // MARK: Signed-in person

    /// The name posts and comments go out under: the SayIt profile's display
    /// name, else the account's name or email.
    var displayName: String {
        let name = profile?.displayName.trimmingCharacters(in: .whitespaces) ?? ""
        return name.isEmpty ? auth.fallbackDisplayName : name
    }

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
        await refreshUnreadInterests()
    }

    func refreshUnreadInterests() async {
        guard let uid = auth.userId, let interests = try? await repository.interests(forAuthor: uid) else { return }
        unreadInterestCount = interests.filter { !$0.viewed }.count
    }

    func profileSaved(_ saved: SayItProfile) {
        var updated = saved
        updated.blockedUids = Array(blockedUids)
        profile = updated
    }

    func postURL(for post: Post) -> URL {
        PostLinks.url(forPostId: post.id, base: config.webBaseURL)
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
