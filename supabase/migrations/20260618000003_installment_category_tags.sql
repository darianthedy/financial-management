-- ============================================================
-- MIGRATION: Carry category, fixed expense, and tags on new installments
--
-- create_budget_installment originally recorded the source expense as a bare
-- row (no category, no fixed-expense link, no tags) because the spread replaced
-- the single-budget link. That left new installments unable to categorise or
-- tag their expense, even though spreading an EXISTING expense (see
-- 20260618000002_spread_existing_transaction.sql) preserved those fields.
--
-- This widens the RPC to accept an optional category, fixed-expense link, and
-- tag set, persisting them on the source expense exactly like an ordinary
-- expense. Only the single `budget_id` stays NULL — the reservation grid takes
-- its place. The new params default to NULL, so older callers keep working.
--
-- See System Design §4.11, Supabase Tech Plan §3.10, and Web §7.8.
-- ============================================================

BEGIN;

-- Adding parameters changes the function's input signature, so the old 7-arg
-- version must be dropped before the widened one is created (CREATE OR REPLACE
-- alone would leave both as overloads and make PostgREST calls ambiguous).
DROP FUNCTION IF EXISTS create_budget_installment(UUID, BIGINT, DATE, TEXT, TEXT, SMALLINT, JSONB);

CREATE FUNCTION create_budget_installment(
  p_account_id       UUID,
  p_amount           BIGINT,
  p_date             DATE,
  p_description      TEXT,
  p_start_year_month TEXT,
  p_months           SMALLINT,
  p_grid             JSONB,
  p_category_id      UUID DEFAULT NULL,
  p_fixed_expense_id UUID DEFAULT NULL,
  p_tag_ids          UUID[] DEFAULT NULL
) RETURNS UUID
LANGUAGE plpgsql SECURITY INVOKER AS $$
DECLARE
  v_user UUID := auth.uid();
  v_txn  UUID;
  v_inst UUID;
  v_cell RECORD;
  v_sum  BIGINT;
BEGIN
  -- Grid must reconcile to the expense amount.
  SELECT COALESCE(SUM((c->>'amount')::BIGINT), 0) INTO v_sum
  FROM jsonb_array_elements(p_grid) c;
  IF v_sum <> p_amount THEN
    RAISE EXCEPTION 'Allocation grid (%) must equal expense amount (%)', v_sum, p_amount;
  END IF;

  -- 1. The real expense. budget_id stays NULL (the spread accounts for the
  --    budget impact), but category, fixed-expense link, and tags carry through
  --    like an ordinary expense.
  INSERT INTO transactions
    (user_id, account_id, type, status, amount, description, date,
     category_id, fixed_expense_id)
  VALUES (v_user, p_account_id, 'expense', 'confirmed', p_amount, p_description, p_date,
          p_category_id, p_fixed_expense_id)
  RETURNING id INTO v_txn;

  -- Tag links (RLS on transaction_tags confines the rows to this owner).
  IF p_tag_ids IS NOT NULL THEN
    INSERT INTO transaction_tags (transaction_id, tag_id)
    SELECT v_txn, t FROM unnest(p_tag_ids) AS t;
  END IF;

  -- 2. Header.
  INSERT INTO budget_installments
    (user_id, source_transaction_id, total_amount, description, start_year_month, months)
  VALUES (v_user, v_txn, p_amount, p_description, p_start_year_month, p_months)
  RETURNING id INTO v_inst;

  -- 3. For each cell: materialize the budget row if missing, then insert the allocation.
  FOR v_cell IN SELECT * FROM jsonb_array_elements(p_grid) AS c LOOP
    INSERT INTO budgets (user_id, name, year_month, periodic_amount)
    VALUES (
      v_user,
      v_cell.value->>'budget_name',
      v_cell.value->>'year_month',
      COALESCE((
        SELECT b.periodic_amount FROM budgets b
        WHERE b.user_id = v_user AND b.name = v_cell.value->>'budget_name'
          AND b.year_month <= v_cell.value->>'year_month'
        ORDER BY b.year_month DESC LIMIT 1
      ), 0)
    )
    ON CONFLICT (user_id, name, year_month) DO NOTHING;

    INSERT INTO budget_installment_allocations
      (installment_id, user_id, budget_name, year_month, amount)
    VALUES (v_inst, v_user, v_cell.value->>'budget_name',
            v_cell.value->>'year_month', (v_cell.value->>'amount')::BIGINT);
  END LOOP;

  RETURN v_inst;
END;
$$;

COMMIT;
