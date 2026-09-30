import SwiftUI

/// One full-screen post at a time, paged left/right (handoff "Feed paging"):
/// a 60pt drag pages, less snaps back, the ends rubber-band, and the page
/// follows the finger. Renders the member's chosen layout (1a/1b/1c).
struct FeedPagerView: View {
    @ObservedObject var model: AppModel
    let posts: [Post]
    var startIndex = 0
    var layout: FeedLayout
    /// Shown above the pages (the top bar lives outside in the main screen).
    var topInset: CGFloat = 0

    @State private var index = 0
    @State private var drag: CGFloat = 0
    @State private var orgCardPostId: String?
    @State private var route: AppRoute?

    private let snap = Animation.timingCurve(0.2, 0.8, 0.2, 1, duration: 0.46)

    var body: some View {
        GeometryReader { geometry in
            let width = geometry.size.width
            ZStack {
                Theme.media.ignoresSafeArea()
                if posts.isEmpty {
                    emptyState
                } else {
                    ForEach(visibleIndices, id: \.self) { i in
                        page(for: posts[i], size: geometry.size)
                            .frame(width: width, height: geometry.size.height)
                            .offset(x: CGFloat(i - index) * width + FeedPaging.offset(for: drag, at: index, count: posts.count))
                    }
                    indicator
                    if let post = posts.first(where: { $0.id == orgCardPostId }) {
                        orgCard(for: post)
                    }
                }
                if let toast = model.toast {
                    VStack {
                        ToastView(message: toast).padding(.top, topInset + 48)
                        Spacer()
                    }
                    .transition(.opacity.combined(with: .move(edge: .top)))
                }
            }
            .contentShape(Rectangle())
            .simultaneousGesture(
                DragGesture(minimumDistance: 10)
                    .onChanged { value in
                        guard abs(value.translation.width) > abs(value.translation.height) else { return }
                        drag = value.translation.width
                    }
                    .onEnded { value in
                        let next = FeedPaging.index(after: value.translation.width, from: index, count: posts.count)
                        withAnimation(snap) {
                            if next != index { orgCardPostId = nil }
                            index = next
                            drag = 0
                        }
                    }
            )
        }
        .animation(.easeInOut(duration: 0.25), value: model.toast)
        .onAppear { index = min(startIndex, max(posts.count - 1, 0)) }
        .onChange(of: posts.count) { _, count in if index >= count { index = max(count - 1, 0) } }
        .navigationDestination(item: $route) { AppDestination(model: model, route: $0) }
        .accessibilityAction(named: "Next post") { withAnimation(snap) { index = min(index + 1, posts.count - 1) } }
        .accessibilityAction(named: "Previous post") { withAnimation(snap) { index = max(index - 1, 0) } }
    }

    private var visibleIndices: [Int] {
        guard !posts.isEmpty else { return [] }
        return Array(max(0, index - 1)...min(posts.count - 1, index + 1))
    }

    @ViewBuilder
    private func page(for post: Post, size: CGSize) -> some View {
        let actions = PostActions(
            isLiked: model.isLiked(post),
            likeCount: model.likeCount(post),
            isInterested: model.isInterested(post),
            isOwn: post.authorUid != nil && post.authorUid == model.auth.userId,
            canBeInterested: post.authorUid != nil && !post.isSystemPost,
            shareURL: model.postURL(for: post),
            like: { signedIn { model.toggleLike(post) } },
            interested: { signedIn { Task { await model.toggleInterest(post) } } },
            openOrg: { orgCardPostId = post.id; Task { if model.orgs.isEmpty { await model.loadOrgs() } } },
            openPost: { route = .post(post.id) },
            counter: "\(index + 1) / \(posts.count)"
        )
        switch layout {
        case .overlay: OverlayPostPage(post: post, actions: actions, topInset: topInset)
        case .sheet: SheetPostPage(post: post, actions: actions, topInset: topInset)
        case .ribbon: RibbonPostPage(post: post, actions: actions, topInset: topInset)
        }
    }

    private func signedIn(_ action: () -> Void) {
        if model.auth.isSignedIn { action() } else { route = .signIn }
    }

    /// Page pills (1a, 1b): active 22pt, others 6pt at 50%.
    @ViewBuilder
    private var indicator: some View {
        if layout != .ribbon && posts.count > 1 {
            VStack {
                HStack(spacing: 5) {
                    ForEach(indicatorRange, id: \.self) { i in
                        Capsule()
                            .fill(Theme.cream.opacity(i == index ? 1 : 0.5))
                            .frame(width: i == index ? 22 : 6, height: 4)
                    }
                }
                .animation(.easeInOut(duration: 0.3), value: index)
                .padding(.top, topInset + 4)
                Spacer()
            }
            .allowsHitTesting(false)
            .accessibilityHidden(true)
        }
    }

    /// At most 9 pills, centered on the current post.
    private var indicatorRange: [Int] {
        let lower = max(0, min(index - 4, posts.count - 9))
        return Array(lower..<min(posts.count, lower + 9))
    }

    private var emptyState: some View {
        VStack(spacing: 12) {
            Text("No posts yet").font(Theme.display(26)).foregroundStyle(Theme.cream)
            Text("Be the first to say what you need or offer.")
                .font(Theme.body(14))
                .foregroundStyle(Theme.neutral300)
        }
        .padding(32)
    }

    // MARK: Org card

    private func orgCard(for post: Post) -> some View {
        let orgName = post.orgLabel
        let org = model.org(named: orgName)
        let color = Theme.orgColor(orgName)
        return ZStack(alignment: layout == .sheet ? .top : .bottom) {
            Theme.scrim.opacity(0.35)
                .ignoresSafeArea()
                .onTapGesture { orgCardPostId = nil }
            VStack(alignment: .leading, spacing: 12) {
                HStack(spacing: 12) {
                    Circle().fill(color).frame(width: 48, height: 48)
                        .overlay(Text(String((orgName ?? post.personName).prefix(1)).uppercased()).font(Theme.display(20)).foregroundStyle(Theme.cream))
                    VStack(alignment: .leading, spacing: 2) {
                        Text(orgName ?? post.personName).font(Theme.display(20)).foregroundStyle(Theme.text)
                        Text(org.map { "\($0.memberUids.count) \($0.memberUids.count == 1 ? "person" : "people") on Say It" } ?? "On Say It")
                            .font(Theme.body(12)).foregroundStyle(Theme.neutral700)
                    }
                }
                Text(cardSentence(post, orgName: orgName))
                    .font(Theme.body(13.5)).foregroundStyle(Theme.neutral800)
                HStack(spacing: 10) {
                    if let org {
                        Button {
                            orgCardPostId = nil
                            route = .org(org)
                        } label: {
                            Text("View \(org.name)").font(Theme.display(14)).lineLimit(1)
                                .frame(maxWidth: .infinity, minHeight: 42)
                        }
                        .buttonStyle(PrimaryPillStyle(fill: Theme.accent, pressedFill: Theme.accent600))
                    }
                    Button("Close") { orgCardPostId = nil }
                        .font(Theme.body(14, .semibold))
                        .foregroundStyle(Theme.text)
                        .frame(minWidth: 90, minHeight: 42)
                        .overlay(Capsule().stroke(Theme.divider))
                }
            }
            .padding(18)
            .background(Theme.ground, in: RoundedRectangle(cornerRadius: 32, style: .continuous))
            .shadow(color: Theme.neutral900.opacity(0.22), radius: 16, y: 12)
            .padding(.horizontal, 12)
            .padding(layout == .sheet ? .top : .bottom, layout == .sheet ? topInset + 66 : 120)
        }
        .transition(.opacity)
    }

    private func cardSentence(_ post: Post, orgName: String?) -> AttributedString {
        var name = AttributedString(post.personName)
        name.font = Theme.body(13.5, .bold)
        let role = post.authorRole.flatMap { $0.isEmpty ? nil : $0 }
        let rest: String
        switch (role, orgName) {
        case let (role?, org?): rest = " is \(role) at \(org)."
        case let (nil, org?): rest = " posts for \(org)."
        case let (role?, nil): rest = " is \(role)."
        default: rest = " posts on Say It."
        }
        return name + AttributedString(rest)
    }
}

/// Everything a layout needs to render a post and react to taps.
struct PostActions {
    var isLiked: Bool
    var likeCount: Int
    var isInterested: Bool
    var isOwn: Bool
    var canBeInterested: Bool
    var shareURL: URL
    var like: () -> Void
    var interested: () -> Void
    var openOrg: () -> Void
    var openPost: () -> Void
    var counter: String
}

// MARK: - Shared pieces

/// "I'm interested" / "In your inbox" - terracotta off, sage on, 0.25s.
struct InterestedButton: View {
    let actions: PostActions
    var height: CGFloat = 56
    var font: Font = Theme.display(18)
    var onLabel = "In your inbox"

    var body: some View {
        if actions.isOwn {
            Button(action: actions.openPost) {
                Label("Your post", systemImage: "person.fill").font(font)
                    .frame(maxWidth: .infinity, minHeight: height)
            }
            .buttonStyle(PrimaryPillStyle(fill: Theme.neutral700, pressedFill: Theme.neutral800))
        } else if actions.canBeInterested {
            Button(action: actions.interested) {
                HStack(spacing: 10) {
                    Image(systemName: actions.isInterested ? "checkmark" : "tray").font(.system(size: 18, weight: .bold))
                    Text(actions.isInterested ? onLabel : "I'm interested").font(font).lineLimit(1)
                }
                .frame(maxWidth: .infinity, minHeight: height)
            }
            .buttonStyle(PrimaryPillStyle(fill: actions.isInterested ? Theme.sage700 : Theme.accent600,
                                          pressedFill: actions.isInterested ? Theme.hex(0x3D472B) : Theme.accent700))
            .animation(.easeInOut(duration: 0.25), value: actions.isInterested)
            .accessibilityHint(actions.isInterested ? "Removes it from your inbox" : "Adds it to your inbox so you can message the author")
        }
    }
}

/// The ••• button: open the post (comments), report, block.
struct PostMoreButton: View {
    let actions: PostActions
    var tint: Color = Theme.cream
    var body: some View {
        Button(action: actions.openPost) {
            Image(systemName: "ellipsis")
                .font(.system(size: 16, weight: .bold))
                .foregroundStyle(tint)
                .frame(width: 36, height: 36)
                .background(tint.opacity(0.16), in: Circle())
        }
        .accessibilityLabel("More: comments, report, block")
    }
}

/// Kind tag and price ("SELLING  $18 each").
struct KindPriceRow: View {
    let post: Post
    var priceColor: Color = Theme.cream
    var priceSize: CGFloat = 14
    var tagFill: Color = Theme.sage200
    var tagInk: Color = Theme.sage900

    var body: some View {
        if let kind = post.kind {
            HStack(spacing: 8) {
                KindTag(text: kind.label, fill: tagFill, ink: tagInk)
                if let price = post.price, !price.isEmpty {
                    Text(price).font(Theme.body(priceSize, .bold)).foregroundStyle(priceColor)
                }
            }
        }
    }
}

func relativeTime(_ date: Date?) -> String {
    guard let date else { return "" }
    let seconds = Date().timeIntervalSince(date)
    if seconds < 60 { return "now" }
    if seconds < 3600 { return "\(Int(seconds / 60))m" }
    if seconds < 86_400 { return "\(Int(seconds / 3600))h" }
    if seconds < 604_800 { return "\(Int(seconds / 86_400))d" }
    return date.formatted(.dateTime.month(.abbreviated).day())
}

// MARK: - Shared post pieces

/// The photo, or the design's striped placeholder in the org's tone when
/// the post has none - every layout starts from this, like the prototypes.
struct PostBackdrop: View {
    let post: Post
    var body: some View {
        PostMedia(url: post.imageURL, tint: Theme.orgColor(post.orgLabel ?? post.category))
    }
}

/// Category and the AI moderation summary (the web's "Content Description").
struct PostMetaRow: View {
    let post: Post
    /// True over photos (cream text), false on the light/dark card.
    var onMedia: Bool

    var body: some View {
        let hasCategory = post.category.lowercased() != "all" && !post.category.isEmpty
        let summary = post.ratingExplanation.flatMap { $0.isEmpty ? nil : $0 }
        if hasCategory || summary != nil {
            VStack(alignment: .leading, spacing: 5 * Theme.scale) {
                if hasCategory {
                    Label(PostCategory.label(for: post.category), systemImage: "folder")
                        .font(Theme.body(11.5, .semibold))
                        .foregroundStyle(onMedia ? Theme.cream.opacity(0.9) : Theme.neutral800)
                        .labelStyle(.titleAndIcon)
                        .accessibilityLabel("Category: \(PostCategory.label(for: post.category))")
                }
                if let summary {
                    HStack(alignment: .top, spacing: 5) {
                        Image(systemName: "sparkles")
                        Text(summary).lineLimit(2)
                    }
                    .font(Theme.body(11.5).italic())
                    .foregroundStyle(onMedia ? Theme.neutral300 : Theme.neutral700)
                    .accessibilityElement(children: .combine)
                    .accessibilityLabel("AI summary: \(summary)")
                }
            }
        }
    }
}

/// Keeps a post's words in a phone-width column on big screens.
extension View {
    func postColumn(alignment: Alignment = .center) -> some View {
        frame(maxWidth: Theme.readableWidth, alignment: .leading)
            .frame(maxWidth: .infinity, alignment: alignment)
    }
}

// MARK: - 1a Overlay + rail

struct OverlayPostPage: View {
    let post: Post
    let actions: PostActions
    var topInset: CGFloat
    private let s = Theme.scale

    var body: some View {
        ZStack(alignment: .bottom) {
            PostBackdrop(post: post)
            LinearGradient(stops: [.init(color: Theme.scrim.opacity(0.94), location: 0), .init(color: Theme.scrim.opacity(0.7), location: 0.45), .init(color: .clear, location: 1)],
                           startPoint: .bottom, endPoint: .top)
                .containerRelativeFrame(.vertical) { height, _ in height * 0.62 }
                .frame(maxHeight: .infinity, alignment: .bottom)
                .allowsHitTesting(false)

            VStack {
                HStack { Spacer(); PostMoreButton(actions: actions) }
                    .padding(.top, topInset + 16).padding(.trailing, 14)
                Spacer()
            }

            VStack(spacing: 16 * s) {
                HStack(alignment: .bottom, spacing: 12) {
                    // Author block
                    VStack(alignment: .leading, spacing: 8 * s) {
                        Button(action: actions.openOrg) {
                            HStack(spacing: 10) {
                                RingAvatar(name: post.personName, photoURL: post.photoURL, size: 42 * s, ring: Theme.orgColor(post.orgLabel))
                                VStack(alignment: .leading, spacing: 3) {
                                    HStack(spacing: 6) {
                                        Text(post.personName).font(Theme.body(15, .bold)).foregroundStyle(Theme.cream)
                                        if let org = post.orgLabel {
                                            Text("at \(org)").font(Theme.body(11, .semibold)).foregroundStyle(Theme.cream)
                                                .padding(.horizontal, 9).frame(height: 20 * s)
                                                .background(Theme.orgColor(org), in: Capsule())
                                                .lineLimit(1)
                                        }
                                    }
                                    Text([post.authorRole, relativeTime(post.timestamp)].compactMap { $0?.isEmpty == false ? $0 : nil }.joined(separator: " · "))
                                        .font(Theme.body(12)).foregroundStyle(Theme.neutral300)
                                }
                            }
                        }
                        .buttonStyle(.plain)
                        KindPriceRow(post: post)
                        Group {
                            Text(post.headline).font(Theme.display(21)).foregroundStyle(Theme.cream).lineLimit(5)
                            if let body = post.body {
                                Text(body).font(Theme.body(13.5)).foregroundStyle(Theme.hex(0xEEE7DB)).lineLimit(4)
                            }
                        }
                        .onTapGesture(perform: actions.openPost)
                        PostMetaRow(post: post, onMedia: true)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)

                    // Right rail
                    VStack(spacing: 16 * s) {
                        railButton(systemImage: actions.isLiked ? "heart.fill" : "heart", label: Formatting.count(actions.likeCount),
                                   tint: actions.isLiked ? Theme.accent400 : Theme.cream, action: actions.like)
                            .accessibilityLabel(actions.isLiked ? "Unlike" : "Like")
                        ShareLink(item: actions.shareURL) {
                            railLabel(systemImage: "paperplane", label: "Share", tint: Theme.cream)
                        }
                    }
                }
                InterestedButton(actions: actions, height: 56 * s)
            }
            .padding(.horizontal, 16)
            .padding(.bottom, 20)
            .postColumn()
        }
    }

    private func railButton(systemImage: String, label: String, tint: Color, action: @escaping () -> Void) -> some View {
        Button(action: action) { railLabel(systemImage: systemImage, label: label, tint: tint) }
            .buttonStyle(PressScaleStyle())
    }

    private func railLabel(systemImage: String, label: String, tint: Color) -> some View {
        VStack(spacing: 4) {
            Image(systemName: systemImage)
                .font(.system(size: 20 * s, weight: .bold))
                .foregroundStyle(tint)
                .frame(width: 46 * s, height: 46 * s)
                .background(Theme.cream.opacity(0.16), in: Circle())
            Text(label).font(Theme.body(12, .semibold)).foregroundStyle(Theme.cream)
        }
    }
}

// MARK: - 1b Floating sheet

struct SheetPostPage: View {
    let post: Post
    let actions: PostActions
    var topInset: CGFloat
    private let s = Theme.scale

    var body: some View {
        ZStack(alignment: .bottom) {
            PostBackdrop(post: post)

            VStack {
                HStack { Spacer(); PostMoreButton(actions: actions) }
                    .padding(.top, topInset + 16).padding(.trailing, 14)
                Spacer()
            }

            // Sheet
            VStack(alignment: .leading, spacing: 0) {
                HStack {
                    Text((post.orgLabel ?? "Say It").uppercased())
                    Spacer()
                    Text(post.kind?.label.uppercased() ?? PostCategory.label(for: post.category).uppercased()).opacity(0.85)
                }
                .font(Theme.body(10.5, .bold)).tracking(1)
                .foregroundStyle(Theme.cream)
                .padding(.horizontal, 18)
                .frame(height: 30 * s)
                .background(Theme.orgColor(post.orgLabel))

                VStack(alignment: .leading, spacing: 10 * s) {
                    HStack(alignment: .top) {
                        Button(action: actions.openOrg) {
                            HStack(spacing: 10) {
                                RingAvatar(name: post.personName, photoURL: post.photoURL, size: 38 * s)
                                VStack(alignment: .leading, spacing: 1) {
                                    Text(post.personName).font(Theme.body(15, .bold)).foregroundStyle(Theme.text)
                                    if let org = post.orgLabel {
                                        (Text(post.authorRole.map { "\($0) at " } ?? "at ") + Text(org).underline())
                                            .font(Theme.body(12)).foregroundStyle(Theme.neutral700).lineLimit(1)
                                    }
                                }
                            }
                        }
                        .buttonStyle(.plain)
                        Spacer()
                        Text(relativeTime(post.timestamp)).font(Theme.body(12)).foregroundStyle(Theme.neutral700)
                    }
                    Group {
                        Text(post.headline).font(Theme.display(20)).foregroundStyle(Theme.text).lineLimit(4)
                        if let body = post.body {
                            Text(body).font(Theme.body(13.5)).foregroundStyle(Theme.neutral800).lineLimit(4)
                        }
                    }
                    .onTapGesture(perform: actions.openPost)
                    KindPriceRow(post: post, priceColor: Theme.text, priceSize: 15, tagFill: Theme.sage100, tagInk: Theme.sage800)
                    PostMetaRow(post: post, onMedia: false)
                    HStack(spacing: 8) {
                        Button(action: actions.like) {
                            HStack(spacing: 6) {
                                Image(systemName: actions.isLiked ? "heart.fill" : "heart")
                                    .foregroundStyle(actions.isLiked ? Theme.accent400 : Theme.text)
                                Text(Formatting.count(actions.likeCount)).font(Theme.body(13, .bold)).foregroundStyle(Theme.text)
                            }
                            .padding(.horizontal, 12).frame(height: 50 * s)
                            .overlay(Capsule().stroke(Theme.divider))
                        }
                        .buttonStyle(PressScaleStyle())
                        .accessibilityLabel(actions.isLiked ? "Unlike, \(actions.likeCount) likes" : "Like, \(actions.likeCount) likes")
                        ShareLink(item: actions.shareURL) {
                            Image(systemName: "paperplane").foregroundStyle(Theme.text)
                                .frame(width: 50 * s, height: 50 * s).overlay(Circle().stroke(Theme.divider))
                        }
                        .accessibilityLabel("Share")
                        InterestedButton(actions: actions, height: 50 * s, font: Theme.display(15))
                    }
                }
                .padding(.top, 14).padding(.horizontal, 16).padding(.bottom, 16)
            }
            .background(Theme.ground)
            .clipShape(RoundedRectangle(cornerRadius: 32, style: .continuous))
            .shadow(color: Theme.neutral900.opacity(0.22), radius: 16, y: 12)
            .padding(.horizontal, 10)
            .padding(.bottom, 10)
            .postColumn()
        }
    }
}

// MARK: - 1c Ribbon + sticker

struct RibbonPostPage: View {
    let post: Post
    let actions: PostActions
    var topInset: CGFloat
    private let s = Theme.scale

    var body: some View {
        GeometryReader { geometry in
            page(width: geometry.size.width)
        }
    }

    private func page(width: CGFloat) -> some View {
        HStack(spacing: 0) {
            // Org ribbon, read bottom to top
            Theme.orgColor(post.orgLabel)
                .frame(width: 34 * s)
                .overlay {
                    Text("\((post.orgLabel ?? "Say It").uppercased())\(post.kind.map { " · \($0.label.uppercased())" } ?? "")")
                        .font(Theme.body(11, .bold)).tracking(2)
                        .foregroundStyle(Theme.cream)
                        .lineLimit(1)
                        .fixedSize()
                        .rotationEffect(.degrees(-90))
                        .frame(width: 34 * s)
                }
                .clipped()

            ZStack(alignment: .topLeading) {
                PostBackdrop(post: post)
                VStack(spacing: 0) {
                    LinearGradient(colors: [Theme.scrim.opacity(0.75), .clear], startPoint: .top, endPoint: .bottom)
                        .containerRelativeFrame(.vertical) { h, _ in h * 0.46 }
                    Spacer()
                    LinearGradient(colors: [.clear, Theme.scrim.opacity(0.9)], startPoint: .top, endPoint: .bottom)
                        .containerRelativeFrame(.vertical) { h, _ in h * 0.5 }
                }
                .allowsHitTesting(false)

                VStack(alignment: .leading, spacing: 0) {
                    HStack(alignment: .top) {
                        Text(post.headline)
                            .font(Theme.display(30))
                            .foregroundStyle(Theme.cream)
                            .minimumScaleFactor(0.6)
                            .lineLimit(5)
                            .onTapGesture(perform: actions.openPost)
                        Spacer(minLength: 8)
                        VStack(alignment: .trailing, spacing: 10) {
                            Text(actions.counter).font(Theme.body(12, .bold)).foregroundStyle(Theme.cream.opacity(0.85))
                            PostMoreButton(actions: actions)
                        }
                    }
                    .padding(.top, topInset + 24)

                    Spacer()

                    VStack(alignment: .leading, spacing: 8 * s) {
                        Button(action: actions.openOrg) {
                            HStack(spacing: 10) {
                                RingAvatar(name: post.personName, photoURL: post.photoURL, size: 36 * s)
                                VStack(alignment: .leading, spacing: 1) {
                                    (Text(post.personName).font(Theme.body(15, .bold))
                                     + Text(post.orgLabel.map { " at \($0)" } ?? "").font(Theme.body(15, .semibold)).foregroundColor(Theme.cream.opacity(0.8)))
                                        .foregroundStyle(Theme.cream).lineLimit(1)
                                    Text([post.authorRole, relativeTime(post.timestamp)].compactMap { $0?.isEmpty == false ? $0 : nil }.joined(separator: " · "))
                                        .font(Theme.body(12)).foregroundStyle(Theme.neutral300)
                                }
                            }
                        }
                        .buttonStyle(.plain)
                        if let body = post.body {
                            Text(body).font(Theme.body(13.5)).foregroundStyle(Theme.hex(0xEEE7DB)).lineLimit(3)
                        }
                        PostMetaRow(post: post, onMedia: true)
                    }
                    .padding(.trailing, post.kind == nil ? 0 : 20)
                    .padding(.bottom, 16 * s)

                    // Bottom row
                    HStack(alignment: .bottom) {
                        Button(action: actions.like) {
                            HStack(spacing: 6) {
                                Image(systemName: actions.isLiked ? "heart.fill" : "heart")
                                    .foregroundStyle(actions.isLiked ? Theme.accent400 : Theme.cream)
                                Text(Formatting.count(actions.likeCount)).font(Theme.body(13, .bold)).foregroundStyle(Theme.cream)
                            }
                            .padding(.horizontal, 14).frame(height: 46 * s)
                            .background(Theme.cream.opacity(0.18), in: Capsule())
                        }
                        .buttonStyle(PressScaleStyle())
                        .accessibilityLabel(actions.isLiked ? "Unlike" : "Like")
                        ShareLink(item: actions.shareURL) {
                            Image(systemName: "paperplane").foregroundStyle(Theme.cream)
                                .frame(width: 46 * s, height: 46 * s).background(Theme.cream.opacity(0.18), in: Circle())
                        }
                        .accessibilityLabel("Share")
                        Spacer()
                        roundInterested
                    }
                    .padding(.bottom, 20)
                }
                .padding(.leading, 20)
                .padding(.trailing, 16)
                .postColumn(alignment: .leading)

                // Price sticker
                if let kind = post.kind {
                    VStack(spacing: 2) {
                        Text(kind.label.uppercased()).font(Theme.body(10, .bold))
                        if let price = post.price, !price.isEmpty {
                            Text(price).font(Theme.display(18)).multilineTextAlignment(.center).minimumScaleFactor(0.6)
                        }
                    }
                    .foregroundStyle(Theme.sage900)
                    .padding(10)
                    .frame(width: 104 * s, height: 104 * s)
                    .background(Theme.sage300, in: Circle())
                    .shadow(color: Theme.neutral900.opacity(0.16), radius: 5, y: 3)
                    .rotationEffect(.degrees(-9))
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .trailing)
                    .padding(.trailing, 18)
                    .accessibilityElement(children: .combine)
                }
            }
            .frame(width: max(width - 34 * s, 0))
            .clipped()
        }
    }

    @ViewBuilder
    private var roundInterested: some View {
        if actions.canBeInterested && !actions.isOwn {
            Button(action: actions.interested) {
                VStack(spacing: 4) {
                    Image(systemName: actions.isInterested ? "checkmark" : "tray").font(.system(size: 22 * s, weight: .bold))
                    Text(actions.isInterested ? "In inbox" : "I'm\ninterested").font(Theme.display(13)).multilineTextAlignment(.center)
                }
                .foregroundStyle(Theme.cream)
                .frame(width: 92 * s, height: 92 * s)
                .background(actions.isInterested ? Theme.sage700 : Theme.accent600, in: Circle())
                .shadow(color: Theme.neutral900.opacity(0.22), radius: 16, y: 12)
            }
            .buttonStyle(PressScaleStyle(scale: 0.94))
            .animation(.easeInOut(duration: 0.25), value: actions.isInterested)
            .accessibilityLabel(actions.isInterested ? "In your inbox" : "I'm interested")
        }
    }
}
