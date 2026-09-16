import SwiftUI
import Foundation

struct PersistedAppState: Sendable {
    var activity: [ActivityLogEntry] = []
    var snapshot: HandlerSnapshot?
}

protocol AppStateStore: Sendable {
    func load() async -> PersistedAppState
    func saveActivity(_ activity: [ActivityLogEntry]) async
    func saveSnapshot(_ snapshot: HandlerSnapshot) async
}

actor PreferencesStateStore: AppStateStore {
    private let defaults: UserDefaults
    private let activityKey = "DefaultOpenerActivityLogV2"
    private let snapshotKey = "DefaultOpenerHandlerSnapshotV2"

    init(suiteName: String? = nil) {
        defaults = suiteName.flatMap(UserDefaults.init(suiteName:)) ?? .standard
    }
    func load() -> PersistedAppState {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let activity = defaults.data(forKey: activityKey).flatMap { try? decoder.decode([ActivityLogEntry].self, from: $0) } ?? []
        let snapshot = defaults.data(forKey: snapshotKey).flatMap { try? decoder.decode(HandlerSnapshot.self, from: $0) }
        return PersistedAppState(activity: activity, snapshot: snapshot)
    }
    func saveActivity(_ activity: [ActivityLogEntry]) {
        defaults.set(encode(activity), forKey: activityKey)
    }
    func saveSnapshot(_ snapshot: HandlerSnapshot) {
        defaults.set(encode(snapshot), forKey: snapshotKey)
    }
    private func encode<T: Encodable>(_ value: T) -> Data? {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        return try? encoder.encode(value)
    }
}

@MainActor
final class AppViewModel: ObservableObject {
    @Published var fileTypes: [FileTypeAssociation] = []
    @Published var urlSchemes: [URLSchemeAssociation] = []
    @Published var searchText = ""
    @Published var isLoading = false
    @Published var isMutating = false
    @Published var backups: [BackupInfo] = []
    @Published var activityLog: [ActivityLogEntry] = []
    @Published var toastMessage: String?
    @Published var undoAction: (() -> Void)?
    @Published var externalChanges: [ExternalChange] = []
    @Published var externalChangeDetectionComplete = false
    @Published var operationError: OperationError?
    @Published var lastOperationSucceeded: Bool?

    let handlers: any HandlerService
    let backupStore: any BackupStore
    let stateStore: any AppStateStore
    let mutations: HandlerMutationService
    var baseline: HandlerSnapshot?
    private var additionalContentTypeHandlers: [String: AppInfo] = [:]
    var operationTask: Task<Void, Never>?
    private var refreshTask: Task<Void, Never>?
    private var toastTask: Task<Void, Never>?
    private var loadedState = false
    private var snapshotSaveTask: Task<Void, Never>?
    private var activitySaveTask: Task<Void, Never>?

    init(handlers: any HandlerService = WorkspaceHandlerService(),
         backups: any BackupStore = BackupManager(),
         stateStore: any AppStateStore = PreferencesStateStore(),
         automaticallyLoad: Bool = true) {
        self.handlers = handlers
        backupStore = backups
        self.stateStore = stateStore
        mutations = HandlerMutationService(handlers: handlers)
        if automaticallyLoad { refresh() }
    }

    func refresh() {
        guard !isLoading, !isMutating else { return }
        isLoading = true
        externalChangeDetectionComplete = false
        refreshTask = Task { await load() }
    }

    /// Explicit async entry point also allows tests to load a model without starting the application.
    func load() async {
        isLoading = true
        externalChangeDetectionComplete = false
        defer { isLoading = false }
        if !loadedState {
            let state = await stateStore.load()
            activityLog = Self.prunedActivity(state.activity)
            baseline = state.snapshot
            loadedState = true
        }
        do {
            try await reloadAssociations()
            await loadBackups()
            await detectExternalChanges()
        } catch {
            reportError("Couldn’t Load Defaults", error.localizedDescription)
        }
    }

    func waitForOperation() async { await operationTask?.value }
    func waitForRefresh() async { await refreshTask?.value }

    func reloadAssociations(additionalTargets: [HandlerTarget] = []) async throws {
        var schemes = Set(CommonURLSchemes.all)
        schemes.formUnion(baseline?.urlSchemes.keys.map { $0 } ?? [])
        var contentTypes = Set(baseline?.fileTypes.keys.map { $0 } ?? [])
        for target in additionalTargets {
            switch target {
            case .contentType(let identifier): contentTypes.insert(identifier)
            case .urlScheme(let scheme): schemes.insert(scheme)
            }
        }
        let catalog = try await handlers.associations(extensions: CommonExtensions.all, schemes: schemes.sorted())
        let listedTypes = Set(catalog.fileTypes.map(\.uti))
        var extraHandlers: [String: AppInfo] = [:]
        // Imported backups may contain types without an extension in our curated list.
        // Query those exact UTIs and retain them in snapshots and subsequent backups.
        for identifier in contentTypes.subtracting(listedTypes).sorted() {
            extraHandlers[identifier] = try await handlers.currentHandler(for: .contentType(identifier))
        }
        fileTypes = catalog.fileTypes
        urlSchemes = catalog.urlSchemes
        additionalContentTypeHandlers = extraHandlers
    }

    func loadedHandler(for target: HandlerTarget) -> AppInfo? {
        switch target {
        case .contentType(let uti):
            return fileTypes.first { $0.uti == uti }?.defaultHandler ?? additionalContentTypeHandlers[uti]
        case .urlScheme(let scheme): return urlSchemes.first { $0.scheme == scheme }?.defaultHandler
        }
    }

    func loadBackups() async {
        do {
            let result = try await backupStore.listBackups()
            backups = result.backups
            if !result.warnings.isEmpty {
                reportError("Some Backups Couldn’t Be Read", result.warnings.joined(separator: "\n"))
            }
        } catch { reportError("Couldn’t Load Backups", error.localizedDescription) }
    }

    var currentSnapshot: HandlerSnapshot {
        var snapshot = HandlerCatalog(fileTypes: fileTypes, urlSchemes: urlSchemes).snapshot
        for (identifier, handler) in additionalContentTypeHandlers {
            snapshot.fileTypes[identifier] = handler.bundleIdentifier
        }
        return snapshot
    }

    func detectExternalChanges() async {
        let current = currentSnapshot
        guard let previous = baseline else {
            baseline = current
            await enqueueSnapshotSave(current).value
            externalChanges = []
            externalChangeDetectionComplete = true
            return
        }
        var targets = Set(previous.fileTypes.keys.map(HandlerTarget.contentType))
        targets.formUnion(previous.urlSchemes.keys.map(HandlerTarget.urlScheme))
        // New handlers have no previous default to restore, so only previously tracked defaults are compared.
        var changes: [ExternalChange] = []
        for target in targets.sorted(by: { $0.displayName < $1.displayName }) {
            guard previous[target] != current[target] else { continue }
            let oldApp = if let id = previous[target] { await handlers.application(bundleID: id) } else { nil as AppInfo? }
            let newApp = if let id = current[target] { await handlers.application(bundleID: id) } else { nil as AppInfo? }
            let type: ExternalChange.ChangeType
            let value: String
            switch target {
            case .contentType(let uti):
                type = .fileType
                value = fileTypes.first(where: { $0.uti == uti })?.fileExtension ?? uti
            case .urlScheme(let scheme): type = .urlScheme; value = scheme
            }
            changes.append(ExternalChange(handlerTarget: target, type: type, target: value,
                oldBundleID: previous[target], oldAppName: oldApp?.name ?? previous[target],
                newBundleID: current[target], newAppName: newApp?.name ?? current[target]))
        }
        externalChanges = changes
        externalChangeDetectionComplete = true
    }

    /// Only advance confirmed targets; unrelated external changes remain available for review.
    func recordConfirmedChanges(_ changes: [HandlerChangeRecord]) async {
        var updated = baseline ?? currentSnapshot
        for change in changes { updated[change.target] = change.newHandler?.bundleIdentifier }
        updated.timestamp = Date()
        baseline = updated
        await enqueueSnapshotSave(updated).value
    }

    func dismissAllExternalChanges() {
        guard !isMutating, !isLoading else { return }
        let reviewed = externalChanges
        var updated = baseline ?? currentSnapshot
        for change in reviewed { updated[change.handlerTarget] = change.newBundleID }
        updated.timestamp = Date()
        baseline = updated
        externalChanges = []
        operationTask = enqueueSnapshotSave(updated)
    }

    func appendActivity(_ entry: ActivityLogEntry) async {
        activityLog = Self.prunedActivity([entry] + activityLog)
        await enqueueActivitySave(activityLog).value
    }

    // Enqueue synchronously, in the same order as published state changes. An injected store may suspend.
    private func enqueueSnapshotSave(_ snapshot: HandlerSnapshot) -> Task<Void, Never> {
        let previous = snapshotSaveTask
        let task = Task { [stateStore] in
            await previous?.value
            await stateStore.saveSnapshot(snapshot)
        }
        snapshotSaveTask = task
        return task
    }

    private func enqueueActivitySave(_ activity: [ActivityLogEntry]) -> Task<Void, Never> {
        let previous = activitySaveTask
        let task = Task { [stateStore] in
            await previous?.value
            await stateStore.saveActivity(activity)
        }
        activitySaveTask = task
        return task
    }

    private static func prunedActivity(_ entries: [ActivityLogEntry]) -> [ActivityLogEntry] {
        let cutoff = Date().addingTimeInterval(-30 * 24 * 60 * 60)
        return Array(entries.filter { $0.timestamp > cutoff }.prefix(100))
    }

    func showToast(_ message: String, undoAction: (() -> Void)? = nil) {
        toastTask?.cancel()
        toastMessage = message
        self.undoAction = undoAction
        toastTask = Task { [weak self] in
            do { try await Task.sleep(for: .seconds(6)) } catch { return }
            self?.toastMessage = nil
            self?.undoAction = nil
        }
    }

    func performUndo() {
        guard !isMutating, !isLoading else { return }
        let action = undoAction
        undoAction = nil
        toastMessage = nil
        action?()
    }

    func reportError(_ title: String, _ message: String) {
        operationError = OperationError(title: title, message: message)
    }

    var filteredFileTypes: [FileTypeAssociation] { fileTypes.filter(matchesSearch) }
    var filteredURLSchemes: [URLSchemeAssociation] {
        guard !searchText.isEmpty else { return urlSchemes }
        return urlSchemes.filter {
            $0.scheme.localizedCaseInsensitiveContains(searchText) ||
            ($0.defaultHandler?.name.localizedCaseInsensitiveContains(searchText) ?? false)
        }
    }
    private func matchesSearch(_ item: FileTypeAssociation) -> Bool {
        searchText.isEmpty || item.fileExtension.localizedCaseInsensitiveContains(searchText) ||
            item.uti.localizedCaseInsensitiveContains(searchText) ||
            (item.defaultHandler?.name.localizedCaseInsensitiveContains(searchText) ?? false)
    }
    var uniqueApps: [AppInfo] {
        var seen = Set<String>()
        return fileTypes.compactMap(\.defaultHandler).filter { seen.insert($0.bundleIdentifier).inserted }
            .sorted { $0.name.localizedStandardCompare($1.name) == .orderedAscending }
    }
    func fileTypesCount(for bundleID: String) -> Int {
        fileTypes.filter { $0.defaultHandler?.bundleIdentifier == bundleID }.count
    }
    func fileTypes(for category: FileCategory) -> [FileTypeAssociation] {
        let extensions = Set(category.extensions)
        return fileTypes.filter { extensions.contains($0.fileExtension) && matchesSearch($0) }
    }
}
