import Foundation
import SwiftData

@Model final class Store {
    @Attribute(.unique) var id: UUID
    var name: String
    @Relationship(deleteRule: .nullify, inverse: \Receipt.store) var receipts: [Receipt]

    init(name: String) {
        self.id = UUID()
        self.name = name
        self.receipts = []
    }
}
