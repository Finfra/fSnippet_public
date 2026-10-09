//
//  ContextWindowSelectionTests.swift
//  fSnippetCliTests
//
//  tdd #24 context-window-layer (Issue255): apps without AXWindowNumber (TextEdit among them)
//  fall back to CGWindowList to name the active window. Picking the first window the app owns
//  let a transient layer-3 helper window win whenever it was on screen; the 0.5s focus poll then
//  saw the window ID flip, called it a window switch, and cleared the buffer mid-typing —
//  `@good` lost `@go` and the shorter `od` snippet expanded instead.
//  Only layer-0 (normal app) windows can be the context, as TextReplacer.getFrontmostWindowID()
//  already decides.
//

import XCTest
@testable import fSnippetCli

final class ContextWindowSelectionTests: XCTestCase {

    private func window(_ id: Int, pid: Int, layer: Int?) -> [String: Any] {
        var entry: [String: Any] = [
            kCGWindowNumber as String: NSNumber(value: id),
            kCGWindowOwnerPID as String: NSNumber(value: pid),
        ]
        if let layer = layer {
            entry[kCGWindowLayer as String] = NSNumber(value: layer)
        }
        return entry
    }

    func testTransientWindowAboveTheDocumentIsNotTheContext() {
        // Front-to-back order as CGWindowListCopyWindowInfo returns it (jma TextEdit, Issue255).
        let list = [
            window(5099, pid: 24151, layer: 3),
            window(5138, pid: 24151, layer: 0),
            window(5104, pid: 24151, layer: 0),
        ]
        XCTAssertEqual(ContextUtils.frontmostNormalWindowID(in: list, pid: 24151), 5138)
    }

    func testSameDocumentWithOrWithoutTheTransientWindow() {
        let document = window(5138, pid: 24151, layer: 0)
        let withHelper = [window(5099, pid: 24151, layer: 3), document]
        XCTAssertEqual(
            ContextUtils.frontmostNormalWindowID(in: withHelper, pid: 24151),
            ContextUtils.frontmostNormalWindowID(in: [document], pid: 24151),
            "a helper window appearing must not look like a window switch")
    }

    func testOtherAppsWindowsAreIgnored() {
        let list = [
            window(10, pid: 1, layer: 0),
            window(20, pid: 24151, layer: 0),
        ]
        XCTAssertEqual(ContextUtils.frontmostNormalWindowID(in: list, pid: 24151), 20)
    }

    func testWindowWithoutLayerIsNotTheContext() {
        let list = [
            window(30, pid: 24151, layer: nil),
            window(31, pid: 24151, layer: 0),
        ]
        XCTAssertEqual(ContextUtils.frontmostNormalWindowID(in: list, pid: 24151), 31)
    }

    func testNoNormalWindowGivesNil() {
        let list = [window(5099, pid: 24151, layer: 3)]
        XCTAssertNil(ContextUtils.frontmostNormalWindowID(in: list, pid: 24151))
    }
}
