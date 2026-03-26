import Foundation

/// A single line item on a shopping list.
/// Designed to stay `Codable` and stable for persistence; extend with aisle/store metadata later without breaking v1 payloads.
struct ShoppingItem: Identifiable, Codable, Equatable, Hashable {
    /// Stable identity for list edits, completion toggles, and future sync.
    var id: UUID

    /// Display name shown in the list.
    var name: String

    /// Merchandising category (`GroceryCategory.rawValue`). Nil or unknown strings read as `.other` in UI.
    var category: String?

    /// When true, auto-categorization must not change `category` (user override).
    var categoryManualOverride: Bool

    /// Optional aisle assignment in the active/default store.
    var aisleId: UUID?

    /// Pack or unit count (Phase 2). Must be at least 1.
    var quantity: Int

    /// Whether the shopper has picked up this item.
    var isCompleted: Bool

    /// Creation time supports default sorting and future “recently added” UX.
    var createdAt: Date

    init(
        id: UUID = UUID(),
        name: String,
        category: String? = nil,
        categoryManualOverride: Bool = false,
        aisleId: UUID? = nil,
        quantity: Int = 1,
        isCompleted: Bool = false,
        createdAt: Date = Date()
    ) {
        self.id = id
        self.name = name
        self.category = category
        self.categoryManualOverride = categoryManualOverride
        self.aisleId = aisleId
        self.quantity = max(1, quantity)
        self.isCompleted = isCompleted
        self.createdAt = createdAt
    }

    enum CodingKeys: String, CodingKey {
        case id, name, category, categoryManualOverride, aisleId, quantity, isCompleted, createdAt
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decode(UUID.self, forKey: .id)
        name = try c.decode(String.self, forKey: .name)
        category = try c.decodeIfPresent(String.self, forKey: .category)
        categoryManualOverride = try c.decodeIfPresent(Bool.self, forKey: .categoryManualOverride) ?? false
        aisleId = try c.decodeIfPresent(UUID.self, forKey: .aisleId)
        quantity = try c.decodeIfPresent(Int.self, forKey: .quantity) ?? 1
        isCompleted = try c.decode(Bool.self, forKey: .isCompleted)
        createdAt = try c.decode(Date.self, forKey: .createdAt)
    }

    func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encode(id, forKey: .id)
        try c.encode(name, forKey: .name)
        try c.encodeIfPresent(category, forKey: .category)
        try c.encode(categoryManualOverride, forKey: .categoryManualOverride)
        try c.encodeIfPresent(aisleId, forKey: .aisleId)
        try c.encode(quantity, forKey: .quantity)
        try c.encode(isCompleted, forKey: .isCompleted)
        try c.encode(createdAt, forKey: .createdAt)
    }
}
