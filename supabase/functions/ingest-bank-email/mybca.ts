/**
 * Parser for myBCA "Internet Transaction Journal" emails (bca@bca.co.id).
 *
 * These are the debit-account notifications, and they are a DIFFERENT family
 * from the credit card alerts in parser.ts: different sender, different
 * subject, different date format, and -- the trap -- a different number format.
 *
 *   credit card (parser.ts) : "Rp102.000,00"   dot = thousands, comma = decimal
 *   myBCA (here)            : "IDR 102,000.00" comma = thousands, dot = decimal
 *
 * Running one through the other's number parser silently yields a value off by
 * a factor of 1000, so the two must never share an amount parser.
 *
 * A single subject covers eight observed layouts, distinguished only by which
 * rows are present (verified against 40 real messages):
 *
 *   1. QRIS Payment                    Payment to / ... / Total Payment
 *   2. Credit Card & Paylater - BCA    Name / Total Bill / Total Payment
 *   3. Transfer to BCA Account         Beneficiary Name / Transfer Amount
 *   4. ...as 3, plus "Save to Beneficiary List"
 *   5. Transfer to BCA Virtual Account Pay Amount / Admin Fee / Total Payment
 *   6. ...as 5, but an itemised bill (TAGIHAN IPKL, DENDA, ...) / Bill Total
 *   7. Interbank transfer (BI FAST)    Amount / Fee, and NO total row
 *   8. ...as 7, plus "Save to beneficiary list" (note: lowercase 'b' and 'l',
 *      where format 4 title-cases them -- do not match these case-sensitively)
 *
 * Rather than detect the format, the fields are read by priority. That way a
 * ninth layout that reuses the same vocabulary keeps working.
 */

import {
  BankEmailParseError,
  findFieldIn,
  htmlToLines,
  labelSet,
} from "./html.ts";

export interface ParsedMyBcaEmail {
  /** Coarse family, for reporting. */
  kind: "mybca";
  /** "QRIS Payment", "Transfer to BCA Account", ... Informational. */
  transactionKind: string | null;
  /** Counterparty / merchant, used as the transaction description. */
  merchant: string;
  /** Bank-local (WIB) calendar date, YYYY-MM-DD. */
  date: string;
  /** Raw "Transaction Date" value, kept for debugging. */
  rawDateTime: string;
  /** Whole rupiah actually debited, fees included. Always positive. */
  amount: number;
  rawAmount: string;
  /** Which row(s) the amount came from, so a wrong total is traceable. */
  amountSource: string;
  /** "Successful", etc. Only successful transactions are ingested. */
  status: string | null;
  /**
   * True when this journal settles a BCA credit card bill.
   *
   * Money moves between two accounts the user owns rather than leaving the
   * ledger, so the caller books it as a `transfer` to the card account instead
   * of an expense. Booking it as an expense would double-count: the card's own
   * purchase alerts are already ingested as expenses, so the bill payment would
   * charge the same spending to the budget a second time.
   */
  settlesCreditCard: boolean;
}

/**
 * Every label any of the eight layouts can emit.
 *
 * Completeness matters: this set is the guard that stops an empty row from
 * absorbing the next row's label as its value (format 5's "Description" row is
 * empty and sits directly above "Reference No.").
 *
 * The itemised bill rows of format 6 (TAGIHAN IPKL, TAGIHAN AIR, DENDA,
 * BIAYA ADMIN) are merchant-supplied and cannot be enumerated, which is why
 * every amount read is additionally validated as currency by parseMyBcaAmount.
 */
const KNOWN_LABELS = labelSet([
  "Status",
  "Transaction Date",
  "Transaction Type",
  "Transfer Type",
  "Source of Fund",
  "Source Currency",
  "Transfer Currency",
  "Payment to",
  "Merchant Location",
  "Acquirer",
  "Merchant PAN",
  "Terminal ID",
  "Customer PAN",
  "RRN",
  "Card No. / Customer No.",
  "Name",
  "Total Bill",
  "Remaining Bill",
  "Beneficiary Account",
  "Beneficiary Name",
  "Beneficiary Bank",
  "Beneficiary Account No.",
  "Save to Beneficiary List",
  "BCA Virtual Account No.",
  "Company/Product Name",
  "Pay Amount",
  "Admin Fee",
  "Bill Total",
  "Transfer Amount",
  "Total Payment",
  "Amount",
  "Fee",
  "Transfer Method",
  "Transaction Purpose",
  "Remarks",
  "Description",
  "Reference No.",
]);

function field(lines: string[], label: string): string | null {
  return findFieldIn(lines, label, KNOWN_LABELS);
}

/**
 * Parses a myBCA rupiah amount: "IDR 102,000.00" -> 102000.
 *
 * Commas are thousands separators and the dot is the decimal separator. The
 * shape is validated rather than digits being scraped out, because a label that
 * leaked through (e.g. "TAGIHAN AIR") must fail loudly instead of parsing as
 * some arbitrary number.
 *
 * Rounded to whole rupiah: IDR is seeded with 0 decimal places
 * (20260509000015_seed_currencies.sql) and the app stores integer minor units
 * scaled by that (20260606000001_drop_currency_columns.sql).
 */
export function parseMyBcaAmount(raw: string): number {
  const trimmed = (raw ?? "").trim();
  const match = trimmed.match(/^(?:IDR|Rp)?\s*(\d{1,3}(?:,\d{3})*|\d+)(?:\.(\d{1,2}))?$/i);

  if (!match) {
    throw new BankEmailParseError(`Unrecognised amount format: "${raw}"`);
  }

  const value = Number(`${match[1].replace(/,/g, "")}.${match[2] ?? "0"}`);

  if (!Number.isFinite(value)) {
    throw new BankEmailParseError(`Unparseable amount: "${raw}"`);
  }

  return Math.round(value);
}

const MONTHS: Record<string, string> = {
  // English, as sent today.
  jan: "01", feb: "02", mar: "03", apr: "04", may: "05", jun: "06",
  jul: "07", aug: "08", sep: "09", oct: "10", nov: "11", dec: "12",
  // Indonesian, in case the account's language preference is switched.
  mei: "05", agu: "08", agt: "08", okt: "10", des: "12",
};

/**
 * Parses "12 Sep 2026 13:14:50" -> "2026-09-12".
 *
 * Note this is NOT the credit card template's "25-07-2026 07:49:41 WIB".
 *
 * The date is taken verbatim from the bank's local (WIB) clock and never
 * converted through UTC. `transactions.date` is a plain DATE, and a payment at
 * 00:30 WIB is 17:30 UTC on the *previous* day -- converting would file it in
 * the wrong month at month boundaries. Three of the 40 sample emails are
 * timestamped between 01:19 and 03:58, so this is a live concern, not a
 * theoretical one.
 */
export function parseMyBcaDate(raw: string): string {
  const match = (raw ?? "").match(/(\d{1,2})\s+([A-Za-z]{3,})\s+(\d{4})/);
  if (!match) {
    throw new BankEmailParseError(`Unrecognised date format: "${raw}"`);
  }

  const [, day, monthName, year] = match;
  const mm = MONTHS[monthName.slice(0, 3).toLowerCase()];
  if (!mm) {
    throw new BankEmailParseError(`Unknown month "${monthName}" in "${raw}"`);
  }

  const dayNum = Number(day);
  if (dayNum < 1 || dayNum > 31) {
    throw new BankEmailParseError(`Date out of range: "${raw}"`);
  }

  return `${year}-${mm}-${day.padStart(2, "0")}`;
}

/** Whether this email is a myBCA Internet Transaction Journal. */
export function isInternetTransactionJournal(subject: string): boolean {
  return /internet\s+transaction\s+journal/i.test(subject ?? "");
}

/**
 * Resolves the amount actually debited from the account.
 *
 * Order matters, and the fee handling differs per layout:
 *
 *   "Total Payment" already INCLUDES any fee -- format 5 shows
 *   Pay Amount 500,000 + Admin Fee 1,000 = Total Payment 501,000 -- so adding
 *   the fee again would overstate the debit. It is therefore checked first and
 *   used alone.
 *
 *   The interbank layouts (7/8) have no total at all, so there the fee must be
 *   added: Amount 8,000,000 + Fee 2,500 = 8,002,500 leaves the account.
 */
function resolveAmount(lines: string[]): { amount: number; raw: string; source: string } {
  const total = field(lines, "Total Payment");
  if (total) {
    return { amount: parseMyBcaAmount(total), raw: total, source: "Total Payment" };
  }

  for (const label of ["Transfer Amount", "Amount"]) {
    const base = field(lines, label);
    if (!base) continue;

    let amount = parseMyBcaAmount(base);
    let source = label;

    const fee = field(lines, "Fee");
    if (fee) {
      amount += parseMyBcaAmount(fee);
      source = `${label} + Fee`;
    }

    return { amount, raw: base, source };
  }

  throw new BankEmailParseError(
    "No amount row found (looked for Total Payment, Transfer Amount, Amount). " +
      "The email template may have changed.",
  );
}

/**
 * Resolves the counterparty used as the transaction description.
 *
 * "Name" is deliberately NOT in this list. On the credit card payment layout it
 * is the masked cardholder ("***IAN **EDY") and on the virtual account layout
 * it is the masked customer ("Dxxxxx Txxxx") -- both useless as a description,
 * and both layouts carry a better field or fall through to the transaction type.
 */
function resolveMerchant(lines: string[]): string {
  const candidates = [
    "Payment to", // QRIS merchant
    "Beneficiary Name", // intra-BCA and interbank transfers
    "Company/Product Name", // virtual account billers
    "Transaction Type", // credit card payment: "Credit Card & Paylater - BCA"
    "Transfer Type",
  ];

  for (const label of candidates) {
    const value = field(lines, label);
    if (value) return value;
  }

  throw new BankEmailParseError(
    "No description row found (looked for Payment to, Beneficiary Name, " +
      "Company/Product Name, Transaction Type). The email template may have changed.",
  );
}

/**
 * Whether the journal settles a BCA credit card bill (layout 2).
 *
 * Two signals are required, because acting on this reroutes the money to a
 * different account and a false positive is worse than a miss:
 *
 *   - the transaction type names a credit card ("Credit Card & Paylater - BCA")
 *   - the layout carries "Card No. / Customer No.", which only that layout has
 *
 * A miss is safe: the caller falls back to booking an expense, and every
 * ingested transaction is pending for the user to review anyway.
 *
 * The transaction type is matched loosely rather than compared to the exact
 * observed string, so a renamed menu item does not silently turn these back
 * into expenses.
 */
function detectCreditCardPayment(lines: string[], transactionKind: string | null): boolean {
  return /credit\s*card/i.test(transactionKind ?? "") &&
    field(lines, "Card No. / Customer No.") !== null;
}

export function parseMyBcaEmail(htmlBody: string): ParsedMyBcaEmail {
  const lines = htmlToLines(htmlBody ?? "");

  const rawDateTime = field(lines, "Transaction Date");
  if (!rawDateTime) {
    throw new BankEmailParseError(
      'Missing field: "Transaction Date". The email template may have changed.',
    );
  }

  const { amount, raw, source } = resolveAmount(lines);
  if (amount <= 0) {
    // Zero would violate transactions_amount_check.
    throw new BankEmailParseError(`Amount must be positive, got ${amount} from "${raw}"`);
  }

  const transactionKind = field(lines, "Transaction Type") ??
    field(lines, "Transfer Type");

  return {
    kind: "mybca",
    transactionKind,
    merchant: resolveMerchant(lines),
    date: parseMyBcaDate(rawDateTime),
    rawDateTime,
    amount,
    rawAmount: raw,
    amountSource: source,
    status: field(lines, "Status"),
    settlesCreditCard: detectCreditCardPayment(lines, transactionKind),
  };
}

/**
 * Whether the journal describes a completed debit.
 *
 * All 40 sampled emails say "Successful", but myBCA also journals failed and
 * pending attempts under the same subject. Those move no money, so ingesting
 * them would create a pending transaction for a payment that never happened.
 */
export function isSuccessful(status: string | null): boolean {
  return /^success/i.test((status ?? "").trim());
}
