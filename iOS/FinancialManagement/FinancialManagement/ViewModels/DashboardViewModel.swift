import Foundation
import Observation
import Supabase
import SwiftUI

/// Drives the month-scoped dashboard. Loads all four widgets in parallel per
/// `year_month` and refreshes live on changes to `transactions`, `budgets`,
/// `fixed_expenses`, `accounts`, and `account_monthly_balances` — any of which
/// can re-flow the displayed numbers (carry-over and balances are computed in
/// SQL). See iOS Tech Plan §8.1 and System Design §4.6.
@Observable
@MainActor
final class DashboardViewModel {
    var yearMonth = DateUtils.currentYearMonth()
    var data: DashboardData?
    var isLoading = false
    var errorMessage: String?
    var navigationDirection: Edge = .trailing

    private let repository = DashboardRepository()
    private let supabase = SupabaseService.shared.client
    private var realtimeChannel: RealtimeChannelV2?
    private var cache: [String: DashboardData] = [:]

    func load() async {
        let month = yearMonth

        if cache[month] == nil {
            isLoading = true
        }
        defer { if yearMonth == month { isLoading = false } }

        do {
            let fetched = try await repository.load(yearMonth: month)
            cache[month] = fetched
            guard yearMonth == month else { return }
            data = fetched
        } catch {
            errorMessage = error.localizedDescription
        }

        await prefetchAdjacentMonths()
    }

    func navigateMonth(by offset: Int) {
        navigate(to: DateUtils.navigate(yearMonth, by: offset))
    }

    /// Jump the whole dashboard to `month` — driven by the MonthNavigator. Shows
    /// any cached data instantly, animates in the direction of travel, then
    /// reloads. A no-op when already there.
    /// `year_month` is 'YYYY-MM' text, so lexical order matches chronological.
    func navigate(to month: String) {
        guard month != yearMonth else { return }
        navigationDirection = month > yearMonth ? .trailing : .leading

        let cached = cache[month]
        withAnimation(.easeInOut(duration: 0.3)) {
            yearMonth = month
            data = cached
            isLoading = cached == nil
        }

        Task { await load() }
    }

    func subscribeToChanges() async {
        let channel = supabase.realtimeV2.channel("dashboard-realtime")

        // Any of these can change a widget: transactions feed spend/balances,
        // budgets/fixed_expenses define the plan, accounts/balances drive the
        // Accounts card.
        let tables = ["transactions", "budgets", "fixed_expenses", "accounts", "account_monthly_balances"]
        let streams = tables.map {
            channel.postgresChange(AnyAction.self, schema: "public", table: $0)
        }

        await channel.subscribe()

        for stream in streams {
            Task {
                for await _ in stream { invalidateAndReload() }
            }
        }

        realtimeChannel = channel
    }

    func unsubscribe() async {
        if let channel = realtimeChannel {
            await supabase.realtimeV2.removeChannel(channel)
        }
    }

    /// Carry-over and balances are live, so any write can re-flow every month —
    /// drop the whole cache and reload the visible month.
    private func invalidateAndReload() {
        cache.removeAll()
        Task { await load() }
    }

    private func prefetchAdjacentMonths() async {
        let months = [-1, 1].map { DateUtils.navigate(yearMonth, by: $0) }
        for month in months where cache[month] == nil {
            if let fetched = try? await repository.load(yearMonth: month) {
                cache[month] = fetched
            }
        }
    }
}
