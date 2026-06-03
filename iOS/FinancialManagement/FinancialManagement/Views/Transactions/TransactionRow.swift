import SwiftUI

struct TransactionRow: View {
    let transaction: Transaction

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: iconName)
                .font(.title3)
                .foregroundStyle(iconColor)
                .frame(width: 32)

            VStack(alignment: .leading, spacing: 2) {
                Text(transaction.description ?? transaction.type.rawValue.capitalized)
                    .font(.body)
                    .lineLimit(1)
                Text(transaction.transactionDate, style: .date)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            Text(formattedAmount)
                .font(.body.monospacedDigit().bold())
                .foregroundStyle(amountColor)
        }
        .padding(.vertical, 2)
    }

    private var iconName: String {
        switch transaction.type {
        case .income: return "arrow.down.circle.fill"
        case .expense: return "arrow.up.circle.fill"
        case .transfer: return "arrow.left.arrow.right.circle.fill"
        }
    }

    private var iconColor: Color {
        switch transaction.type {
        case .income: return .green
        case .expense: return .red
        case .transfer: return .blue
        }
    }

    private var amountColor: Color {
        switch transaction.type {
        case .income: return .green
        case .expense: return .red
        case .transfer: return .blue
        }
    }

    private var formattedAmount: String {
        let formatted = transaction.amount.asCurrency(code: transaction.currency)
        switch transaction.type {
        case .income: return "+\(formatted)"
        case .expense: return "-\(formatted)"
        case .transfer: return formatted
        }
    }
}
