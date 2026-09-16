import XCTest

@MainActor
final class AppViewModelTests: XCTestCase {
    private func store() throws -> BackupManager {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent("DefaultOpenerModelTests-\(UUID().uuidString)")
        addTeardownBlock { try? FileManager.default.removeItem(at: directory) }
        return BackupManager(directory: directory)
    }

    func testAliasChangeUpdatesAllRowsAndProducesOneUndoRecord() async throws {
        let service = FakeHandlerService()
        let model = AppViewModel(handlers: service, backups: try store(), stateStore: MemoryStateStore(), automaticallyLoad: false)
        await model.load()
        model.setDefaultHandler(forExtension: "jpg", bundleID: secondApp.bundleIdentifier)
        await model.waitForOperation()
        let aliases = model.fileTypes.filter { $0.uti == "public.jpeg" }
        XCTAssertGreaterThanOrEqual(aliases.count, 2)
        XCTAssertTrue(aliases.allSatisfy { $0.defaultHandler?.bundleIdentifier == secondApp.bundleIdentifier })
        XCTAssertEqual(model.activityLog.first?.changes.count, 1)
        XCTAssertEqual(model.lastOperationSucceeded, true)
    }

    func testFailedExternalRevertKeepsAlertAndReportsError() async throws {
        let target = HandlerTarget.contentType("public.jpeg")
        let service = FakeHandlerService(defaults: [target: secondApp])
        let snapshot = HandlerSnapshot(timestamp: Date(), fileTypes: ["public.jpeg": firstApp.bundleIdentifier], urlSchemes: [:])
        let model = AppViewModel(handlers: service, backups: try store(), stateStore: MemoryStateStore(snapshot: snapshot), automaticallyLoad: false)
        await model.load()
        XCTAssertTrue(model.externalChangeDetectionComplete)
        XCTAssertEqual(model.externalChanges.count, 1)
        await service.reject(target)
        model.revertAllExternalChanges()
        await model.waitForOperation()
        XCTAssertEqual(model.externalChanges.count, 1)
        XCTAssertNotNil(model.operationError)
        XCTAssertEqual(model.lastOperationSucceeded, false)
        XCTAssertTrue(model.activityLog.isEmpty)
    }

    func testToastUndoChecksCurrentHandlerRatherThanCachedRow() async throws {
        let target = HandlerTarget.contentType("public.jpeg")
        let service = FakeHandlerService()
        let model = AppViewModel(handlers: service, backups: try store(), stateStore: MemoryStateStore(), automaticallyLoad: false)
        await model.load()
        model.setDefaultHandler(forExtension: "jpg", bundleID: secondApp.bundleIdentifier)
        await model.waitForOperation()
        XCTAssertNotNil(model.undoAction)
        await service.replaceExternally(target, with: thirdApp)
        model.performUndo()
        await model.waitForOperation()
        let current = await service.currentHandler(for: target)
        XCTAssertEqual(current?.bundleIdentifier, thirdApp.bundleIdentifier)
        XCTAssertNotNil(model.operationError)
        XCTAssertEqual(model.activityLog.count, 1)
    }

    func testBulkUndoUpdatesBaselineSoRestartDoesNotReportOwnChanges() async throws {
        let service = FakeHandlerService()
        let backups = try store()
        let state = MemoryStateStore()
        let model = AppViewModel(handlers: service, backups: backups, stateStore: state, automaticallyLoad: false)
        await model.load()
        model.bulkSetDefaultHandler(forExtensions: ["jpg", "jpeg"], bundleID: secondApp.bundleIdentifier, appName: secondApp.name)
        await model.waitForOperation()
        let entry = try XCTUnwrap(model.activityLog.first)
        model.undoActivity(entry)
        await model.waitForOperation()
        let relaunched = AppViewModel(handlers: service, backups: backups, stateStore: state, automaticallyLoad: false)
        await relaunched.load()
        XCTAssertTrue(relaunched.externalChanges.isEmpty)
        XCTAssertEqual(relaunched.fileTypes.first { $0.fileExtension == "jpg" }?.defaultHandler?.bundleIdentifier, firstApp.bundleIdentifier)
    }

    func testBackupRestoreUpdatesBaselineAndReportsNoFalseExternalChange() async throws {
        let service = FakeHandlerService()
        let backups = try store()
        let state = MemoryStateStore()
        let backupURL = try await backups.createBackup(fileTypes: ["public.jpeg": secondApp.bundleIdentifier], urlSchemes: [:])
        let info = try await backups.inspectBackup(at: backupURL)
        let model = AppViewModel(handlers: service, backups: backups, stateStore: state, automaticallyLoad: false)
        await model.load()
        model.restoreBackup(info)
        await model.waitForOperation()
        XCTAssertEqual(model.lastOperationSucceeded, true)
        let relaunched = AppViewModel(handlers: service, backups: backups, stateStore: state, automaticallyLoad: false)
        await relaunched.load()
        XCTAssertTrue(relaunched.externalChanges.isEmpty)
        XCTAssertEqual(relaunched.fileTypes.first { $0.fileExtension == "jpeg" }?.defaultHandler?.bundleIdentifier, secondApp.bundleIdentifier)
    }

    func testUnrelatedExternalChangeIsNotAcknowledgedByOurMutation() async throws {
        let service = FakeHandlerService()
        let state = MemoryStateStore()
        let backups = try store()
        let model = AppViewModel(handlers: service, backups: backups, stateStore: state, automaticallyLoad: false)
        await model.load()
        await service.replaceExternally(.urlScheme("https"), with: thirdApp)
        model.setDefaultHandler(forExtension: "jpg", bundleID: secondApp.bundleIdentifier)
        await model.waitForOperation()
        let relaunched = AppViewModel(handlers: service, backups: backups, stateStore: state, automaticallyLoad: false)
        await relaunched.load()
        XCTAssertEqual(relaunched.externalChanges.map(\.handlerTarget), [.urlScheme("https")])
    }

    func testFailedDiscoveryDoesNotReplaceSavedBaseline() async throws {
        let service = FakeHandlerService()
        await service.failDiscovery(true)
        let snapshot = HandlerSnapshot(timestamp: Date(), fileTypes: ["public.jpeg": thirdApp.bundleIdentifier], urlSchemes: [:])
        let state = MemoryStateStore(snapshot: snapshot)
        let model = AppViewModel(handlers: service, backups: try store(), stateStore: state, automaticallyLoad: false)
        await model.load()
        XCTAssertNotNil(model.operationError)
        XCTAssertFalse(model.externalChangeDetectionComplete)
        let saved = await state.load()
        XCTAssertEqual(saved.snapshot?.fileTypes, snapshot.fileTypes)
    }
    func testPartialRestoreKeepsFailureVisibleAndPersistsOnlyConfirmedChanges() async throws {
        let service = FakeHandlerService()
        let backups = try store()
        let state = MemoryStateStore()
        let url = try await backups.createBackup(fileTypes: ["public.jpeg": secondApp.bundleIdentifier],
            urlSchemes: ["https": secondApp.bundleIdentifier])
        let info = try await backups.inspectBackup(at: url)
        let model = AppViewModel(handlers: service, backups: backups, stateStore: state, automaticallyLoad: false)
        await model.load()
        await service.reject(.urlScheme("https"))
        model.restoreBackup(info)
        await model.waitForOperation()
        XCTAssertEqual(model.lastOperationSucceeded, false)
        XCTAssertTrue(model.operationError?.message.contains("https") == true)
        XCTAssertNotNil(model.undoAction, "Confirmed changes must remain undoable after a partial failure")
        XCTAssertEqual(model.activityLog.first?.changes.count, 1)
        let saved = await state.load()
        XCTAssertEqual(saved.snapshot?.fileTypes["public.jpeg"], secondApp.bundleIdentifier)
        XCTAssertEqual(saved.snapshot?.urlSchemes["https"], firstApp.bundleIdentifier)
    }

    func testBusyOperationRejectsSecondWriteAndPreservesFirstCompletion() async throws {
        let service = FakeHandlerService()
        let model = AppViewModel(handlers: service, backups: try store(), stateStore: MemoryStateStore(), automaticallyLoad: false)
        await model.load()
        await service.pauseNextMutation()
        model.setDefaultHandler(forExtension: "jpg", bundleID: secondApp.bundleIdentifier)
        XCTAssertTrue(model.isMutating)
        await service.waitUntilMutationStarts()
        model.setDefaultHandler(forScheme: "https", bundleID: thirdApp.bundleIdentifier)
        await service.resumeMutation()
        await model.waitForOperation()
        XCTAssertFalse(model.isMutating)
        XCTAssertEqual(model.lastOperationSucceeded, true)
        let current = await service.currentHandler(for: .urlScheme("https"))
        XCTAssertEqual(current?.bundleIdentifier, firstApp.bundleIdentifier)
    }

    func testCatalogConfirmsChangeAfterStaleImmediateVerification() async throws {
        let service = FakeHandlerService()
        let state = MemoryStateStore()
        let model = AppViewModel(handlers: service, backups: try store(), stateStore: state, automaticallyLoad: false)
        await model.load()
        await service.useStaleVerificationOnce()
        model.setDefaultHandler(forExtension: "jpg", bundleID: secondApp.bundleIdentifier)
        await model.waitForOperation()
        XCTAssertEqual(model.lastOperationSucceeded, true)
        XCTAssertNil(model.operationError)
        XCTAssertEqual(model.activityLog.first?.changes.count, 1)
        XCTAssertTrue(model.externalChanges.isEmpty)
        let saved = await state.load()
        XCTAssertEqual(saved.snapshot?.fileTypes["public.jpeg"], secondApp.bundleIdentifier)
    }

    func testRestoredCustomSchemeSurvivesDetectionAndNextBackup() async throws {
        let service = FakeHandlerService()
        let state = MemoryStateStore()
        let backups = try store()
        let url = try await backups.createBackup(fileTypes: [:], urlSchemes: ["custom-test": secondApp.bundleIdentifier])
        let info = try await backups.inspectBackup(at: url)
        let model = AppViewModel(handlers: service, backups: backups, stateStore: state, automaticallyLoad: false)
        await model.load()
        model.restoreBackup(info)
        await model.waitForOperation()
        XCTAssertEqual(model.lastOperationSucceeded, true)
        XCTAssertTrue(model.externalChanges.isEmpty)
        let relaunched = AppViewModel(handlers: service, backups: backups, stateStore: state, automaticallyLoad: false)
        await relaunched.load()
        XCTAssertTrue(relaunched.externalChanges.isEmpty)
        relaunched.createBackup()
        await relaunched.waitForOperation()
        let latest = try XCTUnwrap(relaunched.backups.first)
        let contents = try await backups.readBackup(at: latest.url)
        XCTAssertEqual(contents.urlSchemes["custom-test"], secondApp.bundleIdentifier)
    }

}
