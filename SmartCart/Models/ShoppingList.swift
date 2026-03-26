import Foundation

/// Aggregate root for everything the shopper is buying on one trip or recurring list.
/// Phase 1 uses a single active list; the model already supports multiple lists via `id` + `name`.
struct ShoppingList: Identifiable, Codable, Equatable {
    var id: UUID
    var name: String
    var items: [ShoppingItem]
    var updatedAt: Date

    init(
        id: UUID = UUID(),
        name: String = "My List",
        items: [ShoppingItem] = [],
        updatedAt: Date = Date()
    ) {
        self.id = id
        self.name = name
        self.items = items
        self.updatedAt = updatedAt
    }

    /// Items not yet checked off, sorted by created date (oldest first) for a predictable shopping flow.
    var activeItems: [ShoppingItem] {
        items
            .filter { !$0.isCompleted }
            .sorted { $0.createdAt < $1.createdAt }
    }

    /// Completed items at the bottom, most recently completed last (approximated via array order after toggle).
    var completedItems: [ShoppingItem] {
        items.filter(\.isCompleted)
    }
}
