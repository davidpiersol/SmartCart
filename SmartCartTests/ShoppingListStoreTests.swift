import CoreData
import XCTest
@testable import SmartCart

/// Validates list/item persistence independent of SwiftUI. Run with ⌘U or `xcodebuild test`.
@MainActor
final class ShoppingListStoreTests: XCTestCase {
    private var container: NSPersistentContainer!
    private var store: CoreDataShoppingListStore!

    override func setUp() async throws {
        try await super.setUp()
        let exp = expectation(description: "load stores")
        container = NSPersistentContainer(name: "SmartCart")
        let desc = NSPersistentStoreDescription()
        desc.type = NSInMemoryStoreType
        container.persistentStoreDescriptions = [desc]
        container.loadPersistentStores { _, error in
            XCTAssertNil(error)
            exp.fulfill()
        }
        await fulfillment(of: [exp], timeout: 10)
        store = CoreDataShoppingListStore(container: container)
    }

    override func tearDown() async throws {
        container = nil
        store = nil
        try await super.tearDown()
    }

    func testCreateListThenAddItemAppearsInLoadState() throws {
        let listId = try store.createList(named: "Groceries")
        try store.addItem(
            listId: listId,
            name: "Milk",
            quantity: 2,
            category: GroceryCategory.dairy.rawValue,
            categoryManualOverride: false,
            aisleId: nil
        )

        let state = try store.loadState()
        let list = state.lists.first { $0.id == listId }
        XCTAssertNotNil(list, "List should exist after create + add")
        XCTAssertEqual(list?.items.count, 1)
        XCTAssertEqual(list?.items.first?.name, "Milk")
        XCTAssertEqual(list?.items.first?.quantity, 2)
        XCTAssertEqual(list?.items.first?.category, GroceryCategory.dairy.rawValue)
        XCTAssertFalse(list?.items.first?.categoryManualOverride ?? true)
        XCTAssertFalse(list?.items.first?.isCompleted ?? true)
    }

    func testAddItemToSecondListDoesNotMix() throws {
        let a = try store.createList(named: "A")
        let b = try store.createList(named: "B")
        try store.addItem(
            listId: a,
            name: "Eggs",
            quantity: 1,
            category: GroceryCategory.dairy.rawValue,
            categoryManualOverride: false,
            aisleId: nil
        )
        try store.addItem(
            listId: b,
            name: "Soap",
            quantity: 1,
            category: GroceryCategory.household.rawValue,
            categoryManualOverride: true,
            aisleId: nil
        )

        let state = try store.loadState()
        let listA = state.lists.first { $0.id == a }
        let listB = state.lists.first { $0.id == b }
        XCTAssertEqual(listA?.items.count, 1)
        XCTAssertEqual(listB?.items.count, 1)
        XCTAssertEqual(listA?.items.first?.name, "Eggs")
        XCTAssertEqual(listB?.items.first?.name, "Soap")
        XCTAssertEqual(listB?.items.first?.categoryManualOverride, true)
    }

    func testManualCategoryPersistsThroughUpdate() throws {
        let listId = try store.createList(named: "L")
        try store.addItem(
            listId: listId,
            name: "Thing",
            quantity: 1,
            category: GroceryCategory.frozen.rawValue,
            categoryManualOverride: true,
            aisleId: nil
        )
        guard var item = try store.loadState().lists.first(where: { $0.id == listId })?.items.first else {
            return XCTFail("missing item")
        }
        item.name = "Renamed"
        item.categoryManualOverride = true
        try store.updateItem(listId: listId, item: item)

        let loaded = try store.loadState().lists.first { $0.id == listId }?.items.first
        XCTAssertEqual(loaded?.name, "Renamed")
        XCTAssertEqual(loaded?.category, GroceryCategory.frozen.rawValue)
        XCTAssertEqual(loaded?.categoryManualOverride, true)
    }

    func testStoreAisleAssignmentPersists() throws {
        let listId = try store.createList(named: "Route")
        let storeId = try store.createStore(named: "Target")
        _ = try store.createAisle(storeId: storeId, name: "Produce")
        let freezerId = try store.createAisle(storeId: storeId, name: "Frozen")
        try store.setActiveStore(id: storeId)

        try store.addItem(
            listId: listId,
            name: "Ice cream",
            quantity: 1,
            category: GroceryCategory.frozen.rawValue,
            categoryManualOverride: false,
            aisleId: freezerId
        )

        let state = try store.loadState()
        XCTAssertEqual(state.activeStoreId, storeId)
        let loadedStore = state.stores.first(where: { $0.id == storeId })
        XCTAssertEqual(loadedStore?.aislesByOrder.map(\.name), ["Produce", "Frozen"])
        let item = state.lists.first(where: { $0.id == listId })?.items.first
        XCTAssertEqual(item?.aisleId, freezerId)
    }
}
