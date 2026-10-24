import XCTest
import SwiftData
@testable import GetTucked

final class BikeDeleteTests: XCTestCase {
    func testDeletingBikeAndSavingCascadesToPositions() throws {
        let schema = Schema(versionedSchema: SchemaV12.self)
        let container = try ModelContainer(for: schema, configurations: [ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)])
        let context = ModelContext(container)
        let bike = Bike(nickname: "A", handlebarWidthMm: 420)
        context.insert(bike)
        for i in 0..<2 { context.insert(Position(label: "P\(i)", bike: bike)) }
        try context.save()

        context.delete(bike)
        try context.save()

        XCTAssertTrue(try context.fetch(FetchDescriptor<Bike>()).isEmpty)
        XCTAssertTrue(try context.fetch(FetchDescriptor<Position>()).isEmpty)
    }

    func testPredicateOnPersistentModelIDMatchesOnePosition() throws {
        let schema = Schema(versionedSchema: SchemaV12.self)
        let container = try ModelContainer(for: schema, configurations: [ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)])
        let context = ModelContext(container)
        let p = Position(label: "P", bike: nil)
        context.insert(p)
        context.insert(Position(label: "Q", bike: nil))
        try context.save()
        let id = p.persistentModelID

        let found = try context.fetch(FetchDescriptor<Position>(predicate: #Predicate { $0.persistentModelID == id }))
        XCTAssertEqual(found.count, 1)
    }
}
