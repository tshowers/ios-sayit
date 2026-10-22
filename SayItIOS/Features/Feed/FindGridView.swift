import SwiftUI

// MARK: - Find grid

/// The Find feed as a scrolling grid, matching the web board's Grid view:
/// one card across on iPhone, more on iPad. Tapping a card opens it in One
/// at a time.
struct FindGridView: View {
    @ObservedObject var model: AppModel
    let posts: [Post]
    var topInset: CGFloat
    /// Opens One at a time at this post.
    var open: (Int) -> Void

    var body: some View {
        ScrollView {
            if posts.isEmpty {
                Text(model.isFeedLoading ? "Loading posts…" : "No posts yet")
                    .font(Theme.body(15)).foregroundStyle(Theme.neutral700)
                    .padding(.top, 80)
            } else {
                LazyVGrid(columns: [GridItem(.adaptive(minimum: 300), spacing: 12, alignment: .top)], spacing: 12) {
                    ForEach(Array(posts.enumerated()), id: \.element.id) { index, post in
                        FindGridCard(model: model, post: post) { open(index) }
                    }
                }
                .padding(.horizontal, 12)
                .padding(.bottom, 24)
            }
        }
        .contentMargins(.top, topInset, for: .scrollContent)
        .background(Theme.stage)
    }
}

/// One post in the grid: the photo, or the post's tint with its words, then
/// the author, like / share and I'm interested.
struct FindGridCard: View {
    @ObservedObject var model: AppModel
    let post: Post
    var open: () -> Void

    private var tint: (bg: Color, fg: Color) { Theme.tint(for: post.id) }
    private var hasPhoto: Bool { post.imageURL != nil }

    private var actions: PostActions {
        PostActions(
            isLiked: model.isLiked(post),
            likeCount: model.likeCount(post),
            isInterested: model.isInterested(post),
            isOwn: post.authorUid != nil && post.authorUid == model.auth.userId,
            canBeInterested: post.authorUid != nil && !post.isSystemPost,
            shareURL: model.postURL(for: post),
            like: { signedIn { model.toggleLike(post) } },
            interested: { signedIn { Task { await model.toggleInterest(post) } } },
            openOrg: open,
            openPost: open,
            play: { _ in open() },
            counter: ""
        )
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            hero
                .frame(height: 200)
                .frame(maxWidth: .infinity)
                .clipped()
                .contentShape(Rectangle())
                .onTapGesture(perform: open)
            VStack(alignment: .leading, spacing: 12) {
                author
                if hasPhoto {
                    Text(post.headline)
                        .font(Theme.body(15, .bold)).foregroundStyle(Theme.text)
                        .lineLimit(3)
                        .onTapGesture(perform: open)
                }
                HStack(spacing: 8) {
                    Button(action: actions.like) {
                        HStack(spacing: 6) {
                            Image(systemName: actions.isLiked ? "heart.fill" : "heart")
                            Text(Formatting.count(actions.likeCount)).font(Theme.body(14, .bold))
                        }
                        .foregroundStyle(actions.isLiked ? Theme.tints[5].fg : Theme.text)
                        .padding(.horizontal, 14).frame(height: 38)
                        .background(actions.isLiked ? Theme.tints[5].bg : Theme.ground, in: Capsule())
                    }
                    .buttonStyle(PressScaleStyle())
                    .accessibilityLabel(actions.isLiked ? "Unlike, \(actions.likeCount) likes" : "Like, \(actions.likeCount) likes")
                    ShareLink(item: actions.shareURL) {
                        Label("Share", systemImage: "paperplane.fill")
                            .font(Theme.body(14, .bold)).foregroundStyle(Theme.text)
                            .padding(.horizontal, 14).frame(height: 38)
                            .background(Theme.ground, in: Capsule())
                    }
                }
                InterestedButton(actions: actions, height: 44, font: Theme.body(15, .bold))
            }
            .padding(14)
        }
        .background(Theme.surface)
        .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
    }

    @ViewBuilder
    private var hero: some View {
        if hasPhoto {
            ZStack {
                PostMedia(url: post.imageURL, tint: .clear)
                if post.linkVideo != nil { PlayBadge(size: 52) }
            }
        } else {
            ZStack(alignment: .bottomLeading) {
                tint.bg
                Text(post.headline)
                    .font(Theme.display(post.headline.count > 90 ? 17 : 21))
                    .foregroundStyle(tint.fg)
                    .lineLimit(6)
                    .padding(16)
            }
        }
    }

    private var author: some View {
        HStack(spacing: 10) {
            RingAvatar(name: post.personName, photoURL: post.photoURL, size: 36)
            VStack(alignment: .leading, spacing: 1) {
                Text(post.orgLabel.map { "\(post.personName) at \($0)" } ?? post.personName)
                    .font(Theme.body(14, .bold)).foregroundStyle(Theme.text).lineLimit(1)
                Text(relativeTime(post.timestamp))
                    .font(Theme.body(12)).foregroundStyle(Theme.neutral700)
            }
            Spacer(minLength: 4)
            if let tag = kindTag {
                Text(tag).font(Theme.body(11.5, .bold))
                    .padding(.horizontal, 10).frame(height: 24)
                    .foregroundStyle(Theme.text)
                    .background(Theme.ground, in: Capsule())
                    .lineLimit(1)
            }
        }
    }

    private var kindTag: String? {
        if let kind = post.kind { return kind.label }
        let category = post.category.trimmingCharacters(in: .whitespaces)
        return category.isEmpty || category.lowercased() == "all" ? nil : PostCategory.label(for: category)
    }

    private func signedIn(_ action: () -> Void) {
        if model.auth.isSignedIn { action() } else { model.feedPath.append(.signIn) }
    }
}
