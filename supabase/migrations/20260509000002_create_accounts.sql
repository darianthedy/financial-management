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

-- Running balance ledger: one row per account per month.
-- balance(M) = balance(M-1) + net confirmed transactions in M
CREATE TABLE account_monthly_balances (
  account_id  UUID NOT NULL REFERENCES accounts(id) ON DELETE CASCADE,
  year_month  TEXT NOT NULL,
  balance     BIGINT NOT NULL DEFAULT 0,
  updated_at  TIMESTAMPTZ NOT NULL DEFAULT now(),
  PRIMARY KEY (account_id, year_month)
);

CREATE INDEX idx_amb_account ON account_monthly_balances(account_id);
CREATE INDEX idx_amb_month   ON account_monthly_balances(year_month);
