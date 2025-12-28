import Foundation
import UniformTypeIdentifiers

// MARK: - Application Info

/// Represents an application that can handle files or URLs
public struct AppInfo: Codable, Hashable, Identifiable, Sendable {
    public var id: String { bundleIdentifier }

    public let bundleIdentifier: String
    public let name: String
    public let path: String

    public init(bundleIdentifier: String, name: String, path: String) {
        self.bundleIdentifier = bundleIdentifier
        self.name = name
        self.path = path
    }

    public init?(url: URL) {
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
}

// MARK: - File Type Association

/// Represents a file extension and its associated applications
public struct FileTypeAssociation: Codable, Identifiable, Sendable {
    public var id: String { fileExtension }

    public let fileExtension: String
    public let uti: String
    public let utiDescription: String?
    public var defaultHandler: AppInfo?
    public var availableHandlers: [AppInfo]

    public init(
        fileExtension: String,
        uti: String,
        utiDescription: String? = nil,
        defaultHandler: AppInfo? = nil,
        availableHandlers: [AppInfo] = []
    ) {
        self.fileExtension = fileExtension
        self.uti = uti
        self.utiDescription = utiDescription
        self.defaultHandler = defaultHandler
        self.availableHandlers = availableHandlers
    }
}

// MARK: - URL Scheme Association

/// Represents a URL scheme and its associated applications
public struct URLSchemeAssociation: Codable, Identifiable, Sendable {
    public var id: String { scheme }

    public let scheme: String
    public let description: String?
    public var defaultHandler: AppInfo?
    public var availableHandlers: [AppInfo]

    public init(
        scheme: String,
        description: String? = nil,
        defaultHandler: AppInfo? = nil,
        availableHandlers: [AppInfo] = []
    ) {
        self.scheme = scheme
        self.description = description
        self.defaultHandler = defaultHandler
        self.availableHandlers = availableHandlers
    }
}

// MARK: - Backup

/// Complete backup of all file type and URL scheme associations
public struct AssociationsBackup: Codable, Sendable {
    public let version: Int
    public let createdAt: Date
    public let macOSVersion: String
    public let fileTypes: [String: String]  // extension -> bundleID
    public let urlSchemes: [String: String] // scheme -> bundleID

    public init(
        fileTypes: [String: String],
        urlSchemes: [String: String]
    ) {
        self.version = 1
        self.createdAt = Date()
        self.macOSVersion = ProcessInfo.processInfo.operatingSystemVersionString
        self.fileTypes = fileTypes
        self.urlSchemes = urlSchemes
    }
}

// MARK: - Common Extensions & Schemes

public enum CommonExtensions {
    public static let documents: [String] = [
        "txt", "rtf", "rtfd", "pdf",
        "doc", "docx", "odt",
        "xls", "xlsx", "ods", "csv",
        "ppt", "pptx", "odp",
        "pages", "numbers", "key"
    ]

    public static let code: [String] = [
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

    public static let images: [String] = [
        "png", "jpg", "jpeg", "gif", "webp",
        "svg", "ico", "icns",
        "bmp", "tiff", "tif",
        "heic", "heif",
        "raw", "cr2", "nef", "arw",
        "psd", "ai", "eps",
        "sketch", "fig"
    ]

    public static let video: [String] = [
        "mp4", "m4v", "mov", "avi",
        "mkv", "webm", "flv",
        "wmv", "mpg", "mpeg",
        "3gp", "ogv"
    ]

    public static let audio: [String] = [
        "mp3", "m4a", "aac", "wav",
        "flac", "ogg", "wma",
        "aiff", "aif", "opus"
    ]

    public static let archives: [String] = [
        "zip", "tar", "gz", "tgz",
        "bz2", "xz", "7z",
        "rar", "dmg", "iso"
    ]

    public static var all: [String] {
        documents + code + images + video + audio + archives
    }
}

public enum CommonURLSchemes {
    public static let web: [String] = ["http", "https", "file", "ftp"]
    public static let email: [String] = ["mailto"]
    public static let communication: [String] = ["tel", "sms", "facetime", "facetime-audio"]
    public static let developer: [String] = ["ssh", "git", "vscode", "vscode-insiders", "cursor", "zed"]
    public static let apps: [String] = ["slack", "discord", "zoom", "zoommtg", "msteams"]

    public static var all: [String] {
        web + email + communication + developer + apps
    }

    public static func description(for scheme: String) -> String? {
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
