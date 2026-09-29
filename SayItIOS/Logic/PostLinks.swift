import Foundation

/// Links between the app and sayit.taliferro.tech. Shared posts are
/// `https://sayit.taliferro.tech/post/<id>` - the web opens the isolated
/// post view, and with the app installed iOS opens it here instead
/// (Universal Links).
enum PostLinks {
    static let hosts: Set<String> = ["sayit.taliferro.tech", "todd-sayit.web.app"]

    static func url(forPostId id: String, base: URL) -> URL {
        base.appending(path: "post").appending(path: id)
    }

    /// The post id in a SayIt link, or nil if it isn't one. Understands
    /// `/post/<id>` and the old `/?post=<id>` share links.
    static func postId(from url: URL) -> String? {
        guard let host = url.host?.lowercased(), hosts.contains(host) else { return nil }

        let parts = url.pathComponents.filter { $0 != "/" }
        if parts.count >= 2, parts[0] == "post" {
            let id = parts[1].trimmingCharacters(in: .whitespaces)
            return id.isEmpty ? nil : id
        }

        if parts.isEmpty,
           let id = URLComponents(url: url, resolvingAgainstBaseURL: false)?
            .queryItems?.first(where: { $0.name == "post" })?.value?
            .trimmingCharacters(in: .whitespaces),
           !id.isEmpty {
            return id
        }
        return nil
    }
}
