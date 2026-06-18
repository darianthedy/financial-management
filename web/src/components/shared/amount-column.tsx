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
   * every row's symbol and digits sit in the same column.
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

  // Reserve room for the symbol and a sign slot on top of the numeric body, then
  // right-align the whole thing. Every row in a list shares one width (same
  // symbol, same +1 sign slot), so the digits' right edges line up while the
  // symbol stays flush against the number — any slack falls to the left of the
  // symbol instead of opening a gap between the symbol and the digits.
  const minWidthCh =
    numberWidthCh != null ? numberWidthCh + symbol.length + 1 : undefined;

  return (
    <span
      className={cn("inline-block text-right tabular-nums", className)}
      style={minWidthCh != null ? { minWidth: `${minWidthCh}ch` } : undefined}
    >
      {leadingSign}
      {symbol}
      {number}
    </span>
  );
}
