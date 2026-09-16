import Foundation
import UniformTypeIdentifiers

protocol BackupStore: Sendable {
    func createBackup(fileTypes: [String: String], urlSchemes: [String: String]) async throws -> URL
    func readBackup(at url: URL) async throws -> AssociationsBackup
    func inspectBackup(at url: URL) async throws -> BackupInfo
    func listBackups() async throws -> BackupListing
    func trashBackup(at url: URL) async throws
}

struct BackupListing: Sendable {
    var backups: [BackupInfo] = []
    var warnings: [String] = []
}

enum BackupError: LocalizedError {
    case unsupportedVersion(Int)
    case invalidContentType(String)
    case invalidScheme(String)
    case invalidApplication(String)
    case outsideBackupDirectory

    var errorDescription: String? {
        switch self {
        case .unsupportedVersion(let version):
            return "Backup version \(version) is not supported. Create a new backup with this version of Default Opener."
        case .invalidContentType(let value): return "The backup contains an invalid content type: \(value)."
        case .invalidScheme(let value): return "The backup contains an invalid URL scheme: \(value)."
        case .invalidApplication(let value): return "The backup contains an invalid application identifier for \(value)."
        case .outsideBackupDirectory: return "Only backups in Default Opener’s backup folder can be moved to Trash."
        }
    }
}

/// Backup parsing and disk access never run on the UI actor. This service does not change defaults.
actor BackupManager: BackupStore {
    let backupDirectoryURL: URL
    private let now: @Sendable () -> Date

    init(directory: URL? = nil, now: @escaping @Sendable () -> Date = Date.init) {
        backupDirectoryURL = directory ?? FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("DefaultOpener/backups", isDirectory: true)
        self.now = now
    }

    func createBackup(fileTypes: [String: String], urlSchemes: [String: String]) throws -> URL {
        let backup = AssociationsBackup(fileTypes: fileTypes, urlSchemes: urlSchemes, createdAt: now())
        try validate(backup)
        try ensureDirectoryExists()
        let timestamp = backup.createdAt.ISO8601Format().replacingOccurrences(of: ":", with: "-")
        let url = backupDirectoryURL.appendingPathComponent("backup-\(timestamp)-\(UUID().uuidString).json")
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        encoder.dateEncodingStrategy = .iso8601
        try encoder.encode(backup).write(to: url, options: .atomic)
        return url
    }

    func readBackup(at url: URL) throws -> AssociationsBackup {
        let accessed = url.startAccessingSecurityScopedResource()
        defer { if accessed { url.stopAccessingSecurityScopedResource() } }
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let backup = try decoder.decode(AssociationsBackup.self, from: Data(contentsOf: url))
        try validate(backup)
        return backup
    }

    func inspectBackup(at url: URL) throws -> BackupInfo {
        let accessed = url.startAccessingSecurityScopedResource()
        defer { if accessed { url.stopAccessingSecurityScopedResource() } }
        let backup = try readBackup(at: url)
        let values = try url.resourceValues(forKeys: [.fileSizeKey])
        return BackupInfo(url: url, createdAt: backup.createdAt, macOSVersion: backup.macOSVersion,
            fileTypesCount: backup.fileTypes.count, schemesCount: backup.urlSchemes.count,
            fileSize: values.fileSize ?? 0)
    }

    func listBackups() throws -> BackupListing {
        try ensureDirectoryExists()
        let urls = try FileManager.default.contentsOfDirectory(at: backupDirectoryURL,
            includingPropertiesForKeys: [.fileSizeKey], options: [.skipsHiddenFiles])
        var result = BackupListing()
        for url in urls.filter({ $0.pathExtension == "json" }) {
            do { result.backups.append(try inspectBackup(at: url)) }
            catch { result.warnings.append("\(url.lastPathComponent): \(error.localizedDescription)") }
        }
        result.backups.sort { $0.createdAt > $1.createdAt }
        return result
    }

    func trashBackup(at url: URL) throws {
        guard url.deletingLastPathComponent().resolvingSymlinksInPath().standardizedFileURL ==
                backupDirectoryURL.resolvingSymlinksInPath().standardizedFileURL,
              url.pathExtension == "json" else { throw BackupError.outsideBackupDirectory }
        try FileManager.default.trashItem(at: url, resultingItemURL: nil)
    }

    private func validate(_ backup: AssociationsBackup) throws {
        guard backup.version == 2 else { throw BackupError.unsupportedVersion(backup.version) }
        for (identifier, bundleID) in backup.fileTypes {
            guard UTType(identifier) != nil else { throw BackupError.invalidContentType(identifier) }
            try validateApplication(bundleID, target: identifier)
        }
        for (scheme, bundleID) in backup.urlSchemes {
            guard scheme.range(of: "^[A-Za-z][A-Za-z0-9+.-]*$", options: .regularExpression) != nil else {
                throw BackupError.invalidScheme(scheme)
            }
            try validateApplication(bundleID, target: scheme)
        }
    }

    private func validateApplication(_ bundleID: String, target: String) throws {
        guard !bundleID.isEmpty, bundleID.rangeOfCharacter(from: .whitespacesAndNewlines) == nil else {
            throw BackupError.invalidApplication(target)
        }
    }

    private func ensureDirectoryExists() throws {
        try FileManager.default.createDirectory(at: backupDirectoryURL, withIntermediateDirectories: true)
    }
}
