import SwiftUI
import Sparkle

// This view model class publishes when new updates can be checked by the user
final class CheckForUpdatesViewModel: ObservableObject {
    @Published var canCheckForUpdates = false

    init(updater: SPUUpdater) {
        updater.publisher(for: \.canCheckForUpdates)
            .assign(to: &$canCheckForUpdates)
    }
}

// This is the view for the Check for Updates menu item
struct CheckForUpdatesView: View {
    @ObservedObject private var checkForUpdatesViewModel: CheckForUpdatesViewModel
    private let updater: SPUUpdater

    init(updater: SPUUpdater) {
        self.updater = updater
        self.checkForUpdatesViewModel = CheckForUpdatesViewModel(updater: updater)
    }

    var body: some View {
        Button("Check for Updates…", action: updater.checkForUpdates)
            .disabled(!checkForUpdatesViewModel.canCheckForUpdates)
    }
}

@main
struct OpenerApp: App {
    @StateObject private var viewModel = AppViewModel()
    @State private var showingAbout = false

    // Sparkle updater controller
    private let updaterController: SPUStandardUpdaterController

    init() {
        // Create updater controller with default user driver (shows standard Sparkle UI)
        updaterController = SPUStandardUpdaterController(startingUpdater: true, updaterDelegate: nil, userDriverDelegate: nil)
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(viewModel)
                .sheet(isPresented: $showingAbout) {
                    AboutView()
                }
        }
        .windowStyle(.hiddenTitleBar)
        .defaultSize(width: 900, height: 650)
        .commands {
            CommandGroup(replacing: .newItem) {}

            // Replace default About with custom
            CommandGroup(replacing: .appInfo) {
                Button("About Opener") {
                    showingAbout = true
                }
            }

            // App menu items
            CommandGroup(after: .appSettings) {
                CheckForUpdatesView(updater: updaterController.updater)

                Divider()

                Button("Refresh") {
                    viewModel.refresh()
                }
                .keyboardShortcut("r", modifiers: .command)
            }
        }

        Settings {
            SettingsView()
                .environmentObject(viewModel)
        }
    }
}

// MARK: - About View

struct AboutView: View {
    @Environment(\.dismiss) private var dismiss

    private var appVersion: String {
        Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0"
    }

    private var buildNumber: String {
        Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "1"
    }

    var body: some View {
        VStack(spacing: 20) {
            // App Icon
            if let appIcon = NSApp.applicationIconImage {
                Image(nsImage: appIcon)
                    .resizable()
                    .frame(width: 128, height: 128)
            }

            // App Name
            Text("Opener")
                .font(.system(size: 28, weight: .bold))

            // Version
            Text("Version \(appVersion) (\(buildNumber))")
                .font(.subheadline)
                .foregroundStyle(.secondary)

            // Description
            Text("Take back control of your default apps on macOS")
                .font(.body)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)

            Divider()
                .frame(width: 200)

            // Links
            VStack(spacing: 8) {
                Link(destination: URL(string: "https://github.com/bernaferrari/Opener")!) {
                    Label("View on GitHub", systemImage: "link")
                }

                Link(destination: URL(string: "https://github.com/bernaferrari/Opener/issues")!) {
                    Label("Report an Issue", systemImage: "exclamationmark.bubble")
                }
            }
            .font(.subheadline)

            Spacer()

            // Copyright
            Text("Made with care for the macOS community")
                .font(.caption)
                .foregroundStyle(.tertiary)

            Button("Close") {
                dismiss()
            }
            .keyboardShortcut(.escape, modifiers: [])
        }
        .padding(30)
        .frame(width: 340, height: 420)
    }
}

