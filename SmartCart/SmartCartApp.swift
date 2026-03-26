import SwiftUI

@main
struct SmartCartApp: App {
    private let persistence = PersistenceController.shared

    var body: some Scene {
        WindowGroup {
            ShoppingListRootView(persistence: persistence)
                .environment(\.managedObjectContext, persistence.container.viewContext)
        }
    }
}
