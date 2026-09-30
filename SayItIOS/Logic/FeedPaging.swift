import Foundation

/// The design's one-post-at-a-time pager rules: a 60pt drag pages, less
/// snaps back, and the first/last post rubber-bands at 30%.
enum FeedPaging {
    static let threshold: Double = 60
    static let rubberBand: Double = 0.3
    /// Drags beyond this don't count as taps.
    static let tapSlop: Double = 6

    static func index(after dragWidth: Double, from current: Int, count: Int) -> Int {
        guard count > 0 else { return 0 }
        if dragWidth <= -threshold { return min(current + 1, count - 1) }
        if dragWidth >= threshold { return max(current - 1, 0) }
        return current
    }

    /// How far the page follows the finger, damped past either end.
    static func offset(for dragWidth: Double, at current: Int, count: Int) -> Double {
        let atStart = current == 0 && dragWidth > 0
        let atEnd = current >= count - 1 && dragWidth < 0
        return (atStart || atEnd) ? dragWidth * rubberBand : dragWidth
    }
}
