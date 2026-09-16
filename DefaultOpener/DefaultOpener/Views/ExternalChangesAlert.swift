import SwiftUI
import AppKit

struct ExternalChangesAlert: View {
    @EnvironmentObject var viewModel: AppViewModel
    @EnvironmentObject private var sheetPresentation: SheetPresentationState
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack(spacing: 16) {
                Image(systemName: "exclamationmark.triangle.fill")
                    .font(.system(size: 40))
                    .foregroundStyle(.orange)

                VStack(alignment: .leading, spacing: 4) {
                    Text("Defaults Changed Outside This App")
                        .font(.title2.bold())
                    Text("\(viewModel.externalChanges.count) default \(viewModel.externalChanges.count == 1 ? "handler has" : "handlers have") changed since the last check.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }

                Spacer()
            }
            .padding()

            Divider()

            // List of changes
            ScrollView {
                LazyVStack(spacing: 0) {
                    ForEach(viewModel.externalChanges) { change in
                        ExternalChangeRow(change: change)
                        if change.id != viewModel.externalChanges.last?.id {
                            Divider().padding(.leading, 16)
                        }
                    }
                }
                .padding()
            }

            Divider()

            if let error = viewModel.operationError {
                ScrollView {
                    Text(error.message)
                        .textSelection(.enabled)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding()
                }
                .frame(maxHeight: 120)
            }

            // Footer buttons
            HStack {
                Button("Keep All Changes") {
                    viewModel.dismissAllExternalChanges()
                    dismiss()
                }

                Spacer()

                Button("Revert All") {
                    viewModel.revertAllExternalChanges()
                }
                .buttonStyle(.borderedProminent)
            }
            .padding()
        }
        .disabled(viewModel.isLoading || viewModel.isMutating)
        .interactiveDismissDisabled(viewModel.isMutating)
        .onAppear { sheetPresentation.presentedCount += 1 }
        .onDisappear { sheetPresentation.presentedCount = max(0, sheetPresentation.presentedCount - 1) }
        .onChange(of: viewModel.externalChanges.isEmpty) { _, isEmpty in
            if isEmpty { dismiss() }
        }
        .frame(width: 480, height: 400)
    }
}

struct ExternalChangeRow: View {
    let change: ExternalChange
    @EnvironmentObject var viewModel: AppViewModel

    var oldAppIcon: NSImage? {
        guard let bundleID = change.oldBundleID,
              let url = NSWorkspace.shared.urlForApplication(withBundleIdentifier: bundleID) else {
            return nil
        }
        return NSWorkspace.shared.icon(forFile: url.path)
    }

    var newAppIcon: NSImage? {
        guard let bundleID = change.newBundleID,
              let url = NSWorkspace.shared.urlForApplication(withBundleIdentifier: bundleID) else {
            return nil
        }
        return NSWorkspace.shared.icon(forFile: url.path)
    }

    var body: some View {
        HStack(spacing: 12) {
            // Target (extension or scheme)
            Text(change.displayTarget)
                .font(.system(.body, design: .monospaced, weight: .medium))
                .foregroundStyle(change.type == .fileType ? .blue : .purple)
                .frame(width: 80, alignment: .leading)

            // Old app
            HStack(spacing: 4) {
                if let icon = oldAppIcon {
                    Image(nsImage: icon)
                        .resizable()
                        .interpolation(.high)
                        .frame(width: 20, height: 20)
                }
                Text(change.oldAppName ?? "None")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
            .frame(width: 100, alignment: .leading)

            Image(systemName: "arrow.right")
                .font(.caption)
                .foregroundStyle(.tertiary)

            // New app
            HStack(spacing: 4) {
                if let icon = newAppIcon {
                    Image(nsImage: icon)
                        .resizable()
                        .interpolation(.high)
                        .frame(width: 20, height: 20)
                }
                Text(change.newAppName ?? "None")
                    .font(.subheadline)
                    .lineLimit(1)
            }

            Spacer()
        }
        .padding(.vertical, 8)
    }
}
