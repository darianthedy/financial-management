import XCTest
@testable import FinancialManagement

/// Accounts and Transactions sometimes opened empty on the outer display
/// ("No accounts yet" with accounts on the server). The collapsed split can
/// start a list's `.task` and cancel it straight away; a load started from a
/// cancelled task must still fill the list. Runs against the fixture backend
/// (the test scheme sets `DUO_FIXTURES=1`).
@MainActor
final class ListLoadCancellationTests: XCTestCase {
    override func setUpWithError() throws {
        try XCTSkipUnless(FixtureMode.isEnabled, "needs the fixture backend (DUO_FIXTURES=1)")
    }

    func testAccountsLoadFromACancelledTaskStillFillsTheList() async {
        let vm = AccountListViewModel()
        let load = Task { await vm.load() }
        load.cancel()
        await load.value

        XCTAssertFalse(vm.accounts.isEmpty, "a cancelled caller left Accounts empty")
        XCTAssertNil(vm.errorMessage)
        XCTAssertFalse(vm.isLoading)
    }

    func testTransactionsLoadFromACancelledTaskStillFillsTheList() async {
        let vm = TransactionListViewModel()
        let load = Task { await vm.load() }
        load.cancel()
        await load.value

        XCTAssertFalse(vm.transactions.isEmpty, "a cancelled caller left Transactions empty")
        XCTAssertNil(vm.errorMessage)
        XCTAssertFalse(vm.isLoading)
    }

    /// The race on the outer display: a good load is in flight when a newer
    /// one starts from a task that is cancelled. The newer load wins the
    /// generation check, so it must not fail and discard the good one.
    func testCancelledNewerTransactionsLoadDoesNotDiscardTheGoodOne() async {
        let vm = TransactionListViewModel()
        let good = Task { await vm.load() }
        let cancelled = Task { await vm.load() }
        cancelled.cancel()
        await good.value
        await cancelled.value

        XCTAssertFalse(vm.transactions.isEmpty, "the cancelled newer load discarded the good one")
        XCTAssertNil(vm.errorMessage)
        XCTAssertFalse(vm.isLoading)
    }
}
