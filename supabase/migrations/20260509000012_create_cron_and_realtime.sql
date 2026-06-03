-- PL/pgSQL function to generate pending transactions from scheduled_transactions.
-- Called daily by pg_cron. This keeps everything inside Postgres without HTTP overhead.
CREATE OR REPLACE FUNCTION fn_generate_pending_transactions()
RETURNS void AS $$
DECLARE
  sched RECORD;
  next_date DATE;
BEGIN
  FOR sched IN
    SELECT * FROM scheduled_transactions
    WHERE is_active = TRUE AND next_due_date <= CURRENT_DATE
  LOOP
    INSERT INTO transactions (
      user_id, account_id, type, status, amount, currency,
      description, date, scheduled_txn_id
    ) VALUES (
      sched.user_id, sched.account_id, sched.type, 'pending',
      sched.amount, sched.currency, sched.description,
      sched.next_due_date, sched.id
    );

    next_date := sched.next_due_date + INTERVAL '1 month';
    UPDATE scheduled_transactions
    SET next_due_date = next_date, updated_at = now()
    WHERE id = sched.id;
  END LOOP;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Enable Realtime on tables that clients subscribe to
ALTER PUBLICATION supabase_realtime ADD TABLE transactions;
ALTER PUBLICATION supabase_realtime ADD TABLE accounts;
ALTER PUBLICATION supabase_realtime ADD TABLE budget_periods;
ALTER PUBLICATION supabase_realtime ADD TABLE fixed_expenses;
