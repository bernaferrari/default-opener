import SwiftUI
import AppKit

struct BackupsView: View {
    @EnvironmentObject var viewModel: AppViewModel
    @State private var showingRestoreConfirm = false
    @State private var backupToRestore: BackupInfo?
    @State private var showingImportError = false
    @State private var importError = ""

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Backups")
                        .font(.title2.bold())
                    Text("Save and restore your file associations")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }

                Spacer()

                Button {
                    importBackup()
                } label: {
                    Label("Import...", systemImage: "square.and.arrow.down")
                }

                Button {
                    viewModel.createBackup()
                } label: {
                    Label("Create Backup", systemImage: "plus")
                }
                .buttonStyle(.borderedProminent)
            }
            .padding()
            .background(Color(nsColor: .windowBackgroundColor))

            Divider()

            if viewModel.backups.isEmpty {
                VStack(spacing: 16) {
                    Spacer()
                    Image(systemName: "clock.arrow.circlepath")
                        .font(.system(size: 48))
                        .foregroundStyle(.secondary)
                    Text("No Backups")
                        .font(.title2.bold())
                    Text("Create a backup to save your current file associations")
                        .foregroundStyle(.secondary)
                    HStack(spacing: 12) {
                        Button("Import...") {
                            importBackup()
                        }
                        Button("Create Backup") {
                            viewModel.createBackup()
                        }
                        .buttonStyle(.borderedProminent)
                    }
                    Spacer()
                }
            } else {
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 0) {
                        ForEach(Array(viewModel.backups.enumerated()), id: \.1.id) { index, backup in
                            if index != 0 {
                                Divider()
                                    .padding(.leading, 30)
                            }
                            BackupRow(
                                backup: backup,
                                onRestore: {
                                    backupToRestore = backup
                                    showingRestoreConfirm = true
                                },
                                onReveal: {
                                    NSWorkspace.shared.selectFile(backup.url.path, inFileViewerRootedAtPath: "")
                                },
                                onDelete: {
                                    viewModel.deleteBackup(backup)
                                }
                            )
                            .padding(.horizontal, 16)
                        }
                    }
                    .padding(.vertical, 4)
                }
            }
        }
        .confirmationDialog(
            "Restore Backup?",
            isPresented: $showingRestoreConfirm,
            presenting: backupToRestore
        ) { backup in
            Button("Restore") {
                viewModel.restoreBackup(backup)
            }
            Button("Cancel", role: .cancel) {}
        } message: { backup in
            Text("This will restore \(backup.fileTypesCount) file types and \(backup.schemesCount) URL schemes from \(backup.formattedDate)")
        }
        .alert("Import Failed", isPresented: $showingImportError) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(importError)
        }
    }

    private func importBackup() {
        let panel = NSOpenPanel()
        panel.allowedContentTypes = [.json]
        panel.canChooseFiles = true
        panel.canChooseDirectories = false
        panel.allowsMultipleSelection = false
        panel.message = "Select a Default Opener backup file to restore"

        if panel.runModal() == .OK, let url = panel.url {
            do {
                let fileManager = FileManager.default
                let data = try Data(contentsOf: url)

                let decoder = JSONDecoder()
                decoder.dateDecodingStrategy = .iso8601
                let backup = try decoder.decode(AssociationsBackup.self, from: data)

                let attributes = try fileManager.attributesOfItem(atPath: url.path)
                let size = attributes[.size] as? Int ?? 0

                let backupInfo = BackupInfo(
                    url: url,
                    createdAt: backup.createdAt,
                    macOSVersion: backup.macOSVersion,
                    fileTypesCount: backup.fileTypes.count,
                    schemesCount: backup.urlSchemes.count,
                    fileSize: size
                )

                backupToRestore = backupInfo
                showingRestoreConfirm = true
            } catch {
                importError = "Failed to read backup: \(error.localizedDescription)"
                showingImportError = true
            }
        }
    }
}

struct BackupRow: View {
    let backup: BackupInfo
    let onRestore: () -> Void
    let onReveal: () -> Void
    let onDelete: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: "doc.zipper")
                .font(.title2)
                .foregroundStyle(.blue)
                .frame(width: 32)

            VStack(alignment: .leading, spacing: 4) {
                Text(backup.formattedDate)
                    .font(.headline)

                HStack(spacing: 12) {
                    Label("\(backup.fileTypesCount) file types", systemImage: "doc.fill")
                    Label("\(backup.schemesCount) schemes", systemImage: "link")
                    Text(backup.formattedSize)
                }
                .font(.caption)
                .foregroundStyle(.secondary)
            }

            Spacer()

            Button {
                onReveal()
            } label: {
                Image(systemName: "folder")
            }
            .help("Reveal in Finder")

            Button("Restore") {
                onRestore()
            }

            Button(role: .destructive) {
                onDelete()
            } label: {
                Image(systemName: "trash")
            }
        }
        .padding(.vertical, 4)
    }
}

#Preview("Empty State") {
    BackupsView()
        .environmentObject(AppViewModel())
        .frame(width: 600, height: 400)
}
