CREATE OR REPLACE VIEW v_monthly_cashflow AS
SELECT
  user_id,
  to_char(date, 'YYYY-MM') AS year_month,
  SUM(CASE WHEN type = 'income'  THEN amount ELSE 0 END) AS total_income,
  SUM(CASE WHEN type = 'expense' THEN amount ELSE 0 END) AS total_expense,
  SUM(CASE WHEN type = 'income'  THEN amount ELSE 0 END)
    - SUM(CASE WHEN type = 'expense' THEN amount ELSE 0 END) AS net
FROM transactions
WHERE status = 'confirmed'
GROUP BY user_id, to_char(date, 'YYYY-MM');

CREATE OR REPLACE VIEW v_budget_progress AS
SELECT
  bp.id AS budget_period_id,
  b.id AS budget_id,
  b.name AS budget_name,
  b.enable_carry_over,
  bp.year_month,
  bp.periodic_amount,
  bp.carry_over_amount,
  bp.periodic_amount + bp.carry_over_amount AS effective_amount,
  bp.currency,
  COALESCE(SUM(t.amount), 0) AS spent,
  (bp.periodic_amount + bp.carry_over_amount) - COALESCE(SUM(t.amount), 0) AS remaining
FROM budget_periods bp
JOIN budgets b ON b.id = bp.budget_id
LEFT JOIN transactions t
  ON t.budget_period_id = bp.id
  AND t.status = 'confirmed'
GROUP BY bp.id, b.id, b.name, b.enable_carry_over,
         bp.year_month, bp.periodic_amount, bp.carry_over_amount, bp.currency;

CREATE OR REPLACE VIEW v_spending_by_category AS
SELECT
  t.user_id,
  to_char(t.date, 'YYYY-MM') AS year_month,
  c.id AS category_id,
  c.name AS category_name,
  c.icon,
  c.color,
  SUM(t.amount) AS total_amount
FROM transactions t
JOIN transaction_categories tc ON tc.transaction_id = t.id
JOIN categories c ON c.id = tc.category_id
WHERE t.type = 'expense' AND t.status = 'confirmed'
GROUP BY t.user_id, to_char(t.date, 'YYYY-MM'), c.id, c.name, c.icon, c.color;
