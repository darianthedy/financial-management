import XCTest
@testable import FinancialManagement

/// Unit tests for `YYYY-MM` month math that drives the MonthNavigator and the
/// default date window of the filter pipeline (§13, §7.2, §9.1).
final class DateUtilsTests: XCTestCase {
    func testNavigateForwardAndBackward() {
        XCTAssertEqual(DateUtils.navigate("2026-06", by: 1), "2026-07")
        XCTAssertEqual(DateUtils.navigate("2026-06", by: -1), "2026-05")
        XCTAssertEqual(DateUtils.navigate("2026-06", by: 0), "2026-06")
    }

    func testNavigateAcrossYearBoundary() {
        XCTAssertEqual(DateUtils.navigate("2026-12", by: 1), "2027-01")
        XCTAssertEqual(DateUtils.navigate("2026-01", by: -1), "2025-12")
        XCTAssertEqual(DateUtils.navigate("2026-06", by: 12), "2027-06")
    }

    func testNavigateMalformedInputIsReturnedUnchanged() {
        XCTAssertEqual(DateUtils.navigate("not-a-month", by: 1), "not-a-month")
    }

    func testCurrentYearMonthMatchesYYYYMMShape() {
        let value = DateUtils.currentYearMonth()
        XCTAssertEqual(value.count, 7)
        XCTAssertEqual(value[value.index(value.startIndex, offsetBy: 4)], "-")
        XCTAssertNotNil(DateUtils.monthDateRange(value), "current month should parse back")
    }

    func testYearMonthFromDate() {
        var comps = DateComponents()
        comps.year = 2026
        comps.month = 3
        comps.day = 15
        let date = Calendar.current.date(from: comps)!
        XCTAssertEqual(DateUtils.yearMonth(from: date), "2026-03")
    }

    func testMonthDateRangeSpansWholeMonth() {
        let range = DateUtils.monthDateRange("2026-02")    // non-leap February
        XCTAssertNotNil(range)
        XCTAssertEqual(DateUtils.yearMonthDay(from: range!.start), "2026-02-01")
        XCTAssertEqual(DateUtils.yearMonthDay(from: range!.end), "2026-02-28")
    }

    func testMonthDateRangeHandlesLeapFebruary() {
        let range = DateUtils.monthDateRange("2028-02")
        XCTAssertEqual(DateUtils.yearMonthDay(from: range!.end), "2028-02-29")
    }

    func testMonthDateRangeRejectsMalformedInput() {
        XCTAssertNil(DateUtils.monthDateRange("2026-13-oops"))
    }

    func testFormatYearMonthIsHumanReadable() {
        // Locale-dependent month name; assert the year is present and the raw
        // token is gone.
        let formatted = DateUtils.formatYearMonth("2026-06")
        XCTAssertTrue(formatted.contains("2026"))
        XCTAssertNotEqual(formatted, "2026-06")
    }
}
