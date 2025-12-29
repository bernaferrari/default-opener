import SwiftUI

struct DetailView: View {
    @Binding var selection: ContentView.SidebarItem?
    @EnvironmentObject var viewModel: AppViewModel

    var body: some View {
        Group {
            switch selection {
            case .allFileTypes:
                FileTypesListView(fileTypes: viewModel.filteredFileTypes, title: "All File Types")
            case .allURLSchemes:
                URLSchemesListView(schemes: viewModel.filteredURLSchemes, title: "URL Schemes")
            case .backups:
                BackupsView()
            case .category(let category):
                FileTypesListView(
                    fileTypes: viewModel.fileTypes(for: category),
                    title: category.rawValue
                )
            case .app(let bundleID):
                AppFileTypesView(bundleID: bundleID, selection: $selection)
            case nil:
                Text("Select an item from the sidebar")
                    .foregroundStyle(.secondary)
            }
        }
        .overlay {
            if viewModel.isLoading {
                VStack(spacing: 12) {
                    ProgressView()
                        .scaleEffect(1.5)
                    Text("Loading...")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(.ultraThinMaterial)
                .allowsHitTesting(false)
            }
        }
    }
}

#Preview {
    DetailView(selection: .constant(.allFileTypes))
        .environmentObject(AppViewModel())
        .frame(width: 600, height: 400)
}
