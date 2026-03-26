import Foundation

/// A route optimizer can evolve from linear aisle ordering to graph shortest-path routing.
protocol RouteOptimizing {
    func buildRoute(items: [ShoppingItem], aisles: [Aisle]) -> OptimizedRoute
}

struct OptimizedRoute: Equatable {
    struct Stop: Identifiable, Equatable {
        enum Kind: Equatable {
            case aisle(Aisle)
            case unassigned
        }

        var kind: Kind
        var items: [ShoppingItem]
        var orderIndex: Int

        var id: String {
            switch kind {
            case .aisle(let aisle):
                return "aisle-\(aisle.id.uuidString)"
            case .unassigned:
                return "unassigned"
            }
        }

        var title: String {
            switch kind {
            case .aisle(let aisle):
                return aisle.name
            case .unassigned:
                return "Unassigned"
            }
        }

        var isUnassigned: Bool {
            if case .unassigned = kind { return true }
            return false
        }
    }

    var stops: [Stop]

    var totalItems: Int {
        stops.reduce(0) { $0 + $1.items.count }
    }

    var completedItems: Int {
        stops.reduce(0) { running, stop in
            running + stop.items.filter(\.isCompleted).count
        }
    }
}

/// First implementation: linear walk using `Aisle.orderIndex`.
/// Future graph implementation can preserve this API and replace internals.
struct RouteOptimizationService: RouteOptimizing {
    func buildRoute(items: [ShoppingItem], aisles: [Aisle]) -> OptimizedRoute {
        guard !items.isEmpty else { return OptimizedRoute(stops: []) }

        let aisleById = Dictionary(uniqueKeysWithValues: aisles.map { ($0.id, $0) })
        let sortedAisles = aisles.sorted {
            if $0.orderIndex != $1.orderIndex { return $0.orderIndex < $1.orderIndex }
            return $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending
        }

        var itemBucketsByAisle: [UUID: [ShoppingItem]] = [:]
        var unassigned: [ShoppingItem] = []

        for item in items {
            if let aisleId = item.aisleId, aisleById[aisleId] != nil {
                itemBucketsByAisle[aisleId, default: []].append(item)
            } else {
                unassigned.append(item)
            }
        }

        var stops: [OptimizedRoute.Stop] = []
        for aisle in sortedAisles {
            guard var aisleItems = itemBucketsByAisle[aisle.id], !aisleItems.isEmpty else { continue }
            aisleItems.sort(by: itemSort)
            stops.append(
                OptimizedRoute.Stop(
                    kind: .aisle(aisle),
                    items: aisleItems,
                    orderIndex: aisle.orderIndex
                )
            )
        }

        if !unassigned.isEmpty {
            unassigned.sort(by: itemSort)
            stops.append(
                OptimizedRoute.Stop(
                    kind: .unassigned,
                    items: unassigned,
                    orderIndex: Int.max
                )
            )
        }

        return OptimizedRoute(stops: stops)
    }

    private var itemSort: (ShoppingItem, ShoppingItem) -> Bool {
        { lhs, rhs in
            if lhs.isCompleted != rhs.isCompleted { return !lhs.isCompleted }
            return lhs.createdAt < rhs.createdAt
        }
    }
}
