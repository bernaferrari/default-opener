import SwiftUI
import AppKit

struct UpdateBanner: View {
    let updateInfo: UpdateInfo?
    @State private var isDismissed = false

    var body: some View {
        ZStack {
            if let info = updateInfo, info.isUpdateAvailable, !isDismissed {
                HStack(spacing: 12) {
                    Image(systemName: "arrow.down.circle.fill")
                        .font(.title2)
                        .foregroundStyle(.white)

                    VStack(alignment: .leading, spacing: 2) {
                        Text("Update Available")
                            .font(.headline)
                            .foregroundStyle(.white)
                        Text("Version \(info.latestVersion) is now available (you have \(info.currentVersion))")
                            .font(.caption)
                            .foregroundStyle(.white.opacity(0.9))
                    }

                    Spacer()

                    Button("Download") {
                        NSWorkspace.shared.open(info.releaseURL)
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(.white)
                    .foregroundStyle(.blue)

                    Button {
                        isDismissed = true
                    } label: {
                        Image(systemName: "xmark")
                            .foregroundStyle(.white.opacity(0.8))
                    }
                    .buttonStyle(.plain)
                }
                .padding()
                .background(
                    LinearGradient(
                        colors: [.blue, .purple],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                )
                .transition(.move(edge: .top).combined(with: .opacity))
            }
        }
        .animation(.spring(response: 0.4, dampingFraction: 0.8), value: isDismissed)
        .animation(.spring(response: 0.4, dampingFraction: 0.8), value: updateInfo?.latestVersion)
    }
}

#Preview {
    UpdateBanner(updateInfo: UpdateInfo(
        currentVersion: "1.0.0",
        latestVersion: "1.1.0",
        releaseURL: URL(string: "https://github.com")!,
        releaseNotes: nil
    ))
}
