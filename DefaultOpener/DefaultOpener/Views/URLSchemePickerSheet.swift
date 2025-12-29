import SwiftUI
import AppKit

struct URLSchemePickerSheet: View {
    let scheme: String
    let currentHandler: AppInfo?
    let registeredHandlers: [AppInfo]
    let onSelect: (String) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var searchText = ""
    @State private var allApps: [AppInfo] = []
    @State private var isLoading = true
    @FocusState private var isSearchFocused: Bool

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
                        // Registered Handlers Section
                        if !filteredRegistered.isEmpty {
                            AppSection(title: "Registered for this scheme") {
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
            allApps = await AppScanner.findAllApps()
            isLoading = false
        }
    }
}
