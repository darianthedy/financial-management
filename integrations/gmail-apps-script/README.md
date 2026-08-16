# Gmail bank-email ingest (Apps Script)

Polls Gmail every few minutes for bank notification emails and POSTs them to the
`ingest-bank-email` Supabase edge function, which parses them and creates a
pending transaction.

## Design

The script is **transport only** — it does not parse amounts or merchants.
Bank email templates change without warning, and shipping a new edge function is
much easier than editing and re-authorising an Apps Script project. Everything
bank-specific lives server side.

What it does handle:

- **De-duplication**, keyed on the Gmail message id, stored in Script
  Properties. It is deliberately *not* keyed on a Gmail label: labels in Gmail
  apply to an entire thread, and banks reply into an existing notification
  thread, so a `-label:fm-ingested` search filter would permanently hide every
  alert after the first one in that thread. The message id also goes in the
  payload so the endpoint can enforce idempotency independently.
- **Retry** — a failed POST records an attempt count and is retried on the next
  tick. After `MAX_ATTEMPTS` it is marked failed and left alone. `LOOKBACK_DAYS`
  bounds the retry window regardless.
- **Per-message, not per-thread** — a thread's messages are each considered
  separately.
- **Overlap protection** — `LockService` prevents two runs POSTing the same
  in-flight message.
- **State pruning** — entries older than twice the lookback window are deleted
  each run, so Script Properties never approaches its 500KB limit.

The `fm-ingested` / `fm-ingest-failed` labels are still applied, but purely so
outcomes are visible in the Gmail UI. Nothing depends on them.

## Setup

1. Create the script project:
   - <https://script.google.com> → **New project**, or
   - `npm i -g @google/clasp && clasp login && clasp create --type standalone`
     then `cp .clasp.json.example .clasp.json`, fill in the script id, and
     `clasp push`.
2. Paste `Code.gs` and `appsscript.json` in if you did it by hand
   (**Project Settings → Show `appsscript.json`** to edit the manifest).
3. **Project Settings → Script Properties**, add:

   | Property | Required | Example |
   | --- | --- | --- |
   | `INGEST_URL` | yes | `https://<ref>.supabase.co/functions/v1/ingest-bank-email` |
   | `INGEST_SECRET` | yes | long random string, also set on the edge function |
   | `SENDER_QUERY` | no | `from:(noreply@bca.co.id)` |
   | `LOOKBACK_DAYS` | no | `3` |
   | `TRIGGER_MINUTES` | no | `5` |
   | `MAX_ATTEMPTS` | no | `3` |

   Generate the secret with `openssl rand -hex 32`. Never commit it — this file
   is in git, Script Properties are not.
4. Run `dryRun` from the editor and approve the OAuth consent screen. It logs
   the query and the exact payloads without sending or labelling anything. Fix
   `SENDER_QUERY` until it matches only your bank's alerts.
5. Run `sendMostRecentForTesting` once the endpoint is deployed to verify auth
   and parsing end to end.
6. Run `installTrigger` to start the schedule. `removeTrigger` stops it.

The consent screen will warn the app is unverified — that is expected for a
personal standalone script; choose **Advanced → Go to \<project\> (unsafe)**.

## Payload

```json
{
  "source": "gmail-apps-script",
  "version": 1,
  "messageId": "18f2a1c0d9e8b7a6",
  "threadId": "18f2a1c0d9e8b7a6",
  "from": "BCA <noreply@bca.co.id>",
  "to": "you@gmail.com",
  "subject": "Notifikasi Transaksi",
  "receivedAt": "2026-08-16T03:14:07.000Z",
  "bodyTruncated": false,
  "body": "..."
}
```

Authenticated with an `X-Ingest-Secret` header. If you later want replay
protection, swap it for an HMAC over the body using
`Utilities.computeHmacSha256Signature` plus the `receivedAt` timestamp.

## Operating notes

- Minimum trigger interval is 1 minute; 5 is plenty for pending transactions and
  keeps you far from the Apps Script daily quota.
- Failures are visible three ways: the `fm-ingest-failed` label in Gmail,
  **Executions** in the Apps Script editor, and Google's automatic failure email.
- To reprocess emails, run `resetState` (clears message state, keeps config).
  The endpoint will still reject them as duplicates unless you also clear its
  own record — that is the backstop working as intended.
- Changing `SENDER_QUERY` does not retroactively pick up old mail beyond
  `LOOKBACK_DAYS`. Backfill by widening `LOOKBACK_DAYS` for one run.
