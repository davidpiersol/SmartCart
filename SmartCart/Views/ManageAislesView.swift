import SwiftUI

struct ManageAislesView: View {
    @ObservedObject var viewModel: SmartCartViewModel
    let storeId: UUID

    @State private var showingAdd = false
    @State private var newAisleName = ""
    @State private var aisleToRename: Aisle?
    @State private var renameText = ""

    private var store: Store? {
        viewModel.state.stores.first(where: { $0.id == storeId })
    }

    var body: some View {
        List {
            if let store {
                ForEach(store.aislesByOrder) { aisle in
                    HStack {
                        Text(aisle.name)
                        Spacer()
                        Text("#\(aisle.orderIndex + 1)")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    .contentShape(Rectangle())
                    .onTapGesture {
                        aisleToRename = aisle
                        renameText = aisle.name
                    }
                }
                .onDelete { offsets in
                    viewModel.deleteAisles(at: offsets, storeId: storeId)
                }
                .onMove { source, destination in
                    viewModel.moveAisles(storeId: storeId, from: source, to: destination)
                }
            }
        }
        .navigationTitle(store?.name ?? "Aisles")
        .toolbar {
            ToolbarItem(placement: .topBarLeading) { EditButton() }
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    newAisleName = ""
                    showingAdd = true
                } label: {
                    Image(systemName: "plus.circle.fill")
                }
            }
        }
        .sheet(isPresented: $showingAdd) {
            NavigationStack {
                Form {
                    TextField("Aisle name", text: $newAisleName)
                }
                .navigationTitle("New Aisle")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) {
                        Button("Cancel") { showingAdd = false }
                    }
                    ToolbarItem(placement: .confirmationAction) {
                        Button("Add") {
                            viewModel.createAisle(storeId: storeId, name: newAisleName)
                            showingAdd = false
                        }
                    }
                }
            }
            .presentationDetents([.medium])
        }
        .sheet(item: $aisleToRename) { aisle in
            NavigationStack {
                Form {
                    TextField("Aisle name", text: $renameText)
                }
                .navigationTitle("Rename Aisle")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) {
                        Button("Cancel") { aisleToRename = nil }
                    }
                    ToolbarItem(placement: .confirmationAction) {
                        Button("Save") {
                            viewModel.renameAisle(storeId: storeId, aisleId: aisle.id, to: renameText)
                            aisleToRename = nil
                        }
                    }
                }
            }
            .presentationDetents([.medium])
        }
    }
}
