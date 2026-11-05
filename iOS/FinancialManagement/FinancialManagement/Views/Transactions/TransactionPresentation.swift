import SwiftUI

/// How a transaction reads on screen, shared by the list row and the detail
/// view so both name, color and sign it the same way (web: `deriveTitle`,
/// `amountColor`).
struct TransactionPresentation {
    let transaction: Transaction
    var account: Account?
    var category: Category?
    var transferAccountName: String?
    var tags: [Tag] = []
    var budgetName: String?
    var fixedExpenseName: String?
    var isSpread = false

    var isPending: Bool { transaction.status == .pending }

    /// Eligible for "Create virtual installment": an expense not already spread.
    var canCreateInstallment: Bool { transaction.type == .expense && !isSpread }

    // MARK: - Title (web: deriveTitle)

    struct DerivedTitle {
        let title: String
        /// The category was promoted to the title, so drop its chip.
        let usedCategory: Bool
        /// The fixed expense was promoted to the title, so drop its chip.
        let usedFixed: Bool
        /// The description became the title, so don't repeat it as a subtitle.
        let titleIsDescription: Bool
    }

    /// Title precedence: budget (non-transfer) → fixed expense → category →
    /// description → the type word.
    var derived: DerivedTitle {
        if let budgetName, transaction.type != .transfer {
            return DerivedTitle(title: budgetName, usedCategory: false, usedFixed: false, titleIsDescription: false)
        }
        if let fixedExpenseName {
            return DerivedTitle(title: fixedExpenseName, usedCategory: false, usedFixed: true, titleIsDescription: false)
        }
        if let category {
            return DerivedTitle(title: category.name, usedCategory: true, usedFixed: false, titleIsDescription: false)
        }
        if let description, !description.isEmpty {
            return DerivedTitle(title: description, usedCategory: false, usedFixed: false, titleIsDescription: true)
        }
        return DerivedTitle(title: typeName, usedCategory: false, usedFixed: false, titleIsDescription: false)
    }

    var title: String { derived.title }

    var description: String? { transaction.description }

    var typeName: String { transaction.type.rawValue.capitalized }

    /// "BCA → BCA VISA SQ Infinite" for a transfer, else the account's name.
    var accountLine: String? {
        guard let account else { return transferAccountName.map { "→ \($0)" } }
        if transaction.type == .transfer, let transferAccountName {
            return "\(account.name) → \(transferAccountName)"
        }
        return account.name
    }

    // MARK: - Type styling

    var typeIcon: String {
        switch transaction.type {
        case .income: return "arrow.down.circle.fill"
        case .expense: return "arrow.up.circle.fill"
        case .transfer: return "arrow.left.arrow.right.circle.fill"
        }
    }

    /// Amount/direction color, matching web `amountColor`: income → success,
    /// expense → danger, transfer → foreground.
    var amountColor: Color {
        switch transaction.type {
        case .income: return .appSuccess
        case .expense: return .appDanger
        case .transfer: return .appForeground
        }
    }

    /// The leading sign for the amount (the magnitude is rendered by
    /// `AmountColumnView`). Transfers are unsigned; income is `+` (a negative
    /// income reduces cash, so `-`); an expense is `-` (a negative expense — a
    /// refund — adds cash back, so `+`).
    var amountSign: String {
        switch transaction.type {
        case .transfer:
            return ""
        case .income:
            return transaction.amount < 0 ? "-" : "+"
        case .expense:
            return transaction.amount < 0 ? "+" : "-"
        }
    }
}
