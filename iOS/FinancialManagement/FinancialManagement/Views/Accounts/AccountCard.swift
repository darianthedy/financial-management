import SwiftUI

struct AccountCard: View {
    @Environment(AppState.self) private var appState
    let account: Account
    let currentBalance: Int64

    private var isDefault: Bool { appState.defaultAccountId == account.id }

    var body: some View {
        HStack {
            AccountAvatar(imageUrl: account.imageUrl, accountType: account.type, size: 40)

            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 4) {
                    Text(account.name)
                        .font(.body.weight(.medium))
                        .foregroundStyle(Color.appForeground)
                    if isDefault {
                        Image(systemName: "star.fill")
                            .font(.caption2)
                            .foregroundStyle(.yellow)
                    }
                }
                // web shows the type and an optional "Off dashboard" state as
                // pill badges.
                HStack(spacing: 4) {
                    Badge(account.type.displayName)
                    if !account.showOnDashboard {
                        Badge("Off dashboard")
                    }
                }
            }

            Spacer()

            // web: danger when negative, otherwise the default foreground.
            Text(currentBalance.asCurrency(code: appState.defaultCurrency))
                .font(.body.monospacedDigit().weight(.semibold))
                .foregroundStyle(currentBalance < 0 ? Color.appDanger : Color.appForeground)
        }
        .padding(.vertical, 4)
    }
}
