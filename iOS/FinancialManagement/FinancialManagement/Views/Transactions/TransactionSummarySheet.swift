import SwiftUI
import Supabase

/// One labelled total inside a breakdown (e.g. spend per category).
private struct GroupTotal: Identifiable {
    let id: String
    let name: String
    let amount: Int64
}

/// Reduced result of the filtered set (§8.3.2). Money math uses **confirmed**
/// rows only; pending rows are surfaced separately as a projection; dismissed
/// rows are excluded. Transfers are reported in/out, never as income/expense.
private struct SummaryResult {
    var income: Int64 = 0
    var expense: Int64 = 0
    var transfersIn: Int64 = 0
    var transfersOut: Int64 = 0
    var largestExpense: Int64 = 0
    var count = 0
    var pendingIncome: Int64 = 0
    var pendingExpense: Int64 = 0
    var byAccount: [GroupTotal] = []
    var byCategory: [GroupTotal] = []
    var byBudget: [GroupTotal] = []
    var byFixed: [GroupTotal] = []
    var byTag: [GroupTotal] = []

    var net: Int64 { income - expense }
    var pendingNet: Int64 { pendingIncome - pendingExpense }
    var hasPending: Bool { pendingIncome != 0 || pendingExpense != 0 }
}

/// Whole-set Summary over `v_transactions`, sharing the list's `applyFilters`
/// (via `TransactionRepository.fetchAll`) so its numbers can't drift from the
/// list. Money rows use the vertical stacked layout (§9.2).
struct TransactionSummarySheet: View {
    @Environment(\.dismiss) private var dismiss

    let filters: TransactionFilters
    let currencyCode: String
    let accountsById: [UUID: Account]
    let categoriesById: [UUID: Category]
    let tagsById: [UUID: Tag]

    @State private var result: SummaryResult?
    @State private var isLoading = true
    @State private var errorMessage: String?

    private let repository = TransactionRepository()

    var body: some View {
        NavigationStack {
            Group {
                if isLoading {
                    ProgressView("Summarizing…")
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else if let errorMessage {
                    ContentUnavailableView("Couldn't Summarize", systemImage: "exclamationmark.triangle", description: Text(errorMessage))
                } else if let result {
                    summaryContent(result)
                }
            }
            .navigationTitle("Summary")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
        .task { await compute() }
    }

    @ViewBuilder
    private func summaryContent(_ r: SummaryResult) -> some View {
        List {
            Section("Totals") {
                moneyRow("Income", systemImage: "arrow.down.circle.fill", amount: r.income, color: .green)
                moneyRow("Expense", systemImage: "arrow.up.circle.fill", amount: r.expense, color: .red)
                moneyRow("Net", systemImage: "equal.circle.fill", amount: r.net, color: r.net >= 0 ? .green : .red, labelColor: .primary)
                moneyRow("Transfers in", systemImage: "arrow.down.left.circle", amount: r.transfersIn, color: .secondary, labelColor: .primary)
                moneyRow("Transfers out", systemImage: "arrow.up.right.circle", amount: r.transfersOut, color: .secondary, labelColor: .primary)
                moneyRow("Largest expense", systemImage: "flame.fill", amount: r.largestExpense, color: .red, labelColor: .primary)
                HStack {
                    Label("Count", systemImage: "number.circle.fill")
                        .foregroundStyle(.primary)
                    Spacer()
                    Text("\(r.count)").font(.title3.bold())
                }
            }

            if r.hasPending {
                Section("Pending (projection)") {
                    moneyRow("Income", systemImage: "arrow.down.circle", amount: r.pendingIncome, color: .green)
                    moneyRow("Expense", systemImage: "arrow.up.circle", amount: r.pendingExpense, color: .red)
                    moneyRow("Net", systemImage: "equal.circle", amount: r.pendingNet, color: r.pendingNet >= 0 ? .green : .red, labelColor: .primary)
                }
            }

            breakdown("By Account", r.byAccount)
            breakdown("By Category", r.byCategory)
            breakdown("By Budget", r.byBudget)
            breakdown("By Fixed Expense", r.byFixed)
            breakdown("By Tag", r.byTag)
        }
        .listStyle(.insetGrouped)
    }

    @ViewBuilder
    private func breakdown(_ title: String, _ groups: [GroupTotal]) -> some View {
        if !groups.isEmpty {
            Section {
                DisclosureGroup(title) {
                    ForEach(groups) { group in
                        moneyRow(group.name, systemImage: nil, amount: group.amount,
                                 color: group.amount >= 0 ? .green : .red, labelColor: .primary)
                    }
                }
            }
        }
    }

    /// Vertical stacked money row (§9.2): label/icon left, amount right; the
    /// amount never wraps (`lineLimit(1)` + `minimumScaleFactor`).
    private func moneyRow(_ label: String, systemImage: String?, amount: Int64, color: Color, labelColor: Color? = nil) -> some View {
        HStack {
            if let systemImage {
                Label(label, systemImage: systemImage).foregroundStyle(labelColor ?? color)
            } else {
                Text(label).foregroundStyle(labelColor ?? color)
            }
            Spacer()
            Text(amount.asCurrency(code: currencyCode))
                .font(.title3.bold())
                .foregroundStyle(color)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
        }
    }

    // MARK: - Computation

    private func compute() async {
        isLoading = true
        defer { isLoading = false }
        do {
            async let budgetsTask = loadNames(table: "budgets")
            async let fixedTask = loadNames(table: "fixed_expenses")
            let rows = try await repository.fetchAll(filters: filters)
            let budgetNames = try await budgetsTask
            let fixedNames = try await fixedTask
            result = build(rows: rows, budgetNames: budgetNames, fixedNames: fixedNames)
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func loadNames(table: String) async throws -> [UUID: String] {
        struct Row: Decodable { let id: UUID; let name: String }
        let rows: [Row] = try await SupabaseService.shared.client
            .from(table).select("id,name").execute().value
        return Dictionary(rows.map { ($0.id, $0.name) }, uniquingKeysWith: { a, _ in a })
    }

    private func build(rows: [VTransactionRow], budgetNames: [UUID: String], fixedNames: [UUID: String]) -> SummaryResult {
        var r = SummaryResult()
        var account: [UUID: Int64] = [:]
        var category: [String: Int64] = [:]
        var budget: [String: Int64] = [:]
        var fixed: [String: Int64] = [:]
        var tag: [String: Int64] = [:]

        for row in rows {
            switch row.status {
            case .dismissed:
                continue
            case .pending:
                switch row.type {
                case .income: r.pendingIncome += row.amount
                case .expense: r.pendingExpense += row.amount
                case .transfer: break
                }
                continue
            case .confirmed:
                break
            }

            r.count += 1
            switch row.type {
            case .income:
                r.income += row.amount
            case .expense:
                r.expense += row.amount
                r.largestExpense = max(r.largestExpense, row.amount)
            case .transfer:
                r.transfersOut += row.amount
                r.transfersIn += row.amount
            }

            // Breakdowns net income (+) against expense (−); transfers excluded.
            let contribution: Int64
            switch row.type {
            case .income: contribution = row.amount
            case .expense: contribution = -row.amount
            case .transfer: contribution = 0
            }
            guard row.type != .transfer else { continue }

            account[row.accountId, default: 0] += contribution
            category[row.categoryId?.uuidString ?? "∅", default: 0] += contribution
            budget[row.budgetId?.uuidString ?? "∅", default: 0] += contribution
            fixed[row.fixedExpenseId?.uuidString ?? "∅", default: 0] += contribution
            if row.tagIds.isEmpty {
                tag["∅", default: 0] += contribution
            } else {
                for t in row.tagIds { tag[t.uuidString, default: 0] += contribution }
            }
        }

        r.byAccount = account.map { GroupTotal(id: $0.key.uuidString, name: accountsById[$0.key]?.name ?? "Unknown", amount: $0.value) }
            .sorted { abs($0.amount) > abs($1.amount) }
        r.byCategory = group(category, blanks: "Uncategorized") { categoriesById[$0]?.name }
        r.byBudget = group(budget, blanks: "No budget") { budgetNames[$0] }
        r.byFixed = group(fixed, blanks: "No fixed expense") { fixedNames[$0] }
        r.byTag = group(tag, blanks: "Untagged") { tagsById[$0]?.name }
        return r
    }

    /// Turns a `[idString: amount]` map (with the `"∅"` blanks sentinel) into a
    /// sorted `[GroupTotal]`, resolving names via `name`.
    private func group(_ totals: [String: Int64], blanks: String, name: (UUID) -> String?) -> [GroupTotal] {
        totals.map { key, amount in
            if key == "∅" {
                return GroupTotal(id: key, name: blanks, amount: amount)
            }
            let resolved = UUID(uuidString: key).flatMap(name) ?? "Unknown"
            return GroupTotal(id: key, name: resolved, amount: amount)
        }
        .sorted { abs($0.amount) > abs($1.amount) }
    }
}
