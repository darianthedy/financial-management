import SwiftUI

struct TransactionRow: View {
    @Environment(AppState.self) private var appState
    let transaction: Transaction
    /// The transaction's source account, used for the avatar (§ row reuses the
    /// linked account image). Falls back to a type glyph when unavailable.
    var account: Account?

    var body: some View {
        HStack(spacing: 12) {
            if let account {
                AccountAvatar(imageUrl: account.imageUrl, accountType: account.type, size: 36)
                    .overlay(alignment: .bottomTrailing) { typeBadge }
            } else {
                Image(systemName: typeIcon)
                    .font(.title3)
                    .foregroundStyle(typeColor)
                    .frame(width: 36)
            }

            VStack(alignment: .leading, spacing: 2) {
                Text(transaction.description ?? transaction.type.rawValue.capitalized)
                    .font(.body)
                    .lineLimit(1)
                HStack(spacing: 6) {
                    Text(transaction.transactionDate, style: .date)
                    if transaction.status == .pending {
                        Text("Pending")
                            .foregroundStyle(.orange)
                    } else if transaction.status == .dismissed {
                        Text("Dismissed")
                            .foregroundStyle(.secondary)
                    }
                }
                .font(.caption)
                .foregroundStyle(.secondary)
            }

            Spacer()

            Text(formattedAmount)
                .font(.body.monospacedDigit().bold())
                .foregroundStyle(typeColor)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
                .opacity(transaction.status == .dismissed ? 0.4 : 1)
        }
        .padding(.vertical, 2)
    }

    private var typeBadge: some View {
        Image(systemName: typeIcon)
            .font(.system(size: 12))
            .foregroundStyle(typeColor)
            .background(Circle().fill(.background).padding(-1))
    }

    private var typeIcon: String {
        switch transaction.type {
        case .income: return "arrow.down.circle.fill"
        case .expense: return "arrow.up.circle.fill"
        case .transfer: return "arrow.left.arrow.right.circle.fill"
        }
    }

    private var typeColor: Color {
        switch transaction.type {
        case .income: return .green
        case .expense: return .red
        case .transfer: return .blue
        }
    }

    private var formattedAmount: String {
        let formatted = abs(transaction.amount).asCurrency(code: appState.defaultCurrency)
        switch transaction.type {
        case .transfer:
            return formatted
        case .income:
            // Signed amounts allowed: a negative income reduces cash.
            return transaction.amount < 0 ? "-\(formatted)" : "+\(formatted)"
        case .expense:
            // Expenses reduce cash; a negative expense (refund) adds it back.
            return transaction.amount < 0 ? "+\(formatted)" : "-\(formatted)"
        }
    }
}
