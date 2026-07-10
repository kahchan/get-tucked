import Foundation
import SwiftData

enum AppSchema {
    static let models: [any PersistentModel.Type] = [
        Bike.self,
        Position.self,
        PositionMetrics.self,
    ]
}

enum AppMigrationPlan: SchemaMigrationPlan {
    static var schemas: [any VersionedSchema.Type] { [SchemaV1.self, SchemaV2.self] }
    static var stages: [MigrationStage] { [migrateV1toV2] }

    // All V2 additions are optional properties, so SwiftData can infer the
    // mapping without a custom stage.
    static let migrateV1toV2 = MigrationStage.lightweight(fromVersion: SchemaV1.self, toVersion: SchemaV2.self)
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

// The current shape (Plan O: pose landmarks + side-on mask) — the live
// top-level classes, which the rest of the app builds against directly.
enum SchemaV2: VersionedSchema {
    static var versionIdentifier = Schema.Version(2, 0, 0)
    static var models: [any PersistentModel.Type] {
        AppSchema.models
    }
}
