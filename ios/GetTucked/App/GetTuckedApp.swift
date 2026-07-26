import SwiftUI
import SwiftData

@main
struct GetTuckedApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate

    // Built explicitly (rather than the `.modelContainer(for:)` convenience)
    // so AppMigrationPlan actually runs — the convenience initializer has no
    // migrationPlan parameter and would silently skip SchemaV1→V2 (Plan O),
    // V2→V3 (Plan P1.5), V3→V4 (ghost-compare), V4→V5 (Plan S1),
    // V5→V6 (Plan V), or V6→V7 (Plan W). This MUST name the latest schema
    // version — pointing it at a frozen snapshot makes the store's entities
    // resolve to the nested copies and every live-class @Query dies with a
    // "Failed to cast model" fatal (seen after Plan V, when V5 became a
    // snapshot — see commit 7d7f311).
    var sharedModelContainer: ModelContainer = {
        let schema = Schema(versionedSchema: SchemaV8.self)
        let configuration = ModelConfiguration(schema: schema)
        return try! ModelContainer(
            for: schema,
            migrationPlan: AppMigrationPlan.self,
            configurations: [configuration]
        )
    }()

    var body: some Scene {
        WindowGroup {
            ContentView()
        }
        .modelContainer(sharedModelContainer)
    }
}
