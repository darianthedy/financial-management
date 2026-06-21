import XCTest
@testable import FinancialManagement

/// Unit tests for the money conversion/formatting edge (§13, §7.1). Money lives
/// as `Int64` minor units everywhere; only `CurrencyUtils` crosses to `Double`.
final class CurrencyUtilsTests: XCTestCase {
    func testToMinorUnitsRoundsHalfAwayFromZero() {
        XCTAssertEqual(CurrencyUtils.toMinorUnits(10.50), 1050)
        XCTAssertEqual(CurrencyUtils.toMinorUnits(0.005), 1)        // 0.005 → 1 minor unit
        XCTAssertEqual(CurrencyUtils.toMinorUnits(0), 0)
    }

    func testToMinorUnitsHonoursDecimalPlaces() {
        // Zero-decimal currency (e.g. IDR): major units == minor units.
        XCTAssertEqual(CurrencyUtils.toMinorUnits(1500, decimalPlaces: 0), 1500)
        // Three-decimal currency.
        XCTAssertEqual(CurrencyUtils.toMinorUnits(1.234, decimalPlaces: 3), 1234)
    }

    func testToDisplayAmountIsInverseOfToMinorUnits() {
        XCTAssertEqual(CurrencyUtils.toDisplayAmount(1050), 10.50, accuracy: 0.0001)
        XCTAssertEqual(CurrencyUtils.toDisplayAmount(1500, decimalPlaces: 0), 1500, accuracy: 0.0001)
    }

    func testMinorUnitRoundTrip() {
        for amount in [0.00, 0.01, 9.99, 1234.56, 1_000_000.00] {
            let minor = CurrencyUtils.toMinorUnits(amount)
            XCTAssertEqual(CurrencyUtils.toDisplayAmount(minor), amount, accuracy: 0.0001)
        }
    }

    func testFormatProducesCurrencyString() {
        // NumberFormatter output is locale-shaped; assert on the digits/decimals
        // it must contain rather than the exact symbol placement.
        let formatted = CurrencyUtils.format(1050, currency: "USD")
        XCTAssertTrue(formatted.contains("10.50"), "got \(formatted)")
    }

    func testFractionDigitsDefaultsToTwoWhenNotConfigured() {
        XCTAssertEqual(CurrencyUtils.fractionDigits(for: "ZZZ"), 2)
    }

    func testConfigureRegistersDecimalPlaces() {
        CurrencyUtils.configure(with: [
            Currency(code: "IDR", name: "Indonesian Rupiah", symbol: "Rp", decimalPlaces: 0, createdAt: Date()),
            Currency(code: "USD", name: "US Dollar", symbol: "$", decimalPlaces: 2, createdAt: Date()),
        ])
        XCTAssertEqual(CurrencyUtils.fractionDigits(for: "IDR"), 0)
        XCTAssertEqual(CurrencyUtils.fractionDigits(for: "USD"), 2)
    }
}
