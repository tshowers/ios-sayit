import SwiftUI

struct FeedView: View {
    @ObservedObject var model: AppModel

    @State private var filter = FeedFilter()
    @State private var isComposing = false
    @State private var isGating = false

    private var visiblePosts: [Post] {
        var current = filter
        current.blockedUids = model.blockedUids
        return current.apply(to: model.posts)
    }

    var body: some View {
        NavigationStack {
            Group {
                if model.isFeedLoading {
                    ProgressView()
                } else if let error = model.feedError, model.posts.isEmpty {
                    ContentUnavailableView("Couldn't load posts", systemImage: "wifi.exclamationmark", description: Text(error))
                } else if visiblePosts.isEmpty {
                    ContentUnavailableView(
                        filter.searchText.isEmpty ? "No posts yet" : "No matching posts",
                        systemImage: "bubble.left",
                        description: Text(filter.searchText.isEmpty ? "Be the first to say what you need or offer." : "Try a different search or category.")
                    )
                } else {
                    List(visiblePosts) { post in
                        NavigationLink(value: post.id) {
                            PostRowView(post: post)
                        }
                    }
                    .listStyle(.plain)
                }
            }
            .navigationTitle("Say It")
            .navigationDestination(for: String.self) { postId in
                PostDetailView(model: model, postId: postId)
            }
            .searchable(text: $filter.searchText, prompt: "What do you need or offer?")
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Menu {
                        Picker("Category", selection: $filter.category) {
                            ForEach(PostCategory.all, id: \.self) { category in
                                Text(PostCategory.label(for: category)).tag(category)
                            }
                        }
                    } label: {
                        Label("Category", systemImage: filter.category == "all" ? "line.3.horizontal.decrease.circle" : "line.3.horizontal.decrease.circle.fill")
                    }
                    .accessibilityLabel("Filter by category")
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        if model.canParticipate { isComposing = true } else { isGating = true }
                    } label: {
                        Label("New post", systemImage: "square.and.pencil")
                    }
                }
            }
            .sheet(isPresented: $isComposing) {
                ComposerView(model: model, initialCategory: filter.category)
            }
            .sheet(isPresented: $isGating) {
                ParticipationGate(model: model) {
                    isGating = false
                    isComposing = true
                }
            }
        }
    }
}
