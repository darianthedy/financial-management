import Foundation
import Observation
import SwiftUI
import Supabase

@Observable
@MainActor
final class DashboardViewModel {
    var yearMonth = DateUtils.currentYearMonth()
    var summary: DashboardSummary?
    var budgetProgress: [BudgetProgress] = []
    var isLoading = false
    var errorMessage: String?
    var navigationDirection: Edge = .trailing

    private let dashboardRepo = DashboardRepository()
    private let budgetRepo = BudgetRepository()

    private var summaryCache: [String: DashboardSummary] = [:]
    private var progressCache: [String: [BudgetProgress]] = [:]

    func load() async {
        let month = yearMonth

        if summaryCache[month] == nil {
            isLoading = true
        }
        defer { if yearMonth == month { isLoading = false } }

        do {
            async let summaryResult = dashboardRepo.getSummary(yearMonth: month)
            async let progressResult = budgetRepo.progress(yearMonth: month)

            let fetchedSummary = try await summaryResult
            let fetchedProgress = try await progressResult

            summaryCache[month] = fetchedSummary
            progressCache[month] = fetchedProgress

            guard yearMonth == month else { return }
            summary = fetchedSummary
            budgetProgress = fetchedProgress
        } catch {
            errorMessage = error.localizedDescription
        }

        await prefetchAdjacentMonths()
    }

    func navigateMonth(by offset: Int) {
        navigationDirection = offset > 0 ? .trailing : .leading
        let newMonth = DateUtils.navigate(yearMonth, by: offset)

        let cachedSummary = summaryCache[newMonth]
        let cachedProgress = progressCache[newMonth] ?? []
        let hasCache = cachedSummary != nil

        withAnimation(.easeInOut(duration: 0.3)) {
            yearMonth = newMonth
            summary = cachedSummary
            budgetProgress = cachedProgress
            isLoading = !hasCache
        }

        Task { await load() }
    }

    private func prefetchAdjacentMonths() async {
        let months = [-1, 1].map { DateUtils.navigate(yearMonth, by: $0) }

        for month in months where summaryCache[month] == nil {
            do {
                async let s = dashboardRepo.getSummary(yearMonth: month)
                async let p = budgetRepo.progress(yearMonth: month)
                summaryCache[month] = try await s
                progressCache[month] = try await p
            } catch {
                // Non-fatal: prefetch failure is silent
            }
        }
    }
}
