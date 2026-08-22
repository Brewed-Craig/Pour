import Foundation
import HistoryKit
import PrivacyKit

func require(_ condition: @autoclosure () -> Bool, _ message: String) {
    guard condition() else {
        FileHandle.standardError.write(Data("FAIL: \(message)\n".utf8))
        exit(1)
    }
}

func mode(of url: URL) throws -> Int {
    let attributes = try FileManager.default.attributesOfItem(atPath: url.path)
    return (attributes[.posixPermissions] as? NSNumber)?.intValue ?? -1
}

@MainActor
func checkHistory(in root: URL) throws {
    let historyFile = root.appendingPathComponent("history.json")
    let store = HistoryStore(fileURL: historyFile)
    let enabledResult = store.record(text: "kept", appName: nil, strategy: "accessibility", elapsedMS: 1, hits: [])
    require(enabledResult != nil, "enabled history did not record")
    require(FileManager.default.fileExists(atPath: historyFile.path), "history was not persisted")
    store.setEnabled(false)
    let disabledResult = store.record(text: "discarded", appName: nil, strategy: "accessibility", elapsedMS: 1, hits: [])
    require(disabledResult == nil, "disabled history recorded a transcript")
    let countAfterDisabledRecord = store.entries.count
    require(countAfterDisabledRecord == 1, "disabled history changed existing entries")
    store.clear()
    let isEmptyAfterClear = store.entries.isEmpty
    require(isEmptyAfterClear, "clear did not empty in-memory history")
    require(!FileManager.default.fileExists(atPath: historyFile.path), "clear did not remove persisted history")
}

let root = FileManager.default.temporaryDirectory
    .appendingPathComponent(UUID().uuidString, isDirectory: true)
defer { try? FileManager.default.removeItem(at: root) }

do {
    try FileManager.default.createDirectory(
        at: root,
        withIntermediateDirectories: true,
        attributes: [.posixPermissions: 0o755]
    )
    try SecureLocalStorage.prepareDirectory(root)
    let privateFile = root.appendingPathComponent("private.json")
    try Data("[]".utf8).write(to: privateFile)
    try FileManager.default.setAttributes([.posixPermissions: 0o644], ofItemAtPath: privateFile.path)
    try SecureLocalStorage.protectFile(privateFile)
    let directoryMode = try mode(of: root)
    let fileMode = try mode(of: privateFile)
    require(directoryMode == 0o700, "support directory is not mode 700")
    require(fileMode == 0o600, "private file is not mode 600")
    print("PASS: permissions")

    try await checkHistory(in: root)
    print("PASS: history")
} catch {
    FileHandle.standardError.write(Data("FAIL: \(error)\n".utf8))
    exit(1)
}
