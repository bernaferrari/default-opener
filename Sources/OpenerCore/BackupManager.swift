import Foundation

/// Manages backup and restore of file associations
public final class BackupManager: @unchecked Sendable {
    public static let shared = BackupManager()

    private let backupDirectory: URL

    private init() {
        let appSupport = FileManager.default.urls(
            for: .applicationSupportDirectory,
            in: .userDomainMask
        ).first!

        backupDirectory = appSupport
            .appendingPathComponent("Opener", isDirectory: true)
            .appendingPathComponent("backups", isDirectory: true)
    }

    // MARK: - Directory Management

    private func ensureBackupDirectoryExists() throws {
        if !FileManager.default.fileExists(atPath: backupDirectory.path) {
            try FileManager.default.createDirectory(
                at: backupDirectory,
                withIntermediateDirectories: true
            )
        }
    }

    /// Get the backup directory URL
    public func getBackupDirectory() -> URL {
        backupDirectory
    }

    // MARK: - Create Backup

    /// Create a backup of current associations
    public func createBackup(
        extensions: [String] = CommonExtensions.all,
        schemes: [String] = CommonURLSchemes.all
    ) throws -> URL {
        try ensureBackupDirectoryExists()

        let manager = LaunchServicesManager.shared

        // Gather file type associations
        var fileTypes: [String: String] = [:]
        for ext in extensions {
            if let handler = try? manager.getDefaultHandler(forExtension: ext) {
                fileTypes[ext] = handler.bundleIdentifier
            }
        }

        // Gather URL scheme associations
        var urlSchemes: [String: String] = [:]
        for scheme in schemes {
            if let handler = try? manager.getDefaultHandler(forScheme: scheme) {
                urlSchemes[scheme] = handler.bundleIdentifier
            }
        }

        let backup = AssociationsBackup(
            fileTypes: fileTypes,
            urlSchemes: urlSchemes
        )

        // Generate filename with timestamp
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withFullDate, .withTime, .withColonSeparatorInTime]
        let timestamp = formatter.string(from: Date())
            .replacingOccurrences(of: ":", with: "-")

        let filename = "backup-\(timestamp).json"
        let fileURL = backupDirectory.appendingPathComponent(filename)

        // Write backup
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        encoder.dateEncodingStrategy = .iso8601

        let data = try encoder.encode(backup)
        try data.write(to: fileURL)

        return fileURL
    }

    /// Create a backup to a specific file
    public func createBackup(
        to url: URL,
        extensions: [String] = CommonExtensions.all,
        schemes: [String] = CommonURLSchemes.all
    ) throws {
        let manager = LaunchServicesManager.shared

        // Gather file type associations
        var fileTypes: [String: String] = [:]
        for ext in extensions {
            if let handler = try? manager.getDefaultHandler(forExtension: ext) {
                fileTypes[ext] = handler.bundleIdentifier
            }
        }

        // Gather URL scheme associations
        var urlSchemes: [String: String] = [:]
        for scheme in schemes {
            if let handler = try? manager.getDefaultHandler(forScheme: scheme) {
                urlSchemes[scheme] = handler.bundleIdentifier
            }
        }

        let backup = AssociationsBackup(
            fileTypes: fileTypes,
            urlSchemes: urlSchemes
        )

        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        encoder.dateEncodingStrategy = .iso8601

        let data = try encoder.encode(backup)
        try data.write(to: url)
    }

    // MARK: - Restore Backup

    /// Restore associations from a backup file
    public func restore(from url: URL) throws -> RestoreResult {
        let data = try Data(contentsOf: url)

        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601

        let backup = try decoder.decode(AssociationsBackup.self, from: data)

        return try restore(backup: backup)
    }

    /// Restore associations from a backup object
    public func restore(backup: AssociationsBackup) throws -> RestoreResult {
        let manager = LaunchServicesManager.shared
        var result = RestoreResult()

        // Restore file types
        for (ext, bundleID) in backup.fileTypes {
            do {
                try manager.setDefaultHandler(forExtension: ext, bundleID: bundleID)
                result.restoredFileTypes.append(ext)
            } catch {
                result.failedFileTypes[ext] = error.localizedDescription
            }
        }

        // Restore URL schemes
        for (scheme, bundleID) in backup.urlSchemes {
            do {
                try manager.setDefaultHandler(forScheme: scheme, bundleID: bundleID)
                result.restoredSchemes.append(scheme)
            } catch {
                result.failedSchemes[scheme] = error.localizedDescription
            }
        }

        return result
    }

    /// Restore from the latest backup
    public func restoreLatest() throws -> RestoreResult {
        guard let latest = try listBackups().first else {
            throw BackupError.noBackupsFound
        }

        return try restore(from: latest.url)
    }

    // MARK: - List Backups

    /// List all available backups (newest first)
    public func listBackups() throws -> [BackupInfo] {
        try ensureBackupDirectoryExists()

        let contents = try FileManager.default.contentsOfDirectory(
            at: backupDirectory,
            includingPropertiesForKeys: [.creationDateKey, .fileSizeKey],
            options: [.skipsHiddenFiles]
        )

        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601

        return contents
            .filter { $0.pathExtension == "json" }
            .compactMap { url -> BackupInfo? in
                guard let data = try? Data(contentsOf: url),
                      let backup = try? decoder.decode(AssociationsBackup.self, from: data),
                      let attributes = try? FileManager.default.attributesOfItem(atPath: url.path),
                      let size = attributes[.size] as? Int else {
                    return nil
                }

                return BackupInfo(
                    url: url,
                    createdAt: backup.createdAt,
                    macOSVersion: backup.macOSVersion,
                    fileTypesCount: backup.fileTypes.count,
                    schemesCount: backup.urlSchemes.count,
                    fileSize: size
                )
            }
            .sorted { $0.createdAt > $1.createdAt }
    }

    // MARK: - Delete Backup

    /// Delete a backup file
    public func deleteBackup(at url: URL) throws {
        try FileManager.default.removeItem(at: url)
    }

    /// Delete all backups
    public func deleteAllBackups() throws {
        let backups = try listBackups()
        for backup in backups {
            try deleteBackup(at: backup.url)
        }
    }

    // MARK: - Preview/Diff

    /// Preview what would change if a backup is restored
    public func previewRestore(from url: URL) throws -> RestorePreview {
        let data = try Data(contentsOf: url)

        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601

        let backup = try decoder.decode(AssociationsBackup.self, from: data)

        return previewRestore(backup: backup)
    }

    /// Preview what would change if a backup is restored
    public func previewRestore(backup: AssociationsBackup) -> RestorePreview {
        let manager = LaunchServicesManager.shared
        var preview = RestorePreview()

        // Check file types
        for (ext, backupBundleID) in backup.fileTypes {
            let currentHandler = try? manager.getDefaultHandler(forExtension: ext)
            let currentBundleID = currentHandler?.bundleIdentifier

            if currentBundleID != backupBundleID {
                preview.fileTypeChanges.append(
                    AssociationChange(
                        identifier: ext,
                        currentBundleID: currentBundleID,
                        newBundleID: backupBundleID
                    )
                )
            }
        }

        // Check URL schemes
        for (scheme, backupBundleID) in backup.urlSchemes {
            let currentHandler = try? manager.getDefaultHandler(forScheme: scheme)
            let currentBundleID = currentHandler?.bundleIdentifier

            if currentBundleID != backupBundleID {
                preview.schemeChanges.append(
                    AssociationChange(
                        identifier: scheme,
                        currentBundleID: currentBundleID,
                        newBundleID: backupBundleID
                    )
                )
            }
        }

        return preview
    }
}

// MARK: - Supporting Types

public struct BackupInfo: Sendable {
    public let url: URL
    public let createdAt: Date
    public let macOSVersion: String
    public let fileTypesCount: Int
    public let schemesCount: Int
    public let fileSize: Int

    public var filename: String {
        url.lastPathComponent
    }

    public var formattedDate: String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter.string(from: createdAt)
    }

    public var formattedSize: String {
        ByteCountFormatter.string(fromByteCount: Int64(fileSize), countStyle: .file)
    }
}

public struct RestoreResult: Sendable {
    public var restoredFileTypes: [String] = []
    public var restoredSchemes: [String] = []
    public var failedFileTypes: [String: String] = [:]
    public var failedSchemes: [String: String] = [:]

    public var totalRestored: Int {
        restoredFileTypes.count + restoredSchemes.count
    }

    public var totalFailed: Int {
        failedFileTypes.count + failedSchemes.count
    }

    public var isSuccess: Bool {
        totalFailed == 0
    }
}

public struct RestorePreview: Sendable {
    public var fileTypeChanges: [AssociationChange] = []
    public var schemeChanges: [AssociationChange] = []

    public var totalChanges: Int {
        fileTypeChanges.count + schemeChanges.count
    }

    public var hasChanges: Bool {
        totalChanges > 0
    }
}

public struct AssociationChange: Sendable {
    public let identifier: String
    public let currentBundleID: String?
    public let newBundleID: String

    public var currentAppName: String {
        guard let bundleID = currentBundleID,
              let app = LaunchServicesManager.shared.getAppInfo(forBundleID: bundleID) else {
            return "(none)"
        }
        return app.name
    }

    public var newAppName: String {
        guard let app = LaunchServicesManager.shared.getAppInfo(forBundleID: newBundleID) else {
            return newBundleID
        }
        return app.name
    }
}

public enum BackupError: Error, LocalizedError {
    case noBackupsFound
    case invalidBackupFile
    case backupDirectoryNotFound

    public var errorDescription: String? {
        switch self {
        case .noBackupsFound:
            return "No backups found"
        case .invalidBackupFile:
            return "Invalid backup file"
        case .backupDirectoryNotFound:
            return "Backup directory not found"
        }
    }
}
