import SwiftUI
import Supabase

struct AccountPicker: View {
    let label: String
    @Binding var selectedId: UUID?

    @State private var accounts: [Account] = []

    var body: some View {
        Picker(label, selection: $selectedId) {
            Text("Select Account").tag(UUID?.none)
            ForEach(accounts) { account in
                Text(account.name).tag(Optional(account.id))
            }
        }
        .task {
            await loadAccounts()
        }
    }

    private func loadAccounts() async {
        do {
            let client = SupabaseService.shared.client
            accounts = try await client
                .from("accounts")
                .select()
                .eq("is_archived", value: false)
                .order("name")
                .execute()
                .value
        } catch {
            accounts = []
        }
    }
}
