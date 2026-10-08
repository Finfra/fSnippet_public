//
//  PlaceholderHistoryCallbackTests.swift
//  fSnippetCliTests
//
//  Issue250: in placeholder callback mode, a history selection lands in the focused field (ex: cname)
//  and the placeholder window regains key afterwards (regression for Issue991 / e185cf1).
//

import XCTest
@testable import fSnippetCli

final class PlaceholderHistoryCallbackTests: XCTestCase {

    private func makeViewModel(focusIndex: Int) -> (PlaceholderInputViewModel, () -> ((String) -> Void)?) {
        let vm = PlaceholderInputViewModel()
        vm.setup(
            placeholders: [
                PlaceholderData(name: "image", defaultValue: nil, index: 0),
                PlaceholderData(name: "cname", defaultValue: nil, index: 1),
            ],
            templateContent: "docker run --name {{cname}} {{image}}",
            onCompletion: { _ in },
            onCancel: {})
        vm.currentFocusedIndex = focusIndex
        var captured: ((String) -> Void)?
        vm.presentHistory = { callback in captured = callback }
        return (vm, { captured })
    }

    func testSelectionLandsInFocusedField() {
        let (vm, callback) = makeViewModel(focusIndex: 1)
        vm.openHistory()
        guard let cb = callback() else { return XCTFail("history was not requested with a callback") }
        cb("web01")
        XCTAssertEqual(vm.results["cname"], "web01")
        XCTAssertNotEqual(vm.results["image"], "web01", "other fields must stay untouched")
    }

    func testSelectionFollowsFocusIndex() {
        let (vm, callback) = makeViewModel(focusIndex: 0)
        vm.openHistory()
        callback()?("nginx")
        XCTAssertEqual(vm.results["image"], "nginx")
        XCTAssertNotEqual(vm.results["cname"], "nginx")
    }

    func testPlaceholderWindowRegainsKeyAfterSelection() {
        let (vm, callback) = makeViewModel(focusIndex: 1)
        var closed = 0
        vm.onHistoryClosed = { closed += 1 }
        vm.openHistory()
        XCTAssertEqual(closed, 0, "hook must not fire before a selection")
        callback()?("web01")
        XCTAssertEqual(closed, 1)
    }

    /// The history panel must not be hidden by the key reassignment that follows app activation.
    func testHistoryPanelKeepsKeyDuringActivationRightAfterShow() {
        XCTAssertTrue(HistoryViewerManager.shouldReassertKey(
            callbackMode: true, elapsedSinceShow: 0.05, alreadyReasserted: false))
    }

    // Issue991: viewer hotkey (⌘;) routing while the placeholder window is up
    func testHotkeyRoutesToPlaceholderWhenPlaceholderVisible() {
        XCTAssertEqual(HistoryViewerManager.hotkeyRoute(
            placeholderVisible: true, historyVisible: false, callbackMode: false), .placeholder)
    }

    func testHotkeyIsNormalWithoutPlaceholder() {
        XCTAssertEqual(HistoryViewerManager.hotkeyRoute(
            placeholderVisible: false, historyVisible: false, callbackMode: false), .normal)
        XCTAssertEqual(HistoryViewerManager.hotkeyRoute(
            placeholderVisible: false, historyVisible: true, callbackMode: false), .normal)
    }

    func testRepeatedHotkeyDoesNotReplaceCallback() {
        XCTAssertEqual(HistoryViewerManager.hotkeyRoute(
            placeholderVisible: true, historyVisible: true, callbackMode: true), .ignore)
    }

    func testHotkeyRouteOpensHistoryWithCallbackThatFillsField() {
        let (vm, callback) = makeViewModel(focusIndex: 1)
        let mgr = HistoryViewerManager.shared
        let savedActive = mgr.isPlaceholderActive, savedOpen = mgr.openPlaceholderHistory
        defer { mgr.isPlaceholderActive = savedActive; mgr.openPlaceholderHistory = savedOpen }
        mgr.isPlaceholderActive = { true }
        mgr.openPlaceholderHistory = { vm.openHistory() }
        mgr.showFromHotkey()
        guard let cb = callback() else { return XCTFail("hotkey did not open history in callback mode") }
        cb("web01")
        XCTAssertEqual(vm.results["cname"], "web01")
    }
}
