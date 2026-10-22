import SwiftUI

/// The "Find" design system, same tokens as the web app
/// (web-products/sayit/design_handoff_sayit_find_2/README.md): white / near-black
/// ground, gray surfaces, blue primary, six soft tints, Helvetica Neue.
/// The property names are the older Organic ones, re-pointed at Find values.
enum Theme {
    static func hex(_ value: UInt32, _ opacity: Double = 1) -> Color {
        Color(.sRGB, red: Double((value >> 16) & 0xFF) / 255, green: Double((value >> 8) & 0xFF) / 255, blue: Double(value & 0xFF) / 255, opacity: opacity)
    }

    /// Follows the system appearance: the light token, or its dark counterpart.
    static func adaptive(_ light: UInt32, _ dark: UInt32, _ opacity: Double = 1) -> Color {
        func ui(_ v: UInt32) -> UIColor {
            UIColor(red: CGFloat((v >> 16) & 0xFF) / 255, green: CGFloat((v >> 8) & 0xFF) / 255, blue: CGFloat(v & 0xFF) / 255, alpha: opacity)
        }
        return Color(UIColor { $0.userInterfaceStyle == .dark ? ui(dark) : ui(light) })
    }

    // Ground and text (adaptive): --bg, --surface, --surface2, --text, --muted
    static let ground = adaptive(0xFFFFFF, 0x0C0E13)
    /// Behind posts: the page ground.
    static let stage = adaptive(0xFFFFFF, 0x0C0E13)
    /// A card sitting on the ground.
    static let card = adaptive(0xF2F3F6, 0x171A22)
    static let surface = adaptive(0xF2F3F6, 0x171A22)
    static let text = adaptive(0x0F1115, 0xF2F4F8)
    /// Find separates by fill, not lines; where a line is still drawn it's --surface2.
    static let divider = adaptive(0xE4E7ED, 0x242936)
    /// Links and accent text: --blue-ink.
    static let accentInk = adaptive(0x1F55E0, 0x86AEFF)

    // Fixed: text on photos, scrims, filled buttons.
    static let cream = hex(0xFFFFFF)
    static let ink = hex(0x0F1115)
    static let scrim = hex(0x0F1115)

    // Blue (primary action) and the blue tint
    static let accent = adaptive(0x2F6BFF, 0x3D7BFF)
    static let accent100 = adaptive(0xE3ECFF, 0x15254A)
    static let accent200 = adaptive(0xE3ECFF, 0x15254A)
    static let accent400 = adaptive(0x2F6BFF, 0x3D7BFF)
    static let accent600 = adaptive(0x2F6BFF, 0x3D7BFF)
    static let accent700 = adaptive(0x1F55E0, 0x2F6BFF)
    static let accent800 = adaptive(0x1D4FD6, 0xA3C1FF)

    // Green tint (kind tags, success)
    static let sage100 = adaptive(0xE0F6E6, 0x0E2C19)
    static let sage200 = adaptive(0xE0F6E6, 0x0E2C19)
    static let sage300 = adaptive(0xC6EDD1, 0x174226)
    /// Solid green, legible under white text in both modes.
    static let sage700 = hex(0x17703A)
    static let sage800 = adaptive(0x17703A, 0x80E2A4)
    static let sage900 = adaptive(0x17703A, 0x80E2A4)

    // Neutrals: grounds, --surface2, and secondary text (--muted)
    static let neutral100 = adaptive(0xF2F3F6, 0x171A22)
    static let neutral200 = adaptive(0xE4E7ED, 0x242936)
    static let neutral300 = adaptive(0xE4E7ED, 0x242936)
    static let neutral700 = adaptive(0x5A6170, 0x9AA2B2)
    static let neutral800 = adaptive(0x454B57, 0xB4BBC8)
    static let neutral900 = hex(0x0F1115)
    static let media = adaptive(0xF2F3F6, 0x171A22)

    // The six Find tints, background / foreground, in the web app's order
    static let tints: [(bg: Color, fg: Color)] = [
        (adaptive(0xE3ECFF, 0x15254A), adaptive(0x1D4FD6, 0xA3C1FF)), // blue
        (adaptive(0xDAF6FC, 0x0C2D35), adaptive(0x08657D, 0x74E4F8)), // cyan
        (adaptive(0xEFE5FF, 0x2A1847), adaptive(0x6427C9, 0xCDAAFF)), // violet
        (adaptive(0xFFF4C2, 0x2F2906), adaptive(0x6E5700, 0xFFE56A)), // yellow
        (adaptive(0xE0F6E6, 0x0E2C19), adaptive(0x17703A, 0x80E2A4)), // green
        (adaptive(0xFFE3F1, 0x3A1029), adaptive(0xA8105A, 0xFF92C9)), // pink
    ]

    /// A post's tint, stable per key: the same hash as the web's tintFor(),
    /// so a post has the same color in the app and on the web.
    static func tint(for key: String) -> (bg: Color, fg: Color) {
        var hash: Int32 = 0
        for unit in key.utf16 { hash = hash &* 31 &+ Int32(unit) }
        return tints[Int(abs(Int64(hash)) % Int64(tints.count))]
    }

    /// Type and column scale: 1 on phones, up to 1.35 on iPad, so text isn't
    /// phone-sized on a big screen.
    static let scale: CGFloat = {
        let shortSide = min(UIScreen.main.bounds.width, UIScreen.main.bounds.height)
        return min(max(shortSide / 390, 1), 1.35)
    }()

    /// Width of a post's content column on big screens (the design is a phone).
    static let readableWidth: CGFloat = 600

    /// Org tones (the tint foregrounds' light values), all legible under white text.
    static let orgPalette: [Color] = [hex(0x2F6BFF), hex(0x6427C9), hex(0x08657D), hex(0xA8105A), hex(0x17703A)]
    static func orgColor(_ name: String?) -> Color {
        guard let name, !name.isEmpty else { return neutral700 }
        return orgPalette[OrgDirectory.colorIndex(for: name) % orgPalette.count]
    }

    // Type: Helvetica Neue throughout; headings are bold (add tight tracking at the call site).
    static func display(_ size: CGFloat) -> Font { .custom("HelveticaNeue-Bold", size: size * scale, relativeTo: .title) }
    static func body(_ size: CGFloat, _ weight: Font.Weight = .regular) -> Font {
        .custom("Helvetica Neue", size: size * scale, relativeTo: .body).weight(weight)
    }
}

/// A pill button in the design's primary style.
struct PrimaryPillStyle: ButtonStyle {
    var fill: Color = Theme.accent600
    var pressedFill: Color = Theme.accent700
    var ink: Color = Theme.cream

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .foregroundStyle(ink)
            .background(configuration.isPressed ? pressedFill : fill, in: Capsule())
            .scaleEffect(configuration.isPressed ? 0.97 : 1)
            .animation(.easeOut(duration: 0.15), value: configuration.isPressed)
    }
}

/// Scale-on-press for icon buttons (0.94 for the big round button).
struct PressScaleStyle: ButtonStyle {
    var scale: CGFloat = 0.97
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? scale : 1)
            .animation(.easeOut(duration: 0.15), value: configuration.isPressed)
    }
}

/// Initials avatar with an optional org-color ring (design: 3pt ring).
struct RingAvatar: View {
    let name: String
    var photoURL: String?
    var size: CGFloat = 42
    var ring: Color?

    var body: some View {
        ZStack {
            Circle().fill(Theme.neutral300)
            if let photoURL, let url = URL(string: photoURL) {
                CachedImage(url: url) { $0.resizable().scaledToFill() } placeholder: { _ in initials }
                    .clipShape(Circle())
            } else {
                initials
            }
        }
        .frame(width: size, height: size)
        .overlay {
            if let ring { Circle().stroke(ring, lineWidth: 3) }
        }
        .accessibilityHidden(true)
    }

    private var initials: some View {
        Text(Formatting.initials(name))
            .font(Theme.body(size * 0.33 / Theme.scale, .bold))
            .foregroundStyle(Theme.text)
    }
}

/// Small uppercase tag ("SELLING", "Verified" is never used).
struct KindTag: View {
    let text: String
    var fill: Color = Theme.sage200
    var ink: Color = Theme.sage900

    var body: some View {
        Text(text.uppercased())
            .font(Theme.body(11, .bold))
            .tracking(0.66)
            .padding(.horizontal, 9)
            .frame(height: 22)
            .foregroundStyle(ink)
            .background(fill, in: Capsule())
    }
}

/// The design's striped placeholder / photo area with the "washed" treatment.
struct PostMedia: View {
    let url: String?
    var tint: Color = Theme.media

    var body: some View {
        ZStack {
            Theme.media
            Stripes(color: tint.opacity(0.35))
            if let url, let parsed = URL(string: url) {
                CachedImage(url: parsed) { $0.resizable().scaledToFill().saturation(0.9) }
            }
        }
        .clipped()
    }
}

struct Stripes: View {
    let color: Color
    var body: some View {
        Canvas { context, size in
            let band: CGFloat = 14
            var x: CGFloat = -size.height
            while x < size.width + size.height {
                var path = Path()
                path.move(to: CGPoint(x: x, y: size.height))
                path.addLine(to: CGPoint(x: x + band, y: size.height))
                path.addLine(to: CGPoint(x: x + band + size.height, y: 0))
                path.addLine(to: CGPoint(x: x + size.height, y: 0))
                path.closeSubpath()
                context.fill(path, with: .color(color))
                x += band * 2
            }
        }
        .allowsHitTesting(false)
    }
}

/// Auto-dismissing toast pill (design: 2.4s).
struct ToastView: View {
    let message: String
    var body: some View {
        Text(message)
            .font(Theme.body(13, .semibold))
            .padding(.vertical, 10)
            .padding(.horizontal, 16)
            .foregroundStyle(Theme.cream)
            .background(Theme.scrim.opacity(0.9), in: Capsule())
            .shadow(color: Theme.neutral900.opacity(0.22), radius: 16, y: 6)
            .accessibilityAddTraits(.isStaticText)
    }
}
