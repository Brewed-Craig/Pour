import AppKit
import SwiftUI

/// 4pt spacing grid. Reach for the name, not the raw number.
public enum PourSpace {
    public static let xxs: CGFloat = 4
    public static let xs: CGFloat = 8
    public static let sm: CGFloat = 12
    public static let md: CGFloat = 16
    public static let lg: CGFloat = 20
    public static let xl: CGFloat = 24
    public static let xxl: CGFloat = 32
    public static let xxxl: CGFloat = 48
}

/// Corner radius, scaled down from the brand's web system (18/26px) for a compact
/// native window.
public enum PourRadius {
    public static let sm: CGFloat = 6   // chips, pills, inline tags
    public static let md: CGFloat = 9   // buttons, text fields, list rows
    public static let lg: CGFloat = 14  // cards, the level meter, dictionary rows
    public static let xl: CGFloat = 20  // window-level panels, sheets
}

public enum PourBorder {
    public static let hairline: CGFloat = 1
    public static let focusRing: CGFloat = 2
}

/// Durations and easing. Everything collapses to the shortest reasonable duration
/// under Reduce Motion — state still changes, it just doesn't travel to get there.
public enum PourMotion {
    public static let instant: Double = 0.08
    public static let fast: Double = 0.15
    public static let base: Double = 0.22
    public static let slow: Double = 0.32

    public static let standard = Animation.timingCurve(0.2, 0.8, 0.2, 1, duration: base)
    public static let emphasized = Animation.timingCurve(0.34, 1.56, 0.64, 1, duration: slow)

    public static var reduceMotionEnabled: Bool {
        NSWorkspace.shared.accessibilityDisplayShouldReduceMotion
    }

    /// Use this instead of a raw `Animation` anywhere state change needs to respect
    /// the system Reduce Motion setting.
    public static func animation(_ base: Animation) -> Animation? {
        reduceMotionEnabled ? nil : base
    }
}
