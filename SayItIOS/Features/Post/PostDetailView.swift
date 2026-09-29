import SwiftUI

/// A single post in isolation, with its comments - what a shared
/// sayit.taliferro.tech/post/<id> link opens.
struct PostDetailView: View {
    @ObservedObject var model: AppModel
    let postId: String

    @Environment(\.dismiss) private var dismiss
    @State private var post: Post?
    @State private var comments: [Comment] = []
    @State private var isLoading = true
    @State private var notFound = false
    @State private var commentText = ""
    @State private var isSending = false
    @State private var interestSent = false
    @State private var errorMessage: String?
    @State private var pendingAction: PendingAction?
    @State private var isReporting = false
    @State private var confirmBlock = false
    @State private var confirmDelete = false
    @FocusState private var commentFocused: Bool

    private enum PendingAction: Identifiable {
        case comment, interest, report, block
        var id: Self { self }
    }

    private var isMine: Bool {
        guard let uid = model.auth.userId else { return false }
        return post?.authorUid == uid
    }

    var body: some View {
        Group {
            if isLoading {
                ProgressView()
            } else if let post, !notFound {
                content(for: post)
            } else {
                ContentUnavailableView("Post not found", systemImage: "questionmark.bubble", description: Text("It may have been removed."))
            }
        }
        .navigationTitle("Post")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            if let post {
                ToolbarItem(placement: .topBarTrailing) {
                    ShareLink(item: model.postURL(for: post), subject: Text("Say It"), message: Text(String(post.content.prefix(120)))) {
                        Label("Share", systemImage: "square.and.arrow.up")
                    }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    actionsMenu(for: post)
                }
            }
        }
        .task(id: postId) { await load() }
        .sheet(item: $pendingAction) { action in
            ParticipationGate(model: model) {
                pendingAction = nil
                Task { await resume(action) }
            }
        }
        .sheet(isPresented: $isReporting) {
            if let post {
                ReportView(model: model, post: post)
            }
        }
        .confirmationDialog("Block \(post?.displayName ?? "this person")?", isPresented: $confirmBlock, titleVisibility: .visible) {
            Button("Block", role: .destructive) { Task { await block() } }
        } message: {
            Text("You won't see their posts anymore. You can unblock them from the Me tab.")
        }
        .confirmationDialog("Delete this post?", isPresented: $confirmDelete, titleVisibility: .visible) {
            Button("Delete", role: .destructive) { Task { await deletePost() } }
        }
        .alert("Something went wrong", isPresented: Binding(get: { errorMessage != nil }, set: { if !$0 { errorMessage = nil } })) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(errorMessage ?? "")
        }
    }

    // MARK: Layout

    private func content(for post: Post) -> some View {
        List {
            Section {
                PostRowView(post: post, isDetail: true)
                if !post.isSystemPost && !isMine {
                    Button {
                        if model.canParticipate { Task { await sendInterest() } } else { pendingAction = .interest }
                    } label: {
                        Label(interestSent ? "Interest sent" : "I'm interested", systemImage: interestSent ? "checkmark.circle.fill" : "hand.thumbsup")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(interestSent)
                    .listRowSeparator(.hidden)
                }
            }

            Section("Comments") {
                if comments.isEmpty {
                    Text("No comments yet.")
                        .foregroundStyle(.secondary)
                }
                ForEach(visibleComments) { comment in
                    CommentRow(comment: comment)
                        .swipeActions {
                            if comment.authorUid == model.auth.userId {
                                Button("Delete", role: .destructive) { Task { await deleteComment(comment) } }
                            }
                        }
                }
            }
        }
        .listStyle(.insetGrouped)
        .refreshable { await load() }
        .safeAreaInset(edge: .bottom) { commentBar }
    }

    private var visibleComments: [Comment] {
        comments.filter { !model.blockedUids.contains($0.authorUid) }
    }

    private var commentBar: some View {
        HStack(spacing: 8) {
            TextField(model.auth.isSignedIn ? "Add a comment…" : "Sign in to join the conversation", text: $commentText, axis: .vertical)
                .lineLimit(1...4)
                .textFieldStyle(.roundedBorder)
                .focused($commentFocused)
                .onTapGesture {
                    if !model.canParticipate {
                        commentFocused = false
                        pendingAction = .comment
                    }
                }
            Button {
                Task { await sendComment() }
            } label: {
                if isSending {
                    ProgressView()
                } else {
                    Image(systemName: "arrow.up.circle.fill").font(.title2)
                }
            }
            .disabled(!CommentDraft.canSend(commentText) || isSending)
            .accessibilityLabel("Send comment")
        }
        .padding(.horizontal)
        .padding(.vertical, 8)
        .background(.bar)
    }

    private func actionsMenu(for post: Post) -> some View {
        Menu {
            if isMine {
                Button("Delete Post", systemImage: "trash", role: .destructive) { confirmDelete = true }
            } else if !post.isSystemPost {
                Button("Report Post", systemImage: "flag") {
                    if model.canParticipate { isReporting = true } else { pendingAction = .report }
                }
                if post.authorUid != nil {
                    Button("Block \(post.displayName)", systemImage: "hand.raised") {
                        if model.auth.isSignedIn { confirmBlock = true } else { pendingAction = .block }
                    }
                }
            }
        } label: {
            Label("More", systemImage: "ellipsis.circle")
        }
    }

    // MARK: Actions

    @MainActor
    private func load() async {
        if post == nil, let cached = model.posts.first(where: { $0.id == postId }) {
            post = cached
            isLoading = false
        }
        do {
            if let fresh = try await model.repository.post(id: postId) {
                post = fresh
                notFound = fresh.isHidden
            } else if post == nil {
                notFound = true
            }
        } catch {
            if post == nil { notFound = true }
        }
        isLoading = false
        comments = (try? await model.repository.comments(postId: postId)) ?? []
    }

    @MainActor
    private func resume(_ action: PendingAction) async {
        switch action {
        case .comment: commentFocused = true
        case .interest: await sendInterest()
        case .report: isReporting = true
        case .block: confirmBlock = true
        }
    }

    @MainActor
    private func sendComment() async {
        guard model.canParticipate else { pendingAction = .comment; return }
        isSending = true
        defer { isSending = false }
        do {
            try await model.repository.addComment(postId: postId, content: commentText, displayName: model.displayName)
            commentText = ""
            comments = (try? await model.repository.comments(postId: postId)) ?? comments
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    @MainActor
    private func sendInterest() async {
        guard let post else { return }
        do {
            try await model.repository.expressInterest(in: post, displayName: model.displayName, postURL: model.postURL(for: post))
            interestSent = true
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    @MainActor
    private func deleteComment(_ comment: Comment) async {
        do {
            try await model.repository.deleteComment(comment)
            comments.removeAll { $0.id == comment.id }
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    @MainActor
    private func block() async {
        guard let author = post?.authorUid else { return }
        do {
            try await model.block(author)
            dismiss()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    @MainActor
    private func deletePost() async {
        guard let post else { return }
        do {
            try await model.repository.deletePost(post)
            dismiss()
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}

private struct CommentRow: View {
    let comment: Comment

    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            AvatarView(urlString: comment.authorPhotoURL, name: comment.authorDisplayName, size: 30)
            VStack(alignment: .leading, spacing: 2) {
                HStack {
                    Text(comment.authorDisplayName).font(.subheadline.weight(.semibold))
                    if let date = comment.createdAt {
                        Text(date.sayItRelative).font(.caption).foregroundStyle(.secondary)
                    }
                }
                Text(comment.content).font(.callout)
            }
        }
        .padding(.vertical, 2)
    }
}
