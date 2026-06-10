-- Per-user preferred account, pre-selected when adding a new transaction.
-- Nullable: a user may have no default. ON DELETE SET NULL so removing the
-- account quietly clears the preference rather than blocking the delete.
ALTER TABLE user_settings
  ADD COLUMN default_account_id UUID REFERENCES accounts(id) ON DELETE SET NULL;
