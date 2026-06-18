-- ============================================================
-- MIGRATION: Spread an EXISTING expense across budgets
--
-- Companion to create_budget_installment (20260618000001). Instead of inserting
-- a brand-new source expense, this converts an expense the user already recorded
-- into a Budget Installment: it detaches the expense from any single budget (so
-- it is not also counted as that budget's spend) and writes the reservation grid.
-- Validation and grid mechanics mirror create_budget_installment exactly; the
-- amount and description come from the existing transaction rather than args.
--
-- See System Design §4.11 and Supabase Tech Plan §3.10.
-- ============================================================

BEGIN;

CREATE OR REPLACE FUNCTION spread_existing_transaction(
  p_transaction_id   UUID,
  p_start_year_month TEXT,
  p_months           SMALLINT,
  p_grid             JSONB
) RETURNS UUID
LANGUAGE plpgsql SECURITY INVOKER AS $$
DECLARE
  v_user UUID := auth.uid();
  v_txn  transactions%ROWTYPE;
  v_inst UUID;
  v_cell RECORD;
  v_sum  BIGINT;
BEGIN
  -- Load the source expense. RLS restricts visibility to the owner, so a missing
  -- row means it does not exist (or is not theirs).
  SELECT * INTO v_txn FROM transactions WHERE id = p_transaction_id;
  IF NOT FOUND THEN
    RAISE EXCEPTION 'Transaction % not found', p_transaction_id;
  END IF;
  IF v_txn.type <> 'expense' THEN
    RAISE EXCEPTION 'Only expenses can be spread across budgets';
  END IF;
  IF EXISTS (
    SELECT 1 FROM budget_installments WHERE source_transaction_id = p_transaction_id
  ) THEN
    RAISE EXCEPTION 'Transaction % is already spread across budgets', p_transaction_id;
  END IF;

  -- Grid must reconcile to the expense amount.
  SELECT COALESCE(SUM((c->>'amount')::BIGINT), 0) INTO v_sum
  FROM jsonb_array_elements(p_grid) c;
  IF v_sum <> v_txn.amount THEN
    RAISE EXCEPTION 'Allocation grid (%) must equal expense amount (%)', v_sum, v_txn.amount;
  END IF;

  -- Detach from a single budget: the reservation grid now accounts for the
  -- impact, so the source expense must not also count as that budget's spend.
  UPDATE transactions SET budget_id = NULL WHERE id = p_transaction_id;

  -- Header carries the expense's own amount + description.
  INSERT INTO budget_installments
    (user_id, source_transaction_id, total_amount, description, start_year_month, months)
  VALUES (v_user, p_transaction_id, v_txn.amount, v_txn.description, p_start_year_month, p_months)
  RETURNING id INTO v_inst;

  -- For each cell: materialize the budget row if missing, then insert the allocation.
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
