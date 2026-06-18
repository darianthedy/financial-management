# Financial Management — System Design & Database Schema

---

## 1. High-Level System Architecture

```
┌─────────────────────────────────────────────────────────────────┐
│                          Clients                                │
│                                                                 │
│   ┌──────────────┐   ┌──────────────┐   ┌──────────────┐       │
│   │  Web / SPA   │   │  iOS App     │   │ Android App  │       │
│   │  (React /    │   │  (Swift /    │   │  (Kotlin /   │       │
│   │   Next.js)   │   │   SwiftUI)   │   │   Compose)   │       │
│   └──────┬───────┘   └──────┬───────┘   └──────┬───────┘       │
│          │                  │                   │               │
│          └──────────────────┼───────────────────┘               │
│                             │                                   │
│                     Supabase Client SDK                         │
│         (supabase-js / supabase-swift / supabase-kt)            │
└─────────────────────────────┬───────────────────────────────────┘
                              │  HTTPS / WebSocket (Realtime)
                              ▼
┌─────────────────────────────────────────────────────────────────┐
│                      Supabase Platform                          │
│                                                                 │
│   ┌──────────────────────────────────────────────────────────┐  │
│   │                    Supabase Auth                         │  │
│   │            (single-user, email/password)                 │  │
│   └──────────────────────────────────────────────────────────┘  │
│                                                                 │
│   ┌──────────────────────────────────────────────────────────┐  │
│   │                   PostgREST API                          │  │
│   │       (auto-generated REST from Postgres schema)         │  │
│   └──────────────────────────────────────────────────────────┘  │
│                                                                 │
│   ┌──────────────────────────────────────────────────────────┐  │
│   │                  Supabase Realtime                        │  │
│   │       (broadcasts row changes to connected clients)      │  │
│   └──────────────────────────────────────────────────────────┘  │
│                                                                 │
│   ┌──────────────────────────────────────────────────────────┐  │
│   │              Supabase Edge Functions                      │  │
│   │  ┌────────────────┐  ┌─────────────────────────────┐     │  │
│   │  │ CRON: generate │  │ P1: Receipt OCR / AI        │     │  │
│   │  │ pending txns   │  │     extraction               │     │  │
│   │  │ from schedules │  │     (calls external API)     │     │  │
│   │  └────────────────┘  └─────────────────────────────┘     │  │
│   └──────────────────────────────────────────────────────────┘  │
│                                                                 │
│   ┌──────────────────────────────────────────────────────────┐  │
│   │                  Supabase Storage                         │  │
│   │   account avatar images (P0) · receipt images (P1)        │  │
│   └──────────────────────────────────────────────────────────┘  │
│                                                                 │
│   ┌──────────────────────────────────────────────────────────┐  │
│   │                     PostgreSQL                           │  │
│   │          (primary data store — see Section 2)            │  │
│   └──────────────────────────────────────────────────────────┘  │
└─────────────────────────────────────────────────────────────────┘
```

### No Custom Backend Server

This architecture has **no custom backend server** (no Express, FastAPI, etc.). Clients connect **directly to Supabase** via the client SDK over HTTPS/WebSocket. All concerns typically handled by a backend are covered natively:

- **CRUD** → PostgREST auto-generates REST endpoints from the Postgres schema.
- **Auth & Authorization** → Supabase Auth + Row-Level Security at the DB layer.
- **Business logic** (balance updates, validation) → Postgres triggers and constraints.
- **Scheduled jobs** (auto-record transactions) → `pg_cron` + Edge Functions (serverless, not a separate server).
- **Realtime sync** → Supabase Realtime over WebSocket.
- **File storage** → Supabase Storage (account avatar images in P0; receipt images in P1).

A custom backend would only be needed if future requirements exceed what Edge Functions can handle (e.g., long-running jobs > 150s, or complex multi-service orchestration). For P0 and P1, this is not the case.

### Key Architectural Decisions

| Decision | Choice | Rationale |
|---|---|---|
| **Backend** | None — direct FE → Supabase | No middleware needed. PostgREST, Auth, RLS, triggers, Edge Functions, and Realtime cover all P0/P1 requirements. |
| **Cross-platform client** | Native per platform: Next.js (Web), Swift/SwiftUI (iOS), Kotlin/Jetpack Compose (Android) | Each platform uses its native SDK for the best UX and platform integration. Supabase provides first-class SDKs for all three (`supabase-js`, `supabase-swift`, `supabase-kt`). |
| **Sync strategy** | Supabase Realtime subscriptions + optimistic client cache | Clients subscribe to table changes via WebSocket. Offline writes are queued locally and pushed on reconnect. |
| **Auth model** | Supabase Auth, single user | Even though single-user, we still gate every table with RLS (`auth.uid()`) so the schema is secure-by-default and P1-ready for multi-user. |
| **Auto-record engine** | Supabase `pg_cron` + Edge Function | A cron job runs daily (or more frequently), checks `scheduled_transactions` for items due today, and inserts pending transactions. Push notification sent via Edge Function. |
| **Currency** | Single-currency: the currency is chosen once in Settings (`user_settings.default_currency`) and every amount is formatted in it — there is no per-record `currency` column. Amounts stored as `bigint` in minor units (cents). A `currencies` table holds all supported ISO 4217 codes. | Avoids floating-point errors. Centralised currency list prevents hardcoding across platforms. Display layer converts to decimal. |
| **Period handling** | `year_month` column (`TEXT` formatted `YYYY-MM`) | Enables simple equality checks for monthly budgets/fixed expenses. Easy to extend to other period types in P1. |

---

## 2. Database Schema

### 2.1 Entity-Relationship Overview

```
  Reference tables (currencies) have no user_id. Every other table carries a
  user_id FK -> users.id (Supabase Auth, single-user). Entities are shown as
  boxes; the cardinality of every link is listed under "Relationships" below.

  ┌──────────────────┐   ┌──────────────────┐   ┌──────────────────┐
  │    currencies    │   │   user_settings  │   │     accounts     │
  │──────────────────│   │──────────────────│   │──────────────────│
  │ code (PK)        │   │ user_id (PK/FK)  │   │ id (PK)          │
  │ name             │   │ default_currency │   │ user_id (FK)     │
  │ symbol           │   └──────────────────┘   │ name             │
  │ decimal_places   │                          │ type             │
  └──────────────────┘                          │ starting_balance │
                                                │ image_url        │
                                                └──────────────────┘
  ┌──────────────────┐   ┌──────────────────┐   ┌──────────────────┐
  │    categories    │   │       tags       │   │     budgets      │
  │──────────────────│   │──────────────────│   │──────────────────│
  │ id (PK)          │   │ id (PK)          │   │ id (PK)          │
  │ user_id (FK)     │   │ user_id (FK)     │   │ user_id (FK)     │
  │ name             │   │ name             │   │ name             │
  │ icon             │   └──────────────────┘   │ year_month       │
  │ color            │                          │ periodic_amount  │
  └──────────────────┘                          └──────────────────┘
  ┌──────────────────┐   ┌──────────────────┐   ┌───────────────────────┐
  │  fixed_expenses  │   │ account_monthly  │   │ scheduled_transactions│
  │──────────────────│   │   _balances      │   │───────────────────────│
  │ id (PK)          │   │──────────────────│   │ id (PK)               │
  │ user_id (FK)     │   │ account_id (PFK) │   │ user_id (FK)          │
  │ name             │   │ year_month (PK)  │   │ account_id (FK)       │
  │ year_month       │   │ balance          │   │ type                  │
  │ amount           │   └──────────────────┘   │ amount                │
  │ due_day          │                          │ recurrence            │
  │ is_active        │                          │ next_due_date         │
  └──────────────────┘                          │ is_active             │
                                                └───────────────────────┘
  ┌────────────────────────────────┐   ┌──────────────────────────────┐
  │          transactions          │   │       transaction_tags       │
  │────────────────────────────────│   │  (many-to-many junction)     │
  │ id (PK)                        │   │──────────────────────────────│
  │ user_id (FK)                   │   │ transaction_id (PFK -> txns) │
  │ account_id (FK)                │   │ tag_id        (PFK -> tags)  │
  │ transfer_account_id (FK)       │   └──────────────────────────────┘
  │ category_id (FK)  <- ONE per txn, nullable
  │ budget_id (FK)                 │
  │ fixed_expense_id (FK)          │
  │ scheduled_txn_id (FK)          │
  │ type / status / amount / date  │
  └────────────────────────────────┘

  Relationships
  ─────────────
   users          1 --< accounts, categories, tags, budgets, fixed_expenses,
                        scheduled_transactions, transactions      (user_id)
   users          1 --  user_settings                             (user_id, PK)
   accounts       1 --< transactions       (account_id, transfer_account_id)
   accounts       1 --< account_monthly_balances                  (account_id)
   categories     1 --< transactions       (category_id - ONE per txn, nullable)   <- single-select
   budgets        1 --< transactions       (budget_id, nullable)
   fixed_expenses 1 --< transactions       (fixed_expense_id, nullable)
   scheduled_transactions 1 --< transactions (scheduled_txn_id, nullable)
   tags           * --< transaction_tags >-- 1 transactions       (many-to-many)
```

### 2.2 Table Definitions (SQL DDL)

All monetary amounts are stored as **`bigint`** in **minor currency units** (e.g., cents for USD). The application layer converts for display.

```sql
-- ============================================================
-- EXTENSIONS
-- ============================================================
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";

-- ============================================================
-- ENUMS
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
  -- P1: 'weekly', 'quarterly', 'yearly', 'custom'
);

-- ============================================================
-- CURRENCIES (reference table — no RLS, readable by all authenticated users)
-- ============================================================
CREATE TABLE currencies (
  code           TEXT PRIMARY KEY,            -- ISO 4217 (e.g. 'USD', 'EUR')
  name           TEXT NOT NULL,               -- e.g. 'US Dollar'
  symbol         TEXT NOT NULL DEFAULT '',     -- e.g. '$', '€'
  decimal_places SMALLINT NOT NULL DEFAULT 2, -- minor unit digits
  created_at     TIMESTAMPTZ NOT NULL DEFAULT now()
);

-- ============================================================
-- USER SETTINGS
-- ============================================================
CREATE TABLE user_settings (
  user_id          UUID PRIMARY KEY REFERENCES auth.users(id) ON DELETE CASCADE,
  default_currency TEXT NOT NULL DEFAULT 'USD' REFERENCES currencies(code),
  created_at       TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at       TIMESTAMPTZ NOT NULL DEFAULT now()
);

-- ============================================================
-- ACCOUNTS
-- ============================================================
CREATE TABLE accounts (
  id            UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  user_id       UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  name          TEXT NOT NULL,
  type          account_type NOT NULL DEFAULT 'other',
  starting_balance BIGINT NOT NULL DEFAULT 0,
  image_url     TEXT,                              -- public URL of the avatar in Supabase Storage (nullable)
  is_archived   BOOLEAN NOT NULL DEFAULT FALSE,
  show_on_dashboard BOOLEAN NOT NULL DEFAULT TRUE, -- when false, hidden from the dashboard Accounts card
  created_at    TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at    TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE INDEX idx_accounts_user ON accounts(user_id);

-- ============================================================
-- ACCOUNT MONTHLY BALANCES (running balance ledger)
-- ============================================================
-- Each row stores the end-of-month balance for one account in one month.
-- Formula: balance(M) = balance(M-1) + net confirmed transactions in M
--          balance(first month) = starting_balance + net confirmed transactions
-- Rows are created by a monthly cron job on the 1st of each month and
-- recalculated by a trigger whenever transactions change.
CREATE TABLE account_monthly_balances (
  account_id  UUID NOT NULL REFERENCES accounts(id) ON DELETE CASCADE,
  year_month  TEXT NOT NULL,  -- format: 'YYYY-MM'
  balance     BIGINT NOT NULL DEFAULT 0,
  updated_at  TIMESTAMPTZ NOT NULL DEFAULT now(),
  PRIMARY KEY (account_id, year_month)
);

CREATE INDEX idx_amb_account ON account_monthly_balances(account_id);
CREATE INDEX idx_amb_month   ON account_monthly_balances(year_month);

-- ============================================================
-- CATEGORIES
-- ============================================================
CREATE TABLE categories (
  id        UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  user_id   UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  name      TEXT NOT NULL,
  icon      TEXT,
  color     TEXT,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),

  UNIQUE(user_id, name)
);

CREATE INDEX idx_categories_user ON categories(user_id);

-- ============================================================
-- TAGS
-- ============================================================
CREATE TABLE tags (
  id        UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  user_id   UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  name      TEXT NOT NULL,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),

  UNIQUE(user_id, name)
);

CREATE INDEX idx_tags_user ON tags(user_id);

-- ============================================================
-- BUDGETS
-- ============================================================
-- Each row is a self-contained monthly budget entry, mirroring fixed_expenses.
-- Identity is (name): rows sharing the same name across consecutive months form
-- one carry-over lineage.
-- periodic_amount: the spending limit the user sets for this month.
-- Carry-over is ALWAYS ON and computed live in v_budget_progress (there is no
-- stored carry_over column), so editing a past month's periodic_amount or its
-- linked transactions automatically recomputes every later month in the lineage.
CREATE TABLE budgets (
  id              UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  user_id         UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  name            TEXT NOT NULL,
  year_month      TEXT NOT NULL,                       -- format: 'YYYY-MM'
  periodic_amount BIGINT NOT NULL,                     -- minor units
  created_at      TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at      TIMESTAMPTZ NOT NULL DEFAULT now(),

  UNIQUE(user_id, name, year_month)
);

CREATE INDEX idx_budgets_user    ON budgets(user_id);
CREATE INDEX idx_budgets_lineage ON budgets(user_id, name, year_month);

-- ============================================================
-- FIXED EXPENSES
-- ============================================================
-- Each row is a self-contained monthly fixed expense entry.
-- Paid status is derived: an entry is considered paid when at least one
-- transaction references it via transactions.fixed_expense_id.
-- "Copy from Previous Month" creates new rows for the next month.
CREATE TABLE fixed_expenses (
  id         UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  user_id    UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  name       TEXT NOT NULL,
  year_month TEXT NOT NULL,  -- format: 'YYYY-MM'
  amount     BIGINT NOT NULL,
  due_day    SMALLINT NOT NULL CHECK (due_day BETWEEN 1 AND 31),
  is_active  BOOLEAN NOT NULL DEFAULT TRUE,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  UNIQUE(user_id, name, year_month)
);
CREATE INDEX idx_fixed_expenses_user  ON fixed_expenses(user_id);
CREATE INDEX idx_fixed_expenses_month ON fixed_expenses(year_month);

-- ============================================================
-- SCHEDULED TRANSACTIONS (Auto-Record source)
-- ============================================================
CREATE TABLE scheduled_transactions (
  id            UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  user_id       UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  account_id    UUID NOT NULL REFERENCES accounts(id) ON DELETE CASCADE,
  type          transaction_type NOT NULL,
  amount        BIGINT NOT NULL,
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
-- TRANSACTIONS
-- ============================================================
CREATE TABLE transactions (
  id                    UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  user_id               UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  account_id            UUID NOT NULL REFERENCES accounts(id) ON DELETE RESTRICT,
  transfer_account_id   UUID REFERENCES accounts(id) ON DELETE RESTRICT,
  type                  transaction_type NOT NULL,
  status                transaction_status NOT NULL DEFAULT 'confirmed',
  amount                BIGINT NOT NULL,
  description           TEXT,
  date                  DATE NOT NULL DEFAULT CURRENT_DATE,
  budget_id                 UUID REFERENCES budgets(id) ON DELETE SET NULL,
  category_id               UUID REFERENCES categories(id) ON DELETE SET NULL,
  scheduled_txn_id          UUID REFERENCES scheduled_transactions(id) ON DELETE SET NULL,
  fixed_expense_id            UUID REFERENCES fixed_expenses(id) ON DELETE SET NULL,
  created_at                TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at                TIMESTAMPTZ NOT NULL DEFAULT now(),

  -- Amount may be negative for income/expense (e.g. a refund recorded as a
  -- negative expense), but never zero; transfers stay strictly positive.
  CONSTRAINT transactions_amount_check CHECK (
    amount <> 0 AND (type <> 'transfer' OR amount > 0)
  ),

  -- Transfer must reference a second account
  CONSTRAINT chk_transfer_account CHECK (
    (type = 'transfer' AND transfer_account_id IS NOT NULL)
    OR (type != 'transfer' AND transfer_account_id IS NULL)
  )
);

CREATE INDEX idx_txn_user       ON transactions(user_id);
CREATE INDEX idx_txn_account    ON transactions(account_id);
CREATE INDEX idx_txn_date       ON transactions(date);
CREATE INDEX idx_txn_status     ON transactions(status);
CREATE INDEX idx_txn_budget     ON transactions(budget_id);
CREATE INDEX idx_txn_category   ON transactions(category_id);
CREATE INDEX idx_txn_type_date  ON transactions(type, date);
CREATE INDEX idx_txn_fixed_exp  ON transactions(fixed_expense_id)
  WHERE fixed_expense_id IS NOT NULL;

-- ============================================================
-- TRANSACTION ↔ TAG  (many-to-many)
-- ============================================================
CREATE TABLE transaction_tags (
  transaction_id UUID NOT NULL REFERENCES transactions(id) ON DELETE CASCADE,
  tag_id         UUID NOT NULL REFERENCES tags(id) ON DELETE CASCADE,
  PRIMARY KEY (transaction_id, tag_id)
);

-- ============================================================
-- ROW-LEVEL SECURITY (RLS)
-- ============================================================
ALTER TABLE currencies              ENABLE ROW LEVEL SECURITY;
ALTER TABLE user_settings           ENABLE ROW LEVEL SECURITY;
ALTER TABLE accounts                ENABLE ROW LEVEL SECURITY;
ALTER TABLE categories              ENABLE ROW LEVEL SECURITY;
ALTER TABLE tags                    ENABLE ROW LEVEL SECURITY;
ALTER TABLE budgets                 ENABLE ROW LEVEL SECURITY;
ALTER TABLE fixed_expenses          ENABLE ROW LEVEL SECURITY;
ALTER TABLE scheduled_transactions  ENABLE ROW LEVEL SECURITY;
ALTER TABLE transactions              ENABLE ROW LEVEL SECURITY;
ALTER TABLE account_monthly_balances ENABLE ROW LEVEL SECURITY;
ALTER TABLE transaction_tags         ENABLE ROW LEVEL SECURITY;

-- currencies: read-only for all authenticated users
CREATE POLICY policy_currencies_read ON currencies FOR SELECT
  USING (auth.role() = 'authenticated');

-- user_settings: owner-only access
CREATE POLICY policy_owner_user_settings ON user_settings FOR ALL
  USING (user_id = auth.uid()) WITH CHECK (user_id = auth.uid());

-- Uniform policy: owner can do everything on their own rows.
-- (Repeat this pattern for each table; shown generically here.)
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

-- account_monthly_balances: derive through account.
CREATE POLICY policy_owner_amb ON account_monthly_balances FOR ALL
  USING (
    EXISTS (SELECT 1 FROM accounts a WHERE a.id = account_id AND a.user_id = auth.uid())
  );

-- Junction table: derive ownership through the transaction's user_id.
CREATE POLICY policy_owner_txn_tags ON transaction_tags FOR ALL
  USING (
    EXISTS (SELECT 1 FROM transactions t WHERE t.id = transaction_id AND t.user_id = auth.uid())
  );

-- ============================================================
-- TRIGGERS: recalculate account_monthly_balances
-- ============================================================

-- Core recalculation function: given an account and a starting month,
-- recomputes all balances from that month forward.
-- Formula: balance(M) = balance(M-1) + net_txns(M)
--          balance(first) = starting_balance + net_txns(first)
CREATE OR REPLACE FUNCTION fn_recalc_balances_from(
  p_account_id UUID,
  p_from_month TEXT  -- 'YYYY-MM'
)
RETURNS void AS $$
DECLARE
  prev_balance BIGINT;
  month_row    RECORD;
  net          BIGINT;
BEGIN
  -- Get the balance from the month before p_from_month.
  -- If none exists, fall back to the account's starting_balance.
  SELECT balance INTO prev_balance
  FROM account_monthly_balances
  WHERE account_id = p_account_id AND year_month < p_from_month
  ORDER BY year_month DESC LIMIT 1;

  IF prev_balance IS NULL THEN
    SELECT starting_balance INTO prev_balance
    FROM accounts WHERE id = p_account_id;
  END IF;

  -- Iterate through every month from p_from_month onward and recalculate
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

-- Trigger function: called on INSERT, UPDATE, or DELETE of transactions.
-- Determines which account(s) and month(s) are affected, then cascades.
CREATE OR REPLACE FUNCTION fn_transaction_balance_trigger()
RETURNS TRIGGER AS $$
DECLARE
  affected RECORD;
BEGIN
  -- Collect all (account_id, year_month) pairs that need recalculation.
  -- Use a temp table to deduplicate when UPDATE changes account or date.
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

  -- For each affected account, recalculate from the earliest affected month
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
-- CRON: create monthly balance rows on the 1st of each month
-- ============================================================
-- Ensures every active account has a balance row for the new month,
-- initialized to the previous month's balance (no transactions yet).
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

-- Schedule via pg_cron: midnight UTC on the 1st of every month
-- SELECT cron.schedule('create-monthly-balance-rows', '0 0 1 * *', 'SELECT fn_create_monthly_balance_rows()');

-- ============================================================
-- TRIGGERS: updated_at auto-touch
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
      'user_settings','accounts','budgets','fixed_expenses',
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
-- VIEWS: dashboard helpers
-- ============================================================

-- Current balance per account (latest month in the ledger)
CREATE OR REPLACE VIEW v_account_current_balance AS
SELECT DISTINCT ON (account_id)
  account_id,
  year_month,
  balance AS current_balance
FROM account_monthly_balances
ORDER BY account_id, year_month DESC;

-- Monthly cash flow for a given month
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

-- Budget progress: spent vs. limit per budget per month, with carry-over
-- computed live (no stored column). Carry-over is always on and compounds along
-- each (user_id, name) lineage; a missing preceding month breaks the
-- chain and resets carry-in to 0. spent is NET: linked expenses minus linked income.
--   effective_amount = periodic_amount + carry_in
--   remaining        = effective_amount - spent   (carries into the next month)
CREATE OR REPLACE VIEW v_budget_progress AS
WITH RECURSIVE spent AS (
  SELECT
    b.id AS budget_id,
    COALESCE(SUM(CASE WHEN t.type = 'income' THEN -t.amount
                      ELSE t.amount END), 0)::BIGINT AS spent
  FROM budgets b
  LEFT JOIN transactions t
    ON t.budget_id = b.id AND t.status = 'confirmed'
  GROUP BY b.id
),
base AS (
  SELECT b.*, s.spent,
         to_char(to_date(b.year_month, 'YYYY-MM') - interval '1 month', 'YYYY-MM') AS prev_month
  FROM budgets b
  JOIN spent s ON s.budget_id = b.id
),
chain AS (
  -- Anchors: no same-lineage row in the immediately preceding month -> carry_in = 0
  SELECT b.id, b.user_id, b.name, b.year_month, b.periodic_amount, b.spent,
         0::BIGINT AS carry_in,
         b.periodic_amount - b.spent AS remaining
  FROM base b
  WHERE NOT EXISTS (
    SELECT 1 FROM base p
    WHERE p.user_id = b.user_id AND p.name = b.name
      AND p.year_month = b.prev_month
  )
  UNION ALL
  -- Recurse forward into the next consecutive month of the same lineage (compounding)
  SELECT n.id, n.user_id, n.name, n.year_month, n.periodic_amount, n.spent,
         c.remaining AS carry_in,
         n.periodic_amount + c.remaining - n.spent AS remaining
  FROM chain c
  JOIN base n
    ON n.user_id = c.user_id AND n.name = c.name
   AND n.year_month = to_char(to_date(c.year_month, 'YYYY-MM') + interval '1 month', 'YYYY-MM')
)
SELECT
  id AS budget_id,
  user_id,
  name AS budget_name,
  year_month,
  periodic_amount,
  carry_in AS carry_over_amount,
  periodic_amount + carry_in AS effective_amount,
  spent,
  periodic_amount + carry_in - spent AS remaining
FROM chain;

-- Spending by category for a given month. Category is single-select
-- (transactions.category_id), so each expense counts toward exactly one slice
-- and the slices sum to total expenses (no double-counting).
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
JOIN categories c ON c.id = t.category_id
WHERE t.type = 'expense' AND t.status = 'confirmed'
GROUP BY t.user_id, to_char(t.date, 'YYYY-MM'), c.id, c.name, c.icon, c.color;

-- Transactions list source. Aggregates each transaction's tag IDs into a
-- tag_ids array so the tag facet (including "untagged") becomes an ordinary SQL
-- predicate (tag_ids && '{…}' / tag_ids = '{}'). That keeps the whole list query
-- server-side and paginatable (.range + count); see §4.9. SECURITY INVOKER so
-- the base tables' RLS still scopes rows to the owner.
CREATE OR REPLACE VIEW v_transactions
WITH (security_invoker = on) AS
SELECT
  t.*,
  COALESCE(
    array_agg(tt.tag_id) FILTER (WHERE tt.tag_id IS NOT NULL),
    '{}'::uuid[]
  ) AS tag_ids
FROM transactions t
LEFT JOIN transaction_tags tt ON tt.transaction_id = t.id
GROUP BY t.id;

-- Each account's balance as of a selected month: the latest ledger row at or
-- before that month (balances carry forward across empty months). Returns at
-- most one row per account regardless of history depth; the dashboard Accounts
-- card calls this for the month it is showing. SECURITY INVOKER so the
-- account_monthly_balances RLS policy still scopes rows to the owner.
CREATE OR REPLACE FUNCTION fn_account_balances_at(p_year_month TEXT)
RETURNS TABLE (account_id UUID, year_month TEXT, balance BIGINT)
LANGUAGE sql
STABLE
SECURITY INVOKER
SET search_path = public
AS $$
  SELECT DISTINCT ON (amb.account_id)
    amb.account_id, amb.year_month, amb.balance
  FROM account_monthly_balances amb
  WHERE amb.year_month <= p_year_month
  ORDER BY amb.account_id, amb.year_month DESC;
$$;
```

---

## 3. Table Summary

| # | Table | Purpose | Key Columns |
|---|---|---|---|
| 1 | `currencies` | Reference table of supported ISO 4217 currency codes | `code` (PK), `name`, `symbol`, `decimal_places` |
| 2 | `user_settings` | Per-user preferences (e.g., default currency) | `user_id` (PK), `default_currency` |
| 3 | `accounts` | Bank accounts, wallets, cash, credit cards | `name`, `type`, `starting_balance`, `image_url` (avatar) |
| 3b | `account_monthly_balances` | End-of-month running balance per account | `account_id` (PK), `year_month` (PK), `balance` |
| 4 | `categories` | Expense/income categories (Food, Salary…) | `name`, `icon`, `color` |
| 5 | `tags` | Free-form labels on transactions | `name` |
| 6 | `budgets` | Self-contained monthly budget entries (identity = name) | `name`, `year_month`, `periodic_amount` (carry-over computed in `v_budget_progress`) |
| 8 | `fixed_expenses` | Monthly fixed expense entries with period-specific amounts | `name`, `year_month`, `amount`, `due_day`, `is_active` (paid = has linked txn) |
| 9 | `scheduled_transactions` | Templates for auto-recorded transactions | `account_id`, `type`, `amount`, `recurrence`, `next_due_date` |
| 10 | `transactions` | All financial movements | `account_id`, `type`, `status`, `amount`, `date`, `category_id`, `budget_id`, `fixed_expense_id` |
| 11 | `transaction_tags` | Many-to-many: transaction ↔ tag | `transaction_id`, `tag_id` |

---

## 4. Design Rationale & Key Patterns

### 4.1 Period-Specific Records (Budget & Fixed Expense)

The requirement states that budgets and fixed expenses are **period-specific** — the amount can change between months, and deleting the parent should not erase historical data.

**Budgets** use the same **flat, self-contained** pattern as fixed expenses: each row in `budgets` represents one budget for one specific month, carrying both the identity (`user_id`, `name`) and the period-specific detail (`year_month`, `periodic_amount`). A budget's identity is **name** — `UNIQUE(user_id, name, year_month)` prevents duplicates.

When the user "removes" a budget in July, we simply stop creating new `budgets` rows from July onward. May and June rows remain untouched. There is no separate header or periods table. A budget row also carries an optional free-text `description` (note). Like fixed expenses, budgets provide a **"Copy from Previous Month"** action that duplicates month M-1's budget rows into month M (preserving `name`, `description`, and `periodic_amount`), skipping any name already present in month M.

**Fixed expenses** use a **flat, self-contained** pattern: each row in `fixed_expenses` represents one fixed expense for one specific month. The table carries both the identity (`name`, `user_id`) and the period-specific details (`year_month`, `amount`, `due_day`). A UNIQUE constraint on `(user_id, name, year_month)` prevents duplicates. To set up a new month, the user copies entries from the previous month (amounts can be adjusted). Historical entries are preserved even if the user stops copying forward.

The app provides a **"Copy from Previous Month"** action: it duplicates all active fixed expense rows from month M-1 into month M, preserving each entry's name, amount, and due day. The user can then edit individual entries as needed.

### 4.2 Budget Carry-Over

Carry-over allows unspent budget (or overspend) to roll into the next month. It is **always on** for every budget — there is no toggle — and it is **computed live** in `v_budget_progress` rather than stored. Because nothing is frozen, editing a past month's `periodic_amount` or adding/removing a linked transaction automatically recomputes every later month in the lineage.

**How it works:**

1. A budget lineage is the set of `budgets` rows sharing the same `(user_id, name)`. Carry-over chains forward through that lineage one month at a time.
2. **`spent`** for a month is the net of its linked confirmed transactions: `SUM(expenses) - SUM(income)`. Income/refunds linked to the budget reduce spend (add back to remaining).
3. **`carry_in(M)`** comes from the **immediately preceding month** (M-1) of the same lineage: `carry_in(M) = remaining(M-1)`. If there is no row for M-1 in this lineage (first month, or a gap because the budget was removed), `carry_in(M) = 0` — the gap resets the chain.
4. **`effective_amount(M)` = `periodic_amount(M) + carry_in(M)`**, and **`remaining(M)` = `effective_amount(M) - spent(M)`**. `remaining(M)` then becomes `carry_in(M+1)`, so surpluses and overspends **compound** down an unbroken run of months.
5. Progress bars and badges read `effective_amount`, `spent`, `remaining`, and `carry_over_amount` (= `carry_in`) directly from `v_budget_progress`.

**Example** (single "Food" lineage, unbroken May–Jul):

| Month | periodic_amount | carry_in | effective_amount | spent (net) | remaining |
|---|---|---|---|---|---|
| May 2026 | $300 | $0 (first month) | $300 | $290 | +$10 |
| Jun 2026 | $400 | +$10 (surplus) | $410 | $430 | −$20 |
| Jul 2026 | $400 | −$20 (overspend) | $380 | $350 | +$30 |

If "Food" were removed in June and re-added in July, July's `carry_in` would be $0 (the May→July gap breaks the chain). A "Food" budget in EUR would form a completely separate lineage with its own chain.

### 4.3 Account Monthly Balances (Running Balance Ledger)

Instead of storing a single `current_balance` on the `accounts` table, balances are tracked in the `account_monthly_balances` table — one row per account per month, similar to a spreadsheet where each cell's formula references the cell above it.

**Formula:**

```
balance(first month) = starting_balance + net confirmed transactions in that month
balance(M)           = balance(M-1)     + net confirmed transactions in M
```

Where `net confirmed transactions` = `SUM(income) - SUM(expense) ± transfers` for confirmed transactions in that month.

**How it stays up to date:**

1. **Transaction trigger** — Any INSERT, UPDATE, or DELETE on `transactions` fires `fn_transaction_balance_trigger()`. It determines the affected account(s) and earliest affected month, then cascades recalculation forward through all subsequent months via `fn_recalc_balances_from()`.
2. **Monthly cron job** — `fn_create_monthly_balance_rows()` runs on the 1st of each month via `pg_cron`. It creates a new row for every active (non-archived) account, initialized to the previous month's balance. This ensures a balance row always exists for the current month, even if no transactions have been recorded yet.
3. **Account creation** — When a new account is created, the app inserts a balance row for the current month with `balance = starting_balance`.

**Example (Checking account, starting_balance = $5,000):**

| year_month | net_txns | balance | How computed |
|---|---|---|---|
| 2026-01 | +$3,000 income, -$1,200 expense = +$1,800 | $6,800 | $5,000 + $1,800 |
| 2026-02 | -$900 expense | $5,900 | $6,800 + (-$900) |
| 2026-03 | (no transactions) | $5,900 | $5,900 + $0 (cron-created) |
| 2026-04 | +$3,000 income, -$2,100 expense = +$900 | $6,800 | $5,900 + $900 |

If the user edits a January transaction, the trigger recalculates January → February → March → April — exactly like a spreadsheet cascade.

**To get the "current balance" of an account**, clients query the latest row:

```sql
SELECT balance FROM account_monthly_balances
WHERE account_id = ? ORDER BY year_month DESC LIMIT 1;
```

### 4.4 Transfers

A transfer is modeled as a **single transaction row** with both `account_id` (source) and `transfer_account_id` (destination). This avoids the complexity of double-entry bookkeeping while still correctly adjusting both account balances via the trigger.

### 4.5 Auto-Record / Scheduled Transactions

The `scheduled_transactions` table holds the recurring template. A **cron job** (Supabase `pg_cron` or Edge Function) runs daily:

1. Queries `scheduled_transactions WHERE is_active = TRUE AND next_due_date <= today`
2. For each match, inserts a new `transactions` row with `status = 'pending'`
3. Advances `next_due_date` to the next recurrence date
4. Sends a push notification to the user

The user then **confirms**, **edits**, or **dismisses** the pending transaction from the app. Only confirmed transactions affect account balances (enforced by the trigger).

### 4.6 Dashboard Queries

The dashboard is **month-scoped**: a month navigator drives every widget, and each is fetched for the selected `year_month`. The client hook issues the reads in parallel and re-runs them on realtime changes to `transactions`, `budgets`, `fixed_expenses`, `accounts`, and `account_monthly_balances`.

| Widget | Source | What it reads |
|---|---|---|
| **Budget Verdict** | `v_budget_progress` | Every budget for the month; the banner counts those with `remaining < 0` and sums the overage. |
| **Accounts** | `accounts` + `fn_account_balances_at` | Active accounts with `show_on_dashboard = true`, joined to each account's end-of-month balance at the selected month (see below). |
| **Planned Expenses** | `v_budget_progress` + `fixed_expenses` | Budgets (with `effective_amount`, `spent`, `remaining` for pace-aware bars) and every fixed expense for the month; paid status is derived from linked `transactions` (`fixed_expense_id`). |
| **Unplanned Expenses** | `transactions` | Confirmed expenses for the month with `budget_id IS NULL` **and** `fixed_expense_id IS NULL`, aggregated by category in the client (null category → "Uncategorized"). |

**Per-month account balances — `fn_account_balances_at(p_year_month)`.** Balances live in `account_monthly_balances` and carry forward across empty months, so an account's balance "as of month M" is the latest ledger row at or before M. `v_account_current_balance` answers this only for the latest month overall; the function is the parameterized version, returning **at most one row per account** (`DISTINCT ON (account_id)` over `year_month <= p_year_month`, ordered `year_month DESC`) regardless of how far back M is. It is `SECURITY INVOKER` so `account_monthly_balances` RLS still scopes rows to the owner. Accounts with no ledger row yet fall back to their `starting_balance` in the client.

> The `v_monthly_cashflow`, `v_spending_by_category`, and `v_account_current_balance` views remain defined and available, but the current dashboard does not read them — the Verdict / Accounts / Planned / Unplanned layout above replaced the original Cash-Flow / Spending-by-Category / Recent-Transactions widgets.

### 4.7 Currency Handling

- Amounts stored as `bigint` in **minor units** (e.g., 1050 = $10.50).
- A `currencies` reference table stores all supported ISO 4217 codes, names, symbols, and decimal places. `user_settings.default_currency` references this table via FK.
- The app is **single-currency**: `user_settings.default_currency` is chosen once in Settings and every amount across the app is formatted in it. There is no per-record `currency` column on accounts, transactions, budgets, scheduled transactions, or fixed expenses; the currency's `decimal_places` drive minor-unit scaling.
- **P1 — Multi-Currency Transactions:** Reintroduces per-record currency. When a transaction's currency differs from the account's currency, the user provides the exchange rate or converted amount. The transaction is recorded in its original currency, and the account balance is adjusted using the converted amount.

### 4.8 Row-Level Security

Every table has RLS enabled. Policies ensure that a user can only read/write rows where `user_id = auth.uid()`. The junction table (`transaction_tags`) derives ownership through the parent `transactions` row. `categories`, `budgets`, and `fixed_expenses` each have a direct `user_id` column and use the standard owner policy.

### 4.9 Transaction Filtering & Search

The transaction list supports filtering on any combination of attributes (see the "Filtering & Search" requirements). Every filter is a **client-issued PostgREST query against the `v_transactions` view** rather than the raw `transactions` table. The view is `transactions.*` plus a `tag_ids` array (tag IDs aggregated from `transaction_tags`); reading through it lets the tag facet — including "untagged" — be expressed as ordinary SQL, so the *entire* query is server-side and can be windowed with `.range()` + `count: 'exact'` for accurate pagination. RLS still scopes every query to the current user (the view is `SECURITY INVOKER`), so filters compose on top of an owner-only row set.

**Combination semantics:** filters across different dimensions are `AND`-ed; multiple values within one multi-select dimension are `OR`-ed. Each multi-select facet is **tri-state**: *absent* = no filter (the default "all"), *non-empty* = match any listed value, *present-but-empty* = match nothing (the user unchecked every option) — an empty facet short-circuits the whole query to no results. The category, tag, budget, and fixed-expense facets may also include a sentinel `(Blanks)` value that matches rows with **no** value for that facet.

A single `applyFilters` helper builds the predicate set, and is shared by the paginated **list** query and the whole-set **Summary** query so their constraints can never drift.

**Column-level facets** map directly to PostgREST operators and are backed by existing indexes:

| Filter | Query mapping | Index |
|---|---|---|
| Search (description) | `ilike('description', '%term%')` | none (sequential scan over the user's rows; acceptable for a single-user dataset) |
| Type | `in('type', types)` (matches ANY selected) | `idx_txn_type_date` |
| Account | `or('account_id.eq.X,transfer_account_id.eq.X', …)` over every selected account (matches the source **or** the transfer side) | `idx_txn_account` |
| Status | `in('status', statuses)` (matches ANY selected) | `idx_txn_status` |
| Date range | `gte('date', from)` / `lte('date', to)` | `idx_txn_date` |
| Amount range | `gte('amount', min)` / `lte('amount', max)` | none (acceptable for single-user) |
| Category | `or('category_id.in.(ids)', 'category_id.is.null')` — selected ids and/or `(Blanks)` | `idx_txn_category` |
| Tag | `or('tag_ids.ov.{ids}', 'tag_ids.eq.{}')` over the view's `tag_ids` array — overlap for selected tags, empty-array for `(Blanks)` | — (array predicate on the view) |

Amounts are filtered in **minor units** (`bigint`) — the client converts the user's major-unit input via `toMinorUnits()` before querying. Date bounds are inclusive `YYYY-MM-DD` strings.

**Tag filter (array predicate).** Because the read goes through `v_transactions`, tags are no longer a junction pre-query: the chosen tag IDs become `tag_ids && '{…}'` (overlap = carries **any** selected tag), and the `(Blanks)/untagged` option becomes `tag_ids = '{}'`. Both are `OR`-ed within the facet, so the tag filter stays a single server-side predicate and never blocks pagination.

**Budget & fixed-expense filters (by name).** Both budgets and fixed expenses are month-specific rows sharing a **name**, so these facets select **names**, not single ids, resolved to an id set with a pre-query and applied as `in('budget_id', …)` / `in('fixed_expense_id', …)`:

1. Budget names resolve through **`v_budget_progress`** (the same view the Budgets page and the transaction budget picker use — not the `budgets` table — so the filter offers exactly the budgets surfaced elsewhere): `v_budget_progress.select('budget_id').in('budget_name', names)`. Fixed-expense names resolve through `fixed_expenses.select('id').in('name', names)`.
2. When a **date range** is also active, the rows are narrowed to the months the range spans via `gte('year_month', fromYM)` / `lte('year_month', toYM)`, where `fromYM`/`toYM` are the `YYYY-MM` prefixes of the date bounds. (Example: a 2026-05-30 → 2026-06-03 range matches rows in `2026-05` and `2026-06`.) With no date range, every period of that name is included.
3. The resolved ids are combined with the facet's `(Blanks)` option as a single `or(…)` clause (e.g. `budget_id.in.(ids),budget_id.is.null`). If named values were chosen but none resolved (and `(Blanks)` was not), the whole query short-circuits to no results. The transaction `date` filter still applies independently, so the final rows are those linked to the named budget/fixed expense **and** within any selected date range.

The selectable budget **names** for the filter UI are read from `v_budget_progress` (distinct `budget_name`) and the fixed-expense names from `fixed_expenses`, both scoped by the same optional month range so the options reflect the active date filter.

This keeps filtering entirely server-side and paginatable. For a single-user app the row counts are small enough that the un-indexed `description ilike`, `amount` range, and array overlap scans are not a concern; the text/amount filters are natural candidates for a trigram / btree index should multi-user scale ever be introduced (P1).

**Summary.** The Summary view re-runs `applyFilters` against `v_transactions` but selects only the money/grouping columns for the *whole* filtered set (every page, fetched on demand when the dialog opens), then hydrates account/category/budget/fixed/tag names client-side to build totals and per-facet breakdowns. Money math counts confirmed rows only (pending surfaced separately as a projection, dismissed excluded); transfers are reported as "transfer out" / "transfer in" rather than income or expense.

### 4.10 Account Avatar Images (Supabase Storage)

Accounts can carry a custom avatar image (e.g. a bank or card logo). Images live in a **public** Supabase Storage bucket named `account-images`; the resulting public URL is stored in `accounts.image_url`. When `image_url` is null, clients fall back to an icon derived from `account_type`.

**Why a public bucket.** Reads are open so a stored permanent URL renders directly in an `<img>` with no signed-URL refresh. Object paths are laid out as `{user_id}/{uuid}.webp`, so the first path segment identifies the owner, and the random filename keeps URLs unguessable. Writes (insert/update/delete) are restricted to the owner's own folder via RLS on `storage.objects`:

```sql
INSERT INTO storage.buckets (id, name, public)
VALUES ('account-images', 'account-images', TRUE)
ON CONFLICT (id) DO NOTHING;

-- Public read; owner-only writes scoped by the first path segment.
CREATE POLICY "account_images_public_read"
  ON storage.objects FOR SELECT USING (bucket_id = 'account-images');

CREATE POLICY "account_images_owner_insert"
  ON storage.objects FOR INSERT WITH CHECK (
    bucket_id = 'account-images'
    AND (storage.foldername(name))[1] = auth.uid()::text
  );
-- ...matching owner-only UPDATE and DELETE policies.
```

**Client responsibilities.** The upload happens on form submit (so cancelling never orphans a file). The client downsizes the picked image to ≤256px and re-encodes it to WebP before upload, keeping objects to a few KB — well within the free-tier 1 GB and avoiding the paid image-transform add-on. When an image is replaced or removed, the previous object is deleted best-effort after the row save succeeds.

**Where the image surfaces.** The account list card, the account detail header, the form preview, and the **dashboard Accounts card** render it via the shared `AccountAvatar` (image, else type icon). The **transaction list** reuses the account image too: its avatar shows the logo when the linked account has one (keeping the small transaction-direction badge), and falls back to colored initials otherwise — so the queries that hydrate transaction rows select `accounts.image_url` alongside the name.

### 4.11 Budget Installments (P1) — Spreading an Expense Across Budgets

This feature absorbs a large one-off expense gradually by **reserving future budget allowance**, without ever touching account balances. The design keeps the two domains the schema already separates — **money** (transactions → accounts) and **budget bookkeeping** (transactions ↔ budgets) — completely independent: the installment lives entirely on the budget side.

**Core idea.** The expense itself is one ordinary `transactions` row that debits the account in full (the account ledger and cash-flow views are untouched, and that row's `budget_id` is left **NULL** so it does not also count as the current month's spend). A separate pair of tables records a budget-side **reservation grid**, and `v_budget_progress` subtracts those reservations from each affected budget month. A reservation is *not* money and never enters `transactions`, so it physically cannot affect an account balance.

**Two new tables:**

```sql
-- One header per spread expense.
CREATE TABLE budget_installments (
  id                    UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  user_id               UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  source_transaction_id UUID NOT NULL REFERENCES transactions(id) ON DELETE CASCADE,
  total_amount          BIGINT NOT NULL CHECK (total_amount > 0),  -- minor units; = the expense
  description           TEXT,
  start_year_month      TEXT NOT NULL,    -- 'YYYY-MM'; first reserved month (display convenience)
  months                SMALLINT NOT NULL CHECK (months > 0),      -- span (display convenience)
  created_at            TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at            TIMESTAMPTZ NOT NULL DEFAULT now()
);
CREATE INDEX idx_budget_installments_user ON budget_installments(user_id);
CREATE INDEX idx_budget_installments_txn  ON budget_installments(source_transaction_id);

-- The budgets x months reservation grid. One row per non-zero cell.
-- Targets a budget LINEAGE by name (budgets are per-month rows), not a budget id,
-- so a reservation survives edits to that month's budget row and works even before
-- the target month's budget row exists.
CREATE TABLE budget_installment_allocations (
  id             UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  installment_id UUID NOT NULL REFERENCES budget_installments(id) ON DELETE CASCADE,
  user_id        UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  budget_name    TEXT NOT NULL,                 -- the budget lineage this cell reserves from
  year_month     TEXT NOT NULL,                 -- 'YYYY-MM'
  amount         BIGINT NOT NULL CHECK (amount > 0),   -- reserved minor units (zero cells not stored)
  created_at     TIMESTAMPTZ NOT NULL DEFAULT now(),
  UNIQUE (installment_id, budget_name, year_month)
);
CREATE INDEX idx_bia_lookup ON budget_installment_allocations(user_id, budget_name, year_month);
```

**View change.** `v_budget_progress` gains a `reserved` term, summed per `(user_id, budget_name, year_month)` and matched to each budget month, then subtracted inside the recursive `remaining`. Because `remaining` feeds the next month's `carry_in`, the reservation lowers the month's pool and only the *true leftover* carries — the **"subtract from effective, then carry normally"** rule (the reservation is use-it-or-lose-it; an overspend still carries as before):

```sql
-- New CTE folded into v_budget_progress:
reserved AS (
  SELECT user_id, budget_name, year_month, SUM(amount)::BIGINT AS reserved
  FROM budget_installment_allocations
  GROUP BY user_id, budget_name, year_month
)
-- base joins reserved on (user_id, name, year_month), COALESCE(reserved, 0).
-- Anchor:   remaining = periodic_amount - spent - reserved
-- Recurse:  remaining = periodic_amount + carry_in - spent - reserved
-- Output adds a `reserved` column; effective_amount stays periodic + carry_in.
```

**Materialization (lineage continuity).** Budgets are per-month rows, so a target future month may have no budget row yet — which would leave the reservation homeless *and* break carry-over (a gap resets the chain). When an installment is created, each distinct `(budget_name, year_month)` cell **upserts a `budgets` row if absent** (`INSERT … ON CONFLICT (user_id, name, year_month) DO NOTHING`), defaulting `periodic_amount` to the latest known value in that lineage at or before the month (else 0). This keeps the reservation visible and the lineage unbroken.

**Lifecycle.**

- **Cancel installment** → delete the `budget_installments` row; `ON DELETE CASCADE` clears its allocations, future budgets recompute, and the full allowance returns. Materialized `budgets` rows remain as ordinary rows.
- **Delete the source expense** → `ON DELETE CASCADE` from `transactions` removes the installment and its allocations (a spread with no source is meaningless).
- **RLS** — both tables carry `user_id` directly and use the standard owner policy (`user_id = auth.uid()`). Add both to the `supabase_realtime` publication so the Budgets page refreshes live.

---

## 5. P1 Extension Points

| Feature | Schema Impact |
|---|---|
| **Receipt Scanning** | Add `receipt_url TEXT` column to `transactions`; store images in Supabase Storage; add an Edge Function that calls an OCR/AI API and pre-fills transaction fields. |
| **Flexible Periods** | Extend `recurrence_type` enum with `'weekly'`, `'quarterly'`, `'yearly'`, `'custom'`. Add a `period_type` column to `budgets` and generalize the lineage/period key in `v_budget_progress` beyond `year_month`. Adjust cron logic. |
| **Budget Installments** | Add `budget_installments` (header, FK → source `transactions` row, `ON DELETE CASCADE`) and `budget_installment_allocations` (budgets × months reservation grid, keyed by `budget_name` + `year_month`). Fold a `reserved` term into `v_budget_progress` (`remaining = periodic + carry_in − spent − reserved`). Materialize missing budget rows on creation to keep lineages unbroken. Account balances untouched (reservations never enter `transactions`). See §4.11. |
| **Multi-Currency Transactions** | Add `original_amount BIGINT`, `original_currency TEXT`, and `exchange_rate NUMERIC` columns to `transactions`. The existing `amount` holds the converted value in the account's currency. The trigger uses `amount` for balance updates. |
| **Extended Dashboard** | Queries over `fixed_expenses` (upcoming/overdue), `transactions WHERE status = 'pending'`, and `v_monthly_cashflow` grouped over multiple months. No schema changes needed. |
