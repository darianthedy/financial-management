import SwiftUI
import Supabase

/// Fixed-expense picker for the scheduled-transaction form. Like `BudgetNamePicker`,
/// a schedule stores a fixed-expense **lineage by name** (fixed expenses are
/// month-scoped, so the generator resolves the name to the due month's row at run
/// time), so this binds `String?` — the name. Mirrors web's `ScheduledForm` fixed
/// expense select: lists the due month's fixed expenses by name, keeps a stored
/// name selectable when that month has no row for it ("· none this month"), and
/// offers an inline create. Shown for expense schedules only.
struct FixedExpenseNamePicker: View {
    @Environment(AppState.self) private var appState
    @Binding var selectedName: String?
    /// The schedule's next-due date; its month scopes the options.
    var dueDate: Date

    @State private var options: [Option] = []
    @State private var showingCreate = false

    // Sentinel string for the in-dropdown "Create…" item; the NUL prefix can't
    // collide with a real fixed-expense name.
    private static let createTag = "\u{0}__create__"

    private var yearMonth: String { DateUtils.yearMonth(from: dueDate) }

    struct Option: Decodable, Identifiable {
        let id: UUID
        let name: String
        let amount: Int64
    }

    /// A stored lineage may have no row in the due month yet; keep it selectable
    /// so editing doesn't silently drop the link.
    private var missingFromMonth: Bool {
        guard let name = selectedName else { return false }
        return !options.contains { $0.name == name }
    }

    var body: some View {
        // Binds the optional name directly (None = nil); the "Create…" item uses a
        // sentinel string handled in onChange, mirroring the id-based pickers.
        Picker("Fixed Expense", selection: $selectedName) {
            Text("Not a fixed expense").tag(String?.none)

            if missingFromMonth, let name = selectedName {
                Text("\(name) · none this month").tag(Optional(name))
            }

            ForEach(options) { option in
                let amount = option.amount.asCurrency(code: appState.defaultCurrency)
                Text("\(option.name) · \(amount)").tag(Optional(option.name))
            }

            Divider()
            Label("Create fixed expense for this month", systemImage: "plus")
                .tag(Optional(Self.createTag))
        }
        .task { await load() }
        .onChange(of: dueDate) { Task { await load() } }
        .onChange(of: selectedName) { previousName, newName in
            // The "Create…" item isn't a real selection: revert and open the
            // create sheet instead.
            if newName == Self.createTag {
                selectedName = previousName
                showingCreate = true
            }
        }
        .sheet(isPresented: $showingCreate) {
            CreateFixedExpenseSheet(yearMonth: yearMonth) { newExpenseId in
                await load()
                // Resolve the freshly created row back to its lineage name.
                if let created = options.first(where: { $0.id == newExpenseId }) {
                    selectedName = created.name
                }
            }
        }
    }

    private func load() async {
        do {
            let client = SupabaseService.shared.client
            options = try await client
                .from("fixed_expenses")
                .select("id,name,amount")
                .eq("year_month", value: yearMonth)
                .order("name")
                .execute()
                .value
        } catch {
            options = []
        }
    }
}
