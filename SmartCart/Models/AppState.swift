import Foundation

/// Top-level persisted state: multiple lists and optional last-opened list (for future deep links).
struct AppState: Codable, Equatable {
    var lists: [ShoppingList]
    var stores: [Store]
    var selectedListId: UUID?
    var activeStoreId: UUID?

    init(
        lists: [ShoppingList] = [],
        stores: [Store] = [],
        selectedListId: UUID? = nil,
        activeStoreId: UUID? = nil
    ) {
        self.lists = lists
        self.stores = stores
        self.selectedListId = selectedListId
        self.activeStoreId = activeStoreId
    }

    /// Lists ordered for the home screen: most recently changed first.
    var listsSortedForDisplay: [ShoppingList] {
        lists.sorted { $0.updatedAt > $1.updatedAt }
    }

    var storesSortedByName: [Store] {
        stores.sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
    }

    enum CodingKeys: String, CodingKey {
        case lists, stores, selectedListId, activeStoreId
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        lists = try c.decodeIfPresent([ShoppingList].self, forKey: .lists) ?? []
        stores = try c.decodeIfPresent([Store].self, forKey: .stores) ?? []
        selectedListId = try c.decodeIfPresent(UUID.self, forKey: .selectedListId)
        activeStoreId = try c.decodeIfPresent(UUID.self, forKey: .activeStoreId)
    }

    func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encode(lists, forKey: .lists)
        try c.encode(stores, forKey: .stores)
        try c.encodeIfPresent(selectedListId, forKey: .selectedListId)
        try c.encodeIfPresent(activeStoreId, forKey: .activeStoreId)
    }
}
