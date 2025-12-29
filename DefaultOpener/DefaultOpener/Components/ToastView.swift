import SwiftUI

struct ToastView: View {
    let message: String?
    let undoAction: (() -> Void)?
    let onUndo: () -> Void

    init(message: String?, undoAction: (() -> Void)? = nil, onUndo: @escaping () -> Void = {}) {
        self.message = message
        self.undoAction = undoAction
        self.onUndo = onUndo
    }

    var body: some View {
        ZStack {
            if let message = message {
                HStack(spacing: 12) {
                    Text(message)
                        .font(.subheadline.weight(.medium))
                        .foregroundStyle(.white)

                    if undoAction != nil {
                        Button("Undo") {
                            onUndo()
                        }
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.white)
                    }
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 10)
                .background(Color.accentColor)
                .clipShape(Capsule())
                .shadow(color: .black.opacity(0.15), radius: 8, y: 4)
                .transition(.move(edge: .bottom).combined(with: .opacity))
            }
        }
        .padding(.bottom, 20)
        .animation(.spring(response: 0.3, dampingFraction: 0.7), value: message)
    }
}

#Preview("With Undo") {
    ToastView(message: "Changed .json to VS Code", undoAction: {})
}

#Preview("Without Undo") {
    ToastView(message: "Backup created")
}
