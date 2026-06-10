import SwiftData

enum AppSchema {
    static let models: [any PersistentModel.Type] = [
        Bike.self,
        Position.self,
        PositionMetrics.self,
    ]
}

enum AppMigrationPlan: SchemaMigrationPlan {
    static var schemas: [any VersionedSchema.Type] { [SchemaV1.self] }
    static var stages: [MigrationStage] { [] }
}

enum SchemaV1: VersionedSchema {
    static var versionIdentifier = Schema.Version(1, 0, 0)
    static var models: [any PersistentModel.Type] {
        AppSchema.models
    }
}
