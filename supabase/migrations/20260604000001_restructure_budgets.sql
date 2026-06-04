-- Restructure budgets: header + budget_periods  ->  flat, self-contained rows.
--
-- New model:
--   * Identity is (name + currency); one row per budget per month.
--   * Carry-over is ALWAYS ON and computed live in v_budget_progress (no stored
--     column, no per-budget toggle). It compounds along each (user_id, name,
--     currency) lineage and resets to 0 after any missing month.
--   * spent is net: linked expenses minus linked income.
--   * transactions link directly to a budget row via budget_id.
--
-- Delivered as a forward migration because the original schema is already deployed.
-- Assumes little/no production budget data; the data-migration block below is a
-- best effort for existing rows. If two distinct budgets share the same
-- (name, currency, year_month), the UNIQUE constraint in step 5 will fail and the
-- conflicting rows must be reconciled by hand.

BEGIN;

-- 0. Drop the old view first (it depends on budget_periods).
DROP VIEW IF EXISTS v_budget_progress;

-- 1. transactions: add the direct budget link.
ALTER TABLE transactions ADD COLUMN budget_id UUID REFERENCES budgets(id) ON DELETE SET NULL;

-- 2. budgets: add the period-specific columns (nullable for now so existing rows survive).
ALTER TABLE budgets ADD COLUMN year_month      TEXT;
ALTER TABLE budgets ADD COLUMN currency        TEXT NOT NULL DEFAULT 'USD' REFERENCES currencies(code);
ALTER TABLE budgets ADD COLUMN periodic_amount BIGINT;

-- 3. Migrate existing data:
--    Promote each budget_periods row into a flat budgets row, REUSING the period's
--    id as the new budget row id. Because transactions.budget_period_id already
--    points at that id, re-pointing is then a straight copy.
INSERT INTO budgets (id, user_id, name, year_month, currency, periodic_amount, created_at, updated_at)
SELECT bp.id, b.user_id, b.name, bp.year_month, bp.currency, bp.periodic_amount,
       bp.created_at, bp.updated_at
FROM budget_periods bp
JOIN budgets b ON b.id = bp.budget_id;

UPDATE transactions SET budget_id = budget_period_id WHERE budget_period_id IS NOT NULL;

-- Remove the obsolete header rows (no year_month). This cascades to their
-- budget_periods rows (ON DELETE CASCADE), which have already been copied above.
DELETE FROM budgets WHERE year_month IS NULL;

-- 4. Drop the obsolete header columns.
ALTER TABLE budgets DROP COLUMN IF EXISTS is_active;
ALTER TABLE budgets DROP COLUMN IF EXISTS enable_carry_over;

-- 5. Enforce the flat shape.
ALTER TABLE budgets ALTER COLUMN year_month      SET NOT NULL;
ALTER TABLE budgets ALTER COLUMN periodic_amount SET NOT NULL;
ALTER TABLE budgets ADD CONSTRAINT uq_budget_lineage UNIQUE (user_id, name, currency, year_month);
CREATE INDEX IF NOT EXISTS idx_budgets_lineage ON budgets(user_id, name, currency, year_month);

-- 6. Drop the old transactions FK column/index and the obsolete child table.
DROP INDEX IF EXISTS idx_txn_budget_per;
ALTER TABLE transactions DROP COLUMN IF EXISTS budget_period_id;
DROP POLICY IF EXISTS policy_owner_budget_periods ON budget_periods;
DROP TABLE IF EXISTS budget_periods;
CREATE INDEX idx_txn_budget ON transactions(budget_id);

-- 7. Realtime: budgets replaces budget_periods (the latter is removed with the table).
ALTER PUBLICATION supabase_realtime ADD TABLE budgets;

-- 8. Recreate the budget progress view with live, compounding carry-over.
--    effective = periodic + carry_in ; remaining = effective - spent ; remaining -> next month's carry_in.
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
  SELECT b.id, b.user_id, b.name, b.currency, b.year_month, b.periodic_amount, b.spent,
         0::BIGINT AS carry_in,
         b.periodic_amount - b.spent AS remaining
  FROM base b
  WHERE NOT EXISTS (
    SELECT 1 FROM base p
    WHERE p.user_id = b.user_id AND p.name = b.name
      AND p.currency = b.currency AND p.year_month = b.prev_month
  )
  UNION ALL
  -- Recurse forward into the next consecutive month of the same lineage (compounding)
  SELECT n.id, n.user_id, n.name, n.currency, n.year_month, n.periodic_amount, n.spent,
         c.remaining AS carry_in,
         n.periodic_amount + c.remaining - n.spent AS remaining
  FROM chain c
  JOIN base n
    ON n.user_id = c.user_id AND n.name = c.name AND n.currency = c.currency
   AND n.year_month = to_char(to_date(c.year_month, 'YYYY-MM') + interval '1 month', 'YYYY-MM')
)
SELECT
  id AS budget_id,
  user_id,
  name AS budget_name,
  currency,
  year_month,
  periodic_amount,
  carry_in AS carry_over_amount,
  periodic_amount + carry_in AS effective_amount,
  spent,
  periodic_amount + carry_in - spent AS remaining
FROM chain;

COMMIT;
