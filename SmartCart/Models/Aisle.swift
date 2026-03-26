import Foundation

/// One aisle/section in a store layout. `orderIndex` is the walking order.
struct Aisle: Identifiable, Codable, Equatable, Hashable {
    var id: UUID
    var name: String
    var orderIndex: Int

    init(id: UUID = UUID(), name: String, orderIndex: Int) {
        self.id = id
        self.name = name
        self.orderIndex = orderIndex
    }
}
