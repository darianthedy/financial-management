import SwiftUI

struct CurrencyField: View {
    let label: String
    @Binding var value: String
    // Income/expense may be negative (e.g. a refund recorded as a negative
    // expense), matching web's CurrencyAmountInput `allowNegative`. Off by
    // default so amounts that must stay positive (budgets, transfers, account
    // balances) show no sign toggle.
    var allowNegative = false

    // The field stores a leading "-" for negatives; the toggle adds/removes it.
    private var isNegative: Bool { value.hasPrefix("-") }

    // Mobile number keyboards have no minus key, so the sign can't be typed.
    // The toggle flips it instead, mirroring web's +/− button, giving a
    // reachable way to enter negatives while the field stays number-only.
    private func toggleSign() {
        if isNegative {
            value.removeFirst()
        } else {
            value = "-" + value
        }
    }

    var body: some View {
        HStack {
            Text(label)
            Spacer()

            if allowNegative {
                Button(action: toggleSign) {
                    Image(systemName: isNegative ? "minus" : "plus")
                        .font(.system(size: 15, weight: .medium))
                        .frame(width: 30, height: 30)
                        .foregroundStyle(isNegative ? Color.appDanger : Color.secondary)
                        .overlay(
                            RoundedRectangle(cornerRadius: 6)
                                .stroke(isNegative ? Color.appDanger : Color.appBorder)
                        )
                }
                // .plain keeps the tap from selecting the whole Form row.
                .buttonStyle(.plain)
                .accessibilityLabel("Toggle positive or negative")
            }

            // Placeholder matches web's CurrencyAmountInput ("0", not "0.00").
            TextField("0", text: $value)
                // Number-only keypad (digits + decimal separator); the sign is
                // entered with the toggle above rather than typed.
                .keyboardType(.decimalPad)
                .multilineTextAlignment(.trailing)
                .frame(maxWidth: 150)
        }
    }
}
