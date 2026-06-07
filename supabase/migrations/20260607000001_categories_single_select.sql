-- ============================================================
-- Migration: Categories become single-select.
--
-- A transaction now carries at most one category via transactions.category_id,
-- replacing the many-to-many transaction_categories junction. This makes
-- v_spending_by_category a true partition of expenses: each expense counts
-- toward exactly one slice, so the slices sum to total spending (the junction
-- previously double-counted any transaction with more than one category).
--
-- Backfill picks one category per transaction (earliest by category created_at,
-- tie-broken by id). All existing transactions have at most one category, so no
-- data is lost in practice.
--
-- transaction_categories is not in the supabase_realtime publication, so the
-- table can be dropped without touching the publication. Tags are unchanged
-- (transaction_tags stays many-to-many).
-- ============================================================

BEGIN;

-- 1. Add the single-category column.
ALTER TABLE transactions
  ADD COLUMN category_id UUID REFERENCES categories(id) ON DELETE SET NULL;

-- 2. Backfill from the junction (one category per transaction).
UPDATE transactions t
SET category_id = sub.category_id
FROM (
  SELECT DISTINCT ON (tc.transaction_id)
    tc.transaction_id, tc.category_id
  FROM transaction_categories tc
  JOIN categories c ON c.id = tc.category_id
  ORDER BY tc.transaction_id, c.created_at, c.id
) sub
WHERE sub.transaction_id = t.id;

CREATE INDEX idx_txn_category ON transactions(category_id);

-- 3. Drop the old view first: it still references transaction_categories, so the
--    table cannot be dropped while it exists. Recreated in step 5.
DROP VIEW IF EXISTS v_spending_by_category;

-- 4. Drop the junction table (its RLS policy drops with it).
DROP POLICY IF EXISTS policy_owner_txn_categories ON transaction_categories;
DROP TABLE IF EXISTS transaction_categories;

-- 5. Recreate v_spending_by_category to read the column directly.
CREATE VIEW v_spending_by_category AS
SELECT
  t.user_id,
  to_char(t.date, 'YYYY-MM') AS year_month,
  c.id   AS category_id,
  c.name AS category_name,
  c.icon,
  c.color,
  SUM(t.amount) AS total_amount
FROM transactions t
JOIN categories c ON c.id = t.category_id
WHERE t.type = 'expense' AND t.status = 'confirmed'
GROUP BY t.user_id, to_char(t.date, 'YYYY-MM'), c.id, c.name, c.icon, c.color;

-- Views default to security_invoker = false (bypasses RLS); enforce caller
-- privileges so each user sees only their own rows (see
-- 20260605000001_views_security_invoker.sql).
ALTER VIEW v_spending_by_category SET (security_invoker = true);

COMMIT;
