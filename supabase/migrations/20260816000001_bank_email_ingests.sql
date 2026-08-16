-- ============================================================
-- Migration: bank email ingest log.
--
-- Backs the `ingest-bank-email` edge function, which turns BCA credit card
-- notification emails into pending transactions.
--
-- Its job is idempotency. The Gmail message id is the primary key, so a
-- re-delivered email (Apps Script retry after an ambiguous failure, a manual
-- re-run, a restored mailbox) cannot create a second transaction for the same
-- notification.
--
-- Rows are also a debugging trail: `parsed` keeps the fields the parser
-- extracted and `error` keeps why it gave up, so a template change by the bank
-- can be diagnosed from the table rather than from Apps Script logs.
--
-- `status` allows retrying a failed parse: only 'succeeded' rows are treated as
-- duplicates, so a fixed parser can reprocess an email that previously failed.
-- ============================================================

BEGIN;

CREATE TABLE bank_email_ingests (
  gmail_message_id TEXT PRIMARY KEY,
  user_id          UUID REFERENCES auth.users(id) ON DELETE CASCADE,
  transaction_id   UUID REFERENCES transactions(id) ON DELETE SET NULL,
  status           TEXT NOT NULL DEFAULT 'processing'
                     CHECK (status IN ('processing', 'succeeded', 'failed')),
  subject          TEXT,
  received_at      TIMESTAMPTZ,
  parsed           JSONB,
  error            TEXT,
  created_at       TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at       TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE INDEX idx_bank_email_ingests_txn    ON bank_email_ingests(transaction_id);
CREATE INDEX idx_bank_email_ingests_status ON bank_email_ingests(status);
CREATE INDEX idx_bank_email_ingests_user   ON bank_email_ingests(user_id);

CREATE TRIGGER trg_updated_at_bank_email_ingests
  BEFORE UPDATE ON bank_email_ingests
  FOR EACH ROW EXECUTE FUNCTION fn_set_updated_at();

-- The edge function uses the service role key, which bypasses RLS. These
-- policies exist so the row is readable from the app under the user's own JWT
-- (e.g. to show "imported from email" provenance on a transaction).
ALTER TABLE bank_email_ingests ENABLE ROW LEVEL SECURITY;

CREATE POLICY policy_owner_bank_email_ingests ON bank_email_ingests FOR ALL
  USING (user_id = auth.uid())
  WITH CHECK (user_id = auth.uid());

COMMIT;
