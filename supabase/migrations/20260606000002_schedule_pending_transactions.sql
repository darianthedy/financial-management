-- ============================================================
-- Migration: Schedule the pending-transaction generator via pg_cron.
--
-- fn_generate_pending_transactions() turns due `scheduled_transactions` into
-- `pending` transactions. It existed but was never wired to a schedule (only
-- the monthly-balance job was). Run it daily, in-database, instead of relying
-- on the HTTP edge function — same logic, no HTTP overhead.
--
-- cron.schedule() upserts by job name, so re-running this is safe (it replaces
-- the existing job rather than creating a duplicate). Requires pg_cron, which
-- is already enabled (see 20260510000001_monthly_balance_ledger.sql).
-- ============================================================

-- Schedule: 00:05 UTC every day.
SELECT cron.schedule(
  'generate-pending-transactions',
  '5 0 * * *',
  'SELECT fn_generate_pending_transactions()'
);
