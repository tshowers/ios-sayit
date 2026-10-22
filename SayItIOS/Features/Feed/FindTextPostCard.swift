import SwiftUI
import UIKit

// MARK: - Find, text post

/// A text-only post in the Find feed (design_handoff_sayit_one_at_a_time 2,
/// iOS 6a/6b): everything sits inside the post's tint - type tag and •••,
/// the words as large as fit, the latest reply, the reply box, then the
/// author with Like, I'm interested and Share. iPad uses the desktop layout
/// (5a/5b): bigger words, two replies, a frame 70% of the screen tall.
struct FindTextPostCard: View {
    @ObservedObject var model: AppModel
    let post: Post
    let actions: PostActions
    var topInset: CGFloat
    @Binding var isReplying: Bool
    var push: (AppRoute) -> Void

    @State private var comments: [Comment] = []
    @State private var draft = ""
    @State private var showThread = false
    @State private var confirmDelete = false
    @FocusState private var replyFocused: Bool

    private var isPad: Bool { UIDevice.current.userInterfaceIdiom == .pad }
    private var tint: (bg: Color, fg: Color) { Theme.tint(for: post.id) }
    private var latest: [Comment] { Array(comments.suffix(isPad ? 2 : 1)) }

    /// The post's words, title and caption together.
    private var words: String {
        [post.headline, post.body].compactMap { $0 }.joined(separator: "\n")
    }

    private var firstName: String {
        Formatting.firstName(post.personName)
    }

    var body: some View {
        GeometryReader { geo in
            let top = topInset + 26
            let available = geo.size.height - top - 34
            card(wordsWidth: min(geo.size.width - 24, Theme.readableWidth) - 36)
                .frame(height: isPad ? min(available, geo.size.height * 0.7) : available)
                .postColumn()
                .padding(.horizontal, 12)
                .padding(.top, top)
                .frame(width: geo.size.width, height: geo.size.height, alignment: .top)
        }
        .background(Theme.stage)
        .task(id: post.id) { await loadComments() }
        .onChange(of: replyFocused) { _, focused in isReplying = focused }
        .sheet(isPresented: $showThread) {
            NavigationStack { PostDetailView(model: model, postId: post.id) }
        }
        .confirmationDialog("Delete this post?", isPresented: $confirmDelete, titleVisibility: .visible) {
            Button("Delete", role: .destructive) { Task { try? await model.repository.deletePost(post) } }
        }
    }

    private func card(wordsWidth: CGFloat) -> some View {
        VStack(alignment: .leading, spacing: 16) {
            topRow
            wordsBlock(width: wordsWidth)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                .onTapGesture(perform: actions.openPost)
            replies
            replyBox
            author
        }
        .padding(18)
        .foregroundStyle(tint.fg)
        .background(tint.bg, in: RoundedRectangle(cornerRadius: 28, style: .continuous))
    }

    // MARK: Top row

    private var topRow: some View {
        HStack {
            if let tag = typeTag {
                Text(tag)
                    .font(Theme.body(13, .bold))
                    .padding(.horizontal, 12).frame(height: 30)
                    .background(Theme.ground, in: Capsule())
            }
            Spacer()
            Menu {
                Button("Open", systemImage: "arrow.up.right.square", action: actions.openPost)
                Button("Copy link", systemImage: "link") {
                    UIPasteboard.general.url = actions.shareURL
                    model.showToast("Link copied")
                }
                if actions.isOwn {
                    Button("Delete", systemImage: "trash", role: .destructive) { confirmDelete = true }
                }
            } label: {
                Image(systemName: "ellipsis")
                    .font(.system(size: 15, weight: .bold))
                    .foregroundStyle(Theme.text)
                    .frame(width: 36, height: 36)
                    .background(Theme.ground, in: Circle())
            }
            .accessibilityLabel("More")
        }
    }

    /// Selling / Looking for when the post says, otherwise its category (as on the web).
    private var typeTag: String? {
        if let kind = post.kind { return kind.label }
        let category = post.category.trimmingCharacters(in: .whitespaces)
        return category.isEmpty || category.lowercased() == "all" ? nil : PostCategory.label(for: category)
    }

    // MARK: Words

    /// The largest size that fits: 40 → 32 → 26 → 22 (32 first with replies),
    /// then 22 clamped with "Read more". iPad starts at 64 / 52.
    /// Sizes where even the longest word ("#SustainableShipping") fits on a
    /// line are tried; a word never breaks mid-word.
    @ViewBuilder
    private func wordsBlock(width: CGFloat) -> some View {
        let all: [CGFloat] = isPad
            ? (comments.isEmpty ? [64, 52, 40, 32] : [52, 40, 32])
            : (comments.isEmpty ? [40, 32, 26, 22] : [32, 26, 22])
        let fitting = all.filter { longestWordWidth(at: $0) <= width }
        let sizes = fitting.isEmpty ? [all.last ?? 22] : fitting
        ViewThatFits(in: .vertical) {
            wordsText(sizes[0])
            if sizes.count > 1 { wordsText(sizes[1]) }
            if sizes.count > 2 { wordsText(sizes[2]) }
            if sizes.count > 3 { wordsText(sizes[3]) }
            VStack(alignment: .leading, spacing: 6) {
                Text(words)
                    .font(wordsFont(sizes.last ?? 22))
                    .tracking(-0.035 * (sizes.last ?? 22))
                    .frame(maxHeight: .infinity, alignment: .topLeading)
                Button("Read more", action: actions.openPost)
                    .font(Theme.body(14, .bold))
            }
        }
    }

    private func longestWordWidth(at size: CGFloat) -> CGFloat {
        guard let font = UIFont(name: "HelveticaNeue-Bold", size: size) else { return 0 }
        return words.split(whereSeparator: \.isWhitespace).map { word in
            let text = String(word)
            return (text as NSString).size(withAttributes: [.font: font]).width - 0.035 * size * CGFloat(text.count)
        }.max() ?? 0
    }

    private func wordsText(_ size: CGFloat) -> some View {
        Text(words)
            .font(wordsFont(size))
            .tracking(-0.035 * size)
            .fixedSize(horizontal: false, vertical: true)
    }

    private func wordsFont(_ size: CGFloat) -> Font {
        .custom("HelveticaNeue-Bold", size: size, relativeTo: .largeTitle)
    }

    // MARK: Replies

    @ViewBuilder
    private var replies: some View {
        if !latest.isEmpty {
            VStack(alignment: .leading, spacing: 8) {
                ForEach(latest) { comment in
                    replyRow(comment)
                }
                if comments.count > latest.count {
                    Button("See all \(comments.count) replies") { showThread = true }
                        .font(Theme.body(14, .bold))
                        .padding(.leading, 4)
                }
            }
        }
    }

    private func replyRow(_ comment: Comment) -> some View {
        let avatarTint = Theme.tint(for: comment.authorDisplayName)
        return HStack(alignment: .top, spacing: 10) {
            Text(Formatting.initials(comment.authorDisplayName))
                .font(Theme.body(11, .bold))
                .foregroundStyle(avatarTint.fg)
                .frame(width: 30, height: 30)
                .background(avatarTint.bg, in: Circle())
            VStack(alignment: .leading, spacing: 2) {
                (Text(comment.authorDisplayName).font(Theme.body(14, .bold)).foregroundColor(Theme.text)
                 + Text(comment.createdAt.map { " · \(relativeTime($0))" } ?? "").font(Theme.body(14)).foregroundColor(Theme.neutral700))
                    .lineLimit(1)
                Text(comment.content)
                    .font(Theme.body(14))
                    .foregroundStyle(Theme.text)
                    .lineLimit(3)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer(minLength: 0)
        }
        .padding(.horizontal, 14).padding(.vertical, 12)
        .background(Theme.ground, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
        .accessibilityElement(children: .combine)
    }

    // MARK: Reply box

    private var replyBox: some View {
        HStack(spacing: 8) {
            TextField(comments.isEmpty ? "Be the first to reply…" : "Reply to \(firstName)…", text: $draft)
                .font(Theme.body(15))
                .foregroundStyle(Theme.text)
                .focused($replyFocused)
                .submitLabel(.send)
                .onSubmit { Task { await send() } }
                .onTapGesture {
                    if !model.canParticipate { replyFocused = false; push(.signIn) }
                }
            Button {
                Task { await send() }
            } label: {
                Image(systemName: "arrow.up")
                    .font(.system(size: 16, weight: .bold))
                    .foregroundStyle(Theme.cream)
                    .frame(width: 40, height: 40)
                    .background(Theme.accent600, in: Circle())
                    .opacity(CommentDraft.canSend(draft) ? 1 : 0.45)
            }
            .disabled(!CommentDraft.canSend(draft))
            .accessibilityLabel("Send reply")
        }
        .padding(.leading, 18).padding(.trailing, 4).padding(.vertical, 4)
        .background(Theme.ground, in: Capsule())
    }

    // MARK: Author

    private var author: some View {
        VStack(alignment: .leading, spacing: 12) {
            Button(action: actions.openOrg) {
                HStack(spacing: 10) {
                    authorAvatar
                    VStack(alignment: .leading, spacing: 1) {
                        Text(post.orgLabel.map { "\(post.personName) at \($0)" } ?? post.personName)
                            .font(Theme.body(15, .bold)).foregroundStyle(Theme.text).lineLimit(1)
                        Text([categoryLabel, relativeTime(post.timestamp)].compactMap { $0?.isEmpty == false ? $0 : nil }.joined(separator: " · "))
                            .font(Theme.body(13)).foregroundStyle(Theme.neutral700).lineLimit(1)
                    }
                }
            }
            .buttonStyle(.plain)
            HStack(spacing: 8) {
                Button(action: actions.like) {
                    HStack(spacing: 6) {
                        Image(systemName: actions.isLiked ? "heart.fill" : "heart")
                        Text(Formatting.count(actions.likeCount)).font(Theme.body(15, .bold))
                    }
                    .foregroundStyle(actions.isLiked ? Theme.tints[5].fg : Theme.text)
                    .padding(.horizontal, 16).frame(height: 44)
                    .background(actions.isLiked ? Theme.tints[5].bg : Theme.ground, in: Capsule())
                }
                .buttonStyle(PressScaleStyle())
                .accessibilityLabel(actions.isLiked ? "Unlike, \(actions.likeCount) likes" : "Like, \(actions.likeCount) likes")
                InterestedButton(actions: actions, height: 44, font: Theme.body(15, .bold))
                ShareLink(item: actions.shareURL) {
                    Label("Share", systemImage: "paperplane")
                        .font(Theme.body(15, .bold))
                        .foregroundStyle(Theme.ground)
                        .padding(.horizontal, 16).frame(height: 44)
                        .background(Theme.text, in: Capsule())
                }
            }
        }
    }

    private var categoryLabel: String? {
        let category = post.category.trimmingCharacters(in: .whitespaces)
        return category.isEmpty || category.lowercased() == "all" ? nil : PostCategory.label(for: category)
    }

    @ViewBuilder
    private var authorAvatar: some View {
        if post.photoURL != nil {
            RingAvatar(name: post.personName, photoURL: post.photoURL, size: 40)
        } else {
            Text(Formatting.initials(post.personName))
                .font(Theme.body(14, .bold))
                .foregroundStyle(tint.fg)
                .frame(width: 40, height: 40)
                .background(Theme.ground, in: Circle())
        }
    }

    // MARK: Data

    private func loadComments() async {
        comments = (try? await model.repository.comments(postId: post.id)) ?? []
    }

    /// Adds the reply at once; the reload swaps in the saved copy.
    @MainActor
    private func send() async {
        guard model.canParticipate else { push(.signIn); return }
        guard model.hasAcceptedGuidelines else { push(.guidelines); return }
        let text = draft.trimmingCharacters(in: .whitespacesAndNewlines)
        guard CommentDraft.canSend(text) else { return }
        let pending = Comment(id: "pending-\(UUID().uuidString)", postId: post.id, authorUid: model.auth.userId ?? "",
                              authorDisplayName: model.displayName, content: text, createdAt: Date())
        comments.append(pending)
        draft = ""
        replyFocused = false
        do {
            _ = try await model.screen(text, category: "comment")
            try await model.repository.addComment(postId: post.id, content: text, displayName: model.displayName)
            model.awards.recordCommented()
            comments = (try? await model.repository.comments(postId: post.id)) ?? comments
        } catch {
            comments.removeAll { $0.id == pending.id }
            draft = text
            model.showToast(error.localizedDescription)
        }
    }
}
