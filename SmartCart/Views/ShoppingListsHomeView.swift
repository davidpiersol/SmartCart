import SwiftUI

/// Home hub for all shopping lists with clear empty state and list management.
struct ShoppingListsHomeView: View {
    @ObservedObject var viewModel: SmartCartViewModel
    @Binding var path: NavigationPath
    @State private var showingNewList = false
    @State private var newListTitle = ""
    @State private var listToRename: ShoppingList?

    var body: some View {
        Group {
            if viewModel.listsForHome.isEmpty {
                ContentUnavailableView {
                    Label("Your lists", systemImage: "list.bullet.rectangle")
                } description: {
                    Text("Keep separate lists for weekly shops, parties, or anything else—all saved on this device.")
                } actions: {
                    Button("Create list") {
                        newListTitle = ""
                        showingNewList = true
                    }
                    .buttonStyle(.borderedProminent)
                }
            } else {
                List {
                    ForEach(viewModel.listsForHome) { list in
                        NavigationLink(value: list.id) {
                            HStack(spacing: 14) {
                                RoundedRectangle(cornerRadius: 10, style: .continuous)
                                    .fill(Color.accentColor.opacity(0.15))
                                    .frame(width: 44, height: 44)
                                    .overlay {
                                        Image(systemName: "cart.fill")
                                            .foregroundStyle(.tint)
                                            .font(.body.weight(.medium))
                                    }

                                VStack(alignment: .leading, spacing: 4) {
                                    Text(list.name)
                                        .font(.headline)
                                    Text("\(list.items.count) items · \(list.updatedAt.formatted(date: .abbreviated, time: .shortened))")
                                        .font(.subheadline)
                                        .foregroundStyle(.secondary)
                                }
                            }
                            .padding(.vertical, 4)
                        }
                        .contextMenu {
                            Button("Rename", systemImage: "pencil") {
                                listToRename = list
                            }
                        }
                    }
                    .onDelete { viewModel.deleteLists(at: $0) }
                }
            }
        }
        .navigationTitle("SmartCart")
        .navigationBarTitleDisplayMode(.large)
        .toolbar {
            ToolbarItem(placement: .topBarLeading) {
                NavigationLink {
                    ManageStoresView(viewModel: viewModel)
                } label: {
                    Image(systemName: "building.2.fill")
                }
                .accessibilityLabel("Manage stores")
            }
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    newListTitle = ""
                    showingNewList = true
                } label: {
                    Image(systemName: "plus.circle.fill")
                        .symbolRenderingMode(.hierarchical)
                }
                .accessibilityLabel("New list")
            }
        }
        .safeAreaInset(edge: .top) {
            if let store = viewModel.activeStore {
                HStack(spacing: 8) {
                    Image(systemName: "mappin.and.ellipse")
                    Text("Active store: \(store.name)")
                        .lineLimit(1)
                }
                .font(.footnote.weight(.semibold))
                .foregroundStyle(.secondary)
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Color(.secondarySystemBackground))
            }
        }
        .navigationDestination(for: UUID.self) { id in
            ShoppingListView(viewModel: viewModel, listId: id)
        }
        .sheet(isPresented: $showingNewList) {
            NavigationStack {
                Form {
                    TextField("List name", text: $newListTitle)
                        .textInputAutocapitalization(.words)
                }
                .navigationTitle("New list")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) {
                        Button("Cancel") { showingNewList = false }
                    }
                    ToolbarItem(placement: .confirmationAction) {
                        Button("Create") {
                            let name = newListTitle.trimmingCharacters(in: .whitespacesAndNewlines)
                            if let id = viewModel.createList(named: name.isEmpty ? "New List" : name) {
                                path.append(id)
                            }
                            showingNewList = false
                        }
                    }
                }
            }
            .presentationDetents([.medium])
        }
        .sheet(item: $listToRename) { list in
            RenameListSheet(initialName: list.name) { newName in
                viewModel.renameList(id: list.id, to: newName)
            }
        }
    }
}

private struct RenameListSheet: View {
    @Environment(\.dismiss) private var dismiss
    @State private var name: String
    let onSave: (String) -> Void

    init(initialName: String, onSave: @escaping (String) -> Void) {
        _name = State(initialValue: initialName)
        self.onSave = onSave
    }

    var body: some View {
        NavigationStack {
            Form {
                TextField("List name", text: $name)
                    .textInputAutocapitalization(.words)
            }
            .navigationTitle("Rename list")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        onSave(name)
                        dismiss()
                    }
                }
            }
        }
        .presentationDetents([.medium])
    }
}

#Preview {
    ShoppingListsHomePreview()
}

private struct ShoppingListsHomePreview: View {
    @StateObject private var viewModel: SmartCartViewModel
    @State private var path = NavigationPath()

    init() {
        let persistence = PersistenceController.preview
        let store = CoreDataShoppingListStore(container: persistence.container)
        _viewModel = StateObject(wrappedValue: SmartCartViewModel(store: store))
    }

    var body: some View {
        NavigationStack(path: $path) {
            ShoppingListsHomeView(viewModel: viewModel, path: $path)
        }
    }
}
