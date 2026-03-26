import SwiftUI

struct ManageStoresView: View {
    @ObservedObject var viewModel: SmartCartViewModel
    @State private var showingNewStore = false
    @State private var newStoreName = ""

    var body: some View {
        List {
            if viewModel.storesForDisplay.isEmpty {
                ContentUnavailableView(
                    "No stores yet",
                    systemImage: "building.2",
                    description: Text("Create a store and define aisle order for walking-route sorting.")
                )
                .listRowBackground(Color.clear)
            } else {
                ForEach(viewModel.storesForDisplay) { store in
                    NavigationLink {
                        ManageAislesView(viewModel: viewModel, storeId: store.id)
                    } label: {
                        HStack {
                            VStack(alignment: .leading, spacing: 4) {
                                Text(store.name)
                                    .font(.headline)
                                Text("\(store.aisles.count) aisles")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                            Spacer()
                            if viewModel.activeStore?.id == store.id {
                                Label("Active", systemImage: "checkmark.circle.fill")
                                    .font(.caption.weight(.semibold))
                                    .foregroundStyle(.green)
                            }
                        }
                    }
                    .swipeActions(edge: .leading, allowsFullSwipe: true) {
                        Button("Use", systemImage: "checkmark.circle") {
                            viewModel.setActiveStore(id: store.id)
                        }
                        .tint(.green)
                    }
                }
                .onDelete(perform: viewModel.deleteStores)
            }
        }
        .navigationTitle("Manage Stores")
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    newStoreName = ""
                    showingNewStore = true
                } label: {
                    Image(systemName: "plus.circle.fill")
                }
                .accessibilityLabel("Add store")
            }
        }
        .sheet(isPresented: $showingNewStore) {
            NavigationStack {
                Form {
                    TextField("Store name", text: $newStoreName)
                        .textInputAutocapitalization(.words)
                }
                .navigationTitle("New Store")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) {
                        Button("Cancel") { showingNewStore = false }
                    }
                    ToolbarItem(placement: .confirmationAction) {
                        Button("Create") {
                            viewModel.createStore(named: newStoreName)
                            showingNewStore = false
                        }
                    }
                }
            }
            .presentationDetents([.medium])
        }
    }
}
