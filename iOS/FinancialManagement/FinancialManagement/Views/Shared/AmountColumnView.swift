import SwiftUI

/// A currency amount laid out as aligned slots — a fixed sign slot, the currency
/// symbol pinned left, and the digits right-aligned within a slot sized to the
/// widest number in the surrounding list — so a column of amounts reads as a tidy
/// table. Mirrors the web `AmountColumn`
/// (`web/src/components/shared/amount-column.tsx`): pass the same `widestNumber`
/// to every amount in a list to align them; omit it for a standalone amount.
///
/// Font and color come from the environment, so style it from the call site
/// (e.g. `.font(.subheadline.weight(.semibold)).foregroundStyle(color)`); the
/// digits are made monospaced internally so they line up across rows.
struct AmountColumnView: View {
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    @Environment(\.isSplitListColumn) private var isSplitListColumn
    /// Amount in minor units; only its magnitude is shown (the sign is explicit).
    let minorUnits: Int64
    /// Leading sign to display: "", "+", or "-". Kept explicit so callers can use
    /// their own convention (e.g. the transaction row's per-type signing).
    var sign: String = ""
    let currencyCode: String
    /// The widest number body in the list (see `CurrencyUtils.numberBody`), used
    /// as an invisible spacer to size the digit slot. Omit for a standalone amount.
    var widestNumber: String?
    /// Never wrap or truncate, even on a plain compact screen (lists whose
    /// rows give way around the amount, e.g. the transaction rows).
    var alwaysWhole = false

    var body: some View {
        let parts = CurrencyUtils.currencyParts(minorUnits, currency: currencyCode)
        if let widestNumber {
            HStack(spacing: 0) {
                // Sign slot: reserved (sized to a "+") even when empty so a leading
                // sign never nudges the symbol out of the column.
                ZStack(alignment: .trailing) {
                    Text("+").hidden()
                    Text(sign)
                }
                Text(parts.symbol)
                // Digit slot: an invisible copy of the widest number sizes it; the
                // real digits right-align on top.
                ZStack(alignment: .trailing) {
                    Text(widestNumber).hidden()
                    Text(parts.number)
                }
            }
            .monospacedDigit()
            .lineLimit(1)
            .modifier(WholeAmount(isOn: keepsWholeAmount))
        } else {
            Text(sign + parts.symbol + parts.number)
                .monospacedDigit()
                .lineLimit(1)
                .modifier(WholeAmount(isOn: keepsWholeAmount))
        }
    }

    /// Regular width, or any tiled split list column (which can report a
    /// compact size class even on iPad): money never wraps or truncates; its
    /// neighbours give way. A plain compact screen keeps its old sizing.
    private var keepsWholeAmount: Bool {
        alwaysWhole || AmountColumnView.keepsWholeAmount(
            sizeClass: horizontalSizeClass, inSplitListColumn: isSplitListColumn
        )
    }

    /// Shared with the rows and headers that rearrange around a whole amount.
    static func keepsWholeAmount(sizeClass: UserInterfaceSizeClass?, inSplitListColumn: Bool) -> Bool {
        sizeClass == .regular || inSplitListColumn
    }
}

/// Regular width: the amount is drawn at its full size, always. A call site's
/// `minimumScaleFactor` would otherwise let each row shrink by a different
/// amount whenever its card is laid out tight, so a column of amounts comes
/// out in mixed sizes with the symbol and digits out of line.
private struct WholeAmount: ViewModifier {
    let isOn: Bool

    func body(content: Content) -> some View {
        if isOn {
            content
                .minimumScaleFactor(1)
                .fixedSize()
        } else {
            content
        }
    }
}
