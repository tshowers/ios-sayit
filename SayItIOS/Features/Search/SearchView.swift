import SwiftUI

/// Search posts: every word across the post, author, org, role, category
/// and price, with Selling / Looking for and industry chips. Results open
/// in the full-screen feed at the tapped post, so you can swipe through
/// the rest of the results from there. Covers the posts the feed has
/// loaded (the newest 200).
struct SearchView: View {
    @ObservedObject var model: AppModel
    @State private var filter = FeedFilter()
    @FocusState private var focused: Bool

    private var results: [Post] {
        var current = filter
        current.blockedUids = model.blockedUids
        return current.apply(to: model.posts)
    }

    private var isFiltering: Bool {
        !FeedFilter.words(in: filter.searchText).isEmpty || filter.kind != nil || filter.category != "all"
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 8) {
                Image(systemName: "magnifyingglass").font(.system(size: 16 * Theme.scale, weight: .semibold)).foregroundStyle(Theme.neutral700)
                TextField("Search posts, people, orgs", text: $filter.searchText)
                    .font(Theme.body(16))
                    .foregroundStyle(Theme.text)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                    .submitLabel(.search)
                    .focused($focused)
                    .accessibilityIdentifier("search-field")
                if !filter.searchText.isEmpty {
                    Button { filter.searchText = "" } label: {
                        Image(systemName: "xmark.circle.fill").foregroundStyle(Theme.neutral700)
                    }
                    .accessibilityLabel("Clear search")
                }
            }
            .padding(.horizontal, 16).frame(height: 46 * Theme.scale)
            .background(Theme.surface, in: Capsule())
            .padding(.horizontal, 18)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    chip("Everything", selected: filter.kind == nil && filter.category == "all") {
                        filter.kind = nil
                        filter.category = "all"
                    }
                    ForEach(PostKind.allCases, id: \.self) { kind in
                        chip(kind.label, selected: filter.kind == kind) { filter.kind = filter.kind == kind ? nil : kind }
                    }
                    ForEach(FeedFilter.categories(in: model.posts), id: \.self) { category in
                        chip(PostCategory.label(for: category), selected: filter.category == category) {
                            filter.category = filter.category == category ? "all" : category
                        }
                    }
                }
                .padding(.horizontal, 18)
            }

            if isFiltering {
                Text(results.isEmpty ? "No posts match." : "\(results.count) \(results.count == 1 ? "post" : "posts")")
                    .font(Theme.body(12.5, .semibold)).foregroundStyle(Theme.neutral700)
                    .padding(.horizontal, 20)
                    .accessibilityAddTraits(.updatesFrequently)
            }

            ScrollView {
                LazyVStack(spacing: 6) {
                    if isFiltering && results.isEmpty {
                        VStack(spacing: 8) {
                            Image(systemName: "magnifyingglass").font(.system(size: 30, weight: .semibold)).foregroundStyle(Theme.accent600)
                            Text("Nothing yet").font(Theme.display(22)).foregroundStyle(Theme.text)
                            Text("Try fewer words, or post what you're looking for - someone may have it.")
                                .font(Theme.body(14)).foregroundStyle(Theme.neutral700).multilineTextAlignment(.center)
                        }
                        .padding(.top, 40).padding(.horizontal, 32)
                    }
                    let shown = isFiltering ? results : Array(results.prefix(30))
                    ForEach(Array(shown.enumerated()), id: \.element.id) { index, post in
                        NavigationLink(value: AppRoute.feedAt(shown, index)) {
                            SearchResultRow(post: post, query: filter.searchText)
                        }
                        .buttonStyle(PressScaleStyle(scale: 0.98))
                    }
                }
                .padding(.horizontal, 14)
                .padding(.bottom, 24)
            }
            .scrollDismissesKeyboard(.interactively)
        }
        .padding(.top, 8)
        .frame(maxWidth: 720)
        .frame(maxWidth: .infinity)
        .background(Theme.ground.ignoresSafeArea())
        .navigationTitle("Search")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear { focused = true }
    }

    private func chip(_ text: String, selected: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(text).font(Theme.body(12.5, .bold))
                .padding(.horizontal, 14).frame(height: 34 * Theme.scale)
                .foregroundStyle(selected ? Theme.ground : Theme.text)
                .background(selected ? Theme.text : .clear, in: Capsule())
                .overlay(Capsule().stroke(selected ? .clear : Theme.divider))
        }
        .accessibilityAddTraits(selected ? .isSelected : [])
    }
}

struct SearchResultRow: View {
    let post: Post
    let query: String

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            ZStack {
                if post.imageURL != nil {
                    PostMedia(url: post.imageURL, tint: Theme.orgColor(post.orgLabel))
                } else {
                    Theme.orgColor(post.orgLabel)
                    Stripes(color: Theme.scrim.opacity(0.18))
                    Text(String(post.personName.prefix(1)).uppercased()).font(Theme.display(22)).foregroundStyle(Theme.cream)
                }
            }
            .frame(width: 64 * Theme.scale, height: 64 * Theme.scale)
            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))

            VStack(alignment: .leading, spacing: 4) {
                Text(highlighted(post.headline))
                    .font(Theme.body(15, .bold)).foregroundStyle(Theme.text)
                    .lineLimit(2).multilineTextAlignment(.leading)
                Text([post.personName, post.orgLabel.map { "at \($0)" }, relativeTime(post.timestamp)].compactMap { $0 }.joined(separator: " · "))
                    .font(Theme.body(12)).foregroundStyle(Theme.neutral700).lineLimit(1)
                HStack(spacing: 6) {
                    if let kind = post.kind {
                        KindTag(text: kind.label, fill: Theme.sage100, ink: Theme.sage800)
                        if let price = post.price, !price.isEmpty {
                            Text(price).font(Theme.body(12.5, .bold)).foregroundStyle(Theme.text)
                        }
                    } else if post.category.lowercased() != "all" {
                        Label(PostCategory.label(for: post.category), systemImage: "folder")
                            .font(Theme.body(11.5, .semibold)).foregroundStyle(Theme.neutral800)
                    }
                }
            }
            Spacer(minLength: 0)
        }
        .padding(10)
        .background(Theme.neutral100, in: RoundedRectangle(cornerRadius: 22, style: .continuous))
        .accessibilityElement(children: .combine)
    }

    /// Bolds the matched words in terracotta.
    private func highlighted(_ text: String) -> AttributedString {
        var attributed = AttributedString(text)
        for word in FeedFilter.words(in: query) where word.count > 1 {
            var searchRange = attributed.startIndex..<attributed.endIndex
            while let range = attributed[searchRange].range(of: word, options: .caseInsensitive) {
                attributed[range].foregroundColor = Theme.accentInk
                searchRange = range.upperBound..<attributed.endIndex
            }
        }
        return attributed
    }
}
