import SwiftUI

/// Shared surface/control styling so views never reach for a one-off value.
extension View {

    /// The standard panel surface: `surfacePanel` fill, hairline border, `lg` radius,
    /// resting shadow.
    public func pourCard(padding: CGFloat = PourSpace.md) -> some View {
        self
            .padding(padding)
            .background(PourColor.surfacePanel)
            .clipShape(RoundedRectangle(cornerRadius: PourRadius.lg, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: PourRadius.lg, style: .continuous)
                    .strokeBorder(PourColor.borderHairline, lineWidth: PourBorder.hairline)
            )
            .pourShadow(.sm)
    }

    /// The one focus treatment in the app: a 2px Amber ring, 2px offset.
    public func pourFocusRing(_ isFocused: Bool, radius: CGFloat = PourRadius.md) -> some View {
        self.overlay(
            RoundedRectangle(cornerRadius: radius, style: .continuous)
                .strokeBorder(PourColor.amber, lineWidth: isFocused ? PourBorder.focusRing : 0)
                .padding(-2)
                .opacity(isFocused ? 1 : 0)
        )
    }
}

/// Primary CTA: Amber fill, Espresso label — same in both appearances.
public struct PourPrimaryButtonStyle: ButtonStyle {
    public init() {}
    public func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(PourFont.headline(13))
            .foregroundStyle(PourColor.onAmber)
            .padding(.horizontal, PourSpace.md)
            .padding(.vertical, PourSpace.xs)
            .background(PourColor.amber.opacity(configuration.isPressed ? 0.8 : 1))
            .clipShape(RoundedRectangle(cornerRadius: PourRadius.md, style: .continuous))
            .animation(PourMotion.animation(.easeOut(duration: PourMotion.fast)), value: configuration.isPressed)
    }
}

/// Secondary: quiet blue outline / text.
public struct PourSecondaryButtonStyle: ButtonStyle {
    public init() {}
    public func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(PourFont.headline(13))
            .foregroundStyle(PourColor.blue500)
            .padding(.horizontal, PourSpace.md)
            .padding(.vertical, PourSpace.xs)
            .background(
                RoundedRectangle(cornerRadius: PourRadius.md, style: .continuous)
                    .strokeBorder(PourColor.blue600.opacity(configuration.isPressed ? 0.9 : 0.6), lineWidth: PourBorder.hairline)
            )
            .animation(PourMotion.animation(.easeOut(duration: PourMotion.fast)), value: configuration.isPressed)
    }
}

/// Destructive: quiet by default, reads as error only on hover/press.
public struct PourDestructiveButtonStyle: ButtonStyle {
    public init() {}
    public func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(PourFont.body(12))
            .foregroundStyle(PourColor.error.opacity(configuration.isPressed ? 0.7 : 1))
    }
}

extension ButtonStyle where Self == PourPrimaryButtonStyle {
    public static var pourPrimary: PourPrimaryButtonStyle { PourPrimaryButtonStyle() }
}
extension ButtonStyle where Self == PourSecondaryButtonStyle {
    public static var pourSecondary: PourSecondaryButtonStyle { PourSecondaryButtonStyle() }
}
extension ButtonStyle where Self == PourDestructiveButtonStyle {
    public static var pourDestructive: PourDestructiveButtonStyle { PourDestructiveButtonStyle() }
}
