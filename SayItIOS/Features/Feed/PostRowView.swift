import SwiftUI

/// One post in the feed or at the top of the post view.
struct PostRowView: View {
    let post: Post
    var isDetail = false
    @State private var revealed = false

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 10) {
                AvatarView(urlString: post.photoURL, name: post.displayName, size: isDetail ? 48 : 40)
                VStack(alignment: .leading, spacing: 2) {
                    Text(post.displayName)
                        .font(.subheadline.weight(.semibold))
                    HStack(spacing: 6) {
                        if let date = post.timestamp {
                            Text(date.sayItRelative)
                        }
                        if post.category != "all" {
                            Text("·")
                            Text(PostCategory.label(for: post.category))
                        }
                    }
                    .font(.caption)
                    .foregroundStyle(.secondary)
                }
                Spacer(minLength: 0)
            }

            ZStack {
                content
                    .blur(radius: post.needsContentWarning && !revealed ? 12 : 0)
                    .accessibilityHidden(post.needsContentWarning && !revealed)

                if post.needsContentWarning && !revealed {
                    VStack(spacing: 6) {
                        Label("Sensitive content", systemImage: "eye.slash")
                            .font(.subheadline.weight(.semibold))
                        if let explanation = post.ratingExplanation {
                            Text(explanation)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                                .multilineTextAlignment(.center)
                                .lineLimit(3)
                        }
                        Button("Show anyway") { revealed = true }
                            .font(.caption.weight(.semibold))
                            .buttonStyle(.bordered)
                    }
                    .padding()
                }
            }
        }
        .padding(.vertical, 6)
    }

    @ViewBuilder
    private var content: some View {
        VStack(alignment: .leading, spacing: 10) {
            if !post.content.isEmpty {
                Text(attributedContent)
                    .font(isDetail ? .body : .callout)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .textSelection(.enabled)
            }

            if let imageURL = post.postImageURL.flatMap(URL.init(string:)) {
                RemoteImage(url: imageURL)
            } else if let preview = post.linkPreview {
                LinkPreviewCard(preview: preview)
            }
        }
    }

    /// Makes URLs in the post tappable.
    private var attributedContent: AttributedString {
        var attributed = AttributedString(post.content)
        guard let detector = try? NSDataDetector(types: NSTextCheckingResult.CheckingType.link.rawValue) else { return attributed }
        let text = post.content
        for match in detector.matches(in: text, range: NSRange(text.startIndex..., in: text)) {
            guard let url = match.url,
                  let range = Range(match.range, in: text),
                  let attributedRange = Range(range, in: attributed) else { continue }
            attributed[attributedRange].link = url
        }
        return attributed
    }
}

private struct RemoteImage: View {
    let url: URL

    var body: some View {
        AsyncImage(url: url) { phase in
            if let image = phase.image {
                image.resizable().scaledToFit()
            } else if phase.error != nil {
                EmptyView()
            } else {
                Rectangle().fill(.quaternary).frame(height: 180)
            }
        }
        .frame(maxWidth: .infinity)
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
    }
}

private struct LinkPreviewCard: View {
    let preview: LinkPreview

    var body: some View {
        let card = VStack(alignment: .leading, spacing: 6) {
            if let image = preview.image.flatMap(URL.init(string:)) {
                RemoteImage(url: image)
            }
            if let title = preview.title {
                Text(title).font(.subheadline.weight(.semibold)).lineLimit(2)
            }
            if let description = preview.description {
                Text(description).font(.caption).foregroundStyle(.secondary).lineLimit(3)
            }
        }
        .padding(10)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(RoundedRectangle(cornerRadius: 12, style: .continuous).fill(Color(.secondarySystemBackground)))

        if let url = preview.url.flatMap(URL.init(string:)) {
            Link(destination: url) { card }
                .buttonStyle(.plain)
        } else {
            card
        }
    }
}
