import XCTest
@testable import fSnippetCli

/// The API server queue is serial. Opening the clipboard DB under ~/Documents blocks in open()
/// while the TCC "Documents folder" consent prompt is pending, so a request that lazily
/// initializes ClipboardDB stalls every later request — including the health check paidApp
/// polls to register (Issue244 ②). The API path must never initialize the DB itself.
final class ClipboardDBReadinessTests: XCTestCase {

    func testGateRefusesAndWarmsUpWhenNotReady() {
        var warmed = 0
        XCTAssertFalse(APIRouter.clipboardDBGate(isReady: false, warmUp: { warmed += 1 }))
        XCTAssertEqual(warmed, 1, "a background warm-up must be requested")
    }

    func testGateAllowsWithoutWarmUpWhenReady() {
        var warmed = 0
        XCTAssertTrue(APIRouter.clipboardDBGate(isReady: true, warmUp: { warmed += 1 }))
        XCTAssertEqual(warmed, 0)
    }

    func testWarmUpInBackgroundMakesDBReady() {
        ClipboardDB.warmUpInBackground()
        ClipboardDB.warmUpInBackground()  // idempotent
        let deadline = Date().addingTimeInterval(10)
        while !ClipboardDB.isReady && Date() < deadline {
            RunLoop.current.run(until: Date().addingTimeInterval(0.05))
        }
        XCTAssertTrue(ClipboardDB.isReady, "warm-up must finish initializing the DB")
    }
}
