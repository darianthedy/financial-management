-- ============================================================
-- MIGRATION: Fix current balance stuck at starting balance
--
-- Root cause: the balance ledger only ever UPDATEs existing
-- account_monthly_balances rows. Rows were created only by the
-- one-time backfill and the monthly cron, so accounts created
-- afterwards (and the current month before the cron runs) had no
-- rows at all. With no row to update, confirmed transactions never
-- moved the balance, and v_account_current_balance returned nothing
-- — so the app fell back to displaying starting_balance.
--
-- This migration:
--   1. Rewrites fn_recalc_balances_from to be self-healing: it walks
--      a generated month series and UPSERTs each row on demand.
--   2. Seeds a current-month row whenever an account is created.
--   3. Backfills/recomputes every existing account.
-- ============================================================

BEGIN;

-- ============================================================
-- 1. SELF-HEALING RECALCULATION
-- Recompute balances from p_from_month forward, creating rows
-- on demand so the ledger never depends on rows pre-existing.
-- balance(M) = balance(M-1) + net confirmed transactions in M
-- ============================================================
CREATE OR REPLACE FUNCTION fn_recalc_balances_from(
  p_account_id UUID,
  p_from_month TEXT
)
RETURNS void AS $$
DECLARE
  prev_balance BIGINT;
  month_row    RECORD;
  net          BIGINT;
  v_end_month  DATE;
BEGIN
  -- Balance carried into p_from_month: the most recent prior row,
  -- or the account's starting balance if there is none.
  SELECT balance INTO prev_balance
  FROM account_monthly_balances
  WHERE account_id = p_account_id AND year_month < p_from_month
  ORDER BY year_month DESC LIMIT 1;

  IF prev_balance IS NULL THEN
    SELECT starting_balance INTO prev_balance
    FROM accounts WHERE id = p_account_id;
  END IF;

  -- Walk through the later of: the current month, the newest existing
  -- row, or p_from_month — so the affected month always gets a row.
  SELECT GREATEST(
           date_trunc('month', CURRENT_DATE)::date,
           to_date(p_from_month, 'YYYY-MM'),
           COALESCE(MAX(to_date(year_month, 'YYYY-MM')), '0001-01-01'::date)
         )
  INTO v_end_month
  FROM account_monthly_balances
  WHERE account_id = p_account_id;

  FOR month_row IN
    SELECT to_char(d, 'YYYY-MM') AS year_month
    FROM generate_series(to_date(p_from_month, 'YYYY-MM'), v_end_month, '1 month') d
    ORDER BY d
  LOOP
    SELECT COALESCE(SUM(
      CASE
        WHEN type = 'income'   AND account_id = p_account_id          THEN amount
        WHEN type = 'expense'  AND account_id = p_account_id          THEN -amount
        WHEN type = 'transfer' AND account_id = p_account_id          THEN -amount
        WHEN type = 'transfer' AND transfer_account_id = p_account_id THEN  amount
        ELSE 0
      END
    ), 0) INTO net
    FROM transactions
    WHERE (account_id = p_account_id OR transfer_account_id = p_account_id)
      AND status = 'confirmed'
      AND to_char(date, 'YYYY-MM') = month_row.year_month;

    prev_balance := prev_balance + net;

    INSERT INTO account_monthly_balances (account_id, year_month, balance)
    VALUES (p_account_id, month_row.year_month, prev_balance)
    ON CONFLICT (account_id, year_month)
    DO UPDATE SET balance = EXCLUDED.balance, updated_at = now();
  END LOOP;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- ============================================================
-- 2. SEED A BALANCE ROW WHEN AN ACCOUNT IS CREATED
-- Keeps the ledger and v_account_current_balance consistent even
-- for accounts that have no transactions yet.
-- ============================================================
CREATE OR REPLACE FUNCTION fn_seed_account_balance()
RETURNS TRIGGER AS $$
BEGIN
  INSERT INTO account_monthly_balances (account_id, year_month, balance)
  VALUES (NEW.id, to_char(CURRENT_DATE, 'YYYY-MM'), NEW.starting_balance)
  ON CONFLICT (account_id, year_month) DO NOTHING;
  RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

DROP TRIGGER IF EXISTS trg_seed_account_balance ON accounts;
CREATE TRIGGER trg_seed_account_balance
  AFTER INSERT ON accounts
  FOR EACH ROW EXECUTE FUNCTION fn_seed_account_balance();

-- ============================================================
-- 3. SELF-HEAL EXISTING DATA
-- Recompute every account from the earliest month it touches, which
-- now creates any missing rows via the rewritten recalc function.
-- ============================================================
DO $$
DECLARE
  r       RECORD;
  v_from  TEXT;
BEGIN
  FOR r IN SELECT id FROM accounts LOOP
    SELECT to_char(LEAST(
      COALESCE(
        (SELECT MIN(to_date(year_month, 'YYYY-MM'))
         FROM account_monthly_balances WHERE account_id = r.id),
        date_trunc('month', CURRENT_DATE)::date),
      COALESCE(
        (SELECT MIN(date_trunc('month', date)::date)
         FROM transactions
         WHERE account_id = r.id OR transfer_account_id = r.id),
        date_trunc('month', CURRENT_DATE)::date),
      date_trunc('month', CURRENT_DATE)::date
    ), 'YYYY-MM') INTO v_from;

    PERFORM fn_recalc_balances_from(r.id, v_from);
  END LOOP;
END $$;

COMMIT;
