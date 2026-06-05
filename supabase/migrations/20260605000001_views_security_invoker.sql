-- ============================================================
-- MIGRATION: Enforce RLS through views (security_invoker)
--
-- Cross-user data leak: every reporting view in the schema was created
-- with the Postgres default security_invoker = false. A view created
-- that way executes with the privileges of its OWNER (postgres), not
-- the querying user, so Row Level Security on the underlying tables
-- (budgets, transactions, accounts: "user_id = auth.uid()") is NOT
-- applied when data is read through the view.
--
-- Concretely: the Budgets page reads v_budget_progress with no explicit
-- user_id filter, trusting RLS to scope rows -- but the view bypassed
-- RLS, so it returned every user's budgets.
--
-- Postgres 15+ (and Supabase) support per-view security_invoker. Setting
-- it true makes each view run with the caller's privileges, so the base
-- tables' RLS policies apply and each user sees only their own rows.
-- ============================================================

ALTER VIEW v_budget_progress        SET (security_invoker = true);
ALTER VIEW v_monthly_cashflow       SET (security_invoker = true);
ALTER VIEW v_spending_by_category   SET (security_invoker = true);
ALTER VIEW v_account_current_balance SET (security_invoker = true);
