import SwiftUI
import AppKit

// MARK: - App Info Model

struct AppInfo: Identifiable, Hashable, Codable, Sendable {
    var id: String { bundleIdentifier }
    let bundleIdentifier: String
    let name: String
    let path: String

    init(bundleIdentifier: String, name: String, path: String) {
        self.bundleIdentifier = bundleIdentifier
        self.name = name
        self.path = path
    }

    init?(url: URL) {
        guard let bundle = Bundle(url: url),
              let bundleId = bundle.bundleIdentifier else {
            return nil
        }

        self.bundleIdentifier = bundleId
        self.name = bundle.infoDictionary?["CFBundleName"] as? String
            ?? bundle.infoDictionary?["CFBundleDisplayName"] as? String
            ?? url.deletingPathExtension().lastPathComponent
        self.path = url.path
    }

    @MainActor
    var icon: NSImage? {
        NSWorkspace.shared.icon(forFile: path)
    }
}

// MARK: - File Type Association

struct FileTypeAssociation: Identifiable, Hashable, Sendable {
    var id: String { fileExtension }
    let fileExtension: String
    let uti: String
    let utiDescription: String?
    var defaultHandler: AppInfo?
    var availableHandlers: [AppInfo]
}

// MARK: - URL Scheme Association

struct URLSchemeAssociation: Identifiable, Hashable, Sendable {
    var id: String { scheme }
    let scheme: String
    let description: String?
    var defaultHandler: AppInfo?
    var availableHandlers: [AppInfo]
}

// MARK: - Recorded Operations

struct HandlerChangeRecord: Codable, Sendable {
    let target: HandlerTarget
    let oldHandler: AppInfo?
    let newHandler: AppInfo?

    var undoRequest: HandlerMutationRequest? {
        guard let old = oldHandler else { return nil }
        return HandlerMutationRequest(target: target, bundleID: old.bundleIdentifier,
            expectation: .matches(newHandler?.bundleIdentifier))
    }
}

struct ActivityLogEntry: Identifiable, Codable, Sendable {
    var id = UUID()
    var timestamp = Date()
    let action: ActionType
    let target: String
    let changes: [HandlerChangeRecord]

    enum ActionType: String, Codable, Sendable {
        case setFileTypeHandler = "Changed file handler"
        case setSchemeHandler = "Changed URL handler"
        case bulkChange = "Bulk change"
        case restore = "Restored backup"
        case createBackup = "Created backup"
    }

    var description: String {
        if changes.count == 1, let change = changes.first {
            return "\(change.target.displayName): \(change.oldHandler?.name ?? "None") → \(change.newHandler?.name ?? "None")"
        }
        switch action {
        case .createBackup: return "Created backup"
        case .restore: return "Restored \(changes.count) defaults from \(target)"
        default: return "Changed \(changes.count) defaults: \(target)"
        }
    }
    var canUndo: Bool { changes.contains { $0.undoRequest != nil } }
}

struct OperationError: Identifiable {
    let id = UUID()
    let title: String
    let message: String
}

// MARK: - External Change Detection

struct ExternalChange: Identifiable, Sendable {
    var id: HandlerTarget { handlerTarget }
    let handlerTarget: HandlerTarget
    let type: ChangeType
    let target: String
    let oldBundleID: String?
    let oldAppName: String?
    let newBundleID: String?
    let newAppName: String?

    enum ChangeType: Sendable { case fileType, urlScheme }
    var displayTarget: String { handlerTarget.displayName }
}

struct HandlerSnapshot: Codable, Sendable {
    var timestamp: Date
    var fileTypes: [String: String]
    var urlSchemes: [String: String]

    subscript(target: HandlerTarget) -> String? {
        get {
            switch target {
            case .contentType(let value): return fileTypes[value]
            case .urlScheme(let value): return urlSchemes[value]
            }
        }
        set {
            switch target {
            case .contentType(let value): fileTypes[value] = newValue
            case .urlScheme(let value): urlSchemes[value] = newValue
            }
        }
    }
}

// MARK: - Backup Data

struct BackupInfo: Identifiable, Sendable {
    var id: String { url.path }
    let url: URL
    let createdAt: Date
    let macOSVersion: String
    let fileTypesCount: Int
    let schemesCount: Int
    let fileSize: Int

    var filename: String { url.lastPathComponent }
    var formattedDate: String { createdAt.formatted(date: .abbreviated, time: .shortened) }
    var formattedSize: String { ByteCountFormatter.string(fromByteCount: Int64(fileSize), countStyle: .file) }
}

/// Version 2 uses canonical UTI identifiers as fileTypes keys.
struct AssociationsBackup: Codable, Sendable {
    let version: Int
    let createdAt: Date
    let macOSVersion: String
    let fileTypes: [String: String]
    let urlSchemes: [String: String]

    init(fileTypes: [String: String], urlSchemes: [String: String], createdAt: Date = Date()) {
        version = 2
        self.createdAt = createdAt
        macOSVersion = ProcessInfo.processInfo.operatingSystemVersionString
        self.fileTypes = fileTypes
        self.urlSchemes = urlSchemes
    }

    var mutationRequests: [HandlerMutationRequest] {
        fileTypes.map { HandlerMutationRequest(target: .contentType($0.key), bundleID: $0.value) }
        + urlSchemes.map { HandlerMutationRequest(target: .urlScheme($0.key), bundleID: $0.value) }
    }
}

// MARK: - Common Extensions

enum CommonExtensions {
    static let documents: [String] = [
        "txt", "rtf", "rtfd", "pdf",
        "doc", "docx", "odt",
        "xls", "xlsx", "ods", "csv",
        "ppt", "pptx", "odp",
        "pages", "numbers", "key"
    ]

    static let code: [String] = [
        "json", "xml", "yaml", "yml", "toml",
        "md", "markdown", "rst",
        "py", "pyw", "pyi",
        "js", "mjs", "cjs", "jsx",
        "ts", "tsx", "mts", "cts",
        "html", "htm", "xhtml",
        "css", "scss", "sass", "less",
        "swift", "m", "mm", "h",
        "kt", "kts",
        "java", "jar", "class",
        "go", "mod",
        "rs",
        "c", "cpp", "cc", "cxx", "hpp",
        "cs",
        "rb", "erb",
        "php",
        "sh", "bash", "zsh", "fish",
        "sql",
        "r", "R",
        "lua",
        "pl", "pm",
        "ex", "exs",
        "clj", "cljs",
        "scala", "sc",
        "hs", "lhs",
        "elm",
        "vue", "svelte",
        "astro",
        "prisma",
        "graphql", "gql",
        "proto",
        "dockerfile",
        "makefile", "cmake",
        "gradle",
        "tf", "tfvars"
    ]

    static let images: [String] = [
        "png", "jpg", "jpeg", "gif", "webp",
        "svg", "ico", "icns",
        "bmp", "tiff", "tif",
        "heic", "heif",
        "raw", "cr2", "nef", "arw",
        "psd", "ai", "eps",
        "sketch", "fig"
    ]

    static let video: [String] = [
        "mp4", "m4v", "mov", "avi",
        "mkv", "webm", "flv",
        "wmv", "mpg", "mpeg",
        "3gp", "ogv"
    ]

    static let audio: [String] = [
        "mp3", "m4a", "aac", "wav",
        "flac", "ogg", "wma",
        "aiff", "aif", "opus"
    ]

    static let archives: [String] = [
        "zip", "tar", "gz", "tgz",
        "bz2", "xz", "7z",
        "rar", "dmg", "iso"
    ]

    static var all: [String] {
        documents + code + images + video + audio + archives
    }
}

enum CommonURLSchemes {
    static let web: [String] = ["http", "https", "file", "ftp"]
    static let email: [String] = ["mailto"]
    static let communication: [String] = ["tel", "sms", "facetime", "facetime-audio"]
    static let developer: [String] = ["ssh", "git", "vscode", "vscode-insiders", "cursor", "zed"]
    static let apps: [String] = ["slack", "discord", "zoom", "zoommtg", "msteams"]

    static var all: [String] {
        web + email + communication + developer + apps
    }

    static func description(for scheme: String) -> String? {
        switch scheme {
        case "http", "https": return "Web Browser"
        case "mailto": return "Email Client"
        case "tel": return "Phone Calls"
        case "sms": return "Text Messages"
        case "facetime", "facetime-audio": return "FaceTime"
        case "ssh": return "SSH Client"
        case "git": return "Git Client"
        case "vscode", "vscode-insiders": return "VS Code"
        case "cursor": return "Cursor"
        case "zed": return "Zed"
        case "slack": return "Slack"
        case "discord": return "Discord"
        case "zoom", "zoommtg": return "Zoom"
        case "msteams": return "Microsoft Teams"
        case "file": return "File Browser"
        case "ftp": return "FTP Client"
        default: return nil
        }
    }
}

// MARK: - File Category

enum FileCategory: String, CaseIterable {
    case code = "Code & Text"
    case documents = "Documents"
    case images = "Images"
    case video = "Video"
    case audio = "Audio"
    case archives = "Archives"

    var extensions: [String] {
        switch self {
        case .code: return CommonExtensions.code
        case .documents: return CommonExtensions.documents
        case .images: return CommonExtensions.images
        case .video: return CommonExtensions.video
        case .audio: return CommonExtensions.audio
        case .archives: return CommonExtensions.archives
        }
    }

    var icon: String {
        switch self {
        case .code: return "curlybraces"
        case .documents: return "doc.text.fill"
        case .images: return "photo.fill"
        case .video: return "film.fill"
        case .audio: return "waveform"
        case .archives: return "archivebox.fill"
        }
    }

    static func category(for ext: String) -> FileCategory {
        if CommonExtensions.code.contains(ext) { return .code }
        if CommonExtensions.documents.contains(ext) { return .documents }
        if CommonExtensions.images.contains(ext) { return .images }
        if CommonExtensions.video.contains(ext) { return .video }
        if CommonExtensions.audio.contains(ext) { return .audio }
        return .archives
    }
}
