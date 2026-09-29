import SwiftUI

/// People who tapped "I'm interested" on your posts (the web's /interests).
struct InterestInboxView: View {
    @ObservedObject var model: AppModel
    @ObservedObject private var authService: AuthService

    @State private var interests: [Interest] = []
    @State private var isLoading = false
    @State private var errorMessage: String?

    init(model: AppModel) {
        self.model = model
        self.authService = model.auth
    }

    var body: some View {
        NavigationStack {
            Group {
                if !authService.isSignedIn {
                    ContentUnavailableView {
                        Label("Your interest inbox", systemImage: "tray")
                    } description: {
                        Text("When someone is interested in one of your posts, you'll see it here.")
                    } actions: {
                        NavigationLink("Sign In", value: AppRoute.signIn)
                            .buttonStyle(.borderedProminent)
                    }
                } else if isLoading && interests.isEmpty {
                    ProgressView()
                } else if let errorMessage, interests.isEmpty {
                    ContentUnavailableView("Couldn't load interest", systemImage: "exclamationmark.triangle", description: Text(errorMessage))
                } else if interests.isEmpty {
                    ContentUnavailableView("No interest yet", systemImage: "tray", description: Text("Post what you need or offer, and interested people will show up here."))
                } else {
                    List(interests) { interest in
                        NavigationLink {
                            PostDetailView(model: model, postId: interest.postId)
                                .task { await markViewed(interest) }
                        } label: {
                            InterestRow(interest: interest)
                        }
                        .swipeActions(edge: .leading) {
                            if let email = interest.interestedEmail, let url = URL(string: "mailto:\(email)") {
                                Link(destination: url) { Label("Email", systemImage: "envelope") }
                                    .tint(.accentColor)
                            }
                        }
                    }
                    .listStyle(.plain)
                }
            }
            .navigationTitle("Interest")
            .refreshable { await load() }
            .task(id: authService.userId) { await load() }
            .appDestinations(model)
        }
    }

    @MainActor
    private func load() async {
        guard let uid = authService.userId else {
            interests = []
            return
        }
        isLoading = true
        defer { isLoading = false }
        do {
            interests = try await model.repository.interests(forAuthor: uid)
                .filter { !model.blockedUids.contains($0.interestedUid) }
            errorMessage = nil
        } catch {
            errorMessage = error.localizedDescription
        }
        await model.refreshUnreadInterests()
        await model.refreshAwardStats()
    }

    @MainActor
    private func markViewed(_ interest: Interest) async {
        guard !interest.viewed else { return }
        try? await model.repository.markViewed(interest)
        if let index = interests.firstIndex(where: { $0.id == interest.id }) {
            interests[index].viewed = true
        }
        await model.refreshUnreadInterests()
    }
}

private struct InterestRow: View {
    let interest: Interest

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            AvatarView(urlString: interest.interestedPhotoURL, name: interest.interestedDisplayName)
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text(interest.interestedDisplayName)
                        .font(.subheadline.weight(interest.viewed ? .regular : .semibold))
                    Spacer()
                    if let date = interest.createdAt {
                        Text(date.sayItRelative).font(.caption).foregroundStyle(.secondary)
                    }
                }
                if let preview = interest.postPreview {
                    Text("Interested in: \(preview)")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(2)
                }
                if let message = interest.message {
                    Text(message).font(.callout)
                }
            }
            if !interest.viewed {
                Circle().fill(Color.accentColor).frame(width: 8, height: 8).padding(.top, 6)
                    .accessibilityLabel("New")
            }
        }
        .padding(.vertical, 4)
    }
}
