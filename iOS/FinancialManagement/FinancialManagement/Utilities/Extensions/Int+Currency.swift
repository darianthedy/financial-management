import Foundation

extension Int64 {
    /// Formats minor units using the decimal places registered for `code`
    /// (falls back to 2 when the currency table hasn't loaded yet).
    func asCurrency(code: String) -> String {
        CurrencyUtils.format(self, currency: code, decimalPlaces: CurrencyUtils.fractionDigits(for: code))
    }
}
