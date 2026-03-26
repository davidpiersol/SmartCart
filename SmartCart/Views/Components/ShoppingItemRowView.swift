import SwiftUI

/// One row in the shopping list with completion affordances and inline rename.
struct ShoppingItemRowView: View {
    let item: ShoppingItem
    var onToggle: () -> Void
    var onRename: (String) -> Void

    @State private var isEditing = false
    @State private var draftName: String = ""

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: 12) {
            Button(action: onToggle) {
                Image(systemName: item.isCompleted ? "checkmark.circle.fill" : "circle")
                    .font(.title3)
                    .symbolRenderingMode(.hierarchical)
                    .foregroundStyle(item.isCompleted ? Color.accentColor : .secondary)
                    .accessibilityLabel(item.isCompleted ? "Mark as not completed" : "Mark as completed")
            }
            .buttonStyle(.plain)

            VStack(alignment: .leading, spacing: 4) {
                if isEditing {
                    TextField("Item name", text: $draftName)
                        .textInputAutocapitalization(.sentences)
                        .submitLabel(.done)
                        .onSubmit { commitRename() }
                } else {
                    Text(item.name)
                        .font(.body.weight(.medium))
                        .strikethrough(item.isCompleted, color: .secondary)
                        .foregroundStyle(item.isCompleted ? .secondary : .primary)
                }

                if let category = item.category, !category.isEmpty {
                    Text(category)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            Spacer(minLength: 0)

            if isEditing {
                Button("Done") { commitRename() }
                    .font(.subheadline.weight(.semibold))
            } else {
                Button {
                    draftName = item.name
                    isEditing = true
                } label: {
                    Image(systemName: "pencil")
                        .font(.body.weight(.medium))
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Edit item name")
            }
        }
        .padding(.vertical, 4)
        .contentShape(Rectangle())
    }

    private func commitRename() {
        let trimmed = draftName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            draftName = item.name
            isEditing = false
            return
        }
        onRename(trimmed)
        isEditing = false
    }
}

#Preview("Row") {
    List {
        ShoppingItemRowView(
            item: ShoppingItem(name: "Oat milk", category: "Dairy", isCompleted: false),
            onToggle: {},
            onRename: { _ in }
        )
        ShoppingItemRowView(
            item: ShoppingItem(name: "Bananas", category: "Produce", isCompleted: true),
            onToggle: {},
            onRename: { _ in }
        )
    }
}
