import Foundation

/// The three feed designs from the Claude Design handoff (1a/1b/1c). Each
/// member picks one in onboarding and can change it under Me; every like,
/// interest and message records which layout it came from
/// (`sayit-layout-events`) so the winner can be chosen on real engagement.
enum FeedLayout: String, Codable, CaseIterable, Identifiable {
    case overlay = "1a"
    case sheet = "1b"
    case ribbon = "1c"

    var id: String { rawValue }
    static let `default`: FeedLayout = .sheet

    var name: String {
        switch self {
        case .overlay: return "Overlay"
        case .sheet: return "Card"
        case .ribbon: return "Ribbon"
        }
    }

    var summary: String {
        switch self {
        case .overlay: return "Words over the photo, buttons on the side."
        case .sheet: return "The post sits on a soft card over the photo."
        case .ribbon: return "Big headline, price sticker, round button."
        }
    }
}
