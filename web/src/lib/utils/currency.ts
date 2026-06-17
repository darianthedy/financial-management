export function toMinorUnits(amount: number, decimalPlaces = 2): number {
  const factor = Math.pow(10, decimalPlaces);
  return Math.round(amount * factor);
}

export function toDisplayAmount(minorUnits: number, decimalPlaces = 2): number {
  const factor = Math.pow(10, decimalPlaces);
  return minorUnits / factor;
}

/**
 * Registry of minor-unit counts sourced from the DB `currencies` table — the
 * SAME source the input/save path uses (`useCurrencies().decimalsFor`). This is
 * the source of truth for display.
 *
 * Do NOT derive these from `Intl`/ISO 4217: it disagrees with the app's data
 * (e.g. Intl reports 2 decimals for IDR — phantom "sen" — but the app stores
 * and edits IDR with 0). Using Intl would render a stored 50000 as "500.00".
 */
const decimalsByCode = new Map<string, number>();

export function registerCurrencyDecimals(
  rows: ReadonlyArray<{ code: string; decimal_places: number }>,
): void {
  for (const row of rows) decimalsByCode.set(row.code, row.decimal_places);
}

/** Minor-unit count for a currency from the DB registry; falls back to 2. */
export function currencyDecimals(currency: string): number {
  return decimalsByCode.get(currency) ?? 2;
}

/**
 * The app's single currency (from `user_settings.default_currency`). Since
 * currency is no longer stored per record, this is the one currency every amount
 * is formatted in. Set by CurrencyProvider; read by formatCurrency() as the
 * default, so leaf components can format without threading the currency through.
 */
let appCurrency = "USD";

export function setAppCurrency(code: string): void {
  appCurrency = code;
}

export function getAppCurrency(): string {
  return appCurrency;
}

export function formatCurrency(
  minorUnits: number,
  currency = appCurrency,
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

export interface FormattedCurrencyParts {
  /** Leading sign: "", "-", or "+". */
  sign: string;
  /** Currency symbol/prefix, e.g. "$", "Rp", or "USD " when Intl is unaware. */
  symbol: string;
  /** Numeric portion with group/decimal separators — no sign, no symbol. */
  number: string;
}

/**
 * Split a formatted amount into its sign, currency symbol, and numeric body so
 * lists can render the symbol in a fixed left column and right-align the digits
 * (see `AmountColumn`). Mirrors `formatCurrency`'s formatting exactly.
 */
export function formatCurrencyParts(
  minorUnits: number,
  currency = appCurrency,
  decimalPlaces = currencyDecimals(currency),
): FormattedCurrencyParts {
  const value = toDisplayAmount(minorUnits, decimalPlaces);
  try {
    const parts = new Intl.NumberFormat(undefined, {
      style: "currency",
      currency,
      minimumFractionDigits: decimalPlaces,
      maximumFractionDigits: decimalPlaces,
    }).formatToParts(value);
    let sign = "";
    let symbol = "";
    let number = "";
    for (const part of parts) {
      switch (part.type) {
        case "minusSign":
        case "plusSign":
          sign = part.value;
          break;
        case "currency":
          symbol += part.value;
          break;
        case "literal":
          // Whitespace between symbol and digits (e.g. "$ 1,234") rides with the
          // symbol so the numeric column stays flush.
          if (symbol && !number) symbol += part.value;
          break;
        default:
          number += part.value;
      }
    }
    return { sign, symbol, number };
  } catch {
    // Mirror formatCurrency's fallback for currencies Intl can't format.
    return {
      sign: value < 0 ? "-" : "",
      symbol: `${currency} `,
      number: Math.abs(toDisplayAmount(minorUnits, decimalPlaces)).toFixed(
        decimalPlaces,
      ),
    };
  }
}

/**
 * Widest numeric body (in characters) across a set of amounts, for sizing an
 * amount column so every symbol and digit lines up. Returns a `ch` count.
 */
export function maxCurrencyNumberWidth(
  amounts: ReadonlyArray<number>,
  currency = appCurrency,
  decimalPlaces = currencyDecimals(currency),
): number {
  let max = 0;
  for (const amount of amounts) {
    const { number } = formatCurrencyParts(amount, currency, decimalPlaces);
    if (number.length > max) max = number.length;
  }
  return max;
}

/** Signed display for a transaction amount (negative for outflows). */
export function formatSignedCurrency(
  minorUnits: number,
  sign: 1 | -1,
  currency = appCurrency,
  decimalPlaces = currencyDecimals(currency),
): string {
  const formatted = formatCurrency(minorUnits, currency, decimalPlaces);
  return sign < 0 ? `-${formatted}` : `+${formatted}`;
}
