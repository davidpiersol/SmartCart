import Foundation

struct SeedStoreDefinition: Equatable, Hashable {
    var name: String
    var latitude: Double
    var longitude: Double
    var radiusMeters: Double
}

enum StoreSeedCatalog {
    /// Albuquerque metro starter set for geofence-driven shopping mode.
    static let albuquerqueMVP: [SeedStoreDefinition] = [
        SeedStoreDefinition(name: "Walmart Supercenter", latitude: 35.1314, longitude: -106.5311, radiusMeters: 175),
        SeedStoreDefinition(name: "Target", latitude: 35.1765, longitude: -106.5578, radiusMeters: 150),
        SeedStoreDefinition(name: "Smith's", latitude: 35.1173, longitude: -106.6054, radiusMeters: 140),
        SeedStoreDefinition(name: "Costco Wholesale", latitude: 35.1450, longitude: -106.5760, radiusMeters: 180),
        SeedStoreDefinition(name: "Albertsons", latitude: 35.1533, longitude: -106.5925, radiusMeters: 140),
        SeedStoreDefinition(name: "Sam's Club", latitude: 35.1722, longitude: -106.5853, radiusMeters: 175),
        SeedStoreDefinition(name: "Whole Foods Market", latitude: 35.1041, longitude: -106.5808, radiusMeters: 130),
        SeedStoreDefinition(name: "Trader Joe's", latitude: 35.1319, longitude: -106.5303, radiusMeters: 120),
        SeedStoreDefinition(name: "Sprouts Farmers Market", latitude: 35.1084, longitude: -106.5723, radiusMeters: 130),
        SeedStoreDefinition(name: "The Home Depot", latitude: 35.1742, longitude: -106.6148, radiusMeters: 170),
        SeedStoreDefinition(name: "Lowe's Home Improvement", latitude: 35.1298, longitude: -106.6038, radiusMeters: 170),
        SeedStoreDefinition(name: "Walgreens", latitude: 35.0884, longitude: -106.6508, radiusMeters: 120),
        SeedStoreDefinition(name: "CVS Pharmacy", latitude: 35.1326, longitude: -106.5319, radiusMeters: 120),
        SeedStoreDefinition(name: "Best Buy", latitude: 35.1485, longitude: -106.5868, radiusMeters: 130)
    ]
}
