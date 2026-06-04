-- ============================================================
-- MIGRATION: Recalculate balances when starting_balance changes
--
-- Editing an account's starting_balance previously had no effect on
-- the displayed current balance: the account_monthly_balances ledger
-- (and v_account_current_balance) is only recomputed by the
-- transaction trigger, and that cascade reads starting_balance only
-- for the earliest month. So a starting_balance edit was silently
-- ignored.
--
-- This migration adds an accounts trigger that recomputes the ledger
-- from the earliest month forward whenever starting_balance actually
-- changes. It reuses the self-healing fn_recalc_balances_from from
-- 20260604000001_fix_balance_row_seeding.sql, so apply that first.
-- ============================================================

BEGIN;

CREATE OR REPLACE FUNCTION fn_recalc_on_starting_balance_change()
RETURNS TRIGGER AS $$
DECLARE
  v_from TEXT;
BEGIN
  -- Recalc from the earliest month that has a balance row — the only
  -- month whose base figure is starting_balance. Fall back to the
  -- current month if the account has no rows yet.
  SELECT to_char(
    COALESCE(MIN(to_date(year_month, 'YYYY-MM')),
             date_trunc('month', CURRENT_DATE)::date),
    'YYYY-MM')
  INTO v_from
  FROM account_monthly_balances
  WHERE account_id = NEW.id;

  PERFORM fn_recalc_balances_from(NEW.id, v_from);
  RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

DROP TRIGGER IF EXISTS trg_recalc_on_starting_balance ON accounts;
CREATE TRIGGER trg_recalc_on_starting_balance
  AFTER UPDATE OF starting_balance ON accounts
  FOR EACH ROW
  WHEN (OLD.starting_balance IS DISTINCT FROM NEW.starting_balance)
  EXECUTE FUNCTION fn_recalc_on_starting_balance_change();

COMMIT;
