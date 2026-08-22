import Foundation

/// Flags dictionary entries that look like they'd fire on ordinary language, not just
/// the term you meant. Shown as a warning in the Dictionary UI — it doesn't block
/// saving, since you might genuinely mean it.
public enum RiskWarning {

    /// A deliberately conservative, project-authored list. These are function words
    /// and everyday terms whose global replacement is very likely to create false
    /// positives. Keeping the list small is preferable to importing a large corpus
    /// with unclear redistribution terms or warning on every valid dictionary word.
    private static let commonWords: Set<String> = Set("""
    a about after again against all also am an and any are as at back be because been before being between both but by
    can could day did do does doing down each even ever every few first for from get give go good got had has have having
    he her here hers herself him himself his how i if in into is it its itself just know last like little long look made
    make many may me more most much must my myself new no nor not now of off on once one only or other our ours ourselves
    out over own people really right said same say see she should since so some still such take than that the their theirs
    them themselves then there these they thing think this those through time to too two under up us use very want was way
    we well were what when where which while who whom why will with work would year you your yours yourself yourselves
    """.split(whereSeparator: { $0.isWhitespace }).map(String.init))

    /// `phrase` is either a vocabulary term or a correction's `from` side.
    public static func check(_ phrase: String) -> String? {
        let trimmed = phrase.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else { return nil }

        let words = trimmed.split(separator: " ")
        guard words.count == 1 else { return nil } // multi-word phrases are self-discriminating

        let word = trimmed.lowercased()
        if commonWords.contains(word) {
            return "\u{201C}\(trimmed)\u{201D} is a common English word — Pour will change it everywhere it's said, including normal use of the word."
        }
        if word.count <= 2 {
            return "\u{201C}\(trimmed)\u{201D} is very short and likely to match inside other words or transcripts."
        }
        return nil
    }
}
