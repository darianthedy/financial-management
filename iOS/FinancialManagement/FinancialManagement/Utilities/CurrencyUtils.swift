import Foundation

/// Money is stored end-to-end as `Int64` minor units; conversion to a display
/// `Double` happens only at the formatting edge. Decimal places come from the
/// active default currency (see `AppState.decimalPlaces` / §7.1).
enum CurrencyUtils {
    // Cache of code -> decimal_places, populated from the `currencies` table so
    // call sites that only have a currency code can resolve its scale.
    private static var decimalPlacesCache: [String: Int] = [:]

    static func configure(with currencies: [Currency]) {
        decimalPlacesCache = Dictionary(uniqueKeysWithValues: currencies.map { ($0.code, $0.decimalPlaces) })
    }

    static func fractionDigits(for currencyCode: String) -> Int {
        decimalPlacesCache[currencyCode] ?? 2
    }

    static func toMinorUnits(_ amount: Double, decimalPlaces: Int = 2) -> Int64 {
        let factor = pow(10.0, Double(decimalPlaces))
        return Int64((amount * factor).rounded())
    }

    static func toDisplayAmount(_ minorUnits: Int64, decimalPlaces: Int = 2) -> Double {
        let factor = pow(10.0, Double(decimalPlaces))
        return Double(minorUnits) / factor
    }

    static func format(_ minorUnits: Int64, currency: String = "USD", decimalPlaces: Int = 2) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencyCode = currency
        formatter.minimumFractionDigits = decimalPlaces
        formatter.maximumFractionDigits = decimalPlaces
        return formatter.string(from: NSNumber(value: toDisplayAmount(minorUnits, decimalPlaces: decimalPlaces))) ?? "$0.00"
    }

    // MARK: - Currency-code convenience (resolves decimal places from the cache)
    // Transitional overloads for screens still keyed by a currency code; the
    // single-currency forms (P02+) pass `decimalPlaces` from `AppState`.

    static func toMinorUnits(_ amount: Double, currency: String) -> Int64 {
        toMinorUnits(amount, decimalPlaces: fractionDigits(for: currency))
    }

    static func toDisplayAmount(_ minorUnits: Int64, currency: String) -> Double {
        toDisplayAmount(minorUnits, decimalPlaces: fractionDigits(for: currency))
    }
}
