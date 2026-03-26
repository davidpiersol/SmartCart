import SwiftUI

/// Root navigation stack; inject `PersistenceController` for tests and previews.
struct ShoppingListRootView: View {
    @StateObject private var viewModel: SmartCartViewModel
    @State private var path = NavigationPath()

    init(persistence: PersistenceController = .shared) {
        let store = CoreDataShoppingListStore(container: persistence.container)
        _viewModel = StateObject(wrappedValue: SmartCartViewModel(store: store))
    }

    var body: some View {
        NavigationStack(path: $path) {
            ShoppingListsHomeView(viewModel: viewModel, path: $path)
        }
        .task {
            viewModel.ensureDefaultListIfNeeded()
        }
    }
}

#Preview {
    ShoppingListRootView(persistence: .preview)
        .environment(\.managedObjectContext, PersistenceController.preview.container.viewContext)
}
