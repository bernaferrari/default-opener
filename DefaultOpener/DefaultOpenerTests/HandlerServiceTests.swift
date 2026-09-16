import XCTest

final class HandlerServiceTests: XCTestCase {
    func testAliasRequestsPerformOneMutationAndRefreshBothRows() async throws {
        let service = FakeHandlerService()
        let mutations = HandlerMutationService(handlers: service)
        let jpg = try XCTUnwrap(HandlerTarget.fileExtension("jpg"))
        let jpeg = try XCTUnwrap(HandlerTarget.fileExtension("jpeg"))
        XCTAssertEqual(jpg, jpeg)
        let result = await mutations.apply([
            HandlerMutationRequest(target: jpg, bundleID: secondApp.bundleIdentifier),
            HandlerMutationRequest(target: jpeg, bundleID: secondApp.bundleIdentifier)
        ])
        XCTAssertTrue(result.succeeded)
        XCTAssertEqual(result.changes.count, 1)
        let writes = await service.writtenTargets()
        XCTAssertEqual(writes, [jpg])
        let catalog = try await service.associations(extensions: ["jpg", "jpeg"], schemes: [])
        XCTAssertEqual(catalog.fileTypes.map { $0.defaultHandler?.bundleIdentifier }, [secondApp.bundleIdentifier, secondApp.bundleIdentifier])
        XCTAssertEqual(catalog.snapshot.fileTypes, ["public.jpeg": secondApp.bundleIdentifier])
    }

    func testUndoRejectsLiveThirdPartyChangeDespiteIdenticalDisplayNames() async throws {
        let target = HandlerTarget.contentType("public.jpeg")
        let service = FakeHandlerService(defaults: [target: thirdApp])
        let result = await HandlerMutationService(handlers: service).apply([
            HandlerMutationRequest(target: target, bundleID: firstApp.bundleIdentifier, expectation: .matches(secondApp.bundleIdentifier))
        ])
        XCTAssertFalse(result.succeeded)
        XCTAssertEqual(result.failures.count, 1)
        let current = await service.currentHandler(for: target)
        let writes = await service.writtenTargets()
        XCTAssertEqual(current?.bundleIdentifier, thirdApp.bundleIdentifier)
        XCTAssertTrue(writes.isEmpty)
    }

    func testUndoRestoresRecordedIdentityWhenNamesAreIdentical() async {
        let target = HandlerTarget.contentType("public.jpeg")
        let service = FakeHandlerService(defaults: [target: secondApp])
        let result = await HandlerMutationService(handlers: service).apply([
            HandlerMutationRequest(target: target, bundleID: firstApp.bundleIdentifier, expectation: .matches(secondApp.bundleIdentifier))
        ])
        XCTAssertTrue(result.succeeded)
        let current = await service.currentHandler(for: target)
        XCTAssertEqual(current?.bundleIdentifier, firstApp.bundleIdentifier)
    }

    func testPartialFailureRetainsSuccessAndNamesFailedTarget() async {
        let file = HandlerTarget.contentType("public.jpeg")
        let url = HandlerTarget.urlScheme("https")
        let service = FakeHandlerService()
        await service.reject(url)
        let result = await HandlerMutationService(handlers: service).apply([
            HandlerMutationRequest(target: file, bundleID: secondApp.bundleIdentifier),
            HandlerMutationRequest(target: url, bundleID: secondApp.bundleIdentifier)
        ])
        XCTAssertFalse(result.succeeded)
        XCTAssertEqual(result.changes.count, 1)
        XCTAssertEqual(result.failures.map(\.target), [url])
        let current = await service.currentHandler(for: url)
        XCTAssertEqual(current?.bundleIdentifier, firstApp.bundleIdentifier)
    }

    func testConflictingAliasTargetsAreRejectedBeforeAnyWrite() async {
        let target = HandlerTarget.contentType("public.jpeg")
        let service = FakeHandlerService()
        let result = await HandlerMutationService(handlers: service).apply([
            HandlerMutationRequest(target: target, bundleID: firstApp.bundleIdentifier),
            HandlerMutationRequest(target: target, bundleID: secondApp.bundleIdentifier)
        ])
        XCTAssertEqual(result.failures.count, 1)
        let writes = await service.writtenTargets()
        XCTAssertTrue(writes.isEmpty)
    }

    func testSuccessfulCallbackWithoutChangedDefaultIsNotReportedAsSuccess() async {
        let target = HandlerTarget.contentType("public.jpeg")
        let service = FakeHandlerService()
        await service.ignoreWrite(target)
        let result = await HandlerMutationService(handlers: service).apply([
            HandlerMutationRequest(target: target, bundleID: secondApp.bundleIdentifier)
        ])
        XCTAssertFalse(result.succeeded)
        XCTAssertTrue(result.changes.isEmpty)
    }

    func testAlreadySelectedHandlerDoesNotCreateUndoRecordOrWrite() async {
        let target = HandlerTarget.contentType("public.jpeg")
        let service = FakeHandlerService()
        let result = await HandlerMutationService(handlers: service).apply([
            HandlerMutationRequest(target: target, bundleID: firstApp.bundleIdentifier)
        ])
        XCTAssertTrue(result.succeeded)
        XCTAssertEqual(result.unchanged, [target])
        XCTAssertTrue(result.changes.isEmpty)
        let writes = await service.writtenTargets()
        XCTAssertTrue(writes.isEmpty)
    }
    func testConcurrentBatchesSerializeTheirReadWriteAndVerification() async {
        let target = HandlerTarget.contentType("public.jpeg")
        let service = FakeHandlerService()
        let mutations = HandlerMutationService(handlers: service)
        await service.pauseNextMutation()
        let first = Task {
            await mutations.apply([HandlerMutationRequest(target: target, bundleID: secondApp.bundleIdentifier,
                expectation: .matches(firstApp.bundleIdentifier))])
        }
        await service.waitUntilMutationStarts()
        let second = Task {
            await mutations.apply([HandlerMutationRequest(target: target, bundleID: thirdApp.bundleIdentifier,
                expectation: .matches(firstApp.bundleIdentifier))])
        }
        await service.resumeMutation()
        let firstResult = await first.value
        let secondResult = await second.value
        XCTAssertTrue(firstResult.succeeded)
        XCTAssertFalse(secondResult.succeeded)
        let writes = await service.writtenTargets()
        XCTAssertEqual(writes, [target])
        let current = await service.currentHandler(for: target)
        XCTAssertEqual(current?.bundleIdentifier, secondApp.bundleIdentifier)
    }

}
