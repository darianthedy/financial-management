import SwiftUI
import XCTest
@testable import FinancialManagement

/// Gate G3's sheet and form boards: every form at its outer-display width and
/// at the card it gets on the inner display. These are the sheets' contents
/// only; the system draws the card itself, which only a device pass can show.
@MainActor
final class SheetScreensLayoutTests: XCTestCase {
    private let formCard = LayoutSize(
        name: "form-card", size: CGSize(width: 540, height: 620),
        horizontal: .regular, vertical: .regular, safeArea: .zero
    )
    private let pageCard = LayoutSize(
        name: "page-card", size: CGSize(width: 700, height: 669),
        horizontal: .regular, vertical: .regular, safeArea: .zero
    )

    override func setUp() async throws {
        try XCTSkipUnless(FixtureMode.isEnabled, "Layout tests need DUO_FIXTURES=1.")
    }

    private func capture<V: View>(_ name: String, _ view: V, card: LayoutSize) async throws {
        let appState = AppState()
        await appState.loadCurrencyData()
        for size in [LayoutSize.outerPortrait, card] {
            let snapshot = try await LayoutHarness.render(
                view.environment(appState).environment(ThemeManager()),
                at: size, timeout: .seconds(1), until: { _ in false }
            )
            attach(snapshot, name: name)
        }
    }

    func testFormSizedSheets() async throws {
        try await capture(
            "F1-transaction",
            NavigationStack { TransactionFormView(defaultAccountId: nil, currency: "IDR", decimalPlaces: 0) {} },
            card: formCard
        )
        try await capture(
            "F5-budget",
            BudgetFormSheet(mode: .add(yearMonth: DateUtils.currentYearMonth()), viewModel: BudgetListViewModel()),
            card: formCard
        )
        try await capture("F6-account", AccountFormSheet(), card: formCard)
        try await capture(
            "F7-fixed-expense",
            FixedExpenseFormSheet(yearMonth: DateUtils.currentYearMonth()),
            card: formCard
        )
        try await capture(
            "F8-scheduled",
            NavigationStack { ScheduledFormView(decimalPlaces: 0) },
            card: formCard
        )
        try await capture("F9-tag", TagFormSheet(mode: .add), card: formCard)
        try await capture("F10-category", CategoryFormSheet(), card: formCard)
    }

    func testPageSizedSheets() async throws {
        try await capture(
            "F2-filters",
            TransactionFilterSheet(initial: TransactionFilters()) { _ in },
            card: pageCard
        )
    }
}
