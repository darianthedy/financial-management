/**
 * Run with:  node --test supabase/functions/ingest-bank-email/
 *
 * Node 24 strips TypeScript types natively, so no build step is needed. The
 * parser imports nothing, which is what keeps it testable outside Deno.
 *
 * The fixtures below reproduce the structure of two real BCA emails (a
 * purchase and a reversal) as observed from the actual messages: a nested
 * table of label / ":" / value rows, a text/plain part of just "-", and the
 * reversal template omitting the "Otentikasi" row that the purchase has.
 */

import test from "node:test";
import assert from "node:assert/strict";

import {
  BankEmailParseError,
  findField,
  htmlToLines,
  isReversal,
  parseBcaCreditCardEmail,
  parseIndonesianAmount,
  parseIndonesianDate,
} from "./parser.ts";

const SUBJECT_PURCHASE = "Credit Card Transaction Notification";
const SUBJECT_REVERSAL = "Credit Card Reversal/Void Transaction Notification";

function row(label: string, value: string): string {
  return `<tr><td style="padding:4px"><span>${label}</span></td>` +
    `<td>:</td><td><span>${value}</span></td></tr>`;
}

function bcaEmail(opts: {
  intro: string;
  merchant: string;
  dateTime: string;
  amount: string;
  otentikasi?: string;
}): string {
  return `<html><head><style>.x{color:red}</style></head><body>
    <table><tr><td>
      <img src="cid:header" alt="T - Notifikasi Transaksi Kartu Kredit"/>
      <p>Yth. Pemegang Kartu Kredit BCA,</p>
      <p>${opts.intro}</p>
      <table>
        ${row("Nomor Customer", "0000000000000000")}
        ${row("Nomor Kartu", "431657XXXX0000")}
        ${row("Merchant / ATM", opts.merchant)}
        ${row("Jenis Transaksi", "E-COMMERCE")}
        ${opts.otentikasi ? row("Otentikasi", opts.otentikasi) : ""}
        ${row("Pada Tanggal", opts.dateTime)}
        ${row("Sejumlah", opts.amount)}
      </table>
      <p>Selalu jaga keamanan fisik kartu dan data pribadi Anda&nbsp;seperti Nomor Kartu,
         Masa Berlaku Kartu, PIN, OTP, CVV/CVC, dll.</p>
      <p>Info lanjut hubungi BCA via aplikasi haloBCA atau telepon 1500888.</p>
    </td></tr></table>
  </body></html>`;
}

const PURCHASE_HTML = bcaEmail({
  intro: "Terima kasih telah bertransaksi menggunakan Kartu Kredit BCA:",
  merchant: "DANA QROFF * Bakmie Me",
  dateTime: "16-08-2026 12:50:51 WIB",
  amount: "Rp102.000,00",
  otentikasi: "TRANSAKSI TANPA OTP",
});

const REVERSAL_HTML = bcaEmail({
  intro: "Kami informasikan adanya transaksi reversal/void:",
  merchant: "M TIX",
  dateTime: "25-07-2026 07:49:41 WIB",
  amount: "Rp1.000,00",
});

// ---------------------------------------------------------------------------
// End-to-end, against both real templates
// ---------------------------------------------------------------------------

test("parses a purchase into a positive expense", () => {
  const parsed = parseBcaCreditCardEmail(SUBJECT_PURCHASE, PURCHASE_HTML);

  assert.equal(parsed.kind, "transaction");
  assert.equal(parsed.merchant, "DANA QROFF * Bakmie Me");
  assert.equal(parsed.amount, 102_000);
  assert.equal(parsed.date, "2026-08-16");
  assert.equal(parsed.transactionKind, "E-COMMERCE");
});

test("parses a reversal into a negative expense", () => {
  const parsed = parseBcaCreditCardEmail(SUBJECT_REVERSAL, REVERSAL_HTML);

  assert.equal(parsed.kind, "reversal");
  assert.equal(parsed.merchant, "M TIX");
  assert.equal(parsed.amount, -1_000);
  assert.equal(parsed.date, "2026-07-25");
});

test("the reversal template's missing Otentikasi row does not shift other fields", () => {
  // The purchase template has an Otentikasi row between Jenis Transaksi and
  // Pada Tanggal; the reversal template does not. A positional parser would
  // read the wrong values here.
  const parsed = parseBcaCreditCardEmail(SUBJECT_REVERSAL, REVERSAL_HTML);

  assert.equal(parsed.rawDateTime, "25-07-2026 07:49:41 WIB");
  assert.equal(parsed.rawAmount, "Rp1.000,00");
});

// ---------------------------------------------------------------------------
// Amounts
// ---------------------------------------------------------------------------

test("parses Indonesian thousand/decimal separators", () => {
  assert.equal(parseIndonesianAmount("Rp102.000,00"), 102_000);
  assert.equal(parseIndonesianAmount("Rp1.000,00"), 1_000);
  assert.equal(parseIndonesianAmount("Rp1.234.567,00"), 1_234_567);
  assert.equal(parseIndonesianAmount("Rp500,00"), 500);
});

test("does not misread a dot as a decimal point", () => {
  // The en-US reading of "Rp1.000,00" is 1.0 -- a silent 1000x understatement.
  assert.notEqual(parseIndonesianAmount("Rp1.000,00"), 1);
});

test("rejects amounts that would violate transactions_amount_check", () => {
  assert.throws(() => parseIndonesianAmount("Rp0,00"), BankEmailParseError);
  assert.throws(() => parseIndonesianAmount("Rp"), BankEmailParseError);
});

// ---------------------------------------------------------------------------
// Dates
// ---------------------------------------------------------------------------

test("reads dd-mm-yyyy, not mm-dd-yyyy", () => {
  // 08-07-2026 is 8 July, not 7 August.
  assert.equal(parseIndonesianDate("08-07-2026 10:00:00 WIB"), "2026-07-08");
});

test("keeps the bank's local date at day boundaries", () => {
  // 00:30 WIB is 17:30 UTC the previous day. Converting through UTC would file
  // this transaction in the previous month.
  assert.equal(parseIndonesianDate("01-09-2026 00:30:00 WIB"), "2026-09-01");
  assert.equal(parseIndonesianDate("31-12-2026 23:59:59 WIB"), "2026-12-31");
});

test("rejects an unparseable date rather than guessing", () => {
  assert.throws(() => parseIndonesianDate("2026/08/16"), BankEmailParseError);
  assert.throws(() => parseIndonesianDate("32-13-2026"), BankEmailParseError);
});

// ---------------------------------------------------------------------------
// HTML handling
// ---------------------------------------------------------------------------

test("does not glue adjacent table cells together", () => {
  const lines = htmlToLines("<td>Merchant / ATM</td><td>:</td><td>M TIX</td>");
  assert.deepEqual(lines, ["Merchant / ATM", ":", "M TIX"]);
});

test("decodes entities in merchant names", () => {
  const html = bcaEmail({
    intro: "Terima kasih",
    merchant: "TOKO A &amp; B",
    dateTime: "16-08-2026 12:50:51 WIB",
    amount: "Rp10.000,00",
  });
  assert.equal(parseBcaCreditCardEmail(SUBJECT_PURCHASE, html).merchant, "TOKO A & B");
});

test("drops style and comment content", () => {
  const lines = htmlToLines(
    "<style>.a{color:red}</style><!-- hidden --><p>Sejumlah</p>",
  );
  assert.deepEqual(lines, ["Sejumlah"]);
});

test("returns null for an absent field instead of the next label's value", () => {
  const lines = htmlToLines(REVERSAL_HTML);
  assert.equal(findField(lines, "Otentikasi"), null);
  assert.equal(findField(lines, "Merchant / ATM"), "M TIX");
});

// ---------------------------------------------------------------------------
// Reversal detection
// ---------------------------------------------------------------------------

test("detects a reversal from the body when the subject is unhelpful", () => {
  assert.equal(isReversal("Notifikasi", htmlToLines(REVERSAL_HTML)), true);
  assert.equal(isReversal("Notifikasi", htmlToLines(PURCHASE_HTML)), false);
});

test("a purchase is never signed negative", () => {
  assert.ok(parseBcaCreditCardEmail(SUBJECT_PURCHASE, PURCHASE_HTML).amount > 0);
});

// ---------------------------------------------------------------------------
// Failure modes
// ---------------------------------------------------------------------------

test("throws when the template changes rather than inventing a transaction", () => {
  assert.throws(
    () => parseBcaCreditCardEmail(SUBJECT_PURCHASE, "<p>Something else entirely</p>"),
    BankEmailParseError,
  );
});

test("throws on the text/plain body BCA actually sends", () => {
  // getPlainBody() returns "-" for these emails; parsing it must fail loudly.
  assert.throws(
    () => parseBcaCreditCardEmail(SUBJECT_PURCHASE, "-"),
    BankEmailParseError,
  );
});
