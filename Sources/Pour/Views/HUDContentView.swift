import DesignKit
import SwiftUI

/// The floating HUD's content: a live waveform driven by `model.level`.
struct HUDContentView: View {
    let model: AppModel

    var body: some View {
        VStack(spacing: PourSpace.xs) {
            Waveform(model: model)
                .frame(height: 42)

            Text("Listening\u{2026}")
                .font(PourFont.caption())
                .foregroundStyle(PourColor.textMuted)
        }
        .padding(.horizontal, PourSpace.lg)
        .padding(.vertical, PourSpace.md)
        .background(PourColor.surfacePanel.opacity(0.97))
        .clipShape(RoundedRectangle(cornerRadius: PourRadius.lg, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: PourRadius.lg, style: .continuous)
                .strokeBorder(PourColor.borderStrong, lineWidth: PourBorder.hairline)
        )
        .pourShadow(.glowAmber)
    }
}

/// Level-reactive bars, each with a fixed phase offset so the group ripples rather
/// than pumping in unison.
///
/// Takes `model` itself, not a `level: Float` snapshot — this view is hosted in a
/// bare `NSPanel` outside any normal SwiftUI window scene, where there's no guarantee
/// `HUDContentView.body` re-invokes on every Observation-tracked change to a value
/// merely passed down into a child view's `let`. Reading `model.level` fresh inside
/// the `TimelineView` closure — which ticks on its own schedule regardless of
/// Observation — guarantees every frame reflects the live level instead of rippling
/// around whatever value happened to be captured at the first render.
private struct Waveform: View {
    let model: AppModel

    private static let barCount = 20
    private static let phases: [Double] = (0..<barCount).map { index in
        // Irrational multiplier keeps the offsets from lining up into a visible period.
        (Double(index) * 0.618).truncatingRemainder(dividingBy: 1)
    }

    var body: some View {
        TimelineView(.animation(minimumInterval: 1.0 / 30.0, paused: false)) { timeline in
            let t = timeline.date.timeIntervalSinceReferenceDate
            let level = model.level
            HStack(alignment: .center, spacing: 3) {
                ForEach(0..<Self.barCount, id: \.self) { index in
                    RoundedRectangle(cornerRadius: 2, style: .continuous)
                        .fill(PourColor.amber)
                        .frame(width: 4, height: height(for: index, at: t, level: level))
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }

    private func height(for index: Int, at time: TimeInterval, level: Float) -> CGFloat {
        let floorHeight: CGFloat = 3
        let phase = Self.phases[index]
        let wave = sin(time * 6.0 + phase * .pi * 2)
        let amplitude = CGFloat(max(0.05, level))
        // The ripple rides on top of the level so bars still breathe during quiet
        // passages instead of flatlining between buffers.
        let scaled = amplitude * (0.55 + 0.45 * CGFloat(wave))
        return floorHeight + max(0, scaled) * 39
    }
}
