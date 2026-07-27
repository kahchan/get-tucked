import XCTest
@testable import GetTucked

/// Plan AI6 — pure ordering logic for `PositionListView`'s sort control,
/// tested independently of SwiftData via `PositionSort.Entry`.
final class PositionSortTests: XCTestCase {
    private let day1 = Date(timeIntervalSince1970: 1_000_000)
    private let day2 = Date(timeIntervalSince1970: 2_000_000)
    private let day3 = Date(timeIntervalSince1970: 3_000_000)

    func testNewestOrderIsCapturedAtDescending() {
        let a = PositionSort.Entry(id: UUID(), capturedAt: day1, areaCm2: 400)
        let b = PositionSort.Entry(id: UUID(), capturedAt: day3, areaCm2: 500)
        let c = PositionSort.Entry(id: UUID(), capturedAt: day2, areaCm2: 300)

        let result = PositionSort.sorted([a, b, c], order: .newest)

        XCTAssertEqual(result.map(\.id), [b.id, c.id, a.id])
    }

    func testSmallestOrderIsAreaAscending() {
        let a = PositionSort.Entry(id: UUID(), capturedAt: day1, areaCm2: 400)
        let b = PositionSort.Entry(id: UUID(), capturedAt: day2, areaCm2: 300)
        let c = PositionSort.Entry(id: UUID(), capturedAt: day3, areaCm2: 500)

        let result = PositionSort.sorted([a, b, c], order: .smallest)

        XCTAssertEqual(result.map(\.id), [b.id, a.id, c.id])
    }

    func testSmallestOrderPlacesMetricLessEntriesLast() {
        let measured = PositionSort.Entry(id: UUID(), capturedAt: day1, areaCm2: 400)
        // Deliberately the newest entry, so a date-only sort would put it
        // first — it must still land after every measured entry.
        let unmeasured = PositionSort.Entry(id: UUID(), capturedAt: day3, areaCm2: nil)

        let result = PositionSort.sorted([unmeasured, measured], order: .smallest)

        XCTAssertEqual(result.map(\.id), [measured.id, unmeasured.id])
    }

    func testSmallestOrderTieBreaksOnCapturedAtDescending() {
        let older = PositionSort.Entry(id: UUID(), capturedAt: day1, areaCm2: 400)
        let newer = PositionSort.Entry(id: UUID(), capturedAt: day2, areaCm2: 400)

        let result = PositionSort.sorted([older, newer], order: .smallest)

        XCTAssertEqual(result.map(\.id), [newer.id, older.id])
    }

    func testSmallestOrderTieBreaksAmongMetricLessEntriesToo() {
        let older = PositionSort.Entry(id: UUID(), capturedAt: day1, areaCm2: nil)
        let newer = PositionSort.Entry(id: UUID(), capturedAt: day2, areaCm2: nil)

        let result = PositionSort.sorted([older, newer], order: .smallest)

        XCTAssertEqual(result.map(\.id), [newer.id, older.id])
    }

    func testEmptyInputReturnsEmpty() {
        XCTAssertEqual(PositionSort.sorted([], order: .newest), [])
        XCTAssertEqual(PositionSort.sorted([], order: .smallest), [])
    }
}
