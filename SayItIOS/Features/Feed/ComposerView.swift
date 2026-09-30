import SwiftUI
import PhotosUI

/// New post: an optional photo, a headline, details, what it's for
/// (selling / looking for, with a price) and a category. Styled with the
/// design's tokens; the handoff didn't design this screen.
struct ComposerView: View {
    @ObservedObject var model: AppModel
    @Environment(\.dismiss) private var dismiss

    @State private var photoItem: PhotosPickerItem?
    @State private var photo: UIImage?
    @State private var title = ""
    @State private var caption = ""
    @State private var kind: PostKind?
    @State private var price = ""
    @State private var category: String
    @State private var isPosting = false
    @State private var status = ""
    @State private var errorMessage: String?
    @FocusState private var titleFocused: Bool

    static let titleLimit = 90
    static let captionLimit = 400

    init(model: AppModel, initialCategory: String) {
        self.model = model
        _category = State(initialValue: initialCategory)
    }

    private var canPost: Bool {
        let t = title.trimmingCharacters(in: .whitespacesAndNewlines)
        return !t.isEmpty && t.count <= Self.titleLimit && caption.count <= Self.captionLimit && !isPosting
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                photoPicker

                field("Headline", text: $title, prompt: "What do you need or offer?", limit: Self.titleLimit, axis: .vertical)
                    .focused($titleFocused)
                field("Details (optional)", text: $caption, prompt: "Anything people should know: when, where, how much.", limit: Self.captionLimit, axis: .vertical)

                VStack(alignment: .leading, spacing: 8) {
                    label("What's it for?")
                    HStack(spacing: 8) {
                        chip("Just sharing", selected: kind == nil) { kind = nil }
                        ForEach(PostKind.allCases, id: \.self) { option in
                            chip(option.label, selected: kind == option) { kind = option }
                        }
                    }
                    if kind != nil {
                        TextField(kind == .selling ? "Price, e.g. $18 each" : "Budget, e.g. Up to $600", text: $price)
                            .font(Theme.body(16))
                            .padding(14)
                            .background(Theme.surface, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                    }
                }

                VStack(alignment: .leading, spacing: 8) {
                    label("Industry")
                    Menu {
                        Picker("Industry", selection: $category) {
                            ForEach(PostCategory.all, id: \.self) { Text(PostCategory.label(for: $0)).tag($0) }
                        }
                    } label: {
                        HStack {
                            Text(PostCategory.label(for: category)).font(Theme.body(16, .semibold)).foregroundStyle(Theme.text)
                            Spacer()
                            Image(systemName: "chevron.up.chevron.down").foregroundStyle(Theme.neutral700)
                        }
                        .padding(14)
                        .background(Theme.surface, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                    }
                }

                Text("Posts are public and screened automatically. Posting as \(model.displayName)\(model.profile?.businessName.isEmpty == false ? " at \(model.profile!.businessName)" : "").")
                    .font(Theme.body(12.5)).foregroundStyle(Theme.neutral700)

                if let errorMessage {
                    Text(errorMessage).font(Theme.body(13, .semibold)).foregroundStyle(Theme.accentInk)
                }

                Button { Task { await post() } } label: {
                    HStack(spacing: 8) {
                        if isPosting { ProgressView().tint(Theme.cream) }
                        Text(isPosting ? status : "Post it").font(Theme.display(18))
                    }
                    .frame(maxWidth: .infinity, minHeight: 54)
                }
                .buttonStyle(PrimaryPillStyle())
                .disabled(!canPost)
                .opacity(canPost || isPosting ? 1 : 0.5)
            }
            .padding(20)
        }
        .scrollDismissesKeyboard(.interactively)
        .background(Theme.ground.ignoresSafeArea())
        .navigationTitle("New post")
        .navigationBarTitleDisplayMode(.inline)
        .navigationBarBackButtonHidden(isPosting)
        .onAppear { titleFocused = true }
        .onChange(of: photoItem) { _, item in
            Task {
                guard let item, let data = try? await item.loadTransferable(type: Data.self) else { return }
                photo = UIImage(data: data)
            }
        }
    }

    private var photoPicker: some View {
        PhotosPicker(selection: $photoItem, matching: .images) {
            ZStack {
                if let photo {
                    Image(uiImage: photo).resizable().scaledToFill()
                } else {
                    Theme.media
                    Stripes(color: Theme.neutral700.opacity(0.35))
                    VStack(spacing: 6) {
                        Image(systemName: "photo.badge.plus").font(.system(size: 28, weight: .semibold))
                        Text("Add a photo").font(Theme.body(14, .bold))
                        Text("Optional - posts without one show as a quote card.").font(Theme.body(12))
                    }
                    .foregroundStyle(Theme.cream)
                }
            }
            .frame(height: 200)
            .frame(maxWidth: .infinity)
            .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
            .overlay(alignment: .topTrailing) {
                if photo != nil {
                    Button {
                        photo = nil
                        photoItem = nil
                    } label: {
                        Image(systemName: "xmark").font(.system(size: 13, weight: .bold)).foregroundStyle(Theme.cream)
                            .frame(width: 30, height: 30).background(Theme.scrim.opacity(0.6), in: Circle())
                    }
                    .padding(10)
                    .accessibilityLabel("Remove photo")
                }
            }
        }
        .accessibilityLabel(photo == nil ? "Add a photo" : "Change photo")
    }

    private func label(_ text: String) -> some View {
        Text(text).font(Theme.body(13, .bold)).foregroundStyle(Theme.neutral800)
    }

    private func field(_ title: String, text: Binding<String>, prompt: String, limit: Int, axis: Axis) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                label(title)
                Spacer()
                Text("\(limit - text.wrappedValue.count)").font(Theme.body(12)).foregroundStyle(text.wrappedValue.count > limit ? Theme.accentInk : Theme.neutral700)
            }
            TextField(prompt, text: text, axis: axis)
                .font(Theme.body(16))
                .lineLimit(axis == .vertical ? 2...6 : 1...1)
                .padding(14)
                .background(Theme.surface, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
        }
    }

    private func chip(_ text: String, selected: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(text).font(Theme.body(13, .bold))
                .padding(.horizontal, 14).frame(height: 36)
                .foregroundStyle(selected ? Theme.ground : Theme.text)
                .background(selected ? Theme.text : .clear, in: Capsule())
                .overlay(Capsule().stroke(selected ? .clear : Theme.divider))
        }
        .accessibilityAddTraits(selected ? .isSelected : [])
    }

    @MainActor
    private func post() async {
        let headline = title.trimmingCharacters(in: .whitespacesAndNewlines)
        let details = caption.trimmingCharacters(in: .whitespacesAndNewlines)
        isPosting = true
        errorMessage = nil
        defer { isPosting = false }

        do {
            var image: (url: String, path: String)?
            if let photo, let jpeg = Self.jpeg(photo) {
                status = "Uploading photo…"
                image = try await model.repository.uploadPostImage(jpeg)
            }
            status = "Posting…"
            let content = details.isEmpty ? headline : "\(headline)\n\n\(details)"
            let moderation = await model.backend.moderate(content: content, category: category)
            let org = model.profile?.businessName.trimmingCharacters(in: .whitespaces) ?? ""
            let role = model.profile?.role.trimmingCharacters(in: .whitespaces) ?? ""
            let trimmedPrice = price.trimmingCharacters(in: .whitespaces)
            try await model.repository.publish(.init(
                content: content,
                category: category,
                displayName: model.displayName,
                photoURL: model.profile?.photoURL ?? model.auth.currentUser?.photoURL?.absoluteString,
                authorHandle: model.profile?.handle,
                moderation: moderation,
                title: headline,
                caption: details.isEmpty ? nil : details,
                kind: kind,
                price: kind == nil || trimmedPrice.isEmpty ? nil : trimmedPrice,
                imageURL: image?.url,
                imagePath: image?.path,
                authorRole: role.isEmpty ? nil : role,
                orgName: org.isEmpty ? nil : org
            ))
            Task { await model.refreshAwardStats() }
            model.showToast("Posted")
            dismiss()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    /// At most 1600px on the long side, JPEG 0.8.
    static func jpeg(_ image: UIImage) -> Data? {
        let maxSide: CGFloat = 1600
        let scale = min(1, maxSide / max(image.size.width, image.size.height))
        let size = CGSize(width: image.size.width * scale, height: image.size.height * scale)
        let resized = UIGraphicsImageRenderer(size: size).image { _ in image.draw(in: CGRect(origin: .zero, size: size)) }
        return resized.jpegData(compressionQuality: 0.8)
    }
}
