import Foundation

extension Int64 {
    func asCurrency(code: String) -> String {
        CurrencyUtils.format(self, currency: code)
    }
}
