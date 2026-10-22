import SwiftUI

struct ReportView: View {
    @ObservedObject var model: AppModel
    let post: Post
    /// Set when reporting a comment rather than the post.
    var comment: Comment? = nil

    @Environment(\.dismiss) private var dismiss
    @State private var reason = ReportView.reasons[0]
    @State private var alsoBlock = false
    @State private var isSending = false
    @State private var sent = false
    @State private var errorMessage: String?

    static let reasons = ["Spam or scam", "Harassment or hate", "Sexual or violent content", "Impersonation", "Something else"]

    var body: some View {
        Form {
            if sent {
                Section {
                    Label("Thanks - we'll review this within 24 hours.", systemImage: "checkmark.seal.fill")
                        .foregroundStyle(.green)
                }
                    .listRowBackground(Theme.neutral100)
            } else {
                Section(comment == nil ? "Why are you reporting this post?" : "Why are you reporting this comment?") {
                    Picker("Reason", selection: $reason) {
                        ForEach(Self.reasons, id: \.self) { Text($0) }
                    }
                    .pickerStyle(.inline)
                    .labelsHidden()
                }
                    .listRowBackground(Theme.neutral100)
                if let name = blockableName {
                    Section {
                        Toggle("Also block \(name)", isOn: $alsoBlock)
                    }
                    .listRowBackground(Theme.neutral100)
                }
                Section {
                    Text(comment == nil ? "The post disappears from your feed right away. We review every report within 24 hours, remove content that breaks the Community Guidelines, and ban whoever posted it." : "We review every report within 24 hours, remove content that breaks the Community Guidelines, and ban whoever posted it.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                    ContactSupportLink()
                }
                .listRowBackground(Theme.neutral100)
                if let errorMessage {
                    Text(errorMessage).foregroundStyle(.red)
                }
            }
        }
        .scrollContentBackground(.hidden)
        .background(Theme.ground.ignoresSafeArea())
        .navigationTitle(comment == nil ? "Report Post" : "Report Comment")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .confirmationAction) {
                if sent {
                    Button("Done") { dismiss() }
                } else if isSending {
                    ProgressView()
                } else {
                    Button("Send") { Task { await send() } }
                }
            }
        }
    }

    private var blockableUid: String? { comment?.authorUid ?? post.authorUid }
    private var blockableName: String? {
        guard blockableUid != nil, blockableUid != model.auth.userId else { return nil }
        return comment?.authorDisplayName ?? post.displayName
    }

    @MainActor
    private func send() async {
        isSending = true
        errorMessage = nil
        defer { isSending = false }
        do {
            // The backend emails the moderator about every new report
            // (post-reports trigger), so it works for every user.
            try await model.repository.report(post, comment: comment, reason: reason)
            if comment == nil { model.hidePost(post.id) }
            if alsoBlock, let author = blockableUid, let name = blockableName {
                try await model.block(SeededPosts.blockKey(authorUid: author, displayName: name))
            }
            sent = true
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}

/// How to reach us about anything inappropriate (guideline 1.2 asks for
/// contact information inside the app).
struct ContactSupportLink: View {
    var body: some View {
        if let mail = URL(string: "mailto:\(AppConfig.supportEmail)?subject=Say%20It%20-%20report%20a%20problem") {
            Link(destination: mail) {
                Label("Contact us: \(AppConfig.supportEmail)", systemImage: "envelope")
            }
        }
    }
}
