ALTER TABLE accounts                ENABLE ROW LEVEL SECURITY;
ALTER TABLE categories              ENABLE ROW LEVEL SECURITY;
ALTER TABLE tags                    ENABLE ROW LEVEL SECURITY;
ALTER TABLE budgets                 ENABLE ROW LEVEL SECURITY;
ALTER TABLE budget_periods          ENABLE ROW LEVEL SECURITY;
ALTER TABLE fixed_expenses          ENABLE ROW LEVEL SECURITY;
ALTER TABLE scheduled_transactions  ENABLE ROW LEVEL SECURITY;
ALTER TABLE transactions            ENABLE ROW LEVEL SECURITY;
ALTER TABLE transaction_categories  ENABLE ROW LEVEL SECURITY;
ALTER TABLE transaction_tags        ENABLE ROW LEVEL SECURITY;

-- Owner-based policies for tables with direct user_id
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

-- Junction tables: derive ownership through the transaction's user_id
CREATE POLICY policy_owner_txn_categories ON transaction_categories FOR ALL
  USING (
    EXISTS (SELECT 1 FROM transactions t WHERE t.id = transaction_id AND t.user_id = auth.uid())
  );

CREATE POLICY policy_owner_txn_tags ON transaction_tags FOR ALL
  USING (
    EXISTS (SELECT 1 FROM transactions t WHERE t.id = transaction_id AND t.user_id = auth.uid())
  );

-- budget_periods: derive ownership through budget
CREATE POLICY policy_owner_budget_periods ON budget_periods FOR ALL
  USING (
    EXISTS (SELECT 1 FROM budgets b WHERE b.id = budget_id AND b.user_id = auth.uid())
  );
