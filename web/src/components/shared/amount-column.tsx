import { cn } from "@/lib/utils/cn";
import { formatCurrencyParts } from "@/lib/utils/currency";

interface Props {
  /** Amount in minor units. */
  minorUnits: number;
  /** Currency code; defaults to the app currency. */
  currency?: string;
  /**
   * The formatted numeric body of the widest amount in the surrounding list
   * (see `widestCurrencyNumber`). Used as an invisible spacer to size the number
   * slot exactly, so the currency symbol pins to the left and the digits
   * right-align — every row's symbol and digits sit in the same column. Sizing
   * by this string rather than a `ch` count keeps the longest amount flush
   * against the symbol (separators render narrower than a tabular digit, so a
   * count would over-reserve and leave a gap). Omit it for a standalone amount
   * that isn't being aligned against anything.
   */
  widestNumber?: string;
  /** Force a leading sign even for positives (e.g. "+$5.00" for inflows). */
  signed?: boolean;
  className?: string;
}

/**
 * Renders a currency amount as an aligned symbol + value pair: the symbol pins
 * to the left and the digits right-align within a shared-width column so a list
 * of amounts reads as a tidy table. Pass the same `widestNumber` to every item
 * in a list to align them.
 */
export function AmountColumn({
  minorUnits,
  currency,
  widestNumber,
  signed = false,
  className,
}: Props) {
  const { sign, symbol, number } = formatCurrencyParts(minorUnits, currency);
  const leadingSign = sign || (signed ? "+" : "");

  // Standalone (no shared width): nothing to line up against, so just render the
  // pieces in their natural order.
  if (!widestNumber) {
    return (
      <span className={cn("inline-block tabular-nums", className)}>
        {leadingSign}
        {symbol}
        {number}
      </span>
    );
  }

  // Inside a list: lay the amount out as three slots so columns line up
  // row-to-row — a sign slot, the currency symbol pinned to the left, and the
  // digits right-aligned within a slot sized to the widest number. Every row
  // uses the same `widestNumber` (and the same symbol), so all the symbols stack
  // in one column on the left and all the digits' right edges stack in another
  // on the right. The longest amount fills its slot and sits flush against the
  // symbol; shorter amounts pad on the left.
  return (
    <span className={cn("inline-flex items-baseline tabular-nums", className)}>
      {/* Sign slot: reserved even when empty so a leading "-"/"+" never nudges
          the symbol out of alignment with the unsigned rows. */}
      <span className="shrink-0 text-right" style={{ width: "1ch" }}>
        {leadingSign}
      </span>
      <span className="shrink-0">{symbol}</span>
      {/* An invisible copy of the widest number sizes this slot to its exact
          rendered width; the real digits right-align on top of it in the same
          grid cell. */}
      <span className="grid justify-items-end">
        <span aria-hidden className="invisible col-start-1 row-start-1">
          {widestNumber}
        </span>
        <span className="col-start-1 row-start-1">{number}</span>
      </span>
    </span>
  );
}
