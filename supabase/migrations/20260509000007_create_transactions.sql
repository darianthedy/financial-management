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
  updated_at            TIMESTAMPTZ NOT NULL DEFAULT now(),

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
