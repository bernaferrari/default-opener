import SwiftUI

struct AppFileTypesView: View {
    let bundleID: String
    @Binding var selection: ContentView.SidebarItem?
    @EnvironmentObject var viewModel: AppViewModel
    @State private var showingBulkChange = false
    @State private var expandedItems: Set<String> = []

    var app: AppInfo? {
        viewModel.uniqueApps.first { $0.bundleIdentifier == bundleID }
    }

    var handledFileTypes: [FileTypeAssociation] {
        viewModel.fileTypes.filter { $0.defaultHandler?.bundleIdentifier == bundleID }
    }

    var body: some View {
        VStack(spacing: 0) {
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

            ScrollView {
                LazyVStack(alignment: .leading, spacing: 0) {
                    ForEach(Array(handledFileTypes.enumerated()), id: \.1.id) { index, fileType in
                        if index != 0 {
                            Divider()
                                .padding(.leading, 30)
                        }
                        FileTypeRow(
                            fileType: fileType,
                            isExpanded: expandedItems.contains(fileType.id),
                            onToggleExpansion: {
                                withAnimation(.snappy(duration: 0.25)) {
                                    if expandedItems.contains(fileType.id) {
                                        expandedItems.remove(fileType.id)
                                    } else {
                                        expandedItems.insert(fileType.id)
                                    }
                                }
                            }
                        )
                            .padding(.horizontal, 16)
                    }
                }
                .padding(.vertical, 4)
            }
        }
        .navigationTitle(app?.name ?? "App")
        .sheet(isPresented: $showingBulkChange) {
            AppPickerSheet(
                mode: .bulk(
                    extensions: handledFileTypes.map(\.fileExtension),
                    currentApp: app,
                    onComplete: {
                        selection = .allFileTypes
                    }
                )
            )
        }
    }
}

#Preview {
    AppFileTypesView(bundleID: "com.apple.TextEdit", selection: .constant(nil))
        .environmentObject(AppViewModel())
        .frame(width: 600, height: 400)
}
