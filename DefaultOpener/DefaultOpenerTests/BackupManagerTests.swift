import XCTest

final class BackupManagerTests: XCTestCase {
    private func temporaryDirectory() throws -> URL {
        let url = FileManager.default.temporaryDirectory.appendingPathComponent("DefaultOpenerTests-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        addTeardownBlock { try? FileManager.default.removeItem(at: url) }
        return url
    }

    func testSameTimestampBackupsRemainDistinctAndRoundTripCanonicalTargets() async throws {
        let directory = try temporaryDirectory()
        let now = Date(timeIntervalSince1970: 1_700_000_000)
        let store = BackupManager(directory: directory, now: { now })
        let first = try await store.createBackup(fileTypes: ["public.jpeg": firstApp.bundleIdentifier], urlSchemes: ["https": firstApp.bundleIdentifier])
        let second = try await store.createBackup(fileTypes: ["public.jpeg": secondApp.bundleIdentifier], urlSchemes: [:])
        XCTAssertNotEqual(first, second)
        let firstBackup = try await store.readBackup(at: first)
        let secondBackup = try await store.readBackup(at: second)
        XCTAssertEqual(firstBackup.createdAt, now)
        XCTAssertEqual(firstBackup.fileTypes, ["public.jpeg": firstApp.bundleIdentifier])
        XCTAssertEqual(secondBackup.fileTypes, ["public.jpeg": secondApp.bundleIdentifier])
        XCTAssertEqual(firstBackup.mutationRequests.count, 2)
        let listing = try await store.listBackups()
        XCTAssertEqual(listing.backups.count, 2)
        XCTAssertTrue(listing.warnings.isEmpty)
    }

    func testCorruptFileProducesWarningWithoutHidingValidBackups() async throws {
        let directory = try temporaryDirectory()
        let store = BackupManager(directory: directory)
        _ = try await store.createBackup(fileTypes: ["public.jpeg": firstApp.bundleIdentifier], urlSchemes: [:])
        try Data("invalid backup".utf8).write(to: directory.appendingPathComponent("broken.json"))
        let listing = try await store.listBackups()
        XCTAssertEqual(listing.backups.count, 1)
        XCTAssertEqual(listing.warnings.count, 1)
        XCTAssertTrue(listing.warnings[0].contains("broken.json"))
    }

    func testUnsupportedBackupVersionIsRejectedBeforeMutation() async throws {
        let directory = try temporaryDirectory()
        let url = directory.appendingPathComponent("unsupported.json")
        let contents = #"{"version":1,"createdAt":"2023-11-14T22:13:20Z","macOSVersion":"old","fileTypes":{"jpg":"test.first","jpeg":"test.second"},"urlSchemes":{}}"#
        try Data(contents.utf8).write(to: url)
        do {
            _ = try await BackupManager(directory: directory).readBackup(at: url)
            XCTFail("Unsupported extension-based backups must not be applied in dictionary order")
        } catch BackupError.unsupportedVersion(1) {
            // Deliberately rejected: the macOS 27 app writes canonical version-2 backups.
        }
    }

    func testInvalidSchemeIsRejectedAndCreatesNoBackup() async throws {
        let directory = try temporaryDirectory()
        let store = BackupManager(directory: directory)
        do {
            _ = try await store.createBackup(fileTypes: [:], urlSchemes: ["not a scheme": firstApp.bundleIdentifier])
            XCTFail("Invalid schemes must be rejected")
        } catch BackupError.invalidScheme {
        }
        XCTAssertTrue(try FileManager.default.contentsOfDirectory(atPath: directory.path).isEmpty)
    }

    func testTrashRefusesFilesOutsideManagedDirectory() async throws {
        let directory = try temporaryDirectory()
        let store = BackupManager(directory: directory.appendingPathComponent("managed"))
        let unrelated = directory.appendingPathComponent("unrelated.json")
        try Data("keep".utf8).write(to: unrelated)
        do {
            try await store.trashBackup(at: unrelated)
            XCTFail("An unrelated imported file must not be trashed")
        } catch BackupError.outsideBackupDirectory {
        }
        XCTAssertTrue(FileManager.default.fileExists(atPath: unrelated.path))
    }
}
