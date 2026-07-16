import XCTest
import SwiftData
@testable import GetTucked

/// Covers Q1.2's `trimmedForCaptureExit` — the pure function every ✕/cancel
/// in the capture flow routes through. Path arithmetic is exactly the kind
/// of logic that silently rots, hence dedicated coverage independent of the
/// view that calls it.
final class AppNavigationTests: XCTestCase {
    private var container: ModelContainer!

    override func setUpWithError() throws {
        let schema = Schema(versionedSchema: SchemaV5.self)
        let configuration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
        container = try ModelContainer(for: schema, configurations: [configuration])
    }

    private func makePositionID() -> PersistentIdentifier {
        let context = ModelContext(container)
        let position = Position(label: "Test", bike: nil)
        context.insert(position)
        return position.persistentModelID
    }

    func testOrdinaryCaptureTrimsSetTheSceneAndCapture() {
        let path: [AppScreen] = [.setTheScene(referenceID: nil), .capture(referenceID: nil)]
        XCTAssertEqual(trimmedForCaptureExit(path), [])
    }

    func testMatchFlowTrimsBackToReferenceDetail() {
        let referenceID = makePositionID()
        let path: [AppScreen] = [
            .positionDetail(referenceID),
            .setTheScene(referenceID: referenceID),
            .capture(referenceID: referenceID),
        ]
        XCTAssertEqual(trimmedForCaptureExit(path), [.positionDetail(referenceID)])
    }

    func testTipsSkippedCaptureTrimsJustCapture() {
        // Post-Q3: hasSeenSetTheScene already true, so .setTheScene was
        // never pushed — only .capture sits on top.
        let path: [AppScreen] = [.capture(referenceID: nil)]
        XCTAssertEqual(trimmedForCaptureExit(path), [])
    }

    func testTipsSkippedMatchFlowTrimsBackToReferenceDetail() {
        // Q3.2: match flow never pushes .setTheScene regardless of the flag.
        let referenceID = makePositionID()
        let path: [AppScreen] = [.positionDetail(referenceID), .capture(referenceID: referenceID)]
        XCTAssertEqual(trimmedForCaptureExit(path), [.positionDetail(referenceID)])
    }

    func testAlreadyEmptyPathStaysEmpty() {
        XCTAssertEqual(trimmedForCaptureExit([]), [])
    }
}
