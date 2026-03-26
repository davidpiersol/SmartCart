import Foundation
import SwiftUI

/// Coordinates shopping lists and items; all persistence goes through `ShoppingListStore` (Core Data in production).
@MainActor
final class SmartCartViewModel: ObservableObject {
    @Published private(set) var state: AppState
    @Published var lastErrorMessage: String?

    private let store: ShoppingListStore
    /// Rule-based today; inject a different `ItemCategorizing` for tests or future ML/API backends.
    let categorization: ItemCategorizing

    init(store: ShoppingListStore, categorization: ItemCategorizing = RuleBasedCategorizationService()) {
        self.store = store
        self.categorization = categorization
        self.state = AppState()
        refresh()
    }

    var listsForHome: [ShoppingList] {
        state.listsSortedForDisplay
    }

    var storesForDisplay: [Store] {
        state.storesSortedByName
    }

    var activeStore: Store? {
        guard let id = state.activeStoreId else { return nil }
        return state.stores.first(where: { $0.id == id })
    }

    func list(id: UUID) -> ShoppingList? {
        state.lists.first { $0.id == id }
    }

    /// Ensures first-time users see a starter list once the Core Data stack is ready.
    func ensureDefaultListIfNeeded() {
        guard state.lists.isEmpty else { return }
        perform { _ = try self.store.createList(named: "My List") }
    }

    /// Creates a list and returns its id (for programmatic navigation). Errors surface via `lastErrorMessage`.
    @discardableResult
    func createList(named name: String) -> UUID? {
        do {
            let id = try store.createList(named: name)
            refresh()
            return id
        } catch {
            lastErrorMessage = error.localizedDescription
            return nil
        }
    }

    func renameList(id: UUID, to newName: String) {
        perform { try self.store.renameList(id: id, to: newName) }
    }

    func deleteLists(at offsets: IndexSet) {
        let ordered = listsForHome
        let ids = offsets.map { ordered[$0].id }
        perform {
            for id in ids {
                try self.store.deleteList(id: id)
            }
        }
    }

    func deleteList(id: UUID) {
        perform { try self.store.deleteList(id: id) }
    }

    func createStore(named name: String) {
        perform {
            let id = try self.store.createStore(named: name)
            try self.store.setActiveStore(id: id)
        }
    }

    func deleteStores(at offsets: IndexSet) {
        let stores = storesForDisplay
        perform {
            for idx in offsets {
                try self.store.deleteStore(id: stores[idx].id)
            }
        }
    }

    func setActiveStore(id: UUID?) {
        perform {
            try self.store.setActiveStore(id: id)
        }
    }

    func createAisle(storeId: UUID, name: String) {
        perform {
            _ = try self.store.createAisle(storeId: storeId, name: name)
        }
    }

    func renameAisle(storeId: UUID, aisleId: UUID, to name: String) {
        perform {
            try self.store.renameAisle(id: aisleId, storeId: storeId, to: name)
        }
    }

    func deleteAisles(at offsets: IndexSet, storeId: UUID) {
        guard let storeModel = state.stores.first(where: { $0.id == storeId }) else { return }
        let ordered = storeModel.aislesByOrder
        perform {
            for idx in offsets {
                try self.store.deleteAisle(id: ordered[idx].id, storeId: storeId)
            }
        }
    }

    func moveAisles(storeId: UUID, from source: IndexSet, to destination: Int) {
        guard let storeModel = state.stores.first(where: { $0.id == storeId }) else { return }
        var ordered = storeModel.aislesByOrder
        ordered.move(fromOffsets: source, toOffset: destination)
        let ids = ordered.map(\.id)
        perform {
            try self.store.reorderAisles(storeId: storeId, orderedAisleIds: ids)
        }
    }

    func addItem(
        listId: UUID,
        name: String,
        quantity: Int,
        categoryMode: CategorySelectionMode,
        aisleId: UUID?
    ) {
        let category: String?
        let manual: Bool
        switch categoryMode {
        case .automatic:
            category = categorization.suggestedCategory(for: name).rawValue
            manual = false
        case .manual(let g):
            category = g.rawValue
            manual = true
        }
        perform {
            try self.store.addItem(
                listId: listId,
                name: name,
                quantity: quantity,
                category: category,
                categoryManualOverride: manual,
                aisleId: aisleId
            )
        }
    }

    func deleteItems(at offsets: IndexSet, from items: [ShoppingItem], listId: UUID) {
        let ids = Set(offsets.map { items[$0].id })
        perform {
            try self.store.deleteItems(listId: listId, itemIds: ids)
        }
    }

    func toggleCompleted(listId: UUID, item: ShoppingItem) {
        perform {
            try self.store.setItemCompleted(
                listId: listId,
                itemId: item.id,
                isCompleted: !item.isCompleted
            )
        }
    }

    func updateItem(listId: UUID, item: ShoppingItem) {
        perform {
            try self.store.updateItem(listId: listId, item: item)
        }
    }

    struct ListDisplaySection: Identifiable {
        enum Kind: Hashable {
            case aisle(UUID)
            case category(GroceryCategory)
        }

        var kind: Kind
        var title: String
        var symbolName: String
        var tint: Color
        var items: [ShoppingItem]
        var sortKey: Int

        var id: String {
            switch kind {
            case .aisle(let id): return "aisle-\(id)"
            case .category(let c): return "cat-\(c.rawValue)"
            }
        }
    }

    func sectionsForList(_ list: ShoppingList) -> [ListDisplaySection] {
        let active = activeStore
        let aisleById: [UUID: Aisle] = Dictionary(uniqueKeysWithValues: (active?.aisles ?? []).map { ($0.id, $0) })

        let sortedItems = list.items.sorted { lhs, rhs in
            let lhsAisleIdx = lhs.aisleId.flatMap { aisleById[$0]?.orderIndex } ?? Int.max
            let rhsAisleIdx = rhs.aisleId.flatMap { aisleById[$0]?.orderIndex } ?? Int.max
            if lhsAisleIdx != rhsAisleIdx { return lhsAisleIdx < rhsAisleIdx }

            let lhsCat = GroceryCategory.resolved(from: lhs.category)
            let rhsCat = GroceryCategory.resolved(from: rhs.category)
            let lhsCatIdx = GroceryCategory.displayOrder.firstIndex(of: lhsCat) ?? Int.max
            let rhsCatIdx = GroceryCategory.displayOrder.firstIndex(of: rhsCat) ?? Int.max
            if lhsCatIdx != rhsCatIdx { return lhsCatIdx < rhsCatIdx }

            if lhs.isCompleted != rhs.isCompleted { return !lhs.isCompleted }
            return lhs.createdAt < rhs.createdAt
        }

        var aisleBuckets: [UUID: [ShoppingItem]] = [:]
        var categoryBuckets: [GroceryCategory: [ShoppingItem]] = [:]
        for item in sortedItems {
            if let id = item.aisleId, aisleById[id] != nil {
                aisleBuckets[id, default: []].append(item)
            } else {
                let cat = GroceryCategory.resolved(from: item.category)
                categoryBuckets[cat, default: []].append(item)
            }
        }

        var sections: [ListDisplaySection] = []
        if let active {
            for aisle in active.aislesByOrder {
                guard let items = aisleBuckets[aisle.id], !items.isEmpty else { continue }
                sections.append(
                    ListDisplaySection(
                        kind: .aisle(aisle.id),
                        title: aisle.name,
                        symbolName: "square.3.layers.3d.top.filled",
                        tint: .accentColor,
                        items: items,
                        sortKey: aisle.orderIndex
                    )
                )
            }
        }
        for cat in GroceryCategory.displayOrder {
            guard let items = categoryBuckets[cat], !items.isEmpty else { continue }
            sections.append(
                ListDisplaySection(
                    kind: .category(cat),
                    title: cat.displayName,
                    symbolName: cat.symbolName,
                    tint: cat.tint,
                    items: items,
                    sortKey: 10_000 + (GroceryCategory.displayOrder.firstIndex(of: cat) ?? 0)
                )
            )
        }
        return sections.sorted { $0.sortKey < $1.sortKey }
    }

    func suggestedAisleId(for category: GroceryCategory, in store: Store?) -> UUID? {
        guard let store else { return nil }
        let target = category.displayName.lowercased()
        return store.aislesByOrder.first(where: {
            let name = $0.name.lowercased()
            return name.contains(target) || target.contains(name)
        })?.id
    }

    private func perform(_ action: () throws -> Void) {
        do {
            try action()
            refresh()
        } catch {
            lastErrorMessage = error.localizedDescription
        }
    }

    private func refresh() {
        do {
            state = try store.loadState()
        } catch {
            lastErrorMessage = error.localizedDescription
        }
    }
}
