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
