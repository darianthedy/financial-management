import XCTest
import SwiftUI
@testable import FinancialManagement

/// ViewModel tests (§13): the synchronous, deterministic state these VMs expose —
/// filter folding, pager/load-more state, and the month-navigation direction that
/// drives the page transition (§9.1). Network-backed loading is intentionally not
/// awaited here; only the immediate state set before any `await` is asserted.
@MainActor
final class ViewModelTests: XCTestCase {
    // MARK: - TransactionListViewModel: filter state

    func testMainListAppliesNoDefaultDateWindow() {
        // The main Transactions list mirrors web: no implicit date window, so it
        // defaults to all transactions and the filters alone govern the period.
        let vm = TransactionListViewModel()
        let f = vm.effectiveFilters
        XCTAssertNil(f.dateFrom)
        XCTAssertNil(f.dateTo)
        XCTAssertFalse(vm.hasExplicitDateRange)
    }

    func testScopedListFoldsInDefaultMonthWindow() {
        // The scoped account-detail list browses month-by-month, so it folds the
        // visible month in as a default window.
        let vm = TransactionListViewModel(scopedAccountId: UUID())
        let f = vm.effectiveFilters
        XCTAssertNotNil(f.dateFrom)
        XCTAssertNotNil(f.dateTo)
    }

    func testExplicitDateRangeSuppressesDefaultWindow() {
        let vm = TransactionListViewModel()
        let pinned = Date(timeIntervalSince1970: 1_700_000_000)
        vm.filters.dateFrom = pinned
        XCTAssertTrue(vm.hasExplicitDateRange)
        XCTAssertEqual(vm.effectiveFilters.dateFrom, pinned)
    }

    func testScopedAccountIsForcedIntoEffectiveFilters() {
        let account = UUID()
        let vm = TransactionListViewModel(scopedAccountId: account)
        XCTAssertEqual(vm.effectiveFilters.accounts?.values, [account])
    }

    func testInitialFiltersAreApplied() {
        var initial = TransactionFilters()
        initial.search = "salary"
        let vm = TransactionListViewModel(initialFilters: initial)
        XCTAssertEqual(vm.filters.search, "salary")
    }

    func testClearFacetClearsTheRightFields() {
        let vm = TransactionListViewModel()
        vm.filters.dateFrom = Date()
        vm.filters.dateTo = Date()
        vm.clearFacet(.date)
        XCTAssertNil(vm.filters.dateFrom)
        XCTAssertNil(vm.filters.dateTo)

        vm.filters.amountMin = 100
        vm.filters.amountMax = 900
        vm.clearFacet(.amount)
        XCTAssertNil(vm.filters.amountMin)
        XCTAssertNil(vm.filters.amountMax)
    }

    func testClearAllFiltersResetsState() {
        let vm = TransactionListViewModel()
        vm.filters.search = "x"
        vm.filters.types = Facet(values: [.expense])
        vm.clearAllFilters()
        XCTAssertTrue(vm.filters.isEmpty)
    }

    func testUpdateSearchTrimsToNilWhenBlank() {
        let vm = TransactionListViewModel()
        vm.updateSearch("   ")
        XCTAssertNil(vm.filters.search)
        vm.updateSearch("rent")
        XCTAssertEqual(vm.filters.search, "rent")
    }

    // MARK: - TransactionListViewModel: pager

    func testCanLoadMoreReflectsTotalCount() {
        let vm = TransactionListViewModel()
        vm.transactions = []
        vm.totalCount = 0
        XCTAssertFalse(vm.canLoadMore)

        vm.totalCount = 5            // 0 loaded < 5 total
        XCTAssertTrue(vm.canLoadMore)
    }

    func testSetPageSizeUpdatesPageSize() {
        let vm = TransactionListViewModel()
        XCTAssertEqual(vm.pageSize, 50)
        vm.setPageSize(100)
        XCTAssertEqual(vm.pageSize, 100)
    }

    // MARK: - Month navigation direction (drives the page transition)

    func testTransactionNavigateMonthSetsDirectionAndMonth() {
        let vm = TransactionListViewModel()
        let start = vm.yearMonth

        vm.navigateMonth(by: 1)
        XCTAssertEqual(vm.navigationDirection, .trailing)
        XCTAssertEqual(vm.yearMonth, DateUtils.navigate(start, by: 1))

        vm.navigateMonth(by: -1)
        XCTAssertEqual(vm.navigationDirection, .leading)
        XCTAssertEqual(vm.yearMonth, start)
    }

    func testDashboardNavigateMonthSetsDirectionAndMonth() {
        let vm = DashboardViewModel()
        let start = vm.yearMonth

        vm.navigateMonth(by: -1)
        XCTAssertEqual(vm.navigationDirection, .leading)
        XCTAssertEqual(vm.yearMonth, DateUtils.navigate(start, by: -1))
    }

    func testBudgetNavigateMonthSetsDirectionAndMonth() {
        let vm = BudgetListViewModel()
        let start = vm.yearMonth

        vm.navigateMonth(by: 1)
        XCTAssertEqual(vm.navigationDirection, .trailing)
        XCTAssertEqual(vm.yearMonth, DateUtils.navigate(start, by: 1))
    }

    func testFixedExpenseNavigateMonthSetsDirectionAndMonth() {
        let vm = FixedExpenseListViewModel()
        let start = vm.yearMonth

        vm.navigateMonth(by: 1)
        XCTAssertEqual(vm.navigationDirection, .trailing)
        XCTAssertEqual(vm.yearMonth, DateUtils.navigate(start, by: 1))
    }
}
