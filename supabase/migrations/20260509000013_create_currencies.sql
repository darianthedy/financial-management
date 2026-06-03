CREATE TABLE currencies (
  code           TEXT PRIMARY KEY,
  name           TEXT NOT NULL,
  symbol         TEXT NOT NULL DEFAULT '',
  decimal_places SMALLINT NOT NULL DEFAULT 2,
  created_at     TIMESTAMPTZ NOT NULL DEFAULT now()
);

ALTER TABLE currencies ENABLE ROW LEVEL SECURITY;

CREATE POLICY policy_currencies_read ON currencies FOR SELECT
  USING (auth.role() = 'authenticated');
