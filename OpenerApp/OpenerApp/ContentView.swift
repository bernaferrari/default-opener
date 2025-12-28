import SwiftUI
import AppKit

struct ContentView: View {
    @EnvironmentObject var viewModel: AppViewModel
    @State private var selectedSidebarItem: SidebarItem? = .allFileTypes
    @State private var refreshRotation: Double = 0

    enum SidebarItem: Hashable {
        case allFileTypes
        case allURLSchemes
        case backups
        case activity
        case category(FileCategory)
        case app(String) // bundleID
    }

    var body: some View {
        NavigationSplitView {
            SidebarView(selection: $selectedSidebarItem)
        } detail: {
            DetailView(selection: selectedSidebarItem)
        }
        .searchable(text: $viewModel.searchText, prompt: "Search file types, apps...")
        .navigationTitle("Opener")
        .overlay(alignment: .bottom) {
            ToastView(message: viewModel.toastMessage)
        }
        .overlay(alignment: .top) {
            UpdateBanner(updateInfo: viewModel.updateInfo)
        }
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button {
                    viewModel.refresh()
                } label: {
                    Image(systemName: "arrow.clockwise")
                        .rotationEffect(.degrees(viewModel.isLoading ? refreshRotation : 0))
                }
                .help("Refresh")
                .disabled(viewModel.isLoading)
            }
        }
        .task(id: viewModel.isLoading) {
            guard viewModel.isLoading else { return }
            // Continuous rotation while loading
            while viewModel.isLoading {
                withAnimation(.linear(duration: 0.6)) {
                    refreshRotation += 360
                }
                try? await Task.sleep(nanoseconds: 600_000_000)
            }
        }
    }
}

// MARK: - Sidebar View

struct SidebarView: View {
    @Binding var selection: ContentView.SidebarItem?
    @EnvironmentObject var viewModel: AppViewModel

    var body: some View {
        List(selection: $selection) {
            Section("Overview") {
                Label("All File Types", systemImage: "doc.fill")
                    .tag(ContentView.SidebarItem.allFileTypes)

                Label("URL Schemes", systemImage: "link")
                    .tag(ContentView.SidebarItem.allURLSchemes)

                Label("Backups", systemImage: "clock.arrow.circlepath")
                    .tag(ContentView.SidebarItem.backups)

                Label {
                    HStack {
                        Text("Activity")
                        if !viewModel.externalChanges.isEmpty {
                            Text("\(viewModel.externalChanges.count)")
                                .font(.caption2)
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .foregroundStyle(.white)
                                .background(Color.orange)
                                .clipShape(Capsule())
                        } else if !viewModel.activityLog.isEmpty {
                            Text("\(viewModel.activityLog.count)")
                                .font(.caption2)
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(Color.secondary.opacity(0.2))
                                .clipShape(Capsule())
                        }
                    }
                } icon: {
                    Image(systemName: viewModel.externalChanges.isEmpty ? "list.bullet.clipboard" : "exclamationmark.triangle.fill")
                        .foregroundStyle(viewModel.externalChanges.isEmpty ? Color.primary : Color.orange)
                }
                .tag(ContentView.SidebarItem.activity)
            }

            Section("Categories") {
                ForEach(FileCategory.allCases, id: \.self) { category in
                    Label(category.rawValue, systemImage: category.icon)
                        .tag(ContentView.SidebarItem.category(category))
                }
            }

            Section("Apps Handling Files") {
                ForEach(viewModel.uniqueApps, id: \.bundleIdentifier) { app in
                    HStack(spacing: 8) {
                        if let icon = app.icon {
                            Image(nsImage: icon)
                                .resizable()
                                .frame(width: 18, height: 18)
                        }
                        Text(app.name)
                        Spacer()
                        Text("\(viewModel.fileTypesCount(for: app.bundleIdentifier))")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    .tag(ContentView.SidebarItem.app(app.bundleIdentifier))
                }
            }
        }
        .listStyle(.sidebar)
        .frame(minWidth: 220)
    }
}

// MARK: - Detail View

struct DetailView: View {
    let selection: ContentView.SidebarItem?
    @EnvironmentObject var viewModel: AppViewModel

    var body: some View {
        switch selection {
        case .allFileTypes:
            FileTypesListView(fileTypes: viewModel.filteredFileTypes, title: "All File Types")
        case .allURLSchemes:
            URLSchemesListView(schemes: viewModel.filteredURLSchemes, title: "URL Schemes")
        case .backups:
            BackupsView()
        case .activity:
            ActivityView()
        case .category(let category):
            FileTypesListView(
                fileTypes: viewModel.fileTypes(for: category),
                title: category.rawValue
            )
        case .app(let bundleID):
            AppFileTypesView(bundleID: bundleID)
        case nil:
            Text("Select an item from the sidebar")
                .foregroundStyle(.secondary)
        }
    }
}

// MARK: - File Types List View

struct FileTypesListView: View {
    let fileTypes: [FileTypeAssociation]
    let title: String
    @EnvironmentObject var viewModel: AppViewModel
    @State private var selectedTypes: Set<String> = []
    @State private var showingBulkChange = false
    @State private var isSelectionMode = false

    var body: some View {
        VStack(spacing: 0) {
            // Header with bulk actions - always visible in selection mode to prevent vertical shift
            if isSelectionMode {
                HStack {
                    if selectedTypes.isEmpty {
                        Text("Tap to select file types")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    } else {
                        Text("\(selectedTypes.count) selected")
                            .font(.subheadline.weight(.medium))
                    }

                    Spacer()

                    Button("Change Selected to...") {
                        showingBulkChange = true
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(selectedTypes.isEmpty)

                    Button("Done") {
                        selectedTypes.removeAll()
                        isSelectionMode = false
                    }
                    .buttonStyle(.bordered)
                }
                .padding(.horizontal)
                .padding(.vertical, 10)
                .background(Color.accentColor.opacity(selectedTypes.isEmpty ? 0.05 : 0.1))
            }

            if fileTypes.isEmpty && !viewModel.searchText.isEmpty {
                NoSearchResultsView(searchText: viewModel.searchText) {
                    viewModel.searchText = ""
                }
            } else {
                List {
                    ForEach(fileTypes) { fileType in
                        FileTypeRow(
                            fileType: fileType,
                            isSelected: selectedTypes.contains(fileType.id),
                            isSelectionMode: isSelectionMode,
                            onToggleSelection: {
                                if selectedTypes.contains(fileType.id) {
                                    selectedTypes.remove(fileType.id)
                                } else {
                                    selectedTypes.insert(fileType.id)
                                }
                            }
                        )
                    }
                }
                .listStyle(.inset)
            }
        }
        .navigationTitle(title)
        .navigationSubtitle("\(fileTypes.count) file types")
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button {
                    isSelectionMode.toggle()
                    if !isSelectionMode {
                        selectedTypes.removeAll()
                    }
                } label: {
                    Image(systemName: isSelectionMode ? "checkmark.circle.fill" : "checkmark.circle")
                }
                .help(isSelectionMode ? "Exit selection mode" : "Select multiple")
            }
        }
        .sheet(isPresented: $showingBulkChange) {
            AppPickerSheet(
                mode: .bulk(
                    extensions: Array(selectedTypes),
                    currentApp: nil,
                    onComplete: {
                        selectedTypes.removeAll()
                        isSelectionMode = false
                    }
                )
            )
        }
    }
}

// MARK: - File Type Row

struct FileTypeRow: View {
    let fileType: FileTypeAssociation
    var isSelected: Bool = false
    var isSelectionMode: Bool = false
    var onToggleSelection: (() -> Void)? = nil
    @EnvironmentObject var viewModel: AppViewModel
    @State private var isExpanded = false
    @State private var showingAllApps = false

    var hasValidDescription: Bool {
        // Hide description for dynamic UTIs and when there's no meaningful description
        guard !fileType.uti.hasPrefix("dyn.") else { return false }
        guard let description = fileType.utiDescription else { return false }
        let lower = description.lowercased()
        // Hide if it's empty, says "unregistered", or is just the UTI repeated
        if description.isEmpty || lower == "unregistered" || description == fileType.uti {
            return false
        }
        return true
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: 12) {
                // Leading indicator - fixed width to prevent jitter
                ZStack {
                    if isSelectionMode {
                        Button {
                            onToggleSelection?()
                        } label: {
                            Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                                .font(.system(size: 18))
                                .foregroundStyle(isSelected ? Color.accentColor : .secondary)
                        }
                        .buttonStyle(.plain)
                    } else {
                        Image(systemName: "chevron.right")
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundStyle(.tertiary)
                            .rotationEffect(.degrees(isExpanded ? 90 : 0))
                    }
                }
                .frame(width: 20)

                // Extension badge
                ExtensionBadge(ext: fileType.fileExtension)

                // Only show description for registered UTIs with valid descriptions
                if hasValidDescription {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(fileType.utiDescription!)
                            .font(.body)

                        Text(fileType.uti)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }

                Spacer()

                // Current handler - clickable to show picker
                Menu {
                    ForEach(fileType.availableHandlers, id: \.bundleIdentifier) { app in
                        Button {
                            viewModel.setDefaultHandler(
                                forExtension: fileType.fileExtension,
                                bundleID: app.bundleIdentifier
                            )
                        } label: {
                            HStack {
                                if let icon = app.icon {
                                    Image(nsImage: icon)
                                }
                                Text(app.name)
                                if app.bundleIdentifier == fileType.defaultHandler?.bundleIdentifier {
                                    Image(systemName: "checkmark")
                                }
                            }
                        }
                    }

                    Divider()

                    Button("Other…") {
                        showingAllApps = true
                    }
                } label: {
                    if let handler = fileType.defaultHandler {
                        AppBadge(app: handler)
                    } else {
                        Text("No default")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(Color.orange.opacity(0.1))
                            .clipShape(RoundedRectangle(cornerRadius: 6))
                    }
                }
                .menuStyle(.borderlessButton)
                .menuIndicator(.hidden)
            }
            .padding(.vertical, 8)
            .contentShape(Rectangle())
            .onTapGesture {
                if isSelectionMode {
                    onToggleSelection?()
                } else {
                    isExpanded.toggle()
                }
            }

            // Expanded section showing all handlers
            if isExpanded && !isSelectionMode {
                VStack(alignment: .leading, spacing: 12) {
                    Text("Choose default app")
                        .font(.subheadline.weight(.medium))
                        .foregroundStyle(.secondary)

                    FlowLayout(spacing: 8) {
                        ForEach(fileType.availableHandlers, id: \.bundleIdentifier) { app in
                            AppOptionButton(
                                app: app,
                                isSelected: app.bundleIdentifier == fileType.defaultHandler?.bundleIdentifier
                            ) {
                                viewModel.setDefaultHandler(
                                    forExtension: fileType.fileExtension,
                                    bundleID: app.bundleIdentifier
                                )
                                isExpanded = false
                            }
                        }

                        // Other... button
                        Button {
                            showingAllApps = true
                        } label: {
                            Text("Other…")
                                .font(.subheadline)
                                .padding(.horizontal, 12)
                                .padding(.vertical, 8)
                                .background(Color.secondary.opacity(0.1))
                                .clipShape(RoundedRectangle(cornerRadius: 8))
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.top, 8)
                .padding(.bottom, 12)
                .padding(.leading, 44)
            }
        }
        .animation(.snappy(duration: 0.25), value: isSelectionMode)
        .sheet(isPresented: $showingAllApps) {
            AppPickerSheet(
                mode: .single(
                    fileExtension: fileType.fileExtension,
                    currentHandler: fileType.defaultHandler,
                    onSelect: { bundleID in
                        viewModel.setDefaultHandler(
                            forExtension: fileType.fileExtension,
                            bundleID: bundleID
                        )
                        isExpanded = false
                    }
                )
            )
        }
    }
}

// MARK: - Unified App Picker Sheet

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
                    if !seen.contains(handler.bundleIdentifier) &&
                       !Self.popularEditorBundleIDs.contains(handler.bundleIdentifier) {
                        seen.insert(handler.bundleIdentifier)
                        apps.append(handler)
                    }
                }
            }
        }

        return apps.sorted { $0.name.lowercased() < $1.name.lowercased() }
    }

    private var popularEditors: [AppInfo] {
        Self.popularEditorBundleIDs.compactMap { bundleID in
            allApps.first { $0.bundleIdentifier == bundleID }
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
            }
            .padding(10)
            .background(Color.secondary.opacity(0.1))
            .clipShape(RoundedRectangle(cornerRadius: 8))
            .padding(.horizontal)
            .padding(.vertical, 8)

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
                            AppSection(title: "Registered for \(extensions.count == 1 ? "This Type" : "These Types")") {
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
            allApps = await findAllApps()
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

    private func findAllApps() async -> [AppInfo] {
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

// MARK: - App Picker Section

private struct AppSection<Content: View>: View {
    let title: String
    @ViewBuilder let content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text(title)
                .font(.caption)
                .foregroundStyle(.secondary)
                .padding(.horizontal, 16)
                .padding(.top, 16)
                .padding(.bottom, 8)

            content
        }
    }
}

// MARK: - App Row

private struct AppRow: View {
    let app: AppInfo
    let isCurrentHandler: Bool
    let isSelected: Bool
    let showSelection: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 12) {
                if let icon = app.icon {
                    Image(nsImage: icon)
                        .resizable()
                        .interpolation(.high)
                        .frame(width: 32, height: 32)
                }

                VStack(alignment: .leading, spacing: 2) {
                    Text(app.name)
                        .font(.body)
                        .foregroundStyle(.primary)
                    Text(app.bundleIdentifier)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Spacer()

                if showSelection && isSelected {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundStyle(Color.accentColor)
                        .font(.title3)
                } else if isCurrentHandler {
                    Text("Current")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(Color.secondary.opacity(0.1))
                        .clipShape(RoundedRectangle(cornerRadius: 4))
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
            .background(isSelected && showSelection ? Color.accentColor.opacity(0.1) : Color.clear)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Flow Layout (for app buttons)

struct FlowLayout: Layout {
    var spacing: CGFloat = 8

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let result = arrange(proposal: proposal, subviews: subviews)
        return result.size
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        let result = arrange(proposal: proposal, subviews: subviews)
        for (index, position) in result.positions.enumerated() {
            subviews[index].place(at: CGPoint(x: bounds.minX + position.x, y: bounds.minY + position.y), proposal: .unspecified)
        }
    }

    private func arrange(proposal: ProposedViewSize, subviews: Subviews) -> (size: CGSize, positions: [CGPoint]) {
        let maxWidth = proposal.width ?? .infinity
        var positions: [CGPoint] = []
        var currentX: CGFloat = 0
        var currentY: CGFloat = 0
        var lineHeight: CGFloat = 0

        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)

            if currentX + size.width > maxWidth && currentX > 0 {
                currentX = 0
                currentY += lineHeight + spacing
                lineHeight = 0
            }

            positions.append(CGPoint(x: currentX, y: currentY))
            lineHeight = max(lineHeight, size.height)
            currentX += size.width + spacing
        }

        return (CGSize(width: maxWidth, height: currentY + lineHeight), positions)
    }
}

// MARK: - URL Scheme Picker Sheet

struct URLSchemePickerSheet: View {
    let scheme: String
    let currentHandler: AppInfo?
    let registeredHandlers: [AppInfo]
    let onSelect: (String) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var searchText = ""
    @State private var allApps: [AppInfo] = []
    @State private var isLoading = true

    private var filteredRegistered: [AppInfo] {
        if searchText.isEmpty { return registeredHandlers }
        return registeredHandlers.filter {
            $0.name.localizedCaseInsensitiveContains(searchText) ||
            $0.bundleIdentifier.localizedCaseInsensitiveContains(searchText)
        }
    }

    private var otherApps: [AppInfo] {
        let registeredIDs = Set(registeredHandlers.map(\.bundleIdentifier))
        let filtered = allApps.filter { !registeredIDs.contains($0.bundleIdentifier) }
        if searchText.isEmpty { return filtered }
        return filtered.filter {
            $0.name.localizedCaseInsensitiveContains(searchText) ||
            $0.bundleIdentifier.localizedCaseInsensitiveContains(searchText)
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Choose App for \(scheme)://")
                        .font(.title2.bold())
                    Text("Select any app to handle this URL scheme")
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
            }
            .padding(10)
            .background(Color.secondary.opacity(0.1))
            .clipShape(RoundedRectangle(cornerRadius: 8))
            .padding(.horizontal)
            .padding(.vertical, 8)

            // App list
            if isLoading {
                Spacer()
                ProgressView()
                    .scaleEffect(0.8)
                Spacer()
            } else {
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 0) {
                        // Registered Handlers Section
                        if !filteredRegistered.isEmpty {
                            AppSection(title: "Registered for This Scheme") {
                                ForEach(filteredRegistered, id: \.bundleIdentifier) { app in
                                    AppRow(
                                        app: app,
                                        isCurrentHandler: app.bundleIdentifier == currentHandler?.bundleIdentifier,
                                        isSelected: false,
                                        showSelection: false
                                    ) {
                                        onSelect(app.bundleIdentifier)
                                        dismiss()
                                    }
                                }
                            }
                        }

                        // Other Apps Section
                        if !otherApps.isEmpty {
                            AppSection(title: "Other Apps") {
                                ForEach(otherApps, id: \.bundleIdentifier) { app in
                                    AppRow(
                                        app: app,
                                        isCurrentHandler: false,
                                        isSelected: false,
                                        showSelection: false
                                    ) {
                                        onSelect(app.bundleIdentifier)
                                        dismiss()
                                    }
                                }
                            }
                        }

                        if filteredRegistered.isEmpty && otherApps.isEmpty {
                            VStack(spacing: 8) {
                                Text("No apps found")
                                    .font(.headline)
                                Text("Try a different search term")
                                    .font(.subheadline)
                                    .foregroundStyle(.secondary)
                            }
                            .frame(maxWidth: .infinity)
                            .padding(.top, 40)
                        }
                    }
                }
            }
        }
        .frame(width: 500, height: 550)
        .task {
            allApps = await loadAllApps()
            isLoading = false
        }
    }

    private func loadAllApps() async -> [AppInfo] {
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

// MARK: - URL Schemes List View

struct URLSchemesListView: View {
    let schemes: [URLSchemeAssociation]
    let title: String
    @EnvironmentObject var viewModel: AppViewModel

    var body: some View {
        Group {
            if schemes.isEmpty && !viewModel.searchText.isEmpty {
                NoSearchResultsView(searchText: viewModel.searchText) {
                    viewModel.searchText = ""
                }
            } else {
                List(schemes) { scheme in
                    URLSchemeRow(scheme: scheme)
                }
                .listStyle(.inset)
            }
        }
        .navigationTitle(title)
        .navigationSubtitle("\(schemes.count) schemes")
    }
}

struct URLSchemeRow: View {
    let scheme: URLSchemeAssociation
    @EnvironmentObject var viewModel: AppViewModel
    @State private var isExpanded = false
    @State private var showingAllApps = false

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: 12) {
                // Leading indicator - fixed width to match FileTypeRow
                ZStack {
                    Image(systemName: "chevron.right")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(.tertiary)
                        .rotationEffect(.degrees(isExpanded ? 90 : 0))
                }
                .frame(width: 20)

                // Scheme badge
                Text("\(scheme.scheme)://")
                    .font(.system(.body, design: .monospaced))
                    .foregroundStyle(.blue)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Color.blue.opacity(0.1))
                    .clipShape(RoundedRectangle(cornerRadius: 6))

                if let description = scheme.description {
                    Text(description)
                        .font(.body)
                }

                Spacer()

                // Current handler - clickable menu
                Menu {
                    ForEach(scheme.availableHandlers, id: \.bundleIdentifier) { app in
                        Button {
                            viewModel.setDefaultHandler(
                                forScheme: scheme.scheme,
                                bundleID: app.bundleIdentifier
                            )
                        } label: {
                            HStack {
                                if let icon = app.icon {
                                    Image(nsImage: icon)
                                }
                                Text(app.name)
                                if app.bundleIdentifier == scheme.defaultHandler?.bundleIdentifier {
                                    Image(systemName: "checkmark")
                                }
                            }
                        }
                    }

                    Divider()

                    Button("Other…") {
                        showingAllApps = true
                    }
                } label: {
                    if let handler = scheme.defaultHandler {
                        AppBadge(app: handler)
                    } else {
                        Text("No default")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(Color.orange.opacity(0.1))
                            .clipShape(RoundedRectangle(cornerRadius: 6))
                    }
                }
                .menuStyle(.borderlessButton)
                .menuIndicator(.hidden)
            }
            .padding(.vertical, 8)
            .contentShape(Rectangle())
            .onTapGesture {
                isExpanded.toggle()
            }

            // Expanded section showing all handlers
            if isExpanded {
                VStack(alignment: .leading, spacing: 12) {
                    Text("Choose default app")
                        .font(.subheadline.weight(.medium))
                        .foregroundStyle(.secondary)

                    FlowLayout(spacing: 8) {
                        ForEach(scheme.availableHandlers, id: \.bundleIdentifier) { app in
                            AppOptionButton(
                                app: app,
                                isSelected: app.bundleIdentifier == scheme.defaultHandler?.bundleIdentifier
                            ) {
                                viewModel.setDefaultHandler(
                                    forScheme: scheme.scheme,
                                    bundleID: app.bundleIdentifier
                                )
                                isExpanded = false
                            }
                        }

                        // Other... button
                        Button {
                            showingAllApps = true
                        } label: {
                            Text("Other…")
                                .font(.subheadline)
                                .padding(.horizontal, 12)
                                .padding(.vertical, 8)
                                .background(Color.secondary.opacity(0.1))
                                .clipShape(RoundedRectangle(cornerRadius: 8))
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.top, 8)
                .padding(.bottom, 12)
                .padding(.leading, 44)
            }
        }
        .animation(.snappy(duration: 0.25), value: isExpanded)
        .sheet(isPresented: $showingAllApps) {
            URLSchemePickerSheet(
                scheme: scheme.scheme,
                currentHandler: scheme.defaultHandler,
                registeredHandlers: scheme.availableHandlers
            ) { bundleID in
                viewModel.setDefaultHandler(
                    forScheme: scheme.scheme,
                    bundleID: bundleID
                )
                isExpanded = false
            }
        }
    }
}

// MARK: - App File Types View (Filter by App)

struct AppFileTypesView: View {
    let bundleID: String
    @EnvironmentObject var viewModel: AppViewModel
    @State private var showingBulkChange = false

    var app: AppInfo? {
        viewModel.uniqueApps.first { $0.bundleIdentifier == bundleID }
    }

    var handledFileTypes: [FileTypeAssociation] {
        viewModel.fileTypes.filter { $0.defaultHandler?.bundleIdentifier == bundleID }
    }

    var body: some View {
        VStack(spacing: 0) {
            // App header
            if let app = app {
                HStack(spacing: 16) {
                    if let icon = app.icon {
                        Image(nsImage: icon)
                            .resizable()
                            .frame(width: 64, height: 64)
                    }

                    VStack(alignment: .leading, spacing: 4) {
                        Text(app.name)
                            .font(.title2.bold())

                        Text(app.bundleIdentifier)
                            .font(.caption)
                            .foregroundStyle(.secondary)

                        Text("\(handledFileTypes.count) file types")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }

                    Spacer()

                    Button("Change All...") {
                        showingBulkChange = true
                    }
                    .buttonStyle(.borderedProminent)
                }
                .padding()
                .background(Color(nsColor: .windowBackgroundColor))
            }

            Divider()

            List(handledFileTypes) { fileType in
                FileTypeRow(fileType: fileType)
            }
            .listStyle(.inset)
        }
        .navigationTitle(app?.name ?? "App")
        .sheet(isPresented: $showingBulkChange) {
            AppPickerSheet(
                mode: .bulk(
                    extensions: handledFileTypes.map(\.fileExtension),
                    currentApp: app,
                    onComplete: {}
                )
            )
        }
    }
}

// MARK: - Backups View

struct BackupsView: View {
    @EnvironmentObject var viewModel: AppViewModel
    @State private var showingRestoreConfirm = false
    @State private var backupToRestore: BackupInfo?
    @State private var showingImportError = false
    @State private var importError = ""

    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Backups")
                        .font(.title2.bold())
                    Text("Save and restore your file associations")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }

                Spacer()

                Button {
                    importBackup()
                } label: {
                    Label("Import...", systemImage: "square.and.arrow.down")
                }

                Button {
                    viewModel.createBackup()
                } label: {
                    Label("Create Backup", systemImage: "plus")
                }
                .buttonStyle(.borderedProminent)
            }
            .padding()
            .background(Color(nsColor: .windowBackgroundColor))

            Divider()

            if viewModel.backups.isEmpty {
                VStack(spacing: 16) {
                    Spacer()
                    Image(systemName: "clock.arrow.circlepath")
                        .font(.system(size: 48))
                        .foregroundStyle(.secondary)
                    Text("No Backups")
                        .font(.title2.bold())
                    Text("Create a backup to save your current file associations")
                        .foregroundStyle(.secondary)
                    HStack(spacing: 12) {
                        Button("Import...") {
                            importBackup()
                        }
                        Button("Create Backup") {
                            viewModel.createBackup()
                        }
                        .buttonStyle(.borderedProminent)
                    }
                    Spacer()
                }
            } else {
                List(viewModel.backups) { backup in
                    BackupRow(
                        backup: backup,
                        onRestore: {
                            backupToRestore = backup
                            showingRestoreConfirm = true
                        },
                        onReveal: {
                            NSWorkspace.shared.selectFile(backup.url.path, inFileViewerRootedAtPath: "")
                        },
                        onDelete: {
                            viewModel.deleteBackup(backup)
                        }
                    )
                }
                .listStyle(.inset)
            }
        }
        .confirmationDialog(
            "Restore Backup?",
            isPresented: $showingRestoreConfirm,
            presenting: backupToRestore
        ) { backup in
            Button("Restore") {
                viewModel.restoreBackup(backup)
            }
            Button("Cancel", role: .cancel) {}
        } message: { backup in
            Text("This will restore \(backup.fileTypesCount) file types and \(backup.schemesCount) URL schemes from \(backup.formattedDate)")
        }
        .alert("Import Failed", isPresented: $showingImportError) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(importError)
        }
    }

    private func importBackup() {
        let panel = NSOpenPanel()
        panel.allowedContentTypes = [.json]
        panel.canChooseFiles = true
        panel.canChooseDirectories = false
        panel.allowsMultipleSelection = false
        panel.message = "Select an Opener backup file to restore"

        if panel.runModal() == .OK, let url = panel.url {
            do {
                let fileManager = FileManager.default
                let data = try Data(contentsOf: url)

                let decoder = JSONDecoder()
                decoder.dateDecodingStrategy = .iso8601
                let backup = try decoder.decode(AssociationsBackup.self, from: data)

                let attributes = try fileManager.attributesOfItem(atPath: url.path)
                let size = attributes[.size] as? Int ?? 0

                let backupInfo = BackupInfo(
                    url: url,
                    createdAt: backup.createdAt,
                    macOSVersion: backup.macOSVersion,
                    fileTypesCount: backup.fileTypes.count,
                    schemesCount: backup.urlSchemes.count,
                    fileSize: size
                )

                backupToRestore = backupInfo
                showingRestoreConfirm = true
            } catch {
                importError = "Failed to read backup: \(error.localizedDescription)"
                showingImportError = true
            }
        }
    }
}

struct BackupRow: View {
    let backup: BackupInfo
    let onRestore: () -> Void
    let onReveal: () -> Void
    let onDelete: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: "doc.zipper")
                .font(.title2)
                .foregroundStyle(.blue)
                .frame(width: 32)

            VStack(alignment: .leading, spacing: 4) {
                Text(backup.formattedDate)
                    .font(.headline)

                HStack(spacing: 12) {
                    Label("\(backup.fileTypesCount) file types", systemImage: "doc.fill")
                    Label("\(backup.schemesCount) schemes", systemImage: "link")
                    Text(backup.formattedSize)
                }
                .font(.caption)
                .foregroundStyle(.secondary)
            }

            Spacer()

            Button {
                onReveal()
            } label: {
                Image(systemName: "folder")
            }
            .help("Reveal in Finder")

            Button("Restore") {
                onRestore()
            }

            Button(role: .destructive) {
                onDelete()
            } label: {
                Image(systemName: "trash")
            }
        }
        .padding(.vertical, 4)
    }
}

// MARK: - No Search Results View

struct NoSearchResultsView: View {
    let searchText: String
    let onClear: () -> Void

    var body: some View {
        VStack(spacing: 16) {
            Spacer()

            Image(systemName: "magnifyingglass")
                .font(.system(size: 48))
                .foregroundStyle(.secondary)

            Text("No Results for \"\(searchText)\"")
                .font(.title2.bold())

            Text("Try a different search term")
                .foregroundStyle(.secondary)

            Button("Clear Search") {
                onClear()
            }
            .buttonStyle(.borderedProminent)

            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

// MARK: - Supporting Views

struct ExtensionBadge: View {
    let ext: String

    var color: Color {
        switch FileCategory.category(for: ext) {
        case .code: return .blue
        case .documents: return .orange
        case .images: return .purple
        case .video: return .red
        case .audio: return .pink
        case .archives: return .brown
        }
    }

    var body: some View {
        Text(".\(ext)")
            .font(.system(.body, design: .monospaced, weight: .medium))
            .foregroundStyle(color)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(color.opacity(0.1))
            .clipShape(RoundedRectangle(cornerRadius: 6))
            .frame(minWidth: 60, alignment: .leading)
    }
}

struct AppBadge: View {
    let app: AppInfo

    var body: some View {
        HStack(spacing: 6) {
            if let icon = app.icon {
                Image(nsImage: icon)
                    .resizable()
                    .interpolation(.high)
                    .frame(width: 20, height: 20)
            }
            Text(app.name)
                .font(.subheadline)
                .lineLimit(1)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(Color(nsColor: .controlBackgroundColor))
        .clipShape(RoundedRectangle(cornerRadius: 6))
    }
}

struct AppOptionButton: View {
    let app: AppInfo
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 6) {
                if let icon = app.icon {
                    Image(nsImage: icon)
                        .resizable()
                        .interpolation(.high)
                        .frame(width: 20, height: 20)
                }
                Text(app.name)
                    .font(.subheadline)
                    .lineLimit(1)

                if isSelected {
                    Image(systemName: "checkmark")
                        .font(.caption.bold())
                        .foregroundStyle(.blue)
                }
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(isSelected ? Color.blue.opacity(0.1) : Color(nsColor: .controlBackgroundColor))
            .clipShape(RoundedRectangle(cornerRadius: 8))
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(isSelected ? Color.blue : Color.clear, lineWidth: 1.5)
            )
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Settings View

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
                Text("Opener manages your default applications for file types and URL schemes.")
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

// MARK: - ViewModel Extensions

extension AppViewModel {
    var uniqueApps: [AppInfo] {
        var seen = Set<String>()
        var apps: [AppInfo] = []

        for fileType in fileTypes {
            if let handler = fileType.defaultHandler {
                if !seen.contains(handler.bundleIdentifier) {
                    seen.insert(handler.bundleIdentifier)
                    apps.append(handler)
                }
            }
        }

        return apps.sorted { $0.name < $1.name }
    }

    func fileTypesCount(for bundleID: String) -> Int {
        fileTypes.filter { $0.defaultHandler?.bundleIdentifier == bundleID }.count
    }

    func fileTypes(for category: FileCategory) -> [FileTypeAssociation] {
        let exts = Set(category.extensions)
        let filtered = fileTypes.filter { exts.contains($0.fileExtension) }

        if searchText.isEmpty {
            return filtered
        }

        let query = searchText.lowercased()
        return filtered.filter {
            $0.fileExtension.lowercased().contains(query) ||
            $0.uti.lowercased().contains(query) ||
            ($0.defaultHandler?.name.lowercased().contains(query) ?? false)
        }
    }
}

// MARK: - Toast View

struct ToastView: View {
    let message: String?

    var body: some View {
        ZStack {
            if let message = message {
                Text(message)
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 10)
                    .background(Color.accentColor)
                    .clipShape(Capsule())
                    .shadow(color: .black.opacity(0.15), radius: 8, y: 4)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
            }
        }
        .padding(.bottom, 20)
        .animation(.spring(response: 0.3, dampingFraction: 0.7), value: message)
    }
}

// MARK: - Update Banner

struct UpdateBanner: View {
    let updateInfo: UpdateInfo?
    @State private var isDismissed = false

    var body: some View {
        ZStack {
            if let info = updateInfo, info.isUpdateAvailable, !isDismissed {
                HStack(spacing: 12) {
                    Image(systemName: "arrow.down.circle.fill")
                        .font(.title2)
                        .foregroundStyle(.white)

                    VStack(alignment: .leading, spacing: 2) {
                        Text("Update Available")
                            .font(.headline)
                            .foregroundStyle(.white)
                        Text("Version \(info.latestVersion) is now available (you have \(info.currentVersion))")
                            .font(.caption)
                            .foregroundStyle(.white.opacity(0.9))
                    }

                    Spacer()

                    Button("Download") {
                        NSWorkspace.shared.open(info.releaseURL)
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(.white)
                    .foregroundStyle(.blue)

                    Button {
                        isDismissed = true
                    } label: {
                        Image(systemName: "xmark")
                            .foregroundStyle(.white.opacity(0.8))
                    }
                    .buttonStyle(.plain)
                }
                .padding()
                .background(
                    LinearGradient(
                        colors: [.blue, .purple],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                )
                .transition(.move(edge: .top).combined(with: .opacity))
            }
        }
        .animation(.spring(response: 0.4, dampingFraction: 0.8), value: isDismissed)
        .animation(.spring(response: 0.4, dampingFraction: 0.8), value: updateInfo?.latestVersion)
    }
}

// MARK: - Activity View

struct ActivityView: View {
    @EnvironmentObject var viewModel: AppViewModel
    @State private var showingClearConfirmation = false

    var groupedActivities: [(String, [ActivityLogEntry])] {
        let calendar = Calendar.current
        let now = Date()

        var groups: [String: [ActivityLogEntry]] = [:]

        for entry in viewModel.activityLog {
            let key: String
            if calendar.isDateInToday(entry.timestamp) {
                key = "Today"
            } else if calendar.isDateInYesterday(entry.timestamp) {
                key = "Yesterday"
            } else if let daysAgo = calendar.dateComponents([.day], from: entry.timestamp, to: now).day, daysAgo < 7 {
                key = "This Week"
            } else {
                key = "Earlier"
            }

            groups[key, default: []].append(entry)
        }

        // Return in order
        let order = ["Today", "Yesterday", "This Week", "Earlier"]
        return order.compactMap { key in
            guard let entries = groups[key], !entries.isEmpty else { return nil }
            return (key, entries)
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Activity")
                        .font(.title2.bold())
                    if !viewModel.externalChanges.isEmpty {
                        Text("\(viewModel.externalChanges.count) external changes detected")
                            .font(.subheadline)
                            .foregroundStyle(.orange)
                    } else {
                        Text("History of your changes")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                }

                Spacer()

                if !viewModel.activityLog.isEmpty {
                    Button(role: .destructive) {
                        showingClearConfirmation = true
                    } label: {
                        Image(systemName: "trash")
                    }
                    .buttonStyle(.borderless)
                    .help("Clear history")
                    .confirmationDialog(
                        "Clear Activity History?",
                        isPresented: $showingClearConfirmation,
                        titleVisibility: .visible
                    ) {
                        Button("Clear All", role: .destructive) {
                            viewModel.clearActivityLog()
                        }
                        Button("Cancel", role: .cancel) {}
                    } message: {
                        Text("This will permanently delete all activity history. This action cannot be undone.")
                    }
                }
            }
            .padding()
            .background(Color(nsColor: .windowBackgroundColor))

            Divider()

            if viewModel.activityLog.isEmpty && viewModel.externalChanges.isEmpty {
                VStack(spacing: 16) {
                    Spacer()
                    Image(systemName: "clock.arrow.circlepath")
                        .font(.system(size: 48))
                        .foregroundStyle(.secondary)
                    Text("No Activity Yet")
                        .font(.title2.bold())
                    Text("Changes you make will appear here")
                        .foregroundStyle(.secondary)
                    Spacer()
                }
            } else {
                ScrollView {
                    LazyVStack(spacing: 0, pinnedViews: .sectionHeaders) {
                        // External Changes Section
                        if !viewModel.externalChanges.isEmpty {
                            Section {
                                ForEach(viewModel.externalChanges) { change in
                                    ExternalChangeRow(change: change)
                                    if change.id != viewModel.externalChanges.last?.id {
                                        Divider().padding(.leading, 60)
                                    }
                                }
                            } header: {
                                ExternalChangesHeader()
                            }
                        }

                        // Grouped Activity Log
                        ForEach(groupedActivities, id: \.0) { group, entries in
                            Section {
                                ForEach(entries) { entry in
                                    ActivityRow(entry: entry)
                                    if entry.id != entries.last?.id {
                                        Divider().padding(.leading, 60)
                                    }
                                }
                            } header: {
                                ActivitySectionHeader(title: group, entries: entries)
                            }
                        }
                    }
                    .padding(.horizontal)
                }
            }
        }
        .navigationTitle("Activity")
    }
}

struct ExternalChangesHeader: View {
    @EnvironmentObject var viewModel: AppViewModel

    var body: some View {
        HStack {
            Image(systemName: "exclamationmark.triangle.fill")
                .foregroundStyle(.orange)
            Text("External Changes")
                .font(.subheadline.weight(.semibold))
            Spacer()
            Button("Revert All") {
                viewModel.revertAllExternalChanges()
            }
            .buttonStyle(.borderless)
            .font(.caption)
            Button("Dismiss") {
                viewModel.dismissAllExternalChanges()
            }
            .buttonStyle(.borderless)
            .font(.caption)
            .foregroundStyle(.secondary)
        }
        .padding(.vertical, 8)
        .padding(.horizontal, 4)
        .background(Color(nsColor: .windowBackgroundColor))
    }
}

struct ActivitySectionHeader: View {
    let title: String
    let entries: [ActivityLogEntry]
    @EnvironmentObject var viewModel: AppViewModel
    @State private var showingUndoConfirm = false

    var undoableEntries: [ActivityLogEntry] {
        entries.filter { $0.canUndo }
    }

    // Consolidate changes: if .cpp changed A→B→C, we only want to restore to A
    var consolidatedUndos: [(target: String, originalApp: String, originalBundleID: String)] {
        var seen = Set<String>()
        var result: [(target: String, originalApp: String, originalBundleID: String)] = []

        // Process in reverse (oldest first) to get the original state
        for entry in undoableEntries.reversed() {
            let key = "\(entry.action.rawValue):\(entry.target)"
            if !seen.contains(key), let oldApp = entry.oldValue, let oldBundleID = entry.oldBundleID {
                seen.insert(key)
                result.append((entry.target, oldApp, oldBundleID))
            }
        }
        return result
    }

    var body: some View {
        HStack {
            Text(title)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.secondary)
            Spacer()
            if !undoableEntries.isEmpty {
                Button("Undo All (\(consolidatedUndos.count))") {
                    showingUndoConfirm = true
                }
                .buttonStyle(.borderless)
                .font(.caption)
                .foregroundStyle(.secondary)
            }
        }
        .padding(.vertical, 8)
        .padding(.horizontal, 4)
        .background(Color(nsColor: .windowBackgroundColor))
        .confirmationDialog("Undo \(title) Changes", isPresented: $showingUndoConfirm) {
            Button("Undo \(consolidatedUndos.count) Changes") {
                performConsolidatedUndo()
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text(undoSummary)
        }
    }

    var undoSummary: String {
        let items = consolidatedUndos.prefix(5).map { ".\($0.target) → \($0.originalApp)" }
        var summary = items.joined(separator: "\n")
        if consolidatedUndos.count > 5 {
            summary += "\n...and \(consolidatedUndos.count - 5) more"
        }
        return summary
    }

    func performConsolidatedUndo() {
        for undo in consolidatedUndos {
            // Find if it's a file type or scheme
            if let entry = undoableEntries.first(where: { $0.target == undo.target }) {
                switch entry.action {
                case .setFileTypeHandler:
                    viewModel.setDefaultHandler(forExtension: undo.target, bundleID: undo.originalBundleID, skipLog: true)
                case .setSchemeHandler:
                    viewModel.setDefaultHandler(forScheme: undo.target, bundleID: undo.originalBundleID, skipLog: true)
                default:
                    break
                }
            }
        }

        // Log as single bulk undo
        let entry = ActivityLogEntry(
            timestamp: Date(),
            action: .bulkChange,
            target: "\(consolidatedUndos.count)",
            oldValue: nil,
            newValue: "restored \(title.lowercased()) changes"
        )
        viewModel.activityLog.insert(entry, at: 0)
        viewModel.showToast("Restored \(consolidatedUndos.count) handlers")
    }
}

// MARK: - External Change Row

struct ExternalChangeRow: View {
    let change: ExternalChange
    @EnvironmentObject var viewModel: AppViewModel

    var oldAppIcon: NSImage? {
        guard let bundleID = change.oldBundleID,
              let url = NSWorkspace.shared.urlForApplication(withBundleIdentifier: bundleID) else {
            return nil
        }
        return NSWorkspace.shared.icon(forFile: url.path)
    }

    var newAppIcon: NSImage? {
        guard let bundleID = change.newBundleID,
              let url = NSWorkspace.shared.urlForApplication(withBundleIdentifier: bundleID) else {
            return nil
        }
        return NSWorkspace.shared.icon(forFile: url.path)
    }

    var body: some View {
        HStack(spacing: 12) {
            // App transition visual
            HStack(spacing: 6) {
                if let icon = oldAppIcon {
                    Image(nsImage: icon)
                        .resizable()
                        .interpolation(.high)
                        .frame(width: 24, height: 24)
                        .opacity(0.5)
                } else if change.oldBundleID != nil {
                    Image(systemName: "questionmark.app")
                        .frame(width: 24, height: 24)
                        .foregroundStyle(.secondary)
                } else {
                    Text("—")
                        .font(.caption.weight(.bold))
                        .frame(width: 24, height: 24)
                        .foregroundStyle(.secondary)
                }

                Image(systemName: "arrow.right")
                    .font(.caption2)
                    .foregroundStyle(.secondary)

                if let icon = newAppIcon {
                    Image(nsImage: icon)
                        .resizable()
                        .interpolation(.high)
                        .frame(width: 24, height: 24)
                } else if change.newBundleID != nil {
                    Image(systemName: "questionmark.app")
                        .frame(width: 24, height: 24)
                        .foregroundStyle(.secondary)
                } else {
                    Text("—")
                        .font(.caption.weight(.bold))
                        .frame(width: 24, height: 24)
                        .foregroundStyle(.secondary)
                }
            }
            .frame(width: 72)

            VStack(alignment: .leading, spacing: 2) {
                Text(change.displayTarget)
                    .font(.body.weight(.medium))

                Text("\(change.oldAppName ?? "Unknown") → \(change.newAppName ?? "Unknown")")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            HStack(spacing: 8) {
                Button {
                    viewModel.revertExternalChange(change)
                } label: {
                    Image(systemName: "arrow.uturn.backward")
                }
                .buttonStyle(.borderless)
                .help("Revert to \(change.oldAppName ?? "previous")")

                Button {
                    viewModel.dismissExternalChange(change)
                } label: {
                    Image(systemName: "xmark")
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.borderless)
                .help("Keep this change")
            }
        }
        .padding(.vertical, 10)
    }
}

// MARK: - Activity Row

struct ActivityRow: View {
    let entry: ActivityLogEntry
    @EnvironmentObject var viewModel: AppViewModel

    var oldAppIcon: NSImage? {
        guard let bundleID = entry.oldBundleID,
              let url = NSWorkspace.shared.urlForApplication(withBundleIdentifier: bundleID) else {
            return nil
        }
        return NSWorkspace.shared.icon(forFile: url.path)
    }

    var newAppIcon: NSImage? {
        guard let bundleID = entry.newBundleID,
              let url = NSWorkspace.shared.urlForApplication(withBundleIdentifier: bundleID) else {
            return nil
        }
        return NSWorkspace.shared.icon(forFile: url.path)
    }

    var body: some View {
        HStack(spacing: 12) {
            // App icons for handler changes, otherwise colored icon
            if showsAppIcons {
                HStack(spacing: 4) {
                    if let icon = oldAppIcon {
                        Image(nsImage: icon)
                            .resizable()
                            .interpolation(.high)
                            .frame(width: 20, height: 20)
                            .opacity(0.5)
                    } else if entry.oldBundleID != nil {
                        // App was set but can't find it anymore
                        Image(systemName: "questionmark.app")
                            .frame(width: 20, height: 20)
                            .foregroundStyle(.secondary)
                    } else {
                        // Was "none"
                        Text("—")
                            .font(.caption.weight(.bold))
                            .frame(width: 20, height: 20)
                            .foregroundStyle(.secondary)
                    }

                    Image(systemName: "arrow.right")
                        .font(.system(size: 8))
                        .foregroundStyle(.secondary)

                    if let icon = newAppIcon {
                        Image(nsImage: icon)
                            .resizable()
                            .interpolation(.high)
                            .frame(width: 20, height: 20)
                    } else if entry.newBundleID != nil {
                        Image(systemName: "questionmark.app")
                            .frame(width: 20, height: 20)
                            .foregroundStyle(.secondary)
                    } else {
                        Text("—")
                            .font(.caption.weight(.bold))
                            .frame(width: 20, height: 20)
                            .foregroundStyle(.secondary)
                    }
                }
                .frame(width: 56)
            } else if entry.action == .bulkChange, let icon = newAppIcon {
                // For bulk changes, show the new app's icon
                Image(nsImage: icon)
                    .resizable()
                    .interpolation(.high)
                    .frame(width: 32, height: 32)
            } else {
                ZStack {
                    Circle()
                        .fill(iconColor.opacity(0.15))
                        .frame(width: 36, height: 36)

                    Image(systemName: iconName)
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(iconColor)
                }
            }

            VStack(alignment: .leading, spacing: 3) {
                HStack(spacing: 6) {
                    Text(targetDisplay)
                        .font(.body.weight(.medium))

                    if let detail = actionDetail {
                        Text(detail)
                            .font(.body)
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                    }
                }
            }

            Spacer()

            Text(formattedTime)
                .font(.caption)
                .foregroundStyle(.tertiary)

            if entry.canUndo {
                Button {
                    viewModel.undoActivity(entry)
                } label: {
                    Image(systemName: "arrow.uturn.backward")
                }
                .buttonStyle(.borderless)
                .help("Undo this change")
            } else if isFromNone {
                Image(systemName: "arrow.uturn.backward")
                    .foregroundStyle(.quaternary)
                    .help("Cannot undo: macOS doesn't support removing default handlers")
            }
        }
        .padding(.vertical, 10)
    }

    var isFromNone: Bool {
        switch entry.action {
        case .setFileTypeHandler, .setSchemeHandler:
            return entry.oldValue == nil && entry.newValue != nil
        default:
            return false
        }
    }

    var showsAppIcons: Bool {
        // Show A → B format for individual handler changes
        // Colored circle for backup/restore/bulk actions
        switch entry.action {
        case .setFileTypeHandler, .setSchemeHandler:
            return true
        case .bulkChange, .restore, .createBackup:
            return false
        }
    }

    var targetDisplay: String {
        switch entry.action {
        case .setFileTypeHandler: return ".\(entry.target)"
        case .setSchemeHandler: return "\(entry.target)://"
        case .bulkChange:
            let count = Int(entry.target) ?? 0
            return "Changed \(count) \(count == 1 ? "file type" : "file types")"
        case .restore: return "Restored backup"
        case .createBackup: return "Created backup"
        }
    }

    var actionDetail: String? {
        switch entry.action {
        case .setFileTypeHandler, .setSchemeHandler:
            let from = entry.oldValue ?? "none"
            let to = entry.newValue ?? "none"
            return "\(from) → \(to)"
        case .bulkChange:
            return "to \(entry.newValue ?? "unknown")"
        case .restore:
            return entry.target
        case .createBackup:
            return nil
        }
    }

    var iconName: String {
        switch entry.action {
        case .setFileTypeHandler: return "doc"
        case .setSchemeHandler: return "link"
        case .bulkChange: return "square.stack.3d.up"
        case .restore: return "arrow.counterclockwise"
        case .createBackup: return "arrow.down.doc"
        }
    }

    var iconColor: Color {
        switch entry.action {
        case .setFileTypeHandler: return .blue
        case .setSchemeHandler: return .purple
        case .bulkChange: return .indigo
        case .restore: return .orange
        case .createBackup: return .green
        }
    }

    var formattedTime: String {
        let calendar = Calendar.current
        if calendar.isDateInToday(entry.timestamp) {
            return entry.timestamp.formatted(date: .omitted, time: .shortened)
        } else {
            return entry.timestamp.formatted(date: .abbreviated, time: .shortened)
        }
    }
}

#Preview {
    ContentView()
        .environmentObject(AppViewModel())
        .frame(width: 900, height: 650)
}

