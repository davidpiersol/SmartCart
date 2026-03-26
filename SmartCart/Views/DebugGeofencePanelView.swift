import CoreLocation
import SwiftUI

#if DEBUG
struct DebugGeofencePanelView: View {
    @ObservedObject var geofencing: StoreGeofencingService

    private var authLabel: String {
        switch geofencing.authorizationStatus {
        case .notDetermined: return "Not Determined"
        case .restricted: return "Restricted"
        case .denied: return "Denied"
        case .authorizedWhenInUse: return "When In Use"
        case .authorizedAlways: return "Always"
        @unknown default: return "Unknown"
        }
    }

    var body: some View {
        NavigationStack {
            List {
                Section("Authorization") {
                    row("Status", authLabel)
                    row("Last location", geofencing.lastKnownLocationText)
                    row("Last geofence event", geofencing.lastGeofenceEvent)
                }

                Section("Monitored Regions (\(geofencing.monitoredDebugRegions.count))") {
                    if geofencing.monitoredDebugRegions.isEmpty {
                        Text("No monitored regions yet")
                            .foregroundStyle(.secondary)
                    } else {
                        ForEach(geofencing.monitoredDebugRegions) { region in
                            VStack(alignment: .leading, spacing: 4) {
                                Text(region.name)
                                    .font(.subheadline.weight(.semibold))
                                Text(String(format: "%.5f, %.5f", region.latitude, region.longitude))
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                                Text("Radius: \(Int(region.radiusMeters))m")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                            .padding(.vertical, 2)
                        }
                    }
                }
            }
            .navigationTitle("Geofence Debug")
            .navigationBarTitleDisplayMode(.inline)
        }
    }

    private func row(_ title: String, _ value: String) -> some View {
        HStack {
            Text(title)
            Spacer(minLength: 8)
            Text(value)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.trailing)
        }
    }
}
#endif
