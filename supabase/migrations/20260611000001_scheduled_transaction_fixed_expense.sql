-- ============================================================
-- Migration: Scheduled transactions can link a fixed expense.
--
-- Like budgets, fixed expenses are month-scoped rows (identity = name +
-- year_month), so a recurring schedule can't pin one row. We store the
--   * fixed_expense_name — a fixed-expense LINEAGE (by name), not a row id —
--     and resolve it to the fixed expense for the *due month* at generation
--     time, mirroring budget_name. If that month has no fixed expense by that
--     name the pending transaction is created with none linked.
--
-- fn_generate_pending_transactions() is recreated to also resolve the fixed
-- expense by lineage and set transactions.fixed_expense_id on each generated row.
-- ============================================================

BEGIN;

-- Fixed-expense lineage name (resolved per due-month at generation; plain text so
-- a deleted/renamed month's fixed expense doesn't break the schedule).
ALTER TABLE scheduled_transactions
  ADD COLUMN fixed_expense_name TEXT;

-- Recreate the generator: also resolve the fixed expense by lineage for the due
-- month and link it on the generated transaction (mirrors budget resolution).
CREATE OR REPLACE FUNCTION fn_generate_pending_transactions()
RETURNS void AS $$
DECLARE
  sched RECORD;
  next_date DATE;
  new_txn_id UUID;
  resolved_budget_id UUID;
  resolved_fixed_expense_id UUID;
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

    -- Resolve the fixed expense for the due month by lineage name; NULL if none
    -- exists for that month (the transaction is still generated, just unlinked).
    resolved_fixed_expense_id := NULL;
    IF sched.fixed_expense_name IS NOT NULL THEN
      SELECT id INTO resolved_fixed_expense_id
      FROM fixed_expenses
      WHERE user_id = sched.user_id
        AND name = sched.fixed_expense_name
        AND year_month = to_char(sched.next_due_date, 'YYYY-MM')
      LIMIT 1;
    END IF;

    INSERT INTO transactions (
      user_id, account_id, type, status, amount,
      description, date, scheduled_txn_id, category_id, budget_id,
      fixed_expense_id
    ) VALUES (
      sched.user_id, sched.account_id, sched.type, 'pending',
      sched.amount, sched.description,
      sched.next_due_date, sched.id, sched.category_id, resolved_budget_id,
      resolved_fixed_expense_id
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
