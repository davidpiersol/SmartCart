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
        Group {
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
        .environment(\.defaultMinListRowHeight, startShoppingMode ? 62 : 44)
    }

    private var progressCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .firstTextBaseline) {
                Text("Progress")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
                    .textCase(.uppercase)
                    .tracking(0.7)
                Spacer(minLength: 0)
                Text("\(route.completedItems)/\(route.totalItems)")
                    .font(.caption.weight(.bold))
                    .foregroundStyle(.secondary)
            }
            Text("\(route.completedItems) of \(route.totalItems) items completed")
                .font(startShoppingMode ? .headline.weight(.semibold) : .subheadline.weight(.semibold))
            ProgressView(value: Double(route.completedItems), total: Double(max(route.totalItems, 1)))
                .tint(.accentColor)
        }
        .padding(14)
        .background(
            LinearGradient(
                colors: [Color(.secondarySystemGroupedBackground), Color.accentColor.opacity(0.04)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        )
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
    }

    private func routeHeader(stop: OptimizedRoute.Stop, stepIndex: Int) -> some View {
        let isHighlighted = highlightedStopId == stop.id
        return HStack(spacing: 8) {
            ZStack {
                Circle()
                    .fill(isHighlighted ? Color.accentColor : Color(.tertiarySystemFill))
                Text("\(stepIndex)")
                    .font(.caption.weight(.bold))
                    .foregroundStyle(isHighlighted ? .white : .secondary)
            }
            .frame(width: 22, height: 22)

            Text(stop.title)
                .font(startShoppingMode ? .title3.weight(.semibold) : .headline)
            Spacer(minLength: 0)
            if isHighlighted {
                Label("Next", systemImage: "arrow.forward.circle.fill")
                    .labelStyle(.titleAndIcon)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.accent)
            }
        }
        .padding(.top, 4)
        .animation(.snappy(duration: 0.25), value: highlightedStopId)
    }
}
