import SwiftUI
import AppKit
import Sparkle

struct SettingsView: View {
    let updater: SPUUpdater

    private var appVersion: String {
        Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "Unknown"
    }

    private var buildNumber: String {
        Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? ""
    }

    var body: some View {
        Form {
            Section {
                Text("Default Opener manages your default applications for file types and URL schemes.")
            }

            Section("About") {
                LabeledContent("Version", value: "\(appVersion) (\(buildNumber))")
                LabeledContent("macOS", value: ProcessInfo.processInfo.operatingSystemVersionString)
            }

            Section("Updates") {
                CheckForUpdatesView(updater: updater)
                Text("Check for updates securely with the built-in updater.")
                    .foregroundStyle(.secondary)
            }
        }
        .formStyle(.grouped)
        .frame(width: 450, height: 280)
    }
}
