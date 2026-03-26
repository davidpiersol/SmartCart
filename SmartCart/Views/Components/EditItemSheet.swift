import SwiftUI

/// Edit name, quantity, and category; respects manual vs automatic categorization flags.
struct EditItemSheet: View {
    @Environment(\.dismiss) private var dismiss
    @FocusState private var nameFocused: Bool

    @State private var name: String
    @State private var quantity: Int
    @State private var categoryMode: CategorySelectionMode
    @State private var aisleId: UUID?

    let item: ShoppingItem
    let categorization: ItemCategorizing
    let availableAisles: [Aisle]
    let suggestedAisle: (GroceryCategory) -> UUID?
    var onSave: (ShoppingItem) -> Void

    init(
        item: ShoppingItem,
        categorization: ItemCategorizing,
        availableAisles: [Aisle],
        suggestedAisle: @escaping (GroceryCategory) -> UUID?,
        onSave: @escaping (ShoppingItem) -> Void
    ) {
        self.item = item
        self.categorization = categorization
        self.availableAisles = availableAisles
        self.suggestedAisle = suggestedAisle
        self.onSave = onSave
        _name = State(initialValue: item.name)
        _quantity = State(initialValue: item.quantity)
        _aisleId = State(initialValue: item.aisleId)
        _categoryMode = State(
            initialValue: item.categoryManualOverride
                ? .manual(GroceryCategory.resolved(from: item.category))
                : .automatic
        )
    }

    private var trimmedName: String {
        name.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private var suggestedCategory: GroceryCategory {
        categorization.suggestedCategory(for: trimmedName)
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField("Item name", text: $name)
                        .textInputAutocapitalization(.sentences)
                        .focused($nameFocused)
                }

                Section {
                    Picker("Category", selection: $categoryMode) {
                        Text("Auto (suggested)").tag(CategorySelectionMode.automatic)
                        ForEach(GroceryCategory.allCases) { cat in
                            Text(cat.displayName).tag(CategorySelectionMode.manual(cat))
                        }
                    }
                } footer: {
                    if categoryMode == .automatic, !trimmedName.isEmpty {
                        Label {
                            Text("Suggested: **\(suggestedCategory.displayName)**")
                        } icon: {
                            Image(systemName: suggestedCategory.symbolName)
                                .foregroundStyle(suggestedCategory.tint)
                        }
                        .font(.footnote)
                    } else {
                        Text("Automatic updates the category when the name changes. Pick a category to lock it.")
                    }
                }

                if !availableAisles.isEmpty {
                    Section {
                        Picker("Aisle", selection: $aisleId) {
                            Text("None").tag(UUID?.none)
                            ForEach(availableAisles) { aisle in
                                Text(aisle.name).tag(UUID?.some(aisle.id))
                            }
                        }
                    }
                }

                Section {
                    Stepper(value: $quantity, in: 1 ... 99) {
                        HStack {
                            Text("Quantity")
                            Spacer()
                            Text("\(quantity)")
                                .foregroundStyle(.secondary)
                                .monospacedDigit()
                        }
                    }
                }
            }
            .navigationTitle("Edit Item")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") { save() }
                        .fontWeight(.semibold)
                        .disabled(trimmedName.isEmpty)
                }
            }
            .onAppear { nameFocused = true }
            .onChange(of: categoryMode) { _, mode in
                guard case .automatic = mode else { return }
                if item.aisleId == nil {
                    aisleId = suggestedAisle(suggestedCategory)
                }
            }
            .onChange(of: trimmedName) { _, _ in
                guard categoryMode == .automatic else { return }
                if item.aisleId == nil {
                    aisleId = suggestedAisle(suggestedCategory)
                }
            }
        }
    }

    private func save() {
        guard !trimmedName.isEmpty else { return }
        var updated = item
        updated.name = trimmedName
        updated.quantity = max(1, min(99, quantity))
        switch categoryMode {
        case .automatic:
            updated.category = categorization.suggestedCategory(for: trimmedName).rawValue
            updated.categoryManualOverride = false
        case .manual(let g):
            updated.category = g.rawValue
            updated.categoryManualOverride = true
        }
        updated.aisleId = aisleId
        onSave(updated)
        dismiss()
    }
}

#Preview {
    EditItemSheet(
        item: ShoppingItem(name: "Milk", quantity: 2),
        categorization: RuleBasedCategorizationService(),
        availableAisles: [],
        suggestedAisle: { _ in nil }
    ) { _ in }
}
