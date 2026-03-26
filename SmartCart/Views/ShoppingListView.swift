import SwiftUI

/// Detail screen for one list: grouped by category, add via toolbar sheet, edit via row tap.
struct ShoppingListView: View {
    @ObservedObject var viewModel: SmartCartViewModel
    let listId: UUID

    @State private var showingAddItem = false
    @State private var itemToEdit: ShoppingItem?
    @State private var expandedSectionIds: Set<String> = []

    var body: some View {
        Group {
            if let list = viewModel.list(id: listId) {
                listBody(list: list)
                    .navigationTitle(list.name)
                    .navigationBarTitleDisplayMode(.large)
            } else {
                ContentUnavailableView(
                    "List unavailable",
                    systemImage: "exclamationmark.triangle",
                    description: Text("This list may have been deleted.")
                )
            }
        }
        .toolbar {
            ToolbarItem(placement: .topBarLeading) {
                activeStoreMenu
            }
            ToolbarItem(placement: .topBarTrailing) {
                HStack(spacing: 16) {
                    Menu {
                        if let list = viewModel.list(id: listId) {
                            Label("\(list.items.count) items", systemImage: "number")
                            Label(
                                "Updated \(list.updatedAt.formatted(date: .abbreviated, time: .shortened))",
                                systemImage: "clock"
                            )
                        }
                    } label: {
                        Image(systemName: "info.circle")
                    }
                    .accessibilityLabel("List information")

                    Button {
                        showingAddItem = true
                    } label: {
                        Image(systemName: "plus.circle.fill")
                            .symbolRenderingMode(.hierarchical)
                    }
                    .accessibilityLabel("Add item")
                }
            }
        }
        .sheet(isPresented: $showingAddItem) {
            AddItemSheet(
                categorization: viewModel.categorization,
                availableAisles: viewModel.activeStore?.aislesByOrder ?? [],
                suggestedAisle: { category in
                    viewModel.suggestedAisleId(for: category, in: viewModel.activeStore)
                }
            ) { name, quantity, mode, aisleId in
                viewModel.addItem(
                    listId: listId,
                    name: name,
                    quantity: quantity,
                    categoryMode: mode,
                    aisleId: aisleId
                )
            }
        }
        .sheet(item: $itemToEdit) { item in
            EditItemSheet(
                item: item,
                categorization: viewModel.categorization,
                availableAisles: viewModel.activeStore?.aislesByOrder ?? [],
                suggestedAisle: { category in
                    viewModel.suggestedAisleId(for: category, in: viewModel.activeStore)
                }
            ) { updated in
                viewModel.updateItem(listId: listId, item: updated)
            }
        }
        .alert(
            "Something went wrong",
            isPresented: Binding(
                get: { viewModel.lastErrorMessage != nil },
                set: { if !$0 { viewModel.lastErrorMessage = nil } }
            ),
            actions: { Button("OK") { viewModel.lastErrorMessage = nil } },
            message: { Text(viewModel.lastErrorMessage ?? "") }
        )
    }

    @ViewBuilder
    private func listBody(list: ShoppingList) -> some View {
        let sections = viewModel.sectionsForList(list)
        List {
            if !sections.isEmpty {
                ForEach(sections) { section in
                    DisclosureGroup(
                        isExpanded: binding(for: section.id),
                        content: {
                            ForEach(section.items) { item in
                                ShoppingItemRowView(
                                    item: item,
                                    showsCategorySubtitle: false,
                                    onToggle: {
                                        withAnimation(.snappy(duration: 0.28)) {
                                            viewModel.toggleCompleted(listId: listId, item: item)
                                        }
                                    },
                                    onEdit: { itemToEdit = item }
                                )
                            }
                            .onDelete { offsets in
                                viewModel.deleteItems(at: offsets, from: section.items, listId: listId)
                            }
                        },
                        label: {
                            sectionLabel(section: section, itemCount: section.items.count)
                        }
                    )
                }
            }

            if list.items.isEmpty {
                Section {
                    ContentUnavailableView(
                        "Nothing here yet",
                        systemImage: "basket",
                        description: Text("Tap + to add your first item. Categories are suggested automatically, or pick one to keep it fixed.")
                    )
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 24)
                    .listRowBackground(Color.clear)
                }
            }
        }
        .listStyle(.insetGrouped)
    }

    private func sectionLabel(section: SmartCartViewModel.ListDisplaySection, itemCount: Int) -> some View {
        HStack(spacing: 10) {
            Image(systemName: section.symbolName)
                .foregroundStyle(section.tint)
                .imageScale(.medium)
                .frame(width: 28, alignment: .center)
            VStack(alignment: .leading, spacing: 2) {
                Text(section.title)
                    .font(.headline)
                Text("\(itemCount) \(itemCount == 1 ? "item" : "items")")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer(minLength: 0)
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(section.title), \(itemCount) items")
    }

    private func binding(for id: String) -> Binding<Bool> {
        Binding(
            get: { expandedSectionIds.contains(id) || expandedSectionIds.isEmpty },
            set: { expanded in
                if expanded {
                    expandedSectionIds.insert(id)
                } else {
                    expandedSectionIds.remove(id)
                }
            }
        )
    }

    /// Switch active store without leaving the list (aisles + sorting update immediately).
    private var activeStoreMenu: some View {
        Menu {
            if viewModel.storesForDisplay.isEmpty {
                Text("No stores yet")
                    .foregroundStyle(.secondary)
            } else {
                ForEach(viewModel.storesForDisplay) { store in
                    Button {
                        viewModel.setActiveStore(id: store.id)
                    } label: {
                        HStack {
                            Text(store.name)
                            Spacer(minLength: 8)
                            if viewModel.activeStore?.id == store.id {
                                Image(systemName: "checkmark")
                            }
                        }
                    }
                }
                Divider()
                Button("Category only (no store)") {
                    viewModel.setActiveStore(id: nil)
                }
            }
        } label: {
            HStack(spacing: 6) {
                Image(systemName: "building.2.fill")
                Text(viewModel.activeStore?.name ?? "Store")
                    .lineLimit(1)
            }
            .font(.subheadline.weight(.semibold))
        }
        .accessibilityLabel("Active store")
        .accessibilityHint("Choose which store layout and aisles apply to this list")
    }
}

#Preview {
    ShoppingListDetailPreview()
}

private struct ShoppingListDetailPreview: View {
    @StateObject private var viewModel: SmartCartViewModel

    init() {
        let persistence = PersistenceController.preview
        let store = CoreDataShoppingListStore(container: persistence.container)
        _viewModel = StateObject(wrappedValue: SmartCartViewModel(store: store))
    }

    var body: some View {
        NavigationStack {
            if let id = viewModel.listsForHome.first?.id {
                ShoppingListView(viewModel: viewModel, listId: id)
            } else {
                Text("Preview: no list")
            }
        }
    }
}
