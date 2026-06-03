-- ============================================================
-- MIGRATION: Replace current_balance with account_monthly_balances
--
-- This migration:
--   1. Creates the account_monthly_balances table
--   2. Drops the old balance triggers (INSERT-only & DELETE-only)
--   3. Creates new triggers that handle INSERT/UPDATE/DELETE with cascade
--   4. Creates a cron function for monthly row creation
--   5. Adds a v_account_current_balance view
--   6. Backfills monthly balances from June 2024 to current month
--   7. Drops current_balance from accounts
-- ============================================================

BEGIN;

-- ============================================================
-- 1. CREATE TABLE
-- ============================================================
CREATE TABLE account_monthly_balances (
  account_id  UUID NOT NULL REFERENCES accounts(id) ON DELETE CASCADE,
  year_month  TEXT NOT NULL,
  balance     BIGINT NOT NULL DEFAULT 0,
  updated_at  TIMESTAMPTZ NOT NULL DEFAULT now(),
  PRIMARY KEY (account_id, year_month)
);

CREATE INDEX idx_amb_account ON account_monthly_balances(account_id);
CREATE INDEX idx_amb_month   ON account_monthly_balances(year_month);

-- ============================================================
-- 2. RLS
-- ============================================================
ALTER TABLE account_monthly_balances ENABLE ROW LEVEL SECURITY;

CREATE POLICY policy_owner_amb ON account_monthly_balances FOR ALL
  USING (
    EXISTS (SELECT 1 FROM accounts a WHERE a.id = account_id AND a.user_id = auth.uid())
  );

-- ============================================================
-- 3. updated_at trigger
-- ============================================================
CREATE TRIGGER trg_updated_at_account_monthly_balances
  BEFORE UPDATE ON account_monthly_balances
  FOR EACH ROW EXECUTE FUNCTION fn_set_updated_at();

-- ============================================================
-- 4. DROP OLD BALANCE TRIGGERS & FUNCTIONS
-- ============================================================
DROP TRIGGER IF EXISTS trg_update_balance_on_insert ON transactions;
DROP TRIGGER IF EXISTS trg_reverse_balance_on_delete ON transactions;
DROP FUNCTION IF EXISTS fn_update_account_balance();
DROP FUNCTION IF EXISTS fn_reverse_account_balance();

-- ============================================================
-- 5. NEW TRIGGER SYSTEM: recalculate monthly balances
-- ============================================================

-- Core: recompute all balances for an account from a given month forward.
-- balance(M) = balance(M-1) + net confirmed transactions in M
-- balance(first) = starting_balance + net confirmed transactions
CREATE OR REPLACE FUNCTION fn_recalc_balances_from(
  p_account_id UUID,
  p_from_month TEXT
)
RETURNS void AS $$
DECLARE
  prev_balance BIGINT;
  month_row    RECORD;
  net          BIGINT;
BEGIN
  SELECT balance INTO prev_balance
  FROM account_monthly_balances
  WHERE account_id = p_account_id AND year_month < p_from_month
  ORDER BY year_month DESC LIMIT 1;

  IF prev_balance IS NULL THEN
    SELECT starting_balance INTO prev_balance
    FROM accounts WHERE id = p_account_id;
  END IF;

  FOR month_row IN
    SELECT year_month
    FROM account_monthly_balances
    WHERE account_id = p_account_id AND year_month >= p_from_month
    ORDER BY year_month
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

    UPDATE account_monthly_balances
    SET balance = prev_balance, updated_at = now()
    WHERE account_id = p_account_id AND year_month = month_row.year_month;
  END LOOP;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Trigger: fires on INSERT/UPDATE/DELETE of transactions, cascades recalculation
CREATE OR REPLACE FUNCTION fn_transaction_balance_trigger()
RETURNS TRIGGER AS $$
DECLARE
  affected RECORD;
BEGIN
  CREATE TEMP TABLE IF NOT EXISTS _affected_balances (
    account_id UUID,
    year_month TEXT
  ) ON COMMIT DROP;

  TRUNCATE _affected_balances;

  IF TG_OP = 'INSERT' OR TG_OP = 'UPDATE' THEN
    INSERT INTO _affected_balances VALUES (NEW.account_id, to_char(NEW.date, 'YYYY-MM'));
    IF NEW.transfer_account_id IS NOT NULL THEN
      INSERT INTO _affected_balances VALUES (NEW.transfer_account_id, to_char(NEW.date, 'YYYY-MM'));
    END IF;
  END IF;

  IF TG_OP = 'DELETE' OR TG_OP = 'UPDATE' THEN
    INSERT INTO _affected_balances VALUES (OLD.account_id, to_char(OLD.date, 'YYYY-MM'));
    IF OLD.transfer_account_id IS NOT NULL THEN
      INSERT INTO _affected_balances VALUES (OLD.transfer_account_id, to_char(OLD.date, 'YYYY-MM'));
    END IF;
  END IF;

  FOR affected IN
    SELECT account_id, MIN(year_month) AS from_month
    FROM _affected_balances
    GROUP BY account_id
  LOOP
    PERFORM fn_recalc_balances_from(affected.account_id, affected.from_month);
  END LOOP;

  IF TG_OP = 'DELETE' THEN
    RETURN OLD;
  END IF;
  RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

CREATE TRIGGER trg_recalc_balances
  AFTER INSERT OR UPDATE OR DELETE ON transactions
  FOR EACH ROW
  EXECUTE FUNCTION fn_transaction_balance_trigger();

-- ============================================================
-- 6. CRON FUNCTION: create monthly balance rows on the 1st
-- ============================================================
CREATE OR REPLACE FUNCTION fn_create_monthly_balance_rows()
RETURNS void AS $$
DECLARE
  current_ym TEXT := to_char(CURRENT_DATE, 'YYYY-MM');
  prev_ym    TEXT := to_char(CURRENT_DATE - INTERVAL '1 month', 'YYYY-MM');
BEGIN
  INSERT INTO account_monthly_balances (account_id, year_month, balance)
  SELECT a.id, current_ym, COALESCE(prev.balance, a.starting_balance)
  FROM accounts a
  LEFT JOIN account_monthly_balances prev
    ON prev.account_id = a.id AND prev.year_month = prev_ym
  WHERE a.is_archived = FALSE
  ON CONFLICT (account_id, year_month) DO NOTHING;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Schedule: midnight UTC on the 1st of every month
-- (Requires pg_cron extension to be enabled)
SELECT cron.schedule(
  'create-monthly-balance-rows',
  '0 0 1 * *',
  'SELECT fn_create_monthly_balance_rows()'
);

-- ============================================================
-- 7. VIEW: convenience for current balance
-- ============================================================
CREATE OR REPLACE VIEW v_account_current_balance AS
SELECT DISTINCT ON (account_id)
  account_id,
  year_month,
  balance AS current_balance
FROM account_monthly_balances
ORDER BY account_id, year_month DESC;

-- ============================================================
-- 8. REALTIME: add new table to publication
-- ============================================================
ALTER PUBLICATION supabase_realtime ADD TABLE account_monthly_balances;

-- ============================================================
-- 9. BACKFILL: June 2024 through current month
-- ============================================================
INSERT INTO account_monthly_balances (account_id, year_month, balance)
SELECT
  a.id,
  m.year_month,
  a.starting_balance + COALESCE(SUM(
    CASE
      WHEN t.type = 'income'   AND t.account_id = a.id          THEN t.amount
      WHEN t.type = 'expense'  AND t.account_id = a.id          THEN -t.amount
      WHEN t.type = 'transfer' AND t.account_id = a.id          THEN -t.amount
      WHEN t.type = 'transfer' AND t.transfer_account_id = a.id THEN  t.amount
      ELSE 0
    END
  ), 0) AS balance
FROM accounts a
CROSS JOIN (
  SELECT to_char(d, 'YYYY-MM') AS year_month
  FROM generate_series('2024-06-01'::date, date_trunc('month', CURRENT_DATE), '1 month') d
) m
LEFT JOIN transactions t
  ON (t.account_id = a.id OR t.transfer_account_id = a.id)
  AND t.status = 'confirmed'
  AND to_char(t.date, 'YYYY-MM') <= m.year_month
GROUP BY a.id, a.starting_balance, m.year_month
ORDER BY a.id, m.year_month
ON CONFLICT (account_id, year_month) DO UPDATE SET
  balance = EXCLUDED.balance,
  updated_at = now();

-- ============================================================
-- 10. DROP current_balance from accounts
-- ============================================================
ALTER TABLE accounts DROP COLUMN current_balance;

COMMIT;
