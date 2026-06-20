import SwiftUI
import Supabase

/// Fixed-expense picker reading `fixed_expenses` for the transaction's month.
/// Linking a transaction here is what marks the fixed expense paid (§5.3). The
/// fixed-expense *screen* lands in P07, but the table already exists, so the
/// picker can be built now.
struct FixedExpensePicker: View {
    @Environment(AppState.self) private var appState
    @Binding var selectedExpenseId: UUID?
    var transactionDate: Date

    @State private var options: [Option] = []

    private var yearMonth: String { DateUtils.yearMonth(from: transactionDate) }

    struct Option: Decodable, Identifiable {
        let id: UUID
        let name: String
        let amount: Int64
    }

    var body: some View {
        Picker("Fixed Expense", selection: $selectedExpenseId) {
            Text("None").tag(UUID?.none)
            ForEach(options) { option in
                let amount = option.amount.asCurrency(code: appState.defaultCurrency)
                Text("\(option.name) (\(amount))").tag(Optional(option.id))
            }
        }
        .task { await load() }
        .onChange(of: transactionDate) { Task { await load() } }
    }

    private func load() async {
        do {
            let client = SupabaseService.shared.client
            options = try await client
                .from("fixed_expenses")
                .select("id,name,amount")
                .eq("year_month", value: yearMonth)
                .eq("is_active", value: true)
                .order("name")
                .execute()
                .value
        } catch {
            options = []
        }
    }
}
