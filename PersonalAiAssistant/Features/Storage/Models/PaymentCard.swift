import Foundation
import SwiftData

@Model final class PaymentCard {
    @Attribute(.unique) var id: UUID
    var label: String
    var lastFourDigits: String?
    @Relationship(deleteRule: .nullify, inverse: \Receipt.paymentCard) var receipts: [Receipt]

    init(label: String, lastFourDigits: String? = nil) {
        self.id = UUID()
        self.label = label
        self.lastFourDigits = lastFourDigits
        self.receipts = []
    }
}
