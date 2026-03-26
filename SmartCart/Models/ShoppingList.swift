import Foundation

/// Aggregate root for everything the shopper is buying on one trip or recurring list (domain model, mapped from Core Data).
struct ShoppingList: Identifiable, Codable, Equatable {
    var id: UUID
    var name: String
    var items: [ShoppingItem]
    var updatedAt: Date
    var storeId: UUID?

    init(
        id: UUID = UUID(),
        name: String = "My List",
        items: [ShoppingItem] = [],
        updatedAt: Date = Date(),
        storeId: UUID? = nil
    ) {
        self.id = id
        self.name = name
        self.items = items
        self.updatedAt = updatedAt
        self.storeId = storeId
    }

    /// Active items in stable “shopping order”: incomplete first, oldest created first (ready for future aisle grouping).
    var activeItemsOrdered: [ShoppingItem] {
        items
            .filter { !$0.isCompleted }
            .sorted { $0.createdAt < $1.createdAt }
    }

    var completedItems: [ShoppingItem] {
        items.filter(\.isCompleted).sorted { $0.createdAt < $1.createdAt }
    }

    /// Sections for grouped list UI: canonical category order, incomplete items before complete within each bucket.
    func itemsGroupedByCategory() -> [(category: GroceryCategory, items: [ShoppingItem])] {
        let grouped = Dictionary(grouping: items) { GroceryCategory.resolved(from: $0.category) }
        return GroceryCategory.displayOrder.compactMap { cat in
            guard let bucket = grouped[cat], !bucket.isEmpty else { return nil }
            let sorted = bucket.sorted { a, b in
                if a.isCompleted != b.isCompleted { return !a.isCompleted }
                return a.createdAt < b.createdAt
            }
            return (cat, sorted)
        }
    }
}
