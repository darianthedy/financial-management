import SwiftUI
import Supabase

/// Budget picker for the scheduled-transaction form. Unlike `BudgetPicker`, which
/// binds a single budget **row id**, a schedule stores a budget **lineage by
/// name** (budgets are month-scoped, so the generator resolves the name to the
/// due month's budget at run time). This variant therefore binds `String?` — the
/// budget name — and mirrors web's `ScheduledForm` budget select: it lists the
/// due month's budgets by name, keeps a stored name selectable even when that
/// month has no row for it ("· none this month"), and offers an inline create.
struct BudgetNamePicker: View {
    @Environment(AppState.self) private var appState
    @Binding var selectedName: String?
    /// The schedule's next-due date; its month scopes the budget options, like
    /// web resolving against the due month.
    var dueDate: Date

    @State private var options: [Option] = []
    @State private var showingCreate = false

    // Sentinel string for the in-dropdown "Create…" item; the NUL prefix can't
    // collide with a real budget name.
    private static let createTag = "\u{0}__create__"

    private var yearMonth: String { DateUtils.yearMonth(from: dueDate) }

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

    /// A stored lineage may have no row in the due month yet; keep it selectable
    /// so editing doesn't silently drop the link (web's `budgetMissingFromMonth`).
    private var missingFromMonth: Bool {
        guard let name = selectedName else { return false }
        return !options.contains { $0.budgetName == name }
    }

    var body: some View {
        // Binds the optional name directly (None = nil); the "Create…" item uses a
        // sentinel string handled in onChange, mirroring web's ScheduledForm and
        // the id-based BudgetPicker.
        Picker("Budget", selection: $selectedName) {
            Text("No budget").tag(String?.none)

            if missingFromMonth, let name = selectedName {
                Text("\(name) · none this month").tag(Optional(name))
            }

            ForEach(options) { option in
                let remaining = option.remaining.asCurrency(code: appState.defaultCurrency)
                Text("\(option.budgetName) · \(remaining) left").tag(Optional(option.budgetName))
            }

            Divider()
            Label("Create budget for this month", systemImage: "plus")
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
            CreateBudgetSheet(yearMonth: yearMonth) { newBudgetId in
                await load()
                // Resolve the freshly created row back to its lineage name (web
                // stores the name, not the id).
                if let created = options.first(where: { $0.budgetId == newBudgetId }) {
                    selectedName = created.budgetName
                }
            }
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
        } catch {
            options = []
        }
    }
}
