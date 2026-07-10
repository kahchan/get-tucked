import XCTest
import CoreGraphics
@testable import GetTucked

final class SkeletonOverlayTests: XCTestCase {
    private let acc = 1e-6

    // MARK: - SkeletonGeometry: Vision bottom-left → view top-left

    func testPointFlipsYAndScalesIntoViewSize() {
        // Vision origin is bottom-left; SwiftUI view origin is top-left, so
        // y must flip while x passes straight through, both scaled by size.
        let point = SkeletonGeometry.point(forUnit: CGPoint(x: 0.25, y: 0.75), in: CGSize(width: 400, height: 800))
        XCTAssertEqual(point.x, 100, accuracy: acc)
        XCTAssertEqual(point.y, 200, accuracy: acc) // (1 - 0.75) * 800
    }

    func testPointCorners() {
        let size = CGSize(width: 200, height: 100)
        // Vision (0,0) = bottom-left of the image → view top-left corner is (0, height).
        XCTAssertEqual(SkeletonGeometry.point(forUnit: .zero, in: size), CGPoint(x: 0, y: 100))
        // Vision (1,1) = top-right of the image → view (width, 0).
        XCTAssertEqual(SkeletonGeometry.point(forUnit: CGPoint(x: 1, y: 1), in: size), CGPoint(x: 200, y: 0))
    }

    // MARK: - SkeletonTimeline.boneTrim: single window == plain progress

    func testBoneTrimSingleWindowMatchesGlobalProgress() {
        let trim = SkeletonTimeline.boneTrim(
            window: 0, windowCount: 1, globalProgress: 0.5, stagger: 0.05, perBoneDuration: 0.25
        )
        XCTAssertEqual(trim, 0.5, accuracy: acc)
    }

    func testBoneTrimClampsBelowZeroAndAboveOne() {
        let below = SkeletonTimeline.boneTrim(window: 0, windowCount: 1, globalProgress: -0.5, perBoneDuration: 0.25)
        let above = SkeletonTimeline.boneTrim(window: 0, windowCount: 1, globalProgress: 1.5, perBoneDuration: 0.25)
        XCTAssertEqual(below, 0, accuracy: acc)
        XCTAssertEqual(above, 1, accuracy: acc)
    }

    // MARK: - SkeletonTimeline.boneTrim: staggered cascade (frontal-with-arms shape)

    func testBoneTrimCascadeStartsAndEndsTogether() {
        // windowCount 3, stagger 0.05, perBoneDuration 0.25 → total 0.35.
        for window in 0 ..< 3 {
            let atStart = SkeletonTimeline.boneTrim(window: window, windowCount: 3, globalProgress: 0, stagger: 0.05, perBoneDuration: 0.25)
            let atEnd = SkeletonTimeline.boneTrim(window: window, windowCount: 3, globalProgress: 1, stagger: 0.05, perBoneDuration: 0.25)
            XCTAssertEqual(atStart, 0, accuracy: acc, "window \(window) should be undrawn at progress 0")
            XCTAssertEqual(atEnd, 1, accuracy: acc, "window \(window) should be fully drawn at progress 1")
        }
    }

    func testBoneTrimCascadeOverlapsLikeCascadeInNotRelay() {
        // total = 2*0.05 + 0.25 = 0.35. At progress = 0.25/0.35, window 0 has
        // just finished (elapsed == its own perBoneDuration) while windows 1
        // and 2 are still mid-flight — an overlapping cascade, not a relay
        // where each bone waits for the previous one to fully finish.
        let progress = 0.25 / 0.35
        let window0 = SkeletonTimeline.boneTrim(window: 0, windowCount: 3, globalProgress: progress, stagger: 0.05, perBoneDuration: 0.25)
        let window1 = SkeletonTimeline.boneTrim(window: 1, windowCount: 3, globalProgress: progress, stagger: 0.05, perBoneDuration: 0.25)
        let window2 = SkeletonTimeline.boneTrim(window: 2, windowCount: 3, globalProgress: progress, stagger: 0.05, perBoneDuration: 0.25)
        XCTAssertEqual(window0, 1.0, accuracy: acc)
        XCTAssertEqual(window1, 0.8, accuracy: acc)
        XCTAssertEqual(window2, 0.6, accuracy: acc)
    }

    func testBoneTrimLaterWindowsNeverAheadOfEarlierOnes() {
        for progress in stride(from: 0.0, through: 1.0, by: 0.1) {
            let window0 = SkeletonTimeline.boneTrim(window: 0, windowCount: 3, globalProgress: progress, stagger: 0.05, perBoneDuration: 0.25)
            let window1 = SkeletonTimeline.boneTrim(window: 1, windowCount: 3, globalProgress: progress, stagger: 0.05, perBoneDuration: 0.25)
            let window2 = SkeletonTimeline.boneTrim(window: 2, windowCount: 3, globalProgress: progress, stagger: 0.05, perBoneDuration: 0.25)
            XCTAssertGreaterThanOrEqual(window0, window1, "at progress \(progress)")
            XCTAssertGreaterThanOrEqual(window1, window2, "at progress \(progress)")
        }
    }

    // MARK: - SkeletonTimeline.jointOpacity

    func testJointOpacityIsZeroBeforePopWindow() {
        // popFraction 0.6 → pop starts at trim 0.4; anything before that is invisible.
        XCTAssertEqual(SkeletonTimeline.jointOpacity(boneTrim: 0, popFraction: 0.6), 0, accuracy: acc)
        XCTAssertEqual(SkeletonTimeline.jointOpacity(boneTrim: 0.4, popFraction: 0.6), 0, accuracy: acc)
    }

    func testJointOpacityReachesOneExactlyAtFullTrim() {
        XCTAssertEqual(SkeletonTimeline.jointOpacity(boneTrim: 1, popFraction: 0.6), 1, accuracy: acc)
    }

    func testJointOpacityIsMonotonicWithinThePopWindow() {
        var previous = -1.0
        for boneTrim in stride(from: 0.4, through: 1.0, by: 0.05) {
            let opacity = SkeletonTimeline.jointOpacity(boneTrim: boneTrim, popFraction: 0.6)
            XCTAssertGreaterThanOrEqual(opacity, previous - acc, "at trim \(boneTrim)")
            previous = opacity
        }
    }

    func testJointOpacityDegradesToBinaryStepWhenPopFractionIsZero() {
        XCTAssertEqual(SkeletonTimeline.jointOpacity(boneTrim: 0.99, popFraction: 0), 0, accuracy: acc)
        XCTAssertEqual(SkeletonTimeline.jointOpacity(boneTrim: 1, popFraction: 0), 1, accuracy: acc)
    }

    // MARK: - SkeletonOverlay.frontal

    func testFrontalMalformedShoulderCountReturnsNil() {
        XCTAssertNil(SkeletonOverlay.frontal(shoulders: [0.1, 0.2, 0.3], arms: nil))
    }

    func testFrontalWithoutArmsHasOnlyTheShoulderBar() {
        guard let overlay = SkeletonOverlay.frontal(shoulders: [0.35, 0.65, 0.65, 0.65], arms: nil) else {
            return XCTFail("expected a non-nil overlay")
        }
        XCTAssertEqual(overlay.joints.count, 2)
        XCTAssertEqual(overlay.bones.count, 1)
        XCTAssertEqual(overlay.bones[0].tier, .measured)
    }

    func testFrontalWithArmsAddsBothChainsInParallelWindows() {
        let arms: [Double] = [0.28, 0.45, 0.22, 0.25, 0.72, 0.45, 0.78, 0.25]
        guard let overlay = SkeletonOverlay.frontal(shoulders: [0.35, 0.65, 0.65, 0.65], arms: arms) else {
            return XCTFail("expected a non-nil overlay")
        }
        XCTAssertEqual(overlay.joints.count, 6) // 2 shoulders + 4 arm joints
        XCTAssertEqual(overlay.bones.count, 5) // shoulder bar + 2 upper arms + 2 forearms

        let shoulderBar = overlay.bones.first { $0.tier == .measured }
        XCTAssertEqual(shoulderBar?.window, 0)

        let upperArms = overlay.bones.filter { $0.tier == .context && ($0.from == 0 || $0.from == 1) }
        XCTAssertEqual(Set(upperArms.map(\.window)), [1], "both upper arms should share one window")

        let contextWindows = Set(overlay.bones.filter { $0.tier == .context }.map(\.window))
        XCTAssertEqual(contextWindows, [1, 2], "arms should occupy exactly two windows (upper, fore)")
    }

    func testFrontalMalformedArmCountReturnsNil() {
        XCTAssertNil(SkeletonOverlay.frontal(shoulders: [0.35, 0.65, 0.65, 0.65], arms: [0.1, 0.2, 0.3]))
    }

    // MARK: - SkeletonOverlay.sideOn

    func testSideOnMalformedCountReturnsNil() {
        XCTAssertNil(SkeletonOverlay.sideOn(points: [0.1, 0.2]))
    }

    func testSideOnHasThreeMeasuredBonesInDistinctWindows() {
        guard let overlay = SkeletonOverlay.sideOn(points: [0.55, 0.55, 0.5, 0.35, 0.45, 0.15, 0.58, 0.62]) else {
            return XCTFail("expected a non-nil overlay")
        }
        XCTAssertEqual(overlay.joints.count, 4)
        XCTAssertEqual(overlay.bones.count, 3)
        XCTAssertTrue(overlay.bones.allSatisfy { $0.tier == .measured })
        XCTAssertEqual(Set(overlay.bones.map(\.window)), [0, 1, 2], "side-on bones draw one at a time, no parallel windows")
    }
}
