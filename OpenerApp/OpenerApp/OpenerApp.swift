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
    @Environment(\.openWindow) private var openWindow

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
        }
        .windowStyle(.hiddenTitleBar)
        .defaultSize(width: 900, height: 650)
        .commands {
            CommandGroup(replacing: .newItem) {}

            // Replace default About with custom
            CommandGroup(replacing: .appInfo) {
                Button("About Opener") {
                    openWindow(id: "about")
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

        // About Window
        Window("About Opener", id: "about") {
            AboutView()
        }
        .windowStyle(.hiddenTitleBar)
        .windowResizability(.contentSize)
        .defaultPosition(.center)

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

    private var currentYear: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy"
        return formatter.string(from: Date())
    }

    var body: some View {
        VStack(spacing: 0) {
            Spacer()
                .frame(height: 24)

            // App Icon
            if let appIcon = NSApp.applicationIconImage {
                Image(nsImage: appIcon)
                    .resizable()
                    .interpolation(.high)
                    .frame(width: 128, height: 128)
                    .shadow(color: .black.opacity(0.1), radius: 8, y: 4)
            }

            Spacer()
                .frame(height: 16)

            // App Name
            Text("Opener")
                .font(.system(size: 24, weight: .bold, design: .rounded))

            Spacer()
                .frame(height: 4)

            // Version
            Text("Version \(appVersion) (\(buildNumber))")
                .font(.system(size: 11))
                .foregroundStyle(.secondary)

            Spacer()
                .frame(height: 20)

            // Description
            Text("Take back control of your\ndefault apps on macOS")
                .font(.system(size: 12))
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .lineSpacing(2)

            Spacer()
                .frame(height: 24)

            // Links
            HStack(spacing: 16) {
                Link(destination: URL(string: "https://github.com/bernaferrari/Opener")!) {
                    HStack(spacing: 4) {
                        Image(systemName: "chevron.left.forwardslash.chevron.right")
                        Text("Source")
                    }
                    .font(.system(size: 11, weight: .medium))
                }
                .buttonStyle(.plain)

                Link(destination: URL(string: "https://github.com/bernaferrari/Opener/issues")!) {
                    HStack(spacing: 4) {
                        Image(systemName: "ladybug")
                        Text("Report Bug")
                    }
                    .font(.system(size: 11, weight: .medium))
                }
                .buttonStyle(.plain)
            }
            .foregroundStyle(.blue)

            Spacer()

            // Copyright
            VStack(spacing: 2) {
                Text("Copyright © \(currentYear) Bernardo Ferrari")
                    .font(.system(size: 10))
                    .foregroundStyle(.tertiary)
                Text("All rights reserved.")
                    .font(.system(size: 10))
                    .foregroundStyle(.tertiary)
            }

            Spacer()
                .frame(height: 16)
        }
        .frame(width: 300, height: 360)
        .background(.regularMaterial)
    }
}

