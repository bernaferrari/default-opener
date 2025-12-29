import SwiftUI

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

#Preview {
    SidebarView(selection: .constant(.allFileTypes))
        .environmentObject(AppViewModel())
        .frame(height: 500)
}
