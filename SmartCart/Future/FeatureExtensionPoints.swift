import Foundation

// MARK: - Future feature seams (routing, maps — not implemented yet)

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

/// `ShoppingItem.category` is persisted in Core Data today; a taxonomy service can normalize values later.
protocol CategoryTaxonomy {
    // func normalizedCategory(for raw: String) async throws -> CategoryID?
}

// MARK: - Phase 3 categorization seam

/// `ItemCategorizing` (see `CategorizationService.swift`) is the injection point for smarter backends:
/// Core ML on-device models, remote APIs, or store-specific aisle graphs—without changing view models.
