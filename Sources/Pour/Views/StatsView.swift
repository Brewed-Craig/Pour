import DesignKit
import HistoryKit
import SwiftUI

struct StatsView: View {
    @Environment(AppModel.self) private var model

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: PourSpace.xl) {
                Text("How much dictating has actually saved you — estimated, not measured.")
                    .font(PourFont.callout())
                    .foregroundStyle(PourColor.textMuted)

                VStack(spacing: PourSpace.md) {
                    statCard(title: "Last 7 Days", totals: model.usageStats.last7Days)
                    statCard(title: "Last 30 Days", totals: model.usageStats.last30Days)
                    statCard(title: "All Time", totals: model.usageStats.allTime)
                }

                Text("Time saved assumes an average typing speed of \(Int(assumedTypingWPM)) words per minute against the words you actually dictated. It's an estimate to give you a sense of scale, not a measurement of how long typing would have taken.")
                    .font(PourFont.callout())
                    .foregroundStyle(PourColor.textDim)
            }
            .padding(PourSpace.lg)
            .frame(maxWidth: 560, alignment: .leading)
        }
        .frame(maxWidth: .infinity)
        .navigationTitle("Stats")
    }

    private func statCard(title: String, totals: UsageStatsStore.Totals) -> some View {
        VStack(alignment: .leading, spacing: PourSpace.md) {
            Text(title.uppercased())
                .font(PourFont.caption())
                .foregroundStyle(PourColor.textDim)

            HStack(alignment: .lastTextBaseline, spacing: PourSpace.xxl) {
                statBlock(
                    value: totals.words.formatted(),
                    label: totals.words == 1 ? "word dictated" : "words dictated",
                    color: PourColor.text
                )
                statBlock(
                    value: totals.dictations.formatted(),
                    label: totals.dictations == 1 ? "dictation" : "dictations",
                    color: PourColor.text
                )
                statBlock(
                    value: formattedDuration(minutes: totals.estimatedMinutesSaved),
                    label: "estimated saved",
                    color: PourColor.success
                )
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .pourCard(padding: PourSpace.lg)
    }

    private func statBlock(value: String, label: String, color: Color) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(value)
                .font(PourFont.display(26))
                .foregroundStyle(color)
            Text(label)
                .font(PourFont.callout())
                .foregroundStyle(PourColor.textMuted)
        }
    }

    private func formattedDuration(minutes: Double) -> String {
        let totalMinutes = Int(minutes.rounded())
        guard totalMinutes >= 1 else { return "< 1m" }
        let hours = totalMinutes / 60
        let mins = totalMinutes % 60
        if hours == 0 { return "\(mins)m" }
        return "\(hours)h \(mins)m"
    }
}
