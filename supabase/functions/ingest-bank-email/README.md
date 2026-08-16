# ingest-bank-email

Turns BCA credit card notification emails into pending transactions. Called by
the Gmail Apps Script in `integrations/gmail-apps-script`.

## Behaviour

- **Purchase** (`Credit Card Transaction Notification`) → positive `expense`.
- **Reversal/void** (`Credit Card Reversal/Void Transaction Notification`) →
  **negative** `expense`, per `20260612000001_allow_signed_amounts.sql`. The
  balance impact of an expense is `-amount`, so a negative amount returns the
  money and reduces budget/category totals without inflating income.
- Always `status = 'pending'`. A parsed email is a suggestion to review in the
  app, never a confirmed ledger entry.
- The account is **hardcoded** (`INGEST_ACCOUNT_ID`, defaulting to the BCA VISA
  card). The email's `Nomor Kartu` is deliberately ignored for now.
- `user_id` is resolved from the account, not sent by the caller.

## Idempotency

`bank_email_ingests.gmail_message_id` is the primary key, and the row is
inserted *before* the transaction. A retried or concurrent delivery loses that
insert and returns `200 {"duplicate": true}` instead of creating a second
transaction. Only `succeeded` rows are final — a row left in `failed` can be
reprocessed after a parser fix.

## Deploy

```sh
supabase secrets set INGEST_SECRET="$(openssl rand -hex 32)"
# Optional; defaults to the BCA VISA card account.
supabase secrets set INGEST_ACCOUNT_ID=2f940480-5908-4c11-9fa1-9ff7a58c65c9

supabase db push
supabase functions deploy ingest-bank-email
```

`verify_jwt = false` is set for this function in `supabase/config.toml`: Apps
Script has no Supabase session and cannot present a JWT, so the platform gate
would reject it before the handler runs. Authentication is the `X-Ingest-Secret`
header, compared in constant time. Use the same value in the Apps Script's
Script Properties.

## Tests

```sh
node --test supabase/functions/ingest-bank-email/parser.test.ts
```

Node 24 strips TypeScript natively, so no build step is needed. `parser.ts`
imports nothing, which is what keeps it runnable outside Deno.

Coverage worth knowing about: Indonesian number format (`Rp1.000,00` is 1000,
not 1.0), `dd-mm-yyyy` dates, WIB dates kept unconverted at day boundaries (a
00:30 WIB purchase is the previous day in UTC and would land in the wrong
month), and the reversal template omitting the `Otentikasi` row that the
purchase template has — which is why fields are matched by label rather than
position.

## Responses

- `201 {"created": true, ...}` — transaction created
- `200 {"duplicate": true, ...}` — already ingested
- `422` — could not parse; Apps Script retries then labels `fm-ingest-failed`
- `401` — bad or missing `X-Ingest-Secret`
