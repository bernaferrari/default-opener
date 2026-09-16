import Foundation

extension AppViewModel {
    func setDefaultHandler(forExtension ext: String, bundleID: String) {
        guard let target = HandlerTarget.fileExtension(ext) else {
            reportError("Couldn’t Change Default", "The file extension .\(ext) has no recognized content type.")
            lastOperationSucceeded = false
            return
        }
        startChanges([HandlerMutationRequest(target: target, bundleID: bundleID)],
            action: .setFileTypeHandler, label: target.displayName)
    }

    func setDefaultHandler(forScheme scheme: String, bundleID: String) {
        startChanges([HandlerMutationRequest(target: .urlScheme(scheme), bundleID: bundleID)],
            action: .setSchemeHandler, label: "\(scheme)://")
    }

    func bulkSetDefaultHandler(forExtensions extensions: [String], bundleID: String, appName: String) {
        var requests: [HandlerMutationRequest] = []
        var failures: [HandlerOperationFailure] = []
        for ext in extensions {
            if let target = HandlerTarget.fileExtension(ext) {
                requests.append(HandlerMutationRequest(target: target, bundleID: bundleID))
            } else {
                failures.append(HandlerOperationFailure(target: .contentType(ext),
                    message: "The file extension .\(ext) has no recognized content type."))
            }
        }
        startChanges(requests, action: .bulkChange, label: appName, initialFailures: failures)
    }

    func undoActivity(_ entry: ActivityLogEntry) {
        let requests = entry.changes.compactMap(\.undoRequest)
        let failures = entry.changes.filter { $0.undoRequest == nil }.map {
            HandlerOperationFailure(target: $0.target,
                message: "There was no previous default for \($0.target.displayName); macOS cannot remove its default through this API.")
        }
        guard !requests.isEmpty else {
            reportError("Couldn’t Undo", "This operation has no previous defaults to restore.")
            lastOperationSucceeded = false
            return
        }
        startChanges(requests, action: entry.action, label: "Undo \(entry.target)", initialFailures: failures)
    }

    func revertAllExternalChanges() {
        revertExternalChanges(externalChanges)
    }

    private func revertExternalChanges(_ changes: [ExternalChange]) {
        let requests = changes.compactMap { change -> HandlerMutationRequest? in
            guard let oldID = change.oldBundleID else { return nil }
            return HandlerMutationRequest(target: change.handlerTarget, bundleID: oldID,
                expectation: .matches(change.newBundleID))
        }
        startChanges(requests, action: .bulkChange, label: "Reverted external changes")
    }

    func startChanges(_ requests: [HandlerMutationRequest], action: ActivityLogEntry.ActionType,
                      label: String, initialFailures: [HandlerOperationFailure] = []) {
        guard beginOperation() else { return }
        operationTask = Task {
            defer { isMutating = false }
            await applyChanges(requests, action: action, label: label, initialFailures: initialFailures)
        }
    }

    /// The mutation flag is set before returning to a sheet, so it can await the real completion state.
    func beginOperation() -> Bool {
        guard !isMutating, !isLoading else { return false }
        isMutating = true
        lastOperationSucceeded = nil
        operationError = nil
        undoAction = nil
        return true
    }

    func applyChanges(_ requests: [HandlerMutationRequest], action: ActivityLogEntry.ActionType,
                      label: String, initialFailures: [HandlerOperationFailure] = []) async {
        var result = await mutations.apply(requests)
        result.failures.insert(contentsOf: initialFailures, at: 0)
        // Record only verified writes. A failed item remains available for review and retry.
        if !result.changes.isEmpty {
            await recordConfirmedChanges(result.changes)
        }
        do {
            // A write affects every alias of its UTI; a fresh catalog also reveals unrelated external changes.
            try await reloadAssociations(additionalTargets: result.unverifiedChanges.map(\.target))
            var recovered: [HandlerChangeRecord] = []
            for pending in result.unverifiedChanges {
                let current = loadedHandler(for: pending.target)
                if current?.bundleIdentifier == pending.requestedBundleID {
                    recovered.append(HandlerChangeRecord(target: pending.target, oldHandler: pending.oldHandler, newHandler: current))
                    result.failures.removeAll { $0.target == pending.target }
                }
            }
            if !recovered.isEmpty {
                result.changes += recovered
                await recordConfirmedChanges(recovered)
            }
            await detectExternalChanges()
        } catch {
            if !result.changes.isEmpty {
                await appendActivity(ActivityLogEntry(action: action, target: label, changes: result.changes))
            }
            lastOperationSucceeded = false
            reportError("Couldn’t Refresh Defaults", "\(result.changes.count) changes were confirmed, but the current defaults couldn’t be reloaded. \(error.localizedDescription)")
            showToast("Couldn’t refresh defaults")
            return
        }
        let entry = ActivityLogEntry(action: action, target: label, changes: result.changes)
        if !result.changes.isEmpty { await appendActivity(entry) }
        lastOperationSucceeded = result.succeeded
        if !result.failures.isEmpty {
            let details = result.failures.map { "\($0.target.displayName): \($0.message)" }.joined(separator: "\n")
            reportError(result.changes.isEmpty ? "Couldn’t Change Defaults" : "Some Defaults Couldn’t Be Changed", details)
            let message = "\(result.changes.count) changed; \(result.failures.count) failed"
            if entry.canUndo {
                showToast(message) { [weak self] in self?.undoActivity(entry) }
            } else { showToast(message) }
        } else if result.changes.isEmpty {
            showToast("Defaults already match")
        } else {
            let message = result.changes.count == 1 ? "Changed \(result.changes[0].target.displayName)" : "Changed \(result.changes.count) defaults"
            if entry.canUndo {
                showToast(message) { [weak self] in self?.undoActivity(entry) }
            } else { showToast(message) }
        }
    }

    func createBackup() {
        guard beginOperation() else { return }
        operationTask = Task {
            defer { isMutating = false }
            do {
                // Capture the live system rather than potentially stale UI rows.
                try await reloadAssociations()
                let snapshot = currentSnapshot
                let url = try await backupStore.createBackup(fileTypes: snapshot.fileTypes, urlSchemes: snapshot.urlSchemes)
                await appendActivity(ActivityLogEntry(action: .createBackup, target: url.lastPathComponent, changes: []))
                await loadBackups()
                await detectExternalChanges()
                lastOperationSucceeded = true
                showToast("Backup created")
            } catch {
                lastOperationSucceeded = false
                reportError("Couldn’t Create Backup", error.localizedDescription)
                showToast("Backup wasn’t created")
            }
        }
    }

    func restoreBackup(_ backup: BackupInfo) {
        guard beginOperation() else { return }
        operationTask = Task {
            defer { isMutating = false }
            do {
                let contents = try await backupStore.readBackup(at: backup.url)
                await applyChanges(contents.mutationRequests, action: .restore, label: backup.formattedDate)
            } catch {
                lastOperationSucceeded = false
                reportError("Couldn’t Restore Backup", error.localizedDescription)
                showToast("Backup wasn’t restored")
            }
        }
    }

    func inspectBackup(at url: URL) async throws -> BackupInfo {
        try await backupStore.inspectBackup(at: url)
    }

    func deleteBackup(_ backup: BackupInfo) {
        guard beginOperation() else { return }
        operationTask = Task {
            defer { isMutating = false }
            do {
                try await backupStore.trashBackup(at: backup.url)
                await loadBackups()
                lastOperationSucceeded = true
                showToast("Backup moved to Trash")
            } catch {
                lastOperationSucceeded = false
                reportError("Couldn’t Move Backup to Trash", error.localizedDescription)
                showToast("Backup wasn’t deleted")
            }
        }
    }
}
