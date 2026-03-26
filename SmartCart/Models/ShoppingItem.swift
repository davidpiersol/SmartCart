import Foundation

/// A single line item on a shopping list.
/// Designed to stay `Codable` and stable for persistence; extend with aisle/store metadata later without breaking v1 payloads.
struct ShoppingItem: Identifiable, Codable, Equatable, Hashable {
    /// Stable identity for list edits, completion toggles, and future sync.
    var id: UUID

    /// Display name shown in the list.
    var name: String

    /// Optional merchandising category (produce, dairy, etc.). Phase 1 is manual/string; later this can reference a taxonomy ID.
    var category: String?

    /// Whether the shopper has picked up this item.
    var isCompleted: Bool

    /// Creation time supports default sorting and future “recently added” UX.
    var createdAt: Date

    init(
        id: UUID = UUID(),
        name: String,
        category: String? = nil,
        isCompleted: Bool = false,
        createdAt: Date = Date()
    ) {
        self.id = id
        self.name = name
        self.category = category
        self.isCompleted = isCompleted
        self.createdAt = createdAt
    }
}
