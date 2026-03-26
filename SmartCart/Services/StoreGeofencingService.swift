import CoreLocation
import Foundation

@MainActor
final class StoreGeofencingService: NSObject, ObservableObject {
    struct DebugRegion: Identifiable, Equatable {
        var id: String
        var name: String
        var radiusMeters: Double
        var latitude: Double
        var longitude: Double
    }

    @Published private(set) var authorizationStatus: CLAuthorizationStatus = .notDetermined
    @Published private(set) var pendingStoreChoices: [Store] = []
    @Published private(set) var exitedStoreId: UUID?
    @Published private(set) var monitoredDebugRegions: [DebugRegion] = []
    @Published private(set) var lastGeofenceEvent: String = "None"
    @Published private(set) var lastKnownLocationText: String = "Unknown"

    private let manager = CLLocationManager()
    private var stores: [Store] = []
    private var monitoredStoreByIdentifier: [String: Store] = [:]
    private var currentLocation: CLLocation?
    private let maxMonitoredRegions = 20

    override init() {
        super.init()
        manager.delegate = self
        manager.desiredAccuracy = kCLLocationAccuracyHundredMeters
        manager.distanceFilter = 120
    }

    func requestWhenInUseAuthorization() {
        authorizationStatus = manager.authorizationStatus
        if authorizationStatus == .notDetermined {
            manager.requestWhenInUseAuthorization()
        } else {
            startLocationTrackingIfAuthorized()
        }
    }

    func updateStores(_ stores: [Store]) {
        self.stores = stores.filter(\.hasGeofence)
        refreshMonitoredRegions()
    }

    func clearPrompt() {
        pendingStoreChoices = []
    }

    private func startLocationTrackingIfAuthorized() {
        guard authorizationStatus == .authorizedWhenInUse || authorizationStatus == .authorizedAlways else { return }
        manager.startMonitoringSignificantLocationChanges()
        manager.requestLocation()
    }

    private func refreshMonitoredRegions() {
        guard authorizationStatus == .authorizedWhenInUse || authorizationStatus == .authorizedAlways else { return }

        let candidates = nearestCandidateStores()
        let targetIdentifiers = Set(candidates.map { $0.id.uuidString })

        for region in manager.monitoredRegions {
            guard let circular = region as? CLCircularRegion else { continue }
            if !targetIdentifiers.contains(circular.identifier) {
                manager.stopMonitoring(for: circular)
                monitoredStoreByIdentifier[circular.identifier] = nil
            }
        }

        for store in candidates {
            let identifier = store.id.uuidString
            monitoredStoreByIdentifier[identifier] = store
            if manager.monitoredRegions.contains(where: { $0.identifier == identifier }) {
                continue
            }
            guard let latitude = store.latitude, let longitude = store.longitude else { continue }
            let center = CLLocationCoordinate2D(latitude: latitude, longitude: longitude)
            let region = CLCircularRegion(center: center, radius: max(80, min(store.geofenceRadiusMeters, 300)), identifier: identifier)
            region.notifyOnEntry = true
            region.notifyOnExit = true
            manager.startMonitoring(for: region)
            manager.requestState(for: region)
        }
        publishDebugSnapshot()
    }

    private func nearestCandidateStores() -> [Store] {
        guard !stores.isEmpty else { return [] }
        guard let currentLocation else {
            return Array(stores.prefix(maxMonitoredRegions))
        }
        return stores
            .sorted { lhs, rhs in
                distance(from: currentLocation, to: lhs) < distance(from: currentLocation, to: rhs)
            }
            .prefix(maxMonitoredRegions)
            .map { $0 }
    }

    private func distance(from location: CLLocation, to store: Store) -> CLLocationDistance {
        guard let latitude = store.latitude, let longitude = store.longitude else { return .greatestFiniteMagnitude }
        let target = CLLocation(latitude: latitude, longitude: longitude)
        return location.distance(from: target)
    }

    private func handlePotentialEntry(triggeredStore: Store?) {
        var candidates: [Store]
        if let currentLocation {
            candidates = stores.filter { store in
                let distanceValue = distance(from: currentLocation, to: store)
                return distanceValue <= max(100, store.geofenceRadiusMeters * 1.1)
            }
        } else if let triggeredStore {
            candidates = [triggeredStore]
        } else {
            candidates = []
        }
        if candidates.isEmpty, let triggeredStore {
            candidates = [triggeredStore]
        }
        pendingStoreChoices = candidates.sorted { $0.name < $1.name }
        if let triggeredStore {
            lastGeofenceEvent = "Entered region near \(triggeredStore.name)"
        } else {
            lastGeofenceEvent = "Entered store region (unresolved)"
        }
    }

    private func publishDebugSnapshot() {
        let mapped: [DebugRegion] = manager.monitoredRegions.compactMap { region in
            guard let circular = region as? CLCircularRegion else { return nil }
            let store = monitoredStoreByIdentifier[circular.identifier]
            return DebugRegion(
                id: circular.identifier,
                name: store?.name ?? "Unknown store",
                radiusMeters: circular.radius,
                latitude: circular.center.latitude,
                longitude: circular.center.longitude
            )
        }
        monitoredDebugRegions = mapped.sorted { $0.name < $1.name }
    }
}

extension StoreGeofencingService: CLLocationManagerDelegate {
    nonisolated func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        Task { @MainActor in
            authorizationStatus = manager.authorizationStatus
            startLocationTrackingIfAuthorized()
            refreshMonitoredRegions()
            lastGeofenceEvent = "Authorization changed: \(manager.authorizationStatus.rawValue)"
        }
    }

    nonisolated func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard let latest = locations.last else { return }
        Task { @MainActor in
            currentLocation = latest
            lastKnownLocationText = String(
                format: "%.5f, %.5f",
                latest.coordinate.latitude,
                latest.coordinate.longitude
            )
            refreshMonitoredRegions()
        }
    }

    nonisolated func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        // Ignore transient location failures; geofence callbacks still work.
    }

    nonisolated func locationManager(_ manager: CLLocationManager, didEnterRegion region: CLRegion) {
        Task { @MainActor in
            let store = monitoredStoreByIdentifier[region.identifier]
            handlePotentialEntry(triggeredStore: store)
            publishDebugSnapshot()
        }
    }

    nonisolated func locationManager(_ manager: CLLocationManager, didDetermineState state: CLRegionState, for region: CLRegion) {
        guard state == .inside else { return }
        Task { @MainActor in
            let store = monitoredStoreByIdentifier[region.identifier]
            handlePotentialEntry(triggeredStore: store)
            publishDebugSnapshot()
        }
    }

    nonisolated func locationManager(_ manager: CLLocationManager, didExitRegion region: CLRegion) {
        Task { @MainActor in
            exitedStoreId = UUID(uuidString: region.identifier)
            if let store = monitoredStoreByIdentifier[region.identifier] {
                lastGeofenceEvent = "Exited region: \(store.name)"
            } else {
                lastGeofenceEvent = "Exited region: \(region.identifier)"
            }
            publishDebugSnapshot()
        }
    }
}
