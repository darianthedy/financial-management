import Foundation
import Observation
import SwiftUI

@Observable
@MainActor
final class FixedExpenseListViewModel {
    var fixedExpenses: [FixedExpense] = []
    var paidIds: Set<UUID> = []
    var yearMonth = DateUtils.currentYearMonth()
    var isLoading = false
    var errorMessage: String?
    var navigationDirection: Edge = .trailing

    private let repository = FixedExpenseRepository()
    private var cache: [String: [FixedExpense]] = [:]
    private var paidCache: [String: Set<UUID>] = [:]

    func load() async {
        let month = yearMonth

        if cache[month] == nil {
            isLoading = true
        }
        defer { if yearMonth == month { isLoading = false } }

        do {
            let entries = try await repository.getForMonth(yearMonth: month)
            let paid = try await repository.getPaidIds(fixedExpenseIds: entries.map(\.id))

            cache[month] = entries
            paidCache[month] = paid

            guard yearMonth == month else { return }
            fixedExpenses = entries
            paidIds = paid
        } catch {
            errorMessage = error.localizedDescription
        }

        await prefetchAdjacentMonths()
    }

    func navigateMonth(by offset: Int) {
        navigationDirection = offset > 0 ? .trailing : .leading
        let newMonth = DateUtils.navigate(yearMonth, by: offset)

        let cached = cache[newMonth]
        let hasCache = cached != nil

        withAnimation(.easeInOut(duration: 0.3)) {
            yearMonth = newMonth
            fixedExpenses = cached ?? []
            paidIds = paidCache[newMonth] ?? []
            isLoading = !hasCache
        }

        Task { await load() }
    }

    var paidCount: Int {
        fixedExpenses.filter { paidIds.contains($0.id) }.count
    }

    func isPaid(_ expense: FixedExpense) -> Bool {
        paidIds.contains(expense.id)
    }

    var totalAmount: Int64 {
        fixedExpenses.reduce(0) { $0 + $1.amount }
    }

    func deleteExpense(_ expense: FixedExpense) async {
        do {
            try await repository.delete(id: expense.id)
            cache.removeValue(forKey: yearMonth)
            await load()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func copyFromPreviousMonth() async {
        let previousMonth = DateUtils.navigate(yearMonth, by: -1)
        do {
            _ = try await repository.copyFromPreviousMonth(from: previousMonth, to: yearMonth)
            cache.removeValue(forKey: yearMonth)
            await load()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func prefetchAdjacentMonths() async {
        let months = [-1, 1].map { DateUtils.navigate(yearMonth, by: $0) }

        for month in months where cache[month] == nil {
            do {
                let entries = try await repository.getForMonth(yearMonth: month)
                cache[month] = entries
                paidCache[month] = try await repository.getPaidIds(fixedExpenseIds: entries.map(\.id))
            } catch {
                // Non-fatal
            }
        }
    }
}
