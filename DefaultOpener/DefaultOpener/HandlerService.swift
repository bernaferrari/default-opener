import AppKit
import Foundation
import UniformTypeIdentifiers

/// LaunchServices associates a handler with a content type, not an individual spelling of its extension.
enum HandlerTarget: Hashable, Codable, Sendable {
    case contentType(String)
    case urlScheme(String)

    static func fileExtension(_ value: String) -> HandlerTarget? {
        UTType(filenameExtension: value).map { .contentType($0.identifier) }
    }

    var displayName: String {
        switch self {
        case .contentType(let identifier):
            return UTType(identifier)?.preferredFilenameExtension.map { ".\($0)" } ?? identifier
        case .urlScheme(let scheme): return "\(scheme)://"
        }
    }
}

struct HandlerCatalog: Sendable {
    var fileTypes: [FileTypeAssociation]
    var urlSchemes: [URLSchemeAssociation]

    var snapshot: HandlerSnapshot {
        var files: [String: String] = [:]
        for item in fileTypes { files[item.uti] = item.defaultHandler?.bundleIdentifier }
        var schemes: [String: String] = [:]
        for item in urlSchemes { schemes[item.scheme] = item.defaultHandler?.bundleIdentifier }
        return HandlerSnapshot(timestamp: Date(), fileTypes: files, urlSchemes: schemes)
    }
}

protocol HandlerService: Sendable {
    func associations(extensions: [String], schemes: [String]) async throws -> HandlerCatalog
    func currentHandler(for target: HandlerTarget) async throws -> AppInfo?
    func application(bundleID: String) async -> AppInfo?
    func setHandler(bundleID: String, for target: HandlerTarget) async throws
}

enum HandlerServiceError: LocalizedError, Sendable {
    case unknownContentType(String)
    case invalidScheme(String)
    case applicationUnavailable(String)
    case changedExternally(String)
    case verificationFailed(String)
    case conflictingRequests(String)

    var errorDescription: String? {
        switch self {
        case .unknownContentType(let value): return "The content type \(value) is unavailable."
        case .invalidScheme(let value): return "The URL scheme \(value) is invalid."
        case .applicationUnavailable(let value): return "The application \(value) is no longer installed."
        case .changedExternally(let value): return "\(value) changed since this operation was recorded. Refresh and review its current default."
        case .verificationFailed(let value): return "macOS did not confirm the requested default for \(value)."
        case .conflictingRequests(let value): return "The operation contains conflicting defaults for \(value)."
        }
    }
}

/// An actor keeps filesystem and synchronous workspace discovery off the UI actor.
actor WorkspaceHandlerService: HandlerService {
    func application(bundleID: String) -> AppInfo? {
        guard let url = NSWorkspace.shared.urlForApplication(withBundleIdentifier: bundleID) else { return nil }
        return AppInfo(url: url)
    }

    func currentHandler(for target: HandlerTarget) throws -> AppInfo? {
        let url: URL?
        switch target {
        case .contentType(let identifier):
            guard let type = UTType(identifier) else { throw HandlerServiceError.unknownContentType(identifier) }
            url = NSWorkspace.shared.urlForApplication(toOpen: type)
        case .urlScheme(let scheme):
            url = NSWorkspace.shared.urlForApplication(toOpen: try schemeURL(scheme))
        }
        return url.flatMap(AppInfo.init(url:))
    }

    func setHandler(bundleID: String, for target: HandlerTarget) async throws {
        guard let applicationURL = NSWorkspace.shared.urlForApplication(withBundleIdentifier: bundleID) else {
            throw HandlerServiceError.applicationUnavailable(bundleID)
        }
        switch target {
        case .contentType(let identifier):
            guard let type = UTType(identifier) else { throw HandlerServiceError.unknownContentType(identifier) }
            try await NSWorkspace.shared.setDefaultApplication(at: applicationURL, toOpen: type)
        case .urlScheme(let scheme):
            _ = try schemeURL(scheme)
            try await NSWorkspace.shared.setDefaultApplication(at: applicationURL, toOpenURLsWithScheme: scheme)
        }
    }

    func associations(extensions: [String], schemes: [String]) throws -> HandlerCatalog {
        var applicationCache: [URL: AppInfo] = [:]
        var typeCache: [String: (AppInfo?, [AppInfo])] = [:]
        var files: [FileTypeAssociation] = []
        for ext in Set(extensions).sorted() {
            try Task.checkCancellation()
            guard let type = UTType(filenameExtension: ext) else { continue }
            let handlers: (AppInfo?, [AppInfo])
            if let cached = typeCache[type.identifier] {
                handlers = cached
            } else {
                let defaultApp: AppInfo?
                if let url = NSWorkspace.shared.urlForApplication(toOpen: type) {
                    defaultApp = app(at: url, cache: &applicationCache)
                } else { defaultApp = nil }
                let availableApps = apps(at: NSWorkspace.shared.urlsForApplications(toOpen: type), cache: &applicationCache)
                handlers = (defaultApp, availableApps)
                typeCache[type.identifier] = handlers
            }
            files.append(FileTypeAssociation(fileExtension: ext, uti: type.identifier,
                utiDescription: type.localizedDescription, defaultHandler: handlers.0, availableHandlers: handlers.1))
        }
        var urls: [URLSchemeAssociation] = []
        for scheme in Set(schemes).sorted() {
            try Task.checkCancellation()
            let url = try schemeURL(scheme)
            let defaultApp: AppInfo?
            if let applicationURL = NSWorkspace.shared.urlForApplication(toOpen: url) {
                defaultApp = app(at: applicationURL, cache: &applicationCache)
            } else { defaultApp = nil }
            let availableApps = apps(at: NSWorkspace.shared.urlsForApplications(toOpen: url), cache: &applicationCache)
            urls.append(URLSchemeAssociation(scheme: scheme, description: CommonURLSchemes.description(for: scheme),
                defaultHandler: defaultApp, availableHandlers: availableApps))
        }
        return HandlerCatalog(fileTypes: files, urlSchemes: urls)
    }

    private func app(at url: URL, cache: inout [URL: AppInfo]) -> AppInfo? {
        if let cached = cache[url] { return cached }
        let value = AppInfo(url: url)
        cache[url] = value
        return value
    }

    private func apps(at urls: [URL], cache: inout [URL: AppInfo]) -> [AppInfo] {
        var seen = Set<String>()
        var result: [AppInfo] = []
        for url in urls {
            if let value = app(at: url, cache: &cache), seen.insert(value.bundleIdentifier).inserted {
                result.append(value)
            }
        }
        return result.sorted { $0.name.localizedStandardCompare($1.name) == .orderedAscending }
    }

    private func schemeURL(_ scheme: String) throws -> URL {
        guard scheme.range(of: "^[A-Za-z][A-Za-z0-9+.-]*$", options: .regularExpression) != nil,
              let url = URL(string: "\(scheme)://") else { throw HandlerServiceError.invalidScheme(scheme) }
        return url
    }
}

struct HandlerMutationRequest: Sendable {
    enum Expectation: Equatable, Sendable {
        case any
        case matches(String?)
    }
    let target: HandlerTarget
    let bundleID: String
    var expectation: Expectation = .any
}

struct HandlerOperationFailure: Identifiable, Sendable {
    var id: HandlerTarget { target }
    let target: HandlerTarget
    let message: String
}

struct PendingHandlerChange: Sendable {
    let target: HandlerTarget
    let oldHandler: AppInfo?
    let requestedBundleID: String
}

struct HandlerMutationResult: Sendable {
    var unverifiedChanges: [PendingHandlerChange] = []
    var changes: [HandlerChangeRecord] = []
    var failures: [HandlerOperationFailure] = []
    var unchanged: [HandlerTarget] = []
    var succeeded: Bool { failures.isEmpty }
}

/// All write paths share the same live-state validation, alias deduplication and failure reporting.
actor HandlerMutationService {
    private let handlers: any HandlerService
    private var isApplying = false
    private var waitingOperations: [CheckedContinuation<Void, Never>] = []
    init(handlers: any HandlerService) { self.handlers = handlers }

    // Actor methods can reenter at each await; explicitly serialize complete read/write/verify operations.
    private func acquireOperation() async {
        if !isApplying {
            isApplying = true
            return
        }
        await withCheckedContinuation { waitingOperations.append($0) }
    }

    private func releaseOperation() {
        if waitingOperations.isEmpty { isApplying = false }
        else { waitingOperations.removeFirst().resume() }
    }

    func apply(_ requests: [HandlerMutationRequest]) async -> HandlerMutationResult {
        await acquireOperation()
        defer { releaseOperation() }
        var result = HandlerMutationResult()
        var unique: [HandlerTarget: HandlerMutationRequest] = [:]
        var conflicts = Set<HandlerTarget>()
        for request in requests {
            if let existing = unique[request.target],
               existing.bundleID != request.bundleID || existing.expectation != request.expectation {
                conflicts.insert(request.target)
            } else { unique[request.target] = request }
        }
        for target in conflicts {
            unique.removeValue(forKey: target)
            result.failures.append(HandlerOperationFailure(target: target,
                message: HandlerServiceError.conflictingRequests(target.displayName).localizedDescription))
        }
        for request in unique.values.sorted(by: { $0.target.displayName < $1.target.displayName }) {
            do {
                try Task.checkCancellation()
                let old = try await handlers.currentHandler(for: request.target)
                if case .matches(let expected) = request.expectation, old?.bundleIdentifier != expected {
                    throw HandlerServiceError.changedExternally(request.target.displayName)
                }
                if old?.bundleIdentifier == request.bundleID {
                    result.unchanged.append(request.target)
                    continue
                }
                try await handlers.setHandler(bundleID: request.bundleID, for: request.target)
                do {
                    let updated = try await handlers.currentHandler(for: request.target)
                    guard updated?.bundleIdentifier == request.bundleID else {
                        throw HandlerServiceError.verificationFailed(request.target.displayName)
                    }
                    result.changes.append(HandlerChangeRecord(target: request.target, oldHandler: old, newHandler: updated))
                } catch {
                    // The setter completed. Preserve its old state so a subsequent successful catalog read can verify it.
                    result.unverifiedChanges.append(PendingHandlerChange(target: request.target,
                        oldHandler: old, requestedBundleID: request.bundleID))
                    throw error
                }
            } catch {
                result.failures.append(HandlerOperationFailure(target: request.target, message: error.localizedDescription))
            }
        }
        return result
    }
}
