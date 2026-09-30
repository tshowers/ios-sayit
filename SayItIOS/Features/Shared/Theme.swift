import SwiftUI

/// The "Organic" design system from the Claude Design handoff
/// (design_handoff_sayit_post_feed/styles.css): cream ground, terracotta
/// accent, sage secondary, Caprasimo display type and Figtree body type.
enum Theme {
    static func hex(_ value: UInt32, _ opacity: Double = 1) -> Color {
        Color(.sRGB, red: Double((value >> 16) & 0xFF) / 255, green: Double((value >> 8) & 0xFF) / 255, blue: Double(value & 0xFF) / 255, opacity: opacity)
    }

    // Ground and text
    static let ground = hex(0xF5EAD8)
    static let surface = hex(0xEBDDC5)
    static let text = hex(0x201E1D)
    static let divider = hex(0x201E1D, 0.16)
    static let cream = hex(0xF9F4ED)
    static let scrim = hex(0x201E1D)

    // Terracotta
    static let accent = hex(0xC67139)
    static let accent100 = hex(0xFFF2EB)
    static let accent200 = hex(0xFFE1D0)
    static let accent400 = hex(0xF6A06B)
    static let accent600 = hex(0xB2622D)
    static let accent700 = hex(0x8C491A)
    static let accent800 = hex(0x643312)

    // Sage
    static let sage100 = hex(0xF0FAE1)
    static let sage200 = hex(0xE1EECC)
    static let sage300 = hex(0xCCDBB2)
    static let sage700 = hex(0x56633F)
    static let sage800 = hex(0x3D472B)
    static let sage900 = hex(0x272E1B)

    // Neutrals
    static let neutral100 = hex(0xF9F4ED)
    static let neutral200 = hex(0xEEE7DB)
    static let neutral300 = hex(0xDCD3C4)
    static let neutral700 = hex(0x645C50)
    static let neutral800 = hex(0x474238)
    static let neutral900 = hex(0x2E2B25)
    static let media = hex(0x2E2B25)

    /// Org tones (the handoff's sample orgs), all legible under cream text.
    static let orgPalette: [Color] = [hex(0x728157), hex(0xB2622D), hex(0x645C50), hex(0x8C491A), hex(0x56633F)]
    static func orgColor(_ name: String?) -> Color {
        guard let name, !name.isEmpty else { return neutral700 }
        return orgPalette[OrgDirectory.colorIndex(for: name) % orgPalette.count]
    }

    // Type
    static func display(_ size: CGFloat) -> Font { .custom("Caprasimo-Regular", size: size, relativeTo: .title) }
    static func body(_ size: CGFloat, _ weight: Font.Weight = .regular) -> Font {
        .custom("Figtree", size: size, relativeTo: .body).weight(weight)
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
            .font(Theme.body(size * 0.33, .bold))
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
            .background(Theme.text.opacity(0.9), in: Capsule())
            .shadow(color: Theme.neutral900.opacity(0.22), radius: 16, y: 6)
            .accessibilityAddTraits(.isStaticText)
    }
}
