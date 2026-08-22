import Foundation
import Observation

/// Owns `dictionary.txt`: loads it, saves it, watches it for edits made outside the
/// app, and answers the two questions the rest of Pour needs — "what should I bias
/// toward?" and "what should I correct after transcribing?"
@MainActor
@Observable
public final class DictionaryStore {

    public private(set) var vocabulary: [VocabularyEntry] = []
    public private(set) var corrections: [CorrectionEntry] = []
    public private(set) var loadError: String?

    private let fileURL: URL
    private var watcher: DispatchSourceFileSystemObject?
    private var lastWrittenContent: String?

    public init(fileURL: URL? = nil) {
        if let fileURL {
            self.fileURL = fileURL
        } else {
            let support = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
                .appendingPathComponent("Pour", isDirectory: true)
            try? FileManager.default.createDirectory(at: support, withIntermediateDirectories: true)
            self.fileURL = support.appendingPathComponent("dictionary.txt")
        }
        load()
        startWatching()
    }


    // MARK: - Load / save

    public func load() {
        guard let text = try? String(contentsOf: fileURL, encoding: .utf8) else {
            vocabulary = []
            corrections = []
            save() // seed the file so it exists on disk from first launch
            return
        }
        let parsed = DictionaryFile.parse(text)
        vocabulary = parsed.vocabulary
        corrections = parsed.corrections
        loadError = nil
    }

    private func save() {
        let content = DictionaryFile.serialize(vocabulary: vocabulary, corrections: corrections)
        lastWrittenContent = content
        do {
            try content.write(to: fileURL, atomically: true, encoding: .utf8)
        } catch {
            loadError = "Couldn't save the dictionary: \(error.localizedDescription)"
        }
    }

    // MARK: - Vocabulary CRUD

    public func addVocabulary(_ term: String) {
        let trimmed = term.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else { return }
        vocabulary.removeAll { $0.id == trimmed.lowercased() }
        vocabulary.append(VocabularyEntry(term: trimmed))
        save()
    }

    public func removeVocabulary(_ entry: VocabularyEntry) {
        vocabulary.removeAll { $0.id == entry.id }
        save()
    }

    // MARK: - Corrections CRUD

    public func addCorrection(from: String, to: String) {
        let from = from.trimmingCharacters(in: .whitespaces)
        let to = to.trimmingCharacters(in: .whitespaces)
        guard !from.isEmpty, !to.isEmpty else { return }
        corrections.removeAll { $0.id == from.lowercased() }
        corrections.append(CorrectionEntry(from: from, to: to))
        save()
    }

    public func removeCorrection(_ entry: CorrectionEntry) {
        corrections.removeAll { $0.id == entry.id }
        save()
    }

    // MARK: - Search

    public func search(_ query: String) -> (vocabulary: [VocabularyEntry], corrections: [CorrectionEntry]) {
        let q = query.trimmingCharacters(in: .whitespaces).lowercased()
        guard !q.isEmpty else { return (vocabulary, corrections) }
        return (
            vocabulary.filter { $0.term.lowercased().contains(q) },
            corrections.filter { $0.from.lowercased().contains(q) || $0.to.lowercased().contains(q) }
        )
    }

    // MARK: - Engine hooks

    /// Short, deliberately: long context makes the model drift on quiet audio.
    public func biasVocabulary(limit: Int = 40) -> [String] {
        Array(vocabulary.map(\.term).prefix(limit))
    }

    public func applyCorrections(to text: String) -> (result: String, hits: [CorrectionHit]) {
        CorrectionEngine.apply(to: text, vocabulary: vocabulary, corrections: corrections)
    }

    // MARK: - External-edit watching

    private func startWatching() {
        let fd = open(fileURL.path, O_EVTONLY)
        guard fd >= 0 else { return }
        let source = DispatchSource.makeFileSystemObjectSource(fileDescriptor: fd, eventMask: [.write, .rename, .delete], queue: .main)
        source.setEventHandler { [weak self] in
            self?.handleExternalChange()
        }
        source.setCancelHandler { close(fd) }
        source.resume()
        watcher = source
    }

    private func handleExternalChange() {
        guard let text = try? String(contentsOf: fileURL, encoding: .utf8) else { return }
        // Skip the reload we triggered ourselves by calling save().
        guard text != lastWrittenContent else { return }
        let parsed = DictionaryFile.parse(text)
        vocabulary = parsed.vocabulary
        corrections = parsed.corrections
    }
}
