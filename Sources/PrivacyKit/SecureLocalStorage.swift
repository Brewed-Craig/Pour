import Foundation

/// Applies least-privilege POSIX permissions to Pour's local private data.
public enum SecureLocalStorage {
    public static let directoryPermissions = 0o700
    public static let filePermissions = 0o600

    public static func prepareDirectory(_ directory: URL) throws {
        if !FileManager.default.fileExists(atPath: directory.path) {
            try FileManager.default.createDirectory(
                at: directory,
                withIntermediateDirectories: true,
                attributes: [.posixPermissions: directoryPermissions]
            )
        }
        try FileManager.default.setAttributes(
            [.posixPermissions: directoryPermissions],
            ofItemAtPath: directory.path
        )
    }

    public static func protectFile(_ file: URL) throws {
        guard FileManager.default.fileExists(atPath: file.path) else { return }
        try FileManager.default.setAttributes(
            [.posixPermissions: filePermissions],
            ofItemAtPath: file.path
        )
    }
}
