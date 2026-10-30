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
    /// Installments reserving allowance in the displayed month (P1), shown below
    /// the budgets in the "Active installments" list.
    var activeInstallments: [ActiveInstallment] = []
    var yearMonth = DateUtils.currentYearMonth()
    var isLoading = false
    var errorMessage: String?
    var navigationDirection: Edge = .trailing

    private let repository = BudgetRepository()
    private let installmentRepository = InstallmentRepository()
    private let supabase = SupabaseService.shared.client
    private let realtime = RealtimeTableWatch()
    private var progressCache: [String: [BudgetProgress]] = [:]
    private var installmentsCache: [String: [ActiveInstallment]] = [:]

    func load() async {
        let month = yearMonth

        if progressCache[month] == nil {
            isLoading = true
        }
        defer { if yearMonth == month { isLoading = false } }

        async let progressResult = repository.progress(yearMonth: month)
        async let installmentsResult = try? installmentRepository.activeInstallments(reservingIn: month)

        do {
            let rows = try await progressResult
            progressCache[month] = rows
            if yearMonth == month {
                progress = rows
            }
        } catch {
            errorMessage = error.localizedDescription
        }

        if let installments = await installmentsResult {
            installmentsCache[month] = installments
            if yearMonth == month {
                activeInstallments = installments
            }
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
            activeInstallments = installmentsCache[newMonth] ?? []
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

    /// Cancel an installment: delete its header (cascades to allocations) so the
    /// future budgets recover their allowance, then re-flow the visible month.
    func cancelInstallment(_ item: ActiveInstallment) async {
        do {
            try await installmentRepository.cancel(id: item.id)
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

    /// Keeps the budgets live until the calling task is cancelled.
    func subscribeToChanges() async {
        // Budget rows (add / edit / remove / copy); linked transactions change
        // `spent`, which re-flows carry-over; installment reservations (P1) feed
        // `reserved` into the view.
        let tables = ["budgets", "transactions", "budget_installment_allocations"]
        await realtime.watch(topic: "budgets-realtime", tables: tables) { [weak self] in
            self?.invalidateAndReload()
        }
    }

    /// Carry-over is live, so any write can re-flow every month — drop the whole
    /// cache and reload the visible month.
    private func invalidateAndReload() {
        progressCache.removeAll()
        installmentsCache.removeAll()
        Task { await load() }
    }

    private func prefetchAdjacentMonths() async {
        let months = [-1, 1].map { DateUtils.navigate(yearMonth, by: $0) }
        for month in months {
            if progressCache[month] == nil {
                do {
                    progressCache[month] = try await repository.progress(yearMonth: month)
                } catch {
                    // Non-fatal: prefetch failure is silent.
                }
            }
            if installmentsCache[month] == nil,
               let installments = try? await installmentRepository.activeInstallments(reservingIn: month) {
                installmentsCache[month] = installments
            }
        }
    }
}
