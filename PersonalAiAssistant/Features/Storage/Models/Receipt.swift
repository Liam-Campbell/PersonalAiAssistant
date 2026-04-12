import Foundation
import SwiftData

@Model final class Receipt {
    @Attribute(.unique) var id: UUID
    var store: Store
    var paymentCard: PaymentCard?
    var transactionTypeRaw: String
    var purchaseDate: Date
    var scannedDate: Date
    var subtotal: Decimal?
    var tax: Decimal?
    var total: Decimal
    var currency: String
    var rawOCRText: String
    var statusRaw: String
    @Relationship(deleteRule: .cascade, inverse: \ReceiptItem.receipt) var items: [ReceiptItem]

    var transactionType: TransactionType {
        get { TransactionType(rawValue: transactionTypeRaw) ?? .other }
        set { transactionTypeRaw = newValue.rawValue }
    }

    var status: ReceiptStatus {
        get { ReceiptStatus(rawValue: statusRaw) ?? .pendingReview }
        set { statusRaw = newValue.rawValue }
    }

    init(
        store: Store,
        paymentCard: PaymentCard? = nil,
        transactionType: TransactionType,
        purchaseDate: Date,
        subtotal: Decimal? = nil,
        tax: Decimal? = nil,
        total: Decimal,
        currency: String,
        rawOCRText: String,
        status: ReceiptStatus,
        items: [ReceiptItem] = []
    ) {
        self.id = UUID()
        self.store = store
        self.paymentCard = paymentCard
        self.transactionTypeRaw = transactionType.rawValue
        self.purchaseDate = purchaseDate
        self.scannedDate = Date()
        self.subtotal = subtotal
        self.tax = tax
        self.total = total
        self.currency = currency
        self.rawOCRText = rawOCRText
        self.statusRaw = status.rawValue
        self.items = items
    }
}
