-- Core recalculation: recomputes all monthly balances from a given month forward
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

-- Monthly cron function: creates balance rows for the new month
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

-- Auto-touch updated_at on row update
CREATE OR REPLACE FUNCTION fn_set_updated_at()
RETURNS TRIGGER AS $$
BEGIN
  NEW.updated_at = now();
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

DO $$
DECLARE
  t TEXT;
BEGIN
  FOR t IN
    SELECT unnest(ARRAY[
      'accounts','budgets','budget_periods','fixed_expenses',
      'scheduled_transactions','transactions',
      'account_monthly_balances'
    ])
  LOOP
    EXECUTE format(
      'CREATE TRIGGER trg_updated_at_%s BEFORE UPDATE ON %I FOR EACH ROW EXECUTE FUNCTION fn_set_updated_at()',
      t, t
    );
  END LOOP;
END $$;
