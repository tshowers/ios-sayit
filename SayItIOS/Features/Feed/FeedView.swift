import SwiftUI

struct FeedView: View {
    @ObservedObject var model: AppModel
    @ObservedObject private var authService: AuthService
    @State private var filter = FeedFilter()

    init(model: AppModel) {
        self.model = model
        self.authService = model.auth
    }

    private var visiblePosts: [Post] {
        var current = filter
        current.blockedUids = model.blockedUids
        return current.apply(to: model.posts)
    }

    var body: some View {
        NavigationStack(path: $model.feedPath) {
            Group {
                if model.isFeedLoading {
                    ProgressView()
                } else if let error = model.feedError, model.posts.isEmpty {
                    ContentUnavailableView("Couldn't load posts", systemImage: "wifi.exclamationmark", description: Text(error))
                } else {
                    List {
                        if !authService.isSignedIn {
                            guestBanner
                        }
                        if visiblePosts.isEmpty {
                            ContentUnavailableView(
                                filter.searchText.isEmpty ? "No posts yet" : "No matching posts",
                                systemImage: "bubble.left",
                                description: Text(filter.searchText.isEmpty ? "Be the first to say what you need or offer." : "Try a different search or category.")
                            )
                        }
                        ForEach(visiblePosts) { post in
                            NavigationLink(value: AppRoute.post(post.id)) {
                                PostRowView(post: post)
                            }
                        }
                    }
                    .listStyle(.plain)
                }
            }
            .navigationTitle("Say It")
            .appDestinations(model)
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
                        if authService.isSignedIn {
                            model.feedPath.append(.compose)
                        } else {
                            startWizard()
                        }
                    } label: {
                        Label("New post", systemImage: "square.and.pencil")
                    }
                }
            }
        }
    }

    private var guestBanner: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Say what you need. Get found.").font(.headline)
            Text("Post what you're looking for or offering in under a minute.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
            Button("Get started", action: startWizard)
                .buttonStyle(.borderedProminent)
                .padding(.top, 2)
        }
        .padding(.vertical, 8)
        .listRowSeparator(.hidden)
    }

    /// Back to the wizard, where writing a first post leads to sign-in.
    private func startWizard() {
        model.isBrowsingAsGuest = false
    }
}
