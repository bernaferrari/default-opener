import ArgumentParser
import Foundation
import OpenerCore

// MARK: - ANSI Colors

enum ANSIColor: String {
    case reset = "\u{001B}[0m"
    case bold = "\u{001B}[1m"
    case dim = "\u{001B}[2m"

    case red = "\u{001B}[31m"
    case green = "\u{001B}[32m"
    case yellow = "\u{001B}[33m"
    case blue = "\u{001B}[34m"
    case magenta = "\u{001B}[35m"
    case cyan = "\u{001B}[36m"
    case white = "\u{001B}[37m"
    case gray = "\u{001B}[90m"
}

func colored(_ text: String, _ color: ANSIColor) -> String {
    "\(color.rawValue)\(text)\(ANSIColor.reset.rawValue)"
}

func bold(_ text: String) -> String {
    "\(ANSIColor.bold.rawValue)\(text)\(ANSIColor.reset.rawValue)"
}

func dim(_ text: String) -> String {
    "\(ANSIColor.dim.rawValue)\(text)\(ANSIColor.reset.rawValue)"
}

// MARK: - Main Command

@main
struct Opener: ParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "opener",
        abstract: "Manage default applications for file types and URL schemes on macOS",
        version: "1.0.0",
        subcommands: [
            Get.self,
            Set.self,
            List.self,
            Backup.self,
            Restore.self,
            Backups.self,
            Apps.self,
        ],
        defaultSubcommand: List.self
    )
}

// MARK: - Get Command

struct Get: ParsableCommand {
    static let configuration = CommandConfiguration(
        abstract: "Get the default application for a file extension or URL scheme"
    )

    @Argument(help: "File extension (e.g., .json, txt) or URL scheme (e.g., https, mailto)")
    var identifier: String

    @Flag(name: .shortAndLong, help: "Show all available handlers, not just the default")
    var all = false

    @Flag(name: .shortAndLong, help: "Output as JSON")
    var json = false

    func run() throws {
        let manager = LaunchServicesManager.shared

        // Determine if it's a file extension or URL scheme
        let isExtension = identifier.contains(".") ||
            CommonExtensions.all.contains(identifier.lowercased())

        if isExtension {
            let association = try manager.getFileTypeAssociation(forExtension: identifier)

            if json {
                printJSON(association)
            } else {
                printFileTypeAssociation(association, showAll: all)
            }
        } else {
            let association = try manager.getURLSchemeAssociation(forScheme: identifier)

            if json {
                printJSON(association)
            } else {
                printURLSchemeAssociation(association, showAll: all)
            }
        }
    }

    private func printFileTypeAssociation(_ assoc: FileTypeAssociation, showAll: Bool) {
        let isDynamicUTI = assoc.uti.hasPrefix("dyn.")

        print()
        print("  \(bold("Extension:"))  .\(colored(assoc.fileExtension, .cyan))")

        // Hide ugly dynamic UTIs from user
        if !isDynamicUTI {
            print("  \(bold("UTI:"))        \(dim(assoc.uti))")
        }

        if let desc = assoc.utiDescription {
            print("  \(bold("Type:"))       \(desc)")
        } else if isDynamicUTI {
            print("  \(bold("Type:"))       \(dim("Unregistered"))")
        }

        print()

        if let handler = assoc.defaultHandler {
            print("  \(bold("Default:"))    \(colored(handler.name, .green))")
            print("              \(dim(handler.bundleIdentifier))")
        } else {
            print("  \(bold("Default:"))    \(colored("(none)", .yellow))")
        }

        if showAll && !assoc.availableHandlers.isEmpty {
            print()
            print("  \(bold("Available handlers:"))")
            for handler in assoc.availableHandlers {
                let isDefault = handler.bundleIdentifier == assoc.defaultHandler?.bundleIdentifier
                let marker = isDefault ? colored("*", .green) : " "
                print("    \(marker) \(handler.name)")
                print("      \(dim(handler.bundleIdentifier))")
            }
        }

        print()
    }

    private func printURLSchemeAssociation(_ assoc: URLSchemeAssociation, showAll: Bool) {
        print()
        print("  \(bold("Scheme:"))     \(colored(assoc.scheme, .cyan))://")

        if let desc = assoc.description {
            print("  \(bold("Type:"))       \(desc)")
        }

        print()

        if let handler = assoc.defaultHandler {
            print("  \(bold("Default:"))    \(colored(handler.name, .green))")
            print("              \(dim(handler.bundleIdentifier))")
        } else {
            print("  \(bold("Default:"))    \(colored("(none)", .yellow))")
        }

        if showAll && !assoc.availableHandlers.isEmpty {
            print()
            print("  \(bold("Available handlers:"))")
            for handler in assoc.availableHandlers {
                let isDefault = handler.bundleIdentifier == assoc.defaultHandler?.bundleIdentifier
                let marker = isDefault ? colored("*", .green) : " "
                print("    \(marker) \(handler.name)")
                print("      \(dim(handler.bundleIdentifier))")
            }
        }

        print()
    }

    private func printJSON<T: Encodable>(_ value: T) {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        if let data = try? encoder.encode(value),
           let string = String(data: data, encoding: .utf8) {
            print(string)
        }
    }
}

// MARK: - Set Command

struct Set: ParsableCommand {
    static let configuration = CommandConfiguration(
        abstract: "Set the default application for a file extension or URL scheme"
    )

    @Argument(help: "File extension (e.g., .json) or URL scheme (e.g., https)")
    var identifier: String

    @Argument(help: "Bundle identifier or app name (e.g., com.microsoft.VSCode or 'Visual Studio Code')")
    var application: String

    func run() throws {
        let manager = LaunchServicesManager.shared

        // Resolve app name to bundle ID if needed
        var bundleID = application
        if !application.contains(".") {
            // It's probably an app name, not a bundle ID
            if let resolved = manager.getBundleID(forAppName: application) {
                bundleID = resolved
            } else {
                throw OpenerError.appNotFound(application)
            }
        }

        // Determine if it's a file extension or URL scheme
        let isExtension = identifier.contains(".") ||
            CommonExtensions.all.contains(identifier.lowercased())

        if isExtension {
            let ext = identifier.hasPrefix(".") ? String(identifier.dropFirst()) : identifier
            try manager.setDefaultHandler(forExtension: ext, bundleID: bundleID)

            // Verify and show result
            if let handler = try? manager.getDefaultHandler(forExtension: ext) {
                print()
                print("  \(colored("✓", .green)) Set default for \(colored(".\(ext)", .cyan)) to \(colored(handler.name, .green))")
                print("    \(dim(handler.bundleIdentifier))")
                print()
            }
        } else {
            let scheme = identifier.replacingOccurrences(of: "://", with: "")
            try manager.setDefaultHandler(forScheme: scheme, bundleID: bundleID)

            // Verify and show result
            if let handler = try? manager.getDefaultHandler(forScheme: scheme) {
                print()
                print("  \(colored("✓", .green)) Set default for \(colored("\(scheme)://", .cyan)) to \(colored(handler.name, .green))")
                print("    \(dim(handler.bundleIdentifier))")
                print()
            }
        }
    }
}

// MARK: - List Command

struct List: ParsableCommand {
    static let configuration = CommandConfiguration(
        abstract: "List default applications for file extensions or URL schemes"
    )

    @Argument(help: "What to list: 'extensions' (or 'ext'), 'schemes' (or 'url'), or 'all'")
    var type: ListType = .all

    @Option(name: .shortAndLong, help: "Filter by category: documents, code, images, video, audio, archives, web, email, dev")
    var category: String?

    @Flag(name: .shortAndLong, help: "Output as JSON")
    var json = false

    enum ListType: String, ExpressibleByArgument, CaseIterable {
        case extensions, ext
        case schemes, url
        case all

        var isExtensions: Bool {
            self == .extensions || self == .ext
        }

        var isSchemes: Bool {
            self == .schemes || self == .url
        }
    }

    func run() throws {
        let manager = LaunchServicesManager.shared

        let showExtensions = type == .all || type.isExtensions
        let showSchemes = type == .all || type.isSchemes

        // Get extensions based on category filter
        let extensions: [String]
        if let cat = category?.lowercased() {
            switch cat {
            case "documents", "doc", "docs":
                extensions = CommonExtensions.documents
            case "code", "programming", "dev":
                extensions = CommonExtensions.code
            case "images", "img", "image":
                extensions = CommonExtensions.images
            case "video", "videos":
                extensions = CommonExtensions.video
            case "audio", "music", "sound":
                extensions = CommonExtensions.audio
            case "archives", "archive", "zip":
                extensions = CommonExtensions.archives
            default:
                extensions = CommonExtensions.all
            }
        } else {
            extensions = CommonExtensions.all
        }

        // Get schemes based on category filter
        let schemes: [String]
        if let cat = category?.lowercased() {
            switch cat {
            case "web", "browser":
                schemes = CommonURLSchemes.web
            case "email", "mail":
                schemes = CommonURLSchemes.email
            case "communication", "comm":
                schemes = CommonURLSchemes.communication
            case "dev", "developer":
                schemes = CommonURLSchemes.developer
            case "apps":
                schemes = CommonURLSchemes.apps
            default:
                schemes = CommonURLSchemes.all
            }
        } else {
            schemes = CommonURLSchemes.all
        }

        if json {
            var output: [String: Any] = [:]

            if showExtensions {
                let fileTypes = manager.getAllFileTypeAssociations(extensions: extensions)
                output["fileTypes"] = fileTypes.map { assoc -> [String: Any] in
                    [
                        "extension": assoc.fileExtension,
                        "uti": assoc.uti,
                        "handler": assoc.defaultHandler?.bundleIdentifier as Any
                    ]
                }
            }

            if showSchemes {
                let urlSchemes = manager.getAllURLSchemeAssociations(schemes: schemes)
                output["urlSchemes"] = urlSchemes.map { assoc -> [String: Any] in
                    [
                        "scheme": assoc.scheme,
                        "handler": assoc.defaultHandler?.bundleIdentifier as Any
                    ]
                }
            }

            if let data = try? JSONSerialization.data(withJSONObject: output, options: [.prettyPrinted, .sortedKeys]),
               let string = String(data: data, encoding: .utf8) {
                print(string)
            }
        } else {
            if showExtensions {
                let fileTypes = manager.getAllFileTypeAssociations(extensions: extensions)
                printFileTypesTable(fileTypes)
            }

            if showSchemes {
                let urlSchemes = manager.getAllURLSchemeAssociations(schemes: schemes)
                printURLSchemesTable(urlSchemes)
            }
        }
    }

    private func printFileTypesTable(_ associations: [FileTypeAssociation]) {
        print()
        print(bold("  File Extensions"))
        print(dim("  ─────────────────────────────────────────────────────────────────"))
        print()

        // Calculate column widths
        let extWidth = 10
        let appWidth = 30

        // Header
        let header = "  EXT         DEFAULT APP                     BUNDLE ID"
        print(dim(header))
        print()

        for assoc in associations.sorted(by: { $0.fileExtension < $1.fileExtension }) {
            let ext = ".\(assoc.fileExtension)"
            let app = assoc.defaultHandler?.name ?? "-"
            let bundle = assoc.defaultHandler?.bundleIdentifier ?? ""

            let extCol = colored(ext.padding(toLength: extWidth, withPad: " ", startingAt: 0), .cyan)
            let appCol = app.padding(toLength: appWidth, withPad: " ", startingAt: 0)
            let bundleCol = dim(bundle)

            print("  \(extCol)  \(appCol)  \(bundleCol)")
        }

        print()
        print(dim("  Total: \(associations.count) file types"))
        print()
    }

    private func printURLSchemesTable(_ associations: [URLSchemeAssociation]) {
        print()
        print(bold("  URL Schemes"))
        print(dim("  ─────────────────────────────────────────────────────────────────"))
        print()

        let schemeWidth = 15
        let appWidth = 30

        let header = "  SCHEME           DEFAULT APP                     BUNDLE ID"
        print(dim(header))
        print()

        for assoc in associations.sorted(by: { $0.scheme < $1.scheme }) {
            let scheme = "\(assoc.scheme)://"
            let app = assoc.defaultHandler?.name ?? "-"
            let bundle = assoc.defaultHandler?.bundleIdentifier ?? ""

            let schemeCol = colored(scheme.padding(toLength: schemeWidth, withPad: " ", startingAt: 0), .cyan)
            let appCol = app.padding(toLength: appWidth, withPad: " ", startingAt: 0)
            let bundleCol = dim(bundle)

            print("  \(schemeCol)  \(appCol)  \(bundleCol)")
        }

        print()
        print(dim("  Total: \(associations.count) URL schemes"))
        print()
    }
}

// MARK: - Backup Command

struct Backup: ParsableCommand {
    static let configuration = CommandConfiguration(
        abstract: "Create a backup of current associations"
    )

    @Option(name: .shortAndLong, help: "Output file path (default: auto-generated in backup directory)")
    var output: String?

    func run() throws {
        let backupManager = BackupManager.shared

        let url: URL
        if let outputPath = output {
            url = URL(fileURLWithPath: outputPath)
            try backupManager.createBackup(to: url)
        } else {
            url = try backupManager.createBackup()
        }

        print()
        print("  \(colored("✓", .green)) Backup created successfully")
        print("    \(dim(url.path))")
        print()
    }
}

// MARK: - Restore Command

struct Restore: ParsableCommand {
    static let configuration = CommandConfiguration(
        abstract: "Restore associations from a backup"
    )

    @Argument(help: "Backup file path, or 'latest' to restore the most recent backup")
    var file: String

    @Flag(name: .long, help: "Preview changes without applying them")
    var dryRun = false

    @Flag(name: .shortAndLong, help: "Skip confirmation prompt")
    var force = false

    func run() throws {
        let backupManager = BackupManager.shared

        let url: URL
        if file.lowercased() == "latest" {
            guard let latest = try backupManager.listBackups().first else {
                throw BackupError.noBackupsFound
            }
            url = latest.url
            print()
            print("  Using latest backup: \(dim(latest.filename))")
        } else {
            url = URL(fileURLWithPath: file)
        }

        // Preview changes
        let preview = try backupManager.previewRestore(from: url)

        if !preview.hasChanges {
            print()
            print("  \(colored("✓", .green)) All associations are already up to date")
            print()
            return
        }

        print()
        print(bold("  Changes to apply:"))
        print()

        for change in preview.fileTypeChanges {
            print("    .\(colored(change.identifier, .cyan)): \(change.currentAppName) → \(colored(change.newAppName, .green))")
        }

        for change in preview.schemeChanges {
            print("    \(colored(change.identifier, .cyan))://: \(change.currentAppName) → \(colored(change.newAppName, .green))")
        }

        print()
        print(dim("  Total: \(preview.totalChanges) changes"))
        print()

        if dryRun {
            print("  \(colored("!", .yellow)) Dry run - no changes applied")
            print()
            return
        }

        if !force {
            print("  Apply these changes? [y/N] ", terminator: "")
            guard let response = readLine()?.lowercased(), response == "y" || response == "yes" else {
                print()
                print("  Cancelled")
                print()
                return
            }
        }

        let result = try backupManager.restore(from: url)

        print()
        if result.isSuccess {
            print("  \(colored("✓", .green)) Restored \(result.totalRestored) associations successfully")
        } else {
            print("  \(colored("!", .yellow)) Restored \(result.totalRestored) associations, \(result.totalFailed) failed")

            for (ext, error) in result.failedFileTypes {
                print("    \(colored("✗", .red)) .\(ext): \(error)")
            }

            for (scheme, error) in result.failedSchemes {
                print("    \(colored("✗", .red)) \(scheme)://: \(error)")
            }
        }
        print()
    }
}

// MARK: - Backups Command

struct Backups: ParsableCommand {
    static let configuration = CommandConfiguration(
        abstract: "List all available backups"
    )

    @Flag(name: .shortAndLong, help: "Show backup directory path")
    var path = false

    func run() throws {
        let backupManager = BackupManager.shared

        if path {
            print(backupManager.getBackupDirectory().path)
            return
        }

        let backups = try backupManager.listBackups()

        if backups.isEmpty {
            print()
            print("  No backups found")
            print()
            print(dim("  Create one with: opener backup"))
            print()
            return
        }

        print()
        print(bold("  Available Backups"))
        print(dim("  ─────────────────────────────────────────────────────────────────"))
        print()

        for (index, backup) in backups.enumerated() {
            let marker = index == 0 ? colored("*", .green) : " "
            let latest = index == 0 ? colored(" (latest)", .green) : ""

            print("  \(marker) \(backup.formattedDate)\(latest)")
            print("      \(dim(backup.filename))")
            print("      \(dim("\(backup.fileTypesCount) file types, \(backup.schemesCount) URL schemes, \(backup.formattedSize)"))")
            print()
        }

        print(dim("  Backup directory: \(backupManager.getBackupDirectory().path)"))
        print()
    }
}

// MARK: - Apps Command

struct Apps: ParsableCommand {
    static let configuration = CommandConfiguration(
        abstract: "List installed applications and their bundle IDs"
    )

    @Argument(help: "Search filter (optional)")
    var filter: String?

    func run() throws {
        let manager = LaunchServicesManager.shared
        var apps = manager.getInstalledApps()

        if let filter = filter?.lowercased() {
            apps = apps.filter {
                $0.name.lowercased().contains(filter) ||
                $0.bundleIdentifier.lowercased().contains(filter)
            }
        }

        print()

        if apps.isEmpty {
            print("  No applications found")
            print()
            return
        }

        let nameWidth = min(30, apps.map { $0.name.count }.max() ?? 30)

        for app in apps {
            let name = app.name.padding(toLength: nameWidth, withPad: " ", startingAt: 0)
            print("  \(name)  \(dim(app.bundleIdentifier))")
        }

        print()
        print(dim("  Total: \(apps.count) applications"))
        print()
    }
}
