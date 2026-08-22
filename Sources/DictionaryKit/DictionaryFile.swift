import Foundation

/// The plain-text `dictionary.txt` format — hand-editable, diffable, no hidden state.
///
/// ```
/// [vocabulary]
/// Anthropic
/// Claude Code
///
/// [corrections]
/// cloud code => Claude Code
/// ```
public enum DictionaryFile {

    public static let header = """
    # Pour Dictionary
    # Edit this file directly, or use Pour's Dictionary tab — both read and write it.
    # Lines starting with # are comments.

    """

    public static func parse(_ text: String) -> (vocabulary: [VocabularyEntry], corrections: [CorrectionEntry]) {
        enum Section { case none, vocabulary, corrections }
        var section = Section.none
        var vocabulary: [VocabularyEntry] = []
        var corrections: [CorrectionEntry] = []
        var seenVocab = Set<String>()
        var seenCorrections = Set<String>()

        for rawLine in text.split(separator: "\n", omittingEmptySubsequences: false) {
            let line = rawLine.trimmingCharacters(in: .whitespaces)
            if line.isEmpty || line.hasPrefix("#") { continue }

            if line.lowercased() == "[vocabulary]" { section = .vocabulary; continue }
            if line.lowercased() == "[corrections]" { section = .corrections; continue }

            switch section {
            case .none:
                continue
            case .vocabulary:
                let key = line.lowercased()
                guard !key.isEmpty, !seenVocab.contains(key) else { continue }
                seenVocab.insert(key)
                vocabulary.append(VocabularyEntry(term: line))
            case .corrections:
                guard let range = line.range(of: "=>") else { continue }
                let from = line[line.startIndex..<range.lowerBound].trimmingCharacters(in: .whitespaces)
                let to = line[range.upperBound...].trimmingCharacters(in: .whitespaces)
                guard !from.isEmpty, !to.isEmpty else { continue }
                let key = from.lowercased()
                guard !seenCorrections.contains(key) else { continue }
                seenCorrections.insert(key)
                corrections.append(CorrectionEntry(from: from, to: to))
            }
        }

        return (vocabulary, corrections)
    }

    public static func serialize(vocabulary: [VocabularyEntry], corrections: [CorrectionEntry]) -> String {
        var out = header
        out += "\n[vocabulary]\n"
        for entry in vocabulary.sorted(by: { $0.term.localizedCaseInsensitiveCompare($1.term) == .orderedAscending }) {
            out += entry.term + "\n"
        }
        out += "\n[corrections]\n"
        for entry in corrections.sorted(by: { $0.from.localizedCaseInsensitiveCompare($1.from) == .orderedAscending }) {
            out += "\(entry.from) => \(entry.to)\n"
        }
        return out
    }
}
