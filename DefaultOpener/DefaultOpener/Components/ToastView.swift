import SwiftUI

struct ToastView: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
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
                        .foregroundStyle(.primary)

                    if undoAction != nil {
                        Button("Undo") {
                            onUndo()
                        }
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.primary)
                    }
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 10)
                .background(Color(nsColor: .windowBackgroundColor))
                .clipShape(Capsule())
                .shadow(color: .black.opacity(0.15), radius: 8, y: 4)
                .transition(reduceMotion ? .identity : .opacity)
            }
        }
        .padding(.bottom, 20)
        .animation(reduceMotion ? nil : .easeOut(duration: 0.2), value: message)
    }
}

#Preview("With Undo") {
    ToastView(message: "Changed .json to VS Code", undoAction: {})
}

#Preview("Without Undo") {
    ToastView(message: "Backup created")
}
