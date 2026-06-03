import Foundation

enum CurrencyUtils {
    private static var decimalPlacesCache: [String: Int] = [:]

    static func configure(with currencies: [Currency]) {
        decimalPlacesCache = Dictionary(uniqueKeysWithValues: currencies.map { ($0.code, $0.decimalPlaces) })
    }

    static func fractionDigits(for currencyCode: String) -> Int {
        decimalPlacesCache[currencyCode] ?? 2
    }

    static func toMinorUnits(_ amount: Double, currency: String = "USD") -> Int64 {
        let dp = fractionDigits(for: currency)
        let factor = pow(10.0, Double(dp))
        return Int64((amount * factor).rounded())
    }

    static func toDisplayAmount(_ minorUnits: Int64, currency: String = "USD") -> Double {
        let dp = fractionDigits(for: currency)
        let factor = pow(10.0, Double(dp))
        return Double(minorUnits) / factor
    }

    static func format(_ minorUnits: Int64, currency: String = "USD") -> String {
        let dp = fractionDigits(for: currency)
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencyCode = currency
        formatter.minimumFractionDigits = dp
        formatter.maximumFractionDigits = dp
        return formatter.string(from: NSNumber(value: toDisplayAmount(minorUnits, currency: currency))) ?? "\(minorUnits)"
    }
}
