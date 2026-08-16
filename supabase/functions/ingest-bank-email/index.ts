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

const supabaseUrl = Deno.env.get("SUPABASE_URL")!;
const serviceRoleKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!;
const ingestSecret = Deno.env.get("INGEST_SECRET") ?? "";

/**
 * Every BCA credit card alert belongs to this account (the BCA VISA card).
 * Hardcoded on purpose for now: the email's "Nomor Kartu" is deliberately
 * ignored. Override with INGEST_ACCOUNT_ID without redeploying.
 */
const DEFAULT_ACCOUNT_ID = "2f940480-5908-4c11-9fa1-9ff7a58c65c9";
const accountId = Deno.env.get("INGEST_ACCOUNT_ID") ?? DEFAULT_ACCOUNT_ID;

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

  // -- Ignore non-transaction mail from the same sender ----------------------
  // Statements, payment confirmations and promos carry no transaction table.
  // They are recorded and acknowledged with 200 so the Apps Script stops
  // retrying them, but they are NOT treated as parse failures.
  if (!isTransactionNotification(subject)) {
    await supabase
      .from("bank_email_ingests")
      .update({ status: "ignored", error: null })
      .eq("gmail_message_id", gmailMessageId);

    return json({ ignored: true, reason: "Not a transaction notification" }, 200);
  }

  // -- Parse -----------------------------------------------------------------
  let parsed;
  try {
    parsed = parseBcaCreditCardEmail(subject, htmlBody);
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
  const { data: transaction, error: insertError } = await supabase
    .from("transactions")
    .insert({
      user_id: account.user_id,
      account_id: account.id,
      type: "expense",
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
    amount: parsed.amount,
    date: parsed.date,
    description: parsed.merchant,
  }, 201);
});
