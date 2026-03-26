import Foundation

// MARK: - Repository protocol

/// Persists the current `ShoppingList`. Keeps storage behind an abstraction so Phase 2 can swap in Core Data, CloudKit, etc.
protocol ShoppingListRepository {
    func load() async throws -> ShoppingList
    func save(_ list: ShoppingList) async throws
}

// MARK: - UserDefaults implementation

/// Lightweight persistence for Phase 1. Suitable for typical grocery list sizes; migrate when relational queries (per-store layouts) appear.
struct UserDefaultsShoppingListRepository: ShoppingListRepository {
    private enum Keys {
        static let storageKey = "com.smartcart.persistence.shoppingList.v1"
    }

    private let defaults: UserDefaults
    private let encoder: JSONEncoder
    private let decoder: JSONDecoder

    init(
        defaults: UserDefaults = .standard,
        encoder: JSONEncoder = JSONEncoder(),
        decoder: JSONDecoder = JSONDecoder()
    ) {
        self.defaults = defaults
        self.encoder = encoder
        encoder.dateEncodingStrategy = .iso8601
        self.decoder = decoder
        decoder.dateDecodingStrategy = .iso8601
    }

    func load() async throws -> ShoppingList {
        guard let data = defaults.data(forKey: Keys.storageKey) else {
            return ShoppingList()
        }
        do {
            return try decoder.decode(ShoppingList.self, from: data)
        } catch {
            // Corrupt payload — fail safe with empty list rather than crashing the app.
            return ShoppingList()
        }
    }

    func save(_ list: ShoppingList) async throws {
        let data = try encoder.encode(list)
        defaults.set(data, forKey: Keys.storageKey)
    }
}
