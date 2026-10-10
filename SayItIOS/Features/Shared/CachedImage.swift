import SwiftUI
import UIKit

/// A remote image that stays loaded. Replaces `AsyncImage`, which cancels
/// its download whenever the view is rebuilt - the feed pager rebuilds
/// pages constantly, and a post is rebuilt again when the server adds its
/// link preview right after posting - and then shows nothing forever.
/// Here images are cached in memory, a reappearing view shows its image at
/// once, and a cancelled or failed download is tried again.
struct CachedImage<Content: View, Placeholder: View>: View {
    let url: URL?
    @ViewBuilder let content: (Image) -> Content
    /// Shown while loading (`false`) and once loading has failed (`true`).
    @ViewBuilder let placeholder: (_ failed: Bool) -> Placeholder

    @State private var image: UIImage?
    @State private var failed = false

    init(url: URL?, @ViewBuilder content: @escaping (Image) -> Content, @ViewBuilder placeholder: @escaping (_ failed: Bool) -> Placeholder) {
        self.url = url
        self.content = content
        self.placeholder = placeholder
        _image = State(initialValue: url.flatMap(ImageLoader.cached))
    }

    var body: some View {
        Group {
            if let image {
                content(Image(uiImage: image))
            } else {
                placeholder(failed)
            }
        }
        .task(id: url) { await load() }
    }

    private func load() async {
        guard let url else { return }
        if let cached = ImageLoader.cached(url) {
            image = cached
            return
        }
        image = nil
        failed = false
        for attempt in 0..<3 {
            if Task.isCancelled { return }
            if let loaded = await ImageLoader.load(url) {
                image = loaded
                return
            }
            try? await Task.sleep(for: .milliseconds(400 * (attempt + 1)))
        }
        if !Task.isCancelled { failed = true }
    }
}

extension CachedImage where Placeholder == EmptyView {
    init(url: URL?, @ViewBuilder content: @escaping (Image) -> Content) {
        self.init(url: url, content: content, placeholder: { _ in EmptyView() })
    }
}

enum ImageLoader {
    private static let cache: NSCache<NSURL, UIImage> = {
        let cache = NSCache<NSURL, UIImage>()
        cache.totalCostLimit = 80 * 1024 * 1024
        return cache
    }()

    static func cached(_ url: URL) -> UIImage? {
        cache.object(forKey: url as NSURL)
    }

    /// Downloads and caches the image; nil when it can't be loaded.
    static func load(_ url: URL) async -> UIImage? {
        guard let (data, response) = try? await URLSession.shared.data(from: url),
              (response as? HTTPURLResponse).map({ (200...299).contains($0.statusCode) }) ?? true,
              let image = UIImage(data: data)
        else { return nil }
        cache.setObject(image, forKey: url as NSURL, cost: data.count)
        return image
    }
}
