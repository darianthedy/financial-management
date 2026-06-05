-- ============================================================
-- COMBINED MIGRATION: Financial Management
-- Run this in the Supabase SQL Editor (Dashboard > SQL Editor)
-- ============================================================

-- ============================================================
-- 1. EXTENSIONS
-- ============================================================
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";

-- ============================================================
-- 2. ENUMS
-- ============================================================
CREATE TYPE account_type AS ENUM (
  'bank_account',
  'credit_card',
  'digital_wallet',
  'cash',
  'other'
);

CREATE TYPE transaction_type AS ENUM (
  'income',
  'expense',
  'transfer'
);

CREATE TYPE transaction_status AS ENUM (
  'confirmed',
  'pending',
  'dismissed'
);

CREATE TYPE recurrence_type AS ENUM (
  'monthly'
);

-- ============================================================
-- 3. ACCOUNTS
-- ============================================================
CREATE TABLE accounts (
  id               UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  user_id          UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  name             TEXT NOT NULL,
  type             account_type NOT NULL DEFAULT 'other',
  currency         TEXT NOT NULL DEFAULT 'USD',
  starting_balance BIGINT NOT NULL DEFAULT 0,
  is_archived      BOOLEAN NOT NULL DEFAULT FALSE,
  created_at       TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at       TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE INDEX idx_accounts_user ON accounts(user_id);

-- ============================================================
-- 3b. ACCOUNT MONTHLY BALANCES (running balance ledger)
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
-- 4. CATEGORIES
-- ============================================================
CREATE TABLE categories (
  id         UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  user_id    UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  name       TEXT NOT NULL,
  icon       TEXT,
  color      TEXT,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),

  UNIQUE(user_id, name)
);

CREATE INDEX idx_categories_user ON categories(user_id);

-- ============================================================
-- 5. TAGS
-- ============================================================
CREATE TABLE tags (
  id         UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  user_id    UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  name       TEXT NOT NULL,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),

  UNIQUE(user_id, name)
);

CREATE INDEX idx_tags_user ON tags(user_id);

-- ============================================================
-- 6. BUDGETS
-- ============================================================
CREATE TABLE budgets (
  id                UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  user_id           UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  name              TEXT NOT NULL,
  is_active         BOOLEAN NOT NULL DEFAULT TRUE,
  enable_carry_over BOOLEAN NOT NULL DEFAULT FALSE,
  created_at        TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at        TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE INDEX idx_budgets_user ON budgets(user_id);

CREATE TABLE budget_periods (
  id                UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  budget_id         UUID NOT NULL REFERENCES budgets(id) ON DELETE CASCADE,
  year_month        TEXT NOT NULL,
  periodic_amount   BIGINT NOT NULL,
  carry_over_amount BIGINT NOT NULL DEFAULT 0,
  currency          TEXT NOT NULL DEFAULT 'USD',
  created_at        TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at        TIMESTAMPTZ NOT NULL DEFAULT now(),

  UNIQUE(budget_id, year_month)
);

CREATE INDEX idx_budget_periods_budget ON budget_periods(budget_id);
CREATE INDEX idx_budget_periods_month  ON budget_periods(year_month);

-- ============================================================
-- 7. FIXED EXPENSES
-- ============================================================
-- Each row represents one fixed expense for one specific month.
-- No separate periods table — the fixed_expenses table itself
-- carries the period (year_month) and financial details.
CREATE TABLE fixed_expenses (
  id         UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  user_id    UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  name       TEXT NOT NULL,
  year_month TEXT NOT NULL,  -- format: 'YYYY-MM'
  amount     BIGINT NOT NULL,
  currency   TEXT NOT NULL DEFAULT 'USD',
  due_day    SMALLINT NOT NULL CHECK (due_day BETWEEN 1 AND 31),
  is_active  BOOLEAN NOT NULL DEFAULT TRUE,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT now(),

  UNIQUE(user_id, name, year_month)
);

CREATE INDEX idx_fixed_expenses_user  ON fixed_expenses(user_id);
CREATE INDEX idx_fixed_expenses_month ON fixed_expenses(year_month);

-- ============================================================
-- 8. SCHEDULED TRANSACTIONS
-- ============================================================
CREATE TABLE scheduled_transactions (
  id            UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  user_id       UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  account_id    UUID NOT NULL REFERENCES accounts(id) ON DELETE CASCADE,
  type          transaction_type NOT NULL,
  amount        BIGINT NOT NULL,
  currency      TEXT NOT NULL DEFAULT 'USD',
  description   TEXT,
  recurrence    recurrence_type NOT NULL DEFAULT 'monthly',
  next_due_date DATE NOT NULL,
  is_active     BOOLEAN NOT NULL DEFAULT TRUE,
  created_at    TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at    TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE INDEX idx_sched_txn_user ON scheduled_transactions(user_id);
CREATE INDEX idx_sched_txn_due  ON scheduled_transactions(next_due_date)
  WHERE is_active = TRUE;

-- ============================================================
-- 9. TRANSACTIONS
-- ============================================================
CREATE TABLE transactions (
  id                    UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  user_id               UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  account_id            UUID NOT NULL REFERENCES accounts(id) ON DELETE RESTRICT,
  transfer_account_id   UUID REFERENCES accounts(id) ON DELETE RESTRICT,
  type                  transaction_type NOT NULL,
  status                transaction_status NOT NULL DEFAULT 'confirmed',
  amount                BIGINT NOT NULL CHECK (amount > 0),
  currency              TEXT NOT NULL DEFAULT 'USD',
  description           TEXT,
  date                  DATE NOT NULL DEFAULT CURRENT_DATE,
  budget_period_id          UUID REFERENCES budget_periods(id) ON DELETE SET NULL,
  scheduled_txn_id          UUID REFERENCES scheduled_transactions(id) ON DELETE SET NULL,
  fixed_expense_id          UUID REFERENCES fixed_expenses(id) ON DELETE SET NULL,
  created_at                TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at                TIMESTAMPTZ NOT NULL DEFAULT now(),

  CONSTRAINT chk_transfer_account CHECK (
    (type = 'transfer' AND transfer_account_id IS NOT NULL)
    OR (type != 'transfer' AND transfer_account_id IS NULL)
  )
);

CREATE INDEX idx_txn_user       ON transactions(user_id);
CREATE INDEX idx_txn_account    ON transactions(account_id);
CREATE INDEX idx_txn_date       ON transactions(date);
CREATE INDEX idx_txn_status     ON transactions(status);
CREATE INDEX idx_txn_budget_per ON transactions(budget_period_id);
CREATE INDEX idx_txn_type_date  ON transactions(type, date);
CREATE INDEX idx_txn_fixed_exp  ON transactions(fixed_expense_id)
  WHERE fixed_expense_id IS NOT NULL;

-- ============================================================
-- 10. JUNCTION TABLES
-- ============================================================
CREATE TABLE transaction_categories (
  transaction_id UUID NOT NULL REFERENCES transactions(id) ON DELETE CASCADE,
  category_id    UUID NOT NULL REFERENCES categories(id) ON DELETE CASCADE,
  PRIMARY KEY (transaction_id, category_id)
);

CREATE TABLE transaction_tags (
  transaction_id UUID NOT NULL REFERENCES transactions(id) ON DELETE CASCADE,
  tag_id         UUID NOT NULL REFERENCES tags(id) ON DELETE CASCADE,
  PRIMARY KEY (transaction_id, tag_id)
);

-- ============================================================
-- 11. ROW-LEVEL SECURITY
-- ============================================================
ALTER TABLE accounts                 ENABLE ROW LEVEL SECURITY;
ALTER TABLE account_monthly_balances ENABLE ROW LEVEL SECURITY;
ALTER TABLE categories               ENABLE ROW LEVEL SECURITY;
ALTER TABLE tags                     ENABLE ROW LEVEL SECURITY;
ALTER TABLE budgets                  ENABLE ROW LEVEL SECURITY;
ALTER TABLE budget_periods           ENABLE ROW LEVEL SECURITY;
ALTER TABLE fixed_expenses           ENABLE ROW LEVEL SECURITY;
ALTER TABLE scheduled_transactions   ENABLE ROW LEVEL SECURITY;
ALTER TABLE transactions             ENABLE ROW LEVEL SECURITY;
ALTER TABLE transaction_categories   ENABLE ROW LEVEL SECURITY;
ALTER TABLE transaction_tags         ENABLE ROW LEVEL SECURITY;

DO $$
DECLARE
  t TEXT;
BEGIN
  FOR t IN
    SELECT unnest(ARRAY[
      'accounts','categories','tags','budgets','fixed_expenses',
      'scheduled_transactions','transactions'
    ])
  LOOP
    EXECUTE format(
      'CREATE POLICY %I ON %I FOR ALL USING (user_id = auth.uid()) WITH CHECK (user_id = auth.uid())',
      'policy_owner_' || t, t
    );
  END LOOP;
END $$;

CREATE POLICY policy_owner_amb ON account_monthly_balances FOR ALL
  USING (
    EXISTS (SELECT 1 FROM accounts a WHERE a.id = account_id AND a.user_id = auth.uid())
  );

CREATE POLICY policy_owner_txn_categories ON transaction_categories FOR ALL
  USING (
    EXISTS (SELECT 1 FROM transactions t WHERE t.id = transaction_id AND t.user_id = auth.uid())
  );

CREATE POLICY policy_owner_txn_tags ON transaction_tags FOR ALL
  USING (
    EXISTS (SELECT 1 FROM transactions t WHERE t.id = transaction_id AND t.user_id = auth.uid())
  );

CREATE POLICY policy_owner_budget_periods ON budget_periods FOR ALL
  USING (
    EXISTS (SELECT 1 FROM budgets b WHERE b.id = budget_id AND b.user_id = auth.uid())
  );

-- ============================================================
-- 12. TRIGGERS: recalculate account_monthly_balances
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

-- Seed a current-month balance row whenever an account is created, so
-- the ledger and v_account_current_balance stay consistent even before
-- the account has any transactions.
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

-- Recompute the ledger when starting_balance changes. The transaction
-- cascade only reads starting_balance for the earliest month, so without
-- this an edit to starting_balance would never reach the current balance.
CREATE OR REPLACE FUNCTION fn_recalc_on_starting_balance_change()
RETURNS TRIGGER AS $$
DECLARE
  v_from TEXT;
BEGIN
  -- Recalc from the earliest month that has a balance row — the only
  -- month whose base figure is starting_balance. Fall back to the
  -- current month if the account has no rows yet.
  SELECT to_char(
    COALESCE(MIN(to_date(year_month, 'YYYY-MM')),
             date_trunc('month', CURRENT_DATE)::date),
    'YYYY-MM')
  INTO v_from
  FROM account_monthly_balances
  WHERE account_id = NEW.id;

  PERFORM fn_recalc_balances_from(NEW.id, v_from);
  RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

DROP TRIGGER IF EXISTS trg_recalc_on_starting_balance ON accounts;
CREATE TRIGGER trg_recalc_on_starting_balance
  AFTER UPDATE OF starting_balance ON accounts
  FOR EACH ROW
  WHEN (OLD.starting_balance IS DISTINCT FROM NEW.starting_balance)
  EXECUTE FUNCTION fn_recalc_on_starting_balance_change();

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
-- 13. CRON FUNCTIONS
-- ============================================================

-- Monthly balance row creation (scheduled via pg_cron: 0 0 1 * *)
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

-- Auto-generate pending transactions (scheduled via pg_cron: 5 0 * * *)
CREATE OR REPLACE FUNCTION fn_generate_pending_transactions()
RETURNS void AS $$
DECLARE
  sched RECORD;
  next_date DATE;
BEGIN
  FOR sched IN
    SELECT * FROM scheduled_transactions
    WHERE is_active = TRUE AND next_due_date <= CURRENT_DATE
  LOOP
    INSERT INTO transactions (
      user_id, account_id, type, status, amount, currency,
      description, date, scheduled_txn_id
    ) VALUES (
      sched.user_id, sched.account_id, sched.type, 'pending',
      sched.amount, sched.currency, sched.description,
      sched.next_due_date, sched.id
    );

    next_date := sched.next_due_date + INTERVAL '1 month';
    UPDATE scheduled_transactions
    SET next_due_date = next_date, updated_at = now()
    WHERE id = sched.id;
  END LOOP;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- ============================================================
-- 14. TRIGGERS: updated_at auto-touch
-- ============================================================
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

-- ============================================================
-- 15. VIEWS: dashboard helpers
-- ============================================================

CREATE OR REPLACE VIEW v_account_current_balance AS
SELECT DISTINCT ON (account_id)
  account_id,
  year_month,
  balance AS current_balance
FROM account_monthly_balances
ORDER BY account_id, year_month DESC;

CREATE OR REPLACE VIEW v_monthly_cashflow AS
SELECT
  user_id,
  to_char(date, 'YYYY-MM') AS year_month,
  SUM(CASE WHEN type = 'income'  THEN amount ELSE 0 END) AS total_income,
  SUM(CASE WHEN type = 'expense' THEN amount ELSE 0 END) AS total_expense,
  SUM(CASE WHEN type = 'income'  THEN amount ELSE 0 END)
    - SUM(CASE WHEN type = 'expense' THEN amount ELSE 0 END) AS net
FROM transactions
WHERE status = 'confirmed'
GROUP BY user_id, to_char(date, 'YYYY-MM');

CREATE OR REPLACE VIEW v_budget_progress AS
SELECT
  bp.id AS budget_period_id,
  b.id AS budget_id,
  b.name AS budget_name,
  b.enable_carry_over,
  bp.year_month,
  bp.periodic_amount,
  bp.carry_over_amount,
  bp.periodic_amount + bp.carry_over_amount AS effective_amount,
  bp.currency,
  COALESCE(SUM(t.amount), 0) AS spent,
  (bp.periodic_amount + bp.carry_over_amount) - COALESCE(SUM(t.amount), 0) AS remaining
FROM budget_periods bp
JOIN budgets b ON b.id = bp.budget_id
LEFT JOIN transactions t
  ON t.budget_period_id = bp.id
  AND t.status = 'confirmed'
GROUP BY bp.id, b.id, b.name, b.enable_carry_over,
         bp.year_month, bp.periodic_amount, bp.carry_over_amount, bp.currency;

CREATE OR REPLACE VIEW v_spending_by_category AS
SELECT
  t.user_id,
  to_char(t.date, 'YYYY-MM') AS year_month,
  c.id AS category_id,
  c.name AS category_name,
  c.icon,
  c.color,
  SUM(t.amount) AS total_amount
FROM transactions t
JOIN transaction_categories tc ON tc.transaction_id = t.id
JOIN categories c ON c.id = tc.category_id
WHERE t.type = 'expense' AND t.status = 'confirmed'
GROUP BY t.user_id, to_char(t.date, 'YYYY-MM'), c.id, c.name, c.icon, c.color;

-- Run views with the caller's privileges so the base tables' RLS
-- (user_id = auth.uid()) applies through the view. Without this, views
-- default to the owner's privileges and leak every user's rows.
ALTER VIEW v_account_current_balance SET (security_invoker = true);
ALTER VIEW v_monthly_cashflow        SET (security_invoker = true);
ALTER VIEW v_budget_progress         SET (security_invoker = true);
ALTER VIEW v_spending_by_category    SET (security_invoker = true);

-- ============================================================
-- 16. REALTIME: enable on tables clients subscribe to
-- ============================================================
ALTER PUBLICATION supabase_realtime ADD TABLE transactions;
ALTER PUBLICATION supabase_realtime ADD TABLE accounts;
ALTER PUBLICATION supabase_realtime ADD TABLE account_monthly_balances;
ALTER PUBLICATION supabase_realtime ADD TABLE budget_periods;
ALTER PUBLICATION supabase_realtime ADD TABLE fixed_expenses;

-- ============================================================
-- 17. BACKFILL: populate monthly balances from June 2024 to current month
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
