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
    @State private var showingCreate = false
    // The month options were last loaded for, so a date change can tell a real
    // month change apart from a same-month edit and only re-link on the former.
    @State private var loadedYearMonth: String?

    // Sentinel tag for the in-dropdown "Create…" item. A random UUID can't
    // collide with a real fixed-expense id, so selecting it is unambiguous.
    private static let createTag = UUID()

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

            // In-dropdown create action: selecting it opens the create sheet
            // (handled in onChange) rather than picking a real fixed expense.
            Divider()
            Label("Create fixed expense for this month", systemImage: "plus")
                .tag(Optional(Self.createTag))
        }
        .task { await load() }
        .onChange(of: transactionDate) { Task { await reloadForDateChange() } }
        .onChange(of: selectedExpenseId) { previousId, newId in
            // The "Create…" item isn't a real selection: revert to the prior
            // value and open the create sheet instead.
            if newId == Self.createTag {
                selectedExpenseId = previousId
                showingCreate = true
            }
        }
        .sheet(isPresented: $showingCreate) {
            CreateFixedExpenseSheet(yearMonth: yearMonth) { newExpenseId in
                await load()
                selectedExpenseId = newExpenseId
            }
        }
    }

    /// Reload options for the new month and, like web, re-link the selection to
    /// the same-named expense in that month (or clear it when none matches).
    private func reloadForDateChange() async {
        let didMonthChange = loadedYearMonth != yearMonth
        let previousName = options.first { $0.id == selectedExpenseId }?.name
        await load()
        if didMonthChange, let previousName {
            selectedExpenseId = options.first { $0.name == previousName }?.id
        }
    }

    private func load() async {
        do {
            let client = SupabaseService.shared.client
            // Web lists every fixed expense for the month (no is_active filter),
            // so a transaction can link to any of them.
            options = try await client
                .from("fixed_expenses")
                .select("id,name,amount")
                .eq("year_month", value: yearMonth)
                .order("name")
                .execute()
                .value
            loadedYearMonth = yearMonth
        } catch {
            options = []
        }
    }
}

/// Minimal inline fixed-expense creation for the month (name + amount), mirroring
/// web's "+ Create fixed expense for this month". Full management is P07.
private struct CreateFixedExpenseSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(AppState.self) private var appState
    let yearMonth: String
    var onCreated: (UUID) async -> Void

    @State private var name = ""
    @State private var amount = ""
    @State private var isSaving = false
    @State private var errorMessage: String?

    private let repository = FixedExpenseRepository()

    private var isValid: Bool {
        !name.trimmingCharacters(in: .whitespaces).isEmpty && (Double(amount) ?? 0) > 0
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Fixed expense for \(DateUtils.formatYearMonth(yearMonth))") {
                    TextField("Name", text: $name)
                    CurrencyField(label: "Amount", value: $amount, decimals: appState.decimalPlaces)
                }
                if let errorMessage {
                    // Error text uses the danger token, matching web's FieldError.
                    Section { Text(errorMessage).foregroundStyle(Color.appDanger) }
                }
            }
            .navigationTitle("New Fixed Expense")
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

        do {
            let minorUnits = CurrencyUtils.toMinorUnits(value, decimalPlaces: appState.decimalPlaces)
            let created = try await repository.create(
                name: name.trimmingCharacters(in: .whitespaces),
                yearMonth: yearMonth,
                amount: minorUnits
            )
            await onCreated(created.id)
            dismiss()
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}
