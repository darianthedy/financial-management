import Foundation

enum AccountType: String, Codable, CaseIterable {
    case bankAccount = "bank_account"
    case creditCard = "credit_card"
    case digitalWallet = "digital_wallet"
    case cash
    case other

    /// SF Symbol used when the account has no custom image (avatars land in P03).
    var defaultIcon: String {
        switch self {
        case .bankAccount:   return "building.columns"
        case .creditCard:    return "creditcard"
        case .digitalWallet: return "wallet.pass"
        case .cash:          return "banknote"
        case .other:         return "circle.grid.2x2"
        }
    }

    /// Human-readable label for pickers and rows.
    var displayName: String {
        switch self {
        case .bankAccount:   return "Bank Account"
        case .creditCard:    return "Credit Card"
        case .digitalWallet: return "Digital Wallet"
        case .cash:          return "Cash"
        case .other:         return "Other"
        }
    }
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
