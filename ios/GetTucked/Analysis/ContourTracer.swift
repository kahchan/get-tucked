import CoreGraphics

/// Marching-squares boundary trace over a binary foreground/background grid
/// (Plan R1.1) — pure geometry, no CGImage/UIKit dependency, so it's
/// directly unit-testable against synthetic grids. `MatteRenderer.
/// contourPaths` is the CGImage-facing wrapper.
///
/// Display-only: these paths feed no area computation, ever. The number
/// pipeline stays on `AnalysisMath.countForegroundPixels` (spec §3).
enum ContourTracer {
    /// Returns each traced contour as a unit-space (0–1) polygon, in the
    /// same top-left-origin, y-down convention as the mask/photo images
    /// themselves — NOT Vision's bottom-left convention used elsewhere in
    /// this app (`SkeletonGeometry`). These line up directly with
    /// `outlineImage`'s own frame, no flip needed.
    ///
    /// - `minAreaFraction`: contours enclosing less than this fraction of
    ///   the total foreground pixel count are discarded as specks.
    /// - `simplifyTolerance`: Douglas–Peucker tolerance, in source pixels.
    static func trace(
        isForeground: (Int, Int) -> Bool,
        width: Int,
        height: Int,
        minAreaFraction: Double = 0.005,
        simplifyTolerance: CGFloat = 1.0
    ) -> [[CGPoint]] {
        guard width > 0, height > 0 else { return [] }

        func sample(_ x: Int, _ y: Int) -> Bool {
            guard x >= 0, x < width, y >= 0, y < height else { return false }
            return isForeground(x, y)
        }

        var foregroundCount = 0
        for y in 0 ..< height {
            for x in 0 ..< width where sample(x, y) { foregroundCount += 1 }
        }
        guard foregroundCount > 0 else { return [] }

        // Doubled integer coordinates so edge-midpoints (which fall on
        // half-integers) hash/compare exactly — no floating-point endpoint
        // matching between adjacent cells.
        struct GridPoint: Hashable {
            let x2: Int
            let y2: Int
        }

        // One ring of implicit background padding (cx/cy from -1) so a
        // foreground region touching the image edge still closes into a
        // proper loop instead of leaving an open chain.
        var segments: [(GridPoint, GridPoint)] = []
        for cy in -1 ..< height {
            for cx in -1 ..< width {
                let topLeft = sample(cx, cy)
                let topRight = sample(cx + 1, cy)
                let bottomRight = sample(cx + 1, cy + 1)
                let bottomLeft = sample(cx, cy + 1)

                let topCrossed = topLeft != topRight
                let rightCrossed = topRight != bottomRight
                let bottomCrossed = bottomRight != bottomLeft
                let leftCrossed = bottomLeft != topLeft
                let crossingCount = [topCrossed, rightCrossed, bottomCrossed, leftCrossed].filter { $0 }.count
                guard crossingCount > 0 else { continue }

                let top = GridPoint(x2: cx * 2 + 1, y2: cy * 2)
                let right = GridPoint(x2: cx * 2 + 2, y2: cy * 2 + 1)
                let bottom = GridPoint(x2: cx * 2 + 1, y2: cy * 2 + 2)
                let left = GridPoint(x2: cx * 2, y2: cy * 2 + 1)

                if crossingCount == 4 {
                    // Saddle: the two diagonal corners are ambiguous about
                    // whether they're connected. Pick a consistent pairing
                    // based on which diagonal is foreground.
                    if topLeft {
                        segments.append((left, top))
                        segments.append((right, bottom))
                    } else {
                        segments.append((top, right))
                        segments.append((bottom, left))
                    }
                } else {
                    var edges: [GridPoint] = []
                    if topCrossed { edges.append(top) }
                    if rightCrossed { edges.append(right) }
                    if bottomCrossed { edges.append(bottom) }
                    if leftCrossed { edges.append(left) }
                    guard edges.count == 2 else { continue } // crossingCount is always even
                    segments.append((edges[0], edges[1]))
                }
            }
        }
        guard !segments.isEmpty else { return [] }

        // Link segments into closed loops by matching endpoints. Every
        // point has degree ≤ 2 (each cell edge is shared by at most 2
        // cells), so this is a disjoint union of simple cycles.
        var adjacency: [GridPoint: [Int]] = [:]
        for (i, segment) in segments.enumerated() {
            adjacency[segment.0, default: []].append(i)
            adjacency[segment.1, default: []].append(i)
        }
        var used = [Bool](repeating: false, count: segments.count)
        var loops: [[GridPoint]] = []

        for startIndex in segments.indices where !used[startIndex] {
            used[startIndex] = true
            var loop = [segments[startIndex].0, segments[startIndex].1]
            var current = segments[startIndex].1

            while true {
                guard let candidates = adjacency[current],
                      let nextIndex = candidates.first(where: { !used[$0] })
                else { break }
                let segment = segments[nextIndex]
                let next = segment.0 == current ? segment.1 : segment.0
                used[nextIndex] = true
                if next == loop[0] { break } // closed
                loop.append(next)
                current = next
            }
            loops.append(loop)
        }

        let areaThreshold = Double(foregroundCount) * minAreaFraction

        return loops.compactMap { loop -> [CGPoint]? in
            guard loop.count >= 3 else { return nil }
            let pixelPoints = loop.map { CGPoint(x: Double($0.x2) / 2, y: Double($0.y2) / 2) }
            guard abs(shoelaceArea(pixelPoints)) >= areaThreshold else { return nil }
            let simplified = douglasPeucker(pixelPoints, tolerance: simplifyTolerance)
            let rotated = rotateToTopmost(simplified)
            return rotated.map {
                CGPoint(
                    x: min(1, max(0, $0.x / Double(width))),
                    y: min(1, max(0, $0.y / Double(height)))
                )
            }
        }
    }

    private static func shoelaceArea(_ points: [CGPoint]) -> Double {
        guard points.count >= 3 else { return 0 }
        var sum = 0.0
        for i in 0 ..< points.count {
            let p1 = points[i]
            let p2 = points[(i + 1) % points.count]
            sum += Double(p1.x * p2.y - p2.x * p1.y)
        }
        return sum / 2
    }

    /// Standard recursive simplification. Anchored on the loop's own
    /// start/end (adjacent points, one edge apart) rather than two
    /// deliberately-chosen far-apart anchors — since the loop already
    /// starts wherever tracing happened to begin, this simplifies
    /// essentially the whole boundary, leaving only the single closing
    /// edge untouched (already minimal, needs no simplification).
    private static func douglasPeucker(_ points: [CGPoint], tolerance: CGFloat) -> [CGPoint] {
        guard points.count > 2, tolerance > 0 else { return points }
        let first = points[0]
        let last = points[points.count - 1]
        var maxDistance: CGFloat = 0
        var index = 0
        for i in 1 ..< (points.count - 1) {
            let distance = perpendicularDistance(points[i], lineStart: first, lineEnd: last)
            if distance > maxDistance {
                maxDistance = distance
                index = i
            }
        }
        guard maxDistance > tolerance else { return [first, last] }
        let left = douglasPeucker(Array(points[0...index]), tolerance: tolerance)
        let right = douglasPeucker(Array(points[index...]), tolerance: tolerance)
        return left.dropLast() + right
    }

    private static func perpendicularDistance(_ point: CGPoint, lineStart: CGPoint, lineEnd: CGPoint) -> CGFloat {
        let dx = lineEnd.x - lineStart.x
        let dy = lineEnd.y - lineStart.y
        let lengthSquared = dx * dx + dy * dy
        guard lengthSquared > 0 else {
            return hypot(point.x - lineStart.x, point.y - lineStart.y)
        }
        let numerator = abs(dy * point.x - dx * point.y + lineEnd.x * lineStart.y - lineEnd.y * lineStart.x)
        return numerator / sqrt(lengthSquared)
    }

    /// The draw then starts at the helmet and wraps down around the rider
    /// (Plan R1.1) — reads as tracing *them*, not scribbling from an
    /// arbitrary seam.
    private static func rotateToTopmost(_ points: [CGPoint]) -> [CGPoint] {
        guard let topIndex = points.indices.min(by: {
            points[$0].y < points[$1].y || (points[$0].y == points[$1].y && points[$0].x < points[$1].x)
        }), topIndex != 0 else { return points }
        return Array(points[topIndex...] + points[..<topIndex])
    }
}
