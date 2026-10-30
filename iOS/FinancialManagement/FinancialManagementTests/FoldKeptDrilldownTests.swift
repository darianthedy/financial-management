import XCTest
@testable import FinancialManagement

/// A fold re-creates a drill-down, which asks for its model again and must get
/// the same one, with the filters the user changed inside it.
@MainActor
final class FoldKeptDrilldownTests: XCTestCase {
    private func filters(_ search: String) -> TransactionFilters {
        var filters = TransactionFilters()
        filters.search = search
        return filters
    }

    func testSameItemKeepsItsModelAndEdits() {
        let models = FoldKeptModels()
        let first = models.drilldown(screen: "tags", item: "a", filters: filters("x"))
        first.filters.search = "edited"

        let recreated = models.drilldown(screen: "tags", item: "a", filters: filters("x"))

        XCTAssertTrue(recreated === first)
        XCTAssertEqual(recreated.filters.search, "edited")
    }

    func testAnotherItemStartsFromItsOwnFilters() {
        let models = FoldKeptModels()
        let first = models.drilldown(screen: "tags", item: "a", filters: filters("x"))

        let second = models.drilldown(screen: "tags", item: "b", filters: filters("y"))

        XCTAssertFalse(second === first)
        XCTAssertEqual(second.filters.search, "y")
    }

    func testScreensDoNotShareADrilldown() {
        let models = FoldKeptModels()
        let tags = models.drilldown(screen: "tags", item: "a", filters: filters("x"))
        let budgets = models.drilldown(screen: "budgets", item: "a", filters: filters("x"))
        XCTAssertFalse(tags === budgets)
    }

    func testDiscardingStartsOver() {
        let models = FoldKeptModels()
        let first = models.drilldown(screen: "tags", item: "a", filters: filters("x"))
        first.filters.search = "edited"

        models.discardDrilldown(screen: "tags")

        let reopened = models.drilldown(screen: "tags", item: "a", filters: filters("x"))
        XCTAssertFalse(reopened === first)
        XCTAssertEqual(reopened.filters.search, "x")
    }
}
