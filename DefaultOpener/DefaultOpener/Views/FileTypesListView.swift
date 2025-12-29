import SwiftUI
import AppKit

struct FileTypesListView: View {
    let fileTypes: [FileTypeAssociation]
    let title: String
    @EnvironmentObject var viewModel: AppViewModel
    @State private var selectedTypes: Set<String> = []
    @State private var showingBulkChange = false
    @State private var isSelectionMode = false
    @State private var expandedItems: Set<String> = []

    private var showSections: Bool {
        title == "All File Types" && viewModel.searchText.isEmpty
    }

    private var groupedFileTypes: [(String, [FileTypeAssociation])] {
        let grouped = Dictionary(grouping: fileTypes) { fileType in
            String(fileType.fileExtension.prefix(1)).uppercased()
        }
        return grouped.sorted { $0.key < $1.key }
    }

    var body: some View {
        VStack(spacing: 0) {
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
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 0) {
                        if showSections {
                            ForEach(Array(groupedFileTypes.enumerated()), id: \.1.0) { sectionIndex, group in
                                let (letter, types) = group
                                sectionHeader(letter: letter)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                    .padding(.horizontal, 16)
                                    .padding(.top, sectionIndex == 0 ? 0 : 8)

                                ForEach(Array(types.enumerated()), id: \.1.id) { itemIndex, fileType in
                                    fileTypeRow(for: fileType, showDivider: !(sectionIndex == 0 && itemIndex == 0))
                                        .padding(.horizontal, 16)
                                }
                            }
                        } else {
                            ForEach(Array(fileTypes.enumerated()), id: \.1.id) { index, fileType in
                                fileTypeRow(for: fileType, showDivider: index != 0)
                                    .padding(.horizontal, 16)
                            }
                        }
                    }
                    .padding(.vertical, 4)
                }
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

    @ViewBuilder
    private func sectionHeader(letter: String) -> some View {
        Text(letter)
            .font(.headline)
            .foregroundStyle(.primary)
            .padding(.leading, 30)
            .padding(.vertical, 8)
    }

    @ViewBuilder
    private func fileTypeRow(for fileType: FileTypeAssociation, showDivider: Bool = true) -> some View {
        VStack(spacing: 0) {
            if showDivider {
                Divider()
                    .padding(.leading, 30)
            }
            FileTypeRow(
                fileType: fileType,
                isExpanded: expandedItems.contains(fileType.id),
                isSelected: selectedTypes.contains(fileType.id),
                isSelectionMode: isSelectionMode,
                onToggleExpansion: {
                    withAnimation(.snappy(duration: 0.25)) {
                        if expandedItems.contains(fileType.id) {
                            expandedItems.remove(fileType.id)
                        } else {
                            expandedItems.insert(fileType.id)
                        }
                    }
                },
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
}

struct FileTypeRow: View {
    let fileType: FileTypeAssociation
    var isExpanded: Bool = false
    var isSelected: Bool = false
    var isSelectionMode: Bool = false
    var onToggleExpansion: (() -> Void)? = nil
    var onToggleSelection: (() -> Void)? = nil
    @EnvironmentObject var viewModel: AppViewModel
    @State private var showingAllApps = false

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: 10) {
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

                ExtensionBadge(ext: fileType.fileExtension)

                Image(systemName: "arrow.right")
                    .font(.system(size: 10, weight: .medium))
                    .foregroundStyle(.quaternary)

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
                        HStack(spacing: 6) {
                            Image(systemName: "questionmark.app.dashed")
                                .resizable()
                                .frame(width: 20, height: 20)
                                .foregroundStyle(.secondary)
                            Text("No default")
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                        }
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(Color.orange.opacity(0.1))
                        .clipShape(RoundedRectangle(cornerRadius: 6))
                    }
                }
                .menuStyle(.borderlessButton)
                .menuIndicator(.hidden)

                Spacer()
            }
            .padding(.vertical, 8)
            .contentShape(Rectangle())
            .onTapGesture {
                if isSelectionMode {
                    onToggleSelection?()
                } else {
                    onToggleExpansion?()
                }
            }

            if isExpanded && !isSelectionMode {
                VStack(alignment: .leading, spacing: 12) {
                    Text("Choose default app")
                        .font(.subheadline.weight(.medium))
                        .foregroundStyle(.secondary)

                    if fileType.availableHandlers.isEmpty {
                        Text("No apps registered for this file type")
                            .font(.subheadline)
                            .foregroundStyle(.tertiary)
                    }

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
                                onToggleExpansion?()
                            }
                        }

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
        .animation(.snappy(duration: 0.2), value: isSelectionMode)
        .contextMenu {
            Button {
                NSPasteboard.general.clearContents()
                NSPasteboard.general.setString(".\(fileType.fileExtension)", forType: .string)
            } label: {
                Label("Copy Extension", systemImage: "doc.on.doc")
            }

            Button {
                NSPasteboard.general.clearContents()
                NSPasteboard.general.setString(fileType.uti, forType: .string)
            } label: {
                Label("Copy UTI", systemImage: "tag")
            }

            Divider()

            Menu("Change Default") {
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
            }
        }
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
                        onToggleExpansion?()
                    }
                )
            )
        }
    }
}

#Preview {
    FileTypesListView(fileTypes: [], title: "All File Types")
        .environmentObject(AppViewModel())
        .frame(width: 600, height: 400)
}
