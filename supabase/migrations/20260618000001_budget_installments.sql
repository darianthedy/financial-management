-- ============================================================
-- MIGRATION: Budget Installments (P1) — spread a large expense across budgets
--
-- Adds the two reservation tables, folds a `reserved` term into
-- v_budget_progress, and provides the create_budget_installment RPC that
-- persists an expense and its allocation grid atomically.
--
-- Reservations are BUDGET-SIDE ONLY: they never enter `transactions` and never
-- affect account balances or cash flow. The source expense is one ordinary
-- expense row with budget_id = NULL (so it doesn't also count as that month's
-- spend); the spreading is done entirely by the reservation grid, which lowers
-- what selected budgets show as available in future months.
--
-- See System Design §4.11 and Supabase Tech Plan §3.10.
-- ============================================================

BEGIN;

-- 1. Tables ---------------------------------------------------------------
CREATE TABLE budget_installments (
  id                    UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  user_id               UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  source_transaction_id UUID NOT NULL REFERENCES transactions(id) ON DELETE CASCADE,
  total_amount          BIGINT NOT NULL CHECK (total_amount > 0),
  description           TEXT,
  start_year_month      TEXT NOT NULL,
  months                SMALLINT NOT NULL CHECK (months > 0),
  created_at            TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at            TIMESTAMPTZ NOT NULL DEFAULT now()
);
CREATE INDEX idx_budget_installments_user ON budget_installments(user_id);
CREATE INDEX idx_budget_installments_txn  ON budget_installments(source_transaction_id);

CREATE TABLE budget_installment_allocations (
  id             UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  installment_id UUID NOT NULL REFERENCES budget_installments(id) ON DELETE CASCADE,
  user_id        UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  budget_name    TEXT NOT NULL,
  year_month     TEXT NOT NULL,
  amount         BIGINT NOT NULL CHECK (amount > 0),
  created_at     TIMESTAMPTZ NOT NULL DEFAULT now(),
  UNIQUE (installment_id, budget_name, year_month)
);
CREATE INDEX idx_bia_lookup ON budget_installment_allocations(user_id, budget_name, year_month);

-- 2. RLS (standard owner policy) -----------------------------------------
ALTER TABLE budget_installments            ENABLE ROW LEVEL SECURITY;
ALTER TABLE budget_installment_allocations ENABLE ROW LEVEL SECURITY;
CREATE POLICY policy_owner_budget_installments ON budget_installments
  FOR ALL USING (user_id = auth.uid()) WITH CHECK (user_id = auth.uid());
CREATE POLICY policy_owner_bia ON budget_installment_allocations
  FOR ALL USING (user_id = auth.uid()) WITH CHECK (user_id = auth.uid());

-- 3. Realtime -------------------------------------------------------------
ALTER PUBLICATION supabase_realtime ADD TABLE budget_installments;
ALTER PUBLICATION supabase_realtime ADD TABLE budget_installment_allocations;

-- 4. Fold `reserved` into v_budget_progress ------------------------------
--    Body is unchanged from 20260613000001_budget_description.sql except for a
--    new `reserved` CTE (SUM of allocations per user_id + budget_name +
--    year_month), LEFT JOIN-ed into `base`, carried through the recursive chain,
--    and subtracted inside `remaining`:
--      anchor:  remaining = periodic_amount - spent - reserved
--      recurse: remaining = periodic_amount + carry_in - spent - reserved
--    effective_amount stays periodic + carry_in; a `reserved` column is exposed.
--    Because remaining feeds the next month's carry_in, a reservation lowers the
--    month's pool and only the true leftover carries (use-it-or-lose-it).
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
reserved AS (
  SELECT
    user_id,
    budget_name,
    year_month,
    SUM(amount)::BIGINT AS reserved
  FROM budget_installment_allocations
  GROUP BY user_id, budget_name, year_month
),
base AS (
  SELECT b.*, s.spent,
         COALESCE(r.reserved, 0)::BIGINT AS reserved,
         to_char(to_date(b.year_month, 'YYYY-MM') - interval '1 month', 'YYYY-MM') AS prev_month
  FROM budgets b
  JOIN spent s ON s.budget_id = b.id
  LEFT JOIN reserved r
    ON r.user_id = b.user_id AND r.budget_name = b.name AND r.year_month = b.year_month
),
chain AS (
  -- Anchors: no same-lineage row in the immediately preceding month -> carry_in = 0
  SELECT b.id, b.user_id, b.name, b.description, b.year_month, b.periodic_amount,
         b.spent, b.reserved,
         0::BIGINT AS carry_in,
         b.periodic_amount - b.spent - b.reserved AS remaining
  FROM base b
  WHERE NOT EXISTS (
    SELECT 1 FROM base p
    WHERE p.user_id = b.user_id AND p.name = b.name
      AND p.year_month = b.prev_month
  )
  UNION ALL
  -- Recurse forward into the next consecutive month of the same lineage (compounding)
  SELECT n.id, n.user_id, n.name, n.description, n.year_month, n.periodic_amount,
         n.spent, n.reserved,
         c.remaining AS carry_in,
         n.periodic_amount + c.remaining - n.spent - n.reserved AS remaining
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
  reserved,
  periodic_amount + carry_in - spent - reserved AS remaining
FROM chain;

-- Views default to security_invoker = false, which bypasses RLS. Enforce the
-- caller's privileges so each user sees only their own rows.
ALTER VIEW v_budget_progress SET (security_invoker = true);

-- 5. RPC: persist an expense + its reservation grid atomically -----------
--    Called by the web client (Web §7.8). p_grid is a JSON array of
--    { budget_name, year_month, amount } objects (non-zero cells only).
CREATE OR REPLACE FUNCTION create_budget_installment(
  p_account_id       UUID,
  p_amount           BIGINT,
  p_date             DATE,
  p_description      TEXT,
  p_start_year_month TEXT,
  p_months           SMALLINT,
  p_grid             JSONB
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

  -- 1. The real expense. budget_id stays NULL: the spread accounts for the impact.
  INSERT INTO transactions (user_id, account_id, type, status, amount, description, date)
  VALUES (v_user, p_account_id, 'expense', 'confirmed', p_amount, p_description, p_date)
  RETURNING id INTO v_txn;

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
