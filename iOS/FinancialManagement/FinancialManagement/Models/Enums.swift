import Foundation

enum AccountType: String, Codable, CaseIterable {
    case bankAccount = "bank_account"
    case creditCard = "credit_card"
    case digitalWallet = "digital_wallet"
    case cash
    case other
}

enum TransactionType: String, Codable, CaseIterable {
    case income
    case expense
    case transfer
}

enum TransactionStatus: String, Codable, CaseIterable {
    case confirmed
    case pending
    case dismissed
}

enum RecurrenceType: String, Codable, CaseIterable {
    case monthly
}
