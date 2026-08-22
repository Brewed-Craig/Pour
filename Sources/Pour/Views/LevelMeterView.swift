import DesignKit
import SwiftUI

/// The live level meter — an amber fill that tracks raw mic RMS while recording, flat
/// and quiet otherwise.
struct LevelMeterView: View {
    let level: Float
    let isActive: Bool

    var body: some View {
        GeometryReader { geo in
            ZStack(alignment: .leading) {
                RoundedRectangle(cornerRadius: PourRadius.sm, style: .continuous)
                    .fill(PourColor.surfacePanel2)
                RoundedRectangle(cornerRadius: PourRadius.sm, style: .continuous)
                    .fill(
                        LinearGradient(
                            colors: [PourColor.amber.opacity(0.75), PourColor.amber],
                            startPoint: .leading, endPoint: .trailing
                        )
                    )
                    .frame(width: isActive ? max(6, geo.size.width * CGFloat(level)) : 0)
                    .animation(PourMotion.animation(.easeOut(duration: PourMotion.fast)), value: level)
            }
        }
        .frame(height: 8)
        .overlay(
            RoundedRectangle(cornerRadius: PourRadius.sm, style: .continuous)
                .strokeBorder(PourColor.borderHairline, lineWidth: PourBorder.hairline)
        )
        .pourShadow(isActive ? .glowAmber : .sm)
        .animation(PourMotion.animation(.easeOut(duration: PourMotion.base)), value: isActive)
    }
}
