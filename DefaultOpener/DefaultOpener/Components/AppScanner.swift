import Foundation
import AppKit

enum AppScanner {
    static func findAllApps() async -> [AppInfo] {
        await withCheckedContinuation { continuation in
            DispatchQueue.global(qos: .userInitiated).async {
                var apps: [AppInfo] = []
                let searchPaths = [
                    "/Applications",
                    "/System/Applications",
                    "/System/Applications/Utilities",
                    NSHomeDirectory() + "/Applications"
                ]

                let fileManager = FileManager.default

                for searchPath in searchPaths {
                    guard let enumerator = fileManager.enumerator(
                        at: URL(fileURLWithPath: searchPath),
                        includingPropertiesForKeys: nil,
                        options: [.skipsHiddenFiles, .skipsPackageDescendants]
                    ) else { continue }

                    for case let fileURL as URL in enumerator {
                        if fileURL.pathExtension == "app",
                           let appInfo = AppInfo(url: fileURL) {
                            apps.append(appInfo)
                        }
                    }
                }

                let sorted = apps.sorted { $0.name.lowercased() < $1.name.lowercased() }
                continuation.resume(returning: sorted)
            }
        }
    }
}
