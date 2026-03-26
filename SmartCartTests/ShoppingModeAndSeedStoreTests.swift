import CoreData
import XCTest
@testable import SmartCart

@MainActor
final class ShoppingModeAndSeedStoreTests: XCTestCase {
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

    func testSeedStoresAreInsertedWithGeofenceData() throws {
        try store.upsertSeedStores(StoreSeedCatalog.albuquerqueMVP)
        let state = try store.loadState()

        XCTAssertGreaterThanOrEqual(state.stores.count, StoreSeedCatalog.albuquerqueMVP.count)
        let walmart = state.stores.first(where: { $0.name == "Walmart Supercenter" })
        XCTAssertNotNil(walmart)
        XCTAssertNotNil(walmart?.latitude)
        XCTAssertNotNil(walmart?.longitude)
        XCTAssertGreaterThan(walmart?.geofenceRadiusMeters ?? 0, 0)
    }

    func testSeedStoresUpsertUpdatesInsteadOfDuplicatingByName() throws {
        try store.upsertSeedStores([SeedStoreDefinition(name: "Target", latitude: 35.0, longitude: -106.0, radiusMeters: 140)])
        try store.upsertSeedStores([SeedStoreDefinition(name: "Target", latitude: 35.5, longitude: -106.5, radiusMeters: 180)])

        let state = try store.loadState()
        let matches = state.stores.filter { $0.name == "Target" }
        XCTAssertEqual(matches.count, 1)
        guard let match = matches.first else {
            return XCTFail("Expected a single Target store")
        }
        XCTAssertEqual(match.latitude ?? 0, 35.5, accuracy: 0.0001)
        XCTAssertEqual(match.longitude ?? 0, -106.5, accuracy: 0.0001)
        XCTAssertEqual(match.geofenceRadiusMeters, 180, accuracy: 0.001)
    }

    func testActivateShoppingModeSetsRouteModeAndStore() throws {
        let storeId = try store.createStore(named: "Test Store")
        viewModel = SmartCartViewModel(store: store, categorization: RuleBasedCategorizationService())
        guard let testStore = viewModel.storesForDisplay.first(where: { $0.id == storeId }) else {
            return XCTFail("missing store")
        }

        viewModel.activateShoppingMode(for: testStore)
        XCTAssertEqual(viewModel.shoppingModeStoreId, storeId)
        XCTAssertEqual(viewModel.shoppingModeStoreName, "Test Store")
        XCTAssertEqual(viewModel.preferredListDisplayMode, .optimizedRoute)

        viewModel.deactivateShoppingMode()
        XCTAssertNil(viewModel.shoppingModeStoreId)
        XCTAssertNil(viewModel.shoppingModeStoreName)
    }
}
