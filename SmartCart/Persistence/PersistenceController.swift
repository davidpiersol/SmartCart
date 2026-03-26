import CoreData
import Foundation

/// Owns the `NSPersistentContainer` for the app and for SwiftUI previews (in-memory + sample data).
final class PersistenceController {
    static let shared = PersistenceController(persistent: true, seedPreviewData: false)

    /// In-memory store with sample lists for canvas previews.
    static let preview = PersistenceController(persistent: false, seedPreviewData: true)

    let container: NSPersistentContainer

    private init(persistent: Bool, seedPreviewData: Bool) {
        container = NSPersistentContainer(name: "SmartCart")
        if !persistent {
            let description = NSPersistentStoreDescription()
            description.type = NSInMemoryStoreType
            container.persistentStoreDescriptions = [description]
        } else {
            container.persistentStoreDescriptions.forEach { desc in
                desc.setOption(true as NSNumber, forKey: NSMigratePersistentStoresAutomaticallyOption)
                desc.setOption(true as NSNumber, forKey: NSInferMappingModelAutomaticallyOption)
            }
        }
        container.loadPersistentStores { _, error in
            if let error {
                fatalError("Core Data failed to load: \(error.localizedDescription)")
            }
        }
        container.viewContext.mergePolicy = NSMergeByPropertyObjectTrumpMergePolicy
        container.viewContext.automaticallyMergesChangesFromParent = true

        if persistent {
            UserDefaultsImportService.importLegacyAppStateIfNeeded(context: container.viewContext)
        }

        if seedPreviewData {
            Self.seedPreviewLists(in: container.viewContext)
        }
    }

    private static func seedPreviewLists(in context: NSManagedObjectContext) {
        let demoStore = StoreEntity(context: context)
        demoStore.id = UUID()
        demoStore.name = "Neighborhood Market"
        demoStore.isDefault = true

        let produceAisle = AisleEntity(context: context)
        produceAisle.id = UUID()
        produceAisle.name = "Produce"
        produceAisle.orderIndex = 0
        produceAisle.store = demoStore
        demoStore.addToAisles(produceAisle)

        let dairyAisle = AisleEntity(context: context)
        dairyAisle.id = UUID()
        dairyAisle.name = "Dairy"
        dairyAisle.orderIndex = 1
        dairyAisle.store = demoStore
        demoStore.addToAisles(dairyAisle)

        let weekly = ShoppingListEntity(context: context)
        weekly.id = UUID()
        weekly.name = "Weekly shop"
        weekly.updatedAt = Date()
        weekly.store = demoStore

        let milk = ShoppingItemEntity(context: context)
        milk.id = UUID()
        milk.name = "Oat milk"
        milk.quantity = 1
        milk.isCompleted = false
        milk.createdAt = Date().addingTimeInterval(-3600)
        milk.category = GroceryCategory.dairy.rawValue
        milk.categoryManualOverride = false
        milk.aisle = dairyAisle
        milk.list = weekly
        weekly.addToItems(milk)

        let bread = ShoppingItemEntity(context: context)
        bread.id = UUID()
        bread.name = "Sourdough loaf"
        bread.quantity = 2
        bread.isCompleted = true
        bread.createdAt = Date().addingTimeInterval(-1800)
        bread.category = GroceryCategory.bakery.rawValue
        bread.categoryManualOverride = false
        bread.aisle = nil
        bread.list = weekly
        weekly.addToItems(bread)

        let party = ShoppingListEntity(context: context)
        party.id = UUID()
        party.name = "Party"
        party.updatedAt = Date().addingTimeInterval(-86_400)

        try? context.save()
    }
}
