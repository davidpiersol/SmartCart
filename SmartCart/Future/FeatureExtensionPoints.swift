import Foundation

// MARK: - Future feature seams (no implementations in Phase 1)

/// When aisle-aware sorting ships, items can expose or resolve an `AisleRef` for a given `StoreID`.
protocol AisleSortableItem {
    var id: UUID { get }
}

extension ShoppingItem: AisleSortableItem {}

/// Placeholder for per-store floor plans, fixture polygons, adjacency graph, etc.
protocol StoreLayoutProviding {
    associatedtype StoreID: Hashable
    // func graph(for store: StoreID) async throws -> StoreNavigationGraph
}

/// Routing / TSP-style optimization will consume a graph + item constraints; keep empty until maps exist.
protocol ShoppingRoutePlanning {
    // func optimizedVisitOrder(
    //     items: [ShoppingItem],
    //     layout: StoreNavigationGraph,
    //     policy: RoutePolicy
    // ) async throws -> [UUID]
}

/// Later, categories can become a taxonomy (ID, synonyms, default aisles) instead of free text.
protocol CategoryTaxonomy {
    // func normalizedCategory(for raw: String) async throws -> CategoryID?
}
