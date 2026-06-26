import XCTest
@testable import FinancialManagement

/// Unit tests for the amount-entry formatting that backs `CurrencyField`,
/// mirroring the web app's `CurrencyAmountInput`: integer grouping with
/// thousands separators, fraction capping, and blur-time padding — while the
/// numeric string handed back to callers stays free of grouping commas.
final class CurrencyInputFormatTests: XCTestCase {
    // MARK: - groupInt

    func testGroupIntInsertsThousandsSeparators() {
        XCTAssertEqual(CurrencyInputFormat.groupInt("100"), "100")
        XCTAssertEqual(CurrencyInputFormat.groupInt("1000"), "1,000")
        XCTAssertEqual(CurrencyInputFormat.groupInt("1234"), "1,234")
        XCTAssertEqual(CurrencyInputFormat.groupInt("1234567"), "1,234,567")
        XCTAssertEqual(CurrencyInputFormat.groupInt(""), "")
    }

    // MARK: - parse: display grouping + clean numeric

    func testParseGroupsIntegerAndKeepsNumericClean() {
        let a = CurrencyInputFormat.parse("1234", decimals: 2, allowNegative: false)
        XCTAssertEqual(a.display, "1,234")
        XCTAssertEqual(a.numeric, "1234")

        let b = CurrencyInputFormat.parse("1234567", decimals: 2, allowNegative: false)
        XCTAssertEqual(b.display, "1,234,567")
        XCTAssertEqual(b.numeric, "1234567")
    }

    func testParseKeepsDecimalsAndCapsToAllowed() {
        let a = CurrencyInputFormat.parse("1234.5", decimals: 2, allowNegative: false)
        XCTAssertEqual(a.display, "1,234.5")
        XCTAssertEqual(a.numeric, "1234.5")

        // A third decimal digit is dropped for a 2-decimal currency.
        let b = CurrencyInputFormat.parse("1234.567", decimals: 2, allowNegative: false)
        XCTAssertEqual(b.display, "1,234.56")
        XCTAssertEqual(b.numeric, "1234.56")
    }

    func testParseStripsLeadingZerosButKeepsLoneZero() {
        let a = CurrencyInputFormat.parse("01", decimals: 2, allowNegative: false)
        XCTAssertEqual(a.display, "1")
        XCTAssertEqual(a.numeric, "1")

        let b = CurrencyInputFormat.parse("0.50", decimals: 2, allowNegative: false)
        XCTAssertEqual(b.display, "0.50")
        XCTAssertEqual(b.numeric, "0.50")
    }

    func testParseCollapsesExtraDots() {
        let a = CurrencyInputFormat.parse("1.2.3", decimals: 2, allowNegative: false)
        XCTAssertEqual(a.display, "1.23")
        XCTAssertEqual(a.numeric, "1.23")
    }

    func testParseEmptyYieldsEmpty() {
        let a = CurrencyInputFormat.parse("", decimals: 2, allowNegative: false)
        XCTAssertEqual(a.display, "")
        XCTAssertEqual(a.numeric, "")
    }

    func testParseHonoursNegativeOnlyWhenAllowed() {
        let allowed = CurrencyInputFormat.parse("-50", decimals: 2, allowNegative: true)
        XCTAssertEqual(allowed.display, "-50")
        XCTAssertEqual(allowed.numeric, "-50")

        // Sign is ignored for fields that must stay positive.
        let disallowed = CurrencyInputFormat.parse("-50", decimals: 2, allowNegative: false)
        XCTAssertEqual(disallowed.display, "50")
        XCTAssertEqual(disallowed.numeric, "50")
    }

    func testParseZeroDecimalCurrencyDropsFraction() {
        // IDR-style (0 decimals): group thousands, ignore any typed decimal point.
        let a = CurrencyInputFormat.parse("1234", decimals: 0, allowNegative: false)
        XCTAssertEqual(a.display, "1,234")
        XCTAssertEqual(a.numeric, "1234")

        let b = CurrencyInputFormat.parse("1234.56", decimals: 0, allowNegative: false)
        XCTAssertEqual(b.display, "123,456")
        XCTAssertEqual(b.numeric, "123456")
    }

    // The clean numeric is always parseable by Double(_:) (used by every caller).
    func testNumericIsDoubleParseable() {
        let p = CurrencyInputFormat.parse("12,345.6", decimals: 2, allowNegative: false)
        XCTAssertEqual(Double(p.numeric), 12345.6)
    }

    // MARK: - settled: padding for the non-typing display

    func testSettledPadsToFullDecimals() {
        XCTAssertEqual(CurrencyInputFormat.settled("1234", decimals: 2), "1,234.00")
        XCTAssertEqual(CurrencyInputFormat.settled("1234.5", decimals: 2), "1,234.50")
    }

    func testSettledNegative() {
        XCTAssertEqual(CurrencyInputFormat.settled("-1234.5", decimals: 2), "-1,234.50")
    }

    func testSettledEmptyOrZeroClearsToPlaceholder() {
        XCTAssertEqual(CurrencyInputFormat.settled("", decimals: 2), "")
        XCTAssertEqual(CurrencyInputFormat.settled("0", decimals: 2), "")
    }

    func testSettledZeroDecimalCurrency() {
        XCTAssertEqual(CurrencyInputFormat.settled("1234567", decimals: 0), "1,234,567")
        XCTAssertEqual(CurrencyInputFormat.settled("1500", decimals: 0), "1,500")
    }
}
