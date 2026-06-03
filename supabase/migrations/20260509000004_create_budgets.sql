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
  year_month        TEXT NOT NULL,  -- format: 'YYYY-MM'
  periodic_amount   BIGINT NOT NULL,
  carry_over_amount BIGINT NOT NULL DEFAULT 0,
  currency          TEXT NOT NULL DEFAULT 'USD',
  created_at        TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at        TIMESTAMPTZ NOT NULL DEFAULT now(),

  UNIQUE(budget_id, year_month)
);

CREATE INDEX idx_budget_periods_budget ON budget_periods(budget_id);
CREATE INDEX idx_budget_periods_month  ON budget_periods(year_month);
