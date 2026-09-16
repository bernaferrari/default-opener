import Foundation
import AppKit

enum AppScanner {
    /// Match picker row identity and prefer the standard installation over duplicate copies.
    static func deduplicateApps(_ apps: [AppInfo]) -> [AppInfo] {
        func rank(_ path: String) -> Int {
            if path.hasPrefix("/Applications/") { return 0 }
            if path.hasPrefix("/System/Applications/") { return 1 }
            return 2
        }
        let candidates = apps.sorted {
            let lhsRank = rank($0.path)
            let rhsRank = rank($1.path)
            return lhsRank == rhsRank ? $0.path < $1.path : lhsRank < rhsRank
        }
        var seen = Set<String>()
        return candidates.filter { seen.insert($0.bundleIdentifier).inserted }.sorted {
            let order = $0.name.localizedStandardCompare($1.name)
            return order == .orderedSame ? $0.bundleIdentifier < $1.bundleIdentifier : order == .orderedAscending
        }
    }

    static func findAllApps() async -> [AppInfo] {
        await withCheckedContinuation { continuation in
            DispatchQueue.global(qos: .userInitiated).async {
                var apps: [AppInfo] = []
                let searchPaths = [
                    "/Applications",
                    "/System/Applications",
                    NSHomeDirectory() + "/Applications"
                ]
                for searchPath in searchPaths {
                    guard let enumerator = FileManager.default.enumerator(
                        at: URL(fileURLWithPath: searchPath),
                        includingPropertiesForKeys: nil,
                        options: [.skipsHiddenFiles, .skipsPackageDescendants]
                    ) else { continue }
                    for case let fileURL as URL in enumerator {
                        if fileURL.pathExtension == "app", let appInfo = AppInfo(url: fileURL) {
                            apps.append(appInfo)
                        }
                    }
                }
                continuation.resume(returning: deduplicateApps(apps))
            }
        }
    }
}
