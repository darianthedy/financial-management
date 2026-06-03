import Foundation
import Observation
import SwiftUI

@Observable
@MainActor
final class BudgetListViewModel {
    var budgets: [Budget] = []
    var periods: [UUID: BudgetPeriod] = [:]
    var yearMonth = DateUtils.currentYearMonth()
    var isLoading = false
    var errorMessage: String?
    var navigationDirection: Edge = .trailing

    private let repository = BudgetRepository()
    private var periodsCache: [String: [UUID: BudgetPeriod]] = [:]

    func load() async {
        let month = yearMonth

        if periodsCache[month] == nil {
            isLoading = true
        }
        defer { if yearMonth == month { isLoading = false } }

        do {
            budgets = try await repository.getAll()
            let allPeriods = try await repository.getAllPeriodsForMonth(yearMonth: month)
            let mapped = Dictionary(uniqueKeysWithValues: allPeriods.map { ($0.budgetId, $0) })

            periodsCache[month] = mapped

            guard yearMonth == month else { return }
            periods = mapped
        } catch {
            errorMessage = error.localizedDescription
        }

        await prefetchAdjacentMonths()
    }

    func navigateMonth(by offset: Int) {
        navigationDirection = offset > 0 ? .trailing : .leading
        let newMonth = DateUtils.navigate(yearMonth, by: offset)

        let cached = periodsCache[newMonth]
        let hasCache = cached != nil

        withAnimation(.easeInOut(duration: 0.3)) {
            yearMonth = newMonth
            periods = cached ?? [:]
            isLoading = !hasCache
        }

        Task { await load() }
    }

    func createBudget(name: String, enableCarryOver: Bool) async {
        do {
            let budget = try await repository.create(name: name, enableCarryOver: enableCarryOver)
            budgets.append(budget)
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func prefetchAdjacentMonths() async {
        let months = [-1, 1].map { DateUtils.navigate(yearMonth, by: $0) }

        for month in months where periodsCache[month] == nil {
            do {
                let allPeriods = try await repository.getAllPeriodsForMonth(yearMonth: month)
                periodsCache[month] = Dictionary(uniqueKeysWithValues: allPeriods.map { ($0.budgetId, $0) })
            } catch {
                // Non-fatal
            }
        }
    }
}
