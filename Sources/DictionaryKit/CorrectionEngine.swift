import Foundation

/// Where a correction came from — shown in transcription history so you can tell
/// whether the dictionary is doing anything.
public enum CorrectionSource: Hashable, Sendable {
    /// A vocabulary term the engine glued together or hyphenated, put back to its
    /// canonical spelling.
    case vocabulary(term: String)
    /// An explicit correction pair.
    case pair(from: String, to: String)
}

/// One fired correction: what matched, what it became, and why.
public struct CorrectionHit: Hashable, Sendable {
    public let matchedText: String
    public let replacement: String
    public let source: CorrectionSource
}

/// The guaranteed path. Biasing (`AnalysisContext`) is a nudge the transcriber may or
/// may not take; this runs after every utterance and always fires on an exact match.
///
/// Rules, longest canonical phrase first:
///  - Whole-word, case-insensitive.
///  - Multi-word patterns tolerate the model gluing words together or hyphenating
///    them: "Claude Code" also catches "ClaudeCode" and "Cloud-Code"-style spacing.
///  - Word boundaries are required on both ends, so "Claude Code" never touches
///    "Cloudflare" or the ordinary word "cloud" — those don't share a boundary with
///    the full multi-word pattern.
public enum CorrectionEngine {

    private struct Rule {
        let regex: NSRegularExpression
        let replacement: String
        let source: CorrectionSource
        let priority: Int // canonical phrase length in characters — longest wins ties
    }

    public static func apply(
        to text: String,
        vocabulary: [VocabularyEntry],
        corrections: [CorrectionEntry]
    ) -> (result: String, hits: [CorrectionHit]) {
        guard !text.isEmpty else { return (text, []) }

        var rules: [Rule] = []

        // Vocabulary: only multi-word terms need a glue-correction rule. A single
        // word is just a bias hint — there's nothing to reassemble.
        for entry in vocabulary where entry.isMultiWord {
            guard let regex = gluePattern(for: entry.term) else { continue }
            rules.append(Rule(
                regex: regex,
                replacement: entry.term,
                source: .vocabulary(term: entry.term),
                priority: entry.term.count
            ))
        }

        for entry in corrections {
            guard let regex = gluePattern(for: entry.from) else { continue }
            rules.append(Rule(
                regex: regex,
                replacement: entry.to,
                source: .pair(from: entry.from, to: entry.to),
                priority: entry.from.count
            ))
        }

        guard !rules.isEmpty else { return (text, []) }

        let ns = text as NSString
        let fullRange = NSRange(location: 0, length: ns.length)

        struct Candidate {
            let range: NSRange
            let rule: Rule
        }

        var candidates: [Candidate] = []
        for rule in rules {
            rule.regex.enumerateMatches(in: text, range: fullRange) { match, _, _ in
                guard let match else { return }
                candidates.append(Candidate(range: match.range, rule: rule))
            }
        }

        // Longest canonical phrase wins on overlap; ties break by earliest position.
        candidates.sort { a, b in
            if a.rule.priority != b.rule.priority { return a.rule.priority > b.rule.priority }
            return a.range.location < b.range.location
        }

        var accepted: [Candidate] = []
        for candidate in candidates {
            let overlaps = accepted.contains { NSIntersectionRange($0.range, candidate.range).length > 0 }
            guard !overlaps else { continue }
            accepted.append(candidate)
        }
        accepted.sort { $0.range.location < $1.range.location }

        guard !accepted.isEmpty else { return (text, []) }

        var result = ""
        var hits: [CorrectionHit] = []
        var cursor = 0
        for candidate in accepted {
            let range = candidate.range
            guard range.location >= cursor else { continue }
            result += ns.substring(with: NSRange(location: cursor, length: range.location - cursor))
            let matched = ns.substring(with: range)
            result += candidate.rule.replacement
            hits.append(CorrectionHit(matchedText: matched, replacement: candidate.rule.replacement, source: candidate.rule.source))
            cursor = range.location + range.length
        }
        if cursor < ns.length {
            result += ns.substring(with: NSRange(location: cursor, length: ns.length - cursor))
        }

        return (result, hits)
    }

    /// Builds `\bword1[\s-]*word2[\s-]*…wordN\b`, case-insensitive — matches spaced,
    /// hyphenated, and fully glued spellings of a phrase, and nothing shorter or
    /// longer than the whole phrase.
    ///
    /// Leading/trailing punctuation on each word is stripped before matching — a
    /// transcript is spoken text, not typed text, so a literal "?" or "." you happened
    /// to type into an entry should never be required for it to fire.
    private static func gluePattern(for phrase: String) -> NSRegularExpression? {
        let words = phrase.split(separator: " ")
            .map { $0.trimmingCharacters(in: .punctuationCharacters) }
            .filter { !$0.isEmpty }
        guard !words.isEmpty else { return nil }
        let escaped = words.map { NSRegularExpression.escapedPattern(for: $0) }
        let pattern = "\\b" + escaped.joined(separator: "[\\s-]*") + "\\b"
        return try? NSRegularExpression(pattern: pattern, options: [.caseInsensitive])
    }
}
