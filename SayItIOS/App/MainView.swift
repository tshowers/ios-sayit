import SwiftUI

/// The signed-in (or browsing) app: the design's top bar - SayIt wordmark,
/// For you / Orgs / Inbox tabs, compose and your avatar - over the
/// full-screen feed or the light Orgs and Inbox screens.
struct MainView: View {
    @ObservedObject var model: AppModel
    @ObservedObject private var authService: AuthService

    init(model: AppModel) {
        self.model = model
        self.authService = model.auth
    }

    /// Find feed: "grid" or "single" (One at a time), remembered like the web's toggle.
    @AppStorage("sayit.boardView") private var boardView = "single"
    /// The post One at a time opens on after a grid card is tapped.
    @State private var singleStart = 0

    private var showsViewToggle: Bool { model.selectedTab == .feed && model.feedLayout == .find }

    private var feedPosts: [Post] {
        FeedFilter(blockedUids: model.blockedUids, hiddenPostIds: model.hiddenPostIds).apply(to: model.posts)
    }

    var body: some View {
        NavigationStack(path: $model.feedPath) {
            GeometryReader { geometry in
                let barTop = geometry.safeAreaInsets.top
                ZStack(alignment: .top) {
                    switch model.selectedTab {
                    case .feed:
                        if showsViewToggle && boardView == "grid" {
                            FindGridView(model: model, posts: feedPosts, topInset: barTop + 96) { index in
                                singleStart = index
                                boardView = "single"
                            }
                            .ignoresSafeArea(.container)
                        } else {
                            // Find leaves a row under the bar for the Grid / One at a time toggle.
                            FeedPagerView(model: model, posts: feedPosts, startIndex: singleStart, layout: model.feedLayout,
                                          topInset: barTop + (showsViewToggle ? 96 : 48))
                                // Not the keyboard's: a text post's reply box rides up with it.
                                .ignoresSafeArea(.container)
                                .id(model.feedLayout)
                        }
                    case .orgs:
                        OrgsView(model: model)
                            .padding(.top, 52)
                            .background(Theme.ground.ignoresSafeArea())
                    case .inbox:
                        InboxView(model: model)
                            .padding(.top, 52)
                            .background(Theme.ground.ignoresSafeArea())
                    }
                    topBar
                    if showsViewToggle {
                        viewToggle
                            .frame(maxWidth: .infinity, alignment: .trailing)
                            .padding(.horizontal, 12)
                            .padding(.top, 50)
                    }
                }
            }
            .toolbar(.hidden, for: .navigationBar)
            .appDestinations(model)
        }
        .tint(Theme.accent600)
    }

    /// Grid / One at a time, as on the web board: a --surface track, the
    /// active one in --text fill.
    private var viewToggle: some View {
        HStack(spacing: 2) {
            viewToggleButton("grid", title: "Grid", systemImage: "square.grid.2x2")
            viewToggleButton("single", title: "One at a time", systemImage: "square")
        }
        .padding(3)
        .background(Theme.surface, in: Capsule())
    }

    private func viewToggleButton(_ value: String, title: String, systemImage: String) -> some View {
        let active = boardView == value
        return Button {
            if value == "single" && !active { singleStart = 0 }
            boardView = value
        } label: {
            Label(title, systemImage: systemImage)
                .font(Theme.body(13, .bold))
                .padding(.horizontal, 12).frame(height: 32)
                .foregroundStyle(active ? Theme.ground : Theme.text)
                .background(active ? Theme.text : .clear, in: Capsule())
        }
        .accessibilityAddTraits(active ? .isSelected : [])
    }

    /// Organic layouts put the bar over the photo; Find keeps it on the page ground, as on the web.
    private var onDark: Bool { model.selectedTab == .feed && model.feedLayout != .find }
    private var ink: Color { onDark ? Theme.cream : Theme.text }

    /// Full size where it fits; tighter spacing and a smaller wordmark on
    /// narrow phones rather than overflowing.
    private var topBar: some View {
        ViewThatFits(in: .horizontal) {
            bar(compact: false)
            bar(compact: true)
        }
        .frame(height: 44)
        .background {
            if !onDark { Theme.ground.ignoresSafeArea(edges: .top) }
        }
    }

    private func bar(compact: Bool) -> some View {
        let button: CGFloat = compact ? 30 : 32
        return HStack(spacing: compact ? 8 : 14) {
            Text("SayIt").font(Theme.display(compact ? 19 : 23)).foregroundStyle(ink)
                .fixedSize()
                .accessibilityAddTraits(.isHeader)
            Spacer(minLength: 4)
            if model.feedLayout == .find {
                findTabs(compact: compact)
            } else if model.selectedTab == .feed && model.feedLayout == .sheet {
                segmentedTabs(compact: compact)
            } else {
                textTabs(compact: compact)
            }
            Button {
                model.feedPath.append(.search)
            } label: {
                circleIcon("magnifyingglass", size: button)
            }
            .accessibilityLabel("Search posts")
            Button {
                if authService.isSignedIn { model.feedPath.append(.compose) } else { model.isBrowsingAsGuest = false }
            } label: {
                circleIcon("plus", size: button)
            }
            .accessibilityLabel("New post")
            Button {
                model.feedPath.append(authService.isSignedIn ? .me : .signIn)
            } label: {
                if authService.isSignedIn {
                    RingAvatar(name: model.displayName, photoURL: model.profile?.photoURL ?? authService.currentUser?.photoURL?.absoluteString,
                               size: button, ring: onDark ? Theme.cream.opacity(0.6) : nil)
                } else {
                    circleIcon("person.fill", size: button)
                }
            }
            .accessibilityLabel(authService.isSignedIn ? "Your profile" : "Sign in")
        }
        .padding(.horizontal, compact ? 12 : 18)
    }

    private func circleIcon(_ name: String, size: CGFloat) -> some View {
        Image(systemName: name).font(.system(size: size * 0.47, weight: .bold)).foregroundStyle(ink)
            .frame(width: size, height: size)
            .background(model.feedLayout == .find ? Theme.surface : (onDark ? Theme.cream : Theme.text).opacity(0.14), in: Circle())
    }

    private let tabs: [(AppTab, String)] = [(.feed, "For you"), (.orgs, "Orgs"), (.inbox, "Inbox")]

    private func textTabs(compact: Bool) -> some View {
        HStack(spacing: compact ? 9 : 12) {
            ForEach(tabs, id: \.0) { tab, title in
                Button {
                    model.selectedTab = tab
                } label: {
                    HStack(spacing: 3) {
                        Text(title).font(Theme.body(13.5, .semibold)).fixedSize()
                        if tab == .inbox && model.unreadThreadCount > 0 {
                            Circle().fill(Theme.accent400).frame(width: 7, height: 7)
                        }
                    }
                    .foregroundStyle(model.selectedTab == tab ? (onDark ? Theme.cream : Theme.accentInk) : ink.opacity(0.55))
                }
                .accessibilityAddTraits(model.selectedTab == tab ? .isSelected : [])
                .accessibilityLabel(tab == .inbox && model.unreadThreadCount > 0 ? "Inbox, \(model.unreadThreadCount) new" : title)
            }
        }
    }

    /// Find's tab track: a --surface pill, the active tab in --text fill with --bg text.
    private func findTabs(compact: Bool) -> some View {
        HStack(spacing: 2) {
            ForEach(tabs, id: \.0) { tab, title in
                Button {
                    model.selectedTab = tab
                } label: {
                    HStack(spacing: 4) {
                        Text(title).font(Theme.body(13, .bold)).fixedSize()
                        if tab == .inbox && model.unreadThreadCount > 0 {
                            Circle().fill(Theme.accent400).frame(width: 6, height: 6)
                        }
                    }
                    .padding(.horizontal, compact ? 8 : 11).frame(height: 30)
                    .foregroundStyle(model.selectedTab == tab ? Theme.ground : Theme.text)
                    .background(model.selectedTab == tab ? Theme.text : .clear, in: Capsule())
                }
                .accessibilityAddTraits(model.selectedTab == tab ? .isSelected : [])
                .accessibilityLabel(tab == .inbox && model.unreadThreadCount > 0 ? "Inbox, \(model.unreadThreadCount) new" : title)
            }
        }
        .padding(3)
        .background(Theme.surface, in: Capsule())
    }

    /// 1b's segmented pill over the photo.
    private func segmentedTabs(compact: Bool) -> some View {
        HStack(spacing: 2) {
            ForEach(tabs, id: \.0) { tab, title in
                Button {
                    model.selectedTab = tab
                } label: {
                    HStack(spacing: 3) {
                        Text(title).font(Theme.body(12.5, .semibold)).fixedSize()
                        if tab == .inbox && model.unreadThreadCount > 0 {
                            Circle().fill(Theme.accent400).frame(width: 6, height: 6)
                        }
                    }
                    .padding(.horizontal, compact ? 7 : 10).frame(height: 28)
                    .foregroundStyle(model.selectedTab == tab ? Theme.ink : Theme.cream)
                    .background(model.selectedTab == tab ? Theme.cream : .clear, in: Capsule())
                }
                .accessibilityAddTraits(model.selectedTab == tab ? .isSelected : [])
                .accessibilityLabel(tab == .inbox && model.unreadThreadCount > 0 ? "Inbox, \(model.unreadThreadCount) new" : title)
            }
        }
        .padding(3)
        .background(Theme.scrim.opacity(0.4), in: Capsule())
    }
}

// MARK: - Layout picker

/// Pick one of the feed designs - in onboarding and under Me. Two across.
struct LayoutPicker: View {
    @Binding var selection: FeedLayout

    var body: some View {
        LazyVGrid(columns: [GridItem(.flexible(), spacing: 10), GridItem(.flexible(), spacing: 10)], spacing: 14) {
            ForEach(FeedLayout.allCases) { layout in
                Button {
                    selection = layout
                } label: {
                    VStack(spacing: 8) {
                        LayoutThumbnail(layout: layout)
                            .frame(height: 170)
                            .overlay(RoundedRectangle(cornerRadius: 18, style: .continuous)
                                .stroke(selection == layout ? Theme.accent600 : Theme.divider, lineWidth: selection == layout ? 3 : 1))
                        HStack(spacing: 4) {
                            if selection == layout { Image(systemName: "checkmark.circle.fill").foregroundStyle(Theme.accent600) }
                            Text(layout.name).font(Theme.body(14, .bold)).foregroundStyle(Theme.text)
                        }
                    }
                }
                .buttonStyle(PressScaleStyle(scale: 0.97))
                .accessibilityLabel("\(layout.name): \(layout.summary)")
                .accessibilityAddTraits(selection == layout ? .isSelected : [])
            }
        }
    }
}

/// A tiny drawing of each layout so people can compare before choosing.
struct LayoutThumbnail: View {
    let layout: FeedLayout

    var body: some View {
        GeometryReader { geo in
            let w = geo.size.width, h = geo.size.height
            ZStack(alignment: .topLeading) {
                Theme.media
                Stripes(color: Theme.neutral700.opacity(0.35))
                switch layout {
                case .find:
                    Theme.ground
                    VStack(spacing: 0) {
                        Theme.tints[0].bg
                            .frame(height: h * 0.5)
                            .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                            .mask(LinearGradient(colors: [.black, .black, .clear], startPoint: .top, endPoint: .bottom))
                            .overlay(Capsule().fill(Theme.tints[0].fg).frame(width: w * 0.45, height: 6).padding(.bottom, 14))
                        Spacer(minLength: 0)
                        VStack(alignment: .leading, spacing: 4) {
                            HStack(spacing: 4) {
                                Circle().fill(Theme.ground).frame(width: 10)
                                Capsule().fill(Theme.text).frame(width: w * 0.35, height: 4)
                            }
                            HStack(spacing: 3) {
                                Capsule().fill(Theme.ground).frame(width: 14, height: 8)
                                Capsule().fill(Theme.ground).frame(width: 14, height: 8)
                            }
                            Capsule().fill(Theme.accent600).frame(height: 10)
                        }
                        .padding(6)
                        .background(Theme.surface, in: RoundedRectangle(cornerRadius: 9, style: .continuous))
                    }
                    .padding(5)
                case .overlay:
                    LinearGradient(colors: [.clear, Theme.scrim.opacity(0.9)], startPoint: .center, endPoint: .bottom)
                    VStack(alignment: .leading, spacing: 4) {
                        Spacer()
                        Capsule().fill(Theme.cream).frame(width: w * 0.5, height: 5)
                        Capsule().fill(Theme.cream.opacity(0.6)).frame(width: w * 0.65, height: 4)
                        Capsule().fill(Theme.accent600).frame(height: 14).padding(.top, 4)
                    }
                    .padding(8)
                    VStack(spacing: 6) {
                        Circle().fill(Theme.cream.opacity(0.3)).frame(width: 12)
                        Circle().fill(Theme.cream.opacity(0.3)).frame(width: 12)
                    }
                    .position(x: w - 12, y: h * 0.55)
                case .sheet:
                    VStack(spacing: 0) {
                        Spacer()
                        VStack(alignment: .leading, spacing: 4) {
                            Rectangle().fill(Theme.orgPalette[0]).frame(height: 8)
                            VStack(alignment: .leading, spacing: 4) {
                                Capsule().fill(Theme.text).frame(width: w * 0.5, height: 5)
                                Capsule().fill(Theme.neutral700.opacity(0.5)).frame(width: w * 0.6, height: 4)
                                HStack(spacing: 3) {
                                    Circle().stroke(Theme.divider).frame(width: 12)
                                    Capsule().fill(Theme.accent600).frame(height: 12)
                                }
                            }
                            .padding(6)
                        }
                        .background(Theme.ground)
                        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                        .padding(5)
                    }
                case .ribbon:
                    HStack(spacing: 0) {
                        Rectangle().fill(Theme.orgPalette[0]).frame(width: 9)
                        VStack(alignment: .leading, spacing: 4) {
                            Capsule().fill(Theme.cream).frame(width: w * 0.55, height: 7)
                            Capsule().fill(Theme.cream).frame(width: w * 0.4, height: 7)
                            Spacer()
                            HStack {
                                Capsule().fill(Theme.cream.opacity(0.3)).frame(width: 18, height: 10)
                                Spacer()
                                Circle().fill(Theme.accent600).frame(width: 24)
                            }
                        }
                        .padding(7)
                    }
                    Circle().fill(Theme.sage300).frame(width: 22).position(x: w - 16, y: h * 0.48)
                }
            }
        }
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
        .accessibilityHidden(true)
    }
}

struct LayoutSettingView: View {
    @ObservedObject var model: AppModel
    @State private var selection: FeedLayout = .default

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                Text("How should posts look?").font(Theme.display(28)).foregroundStyle(Theme.text)
                Text("Pick the feed you like best. You can change it anytime.")
                    .font(Theme.body(15)).foregroundStyle(Theme.neutral700)
                LayoutPicker(selection: $selection)
                Text(selection.summary).font(Theme.body(14)).foregroundStyle(Theme.neutral800)
            }
            .padding(20)
        }
        .background(Theme.ground.ignoresSafeArea())
        .navigationTitle("Feed layout")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear { selection = model.feedLayout }
        .onChange(of: selection) { _, layout in model.setFeedLayout(layout) }
    }
}
