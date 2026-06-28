import SwiftUI

struct AccountDetailView: View {
    @Environment(AppState.self) private var appState
    @Environment(\.dismiss) private var dismiss
    @State private var viewModel: AccountDetailViewModel
    @State private var showingEditSheet = false
    @State private var showingArchiveConfirm = false

    init(accountId: UUID) {
        _viewModel = State(initialValue: AccountDetailViewModel(accountId: accountId))
    }

    var body: some View {
        List {
            if let account = viewModel.account {
                Section {
                    HStack {
                        Spacer()
                        AccountAvatar(imageUrl: account.imageUrl, accountType: account.type, size: 80)
                        Spacer()
                    }
                    .listRowBackground(Color.clear)
                }

                Section("Account Info") {
                    LabeledContent("Name", value: account.name)
                    LabeledContent("Type", value: account.type.displayName)
                    LabeledContent("Starting Balance",
                                   value: account.startingBalance.asCurrency(code: appState.defaultCurrency))
                    LabeledContent("Current Balance") {
                        Text(viewModel.currentBalance.asCurrency(code: appState.defaultCurrency))
                            .bold()
                    }
                }

                Section {
                    LabeledContent("Show on Dashboard", value: account.showOnDashboard ? "Yes" : "No")
                    LabeledContent("Default Account",
                                   value: appState.defaultAccountId == account.id ? "Yes" : "No")
                }

                Section {
                    Button("Archive Account", role: .destructive) {
                        showingArchiveConfirm = true
                    }
                }
            }
        }
        .navigationTitle(viewModel.account?.name ?? "Account")
        .alert("Archive account?", isPresented: $showingArchiveConfirm) {
            Button("Cancel", role: .cancel) {}
            Button("Archive", role: .destructive) {
                Task {
                    await viewModel.archiveAccount()
                    dismiss()
                }
            }
        } message: {
            Text("\"\(viewModel.account?.name ?? "This account")\" will be hidden from your accounts. Its transaction history is preserved.")
        }
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button("Edit") { showingEditSheet = true }
                    .disabled(viewModel.account == nil)
            }
        }
        .sheet(isPresented: $showingEditSheet) {
            if let account = viewModel.account {
                AccountFormSheet(account: account) {
                    await viewModel.load()
                }
            }
        }
        .task { await viewModel.load() }
        .refreshable { await viewModel.load() }
    }
}
