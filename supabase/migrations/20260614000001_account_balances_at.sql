-- Bounded per-month account balances for the dashboard.
--
-- The dashboard needs each account's balance as of a selected month. Balances
-- live in account_monthly_balances and carry forward across empty months, so
-- "balance at month M" is the latest row at or before M. The web client used to
-- fetch every row with year_month <= M and collapse to one-per-account in JS,
-- which means the payload grows with history depth (accounts x months).
--
-- v_account_current_balance already does the right DISTINCT ON collapse but is
-- hard-wired to the latest row overall, so it can't answer for past months.
-- This function is the parameterized version: it returns at most one row per
-- account regardless of how far back M is, and the (account_id, year_month) PK
-- lets the DISTINCT ON run as an index scan.
--
-- SECURITY INVOKER so account_monthly_balances RLS (policy_owner_amb) applies
-- and each user sees only their own accounts -- same rationale as the views in
-- 20260605000001_views_security_invoker.sql.

CREATE OR REPLACE FUNCTION fn_account_balances_at(p_year_month TEXT)
RETURNS TABLE (account_id UUID, year_month TEXT, balance BIGINT)
LANGUAGE sql
STABLE
SECURITY INVOKER
SET search_path = public
AS $$
  SELECT DISTINCT ON (amb.account_id)
    amb.account_id, amb.year_month, amb.balance
  FROM account_monthly_balances amb
  WHERE amb.year_month <= p_year_month
  ORDER BY amb.account_id, amb.year_month DESC;
$$;
