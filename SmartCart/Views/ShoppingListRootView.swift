import SwiftUI

/// Hosts the shopping list feature and owns the view model lifecycle.
struct ShoppingListRootView: View {
    @StateObject private var viewModel: ShoppingListViewModel

    init() {
        _viewModel = StateObject(
            wrappedValue: ShoppingListViewModel(repository: UserDefaultsShoppingListRepository())
        )
    }

    var body: some View {
        ShoppingListView(viewModel: viewModel)
    }
}

#Preview {
    ShoppingListRootView()
}
