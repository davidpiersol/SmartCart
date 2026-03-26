import SwiftUI

/// Primary screen: browse items, add, complete, delete.
struct ShoppingListView: View {
    @ObservedObject var viewModel: ShoppingListViewModel

    var body: some View {
        NavigationStack {
            listContent
                .navigationTitle("SmartCart")
                .navigationBarTitleDisplayMode(.large)
                .toolbar {
                    ToolbarItem(placement: .topBarTrailing) {
                        Menu {
                            Text("Items: \(viewModel.list.items.count)")
                            Text("Updated: \(viewModel.list.updatedAt.formatted(date: .abbreviated, time: .shortened))")
                        } label: {
                            Image(systemName: "info.circle")
                        }
                        .accessibilityLabel("List info")
                    }
                }
                .alert(
                    "Something went wrong",
                    isPresented: Binding(
                        get: { viewModel.lastErrorMessage != nil },
                        set: { if !$0 { viewModel.lastErrorMessage = nil } }
                    ),
                    actions: { Button("OK") { viewModel.lastErrorMessage = nil } },
                    message: {
                        Text(viewModel.lastErrorMessage ?? "")
                    }
                )
        }
        .task { await viewModel.load() }
    }

    @ViewBuilder
    private var listContent: some View {
        List {
            Section {
                AddItemInputBar(
                    name: $viewModel.newItemName,
                    category: $viewModel.newItemCategory,
                    onCommit: { viewModel.addItem() }
                )
                .listRowInsets(EdgeInsets(top: 8, leading: 16, bottom: 8, trailing: 16))
                .listRowSeparator(.hidden)
                .listRowBackground(Color.clear)
            }

            if !viewModel.list.activeItems.isEmpty {
                Section("To buy") {
                    ForEach(viewModel.list.activeItems) { item in
                        ShoppingItemRowView(
                            item: item,
                            onToggle: { viewModel.toggleCompleted(for: item) },
                            onRename: { viewModel.updateName(for: item, to: $0) }
                        )
                    }
                    .onDelete { offsets in
                        viewModel.deleteItems(at: offsets, in: .active)
                    }
                }
            }

            if !viewModel.list.completedItems.isEmpty {
                Section("Completed") {
                    ForEach(viewModel.list.completedItems) { item in
                        ShoppingItemRowView(
                            item: item,
                            onToggle: { viewModel.toggleCompleted(for: item) },
                            onRename: { viewModel.updateName(for: item, to: $0) }
                        )
                    }
                    .onDelete { offsets in
                        viewModel.deleteItems(at: offsets, in: .completed)
                    }
                }
            }

            if viewModel.list.items.isEmpty {
                Section {
                    ContentUnavailableView(
                        "No items yet",
                        systemImage: "cart",
                        description: Text("Add something you need. You can swipe to delete and tap the circle to mark items done.")
                    )
                    .frame(maxWidth: .infinity)
                    .listRowBackground(Color.clear)
                }
            }
        }
        .listStyle(.insetGrouped)
    }
}

private struct PreviewShoppingListRepository: ShoppingListRepository {
    func load() async throws -> ShoppingList {
        ShoppingList(
            items: [
                ShoppingItem(name: "Oat milk", category: "Dairy"),
                ShoppingItem(name: "Sourdough", category: "Bakery", isCompleted: true)
            ]
        )
    }

    func save(_: ShoppingList) async throws {}
}

#Preview {
    ShoppingListView(
        viewModel: ShoppingListViewModel(repository: PreviewShoppingListRepository())
    )
}
