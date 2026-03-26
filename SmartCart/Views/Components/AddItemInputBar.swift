import SwiftUI

/// Inline composer for name + optional category. Keeps keyboard-focused layout isolated for reuse (e.g. future “quick add” on map screens).
struct AddItemInputBar: View {
    @Binding var name: String
    @Binding var category: String
    var onCommit: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 12) {
                Image(systemName: "plus.circle.fill")
                    .foregroundStyle(.tint)
                    .accessibilityHidden(true)

                TextField("Add item", text: $name)
                    .textInputAutocapitalization(.sentences)
                    .submitLabel(.done)
                    .onSubmit(onCommit)

                Button(action: onCommit) {
                    Text("Add")
                        .fontWeight(.semibold)
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.small)
                .disabled(name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                .accessibilityLabel("Add item to list")
            }

            TextField("Category (optional)", text: $category)
                .font(.subheadline)
                .textInputAutocapitalization(.words)
                .submitLabel(.done)
                .onSubmit(onCommit)
        }
        .padding(.vertical, 8)
    }
}

#Preview("Add bar") {
    struct PreviewHolder: View {
        @State private var name = "Milk"
        @State private var category = "Dairy"
        var body: some View {
            AddItemInputBar(name: $name, category: $category, onCommit: {})
                .padding()
        }
    }
    return PreviewHolder()
}
