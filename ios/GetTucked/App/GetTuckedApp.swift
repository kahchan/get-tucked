import SwiftUI
import SwiftData

@main
struct GetTuckedApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate

    // Built explicitly (rather than the `.modelContainer(for:)` convenience)
    // so AppMigrationPlan actually runs — the convenience initializer has no
    // migrationPlan parameter and would silently skip SchemaV1→V2 (Plan O).
    var sharedModelContainer: ModelContainer = {
        let schema = Schema(versionedSchema: SchemaV2.self)
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
