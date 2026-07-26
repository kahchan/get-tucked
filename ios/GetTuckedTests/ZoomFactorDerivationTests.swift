import XCTest
import AVFoundation
@testable import GetTucked

final class ZoomFactorDerivationTests: XCTestCase {
    private let acc = 1e-9

    // MARK: - Device fallback chain order

    func testPrefersTripleCameraWhenAvailable() {
        let available: Set<AVCaptureDevice.DeviceType> = [
            .builtInWideAngleCamera, .builtInDualCamera, .builtInTripleCamera
        ]
        XCTAssertEqual(ZoomFactorDerivation.preferredDeviceType(from: available), .builtInTripleCamera)
    }

    func testPrefersDualOverDualWideAndWide() {
        let available: Set<AVCaptureDevice.DeviceType> = [
            .builtInWideAngleCamera, .builtInDualWideCamera, .builtInDualCamera
        ]
        XCTAssertEqual(ZoomFactorDerivation.preferredDeviceType(from: available), .builtInDualCamera)
    }

    func testPrefersDualWideOverPlainWide() {
        let available: Set<AVCaptureDevice.DeviceType> = [
            .builtInWideAngleCamera, .builtInDualWideCamera
        ]
        XCTAssertEqual(ZoomFactorDerivation.preferredDeviceType(from: available), .builtInDualWideCamera)
    }

    func testFallsBackToPlainWideWhenNothingElseExists() {
        let available: Set<AVCaptureDevice.DeviceType> = [.builtInWideAngleCamera]
        XCTAssertEqual(ZoomFactorDerivation.preferredDeviceType(from: available), .builtInWideAngleCamera)
    }

    func testReturnsNilWhenNoBackCameraFound() {
        XCTAssertNil(ZoomFactorDerivation.preferredDeviceType(from: []))
    }

    // MARK: - Visual-zoom -> videoZoomFactor, per camera configuration

    func testWideOnlyDeviceVisual2xIsFactorTwo() {
        // No ultra-wide constituent, no switch-over table: factor 1.0 already
        // means "wide, as the user understands 1x".
        let factor = ZoomFactorDerivation.factor(
            forVisualMultiplier: 2.0, hasUltraWideConstituent: false, switchOverFactors: []
        )
        XCTAssertEqual(factor, 2.0, accuracy: acc)
    }

    func testDualWideTeleDeviceVisual2xIsFactorTwo() {
        // Dual (wide + tele): still no ultra-wide constituent, so factor 1.0
        // is the wide lens and visual 2x is a plain 2.0 (typically the real
        // switch-over point to the tele lens on these devices).
        let factor = ZoomFactorDerivation.factor(
            forVisualMultiplier: 2.0, hasUltraWideConstituent: false, switchOverFactors: [2.0]
        )
        XCTAssertEqual(factor, 2.0, accuracy: acc)
    }

    func testDualWideUltraWideDeviceVisual2xUsesSwitchOverFactor() {
        // Dual-wide (ultra-wide + wide): factor 1.0 is the ultra-wide, and
        // the ultra-wide -> wide switch-over (here 2.0) IS visual 1x, so
        // visual 2x is double that: 4.0.
        let factor = ZoomFactorDerivation.factor(
            forVisualMultiplier: 2.0, hasUltraWideConstituent: true, switchOverFactors: [2.0]
        )
        XCTAssertEqual(factor, 4.0, accuracy: acc)
    }

    func testTripleCameraDeviceVisual2xUsesFirstSwitchOverFactor() {
        // Triple (ultra-wide + wide + tele): same derivation as dual-wide —
        // only the first switch-over (ultra-wide -> wide) matters for
        // finding visual 1x, the second (wide -> tele) is irrelevant here.
        let factor = ZoomFactorDerivation.factor(
            forVisualMultiplier: 2.0, hasUltraWideConstituent: true, switchOverFactors: [2.0, 6.0]
        )
        XCTAssertEqual(factor, 4.0, accuracy: acc)
    }

    func testVisual1xMatchesUltraWideSwitchOverFactorAlone() {
        let factor = ZoomFactorDerivation.factor(
            forVisualMultiplier: 1.0, hasUltraWideConstituent: true, switchOverFactors: [2.0, 6.0]
        )
        XCTAssertEqual(factor, 2.0, accuracy: acc)
    }

    func testHasUltraWideWithoutSwitchOverFactorsFallsBackToTwo() {
        // Defensive: should never happen on real hardware (a virtual device
        // with an ultra-wide constituent always reports switch-over factors),
        // but don't crash or silently pick 1.0 if it somehow does.
        let factor = ZoomFactorDerivation.factor(
            forVisualMultiplier: 2.0, hasUltraWideConstituent: true, switchOverFactors: []
        )
        XCTAssertEqual(factor, 4.0, accuracy: acc)
    }

    // MARK: - Clamping

    func testClampedStaysWithinRange() {
        XCTAssertEqual(ZoomFactorDerivation.clamped(2.0, min: 1.0, max: 10.0), 2.0, accuracy: acc)
    }

    func testClampedFloorsBelowMinimum() {
        XCTAssertEqual(ZoomFactorDerivation.clamped(0.5, min: 1.0, max: 10.0), 1.0, accuracy: acc)
    }

    func testClampedCeilsAboveMaximum() {
        XCTAssertEqual(ZoomFactorDerivation.clamped(12.0, min: 1.0, max: 10.0), 10.0, accuracy: acc)
    }
}
