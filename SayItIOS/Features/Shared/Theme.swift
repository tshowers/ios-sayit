import SwiftUI

/// The "Organic" design system from the Claude Design handoff
/// (design_handoff_sayit_post_feed/styles.css): cream ground, terracotta
/// accent, sage secondary, Caprasimo display type and Figtree body type.
enum Theme {
    static func hex(_ value: UInt32, _ opacity: Double = 1) -> Color {
        Color(.sRGB, red: Double((value >> 16) & 0xFF) / 255, green: Double((value >> 8) & 0xFF) / 255, blue: Double(value & 0xFF) / 255, opacity: opacity)
    }

    /// Follows the system appearance: the handoff's light value, or a dark
    /// counterpart from the same warm ramp.
    static func adaptive(_ light: UInt32, _ dark: UInt32, _ opacity: Double = 1) -> Color {
        func ui(_ v: UInt32) -> UIColor {
            UIColor(red: CGFloat((v >> 16) & 0xFF) / 255, green: CGFloat((v >> 8) & 0xFF) / 255, blue: CGFloat(v & 0xFF) / 255, alpha: opacity)
        }
        return Color(UIColor { $0.userInterfaceStyle == .dark ? ui(dark) : ui(light) })
    }

    // Ground and text (adaptive)
    static let ground = adaptive(0xF5EAD8, 0x1B1916)
    static let surface = adaptive(0xEBDDC5, 0x2B2723)
    static let text = adaptive(0x201E1D, 0xF3EBDD)
    static let divider = adaptive(0x201E1D, 0xF3EBDD, 0.16)
    /// Accent-colored text and links: terracotta 700 on light, 400 on dark.
    static let accentInk = adaptive(0x8C491A, 0xF6A06B)

    // Fixed: text on photos, scrims, filled buttons, tags with their own fill.
    static let cream = hex(0xF9F4ED)
    static let ink = hex(0x201E1D)
    static let scrim = hex(0x201E1D)

    // Terracotta
    static let accent = hex(0xC67139)
    static let accent100 = adaptive(0xFFF2EB, 0x3A2416)
    static let accent200 = hex(0xFFE1D0)
    static let accent400 = hex(0xF6A06B)
    static let accent600 = hex(0xB2622D)
    static let accent700 = hex(0x8C491A)
    static let accent800 = adaptive(0x643312, 0xFFC6A5)

    // Sage
    static let sage100 = adaptive(0xF0FAE1, 0x26301C)
    static let sage200 = hex(0xE1EECC)
    static let sage300 = hex(0xCCDBB2)
    static let sage700 = hex(0x56633F)
    static let sage800 = adaptive(0x3D472B, 0xCCDBB2)
    static let sage900 = hex(0x272E1B)

    // Neutrals (adaptive where they're grounds or secondary text)
    static let neutral100 = adaptive(0xF9F4ED, 0x25221E)
    static let neutral200 = adaptive(0xEEE7DB, 0x332F2A)
    static let neutral300 = hex(0xDCD3C4)
    static let neutral700 = adaptive(0x645C50, 0xB3A898)
    static let neutral800 = adaptive(0x474238, 0xD6CCBC)
    static let neutral900 = hex(0x2E2B25)
    static let media = hex(0x2E2B25)

    /// Type and column scale: 1 on phones, up to 1.35 on iPad, so text isn't
    /// phone-sized on a big screen.
    static let scale: CGFloat = {
        let shortSide = min(UIScreen.main.bounds.width, UIScreen.main.bounds.height)
        return min(max(shortSide / 390, 1), 1.35)
    }()

    /// Width of a post's content column on big screens (the design is a phone).
    static let readableWidth: CGFloat = 600

    /// Org tones (the handoff's sample orgs), all legible under cream text.
    static let orgPalette: [Color] = [hex(0x728157), hex(0xB2622D), hex(0x645C50), hex(0x8C491A), hex(0x56633F)]
    static func orgColor(_ name: String?) -> Color {
        guard let name, !name.isEmpty else { return neutral700 }
        return orgPalette[OrgDirectory.colorIndex(for: name) % orgPalette.count]
    }

    // Type
    static func display(_ size: CGFloat) -> Font { .custom("Caprasimo-Regular", size: size * scale, relativeTo: .title) }
    static func body(_ size: CGFloat, _ weight: Font.Weight = .regular) -> Font {
        .custom("Figtree", size: size * scale, relativeTo: .body).weight(weight)
    }
}

/// A pill button in the design's primary style.
struct PrimaryPillStyle: ButtonStyle {
    var fill: Color = Theme.accent600
    var pressedFill: Color = Theme.accent700

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .foregroundStyle(Theme.cream)
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
                AsyncImage(url: url) { phase in
                    if let image = phase.image { image.resizable().scaledToFill() } else { initials }
                }
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
            .foregroundStyle(Theme.ink)
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
                AsyncImage(url: parsed) { phase in
                    if let image = phase.image {
                        image.resizable().scaledToFill()
                            .saturation(0.9)
                    }
                }
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
