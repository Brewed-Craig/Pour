import DictionaryKit
import Foundation
import Observation

/// One fired correction, flattened to a persistable, display-ready shape — decoupled
/// from `CorrectionSource` so the on-disk format doesn't move every time that enum does.
struct HistoryCorrection: Codable, Hashable, Sendable {
    let matchedText: String
    let replacement: String
    let label: String // "Dictionary: cloud code → Claude Code" / "Vocabulary: Claude Code"

    init(_ hit: CorrectionHit) {
        matchedText = hit.matchedText
        replacement = hit.replacement
        switch hit.source {
        case .vocabulary(let term):
            label = "Vocabulary: \(term)"
        case .pair(let from, let to):
            label = "Dictionary: \(from) \u{2192} \(to)"
        }
    }
}

struct HistoryEntry: Identifiable, Codable, Sendable {
    let id: UUID
    let date: Date
    let text: String
    let appName: String?
    let strategy: String
    let elapsedMS: Int
    let corrections: [HistoryCorrection]

    init(text: String, appName: String?, strategy: String, elapsedMS: Int, corrections: [HistoryCorrection]) {
        id = UUID()
        date = Date()
        self.text = text
        self.appName = appName
        self.strategy = strategy
        self.elapsedMS = elapsedMS
        self.corrections = corrections
    }
}

/// Past transcriptions, most recent first. Persisted as a single JSON file, pruned to
/// a rolling 5-day window — Pour's history is what you dictated recently, not an
/// indefinite archive.
@MainActor
@Observable
final class HistoryStore {

    private(set) var entries: [HistoryEntry] = []

    private let fileURL: URL
    private static let retention: TimeInterval = 5 * 24 * 60 * 60

    init(fileURL: URL? = nil) {
        if let fileURL {
            self.fileURL = fileURL
        } else {
            let support = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
                .appendingPathComponent("Pour", isDirectory: true)
            try? FileManager.default.createDirectory(at: support, withIntermediateDirectories: true)
            self.fileURL = support.appendingPathComponent("history.json")
        }
        load()
        prune()
    }

    @discardableResult
    func record(text: String, appName: String?, strategy: String, elapsedMS: Int, hits: [CorrectionHit]) -> HistoryEntry {
        let entry = HistoryEntry(
            text: text,
            appName: appName,
            strategy: strategy,
            elapsedMS: elapsedMS,
            corrections: hits.map(HistoryCorrection.init)
        )
        entries.insert(entry, at: 0)
        prune()
        save()
        return entry
    }

    private func prune() {
        let cutoff = Date().addingTimeInterval(-Self.retention)
        entries.removeAll { $0.date < cutoff }
    }

    func search(_ query: String) -> [HistoryEntry] {
        let q = query.trimmingCharacters(in: .whitespaces).lowercased()
        guard !q.isEmpty else { return entries }
        return entries.filter { $0.text.lowercased().contains(q) || ($0.appName?.lowercased().contains(q) ?? false) }
    }

    private func load() {
        guard let data = try? Data(contentsOf: fileURL),
              let decoded = try? JSONDecoder().decode([HistoryEntry].self, from: data)
        else { return }
        entries = decoded
    }

    private func save() {
        guard let data = try? JSONEncoder().encode(entries) else { return }
        try? data.write(to: fileURL, options: .atomic)
    }
}
