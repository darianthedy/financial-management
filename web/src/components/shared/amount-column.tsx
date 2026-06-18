import { cn } from "@/lib/utils/cn";
import { formatCurrencyParts } from "@/lib/utils/currency";

interface Props {
  /** Amount in minor units. */
  minorUnits: number;
  /** Currency code; defaults to the app currency. */
  currency?: string;
  /**
   * Width (in `ch`) reserved for the numeric body, typically the widest amount
   * in the surrounding list (see `maxCurrencyNumberWidth`). With tabular digits
   * this lines the currency symbol up on the left and right-aligns the value so
   * every row's symbol and digits sit in the same column. Omit it for a
   * standalone amount that isn't being aligned against anything.
   */
  numberWidthCh?: number;
  /** Force a leading sign even for positives (e.g. "+$5.00" for inflows). */
  signed?: boolean;
  className?: string;
}

/**
 * Renders a currency amount as an aligned symbol + value pair: the symbol pins
 * to the left and the digits right-align within a shared-width column so a list
 * of amounts reads as a tidy table. Pass the same `numberWidthCh` to every item
 * in a list to align them.
 */
export function AmountColumn({
  minorUnits,
  currency,
  numberWidthCh,
  signed = false,
  className,
}: Props) {
  const { sign, symbol, number } = formatCurrencyParts(minorUnits, currency);
  const leadingSign = sign || (signed ? "+" : "");

  // Standalone (no shared width): nothing to line up against, so just render the
  // pieces in their natural order.
  if (numberWidthCh == null) {
    return (
      <span className={cn("inline-block tabular-nums", className)}>
        {leadingSign}
        {symbol}
        {number}
      </span>
    );
  }

  // Inside a list: lay the amount out as three fixed slots so columns line up
  // row-to-row — a sign slot, the currency symbol pinned to the left, and the
  // digits right-aligned within a shared-width slot. Every row uses the same
  // `numberWidthCh` (and the same symbol), so all the symbols stack in one
  // column on the left and all the digits' right edges stack in another on the
  // right, with any slack opening up as a gap between symbol and digits.
  return (
    <span className={cn("inline-flex items-baseline tabular-nums", className)}>
      {/* Sign slot: reserved even when empty so a leading "-"/"+" never nudges
          the symbol out of alignment with the unsigned rows. */}
      <span className="shrink-0 text-right" style={{ width: "1ch" }}>
        {leadingSign}
      </span>
      <span className="shrink-0">{symbol}</span>
      <span className="text-right" style={{ minWidth: `${numberWidthCh}ch` }}>
        {number}
      </span>
    </span>
  );
}
