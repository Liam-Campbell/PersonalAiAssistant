import Foundation
import SwiftData

@Model final class ReceiptItem {
    @Attribute(.unique) var id: UUID
    var name: String
    var quantity: Int
    var unitPrice: Decimal
    var lineTotal: Decimal
    var receipt: Receipt?

    init(name: String, quantity: Int = 1, unitPrice: Decimal, lineTotal: Decimal) {
        self.id = UUID()
        self.name = name
        self.quantity = quantity
        self.unitPrice = unitPrice
        self.lineTotal = lineTotal
    }
}
