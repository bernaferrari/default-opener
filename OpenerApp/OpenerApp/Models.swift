import SwiftUI
import AppKit

// MARK: - App Info Model

struct AppInfo: Identifiable, Hashable {
    var id: String { bundleIdentifier }
    let bundleIdentifier: String
    let name: String
    let path: String
    let icon: NSImage?

    init(bundleIdentifier: String, name: String, path: String) {
        self.bundleIdentifier = bundleIdentifier
        self.name = name
        self.path = path
        self.icon = NSWorkspace.shared.icon(forFile: path)
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
        self.icon = NSWorkspace.shared.icon(forFile: url.path)
    }
}

// MARK: - File Type Association

struct FileTypeAssociation: Identifiable, Hashable {
    var id: String { fileExtension }
    let fileExtension: String
    let uti: String
    let utiDescription: String?
    var defaultHandler: AppInfo?
    var availableHandlers: [AppInfo]
}

// MARK: - URL Scheme Association

struct URLSchemeAssociation: Identifiable, Hashable {
    var id: String { scheme }
    let scheme: String
    let description: String?
    var defaultHandler: AppInfo?
    var availableHandlers: [AppInfo]
}

// MARK: - Activity Log Entry

struct ActivityLogEntry: Identifiable, Codable {
    let id: UUID
    let timestamp: Date
    let action: ActionType
    let target: String
    let oldValue: String?
    let newValue: String?
    let oldBundleID: String?
    let newBundleID: String?
    let bulkDetails: [BulkChangeDetail]?

    struct BulkChangeDetail: Codable {
        let fileExtension: String
        let oldBundleID: String?
        let oldAppName: String?
    }

    enum ActionType: String, Codable {
        case setFileTypeHandler = "Changed file handler"
        case setSchemeHandler = "Changed URL handler"
        case bulkChange = "Bulk change"
        case restore = "Restored backup"
        case createBackup = "Created backup"
    }

    init(timestamp: Date, action: ActionType, target: String, oldValue: String?, newValue: String?, oldBundleID: String? = nil, newBundleID: String? = nil, bulkDetails: [BulkChangeDetail]? = nil) {
        self.id = UUID()
        self.timestamp = timestamp
        self.action = action
        self.target = target
        self.oldValue = oldValue
        self.newValue = newValue
        self.oldBundleID = oldBundleID
        self.newBundleID = newBundleID
        self.bulkDetails = bulkDetails
    }

    var description: String {
        switch action {
        case .setFileTypeHandler:
            let from = oldValue ?? "none"
            let to = newValue ?? "none"
            return ".\(target): \(from) → \(to)"
        case .setSchemeHandler:
            let from = oldValue ?? "none"
            let to = newValue ?? "none"
            return "\(target)://: \(from) → \(to)"
        case .bulkChange:
            return "\(target) file types → \(newValue ?? "unknown")"
        case .restore:
            return "Restored from \(target)"
        case .createBackup:
            return "Created backup"
        }
    }

    var canUndo: Bool {
        switch action {
        case .setFileTypeHandler, .setSchemeHandler:
            return oldValue != nil
        case .bulkChange:
            guard let details = bulkDetails else { return false }
            return !details.isEmpty
        default:
            return false
        }
    }
}

// MARK: - Update Info

struct UpdateInfo {
    let currentVersion: String
    let latestVersion: String
    let releaseURL: URL
    let releaseNotes: String?

    var isUpdateAvailable: Bool {
        latestVersion.compare(currentVersion, options: .numeric) == .orderedDescending
    }
}

// MARK: - External Change Detection

struct ExternalChange: Identifiable {
    let id = UUID()
    let type: ChangeType
    let target: String
    let oldBundleID: String?
    let oldAppName: String?
    let newBundleID: String?
    let newAppName: String?

    enum ChangeType {
        case fileType
        case urlScheme
    }

    var displayTarget: String {
        switch type {
        case .fileType: return ".\(target)"
        case .urlScheme: return "\(target)://"
        }
    }
}

struct HandlerSnapshot: Codable {
    let timestamp: Date
    let fileTypes: [String: String]
    let urlSchemes: [String: String]
}

// MARK: - Backup Info

struct BackupInfo: Identifiable {
    var id: String { url.path }
    let url: URL
    let createdAt: Date
    let macOSVersion: String
    let fileTypesCount: Int
    let schemesCount: Int
    let fileSize: Int

    var filename: String { url.lastPathComponent }

    var formattedDate: String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter.string(from: createdAt)
    }

    var formattedSize: String {
        ByteCountFormatter.string(fromByteCount: Int64(fileSize), countStyle: .file)
    }
}

struct AssociationsBackup: Codable {
    let version: Int
    let createdAt: Date
    let macOSVersion: String
    let fileTypes: [String: String]
    let urlSchemes: [String: String]

    init(fileTypes: [String: String], urlSchemes: [String: String]) {
        self.version = 1
        self.createdAt = Date()
        self.macOSVersion = ProcessInfo.processInfo.operatingSystemVersionString
        self.fileTypes = fileTypes
        self.urlSchemes = urlSchemes
    }
}

struct RestoreResult {
    var restoredFileTypes: [String] = []
    var restoredSchemes: [String] = []
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
