import SwiftUI

/// Amount entry that groups the integer part with thousands separators and caps
/// the fraction to the currency's decimal places as the user types — mirroring
/// the web app's `CurrencyAmountInput`
/// (web/src/components/shared/currency-amount-input.tsx).
///
/// The bound `value` stays a clean numeric string (no grouping commas, e.g.
/// "1234.5" or "-50") so every call site can keep parsing it with `Double(_:)`.
/// The grouped, padded text lives in `displayText` and is shown in the field.
struct CurrencyField: View {
    let label: String
    @Binding var value: String
    // Decimal places for the active currency (0 for e.g. IDR). Drives both how
    // many fraction digits are kept while typing and the blur-time padding.
    var decimals: Int = 2
    // Income/expense may be negative (e.g. a refund recorded as a negative
    // expense), matching web's CurrencyAmountInput `allowNegative`. Off by
    // default so amounts that must stay positive (budgets, transfers, account
    // balances) show no sign toggle.
    var allowNegative = false

    // Grouped/padded text shown in the field. Kept separate from `value` so the
    // user sees "1,234.50" while downstream parsing reads "1234.5".
    @State private var displayText = ""
    @FocusState private var isFocused: Bool

    private var isNegative: Bool { displayText.hasPrefix("-") }

    var body: some View {
        HStack {
            Text(label)
            Spacer()

            if allowNegative {
                // Mobile number keypads have no minus key, so the sign can't be
                // typed. The toggle flips it instead, mirroring web's +/− button.
                Button(action: toggleSign) {
                    Image(systemName: isNegative ? "minus" : "plus")
                        .font(.system(size: 15, weight: .medium))
                        .frame(width: 30, height: 30)
                        .foregroundStyle(isNegative ? Color.appDanger : Color.secondary)
                        .overlay(
                            RoundedRectangle(cornerRadius: 6)
                                .stroke(isNegative ? Color.appDanger : Color.appBorder)
                        )
                        // Keep the 30pt bordered box visually, but expand the
                        // tappable area to the 44pt HIG minimum.
                        .frame(width: 44, height: 44)
                        .contentShape(Rectangle())
                }
                // .plain keeps the tap from selecting the whole Form row.
                .buttonStyle(.plain)
                .accessibilityLabel("Toggle positive or negative")
            }

            // Placeholder matches web's CurrencyAmountInput ("0", not "0.00").
            // Bound directly to displayText (not a transforming Binding): a
            // get/set binding that rewrites its backing state from inside `set`
            // does NOT push the reformatted text back into the live editing
            // buffer, so grouping wouldn't appear while typing. Reformatting in
            // `.onChange` below is a separate update cycle that does reflect.
            TextField("0", text: $displayText)
                // Number-only keypad (digits + decimal separator); the sign is
                // entered with the toggle above rather than typed.
                .keyboardType(decimals == 0 ? .numberPad : .decimalPad)
                .multilineTextAlignment(.trailing)
                .frame(maxWidth: 150)
                .focused($isFocused)
        }
        .onAppear { displayText = settledText(from: value) }
        // Reformat each keystroke into grouped display text + clean numeric
        // `value`. Guarded to the active editing session: the settle/prefill
        // paths set displayText themselves and must not be re-parsed back into
        // `value` (which would, e.g., turn an external "1234" into "1234.00").
        .onChange(of: displayText) { _, raw in
            guard isFocused else { return }
            let parsed = CurrencyInputFormat.parse(raw, decimals: decimals, allowNegative: allowNegative)
            if parsed.display != displayText { displayText = parsed.display }
            if parsed.numeric != value { value = parsed.numeric }
        }
        // Re-sync from the outside (edit prefill, "use suggested", reset) — but
        // never while the user is actively typing, which would fight the cursor.
        .onChange(of: value) { _, newValue in
            guard !isFocused else { return }
            displayText = settledText(from: newValue)
        }
        .onChange(of: decimals) { _, _ in
            guard !isFocused else { return }
            displayText = settledText(from: value)
        }
        // On blur, settle the display: pad to full decimals so the user never
        // has to type trailing zeros; empty/zero clears to show the "0"
        // placeholder rather than a literal "0.00".
        .onChange(of: isFocused) { _, focused in
            if !focused { displayText = settledText(from: value) }
        }
    }

    private func toggleSign() {
        let nextRaw = isNegative ? String(displayText.dropFirst()) : "-" + displayText
        let parsed = CurrencyInputFormat.parse(nextRaw, decimals: decimals, allowNegative: true)
        // Focus first so the blur-settle path doesn't wipe a lone "-" typed into
        // an otherwise empty field.
        isFocused = true
        displayText = parsed.display
        value = parsed.numeric
    }

    private func settledText(from numeric: String) -> String {
        CurrencyInputFormat.settled(numeric, decimals: decimals)
    }
}
