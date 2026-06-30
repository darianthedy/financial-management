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

    // `NumberFormatter` is very expensive to instantiate (it loads ICU/locale
    // data on first use and is non-trivial thereafter). The formatting helpers
    // below are called once per row — and re-run while a List re-evaluates its
    // visible rows mid-swipe — so allocating a fresh formatter each call burns
    // the frame budget and shows up as a stutter before swipe actions render.
    // Cache and reuse a configured formatter per (style, currency, digits).
    private static let formatterLock = NSLock()
    private static var formatterCache: [String: NumberFormatter] = [:]

    private static func cachedFormatter(
        style: NumberFormatter.Style,
        currency: String,
        fractionDigits: Int
    ) -> NumberFormatter {
        let key = "\(style.rawValue)|\(currency)|\(fractionDigits)"
        formatterLock.lock()
        defer { formatterLock.unlock() }

        if let existing = formatterCache[key] { return existing }

        let formatter = NumberFormatter()
        formatter.numberStyle = style
        if style == .currency { formatter.currencyCode = currency }
        formatter.minimumFractionDigits = fractionDigits
        formatter.maximumFractionDigits = fractionDigits
        formatterCache[key] = formatter
        return formatter
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
        let formatter = cachedFormatter(style: .currency, currency: currency, fractionDigits: decimalPlaces)
        return formatter.string(from: NSNumber(value: toDisplayAmount(minorUnits, decimalPlaces: decimalPlaces))) ?? "$0.00"
    }

    // MARK: - Parts (for amount-column alignment)

    /// The grouped number body of `|minorUnits|` with no sign or symbol, e.g.
    /// "16,634,915". Used both as the digit run and — for the largest amount in a
    /// list — as the invisible spacer that sizes the digit slot so a column of
    /// amounts aligns. Mirrors web `widestCurrencyNumber` / `formatCurrencyParts`.
    static func numberBody(_ minorUnits: Int64, currency: String) -> String {
        let dp = fractionDigits(for: currency)
        let formatter = cachedFormatter(style: .decimal, currency: currency, fractionDigits: dp)
        return formatter.string(from: NSNumber(value: toDisplayAmount(abs(minorUnits), decimalPlaces: dp))) ?? "0"
    }

    /// Splits the formatted amount into its currency symbol (with any adjoining
    /// spacing) and its number body, so a list can pin the symbol in a fixed
    /// column and right-align the digits. Mirrors web `formatCurrencyParts`.
    /// Locales that place the symbol after the number collapse to a leading
    /// symbol here (the same simplification the web column makes).
    static func currencyParts(_ minorUnits: Int64, currency: String) -> (symbol: String, number: String) {
        let dp = fractionDigits(for: currency)
        let number = numberBody(minorUnits, currency: currency)
        let full = format(abs(minorUnits), currency: currency, decimalPlaces: dp)
        if let range = full.range(of: number) {
            let symbol = String(full[..<range.lowerBound]) + String(full[range.upperBound...])
            return (symbol, number)
        }
        return ("", full)
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
