import Foundation
import FirebaseFirestore
import TODDAwardsKit

/// Every page the app pushes. Nothing is presented as a sheet or popup
/// (playbook: "No popups. Pages push").
enum AppRoute: Hashable {
    case post(String)
    /// The feed pager opened at a specific post (from an org's grid).
    case feedAt([Post], Int)
    case thread(String)
    case org(Org)
    case me
    case layoutPicker
    case search
    case compose
    case report(Post)
    case signIn
    case guidelines
    case profileEditor
    case account
    case blocked
    case awards
}

/// The design's top tabs: For you / Orgs / Inbox.
enum AppTab: Hashable {
    case feed, orgs, inbox
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
    @Published private(set) var likedPostIds: Set<String> = []
    /// Post id -> the `post-interests` doc that says I'm interested in it.
    @Published private(set) var interestedPosts: [String: String] = [:]
    @Published private(set) var threads: [ChatThread] = []
    @Published private(set) var orgs: [Org] = []
    @Published var toast: String?
    private var threadsListener: ListenerRegistration?
    private var toastTask: Task<Void, Never>?

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
        threadsListener?.remove()
        threadsListener = nil
        guard let uid = auth.userId else {
            profile = nil
            blockedUids = []
            unreadInterestCount = 0
            likedPostIds = []
            interestedPosts = [:]
            threads = []
            return
        }
        if let loaded = try? await repository.profile(uid: uid) {
            profile = loaded
            blockedUids = Set(loaded.blockedUids)
            likedPostIds = Set(loaded.favoritePostIds)
        } else {
            profile = SayItProfile(uid: uid)
        }
        interestedPosts = (try? await repository.myInterests(uid: uid)) ?? [:]
        threadsListener = repository.listenToThreads(uid: uid) { [weak self] threads in
            Task { @MainActor in self?.threads = threads }
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
        pendingInterestThreads = interests
            .filter { interest in !blockedUids.contains(interest.interestedUid) }
            .map { interest in
                ChatThread(
                    id: ChatThread.id(postId: interest.postId, interestedUid: interest.interestedUid),
                    postId: interest.postId,
                    postTitle: interest.postPreview ?? "",
                    authorUid: uid,
                    interestedUid: interest.interestedUid,
                    people: [interest.interestedUid: .init(name: interest.interestedDisplayName, org: "", role: "",
                                                           photoURL: interest.interestedPhotoURL, email: interest.interestedEmail)],
                    lastMessage: interest.message ?? "Interested in your post",
                    lastMessageAt: interest.createdAt,
                    unread: [uid: interest.viewed ? 0 : 1]
                )
            }
    }

    /// Interest sent before messaging existed (or from the web) has no
    /// thread yet; it shows in the Inbox and becomes one on first reply.
    @Published private(set) var pendingInterestThreads: [ChatThread] = []

    // MARK: Layout

    var feedLayout: FeedLayout { profile?.feedLayout ?? storedLayout ?? .default }

    private var storedLayout: FeedLayout? {
        UserDefaults.standard.string(forKey: "sayit.feedLayout").flatMap(FeedLayout.init(rawValue:))
    }

    func setFeedLayout(_ layout: FeedLayout) {
        UserDefaults.standard.set(layout.rawValue, forKey: "sayit.feedLayout")
        objectWillChange.send()
        guard let uid = auth.userId else { return }
        profile?.feedLayout = layout
        Task { try? await repository.updateProfile(uid: uid, fields: ["feedLayout": layout.rawValue]) }
    }

    private func logLayout(_ action: String, postId: String) {
        guard let uid = auth.userId else { return }
        repository.logLayoutEvent(uid: uid, layout: feedLayout, action: action, postId: postId)
    }

    // MARK: Toast

    func showToast(_ message: String) {
        toast = message
        toastTask?.cancel()
        toastTask = Task { [weak self] in
            try? await Task.sleep(for: .seconds(2.4))
            guard !Task.isCancelled else { return }
            self?.toast = nil
        }
    }

    // MARK: Likes & interest

    func isLiked(_ post: Post) -> Bool { likedPostIds.contains(post.id) }
    func isInterested(_ post: Post) -> Bool { interestedPosts[post.id] != nil }

    /// Count shown under the heart, including my own like right away.
    func likeCount(_ post: Post) -> Int {
        let stored = post.likeCount
        let mine = auth.userId.map { post.favoriteUserIds.contains($0) } ?? false
        return stored + (isLiked(post) && !mine ? 1 : 0) - (!isLiked(post) && mine ? 1 : 0)
    }

    func toggleLike(_ post: Post) {
        guard let uid = auth.userId else { return }
        let liked = !isLiked(post)
        if liked { likedPostIds.insert(post.id) } else { likedPostIds.remove(post.id) }
        if liked { logLayout("like", postId: post.id) }
        Task {
            do { try await repository.setLiked(liked, post: post, uid: uid) } catch {
                if liked { likedPostIds.remove(post.id) } else { likedPostIds.insert(post.id) }
            }
        }
    }

    /// "I'm interested" on: records the interest and opens (or reopens) the
    /// conversation with the author. Off: withdraws the interest but keeps
    /// the conversation and its messages.
    func toggleInterest(_ post: Post) async {
        guard let uid = auth.userId, let author = post.authorUid, author != uid else { return }
        let threadId = ChatThread.id(postId: post.id, interestedUid: uid)

        if let docId = interestedPosts[post.id] {
            interestedPosts[post.id] = nil
            showToast("Removed from inbox")
            do {
                try await repository.withdrawInterest(docId: docId)
                try? await repository.setInterestActive(false, threadId: threadId)
            } catch {
                interestedPosts[post.id] = docId
            }
            return
        }

        interestedPosts[post.id] = "pending"
        showToast("Added to inbox · message \(Formatting.firstName(post.personName))")
        logLayout("interested", postId: post.id)
        do {
            interestedPosts[post.id] = try await repository.expressInterest(in: post, displayName: displayName, postURL: postURL(for: post))
            try await repository.ensureThread(newThread(for: post, me: uid, author: author), systemNote: "\(displayName) tapped I'm interested")
            awards.recordInterestSent()
        } catch {
            if interestedPosts[post.id] == "pending" { interestedPosts[post.id] = nil }
            showToast("Couldn't add it - try again")
        }
    }

    private func newThread(for post: Post, me: String, author: String) -> ChatThread {
        ChatThread(
            id: ChatThread.id(postId: post.id, interestedUid: me),
            postId: post.id,
            postTitle: post.headline,
            postKind: post.kind,
            postPrice: post.price,
            postImageURL: post.imageURL,
            authorUid: author,
            interestedUid: me,
            people: [
                author: .init(name: post.personName, org: post.orgLabel ?? "", role: post.authorRole ?? "", photoURL: post.photoURL, email: post.authorEmail),
                me: .init(name: displayName, org: profile?.businessName ?? "", role: profile?.role ?? "",
                          photoURL: profile?.photoURL ?? auth.currentUser?.photoURL?.absoluteString, email: auth.currentUser?.email),
            ]
        )
    }

    // MARK: Inbox

    /// Real threads plus interest that doesn't have a thread yet.
    var inboxThreads: [ChatThread] {
        let ids = Set(threads.map(\.id))
        let visible = threads.filter { thread in
            guard let me = auth.userId else { return false }
            return !blockedUids.contains(thread.otherUid(me: me))
        }
        return visible + pendingInterestThreads.filter { !ids.contains($0.id) }
    }

    var unreadThreadCount: Int {
        guard let me = auth.userId else { return 0 }
        return InboxRules.unreadThreads(inboxThreads, me: me)
    }

    func thread(id: String) -> ChatThread? { inboxThreads.first { $0.id == id } }

    /// Sends a message, creating the thread first when it only exists as
    /// interest (the author's first reply), and emails the other person on
    /// their first unread message.
    func send(_ text: String, in thread: ChatThread) async throws {
        guard let me = auth.userId else { throw AuthServiceError.notSignedIn }
        if !threads.contains(where: { $0.id == thread.id }) {
            var created = thread
            created.people[me] = .init(name: displayName, org: profile?.businessName ?? "", role: profile?.role ?? "",
                                       photoURL: profile?.photoURL, email: auth.currentUser?.email)
            try await repository.ensureThread(created, systemNote: nil)
        }
        let unreadBefore = try await repository.send(text, in: thread, layout: feedLayout)
        logLayout("message", postId: thread.postId)
        let other = thread.other(me: me)
        if InboxRules.shouldEmail(recipientUnreadBefore: unreadBefore), let email = other.email, !email.isEmpty {
            let url = PostLinks.url(forPostId: thread.postId, base: config.webBaseURL)
            Task { await backend.notifyNewMessage(to: email, from: displayName, postTitle: thread.postTitle, text: InboxRules.cleaned(text), postURL: url) }
        }
    }

    func markRead(_ thread: ChatThread) {
        guard let me = auth.userId, thread.unreadCount(for: me) > 0 else { return }
        if threads.contains(where: { $0.id == thread.id }) {
            Task { try? await repository.markRead(threadId: thread.id, uid: me) }
        }
    }

    // MARK: Orgs

    func loadOrgs() async {
        guard auth.isSignedIn, let profiles = try? await repository.publicProfiles() else { return }
        orgs = OrgDirectory.orgs(from: profiles)
    }

    func org(named name: String?) -> Org? {
        guard let name, !name.isEmpty else { return nil }
        let id = OrgDirectory.slug(name)
        return orgs.first { $0.id == id }
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

            try? await repository.updateProfile(uid: uid, fields: ["feedLayout": draft.feedLayout.rawValue])
            profile?.feedLayout = draft.feedLayout
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
