import SwiftUI
import AppKit

struct AppPickerSheet: View {
    enum Mode {
        case single(fileExtension: String, currentHandler: AppInfo?, onSelect: (String) -> Void)
        case bulk(extensions: [String], currentApp: AppInfo?, onComplete: () -> Void)
    }

    let mode: Mode
    @EnvironmentObject var viewModel: AppViewModel
    @Environment(\.dismiss) private var dismiss
    @State private var searchText = ""
    @State private var allApps: [AppInfo] = []
    @State private var isLoading = true
    @State private var selectedApp: AppInfo?
    @FocusState private var isSearchFocused: Bool

    // Popular code editors that users commonly want
    static let popularEditorBundleIDs: [String] = [
        "com.microsoft.VSCode",
        "com.microsoft.VSCodeInsiders",
        "com.sublimetext.4",
        "com.sublimetext.3",
        "com.apple.dt.Xcode",
        "dev.zed.Zed",
        "com.todesktop.230313mzl4w4u92", // Cursor
        "com.exafunction.windsurf",
        "com.jetbrains.intellij",
        "com.jetbrains.WebStorm",
        "com.jetbrains.PyCharm",
        "com.github.atom",
        "org.vim.MacVim",
        "com.barebones.bbedit",
        "com.coteditor.CotEditor",
        "com.panic.Nova",
        "abnerworks.Typora",
        "com.apple.TextEdit",
        "com.google.android.studio",
    ]

    private var title: String {
        switch mode {
        case .single(let ext, _, _):
            return "Choose App for .\(ext)"
        case .bulk(let exts, let currentApp, _):
            if let app = currentApp {
                return "Replace \(app.name)"
            }
            return "\(exts.count) File Types"
        }
    }

    private var subtitle: String {
        switch mode {
        case .single:
            return "Select any app to open this file type"
        case .bulk(let exts, let currentApp, _):
            if currentApp != nil {
                return "\(exts.count) file types will be changed"
            }
            return "Choose the default app for selected types"
        }
    }

    private var currentHandler: AppInfo? {
        switch mode {
        case .single(_, let handler, _): return handler
        case .bulk(_, let app, _): return app
        }
    }

    private var extensions: [String] {
        switch mode {
        case .single(let ext, _, _): return [ext]
        case .bulk(let exts, _, _): return exts
        }
    }

    private var isBulkMode: Bool {
        if case .bulk = mode { return true }
        return false
    }

    // Get handlers registered for the selected file types
    private var registeredHandlers: [AppInfo] {
        var seen = Set<String>()
        var apps: [AppInfo] = []

        for ext in extensions {
            if let fileType = viewModel.fileTypes.first(where: { $0.fileExtension == ext }) {
                for handler in fileType.availableHandlers {
                    if !seen.contains(handler.bundleIdentifier) {
                        seen.insert(handler.bundleIdentifier)
                        apps.append(handler)
                    }
                }
            }
        }

        return apps.sorted { $0.name.lowercased() < $1.name.lowercased() }
    }

    private var popularEditors: [AppInfo] {
        let registeredIDs = Set(registeredHandlers.map(\.bundleIdentifier))
        return Self.popularEditorBundleIDs.compactMap { bundleID in
            // Skip if already shown in registered handlers
            guard !registeredIDs.contains(bundleID) else { return nil }
            return allApps.first { $0.bundleIdentifier == bundleID }
        }
    }

    private var otherApps: [AppInfo] {
        let handlerIDs = Set(registeredHandlers.map(\.bundleIdentifier))
        let popularIDs = Set(Self.popularEditorBundleIDs)

        return allApps.filter { app in
            !handlerIDs.contains(app.bundleIdentifier) &&
            !popularIDs.contains(app.bundleIdentifier)
        }
    }

    private func filteredApps(_ apps: [AppInfo]) -> [AppInfo] {
        if searchText.isEmpty { return apps }
        return apps.filter {
            $0.name.localizedCaseInsensitiveContains(searchText) ||
            $0.bundleIdentifier.localizedCaseInsensitiveContains(searchText)
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(title)
                        .font(.title2.bold())
                    Text(subtitle)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }

                Spacer()

                Button("Cancel") {
                    dismiss()
                }
            }
            .padding()

            Divider()

            // Search
            HStack {
                Image(systemName: "magnifyingglass")
                    .foregroundStyle(.secondary)
                TextField("Search apps...", text: $searchText)
                    .textFieldStyle(.plain)
                    .focused($isSearchFocused)
            }
            .padding(10)
            .background(Color.secondary.opacity(0.1))
            .clipShape(RoundedRectangle(cornerRadius: 8))
            .padding(.horizontal)
            .padding(.vertical, 8)
            .onAppear { isSearchFocused = true }

            // App list
            if isLoading {
                Spacer()
                ProgressView()
                    .scaleEffect(0.8)
                Spacer()
            } else {
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 0) {
                        // Registered Handlers Section - should come first
                        let filteredRegistered = filteredApps(registeredHandlers)
                        if !filteredRegistered.isEmpty {
                            AppSection(title: "Registered for \(extensions.count == 1 ? "this type" : "these types")") {
                                ForEach(filteredRegistered, id: \.bundleIdentifier) { app in
                                    AppRow(
                                        app: app,
                                        isCurrentHandler: app.bundleIdentifier == currentHandler?.bundleIdentifier,
                                        isSelected: selectedApp?.bundleIdentifier == app.bundleIdentifier,
                                        showSelection: isBulkMode
                                    ) {
                                        handleSelection(app)
                                    }
                                }
                            }
                        }

                        // Popular Editors Section
                        let filteredPopular = filteredApps(popularEditors)
                        if !filteredPopular.isEmpty {
                            AppSection(title: "Popular Editors") {
                                ForEach(filteredPopular, id: \.bundleIdentifier) { app in
                                    AppRow(
                                        app: app,
                                        isCurrentHandler: app.bundleIdentifier == currentHandler?.bundleIdentifier,
                                        isSelected: selectedApp?.bundleIdentifier == app.bundleIdentifier,
                                        showSelection: isBulkMode
                                    ) {
                                        handleSelection(app)
                                    }
                                }
                            }
                        }

                        // Other Apps Section
                        let filteredOther = filteredApps(otherApps)
                        if !filteredOther.isEmpty {
                            AppSection(title: "Other Installed Apps") {
                                ForEach(filteredOther, id: \.bundleIdentifier) { app in
                                    AppRow(
                                        app: app,
                                        isCurrentHandler: app.bundleIdentifier == currentHandler?.bundleIdentifier,
                                        isSelected: selectedApp?.bundleIdentifier == app.bundleIdentifier,
                                        showSelection: isBulkMode
                                    ) {
                                        handleSelection(app)
                                    }
                                }
                            }
                        }
                    }
                }
            }

            // Footer (only for bulk mode)
            if isBulkMode {
                Divider()

                HStack {
                    if let app = selectedApp {
                        HStack(spacing: 8) {
                            if let icon = app.icon {
                                Image(nsImage: icon)
                                    .resizable()
                                    .interpolation(.high)
                                    .frame(width: 24, height: 24)
                            }
                            Text("Change to \(app.name)")
                        }
                    } else {
                        Text("Select an app")
                            .foregroundStyle(.secondary)
                    }

                    Spacer()

                    Button("Apply") {
                        applyBulkChange()
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(selectedApp == nil)
                }
                .padding()
            }
        }
        .frame(width: 500, height: isBulkMode ? 600 : 500)
        .task {
            allApps = await AppScanner.findAllApps()
            isLoading = false
        }
    }

    private func handleSelection(_ app: AppInfo) {
        switch mode {
        case .single(_, _, let onSelect):
            onSelect(app.bundleIdentifier)
            dismiss()
        case .bulk:
            selectedApp = app
        }
    }

    private func applyBulkChange() {
        guard case .bulk(let exts, _, let onComplete) = mode,
              let app = selectedApp else { return }

        viewModel.bulkSetDefaultHandler(
            forExtensions: exts,
            bundleID: app.bundleIdentifier,
            appName: app.name
        )
        onComplete()
        dismiss()
    }
}
