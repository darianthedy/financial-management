/**
 * ingest-bank-email
 *
 * Receives BCA credit card notification emails from the Gmail Apps Script
 * (integrations/gmail-apps-script) and creates a matching PENDING transaction.
 *
 * Purchases become a positive expense; reversals/voids become a NEGATIVE
 * expense, per 20260612000001_allow_signed_amounts.sql -- the balance impact of
 * an expense is `-amount`, so a negative amount returns the money and reduces
 * budget/category totals without inflating income.
 *
 * Every transaction lands as `pending`, never `confirmed`: a parsed email is a
 * suggestion for the user to review in the app, not a verified ledger entry.
 */

import { createClient } from "https://esm.sh/@supabase/supabase-js@2";
import {
  BankEmailParseError,
  isTransactionNotification,
  parseBcaCreditCardEmail,
} from "./parser.ts";
import {
  isInternetTransactionJournal,
  isSuccessful,
  parseMyBcaEmail,
} from "./mybca.ts";

const supabaseUrl = Deno.env.get("SUPABASE_URL")!;
const serviceRoleKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!;
const ingestSecret = Deno.env.get("INGEST_SECRET") ?? "";

/**
 * Which account an email belongs to is decided by its template, because the two
 * templates come from different BCA products and therefore different accounts:
 *
 *   kartukreditbca@bca.co.id "... Transaction Notification"  -> BCA VISA card
 *   bca@bca.co.id "Internet Transaction Journal"             -> BCA debit
 *
 * Since BCA's 2026-09-22 sender move the two products share a domain, so the
 * subject is the only thing separating them -- which is what the routing below
 * already keyed on, and why that cutover needed no change here.
 *
 * Hardcoded on purpose: the card/account number in the email is masked
 * ("5271xxxx31") and deliberately ignored. Each is overridable by env var so
 * the account can be repointed without redeploying.
 */
const CREDIT_CARD_ACCOUNT_ID = Deno.env.get("INGEST_ACCOUNT_ID") ??
  "2f940480-5908-4c11-9fa1-9ff7a58c65c9";
const MYBCA_ACCOUNT_ID = Deno.env.get("INGEST_MYBCA_ACCOUNT_ID") ??
  "bfc92cd3-0eb3-497d-a7c2-7e7eb669e2ae";

function json(body: unknown, status: number): Response {
  return new Response(JSON.stringify(body), {
    status,
    headers: { "Content-Type": "application/json" },
  });
}

/** Constant-time comparison so a wrong secret cannot be recovered by timing. */
function secretMatches(provided: string, expected: string): boolean {
  if (expected.length === 0) return false;
  const a = new TextEncoder().encode(provided);
  const b = new TextEncoder().encode(expected);
  let diff = a.length ^ b.length;
  for (let i = 0; i < Math.max(a.length, b.length); i++) {
    diff |= (a[i] ?? 0) ^ (b[i] ?? 0);
  }
  return diff === 0;
}

Deno.serve(async (req: Request) => {
  if (req.method !== "POST") {
    return json({ error: "Method not allowed" }, 405);
  }

  if (!secretMatches(req.headers.get("X-Ingest-Secret") ?? "", ingestSecret)) {
    return json({ error: "Unauthorized" }, 401);
  }

  let payload: Record<string, unknown>;
  try {
    payload = await req.json();
  } catch {
    return json({ error: "Body is not valid JSON" }, 400);
  }

  const gmailMessageId = typeof payload.messageId === "string" ? payload.messageId : "";
  const subject = typeof payload.subject === "string" ? payload.subject : "";
  const htmlBody = typeof payload.htmlBody === "string" ? payload.htmlBody : "";
  const receivedAt = typeof payload.receivedAt === "string" ? payload.receivedAt : null;

  if (!gmailMessageId) {
    return json({ error: "messageId is required" }, 400);
  }

  const supabase = createClient(supabaseUrl, serviceRoleKey);

  // -- Claim the message -----------------------------------------------------
  // The insert is the idempotency gate: the Gmail message id is the primary
  // key, so a concurrent or retried delivery loses the race and is reported as
  // a duplicate rather than creating a second transaction.
  const { error: claimError } = await supabase
    .from("bank_email_ingests")
    .insert({
      gmail_message_id: gmailMessageId,
      status: "processing",
      subject,
      received_at: receivedAt,
    });

  if (claimError) {
    if (claimError.code !== "23505") {
      return json({ error: `Could not claim message: ${claimError.message}` }, 500);
    }

    // Already seen. Succeeded rows are final; a previously failed row is
    // allowed through again so a parser fix can reprocess the email.
    const { data: existing } = await supabase
      .from("bank_email_ingests")
      .select("status, transaction_id")
      .eq("gmail_message_id", gmailMessageId)
      .single();

    if (existing?.status === "succeeded") {
      return json({
        duplicate: true,
        transactionId: existing.transaction_id,
      }, 200);
    }
  }

  const fail = async (message: string, status: number) => {
    await supabase
      .from("bank_email_ingests")
      .update({ status: "failed", error: message })
      .eq("gmail_message_id", gmailMessageId);
    return json({ error: message }, status);
  };

  const ignore = async (reason: string) => {
    await supabase
      .from("bank_email_ingests")
      .update({ status: "ignored", error: null })
      .eq("gmail_message_id", gmailMessageId);
    return json({ ignored: true, reason }, 200);
  };

  // -- Ignore non-transaction mail from the same senders ----------------------
  // Statements, payment confirmations and promos carry no transaction table.
  // They are recorded and acknowledged with 200 so the Apps Script stops
  // retrying them, but they are NOT treated as parse failures.
  const isCreditCard = isTransactionNotification(subject);
  const isMyBca = isInternetTransactionJournal(subject);

  if (!isCreditCard && !isMyBca) {
    return await ignore("Not a recognised transaction email");
  }

  // -- Parse -----------------------------------------------------------------
  // The two templates share nothing but the label/":"/value shape: the myBCA
  // journal uses "IDR 102,000.00" where the card alert uses "Rp102.000,00", so
  // they must go through their own parsers or amounts land 1000x off.
  let parsed;
  let accountId: string;
  // Set only for a credit card bill payment: money moving between two accounts
  // the user owns, which is a transfer rather than an expense. See below.
  let transferAccountId: string | null = null;
  try {
    if (isCreditCard) {
      parsed = parseBcaCreditCardEmail(subject, htmlBody);
      accountId = CREDIT_CARD_ACCOUNT_ID;
    } else {
      const journal = parseMyBcaEmail(htmlBody);
      // myBCA journals failed and pending attempts under the same subject.
      // Those moved no money, so they must not become a pending transaction.
      if (!isSuccessful(journal.status)) {
        return await ignore(`Transaction status is "${journal.status ?? "unknown"}"`);
      }
      parsed = journal;
      accountId = MYBCA_ACCOUNT_ID;

      // Paying the BCA card bill from the BCA debit account moves money between
      // two accounts we already track, so it is booked as a transfer out of the
      // debit account and into the card account. As an expense it would
      // double-count: the card's own purchase alerts are ingested as expenses,
      // so the bill payment would charge that spending to the budget again.
      //
      // Guarded on the two ids differing: if both env vars point at the same
      // account the balance trigger would apply -amount and +amount to it and
      // net to zero, silently losing the transaction. Falling back to an
      // expense keeps it visible for review.
      if (journal.settlesCreditCard && CREDIT_CARD_ACCOUNT_ID !== MYBCA_ACCOUNT_ID) {
        transferAccountId = CREDIT_CARD_ACCOUNT_ID;
      }
    }
  } catch (err) {
    const message = err instanceof BankEmailParseError
      ? err.message
      : `Unexpected parse failure: ${err}`;
    // 422, not 500: retrying an email we cannot parse will never succeed, and
    // the Apps Script gives up after MAX_ATTEMPTS and labels it for review.
    return await fail(message, 422);
  }

  // -- Resolve the owning user from the account -----------------------------
  const { data: account, error: accountError } = await supabase
    .from("accounts")
    .select("id, user_id")
    .eq("id", accountId)
    .single();

  if (accountError || !account) {
    return await fail(`Account ${accountId} not found: ${accountError?.message}`, 500);
  }

  // -- Create the pending transaction ---------------------------------------
  // chk_transfer_account requires transfer_account_id to be set for a transfer
  // and NULL for anything else, so the two cases are built together.
  const isTransfer = transferAccountId !== null;
  const { data: transaction, error: insertError } = await supabase
    .from("transactions")
    .insert({
      user_id: account.user_id,
      account_id: account.id,
      type: isTransfer ? "transfer" : "expense",
      transfer_account_id: transferAccountId,
      status: "pending",
      amount: parsed.amount,
      description: parsed.merchant,
      date: parsed.date,
    })
    .select("id")
    .single();

  if (insertError) {
    return await fail(`Could not create transaction: ${insertError.message}`, 500);
  }

  await supabase
    .from("bank_email_ingests")
    .update({
      status: "succeeded",
      transaction_id: transaction.id,
      user_id: account.user_id,
      parsed,
      error: null,
    })
    .eq("gmail_message_id", gmailMessageId);

  return json({
    created: true,
    transactionId: transaction.id,
    kind: parsed.kind,
    type: isTransfer ? "transfer" : "expense",
    accountId: account.id,
    transferAccountId,
    amount: parsed.amount,
    date: parsed.date,
    description: parsed.merchant,
  }, 201);
});
