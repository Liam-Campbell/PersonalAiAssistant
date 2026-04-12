import Foundation

enum TransactionType: String, Codable, CaseIterable {
    case contactless
    case chipAndPin
    case cash
    case online
    case other
}
