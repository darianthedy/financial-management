-- ============================================================
-- Migration: Merge fixed_expense_periods into fixed_expenses
--
-- OLD: fixed_expenses (header) + fixed_expense_periods (per-month rows)
--      transactions.fixed_expense_period_id → fixed_expense_periods.id
--
-- NEW: fixed_expenses (self-contained, one row per expense per month)
--      transactions.fixed_expense_id → fixed_expenses.id
-- ============================================================

BEGIN;

-- ============================================================
-- 1. Add new columns to fixed_expenses
-- ============================================================
ALTER TABLE fixed_expenses
  ADD COLUMN year_month TEXT,
  ADD COLUMN amount     BIGINT,
  ADD COLUMN currency   TEXT NOT NULL DEFAULT 'USD',
  ADD COLUMN due_day    SMALLINT;

-- ============================================================
-- 2. Migrate data: create one fixed_expenses row per period
--    The original fixed_expenses rows become "templates" — we
--    INSERT new rows from the periods and then delete the originals.
-- ============================================================

-- Insert a new fixed_expenses row for each fixed_expense_period,
-- inheriting user_id, name, is_active from the parent.
INSERT INTO fixed_expenses (user_id, name, year_month, amount, currency, due_day, is_active, created_at, updated_at)
SELECT
  fe.user_id,
  fe.name,
  fep.year_month,
  fep.amount,
  fep.currency,
  fep.due_day,
  fe.is_active,
  fep.created_at,
  fep.updated_at
FROM fixed_expense_periods fep
JOIN fixed_expenses fe ON fe.id = fep.fixed_expense_id;

-- ============================================================
-- 3. Add fixed_expense_id column to transactions (new FK)
-- ============================================================
ALTER TABLE transactions
  ADD COLUMN fixed_expense_id UUID;

-- ============================================================
-- 4. Populate transactions.fixed_expense_id from the old link
--    Map: old period → (fixed_expense_id, year_month) → new fixed_expenses row
-- ============================================================
UPDATE transactions t
SET fixed_expense_id = new_fe.id
FROM fixed_expense_periods fep
JOIN fixed_expenses old_fe ON old_fe.id = fep.fixed_expense_id
JOIN fixed_expenses new_fe
  ON new_fe.user_id   = old_fe.user_id
  AND new_fe.name      = old_fe.name
  AND new_fe.year_month = fep.year_month
  AND new_fe.amount IS NOT NULL  -- only match the newly inserted rows
WHERE t.fixed_expense_period_id = fep.id;

-- ============================================================
-- 5. Drop old FK column + index from transactions
-- ============================================================
DROP INDEX IF EXISTS idx_txn_fep;
ALTER TABLE transactions DROP COLUMN fixed_expense_period_id;

-- ============================================================
-- 6. Delete the original "header-only" fixed_expenses rows
--    (those with NULL year_month — they had no period data)
-- ============================================================
DELETE FROM fixed_expenses WHERE year_month IS NULL;

-- ============================================================
-- 7. Make new columns NOT NULL and add constraints
-- ============================================================
ALTER TABLE fixed_expenses
  ALTER COLUMN year_month SET NOT NULL,
  ALTER COLUMN amount     SET NOT NULL,
  ALTER COLUMN due_day    SET NOT NULL,
  ADD CONSTRAINT chk_due_day CHECK (due_day BETWEEN 1 AND 31);

-- ============================================================
-- 8. Add UNIQUE constraint and indexes
-- ============================================================
ALTER TABLE fixed_expenses
  ADD CONSTRAINT uq_fixed_expense_user_name_month UNIQUE (user_id, name, year_month);

CREATE INDEX IF NOT EXISTS idx_fixed_expenses_month ON fixed_expenses(year_month);

-- ============================================================
-- 9. Add FK from transactions.fixed_expense_id → fixed_expenses
-- ============================================================
ALTER TABLE transactions
  ADD CONSTRAINT fk_txn_fixed_expense
    FOREIGN KEY (fixed_expense_id) REFERENCES fixed_expenses(id) ON DELETE SET NULL;

CREATE INDEX idx_txn_fixed_exp ON transactions(fixed_expense_id)
  WHERE fixed_expense_id IS NOT NULL;

-- ============================================================
-- 10. Clean up: drop fixed_expense_periods and related objects
-- ============================================================

-- Remove from Realtime publication (may fail if not present — ignore)
DO $$ BEGIN
  ALTER PUBLICATION supabase_realtime DROP TABLE fixed_expense_periods;
EXCEPTION WHEN undefined_object THEN NULL;
END $$;

-- Add fixed_expenses to Realtime (may already be there — ignore)
DO $$ BEGIN
  ALTER PUBLICATION supabase_realtime ADD TABLE fixed_expenses;
EXCEPTION WHEN duplicate_object THEN NULL;
END $$;

-- Drop the trigger
DROP TRIGGER IF EXISTS trg_updated_at_fixed_expense_periods ON fixed_expense_periods;

-- Drop the RLS policy
DROP POLICY IF EXISTS policy_owner_fep ON fixed_expense_periods;

-- Drop the table (cascades FK, indexes)
DROP TABLE fixed_expense_periods;

COMMIT;
