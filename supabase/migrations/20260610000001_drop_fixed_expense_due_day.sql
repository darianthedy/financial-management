-- ============================================================
-- Migration: Drop the `due_day` column from fixed_expenses.
--
-- Fixed expenses are tracked per month with a paid status derived from linked
-- transactions; the day-of-month was display-only noise and is being removed
-- from the UI. Dropping the column also drops its CHECK constraint(s)
-- (fixed_expenses_due_day_check / chk_due_day) automatically.
-- ============================================================

ALTER TABLE fixed_expenses DROP COLUMN IF EXISTS due_day;
