import Foundation
import Observation
import Supabase
import SwiftUI

/// Drives the month-scoped Budgets list. Reads progress rows from
/// `v_budget_progress` (effective / spent / remaining / carry-in), writes to the
/// `budgets` table, and refreshes live: because carry-over and spend are
/// computed in SQL, any change to `budgets` or `transactions` can re-flow the
/// displayed numbers. See iOS Tech Plan §5.9, §8.4.
@Observable
@MainActor
final class BudgetListViewModel {
    var progress: [BudgetProgress] = []
    var yearMonth = DateUtils.currentYearMonth()
    var isLoading = false
    var errorMessage: String?
    var navigationDirection: Edge = .trailing

    private let repository = BudgetRepository()
    private let supabase = SupabaseService.shared.client
    private var realtimeChannel: RealtimeChannelV2?
    private var progressCache: [String: [BudgetProgress]] = [:]

    func load() async {
        let month = yearMonth

        if progressCache[month] == nil {
            isLoading = true
        }
        defer { if yearMonth == month { isLoading = false } }

        do {
            let rows = try await repository.progress(yearMonth: month)
            progressCache[month] = rows
            guard yearMonth == month else { return }
            progress = rows
        } catch {
            errorMessage = error.localizedDescription
        }

        await prefetchAdjacentMonths()
    }

    func navigateMonth(by offset: Int) {
        navigationDirection = offset > 0 ? .trailing : .leading
        let newMonth = DateUtils.navigate(yearMonth, by: offset)

        let cached = progressCache[newMonth]
        let hasCache = cached != nil

        withAnimation(.easeInOut(duration: 0.3)) {
            yearMonth = newMonth
            progress = cached ?? []
            isLoading = !hasCache
        }

        Task { await load() }
    }

    func addBudget(name: String, periodicAmount: Int64, note: String?) async {
        do {
            try await repository.add(
                name: name, yearMonth: yearMonth, periodicAmount: periodicAmount, note: note
            )
            invalidateAndReload()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func updateBudget(id: UUID, name: String, periodicAmount: Int64, note: String?) async {
        do {
            try await repository.update(id: id, fields: [
                "name": .string(name),
                "periodic_amount": .integer(Int(periodicAmount)),
                "description": note.map(AnyJSON.string) ?? .null,
            ])
            invalidateAndReload()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func removeBudget(id: UUID) async {
        do {
            try await repository.remove(id: id)
            invalidateAndReload()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func copyFromPreviousMonth() async {
        do {
            try await repository.copyFromPreviousMonth(into: yearMonth)
            invalidateAndReload()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func subscribeToChanges() async {
        let channel = supabase.realtimeV2.channel("budgets-realtime")

        // Budget rows themselves (add / edit / remove / copy).
        let budgetChanges = channel.postgresChange(
            AnyAction.self, schema: "public", table: "budgets"
        )
        // Linked transactions change `spent`, which re-flows carry-over.
        let transactionChanges = channel.postgresChange(
            AnyAction.self, schema: "public", table: "transactions"
        )

        await channel.subscribe()

        Task {
            for await _ in budgetChanges { invalidateAndReload() }
        }
        Task {
            for await _ in transactionChanges { invalidateAndReload() }
        }

        realtimeChannel = channel
    }

    func unsubscribe() async {
        if let channel = realtimeChannel {
            await supabase.realtimeV2.removeChannel(channel)
        }
    }

    /// Carry-over is live, so any write can re-flow every month — drop the whole
    /// cache and reload the visible month.
    private func invalidateAndReload() {
        progressCache.removeAll()
        Task { await load() }
    }

    private func prefetchAdjacentMonths() async {
        let months = [-1, 1].map { DateUtils.navigate(yearMonth, by: $0) }
        for month in months where progressCache[month] == nil {
            do {
                progressCache[month] = try await repository.progress(yearMonth: month)
            } catch {
                // Non-fatal: prefetch failure is silent.
            }
        }
    }
}
