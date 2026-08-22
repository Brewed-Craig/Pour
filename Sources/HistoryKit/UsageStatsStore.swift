import Foundation
import Observation
import PrivacyKit

/// One day's tally. Kept indefinitely (unlike `HistoryEntry`, which is pruned after
/// five days) — a "this month" stat that quietly resets itself because the
/// transcripts it was derived from expired would be worse than useless.
public struct DailyUsage: Codable, Sendable {
    public let day: Date // start-of-day, local calendar
    public var wordCount: Int
    public var dictationCount: Int
}

/// Assumed average typing speed, for the "time saved" estimate. There's no way to
/// measure the counterfactual (how long typing this would have actually taken), so
/// this is deliberately a round, commonly-cited number — the UI should always present
/// the result as an estimate, not a measurement. Top-level (not a member of
/// `UsageStatsStore`) so `Totals.estimatedMinutesSaved` can read it without needing
/// `@MainActor` isolation itself.
public let assumedTypingWPM: Double = 40

/// Rolling usage totals — words dictated, dictation count, and an estimated time
/// saved versus typing. Independent of `HistoryStore`'s retention window and
/// independent of whether History is even enabled, since these are just counts, not
/// the transcript text itself.
@MainActor
@Observable
public final class UsageStatsStore {

    public private(set) var daily: [DailyUsage] = []

    private let fileURL: URL

    public init(fileURL: URL? = nil) {
        if let fileURL {
            self.fileURL = fileURL
        } else {
            let support = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
                .appendingPathComponent("Pour", isDirectory: true)
            try? SecureLocalStorage.prepareDirectory(support)
            self.fileURL = support.appendingPathComponent("usage-stats.json")
        }
        try? SecureLocalStorage.protectFile(self.fileURL)
        load()
    }

    /// Called once per delivered dictation, regardless of whether History is enabled.
    public func record(wordCount: Int) {
        guard wordCount > 0 else { return }
        let today = Calendar.current.startOfDay(for: Date())
        if let index = daily.firstIndex(where: { $0.day == today }) {
            daily[index].wordCount += wordCount
            daily[index].dictationCount += 1
        } else {
            daily.append(DailyUsage(day: today, wordCount: wordCount, dictationCount: 1))
        }
        save()
    }

    public struct Totals {
        public let words: Int
        public let dictations: Int

        /// Minutes an average typist would need for this many words, at
        /// `assumedTypingWPM` — the headline "time saved" figure.
        public var estimatedMinutesSaved: Double {
            Double(words) / assumedTypingWPM
        }
    }

    public func totals(lastDays: Int?) -> Totals {
        let relevant: [DailyUsage]
        if let lastDays {
            let cutoff = Calendar.current.date(byAdding: .day, value: -(lastDays - 1), to: Calendar.current.startOfDay(for: Date()))!
            relevant = daily.filter { $0.day >= cutoff }
        } else {
            relevant = daily
        }
        return Totals(
            words: relevant.reduce(0) { $0 + $1.wordCount },
            dictations: relevant.reduce(0) { $0 + $1.dictationCount }
        )
    }

    public var last7Days: Totals { totals(lastDays: 7) }
    public var last30Days: Totals { totals(lastDays: 30) }
    public var allTime: Totals { totals(lastDays: nil) }

    private func load() {
        guard let data = try? Data(contentsOf: fileURL),
              let decoded = try? JSONDecoder().decode([DailyUsage].self, from: data)
        else { return }
        daily = decoded
    }

    private func save() {
        guard let data = try? JSONEncoder().encode(daily) else { return }
        do {
            try data.write(to: fileURL, options: .atomic)
            try SecureLocalStorage.protectFile(fileURL)
        } catch {
            // Best-effort, same as HistoryStore — failed persistence must never
            // interrupt dictation.
        }
    }
}
