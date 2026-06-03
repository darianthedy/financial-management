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
