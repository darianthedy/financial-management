-- Per-account toggle for whether the account appears on the dashboard.
--
-- The dashboard's Accounts card lists every active account and totals their
-- balances. This lets a user hide individual accounts (and their balance) from
-- that card without archiving them. Defaults to TRUE so existing accounts keep
-- showing; NOT NULL keeps the flag unambiguous for every row.
ALTER TABLE accounts
  ADD COLUMN show_on_dashboard BOOLEAN NOT NULL DEFAULT TRUE;
