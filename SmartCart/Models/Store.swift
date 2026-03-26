import Foundation

/// A physical store with a customizable aisle order for route-aware shopping.
struct Store: Identifiable, Codable, Equatable, Hashable {
    var id: UUID
    var name: String
    var isDefault: Bool
    var latitude: Double?
    var longitude: Double?
    var geofenceRadiusMeters: Double
    var aisles: [Aisle]

    init(
        id: UUID = UUID(),
        name: String,
        isDefault: Bool = false,
        latitude: Double? = nil,
        longitude: Double? = nil,
        geofenceRadiusMeters: Double = 150,
        aisles: [Aisle] = []
    ) {
        self.id = id
        self.name = name
        self.isDefault = isDefault
        self.latitude = latitude
        self.longitude = longitude
        self.geofenceRadiusMeters = geofenceRadiusMeters
        self.aisles = aisles
    }

    var aislesByOrder: [Aisle] {
        aisles.sorted {
            if $0.orderIndex != $1.orderIndex { return $0.orderIndex < $1.orderIndex }
            return $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending
        }
    }

    var hasGeofence: Bool {
        latitude != nil && longitude != nil
    }
}
