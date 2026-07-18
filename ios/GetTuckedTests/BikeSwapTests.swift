import XCTest
import SwiftData
@testable import GetTucked

/// Covers Plan Y2/Y3's `Position`/`Bike`-touching layer around
/// `AnalysisMath.rescaledMetrics` — the affordance gate, the confirm-state
/// copy (including the no-wheelbase warning), and the actual relationship
/// reassignment + field mutation `BikeSwap.apply` performs. Y1's pure math
/// is covered independently in `AnalysisMathTests`.
final class BikeSwapTests: XCTestCase {
    private var container: ModelContainer!
    private var context: ModelContext!

    override func setUpWithError() throws {
        let schema = Schema(versionedSchema: SchemaV7.self)
        let configuration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
        container = try ModelContainer(for: schema, configurations: [configuration])
        context = ModelContext(container)
    }

    private func makeBike(nickname: String, barMm: Double, wheelbaseMm: Double? = nil, wheelDiameterMm: (rim: RimStandard, tireMm: Double)? = nil) -> Bike {
        let bike = Bike(nickname: nickname, handlebarWidthMm: barMm)
        bike.wheelbaseMm = wheelbaseMm
        if let wheelDiameterMm {
            bike.rimStandard = wheelDiameterMm.rim
            bike.tireWidthMm = wheelDiameterMm.tireMm
        }
        context.insert(bike)
        return bike
    }

    private func makePosition(bike: Bike?, barMmUsed: Double, sideOnPixelsPerCm: Double? = nil, headDropCm: Double? = nil, wheelTapPoints: [Double]? = nil) -> Position {
        let position = Position(label: "Test", bike: bike)
        let metrics = PositionMetrics(frontalAreaCm2: 400, frontalAreaUncertainty: 12, pixelsPerCm: 10, foregroundPixelCount: 40_000)
        metrics.handlebarWidthMmUsed = barMmUsed
        metrics.shoulderWidthCm = 42
        metrics.sideOnPixelsPerCm = sideOnPixelsPerCm
        metrics.headDropCm = headDropCm
        position.metrics = metrics
        position.wheelTapPoints = wheelTapPoints
        context.insert(position)
        return position
    }

    // MARK: - Affordance gate (Plan Y3)

    func testIsAvailableFalseWithZeroOtherBikes() {
        XCTAssertFalse(BikeSwap.isAvailable(otherBikesCount: 0))
    }

    func testIsAvailableTrueWithAtLeastOneOtherBike() {
        XCTAssertTrue(BikeSwap.isAvailable(otherBikesCount: 1))
    }

    func testOtherBikesExcludesCurrentBike() {
        let a = makeBike(nickname: "A", barMm: 400)
        let b = makeBike(nickname: "B", barMm: 500)
        let others = BikeSwap.otherBikes(allBikes: [a, b], excluding: a)
        XCTAssertEqual(others.map(\.id), [b.id])
    }

    func testOtherBikesWithNilCurrentBikeReturnsAll() {
        let a = makeBike(nickname: "A", barMm: 400)
        let b = makeBike(nickname: "B", barMm: 500)
        let others = BikeSwap.otherBikes(allBikes: [a, b], excluding: nil)
        XCTAssertEqual(Set(others.map(\.id)), Set([a.id, b.id]))
    }

    // MARK: - Confirm-state copy

    func testConfirmMessageNamesBikeAndBarWidth() {
        let bike = makeBike(nickname: "Winter trainer", barMm: 640)
        XCTAssertEqual(BikeSwap.confirmMessage(newBike: bike), "Rescales this position using Winter trainer's 640 mm bars")
    }

    func testNoWheelbaseWarningNilWhenPositionHasNoSideOnData() {
        let bike = makeBike(nickname: "B", barMm: 400)
        let position = makePosition(bike: nil, barMmUsed: 400, sideOnPixelsPerCm: nil)
        XCTAssertNil(BikeSwap.noWheelbaseWarning(position: position, newBike: bike))
    }

    func testNoWheelbaseWarningNilWhenNewBikeHasWheelbase() {
        let bike = makeBike(nickname: "B", barMm: 400, wheelbaseMm: 1050)
        let position = makePosition(bike: nil, barMmUsed: 400, sideOnPixelsPerCm: 9.6)
        XCTAssertNil(BikeSwap.noWheelbaseWarning(position: position, newBike: bike))
    }

    func testNoWheelbaseWarningPresentWhenSideOnDataExistsAndNewBikeLacksWheelbase() {
        let bike = makeBike(nickname: "Gravel bike", barMm: 400)
        let position = makePosition(bike: nil, barMmUsed: 400, sideOnPixelsPerCm: 9.6)
        XCTAssertEqual(
            BikeSwap.noWheelbaseWarning(position: position, newBike: bike),
            "Side-on numbers will be removed — Gravel bike has no wheelbase on record."
        )
    }

    // MARK: - Apply (Y2 + Y3)

    func testApplyRescalesMetricsAndReassignsBike() {
        let oldBike = makeBike(nickname: "A", barMm: 400)
        let newBike = makeBike(nickname: "B", barMm: 500)
        let position = makePosition(bike: oldBike, barMmUsed: 400)

        let applied = BikeSwap.apply(to: position, newBike: newBike, imageAspect: CGSize(width: 1, height: 1))

        XCTAssertTrue(applied)
        XCTAssertEqual(position.bike?.id, newBike.id)
        XCTAssertEqual(position.metrics?.pixelsPerCm ?? -1, 8, accuracy: 1e-9) // 10 / 1.25
        XCTAssertEqual(position.metrics?.frontalAreaCm2 ?? -1, 625, accuracy: 1e-9) // 400 * 1.25^2
        XCTAssertEqual(position.metrics?.handlebarWidthMmUsed ?? -1, 500, accuracy: 1e-9)
    }

    func testApplyNoOpsWhenMetricsHasNoBarWidthProvenance() {
        let oldBike = makeBike(nickname: "A", barMm: 400)
        let newBike = makeBike(nickname: "B", barMm: 500)
        let position = makePosition(bike: oldBike, barMmUsed: 400)
        position.metrics?.handlebarWidthMmUsed = nil

        let applied = BikeSwap.apply(to: position, newBike: newBike, imageAspect: CGSize(width: 1, height: 1))

        XCTAssertFalse(applied)
        XCTAssertEqual(position.bike?.id, oldBike.id) // unchanged
        XCTAssertEqual(position.metrics?.pixelsPerCm ?? -1, 10, accuracy: 1e-9) // unchanged
    }

    func testApplyNilsSideOnWhenNewBikeLacksWheelbase() {
        let oldBike = makeBike(nickname: "A", barMm: 400, wheelbaseMm: 1000)
        let newBike = makeBike(nickname: "B", barMm: 400) // no wheelbase
        let position = makePosition(bike: oldBike, barMmUsed: 400, sideOnPixelsPerCm: 9.6, headDropCm: 4.2)

        BikeSwap.apply(to: position, newBike: newBike, imageAspect: CGSize(width: 1, height: 1))

        XCTAssertNil(position.metrics?.sideOnPixelsPerCm)
        XCTAssertNil(position.metrics?.headDropCm)
    }

    /// Full round trip at the model level: swapping A -> B -> A restores
    /// frontal area, scale, and the bike relationship exactly — the
    /// acceptance criterion from the Plan Y doc ("swapping back restores
    /// the originals exactly").
    func testApplyRoundTripRestoresOriginalPosition() {
        let bikeA = makeBike(nickname: "A", barMm: 400, wheelbaseMm: 1000, wheelDiameterMm: (.c700, 45))
        let bikeB = makeBike(nickname: "B", barMm: 500, wheelbaseMm: 1080, wheelDiameterMm: (.c700, 40))
        let position = makePosition(
            bike: bikeA, barMmUsed: 400,
            sideOnPixelsPerCm: 9.6, headDropCm: 4.2,
            wheelTapPoints: [0.5, 0.9, 0.5, 0.544]
        )
        let originalArea = position.metrics!.frontalAreaCm2
        let originalScale = position.metrics!.pixelsPerCm
        let originalShoulder = position.metrics!.shoulderWidthCm!
        let originalSideOn = position.metrics!.sideOnPixelsPerCm!
        let originalHeadDrop = position.metrics!.headDropCm!

        BikeSwap.apply(to: position, newBike: bikeB, imageAspect: CGSize(width: 1000, height: 1000))
        XCTAssertEqual(position.bike?.id, bikeB.id)

        BikeSwap.apply(to: position, newBike: bikeA, imageAspect: CGSize(width: 1000, height: 1000))

        XCTAssertEqual(position.bike?.id, bikeA.id)
        XCTAssertEqual(position.metrics?.frontalAreaCm2 ?? -1, originalArea, accuracy: 1e-9)
        XCTAssertEqual(position.metrics?.pixelsPerCm ?? -1, originalScale, accuracy: 1e-9)
        XCTAssertEqual(position.metrics?.shoulderWidthCm ?? -1, originalShoulder, accuracy: 1e-9)
        XCTAssertEqual(position.metrics?.sideOnPixelsPerCm ?? -1, originalSideOn, accuracy: 1e-9)
        XCTAssertEqual(position.metrics?.headDropCm ?? -1, originalHeadDrop, accuracy: 1e-9)
        XCTAssertEqual(position.metrics?.handlebarWidthMmUsed ?? -1, 400, accuracy: 1e-9)
    }
}
