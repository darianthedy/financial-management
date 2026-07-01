import Foundation
import Supabase

/// A tri-state multi-select facet.
///
/// The facet itself is held as an `Optional` on `TransactionFilters`:
///   * `nil`                         — **absent**: the facet applies no constraint.
///   * present, `values` non-empty   — match **any** listed value (OR-within).
///   * present, `includeBlanks`      — also (or only) match rows with **no** value.
///   * present, empty & no blanks     — **matches nothing** (the user engaged the
///                                     facet and unchecked everything).
///
/// `includeBlanks` is only meaningful for the category / tag / budget / fixed
/// facets (the ones that expose a leading "(Blanks)" option); the others leave it
/// `false`.
struct Facet<Value: Hashable & Codable>: Equatable, Codable {
    var values: Set<Value> = []
    var includeBlanks: Bool = false

    /// True when the facet, as configured, can match no rows at all.
    var matchesNothing: Bool { values.isEmpty && !includeBlanks }
}

/// The complete filter/search state for the Transactions list. Held by
/// `TransactionListViewModel`; not persisted across sessions (the serializer
/// exists only for deep links / state restoration — iOS Tech Plan §8.3.1).
struct TransactionFilters: Equatable, Codable {
    var search: String?
    var types: Facet<TransactionType>?
    var accounts: Facet<UUID>?
    var statuses: Facet<TransactionStatus>?
    var dateFrom: Date?
    var dateTo: Date?
    var categories: Facet<UUID>?
    var tags: Facet<UUID>?
    /// Amount bounds in **minor units** (converted from the user's major-unit
    /// input via `CurrencyUtils.toMinorUnits` at the input edge).
    var amountMin: Int64?
    var amountMax: Int64?
    var budgets: Facet<String>?
    var fixedExpenses: Facet<String>?

    init() {}

    /// Number of distinct facets currently constraining the query — drives the
    /// Filters button badge.
    var activeCount: Int {
        var n = 0
        if let s = search, !s.trimmingCharacters(in: .whitespaces).isEmpty { n += 1 }
        if types != nil { n += 1 }
        if accounts != nil { n += 1 }
        if statuses != nil { n += 1 }
        if dateFrom != nil || dateTo != nil { n += 1 }
        if categories != nil { n += 1 }
        if tags != nil { n += 1 }
        if amountMin != nil || amountMax != nil { n += 1 }
        if budgets != nil { n += 1 }
        if fixedExpenses != nil { n += 1 }
        return n
    }

    var isEmpty: Bool { activeCount == 0 }
}

/// Builds the **shared** predicate set used by both the paginated list query and
/// the whole-set Summary query, so the two can never drift (System Design §4.9).
///
/// Returns the narrowed builder, or `nil` when the filters can match nothing — a
/// present-but-empty tri-state facet, or a chosen-but-unresolved by-name
/// budget/fixed facet — so callers short-circuit to an empty result instead of
/// issuing a query that would (mis)match everything.
///
/// AND-across facets (each `.or(…)` / column predicate is a separate, ANDed
/// constraint); OR-within a facet (values combined inside a single `.or(…)`).
func applyFilters(
    _ filters: TransactionFilters,
    to query: PostgrestFilterBuilder,
    client: SupabaseClient
) async throws -> PostgrestFilterBuilder? {
    var q = query

    // Search (description, debounced upstream) — sequential ilike scan.
    if let raw = filters.search?.trimmingCharacters(in: .whitespaces), !raw.isEmpty {
        q = q.ilike("description", pattern: "%\(raw)%")
    }

    // Type — plain tri-state (no blanks).
    if let f = filters.types {
        if f.matchesNothing { return nil }
        q = q.in("type", values: f.values.map(\.rawValue))
    }

    // Status — plain tri-state.
    if let f = filters.statuses {
        if f.matchesNothing { return nil }
        q = q.in("status", values: f.values.map(\.rawValue))
    }

    // Account — matches the source OR the transfer side of each selected account.
    if let f = filters.accounts {
        if f.matchesNothing { return nil }
        let clause = f.values.flatMap { id in
            ["account_id.eq.\(id.uuidString)", "transfer_account_id.eq.\(id.uuidString)"]
        }.joined(separator: ",")
        q = q.or(clause)
    }

    // Date range — inclusive YYYY-MM-DD bounds.
    if let from = filters.dateFrom {
        q = q.gte("date", value: DateUtils.yearMonthDay(from: from))
    }
    if let to = filters.dateTo {
        q = q.lte("date", value: DateUtils.yearMonthDay(from: to))
    }

    // Amount range — minor units (bigint).
    if let min = filters.amountMin {
        q = q.gte("amount", value: String(min))
    }
    if let max = filters.amountMax {
        q = q.lte("amount", value: String(max))
    }

    // Category — selected ids and/or "(Blanks)".
    if let f = filters.categories {
        var clauses: [String] = []
        if !f.values.isEmpty {
            clauses.append("category_id.in.(\(f.values.map(\.uuidString).joined(separator: ",")))")
        }
        if f.includeBlanks { clauses.append("category_id.is.null") }
        if clauses.isEmpty { return nil }
        q = q.or(clauses.joined(separator: ","))
    }

    // Tags — array predicate over the view's `tag_ids`: overlap for selected,
    // empty-array for "(Blanks)/untagged".
    if let f = filters.tags {
        var clauses: [String] = []
        if !f.values.isEmpty {
            clauses.append("tag_ids.ov.{\(f.values.map(\.uuidString).joined(separator: ","))}")
        }
        if f.includeBlanks { clauses.append("tag_ids.eq.{}") }
        if clauses.isEmpty { return nil }
        q = q.or(clauses.joined(separator: ","))
    }

    // Budget — names resolve to ids via v_budget_progress, scoped to the date
    // range's months; OR-ed with "(Blanks)".
    if let f = filters.budgets {
        var clauses: [String] = []
        if !f.values.isEmpty {
            let ids = try await resolveBudgetIds(
                names: f.values, dateFrom: filters.dateFrom, dateTo: filters.dateTo, client: client
            )
            if !ids.isEmpty {
                clauses.append("budget_id.in.(\(ids.map(\.uuidString).joined(separator: ",")))")
            }
        }
        if f.includeBlanks { clauses.append("budget_id.is.null") }
        if clauses.isEmpty { return nil }   // chosen-but-unresolved (or empty) → no rows
        q = q.or(clauses.joined(separator: ","))
    }

    // Fixed expense — mirrors the budget filter, resolving via fixed_expenses.
    if let f = filters.fixedExpenses {
        var clauses: [String] = []
        if !f.values.isEmpty {
            let ids = try await resolveFixedExpenseIds(
                names: f.values, dateFrom: filters.dateFrom, dateTo: filters.dateTo, client: client
            )
            if !ids.isEmpty {
                clauses.append("fixed_expense_id.in.(\(ids.map(\.uuidString).joined(separator: ",")))")
            }
        }
        if f.includeBlanks { clauses.append("fixed_expense_id.is.null") }
        if clauses.isEmpty { return nil }
        q = q.or(clauses.joined(separator: ","))
    }

    return q
}

/// Months a `from`/`to` date range spans, as `YYYY-MM` prefixes (inclusive).
private func monthBounds(dateFrom: Date?, dateTo: Date?) -> (from: String?, to: String?) {
    (dateFrom.map { DateUtils.yearMonth(from: $0) }, dateTo.map { DateUtils.yearMonth(from: $0) })
}

private func resolveBudgetIds(
    names: Set<String>, dateFrom: Date?, dateTo: Date?, client: SupabaseClient
) async throws -> Set<UUID> {
    struct Row: Decodable { let budget_id: UUID }
    var q = client
        .from("v_budget_progress")
        .select("budget_id")
        .in("budget_name", values: Array(names))
    let (fromYM, toYM) = monthBounds(dateFrom: dateFrom, dateTo: dateTo)
    if let fromYM { q = q.gte("year_month", value: fromYM) }
    if let toYM { q = q.lte("year_month", value: toYM) }
    let rows: [Row] = try await q.execute().value
    return Set(rows.map(\.budget_id))
}

private func resolveFixedExpenseIds(
    names: Set<String>, dateFrom: Date?, dateTo: Date?, client: SupabaseClient
) async throws -> Set<UUID> {
    struct Row: Decodable { let id: UUID }
    var q = client
        .from("fixed_expenses")
        .select("id")
        .in("name", values: Array(names))
    let (fromYM, toYM) = monthBounds(dateFrom: dateFrom, dateTo: dateTo)
    if let fromYM { q = q.gte("year_month", value: fromYM) }
    if let toYM { q = q.lte("year_month", value: toYM) }
    let rows: [Row] = try await q.execute().value
    return Set(rows.map(\.id))
}
