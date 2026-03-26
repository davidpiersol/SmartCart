import SwiftUI

struct OptimizedRouteView: View {
    let route: OptimizedRoute
    var startShoppingMode: Bool
    var itemToEdit: (ShoppingItem) -> Void
    var onToggle: (ShoppingItem) -> Void
    var onDelete: (IndexSet, [ShoppingItem]) -> Void

    private var highlightedStopId: String? {
        guard startShoppingMode else { return nil }
        return route.stops.first(where: { $0.items.contains(where: { !$0.isCompleted }) })?.id
    }

    var body: some View {
        if route.totalItems == 0 {
            Section {
                ContentUnavailableView(
                    "No route yet",
                    systemImage: "figure.walk",
                    description: Text("Add items to generate your in-store walking route.")
                )
                .frame(maxWidth: .infinity)
                .padding(.vertical, 24)
                .listRowBackground(Color.clear)
            }
        } else {
            Section {
                progressCard
            }
            .listRowInsets(EdgeInsets(top: 6, leading: 16, bottom: 6, trailing: 16))
            .listRowBackground(Color.clear)

            ForEach(Array(route.stops.enumerated()), id: \.element.id) { idx, stop in
                Section {
                    ForEach(stop.items) { item in
                        ShoppingItemRowView(
                            item: item,
                            showsCategorySubtitle: !stop.isUnassigned,
                            onToggle: { onToggle(item) },
                            onEdit: { itemToEdit(item) }
                        )
                    }
                    .onDelete { offsets in
                        onDelete(offsets, stop.items)
                    }
                } header: {
                    routeHeader(stop: stop, stepIndex: idx + 1)
                } footer: {
                    if idx < route.stops.count - 1 {
                        HStack(spacing: 6) {
                            Image(systemName: "arrow.down")
                            Text("Continue to next aisle")
                        }
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .padding(.top, 6)
                    }
                }
            }
        }
    }

    private var progressCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Progress")
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)
            Text("\(route.completedItems) of \(route.totalItems) items completed")
                .font(.subheadline.weight(.semibold))
            ProgressView(value: Double(route.completedItems), total: Double(max(route.totalItems, 1)))
                .tint(.accentColor)
        }
        .padding(12)
        .background(Color(.secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
    }

    private func routeHeader(stop: OptimizedRoute.Stop, stepIndex: Int) -> some View {
        let isHighlighted = highlightedStopId == stop.id
        return HStack(spacing: 8) {
            Text("Stop \(stepIndex)")
                .font(.caption2.weight(.bold))
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(isHighlighted ? Color.accentColor.opacity(0.2) : Color(.tertiarySystemFill))
                .clipShape(Capsule())
            Text(stop.title)
                .font(.headline)
            Spacer(minLength: 0)
            if isHighlighted {
                Text("Next")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.accent)
            }
        }
        .padding(.top, 4)
        .animation(.snappy(duration: 0.25), value: highlightedStopId)
    }
}
