import SwiftUI

/// Type scale from the approved token sheet. `Font.custom` falls back to the system
/// font automatically if a PostScript name isn't registered, so this is safe even if
/// `FontRegistrar` hasn't run yet.
public enum PourFont {

    /// Fraunces SemiBold — the one expressive moment. Used sparingly: empty states,
    /// the odd section opener. Never body text.
    public static func display(_ size: CGFloat = 28) -> Font {
        .custom("Fraunces-SemiBold", size: size)
    }

    /// Inter SemiBold 20 — window and section titles.
    public static func title(_ size: CGFloat = 20) -> Font {
        .custom("Inter-Regular_SemiBold", size: size)
    }

    /// Inter SemiBold 15 — list item primary text, card titles.
    public static func headline(_ size: CGFloat = 15) -> Font {
        .custom("Inter-Regular_SemiBold", size: size)
    }

    /// Inter Regular 13 — default UI text.
    public static func body(_ size: CGFloat = 13) -> Font {
        .custom("Inter-Regular", size: size)
    }

    /// Inter Regular 12, muted — secondary text, hints.
    public static func callout(_ size: CGFloat = 12) -> Font {
        .custom("Inter-Regular", size: size)
    }

    /// Inter Medium 11, uppercase — metadata labels, eyebrows.
    public static func caption(_ size: CGFloat = 11) -> Font {
        .custom("Inter-Regular_Medium", size: size)
    }

    /// JetBrains Mono Regular — timestamps, elapsed-ms, model names.
    public static func mono(_ size: CGFloat = 11.5) -> Font {
        .custom("JetBrainsMono-Regular", size: size)
    }

    /// JetBrains Mono Medium — correction diffs, emphasized technical detail.
    public static func monoMedium(_ size: CGFloat = 11.5) -> Font {
        .custom("JetBrainsMonoRoman-Medium", size: size)
    }
}
