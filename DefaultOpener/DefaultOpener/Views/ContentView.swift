import SwiftUI

@MainActor
final class SheetPresentationState: ObservableObject {
    @Published var presentedCount = 0
}

struct ContentView: View {
    @EnvironmentObject var viewModel: AppViewModel
    @State private var selectedSidebarItem: SidebarItem? = .allFileTypes
    @State private var showingExternalChanges = false
    @State private var pendingExternalReview = false
    @StateObject private var sheetPresentation = SheetPresentationState()

    enum SidebarItem: Hashable {
        case allFileTypes
        case allURLSchemes
        case backups
        case category(FileCategory)
        case app(String) // bundleID
    }

    var body: some View {
        NavigationSplitView {
            SidebarView(selection: $selectedSidebarItem)
        } detail: {
            DetailView(selection: $selectedSidebarItem)
        }
        .searchable(text: $viewModel.searchText, prompt: "Search file types, apps...")
        .navigationTitle("Default Opener")
        .overlay(alignment: .bottom) {
            ToastView(message: viewModel.toastMessage, undoAction: viewModel.undoAction) {
                viewModel.performUndo()
            }
        }
        .toolbar(id: "com.bernardoferrari.default-opener.main") {
            ToolbarItem(id: "refresh", placement: .primaryAction) {
                Button {
                    viewModel.refresh()
                } label: {
                    Label("Refresh", systemImage: "arrow.clockwise")
                }
                .help("Refresh")
                .disabled(viewModel.isLoading || viewModel.isMutating)
            }
        }
        .onChange(of: viewModel.externalChanges.isEmpty, initial: true) { _, isEmpty in
            pendingExternalReview = !isEmpty && !showingExternalChanges
            presentPendingExternalReview()
        }
        .onChange(of: sheetPresentation.presentedCount) { _, _ in presentPendingExternalReview() }
        .onChange(of: viewModel.isMutating) { _, _ in presentPendingExternalReview() }
        .onChange(of: viewModel.operationError?.id) { _, _ in presentPendingExternalReview() }
        .alert(item: Binding(
            get: { sheetPresentation.presentedCount == 0 && !showingExternalChanges ? viewModel.operationError : nil },
            set: { value in
                if sheetPresentation.presentedCount == 0 && !showingExternalChanges { viewModel.operationError = value }
            }
        )) { error in
            Alert(title: Text(error.title), message: Text(error.message), dismissButton: .default(Text("OK")))
        }
        .sheet(isPresented: $showingExternalChanges) {
            ExternalChangesAlert()
        }
        .environmentObject(sheetPresentation)
        .frame(minWidth: 820, minHeight: 640)

    }

    private func presentPendingExternalReview() {
        guard pendingExternalReview, !showingExternalChanges,
              sheetPresentation.presentedCount == 0,
              !viewModel.isMutating, viewModel.operationError == nil else { return }
        pendingExternalReview = false
        showingExternalChanges = true
    }

}

#Preview {
    ContentView()
        .environmentObject(AppViewModel())
        .frame(width: 900, height: 650)
}
