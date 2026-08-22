import Foundation

/// A word or phrase Pour should know — biases the engine and, for multi-word terms,
/// canonicalizes glued/hyphenated variants back to the spelling you gave it.
public struct VocabularyEntry: Identifiable, Hashable, Codable, Sendable {
    public var term: String

    public init(term: String) {
        self.term = term
    }

    public var id: String { term.lowercased() }

    public var isMultiWord: Bool { term.split(separator: " ").count > 1 }
}

/// A correction pair — when you hear `from`, write `to`. Unlike a vocabulary entry,
/// `from` and `to` don't need to resemble each other at all.
public struct CorrectionEntry: Identifiable, Hashable, Codable, Sendable {
    public var from: String
    public var to: String

    public init(from: String, to: String) {
        self.from = from
        self.to = to
    }

    public var id: String { from.lowercased() }
}
