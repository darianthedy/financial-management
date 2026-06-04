export function toMinorUnits(amount: number, decimalPlaces = 2): number {
  const factor = Math.pow(10, decimalPlaces);
  return Math.round(amount * factor);
}

export function toDisplayAmount(minorUnits: number, decimalPlaces = 2): number {
  const factor = Math.pow(10, decimalPlaces);
  return minorUnits / factor;
}

/**
 * Minor-unit count for a currency per Intl/ISO 4217 (IDR/JPY -> 0, USD -> 2,
 * KWD -> 3). Matches the decimal_places seeded into the currencies table, so it
 * is a safe source of truth for display when an explicit count isn't supplied.
 */
export function currencyDecimals(currency: string): number {
  try {
    return new Intl.NumberFormat("en", {
      style: "currency",
      currency,
    }).resolvedOptions().maximumFractionDigits;
  } catch {
    return 2;
  }
}

export function formatCurrency(
  minorUnits: number,
  currency = "USD",
  decimalPlaces = currencyDecimals(currency),
): string {
  try {
    return new Intl.NumberFormat(undefined, {
      style: "currency",
      currency,
      minimumFractionDigits: decimalPlaces,
      maximumFractionDigits: decimalPlaces,
    }).format(toDisplayAmount(minorUnits, decimalPlaces));
  } catch {
    // Fall back gracefully if the currency code isn't recognized by Intl.
    return `${currency} ${toDisplayAmount(minorUnits, decimalPlaces).toFixed(decimalPlaces)}`;
  }
}

/** Signed display for a transaction amount (negative for outflows). */
export function formatSignedCurrency(
  minorUnits: number,
  sign: 1 | -1,
  currency = "USD",
  decimalPlaces = currencyDecimals(currency),
): string {
  const formatted = formatCurrency(minorUnits, currency, decimalPlaces);
  return sign < 0 ? `-${formatted}` : `+${formatted}`;
}
