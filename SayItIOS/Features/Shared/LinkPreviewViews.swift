import SwiftUI
import WebKit

// Link previews and in-place video, matching the web board: a post's link
// shows as its page's site, title and summary (the URL itself is hidden), and
// YouTube / Vimeo links play in a theater-mode player.

/// Under a feed post's words: the linked site, the page's title (when the
/// headline is the person's own words) and summary. Tapping opens the link.
struct PostLinkRow: View {
    let post: Post
    var onPlay: (PostVideo) -> Void

    var body: some View {
        if let preview = post.linkPreview, let url = preview.url.flatMap(URL.init(string:)) {
            let video = post.linkVideo
            let site = preview.siteName ?? video?.siteName ?? url.host?.replacingOccurrences(of: "www.", with: "")
            let showTitle = preview.title.map { !$0.isEmpty && $0 != post.headline } ?? false
            let summary = preview.description.flatMap { $0.isEmpty ? nil : $0 }

            HStack(alignment: .center, spacing: 12) {
                VStack(alignment: .leading, spacing: 3) {
                    if let site {
                        Text(site.uppercased()).font(Theme.body(10.5, .bold)).tracking(1.2).foregroundStyle(Theme.neutral700)
                    }
                    if showTitle, let title = preview.title {
                        Text(title).font(Theme.body(14, .semibold)).foregroundStyle(Theme.text).lineLimit(2)
                    }
                    if let summary {
                        Text(summary).font(Theme.body(12.5)).foregroundStyle(Theme.neutral800).lineLimit(2)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                if let video {
                    Button { onPlay(video) } label: {
                        Label("Play", systemImage: "play.fill").font(Theme.body(13, .bold))
                            .padding(.horizontal, 14).frame(height: 36)
                            .foregroundStyle(Theme.cream)
                            .background(Theme.accent600, in: Capsule())
                    }
                    .buttonStyle(PressScaleStyle())
                    .accessibilityLabel("Play video")
                } else {
                    Image(systemName: "arrow.up.right").font(.system(size: 13, weight: .bold)).foregroundStyle(Theme.neutral700)
                        .accessibilityHidden(true)
                }
            }
            .padding(.horizontal, 12).padding(.vertical, 10)
            .background(Theme.text.opacity(0.06), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
            .contentShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
            .onTapGesture {
                if let video { onPlay(video) } else { UIApplication.shared.open(url) }
            }
            .accessibilityElement(children: .combine)
            .accessibilityAddTraits(.isLink)
            .accessibilityHint(video == nil ? "Opens the link" : "Plays the video")
        }
    }
}

/// The round play button over a video's thumbnail.
struct PlayBadge: View {
    var size: CGFloat = 64
    var body: some View {
        Image(systemName: "play.fill")
            .font(.system(size: size * 0.38, weight: .bold))
            .foregroundStyle(Theme.cream)
            .offset(x: size * 0.04)
            .frame(width: size, height: size)
            .background(.ultraThinMaterial, in: Circle())
            .overlay(Circle().stroke(Theme.cream.opacity(0.35), lineWidth: 1))
            .shadow(color: .black.opacity(0.3), radius: 10, y: 4)
    }
}

/// Theater mode: the video on black, filling the width (or the height in
/// landscape), with a close button.
struct VideoTheaterView: View {
    let video: PostVideo
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        ZStack(alignment: .topTrailing) {
            Color.black.ignoresSafeArea()
            VideoPlayerWebView(video: video)
                .aspectRatio(16 / 9, contentMode: .fit)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            Button { dismiss() } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 16, weight: .bold))
                    .foregroundStyle(.white)
                    .frame(width: 44, height: 44)
                    .background(.white.opacity(0.16), in: Circle())
            }
            .padding(16)
            .accessibilityLabel("Close video")
        }
        .statusBarHidden()
    }
}

/// On a post's page: the thumbnail with a play button, which turns into the
/// player in place when tapped.
struct InlineVideoView: View {
    let video: PostVideo
    var thumbnail: String?
    @State private var isPlaying = false

    var body: some View {
        ZStack {
            Color.black
            if isPlaying {
                VideoPlayerWebView(video: video)
            } else {
                Button { isPlaying = true } label: {
                    ZStack {
                        AsyncImage(url: (thumbnail ?? video.thumbnailURL).flatMap(URL.init(string:))) { phase in
                            if let image = phase.image { image.resizable().scaledToFill() } else { Color.black }
                        }
                        PlayBadge()
                    }
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Play video")
            }
        }
        .aspectRatio(16 / 9, contentMode: .fit)
        .frame(maxWidth: .infinity)
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
    }
}

/// The YouTube or Vimeo player in a web view. The player is loaded inside a
/// small page whose address is the Say It site: YouTube's embedded player
/// refuses to play without a referring site.
struct VideoPlayerWebView: UIViewRepresentable {
    let video: PostVideo

    func makeUIView(context: Context) -> WKWebView {
        let configuration = WKWebViewConfiguration()
        configuration.allowsInlineMediaPlayback = true
        configuration.mediaTypesRequiringUserActionForPlayback = []
        let webView = WKWebView(frame: .zero, configuration: configuration)
        webView.isOpaque = false
        webView.backgroundColor = .black
        webView.scrollView.isScrollEnabled = false
        webView.loadHTMLString(html, baseURL: URL(string: "https://sayit.taliferro.tech"))
        return webView
    }

    func updateUIView(_ webView: WKWebView, context: Context) {}

    static func dismantleUIView(_ webView: WKWebView, coordinator: ()) {
        // Stops the sound when the player goes away.
        webView.loadHTMLString("", baseURL: nil)
    }

    private var html: String {
        """
        <!doctype html><html><head>
        <meta name="viewport" content="width=device-width, initial-scale=1, maximum-scale=1">
        <meta name="referrer" content="strict-origin-when-cross-origin">
        <style>html,body{margin:0;height:100%;background:#000}iframe{position:fixed;inset:0;width:100%;height:100%;border:0}</style>
        </head><body>
        <iframe src="\(video.embedURL.absoluteString)" allow="autoplay; encrypted-media; picture-in-picture; fullscreen" allowfullscreen></iframe>
        </body></html>
        """
    }
}
