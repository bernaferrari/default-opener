import SwiftUI
import AppKit

struct SettingsView: View {
    @EnvironmentObject var viewModel: AppViewModel
    @State private var isCheckingUpdate = false

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
                if let update = viewModel.updateInfo, update.isUpdateAvailable {
                    HStack {
                        Label("Version \(update.latestVersion) available", systemImage: "arrow.down.circle.fill")
                            .foregroundStyle(.blue)
                        Spacer()
                        Button("Download") {
                            NSWorkspace.shared.open(update.releaseURL)
                        }
                    }
                } else {
                    HStack {
                        Text("You're up to date")
                            .foregroundStyle(.secondary)
                        Spacer()
                        Button {
                            isCheckingUpdate = true
                            viewModel.checkForUpdates()
                            DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                                isCheckingUpdate = false
                            }
                        } label: {
                            if isCheckingUpdate {
                                ProgressView()
                                    .scaleEffect(0.7)
                            } else {
                                Text("Check for Updates")
                            }
                        }
                        .disabled(isCheckingUpdate)
                    }
                }
            }
        }
        .formStyle(.grouped)
        .frame(width: 450, height: 280)
    }
}

#Preview {
    SettingsView()
        .environmentObject(AppViewModel())
}
