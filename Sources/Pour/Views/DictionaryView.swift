import DesignKit
import DictionaryKit
import SwiftUI

struct DictionaryView: View {
    @Environment(AppModel.self) private var model
    @State private var query = ""
    @State private var newTerm = ""
    @State private var newFrom = ""
    @State private var newTo = ""

    private var newTermWarning: String? { RiskWarning.check(newTerm) }
    private var newFromWarning: String? { RiskWarning.check(newFrom) }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: PourSpace.xxl) {
                vocabularySection
                correctionsSection
            }
            .padding(PourSpace.lg)
        }
        .navigationTitle("Dictionary")
        .searchable(text: $query, placement: .toolbar, prompt: "Search dictionary")
    }

    // MARK: - Vocabulary

    private var vocabularySection: some View {
        let results = model.dictionary.search(query).vocabulary

        return VStack(alignment: .leading, spacing: PourSpace.sm) {
            sectionHeader(
                title: "Vocabulary",
                subtitle: "Words and phrases Pour should know \u{2014} names, jargon, product names, the people you work with."
            )

            VStack(alignment: .leading, spacing: PourSpace.xs) {
                HStack(spacing: PourSpace.xs) {
                    TextField("Add a word or phrase\u{2026}", text: $newTerm)
                        .textFieldStyle(.plain)
                        .padding(.horizontal, PourSpace.sm)
                        .padding(.vertical, PourSpace.xs)
                        .background(PourColor.surfacePanel2)
                        .clipShape(RoundedRectangle(cornerRadius: PourRadius.md, style: .continuous))
                        .onSubmit(addVocabulary)

                    Button("Add", action: addVocabulary)
                        .buttonStyle(.pourSecondary)
                        .disabled(newTerm.trimmingCharacters(in: .whitespaces).isEmpty)
                }
                if let warning = newTermWarning {
                    warningLabel(warning)
                }
            }

            if results.isEmpty {
                Text(query.isEmpty ? "No vocabulary yet." : "No matches.")
                    .font(PourFont.callout())
                    .foregroundStyle(PourColor.textDim)
                    .padding(.vertical, PourSpace.sm)
            } else {
                VStack(spacing: PourSpace.xxs) {
                    ForEach(results) { entry in
                        entryRow(primary: entry.term, secondary: nil, warning: RiskWarning.check(entry.term)) {
                            model.dictionary.removeVocabulary(entry)
                        }
                    }
                }
            }
        }
    }

    // MARK: - Corrections

    private var correctionsSection: some View {
        let results = model.dictionary.search(query).corrections

        return VStack(alignment: .leading, spacing: PourSpace.sm) {
            sectionHeader(
                title: "Corrections",
                subtitle: "When you hear X, write Y \u{2014} for words the model consistently mishears."
            )

            VStack(alignment: .leading, spacing: PourSpace.xs) {
                HStack(spacing: PourSpace.xs) {
                    TextField("Heard as\u{2026}", text: $newFrom)
                        .textFieldStyle(.plain)
                        .padding(.horizontal, PourSpace.sm)
                        .padding(.vertical, PourSpace.xs)
                        .background(PourColor.surfacePanel2)
                        .clipShape(RoundedRectangle(cornerRadius: PourRadius.md, style: .continuous))

                    Image(systemName: "arrow.right")
                        .foregroundStyle(PourColor.textDim)

                    TextField("Write instead\u{2026}", text: $newTo)
                        .textFieldStyle(.plain)
                        .padding(.horizontal, PourSpace.sm)
                        .padding(.vertical, PourSpace.xs)
                        .background(PourColor.surfacePanel2)
                        .clipShape(RoundedRectangle(cornerRadius: PourRadius.md, style: .continuous))
                        .onSubmit(addCorrection)

                    Button("Add", action: addCorrection)
                        .buttonStyle(.pourSecondary)
                        .disabled(newFrom.trimmingCharacters(in: .whitespaces).isEmpty || newTo.trimmingCharacters(in: .whitespaces).isEmpty)
                }
                if let warning = newFromWarning {
                    warningLabel(warning)
                }
            }

            if results.isEmpty {
                Text(query.isEmpty ? "No corrections yet." : "No matches.")
                    .font(PourFont.callout())
                    .foregroundStyle(PourColor.textDim)
                    .padding(.vertical, PourSpace.sm)
            } else {
                VStack(spacing: PourSpace.xxs) {
                    ForEach(results) { entry in
                        entryRow(primary: entry.from, secondary: entry.to, warning: RiskWarning.check(entry.from)) {
                            model.dictionary.removeCorrection(entry)
                        }
                    }
                }
            }
        }
    }

    // MARK: - Shared pieces

    private func sectionHeader(title: String, subtitle: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(title).font(PourFont.title(17)).foregroundStyle(PourColor.text)
            Text(subtitle).font(PourFont.callout()).foregroundStyle(PourColor.textMuted)
        }
    }

    private func warningLabel(_ text: String) -> some View {
        HStack(alignment: .top, spacing: PourSpace.xxs) {
            Image(systemName: "exclamationmark.triangle.fill")
            Text(text)
        }
        .font(PourFont.callout())
        .foregroundStyle(PourColor.warning)
    }

    private func entryRow(primary: String, secondary: String?, warning: String?, onDelete: @escaping () -> Void) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: PourSpace.sm) {
                if let secondary {
                    Text(primary).font(PourFont.mono(12.5)).foregroundStyle(PourColor.textMuted)
                    Image(systemName: "arrow.right").font(.system(size: 10)).foregroundStyle(PourColor.textDim)
                    Text(secondary).font(PourFont.headline(13)).foregroundStyle(PourColor.text)
                } else {
                    Text(primary).font(PourFont.headline(13)).foregroundStyle(PourColor.text)
                }

                Spacer()

                Button(action: onDelete) {
                    Image(systemName: "trash")
                }
                .buttonStyle(.pourDestructive)
                .help("Delete")
            }
            if let warning {
                warningLabel(warning)
            }
        }
        .padding(.horizontal, PourSpace.md)
        .padding(.vertical, PourSpace.sm)
        .background(PourColor.surfacePanel)
        .clipShape(RoundedRectangle(cornerRadius: PourRadius.md, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: PourRadius.md, style: .continuous)
                .strokeBorder(PourColor.borderHairline, lineWidth: PourBorder.hairline)
        )
    }

    private func addVocabulary() {
        let term = newTerm.trimmingCharacters(in: .whitespaces)
        guard !term.isEmpty else { return }
        model.dictionary.addVocabulary(term)
        newTerm = ""
    }

    private func addCorrection() {
        let from = newFrom.trimmingCharacters(in: .whitespaces)
        let to = newTo.trimmingCharacters(in: .whitespaces)
        guard !from.isEmpty, !to.isEmpty else { return }
        model.dictionary.addCorrection(from: from, to: to)
        newFrom = ""
        newTo = ""
    }
}
