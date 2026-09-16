import SwiftUI
import AppKit

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
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 0) {
                        ForEach(Array(schemes.enumerated()), id: \.1.id) { index, scheme in
                            if index != 0 {
                                Divider()
                                    .padding(.leading, 30)
                            }
                            URLSchemeRow(scheme: scheme)
                                .padding(.horizontal, 16)
                        }
                    }
                    .padding(.vertical, 4)
                }
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
            HStack(spacing: 10) {
                Button {
                    isExpanded.toggle()
                } label: {
                    HStack(spacing: 10) {
                        Image(systemName: isExpanded ? "chevron.down" : "chevron.right")
                            .frame(width: 20)
                        Text("\(scheme.scheme)://")
                            .font(.system(.body, design: .monospaced))
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(Color.secondary.opacity(0.1), in: RoundedRectangle(cornerRadius: 6))
                    }
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Default apps for \(scheme.scheme)")
                .accessibilityValue(isExpanded ? "Expanded" : "Collapsed")

                Image(systemName: "arrow.right")
                    .font(.system(size: 10, weight: .medium))
                    .foregroundStyle(.quaternary)

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

                Spacer()
            }
            .padding(.vertical, 8)


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
        .contextMenu {
            Button {
                NSPasteboard.general.clearContents()
                NSPasteboard.general.setString("\(scheme.scheme)://", forType: .string)
            } label: {
                Label("Copy Scheme", systemImage: "doc.on.doc")
            }

            Divider()

            Menu("Change Default") {
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
            }
        }
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

#Preview {
    URLSchemesListView(schemes: [], title: "URL Schemes")
        .environmentObject(AppViewModel())
        .environmentObject(SheetPresentationState())
        .frame(width: 600, height: 400)
}
