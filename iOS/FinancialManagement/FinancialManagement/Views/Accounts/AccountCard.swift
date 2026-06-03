import SwiftUI

struct AccountCard: View {
    let account: Account
    let currentBalance: Int64

    var body: some View {
        HStack {
            Image(systemName: iconName)
                .font(.title2)
                .foregroundStyle(.tint)
                .frame(width: 40)

            VStack(alignment: .leading, spacing: 2) {
                Text(account.name)
                    .font(.body)
                Text(account.type.rawValue.replacingOccurrences(of: "_", with: " ").capitalized)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            Text(currentBalance.asCurrency(code: account.currency))
                .font(.body.monospacedDigit().bold())
                .foregroundStyle(currentBalance >= 0 ? Color.primary : Color.red)
        }
        .padding(.vertical, 4)
    }

    private var iconName: String {
        switch account.type {
        case .bankAccount: return "building.columns"
        case .creditCard: return "creditcard"
        case .digitalWallet: return "wallet.pass"
        case .cash: return "banknote"
        case .other: return "ellipsis.circle"
        }
    }
}
