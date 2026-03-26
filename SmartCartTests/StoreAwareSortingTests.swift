import CoreData
import XCTest
@testable import SmartCart

@MainActor
final class StoreAwareSortingTests: XCTestCase {
    private var container: NSPersistentContainer!
    private var store: CoreDataShoppingListStore!
    private var viewModel: SmartCartViewModel!

    override func setUp() async throws {
        try await super.setUp()
        container = NSPersistentContainer(name: "SmartCart")
        let desc = NSPersistentStoreDescription()
        desc.type = NSInMemoryStoreType
        container.persistentStoreDescriptions = [desc]
        let exp = expectation(description: "load")
        container.loadPersistentStores { _, error in
            XCTAssertNil(error)
            exp.fulfill()
        }
        await fulfillment(of: [exp], timeout: 10)
        store = CoreDataShoppingListStore(container: container)
        viewModel = SmartCartViewModel(store: store, categorization: RuleBasedCategorizationService())
    }

    override func tearDown() async throws {
        viewModel = nil
        store = nil
        container = nil
        try await super.tearDown()
    }

    func testSectionsUseAisleOrderThenCategoryFallback() throws {
        let listId = try store.createList(named: "Trip")
        let storeId = try store.createStore(named: "Market")
        let produceAisleId = try store.createAisle(storeId: storeId, name: "Produce")
        let frozenAisleId = try store.createAisle(storeId: storeId, name: "Frozen")
        try store.setActiveStore(id: storeId)

        try store.addItem(listId: listId, name: "Apple", quantity: 1, category: GroceryCategory.produce.rawValue, categoryManualOverride: false, aisleId: produceAisleId)
        try store.addItem(listId: listId, name: "Ice cream", quantity: 1, category: GroceryCategory.frozen.rawValue, categoryManualOverride: false, aisleId: frozenAisleId)
        try store.addItem(listId: listId, name: "Milk", quantity: 1, category: GroceryCategory.dairy.rawValue, categoryManualOverride: false, aisleId: nil)
        try store.addItem(listId: listId, name: "Rice", quantity: 1, category: GroceryCategory.pantry.rawValue, categoryManualOverride: false, aisleId: nil)

        viewModel = SmartCartViewModel(store: store, categorization: RuleBasedCategorizationService())
        guard let list = viewModel.list(id: listId) else { return XCTFail("missing list") }

        let sections = viewModel.sectionsForList(list)
        XCTAssertEqual(sections.map(\.title), ["Produce", "Frozen", "Dairy", "Pantry"])
    }

    func testReorderAislesPersists() throws {
        let storeId = try store.createStore(named: "Target")
        let a = try store.createAisle(storeId: storeId, name: "A")
        let b = try store.createAisle(storeId: storeId, name: "B")
        let c = try store.createAisle(storeId: storeId, name: "C")

        try store.reorderAisles(storeId: storeId, orderedAisleIds: [c, a, b])
        let state = try store.loadState()
        let names = state.stores.first(where: { $0.id == storeId })?.aislesByOrder.map(\.name)
        XCTAssertEqual(names, ["C", "A", "B"])
    }
}
