-- Add an optional free-text description (note) to budgets.
--
-- Mirrors transactions.description: a nullable TEXT column the user can use to
-- jot context for a budget (e.g. "Groceries + household", "trim in July").
-- v_budget_progress is recreated so the note flows through to every reader
-- (Budgets page, transaction budget picker) alongside the existing columns.

BEGIN;

ALTER TABLE budgets ADD COLUMN description TEXT;

-- Recreate the progress view to surface the new column. Body is unchanged from
-- 20260606000001_drop_currency_columns.sql except for selecting b.description.
DROP VIEW IF EXISTS v_budget_progress;

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
  SELECT b.id, b.user_id, b.name, b.description, b.year_month, b.periodic_amount, b.spent,
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
  SELECT n.id, n.user_id, n.name, n.description, n.year_month, n.periodic_amount, n.spent,
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
  description,
  year_month,
  periodic_amount,
  carry_in AS carry_over_amount,
  periodic_amount + carry_in AS effective_amount,
  spent,
  periodic_amount + carry_in - spent AS remaining
FROM chain;

-- Views default to security_invoker = false, which bypasses RLS. Enforce the
-- caller's privileges so each user sees only their own rows.
ALTER VIEW v_budget_progress SET (security_invoker = true);

COMMIT;
