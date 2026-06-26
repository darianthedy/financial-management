import SwiftUI
import Supabase

/// Budget picker reading `v_budget_progress` for the transaction's month. Each
/// option shows the budget name and its effective amount (periodic + carry-in).
/// Offers an inline "create a budget for this month" action when desired. The
/// budget *screen* lands in P06, but the view and table already exist, so the
/// picker can be built now (§5.3).
struct BudgetPicker: View {
    @Environment(AppState.self) private var appState
    @Binding var selectedBudgetId: UUID?
    var transactionDate: Date

    @State private var options: [Option] = []
    @State private var showingCreate = false
    // The month options were last loaded for, so a date change can tell a real
    // month change apart from a same-month edit and only re-link on the former.
    @State private var loadedYearMonth: String?

    // Sentinel tag for the in-dropdown "Create…" item. A random UUID can't
    // collide with a real budget id, so selecting it is unambiguous.
    private static let createTag = UUID()

    private var yearMonth: String { DateUtils.yearMonth(from: transactionDate) }

    struct Option: Decodable, Identifiable {
        let budgetId: UUID
        let budgetName: String
        let remaining: Int64

        var id: UUID { budgetId }

        enum CodingKeys: String, CodingKey {
            case budgetId = "budget_id"
            case budgetName = "budget_name"
            case remaining
        }
    }

    var body: some View {
        Picker("Budget", selection: $selectedBudgetId) {
            Text("None").tag(UUID?.none)
            ForEach(options) { option in
                // Mirror web: budget name plus how much is left this month.
                let remaining = option.remaining.asCurrency(code: appState.defaultCurrency)
                Text("\(option.budgetName) · \(remaining) left").tag(Optional(option.budgetId))
            }

            // In-dropdown create action: selecting it opens the create sheet
            // (handled in onChange) rather than picking a real budget.
            Divider()
            Label("Create budget for this month", systemImage: "plus")
                .tag(Optional(Self.createTag))
        }
        .task { await load() }
        .onChange(of: transactionDate) { Task { await reloadForDateChange() } }
        .onChange(of: selectedBudgetId) { previousId, newId in
            // The "Create…" item isn't a real selection: revert to the prior
            // value and open the create sheet instead.
            if newId == Self.createTag {
                selectedBudgetId = previousId
                showingCreate = true
            }
        }
        .sheet(isPresented: $showingCreate) {
            CreateBudgetSheet(yearMonth: yearMonth) { newBudgetId in
                await load()
                selectedBudgetId = newBudgetId
            }
        }
    }

    /// Reload options for the new month and, like web, re-link the selection to
    /// the same-named budget in that month (or clear it when none matches).
    private func reloadForDateChange() async {
        let didMonthChange = loadedYearMonth != yearMonth
        let previousName = options.first { $0.budgetId == selectedBudgetId }?.budgetName
        await load()
        if didMonthChange, let previousName {
            selectedBudgetId = options.first { $0.budgetName == previousName }?.budgetId
        }
    }

    private func load() async {
        do {
            let client = SupabaseService.shared.client
            options = try await client
                .from("v_budget_progress")
                .select("budget_id,budget_name,remaining")
                .eq("year_month", value: yearMonth)
                .order("budget_name")
                .execute()
                .value
            loadedYearMonth = yearMonth
        } catch {
            options = []
        }
    }
}

/// Minimal inline budget creation: inserts one `budgets` row for the month
/// (name + periodic amount). Full budget management is P06.
private struct CreateBudgetSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(AppState.self) private var appState
    let yearMonth: String
    var onCreated: (UUID) async -> Void

    @State private var name = ""
    @State private var amount = ""
    @State private var isSaving = false
    @State private var errorMessage: String?

    private var isValid: Bool {
        !name.trimmingCharacters(in: .whitespaces).isEmpty && (Double(amount) ?? 0) > 0
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Budget for \(DateUtils.formatYearMonth(yearMonth))") {
                    TextField("Name", text: $name)
                    CurrencyField(label: "Monthly amount", value: $amount, decimals: appState.decimalPlaces)
                }
                if let errorMessage {
                    // Error text uses the danger token, matching web's FieldError.
                    Section { Text(errorMessage).foregroundStyle(Color.appDanger) }
                }
            }
            .navigationTitle("New Budget")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Create") { Task { await create() } }
                        .disabled(!isValid || isSaving)
                }
            }
        }
    }

    private func create() async {
        guard let value = Double(amount) else { return }
        isSaving = true
        defer { isSaving = false }

        struct Insert: Encodable {
            let user_id: UUID
            let name: String
            let year_month: String
            let periodic_amount: Int64
        }
        struct Created: Decodable { let id: UUID }

        do {
            let client = SupabaseService.shared.client
            let userId = try await client.auth.session.user.id
            let minorUnits = CurrencyUtils.toMinorUnits(value, decimalPlaces: appState.decimalPlaces)
            let created: Created = try await client
                .from("budgets")
                .insert(Insert(
                    user_id: userId,
                    name: name.trimmingCharacters(in: .whitespaces),
                    year_month: yearMonth,
                    periodic_amount: minorUnits
                ))
                .select("id")
                .single()
                .execute()
                .value
            await onCreated(created.id)
            dismiss()
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}
