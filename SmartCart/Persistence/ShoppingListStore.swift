import CoreData
import Foundation

/// ViewModel-facing persistence API. Keeps `NSManagedObject` work out of SwiftUI views.
@MainActor
protocol ShoppingListStore: AnyObject {
    func loadState() throws -> AppState
    func saveContext() throws

    func createList(named: String) throws -> UUID
    func renameList(id: UUID, to name: String) throws
    func deleteList(id: UUID) throws

    func createStore(named: String) throws -> UUID
    func deleteStore(id: UUID) throws
    func setActiveStore(id: UUID?) throws
    func createAisle(storeId: UUID, name: String) throws -> UUID
    func renameAisle(id: UUID, storeId: UUID, to name: String) throws
    func deleteAisle(id: UUID, storeId: UUID) throws
    func reorderAisles(storeId: UUID, orderedAisleIds: [UUID]) throws

    func addItem(
        listId: UUID,
        name: String,
        quantity: Int,
        category: String?,
        categoryManualOverride: Bool,
        aisleId: UUID?
    ) throws
    func updateItem(listId: UUID, item: ShoppingItem) throws
    func deleteItems(listId: UUID, itemIds: Set<UUID>) throws
    func setItemCompleted(listId: UUID, itemId: UUID, isCompleted: Bool) throws
}

/// Core Data implementation of `ShoppingListStore` using the main `viewContext`.
@MainActor
final class CoreDataShoppingListStore: ShoppingListStore {
    private let container: NSPersistentContainer
    private static let activeStoreKey = "com.smartcart.activeStoreId"

    private var viewContext: NSManagedObjectContext {
        container.viewContext
    }

    init(container: NSPersistentContainer) {
        self.container = container
    }

    func loadState() throws -> AppState {
        try mapAppState()
    }

    func saveContext() throws {
        if viewContext.hasChanges {
            try viewContext.save()
        }
    }

    func createList(named: String) throws -> UUID {
        let trimmed = named.trimmingCharacters(in: .whitespacesAndNewlines)
        let finalName = trimmed.isEmpty ? "New List" : trimmed
        let entity = ShoppingListEntity(context: viewContext)
        let id = UUID()
        entity.id = id
        entity.name = finalName
        entity.updatedAt = Date()
        if let activeStoreId = currentActiveStoreId(),
           let activeStore = try fetchStore(id: activeStoreId) {
            entity.store = activeStore
            activeStore.addToLists(entity)
        }
        try saveContext()
        return id
    }

    func renameList(id: UUID, to name: String) throws {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        guard let list = try fetchList(id: id) else { return }
        list.name = trimmed
        list.updatedAt = Date()
        try saveContext()
    }

    func deleteList(id: UUID) throws {
        guard let list = try fetchList(id: id) else { return }
        viewContext.delete(list)
        try saveContext()
    }

    func createStore(named: String) throws -> UUID {
        let trimmed = named.trimmingCharacters(in: .whitespacesAndNewlines)
        let finalName = trimmed.isEmpty ? "Store" : trimmed
        let mo = StoreEntity(context: viewContext)
        let id = UUID()
        mo.id = id
        mo.name = finalName
        mo.isDefault = false
        try saveContext()

        if currentActiveStoreId() == nil {
            try setActiveStore(id: id)
        }
        return id
    }

    func deleteStore(id: UUID) throws {
        guard let store = try fetchStore(id: id) else { return }
        let deletedWasActive = currentActiveStoreId() == id
        viewContext.delete(store)
        try saveContext()

        if deletedWasActive {
            let replacement = try firstStoreId()
            try setActiveStore(id: replacement)
        }
    }

    func setActiveStore(id: UUID?) throws {
        if let id {
            guard try fetchStore(id: id) != nil else {
                throw StoreError.storeNotFound(id)
            }
            UserDefaults.standard.set(id.uuidString, forKey: Self.activeStoreKey)
        } else {
            UserDefaults.standard.removeObject(forKey: Self.activeStoreKey)
        }
        try updateDefaultStoreFlag(activeStoreId: id)
    }

    func createAisle(storeId: UUID, name: String) throws -> UUID {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        let finalName = trimmed.isEmpty ? "Aisle" : trimmed
        guard let store = try fetchStore(id: storeId) else {
            throw StoreError.storeNotFound(storeId)
        }

        let next = (store.aisles as? Set<AisleEntity> ?? []).map(\.orderIndex).max() ?? -1
        let aisle = AisleEntity(context: viewContext)
        let id = UUID()
        aisle.id = id
        aisle.name = finalName
        aisle.orderIndex = next + 1
        aisle.store = store
        store.addToAisles(aisle)
        try saveContext()
        return id
    }

    func renameAisle(id: UUID, storeId: UUID, to name: String) throws {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        guard let aisle = try fetchAisle(id: id, storeId: storeId) else { return }
        aisle.name = trimmed
        try saveContext()
    }

    func deleteAisle(id: UUID, storeId: UUID) throws {
        guard let store = try fetchStore(id: storeId), let aisle = try fetchAisle(id: id, storeId: storeId) else { return }
        viewContext.delete(aisle)
        normalizeAisleOrder(for: store)
        try saveContext()
    }

    func reorderAisles(storeId: UUID, orderedAisleIds: [UUID]) throws {
        guard let store = try fetchStore(id: storeId) else {
            throw StoreError.storeNotFound(storeId)
        }
        let aisles = (store.aisles as? Set<AisleEntity> ?? []).sorted {
            if $0.orderIndex != $1.orderIndex { return $0.orderIndex < $1.orderIndex }
            return ($0.name ?? "") < ($1.name ?? "")
        }
        var lookup: [UUID: AisleEntity] = [:]
        for a in aisles {
            if let id = a.id { lookup[id] = a }
        }
        for (idx, id) in orderedAisleIds.enumerated() {
            lookup[id]?.orderIndex = Int32(idx)
        }
        // Keep any omitted aisles stable at the end.
        var next = Int32(orderedAisleIds.count)
        for a in aisles where !(orderedAisleIds.contains { $0 == a.id }) {
            a.orderIndex = next
            next += 1
        }
        try saveContext()
    }

    func addItem(
        listId: UUID,
        name: String,
        quantity: Int,
        category: String?,
        categoryManualOverride: Bool,
        aisleId: UUID?
    ) throws {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        guard let list = try fetchList(id: listId) else {
            throw StoreError.listNotFound(listId)
        }
        let mo = ShoppingItemEntity(context: viewContext)
        mo.id = UUID()
        mo.name = trimmed
        mo.quantity = Int32(max(1, min(99, quantity)))
        mo.isCompleted = false
        mo.createdAt = Date()
        mo.category = category
        mo.categoryManualOverride = categoryManualOverride
        mo.aisle = try resolvedAisleForAssignment(aisleId)
        mo.list = list
        list.addToItems(mo)
        list.updatedAt = Date()
        viewContext.processPendingChanges()
        try saveContext()
    }

    func updateItem(listId: UUID, item: ShoppingItem) throws {
        guard let mo = try fetchItem(listId: listId, itemId: item.id) else { return }
        mo.name = item.name.trimmingCharacters(in: .whitespacesAndNewlines)
        mo.quantity = Int32(max(1, min(99, item.quantity)))
        mo.category = item.category
        mo.categoryManualOverride = item.categoryManualOverride
        mo.aisle = try resolvedAisleForAssignment(item.aisleId)
        if let list = mo.list {
            list.updatedAt = Date()
        }
        try saveContext()
    }

    func deleteItems(listId: UUID, itemIds: Set<UUID>) throws {
        guard let list = try fetchList(id: listId) else { return }
        for id in itemIds {
            if let item = try fetchItem(listId: listId, itemId: id) {
                viewContext.delete(item)
            }
        }
        list.updatedAt = Date()
        try saveContext()
    }

    func setItemCompleted(listId: UUID, itemId: UUID, isCompleted: Bool) throws {
        guard let mo = try fetchItem(listId: listId, itemId: itemId) else { return }
        mo.isCompleted = isCompleted
        if let list = mo.list {
            list.updatedAt = Date()
        }
        try saveContext()
    }

    // MARK: - Fetch helpers

    /// Resolves lists by comparing UUIDs in Swift. NSPredicate + UUID attributes is unreliable across OS versions.
    private func fetchList(id: UUID) throws -> ShoppingListEntity? {
        let r: NSFetchRequest<ShoppingListEntity> = ShoppingListEntity.fetchRequest()
        let all = try viewContext.fetch(r)
        return all.first { $0.id == id }
    }

    private func fetchItem(listId: UUID, itemId: UUID) throws -> ShoppingItemEntity? {
        let r: NSFetchRequest<ShoppingItemEntity> = ShoppingItemEntity.fetchRequest()
        let all = try viewContext.fetch(r)
        return all.first { $0.id == itemId && $0.list?.id == listId }
    }

    private func fetchStore(id: UUID) throws -> StoreEntity? {
        let r: NSFetchRequest<StoreEntity> = StoreEntity.fetchRequest()
        let all = try viewContext.fetch(r)
        return all.first { $0.id == id }
    }

    private func fetchAisle(id: UUID, storeId: UUID) throws -> AisleEntity? {
        let r: NSFetchRequest<AisleEntity> = AisleEntity.fetchRequest()
        let all = try viewContext.fetch(r)
        return all.first { $0.id == id && $0.store?.id == storeId }
    }

    private func firstStoreId() throws -> UUID? {
        let r: NSFetchRequest<StoreEntity> = StoreEntity.fetchRequest()
        let all = try viewContext.fetch(r)
        return all.first?.id
    }

    private func mapAppState() throws -> AppState {
        let r: NSFetchRequest<ShoppingListEntity> = ShoppingListEntity.fetchRequest()
        r.sortDescriptors = [NSSortDescriptor(keyPath: \ShoppingListEntity.updatedAt, ascending: false)]
        let entities = try viewContext.fetch(r)
        let lists = entities.compactMap { mapList($0) }
        let stores = try mapStores()
        let activeStoreId = resolvedActiveStoreId(stores: stores)
        return AppState(
            lists: lists,
            stores: stores,
            selectedListId: lists.first?.id,
            activeStoreId: activeStoreId
        )
    }

    private func mapList(_ entity: ShoppingListEntity) -> ShoppingList? {
        guard let listId = entity.id else { return nil }
        let set = entity.items as? Set<ShoppingItemEntity> ?? []
        let items = set.compactMap { mapItem($0) }
        return ShoppingList(
            id: listId,
            name: entity.name ?? "Untitled list",
            items: items,
            updatedAt: entity.updatedAt ?? .distantPast,
            storeId: entity.store?.id
        )
    }

    private func mapItem(_ entity: ShoppingItemEntity) -> ShoppingItem? {
        guard let itemId = entity.id else { return nil }
        return ShoppingItem(
            id: itemId,
            name: entity.name ?? "",
            category: entity.category,
            categoryManualOverride: entity.categoryManualOverride,
            aisleId: entity.aisle?.id,
            quantity: max(1, Int(entity.quantity)),
            isCompleted: entity.isCompleted,
            createdAt: entity.createdAt ?? .distantPast
        )
    }

    private func mapStores() throws -> [Store] {
        let r: NSFetchRequest<StoreEntity> = StoreEntity.fetchRequest()
        let entities = try viewContext.fetch(r)
        return entities.compactMap(mapStore)
    }

    private func mapStore(_ entity: StoreEntity) -> Store? {
        guard let id = entity.id else { return nil }
        let aisles = (entity.aisles as? Set<AisleEntity> ?? [])
            .compactMap(mapAisle)
        return Store(id: id, name: entity.name ?? "Store", isDefault: entity.isDefault, aisles: aisles)
    }

    private func mapAisle(_ entity: AisleEntity) -> Aisle? {
        guard let id = entity.id else { return nil }
        return Aisle(id: id, name: entity.name ?? "Aisle", orderIndex: Int(entity.orderIndex))
    }

    private func normalizeAisleOrder(for store: StoreEntity) {
        let aisles = (store.aisles as? Set<AisleEntity> ?? []).sorted {
            if $0.orderIndex != $1.orderIndex { return $0.orderIndex < $1.orderIndex }
            return ($0.name ?? "") < ($1.name ?? "")
        }
        for (idx, aisle) in aisles.enumerated() {
            aisle.orderIndex = Int32(idx)
        }
    }

    private func resolvedAisleForAssignment(_ aisleId: UUID?) throws -> AisleEntity? {
        guard let aisleId else { return nil }
        let r: NSFetchRequest<AisleEntity> = AisleEntity.fetchRequest()
        let all = try viewContext.fetch(r)
        return all.first { $0.id == aisleId }
    }

    private func currentActiveStoreId() -> UUID? {
        guard let raw = UserDefaults.standard.string(forKey: Self.activeStoreKey) else { return nil }
        return UUID(uuidString: raw)
    }

    private func resolvedActiveStoreId(stores: [Store]) -> UUID? {
        if let configured = currentActiveStoreId(), stores.contains(where: { $0.id == configured }) {
            return configured
        }
        return stores.first(where: \.isDefault)?.id ?? stores.first?.id
    }

    private func updateDefaultStoreFlag(activeStoreId: UUID?) throws {
        let r: NSFetchRequest<StoreEntity> = StoreEntity.fetchRequest()
        let stores = try viewContext.fetch(r)
        for s in stores {
            s.isDefault = (s.id == activeStoreId)
        }
        try saveContext()
    }
}

private enum StoreError: LocalizedError {
    case listNotFound(UUID)
    case storeNotFound(UUID)

    var errorDescription: String? {
        switch self {
        case .listNotFound(let id):
            return "Could not find list \(id.uuidString) in the database."
        case .storeNotFound(let id):
            return "Could not find store \(id.uuidString) in the database."
        }
    }
}
