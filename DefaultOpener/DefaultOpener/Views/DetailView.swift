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
        .disabled(viewModel.isLoading || viewModel.isMutating)
        .overlay {
            if viewModel.isLoading || viewModel.isMutating {
                VStack(spacing: 12) {
                    ProgressView()
                        .scaleEffect(1.5)
                    Text(viewModel.isMutating ? "Applying changes…" : "Loading…")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(.ultraThinMaterial)
            }
        }
    }
}

#Preview {
    DetailView(selection: .constant(.allFileTypes))
        .environmentObject(AppViewModel())
        .environmentObject(SheetPresentationState())
        .frame(width: 600, height: 400)
}
