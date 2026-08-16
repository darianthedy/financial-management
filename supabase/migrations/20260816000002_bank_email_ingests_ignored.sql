-- ============================================================
-- Migration: add an 'ignored' status to bank_email_ingests.
--
-- KartuKreditBCA@klikbca.com sends more than transaction alerts: statements,
-- payment confirmations and promos come from the same address. Those carry no
-- transaction table, so the parser reported them as failures — noise that
-- looks identical to a genuine template change.
--
-- They are now recorded as 'ignored' and acknowledged with 200, which stops
-- the Apps Script retrying them while keeping 'failed' meaningful: a 'failed'
-- row now always means an email that SHOULD have parsed and did not.
-- ============================================================

BEGIN;

ALTER TABLE bank_email_ingests
  DROP CONSTRAINT IF EXISTS bank_email_ingests_status_check;

ALTER TABLE bank_email_ingests
  ADD CONSTRAINT bank_email_ingests_status_check
  CHECK (status IN ('processing', 'succeeded', 'failed', 'ignored'));

COMMIT;
