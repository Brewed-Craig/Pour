import Foundation
import HistoryKit

func require(_ condition: @autoclosure () -> Bool, _ message: String) {
    guard condition() else {
        FileHandle.standardError.write(Data("FAIL: \(message)\n".utf8))
        exit(1)
    }
}

struct LegacyDailyUsage: Codable {
    let day: Date
    let wordCount: Int
    let dictationCount: Int
}

@MainActor
func checkLegacyMigration(in root: URL) throws {
    let file = root.appendingPathComponent("legacy-usage.json")
    let today = Calendar.current.startOfDay(for: Date())
    let legacy = [LegacyDailyUsage(day: today, wordCount: 120, dictationCount: 3)]
    try JSONEncoder().encode(legacy).write(to: file)

    let store = UsageStatsStore(fileURL: file)
    require(store.allTime.words == 120, "legacy words were not preserved")
    require(store.allTime.dictations == 3, "legacy dictations were not preserved")
    require(store.appTotals(lastDays: nil).isEmpty, "legacy aggregate data invented an app breakdown")
}

@MainActor
func checkAppAggregation(in root: URL) throws {
    let file = root.appendingPathComponent("app-usage.json")
    let store = UsageStatsStore(fileURL: file)
    let today = Date()

    store.record(
        wordCount: 100,
        appBundleIdentifier: "com.google.Chrome",
        appName: "Google Chrome",
        at: today
    )
    store.record(
        wordCount: 50,
        appBundleIdentifier: "com.tinyspeck.slackmacgap",
        appName: "Slack",
        at: today
    )
    store.record(
        wordCount: 25,
        appBundleIdentifier: "com.google.Chrome",
        appName: "Chrome",
        at: today
    )
    let fortyDaysAgo = Calendar.current.date(byAdding: .day, value: -40, to: today)!
    store.record(
        wordCount: 200,
        appBundleIdentifier: "com.apple.TextEdit",
        appName: "TextEdit",
        at: fortyDaysAgo
    )

    let totals = store.appTotals(lastDays: nil)
    require(totals.count == 3, "expected three app totals")
    let chrome = totals.first { $0.bundleIdentifier == "com.google.Chrome" }
    require(chrome?.appName == "Chrome", "the most recent app name did not win")
    require(chrome?.words == 125, "Chrome words were not aggregated")
    require(chrome?.dictations == 2, "Chrome dictations were not aggregated")
    require(store.appTotals(lastDays: 30).count == 2, "date range did not exclude old app usage")
    require(store.allTime.words == 375, "global totals changed while adding app stats")
    require(store.allTime.dictations == 4, "global dictation totals changed while adding app stats")

    let reloaded = UsageStatsStore(fileURL: file)
    require(reloaded.appTotals(lastDays: nil) == totals, "app totals did not survive persistence")
}

@main
enum UsageStatsChecks {
    @MainActor
    static func main() {
        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        defer { try? FileManager.default.removeItem(at: root) }

        do {
            try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
            try checkLegacyMigration(in: root)
            print("PASS: legacy stats migration")
            try checkAppAggregation(in: root)
            print("PASS: per-app stats aggregation")
        } catch {
            FileHandle.standardError.write(Data("FAIL: \(error)\n".utf8))
            exit(1)
        }
    }
}
