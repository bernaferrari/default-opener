import SwiftUI

struct ContentView: View {
    @EnvironmentObject var viewModel: AppViewModel
    @State private var selectedSidebarItem: SidebarItem? = .allFileTypes
    @State private var refreshRotation: Double = 0
    @State private var showingExternalChanges = false

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
        .overlay(alignment: .top) {
            UpdateBanner(updateInfo: viewModel.updateInfo)
        }
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button {
                    viewModel.refresh()
                } label: {
                    Image(systemName: "arrow.clockwise")
                        .rotationEffect(.degrees(refreshRotation))
                }
                .help("Refresh")
                .disabled(viewModel.isLoading)
            }
        }
        .onChange(of: viewModel.isLoading) { _, isLoading in
            if isLoading {
                withAnimation(.linear(duration: 1).repeatForever(autoreverses: false)) {
                    refreshRotation = 360
                }
            } else {
                withAnimation(.default) {
                    refreshRotation = 0
                }
            }
        }
        .onAppear {
            if !viewModel.externalChanges.isEmpty {
                showingExternalChanges = true
            }
        }
        .sheet(isPresented: $showingExternalChanges) {
            ExternalChangesAlert()
        }
    }
}

#Preview {
    ContentView()
        .environmentObject(AppViewModel())
        .frame(width: 900, height: 650)
}
