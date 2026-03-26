import SwiftUI

/// Checkbox-style completion control, readable typography, and tap-to-edit affordance.
struct ShoppingItemRowView: View {
    let item: ShoppingItem
    var showsCategorySubtitle: Bool = true
    var onToggle: () -> Void
    var onEdit: () -> Void

    private var resolvedCategory: GroceryCategory {
        GroceryCategory.resolved(from: item.category)
    }

    var body: some View {
        HStack(alignment: .center, spacing: 14) {
            Button(action: onToggle) {
                Image(systemName: item.isCompleted ? "checkmark.circle.fill" : "circle")
                    .font(.title2)
                    .symbolRenderingMode(.hierarchical)
                    .foregroundStyle(item.isCompleted ? Color.accentColor : Color.secondary)
                    .contentTransition(.symbolEffect(.replace))
                    .accessibilityLabel(item.isCompleted ? "Mark as not completed" : "Mark as completed")
            }
            .buttonStyle(.plain)

            VStack(alignment: .leading, spacing: 6) {
                HStack(alignment: .firstTextBaseline, spacing: 8) {
                    Text(item.name)
                        .font(.body.weight(.medium))
                        .strikethrough(item.isCompleted, color: .secondary)
                        .foregroundStyle(item.isCompleted ? Color.secondary : Color.primary)

                    if item.quantity > 1 {
                        Text("×\(item.quantity)")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(.secondary)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 3)
                            .background(Color(.secondarySystemFill))
                            .clipShape(Capsule())
                    }
                }

                if showsCategorySubtitle {
                    HStack(spacing: 6) {
                        Image(systemName: resolvedCategory.symbolName)
                            .font(.caption2)
                            .foregroundStyle(resolvedCategory.tint)
                        Text(resolvedCategory.displayName)
                            .font(.caption)
                            .foregroundStyle(.tertiary)
                    }
                }
            }

            Spacer(minLength: 0)

            Image(systemName: "chevron.right")
                .font(.caption.weight(.semibold))
                .foregroundStyle(.tertiary)
        }
        .padding(.vertical, 6)
        .contentShape(Rectangle())
        .onTapGesture(perform: onEdit)
        .accessibilityElement(children: .combine)
        .accessibilityHint("Double tap to edit")
        .animation(.snappy(duration: 0.28), value: item.isCompleted)
        .animation(.snappy(duration: 0.22), value: item.name)
        .animation(.snappy(duration: 0.22), value: item.quantity)
    }
}

#Preview("Row") {
    List {
        ShoppingItemRowView(
            item: ShoppingItem(name: "Oat milk", category: GroceryCategory.dairy.rawValue, quantity: 2, isCompleted: false),
            showsCategorySubtitle: true,
            onToggle: {},
            onEdit: {}
        )
        ShoppingItemRowView(
            item: ShoppingItem(name: "Bananas", quantity: 1, isCompleted: true),
            showsCategorySubtitle: false,
            onToggle: {},
            onEdit: {}
        )
    }
}
