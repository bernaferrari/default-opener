import SwiftUI
import AppKit

struct AppBadge: View {
    let app: AppInfo

    var body: some View {
        HStack(spacing: 6) {
            if let icon = app.icon {
                Image(nsImage: icon)
                    .resizable()
                    .interpolation(.high)
                    .frame(width: 20, height: 20)
            }
            Text(app.name)
                .font(.subheadline)
                .lineLimit(1)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(Color(nsColor: .controlBackgroundColor))
        .clipShape(RoundedRectangle(cornerRadius: 6))
    }
}
