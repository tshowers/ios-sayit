import SwiftUI

struct ComposerView: View {
    @ObservedObject var model: AppModel
    @Environment(\.dismiss) private var dismiss

    @State private var text = ""
    @State private var category: String
    @State private var isPosting = false
    @State private var errorMessage: String?
    @FocusState private var focused: Bool

    init(model: AppModel, initialCategory: String) {
        self.model = model
        _category = State(initialValue: initialCategory)
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField("Hi \(model.displayName), say it…", text: $text, axis: .vertical)
                        .lineLimit(4...8)
                        .focused($focused)
                } footer: {
                    Text("\(PostDraft.remaining(text)) characters left")
                        .foregroundStyle(PostDraft.remaining(text) < 0 ? .red : .secondary)
                }

                Section {
                    Picker("Category", selection: $category) {
                        ForEach(PostCategory.all, id: \.self) { value in
                            Text(PostCategory.label(for: value)).tag(value)
                        }
                    }
                } footer: {
                    Text("Posts are public and screened automatically. Posting as \(model.displayName).")
                }

                if let errorMessage {
                    Text(errorMessage).foregroundStyle(.red)
                }
            }
            .navigationTitle("New Post")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    if isPosting {
                        ProgressView()
                    } else {
                        Button("Post") { Task { await post() } }
                            .disabled(!PostDraft.canPost(text))
                    }
                }
            }
            .onAppear { focused = true }
            .interactiveDismissDisabled(isPosting)
        }
    }

    @MainActor
    private func post() async {
        let content = PostDraft.cleaned(text)
        isPosting = true
        errorMessage = nil
        defer { isPosting = false }

        let moderation = await model.backend.moderate(content: content, category: category)
        do {
            try await model.repository.publish(.init(
                content: content,
                category: category,
                displayName: model.displayName,
                photoURL: model.profile?.photoURL ?? model.auth.currentUser?.photoURL?.absoluteString,
                authorHandle: model.profile?.handle,
                moderation: moderation
            ))
            dismiss()
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}
