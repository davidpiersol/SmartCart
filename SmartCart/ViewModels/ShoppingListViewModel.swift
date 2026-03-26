import Foundation
import SwiftUI

/// Coordinates list mutations, persistence, and presentation state for `ShoppingListView`.
@MainActor
final class ShoppingListViewModel: ObservableObject {
    @Published private(set) var list: ShoppingList
    @Published var newItemName: String = ""
    @Published var newItemCategory: String = ""

    /// Surface load/save issues without crashing flows.
    @Published var lastErrorMessage: String?

    private let repository: ShoppingListRepository

    init(list: ShoppingList = ShoppingList(), repository: ShoppingListRepository) {
        self.list = list
        self.repository = repository
    }

    func load() async {
        do {
            list = try await repository.load()
        } catch {
            lastErrorMessage = error.localizedDescription
        }
    }

    func addItem() {
        let trimmed = newItemName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }

        let categoryTrimmed = newItemCategory.trimmingCharacters(in: .whitespacesAndNewlines)
        let category: String? = categoryTrimmed.isEmpty ? nil : categoryTrimmed

        let item = ShoppingItem(name: trimmed, category: category)
        list.items.append(item)
        list.updatedAt = Date()
        newItemName = ""
        newItemCategory = ""
        persist()
    }

    func deleteItems(at offsets: IndexSet, in section: ShoppingListViewModel.Section) {
        let targetIds: Set<UUID> = {
            switch section {
            case .active:
                let active = list.activeItems
                return Set(offsets.map { active[$0].id })
            case .completed:
                let done = list.completedItems
                return Set(offsets.map { done[$0].id })
            }
        }()
        list.items.removeAll { targetIds.contains($0.id) }
        list.updatedAt = Date()
        persist()
    }

    func delete(item: ShoppingItem) {
        list.items.removeAll { $0.id == item.id }
        list.updatedAt = Date()
        persist()
    }

    func toggleCompleted(for item: ShoppingItem) {
        guard let index = list.items.firstIndex(where: { $0.id == item.id }) else { return }
        list.items[index].isCompleted.toggle()
        list.updatedAt = Date()
        persist()
    }

    func updateName(for item: ShoppingItem, to newName: String) {
        guard let index = list.items.firstIndex(where: { $0.id == item.id }) else { return }
        let trimmed = newName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        list.items[index].name = trimmed
        list.updatedAt = Date()
        persist()
    }

    enum Section {
        case active
        case completed
    }

    private func persist() {
        Task {
            do {
                try await repository.save(list)
            } catch {
                lastErrorMessage = error.localizedDescription
            }
        }
    }
}
