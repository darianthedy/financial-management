/**
 * Parser for BCA credit card notification emails.
 *
 * Deliberately dependency-free and free of Deno APIs so it can be unit tested
 * with plain `node --test` (see parser.test.ts).
 *
 * BCA sends two relevant templates from KartuKreditBCA@klikbca.com, told apart
 * by the subject line:
 *
 *   "Credit Card Transaction Notification"                -> a purchase
 *   "Credit Card Reversal/Void Transaction Notification"  -> a reversal/void
 *
 * Both carry the fields in an HTML table of label / ":" / value rows. The
 * text/plain part of these emails is a single "-", so the HTML is the only
 * usable source.
 *
 * A reversal is emitted as a NEGATIVE expense, matching the convention set by
 * migration 20260612000001_allow_signed_amounts.sql: the balance impact of an
 * expense is `-amount`, so a negative amount returns the money and reduces the
 * budget/category totals, without ever touching income.
 */

export class BankEmailParseError extends Error {
  constructor(message: string) {
    super(message);
    this.name = "BankEmailParseError";
  }
}

export interface ParsedBankEmail {
  kind: "transaction" | "reversal";
  /** Merchant / ATM, used as the transaction description. */
  merchant: string;
  /** "Jenis Transaksi", e.g. E-COMMERCE. Informational. */
  transactionKind: string | null;
  /** Bank-local (WIB) calendar date, YYYY-MM-DD. */
  date: string;
  /** Raw "Pada Tanggal" value, kept for debugging. */
  rawDateTime: string;
  /** Signed minor units. IDR has 0 decimals, so this is whole rupiah. */
  amount: number;
  rawAmount: string;
}

const FIELD_MERCHANT = "Merchant / ATM";
const FIELD_DATETIME = "Pada Tanggal";
const FIELD_AMOUNT = "Sejumlah";
const FIELD_KIND = "Jenis Transaksi";

/**
 * Strips HTML to a list of non-empty trimmed lines.
 *
 * Every tag becomes a line break rather than being deleted, so adjacent table
 * cells cannot be glued into one token ("Merchant / ATM:M TIX").
 */
export function htmlToLines(html: string): string[] {
  const withoutInvisible = html
    .replace(/<!--[\s\S]*?-->/g, " ")
    .replace(/<(script|style)\b[\s\S]*?<\/\1>/gi, " ");

  const text = decodeEntities(withoutInvisible.replace(/<[^>]*>/g, "\n"));

  return text
    .split("\n")
    // NBSP is whitespace for our purposes but not matched by \s in older engines.
    .map((line) => line.replace(/ /g, " ").trim())
    .filter((line) => line.length > 0);
}

function decodeEntities(input: string): string {
  return input
    .replace(/&nbsp;/gi, " ")
    .replace(/&amp;/gi, "&")
    .replace(/&lt;/gi, "<")
    .replace(/&gt;/gi, ">")
    .replace(/&quot;/gi, '"')
    .replace(/&(?:apos|#0*39|#x0*27);/gi, "'")
    .replace(/&#x([0-9a-f]+);/gi, (_, hex) => safeFromCodePoint(parseInt(hex, 16)))
    .replace(/&#(\d+);/g, (_, dec) => safeFromCodePoint(parseInt(dec, 10)));
}

function safeFromCodePoint(code: number): string {
  if (!Number.isFinite(code) || code < 0 || code > 0x10ffff) return "";
  try {
    return String.fromCodePoint(code);
  } catch {
    return "";
  }
}

function normalizeLabel(value: string): string {
  return value.replace(/\s+/g, " ").trim().toLowerCase();
}

/**
 * Finds the value following a label line.
 *
 * The rendered layout is three lines: label, ":", value. The separator is
 * skipped, and the search stops after a couple of lines so that a template
 * where the field is absent yields null instead of silently picking up the
 * next field's label as a value. That matters because the reversal template
 * omits "Otentikasi" while the purchase template includes it.
 */
export function findField(lines: string[], label: string): string | null {
  const target = normalizeLabel(label);

  for (let i = 0; i < lines.length; i++) {
    if (normalizeLabel(lines[i]) !== target) continue;

    for (let j = i + 1; j < Math.min(i + 4, lines.length); j++) {
      const candidate = lines[j].replace(/^:\s*/, "").trim();
      if (candidate.length === 0) continue;
      // Hitting another known label means this field had no value.
      if (isKnownLabel(candidate)) return null;
      return candidate;
    }
    return null;
  }

  return null;
}

const KNOWN_LABELS = new Set(
  [
    FIELD_MERCHANT,
    FIELD_DATETIME,
    FIELD_AMOUNT,
    FIELD_KIND,
    "Nomor Customer",
    "Nomor Kartu",
    "Otentikasi",
  ].map(normalizeLabel),
);

function isKnownLabel(value: string): boolean {
  return KNOWN_LABELS.has(normalizeLabel(value));
}

/**
 * Parses an Indonesian-formatted rupiah amount: "Rp102.000,00" -> 102000.
 *
 * Dots are thousands separators and the comma is the decimal separator -- the
 * opposite of en-US, so this cannot go through parseFloat directly.
 *
 * The result is rounded to whole rupiah because IDR is seeded with 0 decimal
 * places (20260509000015_seed_currencies.sql) and the app stores integer minor
 * units scaled by that (20260606000001_drop_currency_columns.sql).
 */
export function parseIndonesianAmount(raw: string): number {
  const digits = raw.replace(/[^\d.,]/g, "");
  if (digits.length === 0) {
    throw new BankEmailParseError(`Amount has no digits: "${raw}"`);
  }

  const normalized = digits.replace(/\./g, "").replace(",", ".");
  const value = Number(normalized);

  if (!Number.isFinite(value)) {
    throw new BankEmailParseError(`Unparseable amount: "${raw}"`);
  }
  if (value <= 0) {
    // Zero would violate transactions_amount_check; a negative here would mean
    // the template changed and the sign is being applied twice.
    throw new BankEmailParseError(`Amount must be positive, got ${value} from "${raw}"`);
  }

  return Math.round(value);
}

/**
 * Parses "25-07-2026 07:49:41 WIB" -> "2026-07-25".
 *
 * The date is taken verbatim from the bank's local (WIB) clock and never
 * converted through UTC. `transactions.date` is a plain DATE, and a purchase at
 * 00:30 WIB is 17:30 UTC on the *previous* day -- converting would file it in
 * the wrong month at month boundaries.
 */
export function parseIndonesianDate(raw: string): string {
  const match = raw.match(/(\d{1,2})-(\d{1,2})-(\d{4})/);
  if (!match) {
    throw new BankEmailParseError(`Unrecognised date format: "${raw}"`);
  }

  const [, day, month, year] = match;
  const dd = day.padStart(2, "0");
  const mm = month.padStart(2, "0");

  const monthNum = Number(mm);
  const dayNum = Number(dd);
  if (monthNum < 1 || monthNum > 12 || dayNum < 1 || dayNum > 31) {
    throw new BankEmailParseError(`Date out of range: "${raw}"`);
  }

  return `${year}-${mm}-${dd}`;
}

/**
 * Whether a subject line is one of the two templates that carry a transaction.
 *
 *   "Credit Card Transaction Notification"               -> purchase
 *   "Credit Card Reversal/Void Transaction Notification" -> reversal
 *
 * The same sender also mails statements, payment confirmations and promos.
 * Those have no transaction table, so they are ignored rather than reported as
 * parse failures.
 *
 * This is deliberately a subject check and NOT a fallback for a missing-field
 * error: an email whose subject says "Transaction Notification" but whose
 * fields cannot be found is a real template change and must still fail loudly,
 * or genuine transactions would be dropped in silence.
 */
export function isTransactionNotification(subject: string): boolean {
  return /transaction\s+notification/i.test(subject ?? "");
}

export function isReversal(subject: string, lines: string[]): boolean {
  if (/reversal|void/i.test(subject)) return true;
  // Fallback for a changed/missing subject: the body says so too.
  return lines.some((line) => /transaksi\s+reversal\s*\/\s*void/i.test(line));
}

export function parseBcaCreditCardEmail(
  subject: string,
  htmlBody: string,
): ParsedBankEmail {
  const lines = htmlToLines(htmlBody ?? "");

  const merchant = findField(lines, FIELD_MERCHANT);
  const rawDateTime = findField(lines, FIELD_DATETIME);
  const rawAmount = findField(lines, FIELD_AMOUNT);

  const missing: string[] = [];
  if (!merchant) missing.push(FIELD_MERCHANT);
  if (!rawDateTime) missing.push(FIELD_DATETIME);
  if (!rawAmount) missing.push(FIELD_AMOUNT);

  if (missing.length > 0) {
    throw new BankEmailParseError(
      `Missing field(s): ${missing.join(", ")}. The email template may have changed.`,
    );
  }

  const reversal = isReversal(subject, lines);
  const magnitude = parseIndonesianAmount(rawAmount!);

  return {
    kind: reversal ? "reversal" : "transaction",
    merchant: merchant!,
    transactionKind: findField(lines, FIELD_KIND),
    date: parseIndonesianDate(rawDateTime!),
    rawDateTime: rawDateTime!,
    amount: reversal ? -magnitude : magnitude,
    rawAmount: rawAmount!,
  };
}
