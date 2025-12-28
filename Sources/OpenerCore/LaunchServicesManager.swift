import Foundation
import CoreServices
import UniformTypeIdentifiers
import AppKit

// MARK: - Errors

public enum OpenerError: Error, LocalizedError {
    case invalidExtension(String)
    case invalidUTI(String)
    case invalidScheme(String)
    case invalidBundleID(String)
    case noDefaultHandler
    case setHandlerFailed(OSStatus)
    case appNotFound(String)

    public var errorDescription: String? {
        switch self {
        case .invalidExtension(let ext):
            return "Invalid file extension: \(ext)"
        case .invalidUTI(let uti):
            return "Invalid UTI: \(uti)"
        case .invalidScheme(let scheme):
            return "Invalid URL scheme: \(scheme)"
        case .invalidBundleID(let id):
            return "Invalid bundle identifier: \(id)"
        case .noDefaultHandler:
            return "No default handler found"
        case .setHandlerFailed(let status):
            return "Failed to set handler (OSStatus: \(status))"
        case .appNotFound(let name):
            return "Application not found: \(name)"
        }
    }
}

// MARK: - Launch Services Manager

/// Main class for interacting with macOS Launch Services
public final class LaunchServicesManager: @unchecked Sendable {
    public static let shared = LaunchServicesManager()

    private init() {}

    // MARK: - UTI Helpers

    /// Get the UTI for a file extension
    public func uti(forExtension ext: String) -> String? {
        let cleanExt = ext.hasPrefix(".") ? String(ext.dropFirst()) : ext
        guard let utType = UTType(filenameExtension: cleanExt) else {
            return nil
        }
        return utType.identifier
    }

    /// Get human-readable description for a UTI
    public func description(forUTI uti: String) -> String? {
        guard let utType = UTType(uti) else { return nil }
        return utType.localizedDescription
    }

    // MARK: - Get Default Handlers

    /// Get the default application for a file extension
    public func getDefaultHandler(forExtension ext: String) throws -> AppInfo? {
        let cleanExt = ext.hasPrefix(".") ? String(ext.dropFirst()) : ext

        guard let uti = uti(forExtension: cleanExt) else {
            throw OpenerError.invalidExtension(ext)
        }

        return try getDefaultHandler(forUTI: uti)
    }

    /// Get the default application for a UTI
    public func getDefaultHandler(forUTI uti: String) throws -> AppInfo? {
        guard let handlerID = LSCopyDefaultRoleHandlerForContentType(
            uti as CFString,
            .all
        )?.takeRetainedValue() as String? else {
            return nil
        }

        return getAppInfo(forBundleID: handlerID)
    }

    /// Get the default application for a URL scheme
    public func getDefaultHandler(forScheme scheme: String) throws -> AppInfo? {
        let cleanScheme = scheme.replacingOccurrences(of: "://", with: "")

        guard let handlerID = LSCopyDefaultHandlerForURLScheme(
            cleanScheme as CFString
        )?.takeRetainedValue() as String? else {
            return nil
        }

        return getAppInfo(forBundleID: handlerID)
    }

    // MARK: - Get All Handlers

    /// Get all applications that can handle a file extension
    public func getAllHandlers(forExtension ext: String) throws -> [AppInfo] {
        let cleanExt = ext.hasPrefix(".") ? String(ext.dropFirst()) : ext

        guard let uti = uti(forExtension: cleanExt) else {
            throw OpenerError.invalidExtension(ext)
        }

        return try getAllHandlers(forUTI: uti)
    }

    /// Get all applications that can handle a UTI
    public func getAllHandlers(forUTI uti: String) throws -> [AppInfo] {
        guard let handlers = LSCopyAllRoleHandlersForContentType(
            uti as CFString,
            .all
        )?.takeRetainedValue() as? [String] else {
            return []
        }

        return handlers.compactMap { getAppInfo(forBundleID: $0) }
    }

    /// Get all applications that can handle a URL scheme
    public func getAllHandlers(forScheme scheme: String) throws -> [AppInfo] {
        let cleanScheme = scheme.replacingOccurrences(of: "://", with: "")

        guard let handlers = LSCopyAllHandlersForURLScheme(
            cleanScheme as CFString
        )?.takeRetainedValue() as? [String] else {
            return []
        }

        return handlers.compactMap { getAppInfo(forBundleID: $0) }
    }

    // MARK: - Set Default Handlers

    /// Set the default application for a file extension
    @discardableResult
    public func setDefaultHandler(
        forExtension ext: String,
        bundleID: String,
        role: LSRolesMask = .all
    ) throws -> Bool {
        let cleanExt = ext.hasPrefix(".") ? String(ext.dropFirst()) : ext

        guard let uti = uti(forExtension: cleanExt) else {
            throw OpenerError.invalidExtension(ext)
        }

        return try setDefaultHandler(forUTI: uti, bundleID: bundleID, role: role)
    }

    /// Set the default application for a UTI
    @discardableResult
    public func setDefaultHandler(
        forUTI uti: String,
        bundleID: String,
        role: LSRolesMask = .all
    ) throws -> Bool {
        // Verify the bundle ID exists
        guard getAppInfo(forBundleID: bundleID) != nil else {
            throw OpenerError.invalidBundleID(bundleID)
        }

        let status = LSSetDefaultRoleHandlerForContentType(
            uti as CFString,
            role,
            bundleID as CFString
        )

        if status != noErr {
            throw OpenerError.setHandlerFailed(status)
        }

        return true
    }

    /// Set the default application for a URL scheme
    @discardableResult
    public func setDefaultHandler(
        forScheme scheme: String,
        bundleID: String
    ) throws -> Bool {
        let cleanScheme = scheme.replacingOccurrences(of: "://", with: "")

        // Verify the bundle ID exists
        guard getAppInfo(forBundleID: bundleID) != nil else {
            throw OpenerError.invalidBundleID(bundleID)
        }

        let status = LSSetDefaultHandlerForURLScheme(
            cleanScheme as CFString,
            bundleID as CFString
        )

        if status != noErr {
            throw OpenerError.setHandlerFailed(status)
        }

        return true
    }

    // MARK: - Get Associations

    /// Get file type association for an extension
    public func getFileTypeAssociation(forExtension ext: String) throws -> FileTypeAssociation {
        let cleanExt = ext.hasPrefix(".") ? String(ext.dropFirst()) : ext

        guard let uti = uti(forExtension: cleanExt) else {
            throw OpenerError.invalidExtension(ext)
        }

        let defaultHandler = try? getDefaultHandler(forUTI: uti)
        let allHandlers = (try? getAllHandlers(forUTI: uti)) ?? []
        let description = self.description(forUTI: uti)

        return FileTypeAssociation(
            fileExtension: cleanExt,
            uti: uti,
            utiDescription: description,
            defaultHandler: defaultHandler,
            availableHandlers: allHandlers
        )
    }

    /// Get URL scheme association
    public func getURLSchemeAssociation(forScheme scheme: String) throws -> URLSchemeAssociation {
        let cleanScheme = scheme.replacingOccurrences(of: "://", with: "")

        let defaultHandler = try? getDefaultHandler(forScheme: cleanScheme)
        let allHandlers = (try? getAllHandlers(forScheme: cleanScheme)) ?? []
        let description = CommonURLSchemes.description(for: cleanScheme)

        return URLSchemeAssociation(
            scheme: cleanScheme,
            description: description,
            defaultHandler: defaultHandler,
            availableHandlers: allHandlers
        )
    }

    /// Get all file type associations for common extensions
    public func getAllFileTypeAssociations(
        extensions: [String] = CommonExtensions.all
    ) -> [FileTypeAssociation] {
        extensions.compactMap { ext in
            try? getFileTypeAssociation(forExtension: ext)
        }
    }

    /// Get all URL scheme associations for common schemes
    public func getAllURLSchemeAssociations(
        schemes: [String] = CommonURLSchemes.all
    ) -> [URLSchemeAssociation] {
        schemes.compactMap { scheme in
            try? getURLSchemeAssociation(forScheme: scheme)
        }
    }

    // MARK: - App Info Helpers

    /// Get app info from a bundle identifier
    public func getAppInfo(forBundleID bundleID: String) -> AppInfo? {
        guard let appURL = NSWorkspace.shared.urlForApplication(
            withBundleIdentifier: bundleID
        ) else {
            return nil
        }

        return AppInfo(url: appURL)
    }

    /// Get bundle ID from an app name (fuzzy search)
    public func getBundleID(forAppName name: String) -> String? {
        // First try exact match via mdfind
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/mdfind")
        process.arguments = [
            "kMDItemKind == 'Application' && kMDItemDisplayName == '\(name)'cd"
        ]

        let pipe = Pipe()
        process.standardOutput = pipe

        do {
            try process.run()
            process.waitUntilExit()

            let data = pipe.fileHandleForReading.readDataToEndOfFile()
            if let output = String(data: data, encoding: .utf8)?
                .trimmingCharacters(in: .whitespacesAndNewlines),
               !output.isEmpty {
                let paths = output.components(separatedBy: "\n")
                if let firstPath = paths.first,
                   let bundle = Bundle(path: firstPath) {
                    return bundle.bundleIdentifier
                }
            }
        } catch {
            // Fall through to alternative method
        }

        // Try via Applications folder
        let appPaths = [
            "/Applications/\(name).app",
            "/Applications/\(name)",
            "/System/Applications/\(name).app",
            NSHomeDirectory() + "/Applications/\(name).app"
        ]

        for path in appPaths {
            if let bundle = Bundle(path: path) {
                return bundle.bundleIdentifier
            }
        }

        return nil
    }

    /// Get the icon for an application
    public func getAppIcon(forBundleID bundleID: String) -> NSImage? {
        guard let appURL = NSWorkspace.shared.urlForApplication(
            withBundleIdentifier: bundleID
        ) else {
            return nil
        }

        return NSWorkspace.shared.icon(forFile: appURL.path)
    }

    // MARK: - Installed Apps

    /// Get all installed applications
    public func getInstalledApps() -> [AppInfo] {
        var apps: [AppInfo] = []
        let searchPaths = [
            "/Applications",
            "/System/Applications",
            NSHomeDirectory() + "/Applications"
        ]

        let fileManager = FileManager.default

        for searchPath in searchPaths {
            guard let enumerator = fileManager.enumerator(
                at: URL(fileURLWithPath: searchPath),
                includingPropertiesForKeys: [.isApplicationKey],
                options: [.skipsHiddenFiles, .skipsPackageDescendants]
            ) else { continue }

            for case let fileURL as URL in enumerator {
                if fileURL.pathExtension == "app",
                   let appInfo = AppInfo(url: fileURL) {
                    apps.append(appInfo)
                }
            }
        }

        return apps.sorted { $0.name.lowercased() < $1.name.lowercased() }
    }
}

// MARK: - Convenience Extensions

extension LaunchServicesManager {
    /// Quick check if an extension has a default handler
    public func hasDefaultHandler(forExtension ext: String) -> Bool {
        (try? getDefaultHandler(forExtension: ext)) != nil
    }

    /// Quick check if a scheme has a default handler
    public func hasDefaultHandler(forScheme scheme: String) -> Bool {
        (try? getDefaultHandler(forScheme: scheme)) != nil
    }
}
