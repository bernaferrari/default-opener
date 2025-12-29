import Foundation
import UniformTypeIdentifiers
import CoreServices

// MARK: - Backup Manager

class BackupManager {
    private let backupDirectory: URL

    init() {
        let appSupport = FileManager.default.urls(
            for: .applicationSupportDirectory,
            in: .userDomainMask
        ).first!

        backupDirectory = appSupport
            .appendingPathComponent("DefaultOpener", isDirectory: true)
            .appendingPathComponent("backups", isDirectory: true)
    }

    var backupDirectoryURL: URL { backupDirectory }

    func createBackup(fileTypes: [String: String], urlSchemes: [String: String]) throws -> URL {
        try ensureDirectoryExists()

        let backup = AssociationsBackup(fileTypes: fileTypes, urlSchemes: urlSchemes)

        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withFullDate, .withTime, .withColonSeparatorInTime]
        let timestamp = formatter.string(from: Date()).replacingOccurrences(of: ":", with: "-")

        let filename = "backup-\(timestamp).json"
        let fileURL = backupDirectory.appendingPathComponent(filename)

        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        encoder.dateEncodingStrategy = .iso8601

        let data = try encoder.encode(backup)
        try data.write(to: fileURL)

        return fileURL
    }

    func restore(from url: URL) throws -> RestoreResult {
        let data = try Data(contentsOf: url)

        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601

        let backup = try decoder.decode(AssociationsBackup.self, from: data)
        var result = RestoreResult()

        for (ext, bundleID) in backup.fileTypes {
            if let uti = UTType(filenameExtension: ext)?.identifier {
                let status = LSSetDefaultRoleHandlerForContentType(
                    uti as CFString,
                    .all,
                    bundleID as CFString
                )
                if status == noErr {
                    result.restoredFileTypes.append(ext)
                }
            }
        }

        for (scheme, bundleID) in backup.urlSchemes {
            let status = LSSetDefaultHandlerForURLScheme(
                scheme as CFString,
                bundleID as CFString
            )
            if status == noErr {
                result.restoredSchemes.append(scheme)
            }
        }

        return result
    }

    func listBackups() throws -> [BackupInfo] {
        try ensureDirectoryExists()

        let contents = try FileManager.default.contentsOfDirectory(
            at: backupDirectory,
            includingPropertiesForKeys: [.fileSizeKey],
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

    private func ensureDirectoryExists() throws {
        if !FileManager.default.fileExists(atPath: backupDirectory.path) {
            try FileManager.default.createDirectory(
                at: backupDirectory,
                withIntermediateDirectories: true
            )
        }
    }
}
