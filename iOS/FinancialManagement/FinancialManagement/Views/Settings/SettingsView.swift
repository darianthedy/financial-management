import SwiftUI

/// Settings screen (iOS Tech Plan §8.6): the single place to choose the default
/// currency and the default account.
///
/// Changing the currency upserts `user_settings.default_currency` and reloads
/// `AppState` so every formatter and form picks up the new currency and its
/// `decimalPlaces`. The default account writes `user_settings.default_account_id`
/// and pre-selects when adding a new transaction.
struct SettingsView: View {
    @Environment(AppState.self) private var appState
    @State private var viewModel = SettingsViewModel()
    @State private var defaultCurrency = "USD"
    @State private var defaultAccountId: UUID?

    var body: some View {
        List {
            Section("Currency") {
                CurrencyPickerView(label: "Default Currency", selectedCode: $defaultCurrency)
            }

            Section {
                Picker("Default Account", selection: $defaultAccountId) {
                    Text("None").tag(UUID?.none)
                    ForEach(viewModel.accounts) { account in
                        Text(account.name).tag(Optional(account.id))
                    }
                }
            } header: {
                Text("Default Account")
            } footer: {
                Text("Pre-selected when adding a new transaction.")
            }
        }
        .navigationTitle("Settings")
        .task {
            defaultCurrency = appState.defaultCurrency
            defaultAccountId = appState.defaultAccountId
            await viewModel.loadAccounts()
        }
        .onChange(of: defaultCurrency) { _, newValue in
            guard newValue != appState.defaultCurrency else { return }
            Task { await appState.updateDefaultCurrency(newValue) }
        }
        .onChange(of: defaultAccountId) { _, newValue in
            guard newValue != appState.defaultAccountId else { return }
            Task { try? await appState.setDefaultAccount(newValue) }
        }
    }
}
