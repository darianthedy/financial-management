/**
 * Run with:  node --test supabase/functions/ingest-bank-email/
 *
 * Fixtures reproduce the structure of real myBCA "Internet Transaction Journal"
 * emails: a table of three <td> cells per row (label, ": ", value), with the
 * value cell left EMPTY for absent fields rather than the row being omitted.
 *
 * The expected values below were taken from a corpus of 40 real messages
 * spanning all eight observed layouts, and every case here reproduces a
 * property that corpus actually exhibits.
 */

import test from "node:test";
import assert from "node:assert/strict";

import { BankEmailParseError } from "./html.ts";
import {
  isInternetTransactionJournal,
  isSuccessful,
  parseMyBcaAmount,
  parseMyBcaDate,
  parseMyBcaEmail,
} from "./mybca.ts";

const SUBJECT = "Internet Transaction Journal";

function row(label: string, value: string): string {
  return `<tr>
    <td width="198" valign="top" style="font-size:14px;">${label}</td>
    <td width="2" valign="top" style="font-size:14px;">: </td>
    <td valign="top" style="font-size:14px;">${value}</td>
  </tr>`;
}

function journal(greeting: string, rows: Array<[string, string]>): string {
  return `<html><head><style>.x{color:red}</style></head><body>
    <table><tr><td>
      <p>${greeting} DARIAN THEDY,</p>
      <p>You just made a transaction through myBCA.</p>
      <p>Here are the details of your transaction :</p>
      <table>${rows.map(([l, v]) => row(l, v)).join("")}</table>
      <p>Please save this email as your transaction reference.</p>
    </td></tr></table>
  </body></html>`;
}

// --- Layout 1: QRIS payment ------------------------------------------------

const QRIS = journal("Hello", [
  ["Status", "Successful"],
  ["Transaction Date", "11 Sep 2026 08:50:59"],
  ["Transaction Type", "QRIS Payment"],
  ["Payment to", "Rompok donat"],
  ["Merchant Location", "Kab. Majaleng, 45454, ID"],
  ["Acquirer", "DANA"],
  ["Merchant PAN", "9360091530333641392"],
  ["Terminal ID", "033364139"],
  ["Source of Fund", "TAHAPAN - 5271****31"],
  ["Customer PAN", "9360001410141702232"],
  ["Total Payment", "IDR 10,000.00"],
  ["RRN", "305213065"],
  ["Reference No.", "9527120260911085057315QRS1140270027"],
]);

test("QRIS payment: merchant from 'Payment to', amount from 'Total Payment'", () => {
  const parsed = parseMyBcaEmail(QRIS);
  assert.equal(parsed.merchant, "Rompok donat");
  assert.equal(parsed.amount, 10000);
  assert.equal(parsed.date, "2026-09-11");
  assert.equal(parsed.transactionKind, "QRIS Payment");
  assert.equal(parsed.amountSource, "Total Payment");
  assert.ok(isSuccessful(parsed.status));
});

// --- Layout 3/4: intra-BCA transfer ----------------------------------------

function bcaTransfer(extraRows: Array<[string, string]> = []) {
  return journal("Hi", [
    ["Status", "Successful"],
    ["Transaction Date", "12 Sep 2026 13:14:50"],
    ["Transfer Type", "Transfer to BCA Account"],
    ["Source of Fund", "5271xxxx31"],
    ["Source Currency", "IDR - Indonesian Rupiah"],
    ["Beneficiary Account", "5410278164"],
    ["Transfer Currency", "IDR - Indonesian Rupiah"],
    ["Beneficiary Name", "NENG YULIANINGSIH HJ"],
    ...extraRows,
    ["Transfer Amount", "IDR 100,000.00"],
    ["Remarks", "-"],
    ["Reference No.", "AE5D887C-826B-4F1C-909D-0A028EB25638"],
  ]);
}

test("intra-BCA transfer: merchant from 'Beneficiary Name', no fee added", () => {
  const parsed = parseMyBcaEmail(bcaTransfer());
  assert.equal(parsed.merchant, "NENG YULIANINGSIH HJ");
  assert.equal(parsed.amount, 100000);
  assert.equal(parsed.date, "2026-09-12");
  assert.equal(parsed.amountSource, "Transfer Amount");
});

test("optional 'Save to Beneficiary List' row does not shift any field", () => {
  const withSave = parseMyBcaEmail(bcaTransfer([["Save to Beneficiary List", "No"]]));
  const without = parseMyBcaEmail(bcaTransfer());
  assert.deepEqual(withSave, without);
});

// --- Layout 5: virtual account, fee already folded into the total ----------

const VIRTUAL_ACCOUNT = journal("Hello", [
  ["Status", "Successful"],
  ["Transaction Date", "03 Sep 2026 01:19:48"],
  ["Transfer Type", "Transfer to BCA Virtual Account"],
  ["Source of Fund", "5271xxxx31"],
  ["BCA Virtual Account No.", "70001081286741751"],
  ["Name", "Dxxxxx Txxxx"],
  ["Company/Product Name", "PT DOMPET ANAK BANGSA / GO-PAY TOPUP"],
  ["Pay Amount", "IDR 500,000.00"],
  ["Admin Fee", "IDR 1,000.00"],
  ["Total Payment", "IDR 501,000.00"],
  // Real emails render this row with an EMPTY value cell.
  ["Description", ""],
  ["Reference No.", "0F380C0A-1111-2222-3333-444455556666"],
]);

test("virtual account: uses Total Payment, which already includes the admin fee", () => {
  const parsed = parseMyBcaEmail(VIRTUAL_ACCOUNT);
  // NOT 502,000 -- adding Admin Fee on top of Total Payment would double it.
  assert.equal(parsed.amount, 501000);
  assert.equal(parsed.amountSource, "Total Payment");
  // Prefers the biller over the masked customer name "Dxxxxx Txxxx".
  assert.equal(parsed.merchant, "PT DOMPET ANAK BANGSA / GO-PAY TOPUP");
});

test("an empty row does not absorb the next row's label as its value", () => {
  // "Description" is empty and sits directly above "Reference No."; a naive
  // scan reports the reference number as the description.
  const parsed = parseMyBcaEmail(VIRTUAL_ACCOUNT);
  assert.notEqual(parsed.merchant, "Reference No.");
  assert.equal(parsed.amount, 501000);
});

test("a 01:19 WIB transaction keeps its local date, not the UTC previous day", () => {
  const parsed = parseMyBcaEmail(VIRTUAL_ACCOUNT);
  assert.equal(parsed.date, "2026-09-03");
});

// --- Layout 7/8: interbank transfer, fee charged on top --------------------

const INTERBANK = journal("Hello", [
  ["Status", "Successful"],
  ["Transaction Date", "01 Aug 2026 18:02:03"],
  ["Transfer Type", "Transfer to SUPERBANK"],
  ["Source of Fund", "5271xxxx31"],
  ["Beneficiary Name", "DARIAN THEDY"],
  ["Beneficiary Bank", "SUPERBANK"],
  ["Beneficiary Account No.", "9001234567"],
  ["Amount", "IDR 8,000,000.00"],
  ["Fee", "IDR 2,500.00"],
  ["Transfer Method", "BI FAST"],
  ["Remarks", "-"],
  ["Transaction Purpose", "Investment"],
  ["Reference No.", "1122334455"],
]);

test("interbank transfer: fee is added because there is no total row", () => {
  const parsed = parseMyBcaEmail(INTERBANK);
  assert.equal(parsed.amount, 8002500);
  assert.equal(parsed.amountSource, "Amount + Fee");
  assert.equal(parsed.merchant, "DARIAN THEDY");
  assert.equal(parsed.date, "2026-08-01");
});

// --- Layout 2: credit card payment -----------------------------------------

const CARD_PAYMENT = journal("Hello", [
  ["Status", "Successful"],
  ["Transaction Date", "15 Aug 2026 09:19:41"],
  ["Transaction Type", "Credit Card & Paylater - BCA"],
  ["Source of Fund", "5271****31"],
  ["Card No. / Customer No.", "4316********0000"],
  ["Name", "***IAN **EDY"],
  ["Total Bill", "IDR 2,694,819.00"],
  ["Total Payment", "IDR 15,000,000.00"],
  ["Remaining Bill", "IDR 0.00"],
  ["Reference No.", "778899"],
]);

test("credit card payment: amount paid, not the bill; masked name is not used", () => {
  const parsed = parseMyBcaEmail(CARD_PAYMENT);
  // Total Payment (what left the account), not Total Bill (2,694,819).
  assert.equal(parsed.amount, 15000000);
  assert.equal(parsed.merchant, "Credit Card & Paylater - BCA");
  assert.notEqual(parsed.merchant, "***IAN **EDY");
});

test("credit card payment is flagged as settling a card, so it books as a transfer", () => {
  // Booking it as an expense would double-count: the card's own purchase
  // alerts are already ingested as expenses.
  assert.equal(parseMyBcaEmail(CARD_PAYMENT).settlesCreditCard, true);
});

test("a renamed credit card menu item is still detected", () => {
  const renamed = CARD_PAYMENT.replace(
    "Credit Card & Paylater - BCA",
    "BCA Credit Card Bill Payment",
  );
  assert.equal(parseMyBcaEmail(renamed).settlesCreditCard, true);
});

test("no other layout is mistaken for a credit card payment", () => {
  for (const [name, html] of Object.entries({ QRIS, VIRTUAL_ACCOUNT, INTERBANK })) {
    assert.equal(
      parseMyBcaEmail(html).settlesCreditCard,
      false,
      `${name} must not be booked as a transfer to the card account`,
    );
  }
  assert.equal(parseMyBcaEmail(bcaTransfer()).settlesCreditCard, false);
});

test("credit card detection needs both signals, not just the transaction type", () => {
  // A QRIS purchase AT a card-shaped merchant name must stay an expense: it
  // lacks the "Card No. / Customer No." row that only the payment layout has.
  const cardNamedMerchant = journal("Hello", [
    ["Status", "Successful"],
    ["Transaction Date", "11 Sep 2026 08:50:59"],
    ["Transaction Type", "QRIS Payment"],
    ["Payment to", "CREDIT CARD REPAIR SHOP"],
    ["Source of Fund", "TAHAPAN - 5271****31"],
    ["Total Payment", "IDR 10,000.00"],
    ["Reference No.", "X"],
  ]);
  assert.equal(parseMyBcaEmail(cardNamedMerchant).settlesCreditCard, false);
});

// --- Layout 6: itemised bill with merchant-supplied rows -------------------

test("merchant-supplied bill rows do not become the amount", () => {
  const itemised = journal("Hello", [
    ["Status", "Successful"],
    ["Transaction Date", "12 Aug 2026 11:32:23"],
    ["Transfer Type", "Transfer to BCA Virtual Account"],
    ["Source of Fund", "5271xxxx31"],
    ["BCA Virtual Account No.", "6673800500700826"],
    ["Name", "CLJ R MB1 019"],
    ["Company/Product Name", "GRIYA SUKAMANAH PERMAI PT / IPKL MODERNLAND"],
    ["TAGIHAN IPKL", "IDR 150,000.00"],
    ["TAGIHAN AIR", "IDR 40,303.00"],
    ["DENDA", "IDR 0.00"],
    ["BIAYA ADMIN", "IDR 2,000.00"],
    ["Bill Total", "IDR 192,303.00"],
    ["Total Payment", "IDR 192,303.00"],
    ["Remarks", "-"],
    ["Reference No.", "5566778899"],
  ]);

  const parsed = parseMyBcaEmail(itemised);
  assert.equal(parsed.amount, 192303);
  assert.equal(parsed.merchant, "GRIYA SUKAMANAH PERMAI PT / IPKL MODERNLAND");
});

// --- Amount format ----------------------------------------------------------

test("amounts are en-US formatted, the opposite of the credit card template", () => {
  assert.equal(parseMyBcaAmount("IDR 102,000.00"), 102000);
  assert.equal(parseMyBcaAmount("IDR 10,000,000.00"), 10000000);
  assert.equal(parseMyBcaAmount("IDR 18,315.00"), 18315);
  assert.equal(parseMyBcaAmount("IDR 0.00"), 0);
  assert.equal(parseMyBcaAmount("5,900"), 5900);
});

test("a non-currency value is rejected rather than scraped for digits", () => {
  // Guards the itemised layout: a leaked "TAGIHAN AIR" must not parse.
  for (const bad of ["TAGIHAN AIR", "Reference No.", "", "IDR", "-"]) {
    assert.throws(() => parseMyBcaAmount(bad), BankEmailParseError, `expected throw: ${bad}`);
  }
});

test("Indonesian thousand-dot format is rejected, not silently misread", () => {
  // "Rp102.000,00" is the credit card template. If it ever reached this parser,
  // reading it as 102.00 would understate the amount by 1000x, so it must throw.
  assert.throws(() => parseMyBcaAmount("Rp102.000,00"), BankEmailParseError);
});

// --- Dates ------------------------------------------------------------------

test("date parsing handles the 'DD Mon YYYY' format", () => {
  assert.equal(parseMyBcaDate("12 Sep 2026 13:14:50"), "2026-09-12");
  assert.equal(parseMyBcaDate("01 Jun 2026 01:35:52"), "2026-06-01");
  assert.equal(parseMyBcaDate("3 Jul 2026 12:49:32"), "2026-07-03");
});

test("date parsing accepts Indonesian month names", () => {
  assert.equal(parseMyBcaDate("06 Mei 2026 10:00:00"), "2026-05-06");
  assert.equal(parseMyBcaDate("06 Agu 2026 10:00:00"), "2026-08-06");
  assert.equal(parseMyBcaDate("06 Des 2026 10:00:00"), "2026-12-06");
});

test("an unrecognised date is rejected", () => {
  assert.throws(() => parseMyBcaDate("25-07-2026 07:49:41 WIB"), BankEmailParseError);
  assert.throws(() => parseMyBcaDate("12 Xyz 2026"), BankEmailParseError);
});

// --- Routing and status -----------------------------------------------------

test("subject routing", () => {
  assert.ok(isInternetTransactionJournal("Internet Transaction Journal"));
  assert.ok(isInternetTransactionJournal("  internet   transaction   journal  "));
  assert.equal(isInternetTransactionJournal("Credit Card Transaction Notification"), false);
  assert.equal(isInternetTransactionJournal(""), false);
});

test("only successful journals are ingested", () => {
  assert.ok(isSuccessful("Successful"));
  assert.equal(isSuccessful("Failed"), false);
  assert.equal(isSuccessful("Pending"), false);
  assert.equal(isSuccessful(null), false);
});

test("a failed transaction is parsed but flagged as not successful", () => {
  const failed = journal("Hi", [
    ["Status", "Failed"],
    ["Transaction Date", "12 Sep 2026 13:14:50"],
    ["Transfer Type", "Transfer to BCA Account"],
    ["Beneficiary Name", "NENG YULIANINGSIH HJ"],
    ["Transfer Amount", "IDR 100,000.00"],
    ["Reference No.", "X"],
  ]);
  assert.equal(isSuccessful(parseMyBcaEmail(failed).status), false);
});

// --- Failure modes ----------------------------------------------------------

test("a template with no amount row fails loudly", () => {
  const noAmount = journal("Hi", [
    ["Status", "Successful"],
    ["Transaction Date", "12 Sep 2026 13:14:50"],
    ["Transfer Type", "Transfer to BCA Account"],
    ["Beneficiary Name", "SOMEONE"],
    ["Reference No.", "X"],
  ]);
  assert.throws(() => parseMyBcaEmail(noAmount), BankEmailParseError);
});

test("a template with no date row fails loudly", () => {
  const noDate = journal("Hi", [
    ["Status", "Successful"],
    ["Transfer Type", "Transfer to BCA Account"],
    ["Beneficiary Name", "SOMEONE"],
    ["Transfer Amount", "IDR 100,000.00"],
  ]);
  assert.throws(() => parseMyBcaEmail(noDate), BankEmailParseError);
});

test("a zero-amount transaction is rejected (violates transactions_amount_check)", () => {
  const zero = journal("Hi", [
    ["Status", "Successful"],
    ["Transaction Date", "12 Sep 2026 13:14:50"],
    ["Transfer Type", "Transfer to BCA Account"],
    ["Beneficiary Name", "SOMEONE"],
    ["Transfer Amount", "IDR 0.00"],
  ]);
  assert.throws(() => parseMyBcaEmail(zero), BankEmailParseError);
});
