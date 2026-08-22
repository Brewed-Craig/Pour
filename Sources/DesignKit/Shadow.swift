import SwiftUI

/// CSS-style two-layer shadows. SwiftUI's `.shadow()` is single-layer, so each token
/// stacks two via `PourShadowModifier`.
public struct PourShadowStyle {
    let layers: [(color: Color, radius: CGFloat, x: CGFloat, y: CGFloat)]

    public static let sm = PourShadowStyle(layers: [
        (.black.opacity(0.35), 1, 0, 1),
        (.black.opacity(0.28), 10, 0, 4)
    ])

    public static let md = PourShadowStyle(layers: [
        (.black.opacity(0.40), 2, 0, 2),
        (.black.opacity(0.40), 24, 0, 12)
    ])

    public static let glowAmber = PourShadowStyle(layers: [
        (PourColor.amber.opacity(0.35), 0, 0, 0),
        (PourColor.amber.opacity(0.28), 20, 0, 0)
    ])

    public static let glowBlue = PourShadowStyle(layers: [
        (PourColor.blue500.opacity(0.35), 0, 0, 0),
        (PourColor.blue500.opacity(0.24), 20, 0, 0)
    ])
}

private struct PourShadowModifier: ViewModifier {
    let style: PourShadowStyle
    func body(content: Content) -> some View {
        content
            .shadow(color: style.layers[0].color, radius: style.layers[0].radius, x: style.layers[0].x, y: style.layers[0].y)
            .shadow(color: style.layers[1].color, radius: style.layers[1].radius, x: style.layers[1].x, y: style.layers[1].y)
    }
}

extension View {
    public func pourShadow(_ style: PourShadowStyle) -> some View {
        modifier(PourShadowModifier(style: style))
    }
}
