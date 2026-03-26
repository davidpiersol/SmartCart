import CoreData
import Foundation

/// One-time import from Phase 2 JSON (`AppState` in UserDefaults) into Core Data when the store is empty.
enum UserDefaultsImportService {
    private enum Keys {
        static let appStateV2 = "com.smartcart.persistence.appState.v2"
    }

    static func importLegacyAppStateIfNeeded(context: NSManagedObjectContext) {
        let fetch: NSFetchRequest<ShoppingListEntity> = ShoppingListEntity.fetchRequest()
        fetch.fetchLimit = 1
        guard let count = try? context.count(for: fetch), count == 0 else { return }

        guard let data = UserDefaults.standard.data(forKey: Keys.appStateV2),
              let state = try? JSONDecoder.smartCart.decode(AppState.self, from: data)
        else { return }

        for list in state.lists {
            let entity = ShoppingListEntity(context: context)
            entity.id = list.id
            entity.name = list.name
            entity.updatedAt = list.updatedAt
            for item in list.items {
                let mo = ShoppingItemEntity(context: context)
                mo.id = item.id
                mo.name = item.name
                mo.category = item.category
                mo.categoryManualOverride = item.categoryManualOverride
                mo.quantity = Int32(item.quantity)
                mo.isCompleted = item.isCompleted
                mo.createdAt = item.createdAt
                mo.list = entity
                entity.addToItems(mo)
            }
        }

        do {
            try context.save()
            UserDefaults.standard.removeObject(forKey: Keys.appStateV2)
        } catch {
            context.rollback()
        }
    }
}

private extension JSONDecoder {
    static var smartCart: JSONDecoder {
        let d = JSONDecoder()
        d.dateDecodingStrategy = .iso8601
        return d
    }
}
