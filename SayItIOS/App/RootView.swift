import SwiftUI

struct RootView: View {
    @ObservedObject var model: AppModel
    @ObservedObject var authService: AuthService

    var body: some View {
        Group {
            if authService.isLoading {
                ProgressView()
            } else {
                TabView {
                    FeedView(model: model)
                        .tabItem { Label("Feed", systemImage: "bubble.left.and.bubble.right") }

                    InterestInboxView(model: model)
                        .tabItem { Label("Interest", systemImage: "tray") }
                        .badge(model.unreadInterestCount)

                    MyProfileView(model: model)
                        .tabItem { Label("Me", systemImage: "person.crop.circle") }
                }
            }
        }
        .task { model.startFeed() }
        .task(id: authService.userId) { await model.refreshAccount() }
        .sheet(item: Binding(
            get: { model.linkedPostId.map(LinkedPost.init) },
            set: { model.linkedPostId = $0?.id }
        )) { linked in
            NavigationStack {
                PostDetailView(model: model, postId: linked.id)
                    .toolbar {
                        ToolbarItem(placement: .cancellationAction) {
                            Button("Done") { model.linkedPostId = nil }
                        }
                    }
            }
        }
    }
}

private struct LinkedPost: Identifiable {
    let id: String
}
