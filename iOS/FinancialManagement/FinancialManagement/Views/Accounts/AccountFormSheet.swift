import SwiftUI
import Supabase

struct AccountFormSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(AppState.self) private var appState

    /// nil = create a new account; non-nil = edit an existing one.
    let account: Account?
    var onSaved: (() async -> Void)?

    @State private var name = ""
    @State private var type: AccountType = .bankAccount
    @State private var startingBalance = ""
    @State private var showOnDashboard = true
    @State private var setAsDefault = false
    @State private var isSaving = false
    @State private var errorMessage: String?
    @State private var didLoad = false

    private let repository = AccountRepository()

    init(account: Account? = nil, onSaved: (() async -> Void)? = nil) {
        self.account = account
        self.onSaved = onSaved
    }

    private var isEditing: Bool { account != nil }

    var body: some View {
        NavigationStack {
            Form {
                Section("Account Details") {
                    TextField("Account Name", text: $name)

                    Picker("Type", selection: $type) {
                        ForEach(AccountType.allCases, id: \.self) { accountType in
                            Text(accountType.displayName).tag(accountType)
                        }
                    }

                    CurrencyField(label: "Starting Balance", value: $startingBalance)
                }

                Section {
                    Toggle("Show on dashboard", isOn: $showOnDashboard)
                    Toggle("Set as default account", isOn: $setAsDefault)
                } footer: {
                    Text("The default account is pre-selected when adding a new transaction. Only one account can be the default.")
                }

                if let error = errorMessage {
                    Section {
                        Text(error).foregroundStyle(.red)
                    }
                }
            }
            .navigationTitle(isEditing ? "Edit Account" : "New Account")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        let decimalPlaces = appState.decimalPlaces
                        let wasDefault = account.map { appState.defaultAccountId == $0.id } ?? false
                        Task { await save(decimalPlaces: decimalPlaces, wasDefault: wasDefault) }
                    }
                    .disabled(name.isEmpty || isSaving)
                }
            }
            .onAppear(perform: loadInitialValues)
        }
    }

    private func loadInitialValues() {
        guard !didLoad else { return }
        didLoad = true
        if let account {
            name = account.name
            type = account.type
            startingBalance = Self.balanceString(account.startingBalance, decimalPlaces: appState.decimalPlaces)
            showOnDashboard = account.showOnDashboard
            setAsDefault = appState.defaultAccountId == account.id
        }
    }

    private func save(decimalPlaces: Int, wasDefault: Bool) async {
        isSaving = true
        defer { isSaving = false }

        let balance = CurrencyUtils.toMinorUnits(Double(startingBalance) ?? 0, decimalPlaces: decimalPlaces)

        do {
            let accountId: UUID
            if let account {
                try await repository.update(id: account.id, fields: [
                    "name": .string(name),
                    "type": .string(type.rawValue),
                    "starting_balance": .integer(Int(balance)),
                    "show_on_dashboard": .bool(showOnDashboard)
                ])
                accountId = account.id
            } else {
                let created = try await repository.create(
                    name: name,
                    type: type,
                    startingBalance: balance,
                    imageUrl: nil,                 // avatars are P03
                    showOnDashboard: showOnDashboard
                )
                accountId = created.id
            }

            // Default account lives on user_settings (one at a time), never on the
            // account row. Only write when the toggle actually changed.
            if setAsDefault && !wasDefault {
                try await appState.setDefaultAccount(accountId)
            } else if !setAsDefault && wasDefault {
                try await appState.setDefaultAccount(nil)
            }

            await onSaved?()
            dismiss()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private static func balanceString(_ minorUnits: Int64, decimalPlaces: Int) -> String {
        let amount = CurrencyUtils.toDisplayAmount(minorUnits, decimalPlaces: decimalPlaces)
        return String(format: "%.\(decimalPlaces)f", amount)
    }
}
