import Foundation
import Observation
import SwiftUI
import Supabase

@Observable
@MainActor
final class DashboardViewModel {
    var yearMonth = DateUtils.currentYearMonth()
    var summary: DashboardSummary?
    var budgetPeriods: [BudgetPeriod] = []
    var isLoading = false
    var errorMessage: String?
    var navigationDirection: Edge = .trailing

    private let dashboardRepo = DashboardRepository()
    private let budgetRepo = BudgetRepository()

    private var summaryCache: [String: DashboardSummary] = [:]
    private var periodsCache: [String: [BudgetPeriod]] = [:]

    func load() async {
        let month = yearMonth

        if summaryCache[month] == nil {
            isLoading = true
        }
        defer { if yearMonth == month { isLoading = false } }

        do {
            async let summaryResult = dashboardRepo.getSummary(yearMonth: month)
            async let periodsResult = budgetRepo.getAllPeriodsForMonth(yearMonth: month)

            let fetchedSummary = try await summaryResult
            let fetchedPeriods = try await periodsResult

            summaryCache[month] = fetchedSummary
            periodsCache[month] = fetchedPeriods

            guard yearMonth == month else { return }
            summary = fetchedSummary
            budgetPeriods = fetchedPeriods
        } catch {
            errorMessage = error.localizedDescription
        }

        await prefetchAdjacentMonths()
    }

    func navigateMonth(by offset: Int) {
        navigationDirection = offset > 0 ? .trailing : .leading
        let newMonth = DateUtils.navigate(yearMonth, by: offset)

        let cachedSummary = summaryCache[newMonth]
        let cachedPeriods = periodsCache[newMonth] ?? []
        let hasCache = cachedSummary != nil

        withAnimation(.easeInOut(duration: 0.3)) {
            yearMonth = newMonth
            summary = cachedSummary
            budgetPeriods = cachedPeriods
            isLoading = !hasCache
        }

        Task { await load() }
    }

    private func prefetchAdjacentMonths() async {
        let months = [-1, 1].map { DateUtils.navigate(yearMonth, by: $0) }

        for month in months where summaryCache[month] == nil {
            do {
                async let s = dashboardRepo.getSummary(yearMonth: month)
                async let p = budgetRepo.getAllPeriodsForMonth(yearMonth: month)
                summaryCache[month] = try await s
                periodsCache[month] = try await p
            } catch {
                // Non-fatal: prefetch failure is silent
            }
        }
    }
}
