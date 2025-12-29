import SwiftUI

struct ExtensionBadge: View {
    let ext: String

    var color: Color {
        switch FileCategory.category(for: ext) {
        case .code: return .blue
        case .documents: return .orange
        case .images: return .purple
        case .video: return .red
        case .audio: return .pink
        case .archives: return .brown
        }
    }

    var body: some View {
        Text(".\(ext)")
            .font(.system(.body, design: .monospaced, weight: .medium))
            .foregroundStyle(color)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(color.opacity(0.1))
            .clipShape(RoundedRectangle(cornerRadius: 6))
            .frame(minWidth: 60, alignment: .leading)
    }
}

#Preview {
    HStack(spacing: 12) {
        ExtensionBadge(ext: "swift")
        ExtensionBadge(ext: "pdf")
        ExtensionBadge(ext: "png")
        ExtensionBadge(ext: "mp4")
        ExtensionBadge(ext: "mp3")
        ExtensionBadge(ext: "zip")
    }
    .padding()
}
