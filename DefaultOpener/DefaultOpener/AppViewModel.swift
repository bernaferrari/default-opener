import SwiftUI
import AppKit
import UniformTypeIdentifiers
import CoreServices

// MARK: - View Model

@MainActor
final class AppViewModel: ObservableObject {
    @Published var fileTypes: [FileTypeAssociation] = []
    @Published var urlSchemes: [URLSchemeAssociation] = []
    @Published var searchText = ""
    @Published var selectedTab: Tab = .fileTypes
    @Published var isLoading = false
    @Published var backups: [BackupInfo] = []
    @Published var activityLog: [ActivityLogEntry] = [] {
        didSet { saveActivityLog() }
    }
    @Published var toastMessage: String?
    @Published var undoAction: (() -> Void)?
    @Published var updateInfo: UpdateInfo?
    @Published var externalChanges: [ExternalChange] = []
    @Published var lastSnapshotDate: Date?

    // Configure these for your GitHub repo
    static let githubOwner = "bernaferrari"
    static let githubRepo = "default-opener"
    static let currentVersion = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0.0"

    private let activityLogKey = "DefaultOpenerActivityLog"
    private let snapshotKey = "DefaultOpenerHandlerSnapshot"

    enum Tab: String, CaseIterable {
        case fileTypes = "File Types"
        case urlSchemes = "URL Schemes"
        case backups = "Backups"
    }

    var filteredFileTypes: [FileTypeAssociation] {
        if searchText.isEmpty {
            return fileTypes
        }
        let query = searchText.lowercased()
        return fileTypes.filter {
            $0.fileExtension.lowercased().contains(query) ||
            $0.uti.lowercased().contains(query) ||
            ($0.defaultHandler?.name.lowercased().contains(query) ?? false)
        }
    }

    var filteredURLSchemes: [URLSchemeAssociation] {
        if searchText.isEmpty {
            return urlSchemes
        }
        let query = searchText.lowercased()
        return urlSchemes.filter {
            $0.scheme.lowercased().contains(query) ||
            ($0.defaultHandler?.name.lowercased().contains(query) ?? false)
        }
    }

    init() {
        loadActivityLog()
        loadAll()
        checkForUpdates()
    }

    func refresh() {
        loadAll()
    }

    private var hasDetectedExternalChanges = false

    private func loadAll() {
        isLoading = true
        Task {
            await loadFileTypes()
            await loadURLSchemes()
            await loadBackups()
            // Only detect external changes once on app launch, not on every refresh
            if !hasDetectedExternalChanges {
                detectExternalChanges()
                hasDetectedExternalChanges = true
            }
            isLoading = false
        }
    }

    // MARK: - Activity Log Persistence

    private func saveActivityLog() {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        if let data = try? encoder.encode(activityLog) {
            UserDefaults.standard.set(data, forKey: activityLogKey)
        }
    }

    private func loadActivityLog() {
        guard let data = UserDefaults.standard.data(forKey: activityLogKey) else { return }
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        if let log = try? decoder.decode([ActivityLogEntry].self, from: data) {
            // Only keep last 100 entries and entries from last 30 days
            let thirtyDaysAgo = Date().addingTimeInterval(-30 * 24 * 60 * 60)
            activityLog = log
                .filter { $0.timestamp > thirtyDaysAgo }
                .prefix(100)
                .map { $0 }
        }
    }

    func clearActivityLog() {
        activityLog.removeAll()
        UserDefaults.standard.removeObject(forKey: activityLogKey)
    }

    // MARK: - Handler Snapshot & External Change Detection

    func saveHandlerSnapshot() {
        let fileTypeHandlers = Dictionary(uniqueKeysWithValues: fileTypes.compactMap { ft -> (String, String)? in
            guard let handler = ft.defaultHandler else { return nil }
            return (ft.fileExtension, handler.bundleIdentifier)
        })

        let schemeHandlers = Dictionary(uniqueKeysWithValues: urlSchemes.compactMap { us -> (String, String)? in
            guard let handler = us.defaultHandler else { return nil }
            return (us.scheme, handler.bundleIdentifier)
        })

        let snapshot = HandlerSnapshot(
            timestamp: Date(),
            fileTypes: fileTypeHandlers,
            urlSchemes: schemeHandlers
        )

        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        if let data = try? encoder.encode(snapshot) {
            UserDefaults.standard.set(data, forKey: snapshotKey)
        }
    }

    private func loadHandlerSnapshot() -> HandlerSnapshot? {
        guard let data = UserDefaults.standard.data(forKey: snapshotKey) else { return nil }
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return try? decoder.decode(HandlerSnapshot.self, from: data)
    }

    func detectExternalChanges() {
        guard let snapshot = loadHandlerSnapshot() else {
            // First launch - save snapshot, no changes to detect
            saveHandlerSnapshot()
            return
        }

        lastSnapshotDate = snapshot.timestamp
        var changes: [ExternalChange] = []

        // Check file types
        for fileType in fileTypes {
            let currentBundleID = fileType.defaultHandler?.bundleIdentifier
            let savedBundleID = snapshot.fileTypes[fileType.fileExtension]

            // Only report if both exist and differ (ignore new handlers or removed handlers)
            if let current = currentBundleID, let saved = savedBundleID, current != saved {
                // Skip if we made this change ourselves (check activity log)
                if wasChangeMadeByUs(target: fileType.fileExtension, newBundleID: current, since: snapshot.timestamp) {
                    continue
                }

                let oldApp = getAppInfo(forBundleID: saved)
                let change = ExternalChange(
                    type: .fileType,
                    target: fileType.fileExtension,
                    oldBundleID: saved,
                    oldAppName: oldApp?.name ?? saved,
                    newBundleID: current,
                    newAppName: fileType.defaultHandler?.name ?? current
                )
                changes.append(change)
            }
        }

        // Check URL schemes
        for scheme in urlSchemes {
            let currentBundleID = scheme.defaultHandler?.bundleIdentifier
            let savedBundleID = snapshot.urlSchemes[scheme.scheme]

            if let current = currentBundleID, let saved = savedBundleID, current != saved {
                // Skip if we made this change ourselves (check activity log)
                if wasChangeMadeByUs(target: scheme.scheme, newBundleID: current, since: snapshot.timestamp) {
                    continue
                }

                let oldApp = getAppInfo(forBundleID: saved)
                let change = ExternalChange(
                    type: .urlScheme,
                    target: scheme.scheme,
                    oldBundleID: saved,
                    oldAppName: oldApp?.name ?? saved,
                    newBundleID: current,
                    newAppName: scheme.defaultHandler?.name ?? current
                )
                changes.append(change)
            }
        }

        externalChanges = changes

        // Always save current state as new baseline after detection
        // This prevents Opener's own changes from being detected on restart
        saveHandlerSnapshot()
    }

    /// Check if a change was made by us (recorded in activity log) since the snapshot
    private func wasChangeMadeByUs(target: String, newBundleID: String, since snapshotDate: Date) -> Bool {
        // Check recent activity log entries
        for entry in activityLog {
            // Only check entries after the snapshot was taken
            guard entry.timestamp > snapshotDate else { continue }

            // Check if this entry matches the change
            if entry.target == target {
                // Direct match on target
                if entry.newBundleID == newBundleID {
                    return true
                }
                // For bulk changes, check the details
                if entry.action == .bulkChange, let details = entry.bulkDetails {
                    for detail in details {
                        if detail.fileExtension == target {
                            return true
                        }
                    }
                }
            }

            // For bulk changes, the target is the count, so check details
            if entry.action == .bulkChange, let details = entry.bulkDetails {
                if details.contains(where: { $0.fileExtension == target }) && entry.newBundleID == newBundleID {
                    return true
                }
            }
        }
        return false
    }

    func revertExternalChange(_ change: ExternalChange) {
        guard let oldBundleID = change.oldBundleID else { return }

        switch change.type {
        case .fileType:
            setDefaultHandler(forExtension: change.target, bundleID: oldBundleID)
        case .urlScheme:
            setDefaultHandler(forScheme: change.target, bundleID: oldBundleID)
        }

        // Remove from external changes list
        externalChanges.removeAll { $0.id == change.id }
        showToast("Reverted \(change.displayTarget)")
    }

    func dismissExternalChange(_ change: ExternalChange) {
        externalChanges.removeAll { $0.id == change.id }
    }

    func revertAllExternalChanges() {
        let count = externalChanges.count
        for change in externalChanges {
            guard let oldBundleID = change.oldBundleID else { continue }

            switch change.type {
            case .fileType:
                setDefaultHandler(forExtension: change.target, bundleID: oldBundleID, skipLog: true)
            case .urlScheme:
                setDefaultHandler(forScheme: change.target, bundleID: oldBundleID, skipLog: true)
            }
        }

        // Log as single activity
        if count > 0 {
            let entry = ActivityLogEntry(
                timestamp: Date(),
                action: .bulkChange,
                target: "\(count)",
                oldValue: nil,
                newValue: "reverted external changes"
            )
            activityLog.insert(entry, at: 0)
        }

        externalChanges.removeAll()
        showToast("Reverted \(count) external changes")
    }

    func dismissAllExternalChanges() {
        externalChanges.removeAll()
        // Save current state as the new baseline
        saveHandlerSnapshot()
    }

    // MARK: - Update Checker (handled by Sparkle, this is for in-app banner only)

    func checkForUpdates() {
        Task {
            await checkGitHubRelease()
        }
    }

    private func checkGitHubRelease() async {
        let urlString = "https://api.github.com/repos/\(Self.githubOwner)/\(Self.githubRepo)/releases/latest"
        guard let url = URL(string: urlString) else { return }

        do {
            let (data, _) = try await URLSession.shared.data(from: url)

            struct GitHubRelease: Codable {
                let tag_name: String
                let html_url: String
                let body: String?
            }

            let release = try JSONDecoder().decode(GitHubRelease.self, from: data)
            let latestVersion = release.tag_name.replacingOccurrences(of: "v", with: "")

            if let releaseURL = URL(string: release.html_url) {
                let info = UpdateInfo(
                    currentVersion: Self.currentVersion,
                    latestVersion: latestVersion,
                    releaseURL: releaseURL,
                    releaseNotes: release.body
                )

                if info.isUpdateAvailable {
                    updateInfo = info
                }
            }
        } catch {
            // Silently fail - update check is not critical
        }
    }

    private func loadFileTypes() async {
        let extensions = CommonExtensions.all
        var associations: [FileTypeAssociation] = []

        for ext in extensions {
            if let assoc = getFileTypeAssociation(forExtension: ext) {
                associations.append(assoc)
            }
        }

        fileTypes = associations.sorted { $0.fileExtension < $1.fileExtension }
    }

    private func loadURLSchemes() async {
        let schemes = CommonURLSchemes.all
        var associations: [URLSchemeAssociation] = []

        for scheme in schemes {
            if let assoc = getURLSchemeAssociation(forScheme: scheme) {
                associations.append(assoc)
            }
        }

        urlSchemes = associations.sorted { $0.scheme < $1.scheme }
    }

    private func loadBackups() async {
        backups = getBackupsList()
    }

    // MARK: - Set Default Handler

    func setDefaultHandler(forExtension ext: String, bundleID: String, skipLog: Bool = false) {
        guard let uti = UTType(filenameExtension: ext)?.identifier else { return }

        // Record old value for undo
        let oldHandler = fileTypes.first(where: { $0.fileExtension == ext })?.defaultHandler

        let status = LSSetDefaultRoleHandlerForContentType(
            uti as CFString,
            .all,
            bundleID as CFString
        )

        if status == noErr {
            // Reload the specific file type
            if let index = fileTypes.firstIndex(where: { $0.fileExtension == ext }),
               let updated = getFileTypeAssociation(forExtension: ext) {
                fileTypes[index] = updated

                // Log the activity
                if !skipLog {
                    let newHandler = updated.defaultHandler
                    let entry = ActivityLogEntry(
                        timestamp: Date(),
                        action: .setFileTypeHandler,
                        target: ext,
                        oldValue: oldHandler?.name,
                        newValue: newHandler?.name,
                        oldBundleID: oldHandler?.bundleIdentifier,
                        newBundleID: newHandler?.bundleIdentifier
                    )
                    activityLog.insert(entry, at: 0)

                    // Show toast with undo option
                    let newName = newHandler?.name ?? "Unknown"
                    if let oldBundleID = oldHandler?.bundleIdentifier {
                        showToast("Changed .\(ext) to \(newName)") { [weak self] in
                            self?.setDefaultHandler(forExtension: ext, bundleID: oldBundleID, skipLog: true)
                            self?.showToast("Reverted .\(ext)")
                        }
                    } else {
                        showToast("Changed .\(ext) to \(newName)")
                    }
                }

                // Update snapshot so our changes aren't detected as external
                saveHandlerSnapshot()
            }
        }
    }

    func setDefaultHandler(forScheme scheme: String, bundleID: String, skipLog: Bool = false) {
        // Record old value for undo
        let oldHandler = urlSchemes.first(where: { $0.scheme == scheme })?.defaultHandler

        let status = LSSetDefaultHandlerForURLScheme(
            scheme as CFString,
            bundleID as CFString
        )

        if status == noErr {
            // Reload the specific URL scheme
            if let index = urlSchemes.firstIndex(where: { $0.scheme == scheme }),
               let updated = getURLSchemeAssociation(forScheme: scheme) {
                urlSchemes[index] = updated

                // Log the activity
                if !skipLog {
                    let newHandler = updated.defaultHandler
                    let entry = ActivityLogEntry(
                        timestamp: Date(),
                        action: .setSchemeHandler,
                        target: scheme,
                        oldValue: oldHandler?.name,
                        newValue: newHandler?.name,
                        oldBundleID: oldHandler?.bundleIdentifier,
                        newBundleID: newHandler?.bundleIdentifier
                    )
                    activityLog.insert(entry, at: 0)

                    // Show toast with undo option
                    let newName = newHandler?.name ?? "Unknown"
                    if let oldBundleID = oldHandler?.bundleIdentifier {
                        showToast("Changed \(scheme):// to \(newName)") { [weak self] in
                            self?.setDefaultHandler(forScheme: scheme, bundleID: oldBundleID, skipLog: true)
                            self?.showToast("Reverted \(scheme)://")
                        }
                    } else {
                        showToast("Changed \(scheme):// to \(newName)")
                    }
                }

                // Update snapshot so our changes aren't detected as external
                saveHandlerSnapshot()
            }
        }
    }

    // MARK: - Bulk Change

    func bulkSetDefaultHandler(forExtensions extensions: [String], bundleID: String, appName: String) {
        var successCount = 0
        var bulkDetails: [ActivityLogEntry.BulkChangeDetail] = []

        for ext in extensions {
            guard let uti = UTType(filenameExtension: ext)?.identifier else { continue }

            // Record old handler for undo
            let oldHandler = fileTypes.first(where: { $0.fileExtension == ext })?.defaultHandler
            let detail = ActivityLogEntry.BulkChangeDetail(
                fileExtension: ext,
                oldBundleID: oldHandler?.bundleIdentifier,
                oldAppName: oldHandler?.name
            )

            let status = LSSetDefaultRoleHandlerForContentType(
                uti as CFString,
                .all,
                bundleID as CFString
            )

            if status == noErr {
                successCount += 1
                bulkDetails.append(detail)
                // Update the local state
                if let index = fileTypes.firstIndex(where: { $0.fileExtension == ext }),
                   let updated = getFileTypeAssociation(forExtension: ext) {
                    fileTypes[index] = updated
                }
            }
        }

        if successCount > 0 {
            // Log as single bulk operation with undo details
            let entry = ActivityLogEntry(
                timestamp: Date(),
                action: .bulkChange,
                target: "\(successCount)",
                oldValue: nil,
                newValue: appName,
                newBundleID: bundleID,
                bulkDetails: bulkDetails
            )
            activityLog.insert(entry, at: 0)
            showToast("Changed \(successCount) file types to \(appName)")

            // Update snapshot so our changes aren't detected as external
            saveHandlerSnapshot()
        }
    }

    // MARK: - Undo

    func undoActivity(_ entry: ActivityLogEntry) {
        switch entry.action {
        case .setFileTypeHandler:
            // Find the old bundleID from the current handlers
            guard let oldName = entry.oldValue else {
                showToast("Cannot undo: no previous handler")
                return
            }

            guard let fileType = fileTypes.first(where: { $0.fileExtension == entry.target }) else {
                showToast("Cannot undo: file type not found")
                return
            }

            // Validate current state matches what we recorded
            let currentName = fileType.defaultHandler?.name
            if currentName != entry.newValue {
                // State was changed outside the app
                showToast("Handler was changed externally - refreshing")
                refresh()
                return
            }

            guard let handler = fileType.availableHandlers.first(where: { $0.name == oldName }) else {
                showToast("Cannot undo: \(oldName) is no longer available")
                return
            }

            setDefaultHandler(forExtension: entry.target, bundleID: handler.bundleIdentifier, skipLog: true)

            // Log the undo as a new activity
            let undoEntry = ActivityLogEntry(
                timestamp: Date(),
                action: .setFileTypeHandler,
                target: entry.target,
                oldValue: entry.newValue,
                newValue: entry.oldValue
            )
            activityLog.insert(undoEntry, at: 0)
            showToast("Undone: .\(entry.target)")

        case .setSchemeHandler:
            guard let oldName = entry.oldValue else {
                showToast("Cannot undo: no previous handler")
                return
            }

            guard let scheme = urlSchemes.first(where: { $0.scheme == entry.target }) else {
                showToast("Cannot undo: URL scheme not found")
                return
            }

            // Validate current state matches what we recorded
            let currentName = scheme.defaultHandler?.name
            if currentName != entry.newValue {
                showToast("Handler was changed externally - refreshing")
                refresh()
                return
            }

            guard let handler = scheme.availableHandlers.first(where: { $0.name == oldName }) else {
                showToast("Cannot undo: \(oldName) is no longer available")
                return
            }

            setDefaultHandler(forScheme: entry.target, bundleID: handler.bundleIdentifier, skipLog: true)

            let undoEntry = ActivityLogEntry(
                timestamp: Date(),
                action: .setSchemeHandler,
                target: entry.target,
                oldValue: entry.newValue,
                newValue: entry.oldValue
            )
            activityLog.insert(undoEntry, at: 0)
            showToast("Undone: \(entry.target)://")

        case .bulkChange:
            guard let details = entry.bulkDetails, !details.isEmpty else {
                showToast("Cannot undo: no details available")
                return
            }

            // Check if any handlers were changed externally
            var changedExternally = 0
            for detail in details {
                if let fileType = fileTypes.first(where: { $0.fileExtension == detail.fileExtension }) {
                    let currentHandler = fileType.defaultHandler?.bundleIdentifier
                    // The entry's newValue is the app name we changed TO, so current should match
                    // We stored oldBundleID, so current should NOT be oldBundleID (it should be the new one)
                    if currentHandler == detail.oldBundleID {
                        // Already reverted somehow
                        changedExternally += 1
                    }
                }
            }

            if changedExternally > 0 {
                showToast("\(changedExternally) handlers changed externally - refreshing")
                refresh()
                return
            }

            var restoredCount = 0
            var newBulkDetails: [ActivityLogEntry.BulkChangeDetail] = []

            for detail in details {
                guard let oldBundleID = detail.oldBundleID,
                      let uti = UTType(filenameExtension: detail.fileExtension)?.identifier else {
                    continue
                }

                // Record current state for potential re-redo
                let currentHandler = fileTypes.first(where: { $0.fileExtension == detail.fileExtension })?.defaultHandler
                let newDetail = ActivityLogEntry.BulkChangeDetail(
                    fileExtension: detail.fileExtension,
                    oldBundleID: currentHandler?.bundleIdentifier,
                    oldAppName: currentHandler?.name
                )

                let status = LSSetDefaultRoleHandlerForContentType(
                    uti as CFString,
                    .all,
                    oldBundleID as CFString
                )

                if status == noErr {
                    restoredCount += 1
                    newBulkDetails.append(newDetail)

                    if let index = fileTypes.firstIndex(where: { $0.fileExtension == detail.fileExtension }),
                       let updated = getFileTypeAssociation(forExtension: detail.fileExtension) {
                        fileTypes[index] = updated
                    }
                }
            }

            if restoredCount > 0 {
                let undoEntry = ActivityLogEntry(
                    timestamp: Date(),
                    action: .bulkChange,
                    target: "\(restoredCount)",
                    oldValue: nil,
                    newValue: "previous handlers",
                    bulkDetails: newBulkDetails
                )
                activityLog.insert(undoEntry, at: 0)
                showToast("Restored \(restoredCount) file types")
            } else {
                showToast("Cannot undo: previous apps no longer available")
            }

        default:
            break
        }
    }

    // MARK: - Toast

    func showToast(_ message: String, undoAction: (() -> Void)? = nil) {
        toastMessage = message
        self.undoAction = undoAction
        Task {
            try? await Task.sleep(nanoseconds: 4_000_000_000) // 4 seconds for undo opportunity
            if toastMessage == message {
                toastMessage = nil
                self.undoAction = nil
            }
        }
    }

    func performUndo() {
        undoAction?()
        toastMessage = nil
        undoAction = nil
    }

    // MARK: - Backup Management

    func createBackup() {
        Task {
            let backupManager = BackupManager()
            if let url = try? backupManager.createBackup(
                fileTypes: Dictionary(uniqueKeysWithValues: fileTypes.compactMap { ft -> (String, String)? in
                    guard let handler = ft.defaultHandler else { return nil }
                    return (ft.fileExtension, handler.bundleIdentifier)
                }),
                urlSchemes: Dictionary(uniqueKeysWithValues: urlSchemes.compactMap { us -> (String, String)? in
                    guard let handler = us.defaultHandler else { return nil }
                    return (us.scheme, handler.bundleIdentifier)
                })
            ) {
                await loadBackups()

                // Log the activity
                let entry = ActivityLogEntry(
                    timestamp: Date(),
                    action: .createBackup,
                    target: url.lastPathComponent,
                    oldValue: nil,
                    newValue: nil
                )
                activityLog.insert(entry, at: 0)
                showToast("Backup created")
            }
        }
    }

    func restoreBackup(_ backup: BackupInfo) {
        Task {
            let backupManager = BackupManager()
            if let result = try? backupManager.restore(from: backup.url) {
                await loadFileTypes()
                await loadURLSchemes()

                // Log the activity
                let entry = ActivityLogEntry(
                    timestamp: Date(),
                    action: .restore,
                    target: backup.formattedDate,
                    oldValue: nil,
                    newValue: "\(result.restoredFileTypes.count) files, \(result.restoredSchemes.count) schemes"
                )
                activityLog.insert(entry, at: 0)
                showToast("Restored \(result.restoredFileTypes.count) file types, \(result.restoredSchemes.count) schemes")
            }
        }
    }

    func deleteBackup(_ backup: BackupInfo) {
        Task {
            try? FileManager.default.removeItem(at: backup.url)
            await loadBackups()
        }
    }

    // MARK: - Private Helpers

    private func getFileTypeAssociation(forExtension ext: String) -> FileTypeAssociation? {
        guard let utType = UTType(filenameExtension: ext) else { return nil }
        let uti = utType.identifier

        let defaultHandler = getDefaultHandler(forUTI: uti)
        let availableHandlers = getAllHandlers(forUTI: uti)

        return FileTypeAssociation(
            fileExtension: ext,
            uti: uti,
            utiDescription: utType.localizedDescription,
            defaultHandler: defaultHandler,
            availableHandlers: availableHandlers
        )
    }

    private func getURLSchemeAssociation(forScheme scheme: String) -> URLSchemeAssociation? {
        let defaultHandler = getDefaultHandler(forScheme: scheme)
        let availableHandlers = getAllHandlers(forScheme: scheme)

        return URLSchemeAssociation(
            scheme: scheme,
            description: CommonURLSchemes.description(for: scheme),
            defaultHandler: defaultHandler,
            availableHandlers: availableHandlers
        )
    }

    private func getDefaultHandler(forUTI uti: String) -> AppInfo? {
        guard let handlerID = LSCopyDefaultRoleHandlerForContentType(
            uti as CFString,
            .all
        )?.takeRetainedValue() as String? else {
            return nil
        }

        return getAppInfo(forBundleID: handlerID)
    }

    private func getDefaultHandler(forScheme scheme: String) -> AppInfo? {
        guard let url = URL(string: "\(scheme)://"),
              let appURL = NSWorkspace.shared.urlForApplication(toOpen: url) else {
            return nil
        }

        return AppInfo(url: appURL)
    }

    private func getAllHandlers(forUTI uti: String) -> [AppInfo] {
        guard let handlers = LSCopyAllRoleHandlersForContentType(
            uti as CFString,
            .all
        )?.takeRetainedValue() as? [String] else {
            return []
        }

        // Sort by name to maintain consistent order
        return handlers.compactMap { getAppInfo(forBundleID: $0) }
            .sorted { $0.name.lowercased() < $1.name.lowercased() }
    }

    private func getAllHandlers(forScheme scheme: String) -> [AppInfo] {
        guard let url = URL(string: "\(scheme)://") else {
            return []
        }

        let appURLs = NSWorkspace.shared.urlsForApplications(toOpen: url)
        // Sort by name to maintain consistent order
        return appURLs.compactMap { AppInfo(url: $0) }
            .sorted { $0.name.lowercased() < $1.name.lowercased() }
    }

    private func getAppInfo(forBundleID bundleID: String) -> AppInfo? {
        guard let appURL = NSWorkspace.shared.urlForApplication(
            withBundleIdentifier: bundleID
        ) else {
            return nil
        }

        return AppInfo(url: appURL)
    }

    private func getBackupsList() -> [BackupInfo] {
        let backupManager = BackupManager()
        return (try? backupManager.listBackups()) ?? []
    }
}

// MARK: - View Extensions

extension AppViewModel {
    var uniqueApps: [AppInfo] {
        var seen = Set<String>()
        var apps: [AppInfo] = []

        for fileType in fileTypes {
            if let handler = fileType.defaultHandler {
                if !seen.contains(handler.bundleIdentifier) {
                    seen.insert(handler.bundleIdentifier)
                    apps.append(handler)
                }
            }
        }

        return apps.sorted { $0.name < $1.name }
    }

    func fileTypesCount(for bundleID: String) -> Int {
        fileTypes.filter { $0.defaultHandler?.bundleIdentifier == bundleID }.count
    }

    func fileTypes(for category: FileCategory) -> [FileTypeAssociation] {
        let exts = Set(category.extensions)
        let filtered = fileTypes.filter { exts.contains($0.fileExtension) }

        if searchText.isEmpty {
            return filtered
        }

        let query = searchText.lowercased()
        return filtered.filter {
            $0.fileExtension.lowercased().contains(query) ||
            $0.uti.lowercased().contains(query) ||
            ($0.defaultHandler?.name.lowercased().contains(query) ?? false)
        }
    }
}
