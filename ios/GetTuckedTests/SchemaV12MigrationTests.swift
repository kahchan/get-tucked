import XCTest
import SwiftData
@testable import GetTucked

final class SchemaV12MigrationTests: XCTestCase {
    func testBlobsAndBikeRelationshipSurviveV11toV12() throws {
        let dir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: dir) }
        let url = dir.appendingPathComponent("store.sqlite")

        let photo = Data((0..<1_048_576).map { UInt8($0 % 251) })
        let mask = Data([1, 2, 3, 4])

        do {
            let v11 = Schema(versionedSchema: SchemaV11.self)
            let container = try ModelContainer(for: v11, configurations: [ModelConfiguration(schema: v11, url: url)])
            let context = ModelContext(container)
            let bike = SchemaV11.Bike(nickname: "A", handlebarWidthMm: 420)
            let position = SchemaV11.Position(label: "P", bike: bike)
            position.photosData = photo
            position.maskData = mask
            context.insert(bike)
            context.insert(position)
            try context.save()
        }

        let v12 = Schema(versionedSchema: SchemaV12.self)
        let container = try ModelContainer(
            for: v12, migrationPlan: AppMigrationPlan.self,
            configurations: [ModelConfiguration(schema: v12, url: url)]
        )
        let context = ModelContext(container)
        let positions = try context.fetch(FetchDescriptor<Position>())
        XCTAssertEqual(positions.count, 1)
        XCTAssertEqual(positions[0].photosData, photo)
        XCTAssertEqual(positions[0].maskData, mask)
        XCTAssertEqual(positions[0].bike?.nickname, "A")
        XCTAssertEqual(try context.fetch(FetchDescriptor<Bike>()).first?.positions.count, 1)
    }
}
