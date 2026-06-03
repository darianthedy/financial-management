import Foundation
import Observation
import SwiftUI

@Observable
@MainActor
final class TransactionListViewModel {
    var transactions: [Transaction] = []
    var yearMonth = DateUtils.currentYearMonth()
    var filterAccountId: UUID?
    var filterType: TransactionType?
    var isLoading = false
    var errorMessage: String?
    var navigationDirection: Edge = .trailing

    private let repository = TransactionRepository()
    private var transactionCache: [String: [Transaction]] = [:]

    func load() async {
        let month = yearMonth

        if transactionCache[month] == nil {
            isLoading = true
        }
        defer { if yearMonth == month { isLoading = false } }

        do {
            let fetched = try await repository.getAll(
                accountId: filterAccountId,
                yearMonth: month,
                type: filterType
            )

            transactionCache[month] = fetched

            guard yearMonth == month else { return }
            transactions = fetched
        } catch {
            errorMessage = error.localizedDescription
        }

        await prefetchAdjacentMonths()
    }

    func navigateMonth(by offset: Int) {
        navigationDirection = offset > 0 ? .trailing : .leading
        let newMonth = DateUtils.navigate(yearMonth, by: offset)

        let cached = transactionCache[newMonth]
        let hasCache = cached != nil

        withAnimation(.easeInOut(duration: 0.3)) {
            yearMonth = newMonth
            transactions = cached ?? []
            isLoading = !hasCache
        }

        Task { await load() }
    }

    func invalidateCacheAndReload() {
        transactionCache.removeAll()
        Task { await load() }
    }

    func deleteTransaction(_ transaction: Transaction) async {
        do {
            try await repository.delete(id: transaction.id)
            transactions.removeAll { $0.id == transaction.id }
            transactionCache[yearMonth] = transactions
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func prefetchAdjacentMonths() async {
        let months = [-1, 1].map { DateUtils.navigate(yearMonth, by: $0) }

        for month in months where transactionCache[month] == nil {
            do {
                let fetched = try await repository.getAll(
                    accountId: filterAccountId,
                    yearMonth: month,
                    type: filterType
                )
                transactionCache[month] = fetched
            } catch {
                // Non-fatal
            }
        }
    }
}
