import SwiftUI

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

#Preview {
    NoSearchResultsView(searchText: "xcode") {}
        .frame(width: 400, height: 300)
}
