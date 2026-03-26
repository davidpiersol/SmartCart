import SwiftUI

/// Root navigation stack; inject `PersistenceController` for tests and previews.
struct ShoppingListRootView: View {
    @StateObject private var viewModel: SmartCartViewModel
    @StateObject private var geofencing = StoreGeofencingService()
    @State private var path = NavigationPath()
    @State private var showingStorePrompt = false
    @State private var showingLocationDeniedAlert = false
    #if DEBUG
    @State private var showingDebugPanel = false
    #endif

    init(persistence: PersistenceController = .shared) {
        let store = CoreDataShoppingListStore(container: persistence.container)
        _viewModel = StateObject(wrappedValue: SmartCartViewModel(store: store))
    }

    var body: some View {
        NavigationStack(path: $path) {
            ShoppingListsHomeView(viewModel: viewModel, path: $path)
        }
        #if DEBUG
        .overlay(alignment: .bottomTrailing) {
            Button {
                showingDebugPanel = true
            } label: {
                Image(systemName: "ladybug.fill")
                    .font(.title3.weight(.semibold))
                    .foregroundStyle(.white)
                    .frame(width: 44, height: 44)
                    .background(Color.red.gradient)
                    .clipShape(Circle())
                    .shadow(color: .black.opacity(0.2), radius: 6, y: 2)
            }
            .padding(.trailing, 16)
            .padding(.bottom, 18)
            .accessibilityLabel("Open geofence debug panel")
        }
        .sheet(isPresented: $showingDebugPanel) {
            DebugGeofencePanelView(geofencing: geofencing)
        }
        #endif
        .task {
            viewModel.ensureDefaultListIfNeeded()
            viewModel.ensureSeedStoresIfNeeded()
            geofencing.requestWhenInUseAuthorization()
            geofencing.updateStores(viewModel.storesForDisplay)
        }
        .onReceive(viewModel.$state) { state in
            geofencing.updateStores(state.stores)
        }
        .onReceive(geofencing.$pendingStoreChoices) { choices in
            showingStorePrompt = !choices.isEmpty
        }
        .onReceive(geofencing.$authorizationStatus) { status in
            showingLocationDeniedAlert = (status == .denied || status == .restricted)
        }
        .onReceive(geofencing.$exitedStoreId) { exitedStoreId in
            guard let exitedStoreId else { return }
            if viewModel.shoppingModeStoreId == exitedStoreId {
                viewModel.deactivateShoppingMode()
            }
        }
        .confirmationDialog(
            geofencing.pendingStoreChoices.count > 1
                ? "Nearby stores detected"
                : "Start shopping?",
            isPresented: $showingStorePrompt,
            titleVisibility: .visible
        ) {
            ForEach(geofencing.pendingStoreChoices) { store in
                Button("Start shopping at \(store.name)") {
                    viewModel.activateShoppingMode(for: store)
                    geofencing.clearPrompt()
                }
            }
            Button("Not now", role: .cancel) {
                geofencing.clearPrompt()
            }
        } message: {
            if geofencing.pendingStoreChoices.count > 1 {
                Text("Select where you are shopping to activate route mode.")
            } else if let name = geofencing.pendingStoreChoices.first?.name {
                Text("Start shopping at \(name)?")
            }
        }
        .alert("Location Access Needed", isPresented: $showingLocationDeniedAlert) {
            Button("OK", role: .cancel) {}
        } message: {
            Text("Enable Location Services for SmartCart in Settings to auto-detect nearby stores. You can still select stores manually.")
        }
    }
}

#Preview {
    ShoppingListRootView(persistence: .preview)
        .environment(\.managedObjectContext, PersistenceController.preview.container.viewContext)
}
