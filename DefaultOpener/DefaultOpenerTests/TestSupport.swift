import Foundation
import UniformTypeIdentifiers

let firstApp = AppInfo(bundleIdentifier: "test.first", name: "Editor", path: "/Applications/First.app")
let secondApp = AppInfo(bundleIdentifier: "test.second", name: "Editor", path: "/Applications/Second.app")
let thirdApp = AppInfo(bundleIdentifier: "test.third", name: "Third", path: "/Applications/Third.app")

enum TestFailure: LocalizedError {
    case denied
    var errorDescription: String? { "The test handler rejected this change." }
}

actor FakeHandlerService: HandlerService {
    private var defaults: [HandlerTarget: AppInfo]
    private var rejected = Set<HandlerTarget>()
    private var ignored = Set<HandlerTarget>()
    private var writes: [HandlerTarget] = []
    private var discoveryFailure = false
    private var staleReadAfterWrite = false
    private var staleRead: AppInfo?
    private var pauseNextWrite = false
    private var pausedWrite: CheckedContinuation<Void, Never>?
    private var writeStartWaiter: CheckedContinuation<Void, Never>?
    private let apps = [firstApp, secondApp, thirdApp]

    init(defaults: [HandlerTarget: AppInfo] = [.contentType("public.jpeg"): firstApp, .urlScheme("https"): firstApp]) {
        self.defaults = defaults
    }

    func application(bundleID: String) -> AppInfo? { apps.first { $0.bundleIdentifier == bundleID } }
    func currentHandler(for target: HandlerTarget) -> AppInfo? {
        if let staleRead { self.staleRead = nil; return staleRead }
        return defaults[target]
    }
    func useStaleVerificationOnce() { staleReadAfterWrite = true }
    func replaceExternally(_ target: HandlerTarget, with app: AppInfo?) { defaults[target] = app }
    func reject(_ target: HandlerTarget) { rejected.insert(target) }
    func ignoreWrite(_ target: HandlerTarget) { ignored.insert(target) }
    func failDiscovery(_ value: Bool) { discoveryFailure = value }
    func writtenTargets() -> [HandlerTarget] { writes }

    func pauseNextMutation() { pauseNextWrite = true }
    func waitUntilMutationStarts() async {
        if pausedWrite != nil { return }
        await withCheckedContinuation { writeStartWaiter = $0 }
    }
    func resumeMutation() { pausedWrite?.resume(); pausedWrite = nil }

    func setHandler(bundleID: String, for target: HandlerTarget) async throws {
        if rejected.contains(target) { throw TestFailure.denied }
        guard let app = application(bundleID: bundleID) else { throw HandlerServiceError.applicationUnavailable(bundleID) }
        writes.append(target)
        if pauseNextWrite {
            pauseNextWrite = false
            await withCheckedContinuation { continuation in
                pausedWrite = continuation
                writeStartWaiter?.resume()
                writeStartWaiter = nil
            }
        }
        if staleReadAfterWrite {
            staleRead = defaults[target]
            staleReadAfterWrite = false
        }
        if !ignored.contains(target) { defaults[target] = app }
    }

    func associations(extensions: [String], schemes: [String]) throws -> HandlerCatalog {
        if discoveryFailure { throw TestFailure.denied }
        return HandlerCatalog(fileTypes: extensions.compactMap { ext in
            guard let type = UTType(filenameExtension: ext) else { return nil }
            return FileTypeAssociation(fileExtension: ext, uti: type.identifier, utiDescription: type.localizedDescription,
                defaultHandler: defaults[.contentType(type.identifier)], availableHandlers: apps)
        }, urlSchemes: schemes.map { scheme in
            URLSchemeAssociation(scheme: scheme, description: nil,
                defaultHandler: defaults[.urlScheme(scheme)], availableHandlers: apps)
        })
    }
}

actor MemoryStateStore: AppStateStore {
    private var state: PersistedAppState
    init(snapshot: HandlerSnapshot? = nil) { state = PersistedAppState(snapshot: snapshot) }
    func load() -> PersistedAppState { state }
    func saveActivity(_ activity: [ActivityLogEntry]) { state.activity = activity }
    func saveSnapshot(_ snapshot: HandlerSnapshot) { state.snapshot = snapshot }
}
