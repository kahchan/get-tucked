import Foundation
import SwiftData

enum AppSchema {
    static let models: [any PersistentModel.Type] = [
        Bike.self,
        Position.self,
        PositionMetrics.self,
        UserSettings.self,
        Event.self,
    ]
}

enum AppMigrationPlan: SchemaMigrationPlan {
    static var schemas: [any VersionedSchema.Type] { [SchemaV1.self, SchemaV2.self, SchemaV3.self, SchemaV4.self, SchemaV5.self, SchemaV6.self, SchemaV7.self, SchemaV8.self, SchemaV9.self, SchemaV10.self] }
    static var stages: [MigrationStage] { [migrateV1toV2, migrateV2toV3, migrateV3toV4, migrateV4toV5, migrateV5toV6, migrateV6toV7, migrateV7toV8, migrateV8toV9, migrateV9toV10] }

    // All V2 additions are optional properties, so SwiftData can infer the
    // mapping without a custom stage.
    static let migrateV1toV2 = MigrationStage.lightweight(fromVersion: SchemaV1.self, toVersion: SchemaV2.self)

    // Same reasoning as V1→V2: both V3 additions (sideOnPixelsPerCm,
    // sideOnTapPoints) are optional, so SwiftData infers the mapping.
    static let migrateV2toV3 = MigrationStage.lightweight(fromVersion: SchemaV2.self, toVersion: SchemaV3.self)

    // Same reasoning again: the V4 addition (Position.wheelTapPoints) is optional.
    static let migrateV3toV4 = MigrationStage.lightweight(fromVersion: SchemaV3.self, toVersion: SchemaV4.self)

    // Same reasoning again: the V5 addition (Bike.barType) is optional.
    static let migrateV4toV5 = MigrationStage.lightweight(fromVersion: SchemaV4.self, toVersion: SchemaV5.self)

    // Same reasoning again: the V6 additions (headOnBodyPoints,
    // sideOnArmPoints, sideOnAnklePoint) are optional.
    static let migrateV5toV6 = MigrationStage.lightweight(fromVersion: SchemaV5.self, toVersion: SchemaV6.self)

    // Plan W: headOnBodyPoints (dropped, replaced by headOnHipPoints /
    // headOnKneePoints — W4) and Position.subjectMaskData (added — W2) land
    // together under one SchemaV7 bump rather than two separate versions
    // (Kah's call: they ship in the same push). A dropped optional column
    // plus new optional additions both qualify for a lightweight stage —
    // no data to hand-migrate either way.
    static let migrateV6toV7 = MigrationStage.lightweight(fromVersion: SchemaV6.self, toVersion: SchemaV7.self)

    // Plan AH: Position.sideOnSubjectMaskData (added) is an optional
    // property, same reasoning as every other lightweight stage above.
    static let migrateV7toV8 = MigrationStage.lightweight(fromVersion: SchemaV7.self, toVersion: SchemaV8.self)

    // Plan AL, wave 2: PositionMetrics.armWidthCm (added, optional) and the
    // new UserSettings model — a whole new model type is still a lightweight
    // stage as long as it has no relationship back into existing data to
    // hand-migrate, which UserSettings doesn't.
    static let migrateV8toV9 = MigrationStage.lightweight(fromVersion: SchemaV8.self, toVersion: SchemaV9.self)

    // Plan AL, wave 6: the new Event model and Position.events many-to-many
    // (added) are both new relationships with no existing data to
    // hand-migrate — a whole new model plus a to-many array is still a
    // lightweight stage, same reasoning as migrateV8toV9's UserSettings
    // addition.
    static let migrateV9toV10 = MigrationStage.lightweight(fromVersion: SchemaV9.self, toVersion: SchemaV10.self)
}

// The pre-Plan-O shape, frozen here as the migration's "before" snapshot —
// nested (not the live top-level classes) so it can never silently drift to
// match whatever the current model files say. Only stored properties and
// relationships matter for the schema; computed properties are omitted.
enum SchemaV1: VersionedSchema {
    static var versionIdentifier = Schema.Version(1, 0, 0)
    static var models: [any PersistentModel.Type] {
        [SchemaV1.Bike.self, SchemaV1.Position.self, SchemaV1.PositionMetrics.self]
    }
}

extension SchemaV1 {
    @Model
    final class Bike {
        var id: UUID
        var nickname: String
        var handlebarWidthMm: Double
        var bikeType: BikeType
        var rimStandard: RimStandard?
        var tireWidthMm: Double?
        var wheelbaseMm: Double?
        var notes: String?
        var createdAt: Date

        @Relationship(deleteRule: .cascade, inverse: \Position.bike)
        var positions: [Position]

        init(nickname: String, handlebarWidthMm: Double, bikeType: BikeType = .road) {
            self.id = UUID()
            self.nickname = nickname
            self.handlebarWidthMm = handlebarWidthMm
            self.bikeType = bikeType
            self.createdAt = Date()
            self.positions = []
        }
    }

    @Model
    final class Position {
        var id: UUID
        var capturedAt: Date
        var label: String
        var packingList: String?
        var bike: Bike?
        var photosData: Data?
        var maskData: Data?
        var headOnPhotoIdentifier: String?
        var sideOnPhotoIdentifier: String?
        var sideOnPhotoData: Data?
        var handlebarTapPoints: [Double]?

        @Relationship(deleteRule: .cascade)
        var metrics: PositionMetrics?

        var isBaseline: Bool

        init(label: String, bike: Bike?) {
            self.id = UUID()
            self.capturedAt = Date()
            self.label = label
            self.bike = bike
            self.isBaseline = false
        }
    }

    @Model
    final class PositionMetrics {
        var frontalAreaCm2: Double
        var frontalAreaUncertainty: Double
        var pixelsPerCm: Double
        var foregroundPixelCount: Int
        var computedAt: Date
        var pipelineVersion: String
        var shoulderWidthCm: Double?
        var handlebarWidthMmUsed: Double?
        var wheelCheckDisagreementFraction: Double?
        var torsoAngleDeg: Double?
        var hipAngleDeg: Double?
        var headDropCm: Double?

        init(
            frontalAreaCm2: Double,
            frontalAreaUncertainty: Double,
            pixelsPerCm: Double,
            foregroundPixelCount: Int
        ) {
            self.frontalAreaCm2 = frontalAreaCm2
            self.frontalAreaUncertainty = frontalAreaUncertainty
            self.pixelsPerCm = pixelsPerCm
            self.foregroundPixelCount = foregroundPixelCount
            self.computedAt = Date()
            self.pipelineVersion = "2.0"
        }
    }
}

// The pre-Plan-P1.5 shape (Plan O: pose landmarks + side-on mask), frozen
// here as the V2→V3 migration's "before" snapshot — same reasoning as
// SchemaV1 above: nested so it can never silently drift to match whatever
// the current model files say.
enum SchemaV2: VersionedSchema {
    static var versionIdentifier = Schema.Version(2, 0, 0)
    static var models: [any PersistentModel.Type] {
        [SchemaV2.Bike.self, SchemaV2.Position.self, SchemaV2.PositionMetrics.self]
    }
}

extension SchemaV2 {
    @Model
    final class Bike {
        var id: UUID
        var nickname: String
        var handlebarWidthMm: Double
        var bikeType: BikeType
        var rimStandard: RimStandard?
        var tireWidthMm: Double?
        var wheelbaseMm: Double?
        var notes: String?
        var createdAt: Date

        @Relationship(deleteRule: .cascade, inverse: \Position.bike)
        var positions: [Position]

        init(nickname: String, handlebarWidthMm: Double, bikeType: BikeType = .road) {
            self.id = UUID()
            self.nickname = nickname
            self.handlebarWidthMm = handlebarWidthMm
            self.bikeType = bikeType
            self.createdAt = Date()
            self.positions = []
        }
    }

    @Model
    final class Position {
        var id: UUID
        var capturedAt: Date
        var label: String
        var packingList: String?
        var bike: Bike?
        var photosData: Data?
        var maskData: Data?
        var sideOnMaskData: Data?
        var headOnPhotoIdentifier: String?
        var sideOnPhotoIdentifier: String?
        var sideOnPhotoData: Data?
        var handlebarTapPoints: [Double]?

        @Relationship(deleteRule: .cascade)
        var metrics: PositionMetrics?

        var isBaseline: Bool

        init(label: String, bike: Bike?) {
            self.id = UUID()
            self.capturedAt = Date()
            self.label = label
            self.bike = bike
            self.isBaseline = false
        }
    }

    @Model
    final class PositionMetrics {
        var frontalAreaCm2: Double
        var frontalAreaUncertainty: Double
        var pixelsPerCm: Double
        var foregroundPixelCount: Int
        var computedAt: Date
        var pipelineVersion: String
        var shoulderWidthCm: Double?
        var handlebarWidthMmUsed: Double?
        var wheelCheckDisagreementFraction: Double?
        var torsoAngleDeg: Double?
        var hipAngleDeg: Double?
        var headDropCm: Double?
        var headOnSkeletonPoints: [Double]?
        var headOnArmPoints: [Double]?
        var sideOnSkeletonPoints: [Double]?

        init(
            frontalAreaCm2: Double,
            frontalAreaUncertainty: Double,
            pixelsPerCm: Double,
            foregroundPixelCount: Int
        ) {
            self.frontalAreaCm2 = frontalAreaCm2
            self.frontalAreaUncertainty = frontalAreaUncertainty
            self.pixelsPerCm = pixelsPerCm
            self.foregroundPixelCount = foregroundPixelCount
            self.computedAt = Date()
            self.pipelineVersion = "2.0"
        }
    }
}

// The pre-ghost-compare shape (Plan P1.5: side-on wheelbase ruler), frozen
// here as the V3→V4 migration's "before" snapshot — same reasoning as
// SchemaV1/V2 above.
enum SchemaV3: VersionedSchema {
    static var versionIdentifier = Schema.Version(3, 0, 0)
    static var models: [any PersistentModel.Type] {
        [SchemaV3.Bike.self, SchemaV3.Position.self, SchemaV3.PositionMetrics.self]
    }
}

extension SchemaV3 {
    @Model
    final class Bike {
        var id: UUID
        var nickname: String
        var handlebarWidthMm: Double
        var bikeType: BikeType
        var rimStandard: RimStandard?
        var tireWidthMm: Double?
        var wheelbaseMm: Double?
        var notes: String?
        var createdAt: Date

        @Relationship(deleteRule: .cascade, inverse: \Position.bike)
        var positions: [Position]

        init(nickname: String, handlebarWidthMm: Double, bikeType: BikeType = .road) {
            self.id = UUID()
            self.nickname = nickname
            self.handlebarWidthMm = handlebarWidthMm
            self.bikeType = bikeType
            self.createdAt = Date()
            self.positions = []
        }
    }

    @Model
    final class Position {
        var id: UUID
        var capturedAt: Date
        var label: String
        var packingList: String?
        var bike: Bike?
        var photosData: Data?
        var maskData: Data?
        var sideOnMaskData: Data?
        var headOnPhotoIdentifier: String?
        var sideOnPhotoIdentifier: String?
        var sideOnPhotoData: Data?
        var handlebarTapPoints: [Double]?
        var sideOnTapPoints: [Double]?

        @Relationship(deleteRule: .cascade)
        var metrics: PositionMetrics?

        var isBaseline: Bool

        init(label: String, bike: Bike?) {
            self.id = UUID()
            self.capturedAt = Date()
            self.label = label
            self.bike = bike
            self.isBaseline = false
        }
    }

    @Model
    final class PositionMetrics {
        var frontalAreaCm2: Double
        var frontalAreaUncertainty: Double
        var pixelsPerCm: Double
        var foregroundPixelCount: Int
        var computedAt: Date
        var pipelineVersion: String
        var shoulderWidthCm: Double?
        var handlebarWidthMmUsed: Double?
        var wheelCheckDisagreementFraction: Double?
        var torsoAngleDeg: Double?
        var hipAngleDeg: Double?
        var headDropCm: Double?
        var headOnSkeletonPoints: [Double]?
        var headOnArmPoints: [Double]?
        var sideOnSkeletonPoints: [Double]?
        var sideOnPixelsPerCm: Double?

        init(
            frontalAreaCm2: Double,
            frontalAreaUncertainty: Double,
            pixelsPerCm: Double,
            foregroundPixelCount: Int
        ) {
            self.frontalAreaCm2 = frontalAreaCm2
            self.frontalAreaUncertainty = frontalAreaUncertainty
            self.pixelsPerCm = pixelsPerCm
            self.foregroundPixelCount = foregroundPixelCount
            self.computedAt = Date()
            self.pipelineVersion = "2.0"
        }
    }
}

// The pre-Plan-S1 shape (ghost-compare: persisted wheel-check tap points),
// frozen here as the V4→V5 migration's "before" snapshot — same reasoning
// as SchemaV1/V2/V3 above.
enum SchemaV4: VersionedSchema {
    static var versionIdentifier = Schema.Version(4, 0, 0)
    static var models: [any PersistentModel.Type] {
        [SchemaV4.Bike.self, SchemaV4.Position.self, SchemaV4.PositionMetrics.self]
    }
}

extension SchemaV4 {
    @Model
    final class Bike {
        var id: UUID
        var nickname: String
        var handlebarWidthMm: Double
        var bikeType: BikeType
        var rimStandard: RimStandard?
        var tireWidthMm: Double?
        var wheelbaseMm: Double?
        var notes: String?
        var createdAt: Date

        @Relationship(deleteRule: .cascade, inverse: \Position.bike)
        var positions: [Position]

        init(nickname: String, handlebarWidthMm: Double, bikeType: BikeType = .road) {
            self.id = UUID()
            self.nickname = nickname
            self.handlebarWidthMm = handlebarWidthMm
            self.bikeType = bikeType
            self.createdAt = Date()
            self.positions = []
        }
    }

    @Model
    final class Position {
        var id: UUID
        var capturedAt: Date
        var label: String
        var packingList: String?
        var bike: Bike?
        var photosData: Data?
        var maskData: Data?
        var sideOnMaskData: Data?
        var headOnPhotoIdentifier: String?
        var sideOnPhotoIdentifier: String?
        var sideOnPhotoData: Data?
        var handlebarTapPoints: [Double]?
        var sideOnTapPoints: [Double]?
        var wheelTapPoints: [Double]?

        @Relationship(deleteRule: .cascade)
        var metrics: PositionMetrics?

        var isBaseline: Bool

        init(label: String, bike: Bike?) {
            self.id = UUID()
            self.capturedAt = Date()
            self.label = label
            self.bike = bike
            self.isBaseline = false
        }
    }

    @Model
    final class PositionMetrics {
        var frontalAreaCm2: Double
        var frontalAreaUncertainty: Double
        var pixelsPerCm: Double
        var foregroundPixelCount: Int
        var computedAt: Date
        var pipelineVersion: String
        var shoulderWidthCm: Double?
        var handlebarWidthMmUsed: Double?
        var wheelCheckDisagreementFraction: Double?
        var torsoAngleDeg: Double?
        var hipAngleDeg: Double?
        var headDropCm: Double?
        var headOnSkeletonPoints: [Double]?
        var headOnArmPoints: [Double]?
        var sideOnSkeletonPoints: [Double]?
        var sideOnPixelsPerCm: Double?

        init(
            frontalAreaCm2: Double,
            frontalAreaUncertainty: Double,
            pixelsPerCm: Double,
            foregroundPixelCount: Int
        ) {
            self.frontalAreaCm2 = frontalAreaCm2
            self.frontalAreaUncertainty = frontalAreaUncertainty
            self.pixelsPerCm = pixelsPerCm
            self.foregroundPixelCount = foregroundPixelCount
            self.computedAt = Date()
            self.pipelineVersion = "2.0"
        }
    }
}

// The pre-Plan-V shape (Plan S1: Bike.barType), frozen here as the V5→V6
// migration's "before" snapshot — same reasoning as SchemaV1-V4 above.
enum SchemaV5: VersionedSchema {
    static var versionIdentifier = Schema.Version(5, 0, 0)
    static var models: [any PersistentModel.Type] {
        [SchemaV5.Bike.self, SchemaV5.Position.self, SchemaV5.PositionMetrics.self]
    }
}

extension SchemaV5 {
    @Model
    final class Bike {
        var id: UUID
        var nickname: String
        var handlebarWidthMm: Double
        var bikeType: BikeType
        var barType: BarType?
        var rimStandard: RimStandard?
        var tireWidthMm: Double?
        var wheelbaseMm: Double?
        var notes: String?
        var createdAt: Date

        @Relationship(deleteRule: .cascade, inverse: \Position.bike)
        var positions: [Position]

        init(nickname: String, handlebarWidthMm: Double, bikeType: BikeType = .road) {
            self.id = UUID()
            self.nickname = nickname
            self.handlebarWidthMm = handlebarWidthMm
            self.bikeType = bikeType
            self.createdAt = Date()
            self.positions = []
        }
    }

    @Model
    final class Position {
        var id: UUID
        var capturedAt: Date
        var label: String
        var packingList: String?
        var bike: Bike?
        var photosData: Data?
        var maskData: Data?
        var sideOnMaskData: Data?
        var headOnPhotoIdentifier: String?
        var sideOnPhotoIdentifier: String?
        var sideOnPhotoData: Data?
        var handlebarTapPoints: [Double]?
        var sideOnTapPoints: [Double]?
        var wheelTapPoints: [Double]?

        @Relationship(deleteRule: .cascade)
        var metrics: PositionMetrics?

        var isBaseline: Bool

        init(label: String, bike: Bike?) {
            self.id = UUID()
            self.capturedAt = Date()
            self.label = label
            self.bike = bike
            self.isBaseline = false
        }
    }

    @Model
    final class PositionMetrics {
        var frontalAreaCm2: Double
        var frontalAreaUncertainty: Double
        var pixelsPerCm: Double
        var foregroundPixelCount: Int
        var computedAt: Date
        var pipelineVersion: String
        var shoulderWidthCm: Double?
        var handlebarWidthMmUsed: Double?
        var wheelCheckDisagreementFraction: Double?
        var torsoAngleDeg: Double?
        var hipAngleDeg: Double?
        var headDropCm: Double?
        var headOnSkeletonPoints: [Double]?
        var headOnArmPoints: [Double]?
        var sideOnSkeletonPoints: [Double]?
        var sideOnPixelsPerCm: Double?

        init(
            frontalAreaCm2: Double,
            frontalAreaUncertainty: Double,
            pixelsPerCm: Double,
            foregroundPixelCount: Int
        ) {
            self.frontalAreaCm2 = frontalAreaCm2
            self.frontalAreaUncertainty = frontalAreaUncertainty
            self.pixelsPerCm = pixelsPerCm
            self.foregroundPixelCount = foregroundPixelCount
            self.computedAt = Date()
            self.pipelineVersion = "2.0"
        }
    }
}

// The pre-Plan-W shape (Plan V: tertiary bone tier joints), frozen here as
// the V6→V7 migration's "before" snapshot — same reasoning as SchemaV1-V5
// above.
enum SchemaV6: VersionedSchema {
    static var versionIdentifier = Schema.Version(6, 0, 0)
    static var models: [any PersistentModel.Type] {
        [SchemaV6.Bike.self, SchemaV6.Position.self, SchemaV6.PositionMetrics.self]
    }
}

extension SchemaV6 {
    @Model
    final class Bike {
        var id: UUID
        var nickname: String
        var handlebarWidthMm: Double
        var bikeType: BikeType
        var barType: BarType?
        var rimStandard: RimStandard?
        var tireWidthMm: Double?
        var wheelbaseMm: Double?
        var notes: String?
        var createdAt: Date

        @Relationship(deleteRule: .cascade, inverse: \Position.bike)
        var positions: [Position]

        init(nickname: String, handlebarWidthMm: Double, bikeType: BikeType = .road) {
            self.id = UUID()
            self.nickname = nickname
            self.handlebarWidthMm = handlebarWidthMm
            self.bikeType = bikeType
            self.createdAt = Date()
            self.positions = []
        }
    }

    @Model
    final class Position {
        var id: UUID
        var capturedAt: Date
        var label: String
        var packingList: String?
        var bike: Bike?
        var photosData: Data?
        var maskData: Data?
        var sideOnMaskData: Data?
        var headOnPhotoIdentifier: String?
        var sideOnPhotoIdentifier: String?
        var sideOnPhotoData: Data?
        var handlebarTapPoints: [Double]?
        var sideOnTapPoints: [Double]?
        var wheelTapPoints: [Double]?

        @Relationship(deleteRule: .cascade)
        var metrics: PositionMetrics?

        var isBaseline: Bool

        init(label: String, bike: Bike?) {
            self.id = UUID()
            self.capturedAt = Date()
            self.label = label
            self.bike = bike
            self.isBaseline = false
        }
    }

    @Model
    final class PositionMetrics {
        var frontalAreaCm2: Double
        var frontalAreaUncertainty: Double
        var pixelsPerCm: Double
        var foregroundPixelCount: Int
        var computedAt: Date
        var pipelineVersion: String
        var shoulderWidthCm: Double?
        var handlebarWidthMmUsed: Double?
        var wheelCheckDisagreementFraction: Double?
        var torsoAngleDeg: Double?
        var hipAngleDeg: Double?
        var headDropCm: Double?
        var headOnSkeletonPoints: [Double]?
        var headOnArmPoints: [Double]?
        var sideOnSkeletonPoints: [Double]?
        var sideOnPixelsPerCm: Double?
        var headOnBodyPoints: [Double]?
        var sideOnArmPoints: [Double]?
        var sideOnAnklePoint: [Double]?

        init(
            frontalAreaCm2: Double,
            frontalAreaUncertainty: Double,
            pixelsPerCm: Double,
            foregroundPixelCount: Int
        ) {
            self.frontalAreaCm2 = frontalAreaCm2
            self.frontalAreaUncertainty = frontalAreaUncertainty
            self.pixelsPerCm = pixelsPerCm
            self.foregroundPixelCount = foregroundPixelCount
            self.computedAt = Date()
            self.pipelineVersion = "2.0"
        }
    }
}

// The pre-Plan-AH shape (Plan W: independent hip/knee bone gating,
// subject-mask matte), frozen here as the V7→V8 migration's "before"
// snapshot — same reasoning as SchemaV1-V6 above. Was previously the live
// top-level classes directly; frozen now that Plan AH adds a new field
// (sideOnSubjectMaskData) those live classes must NOT retroactively gain here.
enum SchemaV7: VersionedSchema {
    static var versionIdentifier = Schema.Version(7, 0, 0)
    static var models: [any PersistentModel.Type] {
        [SchemaV7.Bike.self, SchemaV7.Position.self, SchemaV7.PositionMetrics.self]
    }
}

extension SchemaV7 {
    @Model
    final class Bike {
        var id: UUID
        var nickname: String
        var handlebarWidthMm: Double
        var bikeType: BikeType
        var barType: BarType?
        var rimStandard: RimStandard?
        var tireWidthMm: Double?
        var wheelbaseMm: Double?
        var notes: String?
        var createdAt: Date

        @Relationship(deleteRule: .cascade, inverse: \Position.bike)
        var positions: [Position]

        init(nickname: String, handlebarWidthMm: Double, bikeType: BikeType = .road) {
            self.id = UUID()
            self.nickname = nickname
            self.handlebarWidthMm = handlebarWidthMm
            self.bikeType = bikeType
            self.createdAt = Date()
            self.positions = []
        }
    }

    @Model
    final class Position {
        var id: UUID
        var capturedAt: Date
        var label: String
        var packingList: String?
        var bike: Bike?
        var photosData: Data?
        var maskData: Data?
        var subjectMaskData: Data?
        var sideOnMaskData: Data?
        var headOnPhotoIdentifier: String?
        var sideOnPhotoIdentifier: String?
        var sideOnPhotoData: Data?
        var handlebarTapPoints: [Double]?
        var sideOnTapPoints: [Double]?
        var wheelTapPoints: [Double]?

        @Relationship(deleteRule: .cascade)
        var metrics: PositionMetrics?

        var isBaseline: Bool

        init(label: String, bike: Bike?) {
            self.id = UUID()
            self.capturedAt = Date()
            self.label = label
            self.bike = bike
            self.isBaseline = false
        }
    }

    @Model
    final class PositionMetrics {
        var frontalAreaCm2: Double
        var frontalAreaUncertainty: Double
        var pixelsPerCm: Double
        var foregroundPixelCount: Int
        var computedAt: Date
        var pipelineVersion: String
        var shoulderWidthCm: Double?
        var handlebarWidthMmUsed: Double?
        var wheelCheckDisagreementFraction: Double?
        var torsoAngleDeg: Double?
        var hipAngleDeg: Double?
        var headDropCm: Double?
        var headOnSkeletonPoints: [Double]?
        var headOnArmPoints: [Double]?
        var sideOnSkeletonPoints: [Double]?
        var sideOnPixelsPerCm: Double?
        var headOnHipPoints: [Double]?
        var headOnKneePoints: [Double]?
        var sideOnArmPoints: [Double]?
        var sideOnAnklePoint: [Double]?

        init(
            frontalAreaCm2: Double,
            frontalAreaUncertainty: Double,
            pixelsPerCm: Double,
            foregroundPixelCount: Int
        ) {
            self.frontalAreaCm2 = frontalAreaCm2
            self.frontalAreaUncertainty = frontalAreaUncertainty
            self.pixelsPerCm = pixelsPerCm
            self.foregroundPixelCount = foregroundPixelCount
            self.computedAt = Date()
            self.pipelineVersion = "2.0"
        }
    }
}

// The pre-Plan-AL shape (Plan AH: side-on subject-lift matte was the last
// change), frozen here as the V8→V9 migration's "before" snapshot — same
// reasoning as SchemaV1-V7 above.
enum SchemaV8: VersionedSchema {
    static var versionIdentifier = Schema.Version(8, 0, 0)
    static var models: [any PersistentModel.Type] {
        [SchemaV8.Bike.self, SchemaV8.Position.self, SchemaV8.PositionMetrics.self]
    }
}

extension SchemaV8 {
    @Model
    final class Bike {
        var id: UUID
        var nickname: String
        var handlebarWidthMm: Double
        var bikeType: BikeType
        var barType: BarType?
        var rimStandard: RimStandard?
        var tireWidthMm: Double?
        var wheelbaseMm: Double?
        var notes: String?
        var createdAt: Date

        @Relationship(deleteRule: .cascade, inverse: \Position.bike)
        var positions: [Position]

        init(nickname: String, handlebarWidthMm: Double, bikeType: BikeType = .road) {
            self.id = UUID()
            self.nickname = nickname
            self.handlebarWidthMm = handlebarWidthMm
            self.bikeType = bikeType
            self.createdAt = Date()
            self.positions = []
        }
    }

    @Model
    final class Position {
        var id: UUID
        var capturedAt: Date
        var label: String
        var packingList: String?
        var bike: Bike?
        var photosData: Data?
        var maskData: Data?
        var subjectMaskData: Data?
        var sideOnMaskData: Data?
        var sideOnSubjectMaskData: Data?
        var headOnPhotoIdentifier: String?
        var sideOnPhotoIdentifier: String?
        var sideOnPhotoData: Data?
        var handlebarTapPoints: [Double]?
        var sideOnTapPoints: [Double]?
        var wheelTapPoints: [Double]?

        @Relationship(deleteRule: .cascade)
        var metrics: PositionMetrics?

        var isBaseline: Bool

        init(label: String, bike: Bike?) {
            self.id = UUID()
            self.capturedAt = Date()
            self.label = label
            self.bike = bike
            self.isBaseline = false
        }
    }

    @Model
    final class PositionMetrics {
        var frontalAreaCm2: Double
        var frontalAreaUncertainty: Double
        var pixelsPerCm: Double
        var foregroundPixelCount: Int
        var computedAt: Date
        var pipelineVersion: String
        var shoulderWidthCm: Double?
        var handlebarWidthMmUsed: Double?
        var wheelCheckDisagreementFraction: Double?
        var torsoAngleDeg: Double?
        var hipAngleDeg: Double?
        var headDropCm: Double?
        var headOnSkeletonPoints: [Double]?
        var headOnArmPoints: [Double]?
        var sideOnSkeletonPoints: [Double]?
        var sideOnPixelsPerCm: Double?
        var headOnHipPoints: [Double]?
        var headOnKneePoints: [Double]?
        var sideOnArmPoints: [Double]?
        var sideOnAnklePoint: [Double]?

        init(
            frontalAreaCm2: Double,
            frontalAreaUncertainty: Double,
            pixelsPerCm: Double,
            foregroundPixelCount: Int
        ) {
            self.frontalAreaCm2 = frontalAreaCm2
            self.frontalAreaUncertainty = frontalAreaUncertainty
            self.pixelsPerCm = pixelsPerCm
            self.foregroundPixelCount = foregroundPixelCount
            self.computedAt = Date()
            self.pipelineVersion = "2.0"
        }
    }
}

// Plan AL wave 2's shape (UserSettings model + PositionMetrics.armWidthCm),
// frozen here as the V9→V10 migration's "before" snapshot — same reasoning
// as every other frozen schema above: nested, not the live top-level
// classes, so it can never silently drift.
enum SchemaV9: VersionedSchema {
    static var versionIdentifier = Schema.Version(9, 0, 0)
    static var models: [any PersistentModel.Type] {
        [SchemaV9.Bike.self, SchemaV9.Position.self, SchemaV9.PositionMetrics.self, SchemaV9.UserSettings.self]
    }
}

extension SchemaV9 {
    @Model
    final class Bike {
        var id: UUID
        var nickname: String
        var handlebarWidthMm: Double
        var bikeType: BikeType
        var barType: BarType?
        var rimStandard: RimStandard?
        var tireWidthMm: Double?
        var wheelbaseMm: Double?
        var notes: String?
        var createdAt: Date

        @Relationship(deleteRule: .cascade, inverse: \Position.bike)
        var positions: [Position]

        init(nickname: String, handlebarWidthMm: Double, bikeType: BikeType = .road) {
            self.id = UUID()
            self.nickname = nickname
            self.handlebarWidthMm = handlebarWidthMm
            self.bikeType = bikeType
            self.createdAt = Date()
            self.positions = []
        }
    }

    @Model
    final class Position {
        var id: UUID
        var capturedAt: Date
        var label: String
        var packingList: String?
        var bike: Bike?
        var photosData: Data?
        var maskData: Data?
        var subjectMaskData: Data?
        var sideOnMaskData: Data?
        var sideOnSubjectMaskData: Data?
        var headOnPhotoIdentifier: String?
        var sideOnPhotoIdentifier: String?
        var sideOnPhotoData: Data?
        var handlebarTapPoints: [Double]?
        var sideOnTapPoints: [Double]?
        var wheelTapPoints: [Double]?

        @Relationship(deleteRule: .cascade)
        var metrics: PositionMetrics?

        var isBaseline: Bool

        init(label: String, bike: Bike?) {
            self.id = UUID()
            self.capturedAt = Date()
            self.label = label
            self.bike = bike
            self.isBaseline = false
        }
    }

    @Model
    final class PositionMetrics {
        var frontalAreaCm2: Double
        var frontalAreaUncertainty: Double
        var pixelsPerCm: Double
        var foregroundPixelCount: Int
        var computedAt: Date
        var pipelineVersion: String
        var shoulderWidthCm: Double?
        var armWidthCm: Double?
        var handlebarWidthMmUsed: Double?
        var wheelCheckDisagreementFraction: Double?
        var torsoAngleDeg: Double?
        var hipAngleDeg: Double?
        var headDropCm: Double?
        var headOnSkeletonPoints: [Double]?
        var headOnArmPoints: [Double]?
        var sideOnSkeletonPoints: [Double]?
        var sideOnPixelsPerCm: Double?
        var headOnHipPoints: [Double]?
        var headOnKneePoints: [Double]?
        var sideOnArmPoints: [Double]?
        var sideOnAnklePoint: [Double]?

        init(
            frontalAreaCm2: Double,
            frontalAreaUncertainty: Double,
            pixelsPerCm: Double,
            foregroundPixelCount: Int
        ) {
            self.frontalAreaCm2 = frontalAreaCm2
            self.frontalAreaUncertainty = frontalAreaUncertainty
            self.pixelsPerCm = pixelsPerCm
            self.foregroundPixelCount = foregroundPixelCount
            self.computedAt = Date()
            self.pipelineVersion = "2.0"
        }
    }

    @Model
    final class UserSettings {
        var noiseFloorPct: Double?
        var noiseFloorLastCalibrated: Date?
        var preferredUnits: PreferredUnits
        var hasCompletedOnboarding: Bool
        var consentToCaptureOthers: Bool

        init() {
            self.preferredUnits = .metric
            self.hasCompletedOnboarding = false
            self.consentToCaptureOthers = false
        }
    }
}

// The current shape (Plan AL9: Event model + Position.events many-to-many)
// — the live top-level classes, which the rest of the app builds against
// directly.
enum SchemaV10: VersionedSchema {
    static var versionIdentifier = Schema.Version(10, 0, 0)
    static var models: [any PersistentModel.Type] {
        AppSchema.models
    }
}
