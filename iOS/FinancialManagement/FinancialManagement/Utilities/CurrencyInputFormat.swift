import Foundation

/// Pure formatting helpers for the amount entry field (`CurrencyField`), kept
/// separate from the view so they can be unit-tested. Mirrors the web app's
/// `CurrencyAmountInput` (web/src/components/shared/currency-amount-input.tsx):
/// the integer part is grouped with thousands separators and the fraction is
/// capped to the currency's decimal places as the user types, while the bound
/// numeric string stays free of grouping commas for `Double(_:)` parsing.
enum CurrencyInputFormat {
    /// Group the integer part with thousands separators: "1234" -> "1,234".
    /// Operates on bare digits only — strip any sign before calling.
    static func groupInt(_ digits: String) -> String {
        guard digits.count > 3 else { return digits }
        var grouped = ""
        for (offset, ch) in digits.reversed().enumerated() {
            if offset != 0, offset % 3 == 0 { grouped.append(",") }
            grouped.append(ch)
        }
        return String(grouped.reversed())
    }

    /// Parse arbitrary typed input into a clean grouped display string plus the
    /// numeric string written to the field's binding. Mirrors web's `parseInput`.
    /// `numeric` is "" when the field is logically empty so callers parsing it
    /// with `Double(_:)` see no value (the web's NaN).
    static func parse(
        _ raw: String,
        decimals: Int,
        allowNegative: Bool
    ) -> (display: String, numeric: String) {
        let negative = allowNegative && raw.contains("-")
        // Keep only ASCII digits and dots; drop the sign, grouping commas, and
        // anything else.
        var cleaned = raw.filter { ("0"..."9").contains($0) || $0 == "." }
        if decimals == 0 { cleaned = cleaned.replacingOccurrences(of: ".", with: "") }

        var intPart: String
        var fracPart = ""
        let hasDot: Bool
        if let firstDot = cleaned.firstIndex(of: ".") {
            intPart = String(cleaned[..<firstDot])
            // Collapse any further dots and cap to the allowed decimal count.
            let after = String(cleaned[cleaned.index(after: firstDot)...])
                .replacingOccurrences(of: ".", with: "")
            fracPart = String(after.prefix(decimals))
            hasDot = true
        } else {
            intPart = cleaned
            hasDot = false
        }

        // Strip leading zeros so a prefilled "0" vanishes once a digit is typed,
        // but keep a lone "0" (e.g. while typing "0.50").
        while intPart.count > 1, intPart.hasPrefix("0") { intPart.removeFirst() }

        let sign = negative ? "-" : ""
        let groupedInt = groupInt(intPart)
        let body = hasDot ? "\(groupedInt).\(fracPart)" : groupedInt
        let display = (body.isEmpty && !negative) ? "" : "\(sign)\(body)"

        let numeric: String
        if display.isEmpty {
            numeric = ""
        } else {
            let intForNum = intPart.isEmpty ? "0" : intPart
            numeric = "\(sign)\(intForNum)\(fracPart.isEmpty ? "" : ".\(fracPart)")"
        }
        return (display, numeric)
    }

    /// Display string for a value the user isn't actively typing: padded to full
    /// decimals (1234 -> "1,234.00"). Zero/empty renders as "" so the field's
    /// placeholder shows a bare "0". Mirrors web's `settledText`.
    static func settled(_ numeric: String, decimals: Int) -> String {
        guard let val = Double(numeric), val.isFinite, val != 0 else { return "" }
        let fixed = String(format: "%.\(decimals)f", val)
        let parts = fixed.split(separator: ".", maxSplits: 1, omittingEmptySubsequences: false)
        let intStr = String(parts[0])
        let negative = intStr.hasPrefix("-")
        let digits = negative ? String(intStr.dropFirst()) : intStr
        let grouped = (negative ? "-" : "") + groupInt(digits)
        if decimals > 0, parts.count > 1 {
            return "\(grouped).\(parts[1])"
        }
        return grouped
    }
}
