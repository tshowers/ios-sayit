import SwiftUI

// MARK: - Find

/// The Find design, matching the web app's "One at a time" view: the photo
/// (or, for a text post, its tint with the words large) fills a rounded area
/// at the top and fades into the page; the post sits on a --surface card
/// below with like / comments / share pills and a full-width I'm interested.
struct FindPostPage: View {
    let post: Post
    let actions: PostActions
    var topInset: CGFloat
    private let s = Theme.scale

    private var tint: (bg: Color, fg: Color) { Theme.tint(for: post.id) }
    private var hasPhoto: Bool { post.imageURL != nil }

    var body: some View {
        GeometryReader { geo in
            let size = geo.size
            ZStack(alignment: .top) {
                Theme.stage
                hero(width: size.width - 24, height: size.height * 0.62)
                    .padding(.top, topInset + 16)
                VStack(spacing: 0) {
                    Color.clear.frame(height: topInset + 56)
                    Spacer(minLength: 0)
                    fitting(card.postColumn())
                    Color.clear.frame(height: size.height * 0.05)
                }
                .padding(.horizontal, 12)
                .frame(width: size.width)
            }
            .frame(width: size.width, height: size.height)
            .clipped()
        }
    }

    // MARK: Hero

    private func hero(width: CGFloat, height: CGFloat) -> some View {
        ZStack {
            if hasPhoto {
                PostMedia(url: post.imageURL, tint: .clear)
                if let video = post.linkVideo {
                    Button { actions.play(video) } label: { PlayBadge(size: 64 * s) }
                        .buttonStyle(PressScaleStyle())
                        .padding(.bottom, height * 0.25)
                        .accessibilityLabel("Play video")
                }
            } else {
                tint.bg
                // A text post's words are the visual, as on the web.
                Text(post.headline)
                    .font(Theme.display(post.headline.count > 90 ? 24 : 30))
                    .tracking(-0.5)
                    .foregroundStyle(tint.fg)
                    .multilineTextAlignment(.center)
                    .lineLimit(7)
                    .minimumScaleFactor(0.7)
                    .padding(.horizontal, 24)
                    .padding(.bottom, height * 0.3)
                    .onTapGesture(perform: actions.openPost)
            }
        }
        .frame(width: width, height: height)
        .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
        .mask(LinearGradient(stops: [.init(color: .black, location: 0), .init(color: .black, location: 0.5), .init(color: .clear, location: 1)],
                             startPoint: .top, endPoint: .bottom))
        .overlay(alignment: .topTrailing) { moreButton.padding(12) }
    }

    private var moreButton: some View {
        Button(action: actions.openPost) {
            Image(systemName: "ellipsis")
                .font(.system(size: 14, weight: .bold))
                .foregroundStyle(Theme.text)
                .frame(width: 32, height: 32)
                .background(Theme.ground, in: Circle())
        }
        .accessibilityLabel("More: comments, report, block")
    }

    // MARK: Card

    private var card: some View {
        VStack(alignment: .leading, spacing: 12 * s) {
            authorRow
            if hasPhoto {
                Text(post.headline).font(Theme.body(16, .bold)).foregroundStyle(Theme.text)
                    .fixedSize(horizontal: false, vertical: true)
                    .onTapGesture(perform: actions.openPost)
            }
            if let text = post.body {
                Text(text).font(Theme.body(14)).foregroundStyle(Theme.neutral700)
                    .fixedSize(horizontal: false, vertical: true)
            }
            PostLinkRow(post: post, onPlay: actions.play)
            if let price = post.price, !price.isEmpty {
                Text(price).font(Theme.body(15, .bold)).foregroundStyle(Theme.text)
            }
            HStack(spacing: 8) {
                Button(action: actions.like) {
                    pill(systemImage: actions.isLiked ? "heart.fill" : "heart", text: Formatting.count(actions.likeCount),
                         fill: actions.isLiked ? Theme.tints[5].bg : Theme.ground, ink: actions.isLiked ? Theme.tints[5].fg : Theme.text)
                }
                .buttonStyle(PressScaleStyle())
                .accessibilityLabel(actions.isLiked ? "Unlike, \(actions.likeCount) likes" : "Like, \(actions.likeCount) likes")
                Button(action: actions.openPost) {
                    pill(systemImage: "bubble.left", text: nil, fill: Theme.ground, ink: Theme.text)
                }
                .buttonStyle(PressScaleStyle())
                .accessibilityLabel("Comments")
                ShareLink(item: actions.shareURL) {
                    pill(systemImage: "paperplane.fill", text: "Share", fill: Theme.ground, ink: Theme.text)
                }
                .accessibilityLabel("Share")
            }
            InterestedButton(actions: actions, height: 46 * s, font: Theme.body(16, .bold))
        }
        .padding(16)
        .background(Theme.surface, in: RoundedRectangle(cornerRadius: 24, style: .continuous))
        .shadow(color: Theme.neutral900.opacity(0.12), radius: 20, y: 8)
    }

    private var authorRow: some View {
        HStack(spacing: 10) {
            Button(action: actions.openOrg) {
                HStack(spacing: 10) {
                    RingAvatar(name: post.personName, photoURL: post.photoURL, size: 40 * s)
                    VStack(alignment: .leading, spacing: 1) {
                        Text(post.orgLabel.map { "\(post.personName) at \($0)" } ?? post.personName)
                            .font(Theme.body(14.5, .bold)).foregroundStyle(Theme.text).lineLimit(1)
                        Text([post.authorRole, relativeTime(post.timestamp)].compactMap { $0?.isEmpty == false ? $0 : nil }.joined(separator: " · "))
                            .font(Theme.body(12)).foregroundStyle(Theme.neutral700).lineLimit(1)
                    }
                }
            }
            .buttonStyle(.plain)
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

    /// Selling / Looking for when the post says, otherwise its category (as on the web).
    private var kindTag: String? {
        if let kind = post.kind { return kind.label }
        let category = post.category.trimmingCharacters(in: .whitespaces)
        return category.isEmpty || category.lowercased() == "all" ? nil : PostCategory.label(for: category)
    }

    private func pill(systemImage: String, text: String?, fill: Color, ink: Color) -> some View {
        HStack(spacing: 6) {
            Image(systemName: systemImage).font(.system(size: 14, weight: .semibold))
            if let text { Text(text).font(Theme.body(13, .bold)) }
        }
        .foregroundStyle(ink)
        .padding(.horizontal, 12)
        .frame(minWidth: 40 * s, minHeight: 38 * s)
        .background(fill, in: Capsule())
    }

    /// Shows the card as is when it fits, otherwise lets it scroll.
    private func fitting<V: View>(_ view: V) -> some View {
        ViewThatFits(in: .vertical) {
            view
            ScrollView(showsIndicators: false) { view }.scrollBounceBehavior(.basedOnSize)
        }
    }
}
