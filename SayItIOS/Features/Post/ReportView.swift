import SwiftUI

struct ReportView: View {
    @ObservedObject var model: AppModel
    let post: Post

    @Environment(\.dismiss) private var dismiss
    @State private var reason = ReportView.reasons[0]
    @State private var alsoBlock = false
    @State private var isSending = false
    @State private var sent = false
    @State private var errorMessage: String?

    static let reasons = ["Spam or scam", "Harassment or hate", "Sexual or violent content", "Impersonation", "Something else"]

    var body: some View {
        NavigationStack {
            Form {
                if sent {
                    Section {
                        Label("Thanks - we'll review this within 24 hours.", systemImage: "checkmark.seal.fill")
                            .foregroundStyle(.green)
                    }
                } else {
                    Section("Why are you reporting this post?") {
                        Picker("Reason", selection: $reason) {
                            ForEach(Self.reasons, id: \.self) { Text($0) }
                        }
                        .pickerStyle(.inline)
                        .labelsHidden()
                    }
                    if post.authorUid != nil {
                        Section {
                            Toggle("Also block \(post.displayName)", isOn: $alsoBlock)
                        }
                    }
                    if let errorMessage {
                        Text(errorMessage).foregroundStyle(.red)
                    }
                }
            }
            .navigationTitle("Report Post")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(sent ? "Done" : "Cancel") { dismiss() }
                }
                if !sent {
                    ToolbarItem(placement: .confirmationAction) {
                        if isSending {
                            ProgressView()
                        } else {
                            Button("Send") { Task { await send() } }
                        }
                    }
                }
            }
        }
    }

    @MainActor
    private func send() async {
        isSending = true
        errorMessage = nil
        defer { isSending = false }
        do {
            try await model.repository.report(post, reason: reason)
            await model.backend.notifyReport(post: post, reason: reason, reporterEmail: model.auth.currentUser?.email, postURL: model.postURL(for: post))
            if alsoBlock, let author = post.authorUid {
                try await model.block(author)
            }
            sent = true
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}
