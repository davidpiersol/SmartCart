import XCTest
@testable import SmartCart

final class RouteOptimizationServiceTests: XCTestCase {
    private let sut = RouteOptimizationService()

    func testBuildRouteOrdersStopsByAisleOrderIndexAndAppendsUnassigned() {
        let produce = Aisle(id: UUID(), name: "Produce", orderIndex: 0)
        let dairy = Aisle(id: UUID(), name: "Dairy", orderIndex: 1)
        let freezer = Aisle(id: UUID(), name: "Frozen", orderIndex: 2)

        let items = [
            ShoppingItem(name: "Ice Cream", aisleId: freezer.id),
            ShoppingItem(name: "Milk", aisleId: dairy.id),
            ShoppingItem(name: "Bananas", aisleId: produce.id),
            ShoppingItem(name: "Mystery item", aisleId: nil),
        ]

        let route = sut.buildRoute(items: items, aisles: [freezer, dairy, produce])

        XCTAssertEqual(route.stops.map(\.title), ["Produce", "Dairy", "Frozen", "Unassigned"])
        XCTAssertEqual(route.totalItems, 4)
    }

    func testBuildRouteDeduplicatesAislesIntoSingleStop() {
        let pantry = Aisle(id: UUID(), name: "Pantry", orderIndex: 3)
        let items = [
            ShoppingItem(name: "Pasta", aisleId: pantry.id),
            ShoppingItem(name: "Olive oil", aisleId: pantry.id),
            ShoppingItem(name: "Rice", aisleId: pantry.id)
        ]

        let route = sut.buildRoute(items: items, aisles: [pantry])

        XCTAssertEqual(route.stops.count, 1)
        XCTAssertEqual(route.stops.first?.title, "Pantry")
        XCTAssertEqual(route.stops.first?.items.count, 3)
    }
}
