import SwiftUI

struct AccountFormSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(AppState.self) private var appState

    @State private var name = ""
    @State private var type: AccountType = .bankAccount
    @State private var currency = ""
    @State private var startingBalance = ""
    @State private var isSaving = false
    @State private var errorMessage: String?

    private let repository = AccountRepository()
    var onSaved: (() async -> Void)?

    var body: some View {
        NavigationStack {
            Form {
                Section("Account Details") {
                    TextField("Account Name", text: $name)

                    Picker("Type", selection: $type) {
                        ForEach(AccountType.allCases, id: \.self) { accountType in
                            Text(accountType.rawValue.replacingOccurrences(of: "_", with: " ").capitalized)
                                .tag(accountType)
                        }
                    }

                    CurrencyPicker(label: "Currency", selectedCode: $currency)

                    CurrencyField(label: "Starting Balance", value: $startingBalance)
                }

                if let error = errorMessage {
                    Section {
                        Text(error)
                            .foregroundStyle(.red)
                    }
                }
            }
            .navigationTitle("New Account")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        Task { await save() }
                    }
                    .disabled(name.isEmpty || isSaving)
                }
            }
            .onAppear {
                if currency.isEmpty {
                    currency = appState.defaultCurrency
                }
            }
        }
    }

    private func save() async {
        isSaving = true
        defer { isSaving = false }

        let balance = CurrencyUtils.toMinorUnits(Double(startingBalance) ?? 0, currency: currency)

        do {
            _ = try await repository.create(
                name: name,
                type: type,
                currency: currency,
                startingBalance: balance
            )
            await onSaved?()
            dismiss()
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}
