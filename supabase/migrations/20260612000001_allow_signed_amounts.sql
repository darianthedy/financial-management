-- ============================================================
-- Migration: Allow signed (negative) amounts on income & expense.
--
-- Refunds for a cancelled expense arrive later, sometimes split across
-- several periods. Recording them as `income` inflates the income total even
-- though no real income occurred. Instead they should be a NEGATIVE `expense`:
-- balance impact is `-amount`, so a negative amount adds cash back AND reduces
-- the expense/category/budget totals — never touching income.
--
-- We relax the positivity check accordingly:
--   * income / expense — any non-zero amount (positive or negative)
--   * transfer         — still strictly positive (a "negative transfer" is
--                        just the reverse transfer; express it by swapping the
--                        source and destination accounts instead)
--   * zero             — still disallowed for every type (a 0 transaction is
--                        meaningless and would clutter totals)
--
-- The old `transactions_amount_check` (CHECK (amount > 0), created inline with
-- the column) is replaced by a table-level check that can reference `type`.
-- ============================================================

BEGIN;

ALTER TABLE transactions
  DROP CONSTRAINT IF EXISTS transactions_amount_check;

ALTER TABLE transactions
  ADD CONSTRAINT transactions_amount_check
  CHECK (amount <> 0 AND (type <> 'transfer' OR amount > 0));

COMMIT;
