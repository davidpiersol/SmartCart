import SwiftUI

/// Modal flow for adding an item: name, quantity, and category (auto or explicit override).
struct AddItemSheet: View {
    @Environment(\.dismiss) private var dismiss
    @FocusState private var nameFieldFocused: Bool

    @State private var name: String = ""
    @State private var quantity: Int = 1
    @State private var categoryMode: CategorySelectionMode = .automatic
    @State private var aisleId: UUID?

    let categorization: ItemCategorizing
    let availableAisles: [Aisle]
    let suggestedAisle: (GroceryCategory) -> UUID?
    var onAdd: (String, Int, CategorySelectionMode, UUID?) -> Void

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
                    TextField("e.g. Milk, Bananas", text: $name)
                        .textInputAutocapitalization(.sentences)
                        .focused($nameFieldFocused)
                        .submitLabel(.done)
                        .onSubmit { commitIfPossible() }
                } header: {
                    Text("Item")
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
                        Text("Auto picks a category from the item name. Choose a category to lock it.")
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
                    } footer: {
                        Text("Suggested from category when available. You can override manually.")
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
                } footer: {
                    Text("You can change quantity later by editing the item.")
                }
            }
            .navigationTitle("New Item")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Add") { commitIfPossible() }
                        .fontWeight(.semibold)
                        .disabled(trimmedName.isEmpty)
                }
            }
            .onAppear {
                nameFieldFocused = true
                if aisleId == nil {
                    aisleId = suggestedAisle(suggestedCategory)
                }
            }
            .onChange(of: categoryMode) { _, mode in
                guard case .automatic = mode else { return }
                aisleId = suggestedAisle(suggestedCategory)
            }
            .onChange(of: trimmedName) { _, _ in
                guard categoryMode == .automatic else { return }
                aisleId = suggestedAisle(suggestedCategory)
            }
        }
    }

    private func commitIfPossible() {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        onAdd(trimmed, quantity, categoryMode, aisleId)
        DispatchQueue.main.async {
            dismiss()
        }
    }
}

#Preview {
    AddItemSheet(
        categorization: RuleBasedCategorizationService(),
        availableAisles: [],
        suggestedAisle: { _ in nil }
    ) { _, _, _, _ in }
}
