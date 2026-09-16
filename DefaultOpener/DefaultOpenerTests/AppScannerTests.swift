import XCTest

final class AppScannerTests: XCTestCase {
    func testOverlappingSearchRootsYieldOneRowPerBundleIdentifier() {
        let utility = AppInfo(bundleIdentifier: "test.utility", name: "Utility", path: "/System/Applications/Utilities/Utility.app")
        let result = AppScanner.deduplicateApps([utility, utility])
        XCTAssertEqual(result, [utility])
    }

    func testPreferredCopyDoesNotDependOnEnumerationOrder() {
        let system = AppInfo(bundleIdentifier: "test.editor", name: "Editor", path: "/System/Applications/Editor.app")
        let installed = AppInfo(bundleIdentifier: "test.editor", name: "Editor", path: "/Applications/Editor.app")
        let alternate = AppInfo(bundleIdentifier: "test.editor", name: "Editor", path: "/Applications/Extras/Editor.app")
        XCTAssertEqual(AppScanner.deduplicateApps([system, alternate, installed]), [installed])
        XCTAssertEqual(AppScanner.deduplicateApps([installed, alternate, system]), [installed])
    }

    func testDifferentAppsWithSameDisplayNameRemainDistinct() {
        let first = AppInfo(bundleIdentifier: "test.a", name: "Editor", path: "/Applications/A.app")
        let second = AppInfo(bundleIdentifier: "test.b", name: "Editor", path: "/Applications/B.app")
        XCTAssertEqual(AppScanner.deduplicateApps([second, first]), [first, second])
    }

    func testEmptyScanProducesEmptyResult() {
        XCTAssertTrue(AppScanner.deduplicateApps([]).isEmpty)
    }
}
