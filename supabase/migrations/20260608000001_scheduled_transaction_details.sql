-- ============================================================
-- Migration: Scheduled transactions carry category, budget, and tags.
--
-- A scheduled transaction can now mirror the detail of a regular one:
--   * category_id  — single category, same as transactions.category_id
--   * budget_name  — a budget LINEAGE (by name), not a fixed budget row id.
--                    Budgets are month-scoped (identity = name + year_month),
--                    so a recurring schedule can't pin one row. We store the
--                    name and resolve it to the budget for the *due month* at
--                    generation time; if that month has no budget by that name
--                    the pending transaction is created with no budget linked.
--   * tags         — many-to-many via scheduled_transaction_tags, mirroring
--                    transaction_tags.
--
-- fn_generate_pending_transactions() is recreated to copy category, resolve the
-- budget by lineage, and copy the tag set onto each generated transaction.
-- ============================================================

BEGIN;

-- 1. Single category (mirrors transactions.category_id; null on category delete).
ALTER TABLE scheduled_transactions
  ADD COLUMN category_id UUID REFERENCES categories(id) ON DELETE SET NULL;

-- 2. Budget lineage name (resolved per due-month at generation; plain text so a
--    deleted/renamed month's budget doesn't break the schedule).
ALTER TABLE scheduled_transactions
  ADD COLUMN budget_name TEXT;

-- 3. Tags junction, mirroring transaction_tags.
CREATE TABLE scheduled_transaction_tags (
  scheduled_transaction_id UUID NOT NULL
    REFERENCES scheduled_transactions(id) ON DELETE CASCADE,
  tag_id UUID NOT NULL REFERENCES tags(id) ON DELETE CASCADE,
  PRIMARY KEY (scheduled_transaction_id, tag_id)
);

ALTER TABLE scheduled_transaction_tags ENABLE ROW LEVEL SECURITY;

-- Ownership derives through the parent schedule (mirror policy_owner_txn_tags;
-- USING also governs INSERT when WITH CHECK is omitted).
CREATE POLICY policy_owner_sched_txn_tags ON scheduled_transaction_tags FOR ALL
  USING (
    EXISTS (
      SELECT 1 FROM scheduled_transactions s
      WHERE s.id = scheduled_transaction_id AND s.user_id = auth.uid()
    )
  );

-- 4. Recreate the generator: copy category, resolve budget by lineage for the
--    due month, copy tags onto the generated transaction.
CREATE OR REPLACE FUNCTION fn_generate_pending_transactions()
RETURNS void AS $$
DECLARE
  sched RECORD;
  next_date DATE;
  new_txn_id UUID;
  resolved_budget_id UUID;
BEGIN
  FOR sched IN
    SELECT * FROM scheduled_transactions
    WHERE is_active = TRUE AND next_due_date <= CURRENT_DATE
  LOOP
    -- Resolve the budget for the due month by lineage name; NULL if none exists
    -- for that month (the transaction is still generated, just unlinked).
    resolved_budget_id := NULL;
    IF sched.budget_name IS NOT NULL THEN
      SELECT id INTO resolved_budget_id
      FROM budgets
      WHERE user_id = sched.user_id
        AND name = sched.budget_name
        AND year_month = to_char(sched.next_due_date, 'YYYY-MM')
      LIMIT 1;
    END IF;

    INSERT INTO transactions (
      user_id, account_id, type, status, amount,
      description, date, scheduled_txn_id, category_id, budget_id
    ) VALUES (
      sched.user_id, sched.account_id, sched.type, 'pending',
      sched.amount, sched.description,
      sched.next_due_date, sched.id, sched.category_id, resolved_budget_id
    )
    RETURNING id INTO new_txn_id;

    -- Copy the schedule's tags onto the generated transaction.
    INSERT INTO transaction_tags (transaction_id, tag_id)
    SELECT new_txn_id, stt.tag_id
    FROM scheduled_transaction_tags stt
    WHERE stt.scheduled_transaction_id = sched.id;

    next_date := sched.next_due_date + INTERVAL '1 month';
    UPDATE scheduled_transactions
    SET next_due_date = next_date, updated_at = now()
    WHERE id = sched.id;
  END LOOP;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

COMMIT;
