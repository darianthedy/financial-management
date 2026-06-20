import SwiftUI

struct AccountCard: View {
    @Environment(AppState.self) private var appState
    let account: Account
    let currentBalance: Int64

    private var isDefault: Bool { appState.defaultAccountId == account.id }

    var body: some View {
        HStack {
            // Type-based SF Symbol stands in for the avatar (real images land in P03).
            Image(systemName: account.type.defaultIcon)
                .font(.title2)
                .foregroundStyle(.tint)
                .frame(width: 40)

            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 4) {
                    Text(account.name)
                        .font(.body)
                    if isDefault {
                        Image(systemName: "star.fill")
                            .font(.caption2)
                            .foregroundStyle(.yellow)
                    }
                }
                HStack(spacing: 6) {
                    Text(account.type.displayName)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    if !account.showOnDashboard {
                        Text("Off dashboard")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 1)
                            .background(Color.secondary.opacity(0.15), in: Capsule())
                    }
                }
            }

            Spacer()

            Text(currentBalance.asCurrency(code: appState.defaultCurrency))
                .font(.body.monospacedDigit().bold())
                .foregroundStyle(currentBalance >= 0 ? Color.primary : Color.red)
        }
        .padding(.vertical, 4)
    }
}
