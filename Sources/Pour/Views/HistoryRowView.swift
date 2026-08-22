import AppKit
import DesignKit
import HistoryKit
import SwiftUI

struct HistoryRowView: View {
    let entry: HistoryEntry
    var onDelete: () -> Void
    @State private var showCorrections = false
    @State private var didCopy = false

    private static let timeFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateStyle = .none
        f.timeStyle = .medium
        return f
    }()

    var body: some View {
        VStack(alignment: .leading, spacing: PourSpace.xs) {
            HStack(alignment: .top, spacing: PourSpace.sm) {
                Text(entry.text)
                    .font(PourFont.body(13))
                    .foregroundStyle(PourColor.text)
                    .textSelection(.enabled)
                    .frame(maxWidth: .infinity, alignment: .leading)

                HStack(spacing: PourSpace.sm) {
                    Button {
                        copy()
                    } label: {
                        Image(systemName: didCopy ? "checkmark" : "doc.on.doc")
                            .foregroundStyle(didCopy ? PourColor.success : PourColor.textDim)
                    }
                    .buttonStyle(.plain)
                    .help("Copy")

                    Button {
                        onDelete()
                    } label: {
                        Image(systemName: "trash")
                    }
                    .buttonStyle(.pourDestructive)
                    .help("Delete")
                }
            }

            HStack(spacing: PourSpace.xs) {
                Text(Self.timeFormatter.string(from: entry.date))
                if let appName = entry.appName {
                    Text("\u{2192} \(appName)")
                }
                Text("\(entry.elapsedMS)ms")
                Text(entry.strategy)

                if !entry.corrections.isEmpty {
                    Button {
                        withAnimation(PourMotion.animation(.easeOut(duration: PourMotion.fast))) {
                            showCorrections.toggle()
                        }
                    } label: {
                        HStack(spacing: 3) {
                            Image(systemName: "wand.and.sparkles")
                            Text("\(entry.corrections.count) corrected")
                        }
                    }
                    .buttonStyle(.plain)
                    .foregroundStyle(PourColor.success)
                }
            }
            .font(PourFont.mono(10.5))
            .foregroundStyle(PourColor.textDim)

            if showCorrections {
                VStack(alignment: .leading, spacing: PourSpace.xxs) {
                    ForEach(entry.corrections, id: \.matchedText) { correction in
                        HStack(spacing: PourSpace.xs) {
                            Text(correction.matchedText)
                                .strikethrough()
                                .foregroundStyle(PourColor.textDim)
                            Image(systemName: "arrow.right")
                                .foregroundStyle(PourColor.textDim)
                            Text(correction.replacement)
                                .foregroundStyle(PourColor.success)
                            Spacer()
                            Text(correction.label)
                                .foregroundStyle(PourColor.textDim)
                        }
                        .font(PourFont.mono(11))
                    }
                }
                .padding(PourSpace.sm)
                .background(PourColor.surfacePanel2)
                .clipShape(RoundedRectangle(cornerRadius: PourRadius.sm, style: .continuous))
            }
        }
        .padding(PourSpace.md)
        .background(PourColor.surfacePanel)
        .clipShape(RoundedRectangle(cornerRadius: PourRadius.lg, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: PourRadius.lg, style: .continuous)
                .strokeBorder(PourColor.borderHairline, lineWidth: PourBorder.hairline)
        )
    }

    private func copy() {
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(entry.text, forType: .string)
        didCopy = true
        Task {
            try? await Task.sleep(for: .seconds(1.2))
            didCopy = false
        }
    }
}
