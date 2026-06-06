-- ============================================================
-- Migration: Drop the per-record `currency` column from all tables.
--
-- The app is now single-currency: currency is chosen once in Settings
-- (user_settings.default_currency) and every amount is formatted in that one
-- currency. The per-row `currency` column is therefore redundant. This removes
-- it from accounts, transactions, budgets, scheduled_transactions, and
-- fixed_expenses, and reworks the objects that depended on budgets.currency:
--   * budget identity drops to (user_id, name, year_month)
--   * v_budget_progress carry-over no longer chains on currency
--   * fn_generate_pending_transactions stops copying currency
--
-- Amounts are stored as integer minor units scaled by the *currency's* decimal
-- places. No values are converted here — the Settings currency must match the
-- currency the existing data was stored under, or display scaling will be off.
-- ============================================================

BEGIN;

-- 1. Drop the view that references budgets.currency (recreated below).
DROP VIEW IF EXISTS v_budget_progress;

-- 2. budgets: drop currency from the lineage identity, then the column.
ALTER TABLE budgets DROP CONSTRAINT IF EXISTS uq_budget_lineage;
DROP INDEX IF EXISTS idx_budgets_lineage;
ALTER TABLE budgets DROP COLUMN currency;
ALTER TABLE budgets ADD CONSTRAINT uq_budget_lineage UNIQUE (user_id, name, year_month);
CREATE INDEX IF NOT EXISTS idx_budgets_lineage ON budgets(user_id, name, year_month);

-- 3. Recreate the budget progress view (live, compounding carry-over) without
--    currency. Identity / chaining is now (user_id, name) along consecutive
--    months. Mirrors 20260604000001_restructure_budgets.sql minus currency.
CREATE VIEW v_budget_progress AS
WITH RECURSIVE spent AS (
  SELECT
    b.id AS budget_id,
    COALESCE(SUM(CASE WHEN t.type = 'income' THEN -t.amount ELSE t.amount END), 0)::BIGINT AS spent
  FROM budgets b
  LEFT JOIN transactions t
    ON t.budget_id = b.id AND t.status = 'confirmed'
  GROUP BY b.id
),
base AS (
  SELECT b.*, s.spent,
         to_char(to_date(b.year_month, 'YYYY-MM') - interval '1 month', 'YYYY-MM') AS prev_month
  FROM budgets b
  JOIN spent s ON s.budget_id = b.id
),
chain AS (
  -- Anchors: no same-lineage row in the immediately preceding month -> carry_in = 0
  SELECT b.id, b.user_id, b.name, b.year_month, b.periodic_amount, b.spent,
         0::BIGINT AS carry_in,
         b.periodic_amount - b.spent AS remaining
  FROM base b
  WHERE NOT EXISTS (
    SELECT 1 FROM base p
    WHERE p.user_id = b.user_id AND p.name = b.name
      AND p.year_month = b.prev_month
  )
  UNION ALL
  -- Recurse forward into the next consecutive month of the same lineage (compounding)
  SELECT n.id, n.user_id, n.name, n.year_month, n.periodic_amount, n.spent,
         c.remaining AS carry_in,
         n.periodic_amount + c.remaining - n.spent AS remaining
  FROM chain c
  JOIN base n
    ON n.user_id = c.user_id AND n.name = c.name
   AND n.year_month = to_char(to_date(c.year_month, 'YYYY-MM') + interval '1 month', 'YYYY-MM')
)
SELECT
  id AS budget_id,
  user_id,
  name AS budget_name,
  year_month,
  periodic_amount,
  carry_in AS carry_over_amount,
  periodic_amount + carry_in AS effective_amount,
  spent,
  periodic_amount + carry_in - spent AS remaining
FROM chain;

-- Views default to security_invoker = false, which bypasses RLS. Enforce the
-- caller's privileges so each user sees only their own rows (see
-- 20260605000001_views_security_invoker.sql).
ALTER VIEW v_budget_progress SET (security_invoker = true);

-- 4. Drop the column from the remaining tables. None of the other views
--    (v_account_current_balance, v_monthly_cashflow, v_spending_by_category) or
--    the balance triggers reference currency, so no further recreation needed.
ALTER TABLE accounts               DROP COLUMN currency;
ALTER TABLE transactions           DROP COLUMN currency;
ALTER TABLE scheduled_transactions DROP COLUMN currency;
ALTER TABLE fixed_expenses         DROP COLUMN currency;

-- 5. The pending-transaction generator copied scheduled_transactions.currency
--    into transactions. Recreate it without currency.
CREATE OR REPLACE FUNCTION fn_generate_pending_transactions()
RETURNS void AS $$
DECLARE
  sched RECORD;
  next_date DATE;
BEGIN
  FOR sched IN
    SELECT * FROM scheduled_transactions
    WHERE is_active = TRUE AND next_due_date <= CURRENT_DATE
  LOOP
    INSERT INTO transactions (
      user_id, account_id, type, status, amount,
      description, date, scheduled_txn_id
    ) VALUES (
      sched.user_id, sched.account_id, sched.type, 'pending',
      sched.amount, sched.description,
      sched.next_due_date, sched.id
    );

    next_date := sched.next_due_date + INTERVAL '1 month';
    UPDATE scheduled_transactions
    SET next_due_date = next_date, updated_at = now()
    WHERE id = sched.id;
  END LOOP;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

COMMIT;
