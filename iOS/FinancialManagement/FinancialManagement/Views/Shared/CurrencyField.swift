import SwiftUI

struct CurrencyField: View {
    let label: String
    @Binding var value: String
    // Income/expense may be negative (e.g. a refund recorded as a negative
    // expense), matching web's CurrencyAmountInput `allowNegative`. Off by
    // default so amounts that must stay positive (budgets, transfers, account
    // balances) keep the decimal pad with no minus key.
    var allowNegative = false

    var body: some View {
        HStack {
            Text(label)
            Spacer()
            // Placeholder matches web's CurrencyAmountInput ("0", not "0.00").
            TextField("0", text: $value)
                // The decimal pad has no minus key, so switch to a keyboard that
                // offers one when negatives are allowed.
                .keyboardType(allowNegative ? .numbersAndPunctuation : .decimalPad)
                .multilineTextAlignment(.trailing)
                .frame(maxWidth: 150)
        }
    }
}
