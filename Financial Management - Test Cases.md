# Financial Management — Test Cases

Detailed test cases for the Financial Management application, derived from the [requirements](Financial%20Management.md) and [system design](Financial%20Management%20-%20System%20Design.md).

**Conventions:**
- All monetary amounts in examples use USD unless stated otherwise. Amounts are shown in display form (e.g., $10.50) but stored as `bigint` minor units (e.g., 1050).
- UUIDs are replaced with short labels (e.g., `acc-1`, `txn-1`) for readability.
- `year_month` follows the `YYYY-MM` format.

---

## 1. Accounts

### 1.1 Create Account

| # | Case | Input | Expected Result |
|---|------|-------|-----------------|
| 1.1.1 | Create a bank account with defaults | `name: "Checking", type: bank_account, currency: USD, starting_balance: 500000` (i.e., $5,000.00) | Account created. `is_archived` = false. An `account_monthly_balances` row is created for the current month with `balance` = 500000. |
| 1.1.2 | Create a cash account with zero balance | `name: "Wallet Cash", type: cash, starting_balance: 0` | Account created. Monthly balance row created with `balance` = 0. |
| 1.1.3 | Create a credit card account | `name: "Visa Platinum", type: credit_card, currency: USD, starting_balance: -15000` (i.e., -$150.00 owed) | Account created. Negative starting balance is acceptable for credit cards. |
| 1.1.4 | Create account with non-default currency | `name: "Savings THB", type: bank_account, currency: THB, starting_balance: 10000000` (i.e., ฿100,000.00) | Account created with `currency = 'THB'`. |
| 1.1.5 | Reject account with invalid currency | `name: "Test", currency: "ZZZ"` | Rejected — FK constraint fails because `ZZZ` does not exist in `currencies`. |
| 1.1.6 | Reject account with missing name | `name: NULL, type: bank_account` | Rejected — `name` column is `NOT NULL`. |

### 1.2 Update Account

| # | Case | Setup | Action | Expected Result |
|---|------|-------|--------|-----------------|
| 1.2.1 | Rename account | Account `acc-1` exists with name "Checking" | Update name to "Main Checking" | Name updated. `updated_at` auto-set by trigger. |
| 1.2.2 | Archive account | Account `acc-1` has `is_archived = false` | Set `is_archived = true` | Account is archived. Existing transactions remain intact. |

### 1.3 Delete Account

| # | Case | Setup | Action | Expected Result |
|---|------|-------|--------|-----------------|
| 1.3.1 | Delete account with no transactions | Account `acc-1` has zero transactions | Delete `acc-1` | Account deleted successfully. |
| 1.3.2 | Reject delete when transactions exist | Account `acc-1` is referenced by `transactions.account_id` | Delete `acc-1` | Rejected — `ON DELETE RESTRICT` prevents deletion. |
| 1.3.3 | Reject delete when account is a transfer target | Account `acc-2` is referenced by `transactions.transfer_account_id` | Delete `acc-2` | Rejected — `ON DELETE RESTRICT` prevents deletion. |

### 1.4 Row-Level Security — Accounts

| # | Case | Setup | Action | Expected Result |
|---|------|-------|--------|-----------------|
| 1.4.1 | User can read own accounts | User A owns `acc-1`, `acc-2` | User A `SELECT * FROM accounts` | Returns `acc-1`, `acc-2` only. |
| 1.4.2 | User cannot read another user's accounts | User B owns `acc-3` | User A `SELECT * FROM accounts WHERE id = acc-3` | Returns empty result. |
| 1.4.3 | User cannot insert account for another user | User A is authenticated | Insert with `user_id = User_B_id` | Rejected by RLS `WITH CHECK` policy. |

---

## 2. Transactions

### 2.1 Create Income Transaction

| # | Case | Input | Expected Result |
|---|------|-------|-----------------|
| 2.1.1 | Basic income | `account_id: acc-1 (balance: 500000), type: income, amount: 300000, date: 2026-05-01, status: confirmed` | Transaction created. `account_monthly_balances` for acc-1/2026-05 updated from 500000 → 800000 (trigger recalculates). |
| 2.1.2 | Income with description and category | `type: income, amount: 5000000, description: "May salary", date: 2026-05-01, categories: [cat-salary]` | Transaction created. Row in `transaction_categories` linking `txn-1 ↔ cat-salary`. |
| 2.1.3 | Pending income does not affect balance | `type: income, amount: 300000, status: pending` | Transaction created with `status = 'pending'`. Monthly balance unchanged (trigger skips non-confirmed). |

### 2.2 Create Expense Transaction

| # | Case | Input | Expected Result |
|---|------|-------|-----------------|
| 2.2.1 | Basic expense | `account_id: acc-1 (balance: 800000), type: expense, amount: 15000, date: 2026-05-02, status: confirmed` | Transaction created. Monthly balance for acc-1/2026-05 updated from 800000 → 785000. |
| 2.2.2 | Expense linked to budget | `type: expense, amount: 5000, budget_period_id: bp-may-food, date: 2026-05-02` | Transaction created with `budget_period_id` set. The `v_budget_progress` view reflects the spent amount. |
| 2.2.3 | Expense linked to fixed expense | `type: expense, amount: 5000, fixed_expense_id: fe-may-gym, date: 2026-05-15` | Transaction created with `fixed_expense_id` set. The fixed expense `fe-may-gym` is now considered paid (has at least one linked transaction). |
| 2.2.4 | Expense with multiple categories and tags | `type: expense, amount: 8500, categories: [cat-food, cat-entertainment], tags: [tag-weekend, tag-friends]` | Transaction created. Two rows in `transaction_categories`, two rows in `transaction_tags`. |
| 2.2.5 | Reject zero-amount expense | `type: expense, amount: 0` | Rejected — `CHECK (amount > 0)` constraint fails. |
| 2.2.6 | Reject negative-amount expense | `type: expense, amount: -5000` | Rejected — `CHECK (amount > 0)` constraint fails. |

### 2.3 Create Transfer Transaction

| # | Case | Input | Expected Result |
|---|------|-------|-----------------|
| 2.3.1 | Transfer between two accounts | `account_id: acc-1 (balance: 785000), transfer_account_id: acc-2 (balance: 200000), type: transfer, amount: 100000` | Transaction created. acc-1 monthly balance → 685000 (debited). acc-2 monthly balance → 300000 (credited). |
| 2.3.2 | Reject transfer without destination | `type: transfer, account_id: acc-1, transfer_account_id: NULL` | Rejected — `chk_transfer_account` constraint: transfer requires `transfer_account_id IS NOT NULL`. |
| 2.3.3 | Reject non-transfer with destination | `type: expense, account_id: acc-1, transfer_account_id: acc-2` | Rejected — `chk_transfer_account` constraint: non-transfer requires `transfer_account_id IS NULL`. |
| 2.3.4 | Pending transfer does not move balances | `type: transfer, amount: 50000, status: pending` | Transaction created. Neither account balance changes. |

### 2.4 Delete Transaction (Balance Reversal)

| # | Case | Setup | Action | Expected Result |
|---|------|-------|--------|-----------------|
| 2.4.1 | Delete confirmed income | acc-1 monthly balance = 800000. Income txn of 300000 exists (confirmed). | Delete the transaction | acc-1 monthly balance → 500000 (recalculated by `fn_transaction_balance_trigger`). |
| 2.4.2 | Delete confirmed expense | acc-1 monthly balance = 785000. Expense txn of 15000 exists (confirmed). | Delete the transaction | acc-1 monthly balance → 800000. |
| 2.4.3 | Delete confirmed transfer | `acc-1 = 685000, acc-2 = 300000`. Transfer of 100000 (acc-1 → acc-2) exists. | Delete the transaction | `acc-1` → 785000, `acc-2` → 200000. Both reversed. |
| 2.4.4 | Delete pending transaction | Pending txn exists. Account balances unaffected. | Delete the transaction | Transaction deleted. No balance change (trigger skips `status != 'confirmed'`). |

### 2.5 Transaction Status Transitions

| # | Case | Setup | Action | Expected Result |
|---|------|-------|--------|-----------------|
| 2.5.1 | Confirm a pending transaction | Pending income txn of 100000 on `acc-1 (balance: 500000)` | Update `status` from `pending` → `confirmed` | Balance should be updated to 600000 (application layer handles recomputation). |
| 2.5.2 | Dismiss a pending transaction | Pending expense txn of 25000 | Update `status` from `pending` → `dismissed` | Transaction marked dismissed. Account balance unchanged. |

### 2.6 Row-Level Security — Transactions

| # | Case | Expected Result |
|---|------|-----------------|
| 2.6.1 | User can only query own transactions | User A sees only transactions where `user_id = User_A`. |
| 2.6.2 | Junction table access derives from transaction ownership | User A can read `transaction_categories` and `transaction_tags` only for transactions they own. |

---

## 3. Budgets

### 3.1 Create Budget

| # | Case | Input | Expected Result |
|---|------|-------|-----------------|
| 3.1.1 | Create budget without carry-over | `name: "Food", is_active: true, enable_carry_over: false` | Budget created. No period rows yet. |
| 3.1.2 | Create budget with carry-over enabled | `name: "Entertainment", is_active: true, enable_carry_over: true` | Budget created with `enable_carry_over = true`. |

### 3.2 Budget Periods

| # | Case | Setup | Action | Expected Result |
|---|------|-------|--------|-----------------|
| 3.2.1 | Create first budget period | Budget "Food" exists (no carry-over) | Insert `budget_periods`: `year_month: '2026-05', periodic_amount: 30000` ($300) | Period created. `carry_over_amount = 0` (first month, no carry-over). |
| 3.2.2 | Create period with different amount | Same budget | Insert `year_month: '2026-06', periodic_amount: 40000` ($400) | Period created. Amount differs from May — this is valid per period-specific design. |
| 3.2.3 | Reject duplicate period | Period for `2026-05` already exists on budget "Food" | Insert another row for `year_month: '2026-05'` | Rejected — `UNIQUE(budget_id, year_month)` constraint. |

### 3.3 Budget Carry-Over Calculation

**Scenario:** Budget "Food" with `enable_carry_over = true`.

| Month | periodic_amount | Previous Remaining | carry_over_amount | effective_amount | Transactions (expense) | spent | remaining |
|-------|-----------------|-------------------|-------------------|------------------|----------------------|-------|-----------|
| 2026-05 | $300 (30000) | N/A (first month) | $0 (0) | $300 (30000) | $290 (29000) | 29000 | 1000 |
| 2026-06 | $400 (40000) | $10 surplus | +$10 (1000) | $410 (41000) | $430 (43000) | 43000 | -2000 |
| 2026-07 | $400 (40000) | -$20 overspend | -$20 (-2000) | $380 (38000) | $350 (35000) | 35000 | 3000 |

**Test steps:**

| # | Case | Expected Result |
|---|------|-----------------|
| 3.3.1 | May period — first month, no carry-over | `carry_over_amount = 0`. `effective_amount = 30000`. After $290 in expenses, `v_budget_progress.remaining = 1000`. |
| 3.3.2 | June period — surplus carry-over | App computes carry-over = `30000 + 0 - 29000 = 1000`. `carry_over_amount = 1000`. `effective_amount = 41000`. After $430 in expenses, `remaining = -2000`. |
| 3.3.3 | July period — deficit carry-over | App computes carry-over = `40000 + 1000 - 43000 = -2000`. `carry_over_amount = -2000`. `effective_amount = 38000`. After $350 in expenses, `remaining = 3000`. |
| 3.3.4 | Carry-over disabled | Budget "Groceries" has `enable_carry_over = false`. Even if May has $50 remaining, June's `carry_over_amount` = 0. |

### 3.4 Budget Progress View (`v_budget_progress`)

| # | Case | Setup | Expected Query Result |
|---|------|-------|-----------------------|
| 3.4.1 | Budget with no transactions this period | `bp-may-food`: periodic=30000, carry_over=0. No transactions linked. | `spent = 0, remaining = 30000`. |
| 3.4.2 | Budget with partial spending | 3 expense transactions linked to `bp-may-food` totaling 15000. | `spent = 15000, remaining = 15000`. |
| 3.4.3 | Budget exceeded | Expenses linked to `bp-may-food` total 35000 (budget is 30000). | `spent = 35000, remaining = -5000`. Negative remaining indicates overspend. |
| 3.4.4 | Only confirmed transactions counted | One confirmed expense (10000) and one pending expense (5000) linked to same budget period. | `spent = 10000` (pending excluded by `t.status = 'confirmed'` filter). |

### 3.5 Deactivate / Remove Budget

| # | Case | Setup | Action | Expected Result |
|---|------|-------|--------|-----------------|
| 3.5.1 | Deactivate budget | Budget "Food" active with periods for May and June | Set `budgets.is_active = false` | Budget deactivated. Historical period rows (May, June) remain intact. No new periods created. |
| 3.5.2 | Delete budget cascades periods | Budget "Food" with two `budget_periods` rows | Delete the budget row | Budget and all `budget_periods` rows deleted (`ON DELETE CASCADE`). Transactions that referenced those periods have `budget_period_id` set to `NULL` (`ON DELETE SET NULL`). |

---

## 4. Fixed Expenses

### 4.1 Create Fixed Expense

| # | Case | Input | Expected Result |
|---|------|-------|-----------------|
| 4.1.1 | Create fixed expense with all fields | `name: "Gym Membership", year_month: '2026-05', amount: 5000 ($50), currency: 'USD', due_day: 15, is_active: true` | Row created. No linked transactions yet → unpaid. |
| 4.1.2 | Create with different amount for different month | `name: "Gym Membership", year_month: '2026-08', amount: 6000 ($60), due_day: 15` | Created. Previous months unaffected. |
| 4.1.3 | Reject invalid due_day (too high) | `name: "Gym Membership", year_month: '2026-05', due_day: 32` | Rejected — `CHECK (due_day BETWEEN 1 AND 31)` fails. |
| 4.1.4 | Reject invalid due_day (zero) | `name: "Gym Membership", year_month: '2026-05', due_day: 0` | Rejected — CHECK constraint fails. |
| 4.1.5 | Reject duplicate | Row for `(user-1, "Gym Membership", "2026-05")` already exists | Rejected — `UNIQUE(user_id, name, year_month)` fails. |

### 4.2 Copy from Previous Month

| # | Case | Setup | Action | Expected Result |
|---|------|-------|--------|-----------------|
| 4.2.1 | Copy when previous month has entries | May has 3 active fixed expenses: "Gym" ($50, day 15), "Netflix" ($15.99, day 20), "Rent" ($1500, day 1) | Copy from May to June | All active entries copied to `year_month = '2026-06'` with same name, amount, currency, due_day. |
| 4.2.2 | Copy when previous month is empty | April has no fixed expenses | Copy from April to May | No entries created. Operation succeeds with zero copies. |
| 4.2.3 | Copy does not overwrite existing entries | June already has "Gym" row | Copy from May to June | "Netflix" and "Rent" copied. "Gym" skipped — `UNIQUE(user_id, name, year_month)` prevents duplicate. |

### 4.3 Edit Fixed Expense

| # | Case | Setup | Action | Expected Result |
|---|------|-------|--------|-----------------|
| 4.3.1 | Update amount | `fe-may-gym` with amount 5000 | Update amount to 5500 | Amount updated. `updated_at` auto-set by trigger. |
| 4.3.2 | Update name | `fe-may-gym` with name "Gym Membership" | Update name to "Gym & Pool" | Name updated. Historical entries in other months keep old name. |
| 4.3.3 | Update due_day | `fe-may-gym` with due_day 15 | Update due_day to 20 | Due day updated. Valid range (1–31) enforced by CHECK constraint. |

### 4.4 Fixed Expense Paid Status (via Linked Transactions)

Paid status is derived: a fixed expense is considered paid when at least one `transactions` row references it via `fixed_expense_id`.

| # | Case | Setup | Action | Expected Result |
|---|------|-------|--------|-----------------|
| 4.4.1 | Fixed expense with no linked transactions is unpaid | `fe-may-gym` exists, no transactions reference it | Query paid status | Unpaid (no rows in `transactions` with `fixed_expense_id = fe-may-gym`). |
| 4.4.2 | Linking a transaction marks fixed expense as paid | `fe-may-gym` exists | Create expense transaction with `fixed_expense_id = fe-may-gym` | Fixed expense is now considered paid (at least one transaction references it). |
| 4.4.3 | Amount mismatch is allowed | `fe-may-gym` has `amount = 5000` | Create transaction with `amount = 4800, fixed_expense_id = fe-may-gym` | Valid. Fixed expense is paid. Transaction amount does not need to match fixed expense amount. |
| 4.4.4 | Multiple transactions can link to same fixed expense | `fe-may-gym` already has one linked transaction | Create a second transaction with `fixed_expense_id = fe-may-gym` | Valid. Both transactions reference the same fixed expense. Still paid. |
| 4.4.5 | Deleting all linked transactions makes fixed expense unpaid | `fe-may-gym` has one linked transaction `txn-1` | Delete `txn-1` | `txn-1.fixed_expense_id` was the only link. Fixed expense is now unpaid. |
| 4.4.6 | Transaction can link to at most one fixed expense | Transaction `txn-1` has `fixed_expense_id = fe-may-gym` | — | Only one `fixed_expense_id` per transaction (single nullable FK column). To change, update the FK value. |

### 4.5 Period-Specific History

Each fixed expense entry is an independent row in `fixed_expenses`. There is no parent-child relationship — each row stands alone with its own `year_month`, `amount`, and other fields.

**Scenario:** Fixed expense "Gym" = $50/month starting May 2026, increased to $60 in Aug 2026, cancelled in Oct 2026.

| # | Case | Expected Result |
|---|------|-----------------|
| 4.5.1 | Historical records preserved after amount change | Rows for May–Jul show `amount = 5000`. Aug–Sep show `amount = 6000`. Each row is independent. |
| 4.5.2 | Historical records preserved after cancellation | No row created for October. Rows for May–Sep remain intact with their original amounts. |

### 4.6 Delete Fixed Expense

Deleting a fixed expense row sets `fixed_expense_id` to `NULL` on any linked transactions (`ON DELETE SET NULL`). No cascade to other entries — each entry is independent.

| # | Case | Setup | Action | Expected Result |
|---|------|-------|--------|-----------------|
| 4.6.1 | Delete fixed expense with linked transaction | Fixed expense `fe-may-gym` linked to `txn-1` | Delete `fe-may-gym` | Row deleted. `txn-1.fixed_expense_id` → `NULL` (`ON DELETE SET NULL`). Transaction itself is preserved. |
| 4.6.2 | Delete does not affect other months | "Gym" exists for May and June | Delete May row | May row deleted. June row unaffected — each entry is independent. |

---

## 5. Scheduled Transactions (Auto-Record)

### 5.1 Create Scheduled Transaction

| # | Case | Input | Expected Result |
|---|------|-------|-----------------|
| 5.1.1 | Monthly income schedule | `account_id: acc-1, type: income, amount: 5000000 ($50,000), description: "Monthly Salary", recurrence: monthly, next_due_date: 2026-06-01, is_active: true` | Schedule created. |
| 5.1.2 | Monthly expense schedule | `account_id: acc-1, type: expense, amount: 150000 ($1,500), description: "Rent", recurrence: monthly, next_due_date: 2026-06-01` | Schedule created. |

### 5.2 Cron Job Generates Pending Transactions

| # | Case | Setup | Trigger | Expected Result |
|---|------|-------|---------|-----------------|
| 5.2.1 | Due schedule generates pending txn | Schedule `sched-1`: `next_due_date = 2026-06-01`, `is_active = true` | Cron runs on 2026-06-01 | New transaction inserted: `type = income, amount = 5000000, status = 'pending', scheduled_txn_id = sched-1, date = 2026-06-01`. Account balance unchanged. `sched-1.next_due_date` advanced to `2026-07-01`. |
| 5.2.2 | Inactive schedule is skipped | Schedule `sched-2`: `is_active = false, next_due_date = 2026-06-01` | Cron runs on 2026-06-01 | No transaction generated. `next_due_date` unchanged. |
| 5.2.3 | Future schedule is skipped | Schedule `sched-3`: `next_due_date = 2026-06-15` | Cron runs on 2026-06-01 | No transaction generated (not yet due). |
| 5.2.4 | Multiple overdue dates | Schedule `sched-4`: `next_due_date = 2026-05-01` (missed) | Cron runs on 2026-06-01 | Pending transaction created for the overdue date. `next_due_date` advanced appropriately. |

### 5.3 User Handles Pending Transaction

| # | Case | Setup | Action | Expected Result |
|---|------|-------|--------|-----------------|
| 5.3.1 | User confirms pending txn | Pending txn `txn-p1` (income, 5000000) on `acc-1 (balance: 500000)` | Confirm (set `status = 'confirmed'`) | Monthly balance recalculated: acc-1 → 5500000. |
| 5.3.2 | User edits then confirms | Pending txn `txn-p1` (income, 5000000) | Edit `amount` to 4800000, then confirm | Transaction recorded with 4800000. Balance reflects edited amount. |
| 5.3.3 | User dismisses pending txn | Pending txn `txn-p2` (expense, 150000) | Set `status = 'dismissed'` | Transaction marked dismissed. Account balance unchanged. |

---

## 6. Categories & Tags

### 6.1 Categories

| # | Case | Input | Expected Result |
|---|------|-------|-----------------|
| 6.1.1 | Create category | `name: "Food", icon: "🍔", color: "#FF6B35"` | Category created. |
| 6.1.2 | Reject duplicate name for same user | User A already has category "Food" | Create another "Food" | Rejected — `UNIQUE(user_id, name)` constraint. |
| 6.1.3 | Same name allowed for different users | User A has "Food", User B does not | User B creates "Food" | Allowed — uniqueness is per-user. |
| 6.1.4 | Delete category cascades junction rows | Category `cat-food` linked to 3 transactions via `transaction_categories` | Delete `cat-food` | Category and all `transaction_categories` rows referencing it are deleted. Transactions themselves remain. |

### 6.2 Tags

| # | Case | Input | Expected Result |
|---|------|-------|-----------------|
| 6.2.1 | Create tag | `name: "weekend"` | Tag created. |
| 6.2.2 | Reject duplicate tag name for same user | User A already has tag "weekend" | Create another "weekend" | Rejected — `UNIQUE(user_id, name)`. |
| 6.2.3 | Delete tag cascades junction rows | Tag `tag-weekend` linked to transactions | Delete `tag-weekend` | Tag and `transaction_tags` rows deleted. Transactions remain. |

### 6.3 Spending by Category View (`v_spending_by_category`)

| # | Case | Setup | Expected Query Result |
|---|------|-------|-----------------------|
| 6.3.1 | Single category expense total | May 2026: 3 confirmed expenses categorized as "Food" totaling $120 (12000) | `category_name = "Food", year_month = "2026-05", total_amount = 12000`. |
| 6.3.2 | Transaction in multiple categories counted in each | Expense of $50 linked to both "Food" and "Entertainment" | Appears in both "Food" total and "Entertainment" total (each shows 5000). |
| 6.3.3 | Income transactions excluded | An income transaction categorized as "Salary" | Not present in `v_spending_by_category` (view filters `type = 'expense'`). |
| 6.3.4 | Pending expenses excluded | Pending expense of $30 categorized as "Food" | Not counted (view filters `status = 'confirmed'`). |

---

## 7. Currency

### 7.1 Currencies Reference Table

| # | Case | Expected Result |
|---|------|-----------------|
| 7.1.1 | Authenticated user can read currencies | `SELECT * FROM currencies` returns all rows (e.g., USD, EUR, THB, JPY). |
| 7.1.2 | Unauthenticated user cannot read currencies | Query rejected by RLS (requires `auth.role() = 'authenticated'`). |
| 7.1.3 | User cannot insert/update/delete currencies | Any write operation on `currencies` is rejected (only SELECT policy exists). |

### 7.2 User Settings — Default Currency

| # | Case | Setup | Action | Expected Result |
|---|------|-------|--------|-----------------|
| 7.2.1 | Set default currency | User has `user_settings` with `default_currency = 'USD'` | Update to `'THB'` | Updated. New accounts/transactions default to THB. |
| 7.2.2 | Reject invalid currency | User sets `default_currency = 'XYZ'` | — | Rejected — FK to `currencies(code)` fails. |
| 7.2.3 | RLS enforced on user_settings | User A tries to read User B's settings | `SELECT` returns empty (policy: `user_id = auth.uid()`). |

### 7.3 Minor Unit Storage

| # | Case | Display Amount | Stored Value (`bigint`) | Currency | decimal_places |
|---|------|---------------|------------------------|----------|---------------|
| 7.3.1 | USD standard | $10.50 | 1050 | USD | 2 |
| 7.3.2 | JPY (zero decimals) | ¥1500 | 1500 | JPY | 0 |
| 7.3.3 | BHD (three decimals) | BHD 1.234 | 1234 | BHD | 3 |
| 7.3.4 | Large amount | $999,999.99 | 99999999 | USD | 2 |

---

## 8. Dashboard Views

### 8.1 Monthly Cash Flow (`v_monthly_cashflow`)

**Setup:** User has the following confirmed transactions in May 2026:

| Transaction | Type | Amount |
|-------------|------|--------|
| Salary | income | 5000000 ($50,000) |
| Freelance | income | 500000 ($5,000) |
| Rent | expense | 150000 ($1,500) |
| Groceries | expense | 30000 ($300) |
| Utilities | expense | 12000 ($120) |

| # | Case | Expected Query Result (`year_month = '2026-05'`) |
|---|------|----------------------------------------------------|
| 8.1.1 | Total income | `total_income = 5500000` ($55,000) |
| 8.1.2 | Total expense | `total_expense = 192000` ($1,920) |
| 8.1.3 | Net cash flow | `net = 5308000` ($53,080) |
| 8.1.4 | Transfers excluded from income/expense | A transfer of $1,000 between accounts exists | `total_income` and `total_expense` unchanged (transfers are type `'transfer'`, not `'income'` or `'expense'`). |
| 8.1.5 | Pending transactions excluded | A pending income of $2,000 exists | Not counted in totals (view filters `status = 'confirmed'`). |
| 8.1.6 | Empty month returns no row | No transactions in June 2026 | No row for `year_month = '2026-06'` (rather than a row with zeros). |

### 8.2 Recent Transactions

| # | Case | Setup | Query | Expected Result |
|---|------|-------|-------|-----------------|
| 8.2.1 | Returns latest N transactions | 20 transactions exist across various dates | `SELECT ... ORDER BY date DESC, created_at DESC LIMIT 10` | Returns the 10 most recent transactions, ordered newest first. |
| 8.2.2 | Includes all statuses | Mix of confirmed, pending, dismissed transactions | Same query | All statuses are included in recent transactions list. |
| 8.2.3 | Includes all types | Income, expense, and transfer transactions exist | Same query | All types appear. |

---

## 9. Triggers & Constraints

### 9.1 Monthly Balance Recalculation Trigger (`fn_transaction_balance_trigger`)

| # | Case | Transaction Action | Monthly Balance Before (2026-05) | Monthly Balance After (2026-05) |
|---|------|-------------------|----------------------------------|----------------------------------|
| 9.1.1 | Confirmed income adds to balance | INSERT `type: income, amount: 100000, status: confirmed, date: 2026-05-01` | `balance: 500000` | `balance: 600000` |
| 9.1.2 | Confirmed expense subtracts from balance | INSERT `type: expense, amount: 25000, status: confirmed, date: 2026-05-02` | `balance: 600000` | `balance: 575000` |
| 9.1.3 | Confirmed transfer debits source, credits dest | INSERT `type: transfer, amount: 50000, status: confirmed, acc-1 → acc-2, date: 2026-05-03` | `acc-1: 575000, acc-2: 200000` | `acc-1: 525000, acc-2: 250000` |
| 9.1.4 | Pending transaction does not change balance | INSERT `type: income, amount: 100000, status: pending` | `balance: 500000` | `balance: 500000` (unchanged) |
| 9.1.5 | Dismissed transaction does not change balance | INSERT `type: expense, amount: 30000, status: dismissed` | `balance: 500000` | `balance: 500000` (unchanged) |
| 9.1.6 | Delete confirmed income recalculates balance | DELETE confirmed income of 100000 | `balance: 600000` | `balance: 500000` |
| 9.1.7 | Delete confirmed expense recalculates balance | DELETE confirmed expense of 25000 | `balance: 575000` | `balance: 600000` |
| 9.1.8 | Delete confirmed transfer recalculates both | DELETE confirmed transfer of 50000 (acc-1 → acc-2) | `acc-1: 525000, acc-2: 250000` | `acc-1: 575000, acc-2: 200000` |
| 9.1.9 | Delete pending transaction — no balance change | DELETE pending income of 100000 | `balance: 500000` | `balance: 500000` |
| 9.1.10 | Update status pending→confirmed recalculates | UPDATE `status: pending → confirmed` (income, 100000) | `balance: 500000` | `balance: 600000` |
| 9.1.11 | Update amount recalculates balance | UPDATE `amount: 100000 → 80000` (confirmed income) | `balance: 600000` | `balance: 580000` |
| 9.1.12 | Update date across months recalculates both | UPDATE `date: 2026-04-15 → 2026-05-15` (confirmed expense, 30000) | April: 470000, May: 500000 | April: 500000, May: 470000 |

### 9.2 Monthly Balance Cascade

| # | Case | Setup | Action | Expected Result |
|---|------|-------|--------|-----------------|
| 9.2.1 | Editing past month cascades forward | acc-1 balances: Jan=500000, Feb=400000, Mar=350000 | Insert confirmed income of 100000 in January | Jan→600000, Feb→500000, Mar→450000 (all recalculated) |
| 9.2.2 | Editing current month does not affect past | acc-1 balances: Jan=500000, Feb=400000, Mar=350000 | Insert confirmed expense of 50000 in March | Jan=500000 (unchanged), Feb=400000 (unchanged), Mar→300000 |
| 9.2.3 | Cron creates new month row | acc-1 balance for May = 350000. No June row exists. | `fn_create_monthly_balance_rows()` runs on June 1 | June row created with `balance` = 350000 (carried forward from May). |

### 9.3 `updated_at` Auto-Touch Trigger

| # | Case | Action | Expected Result |
|---|------|--------|-----------------|
| 9.3.1 | Updating an account row sets `updated_at` | Update `accounts.name` | `updated_at` is set to `now()` automatically. |
| 9.3.2 | Updating a transaction row sets `updated_at` | Update `transactions.description` | `updated_at` refreshed. |
| 9.3.3 | Applies to all registered tables | Update any of: `user_settings`, `accounts`, `budgets`, `budget_periods`, `fixed_expenses`, `scheduled_transactions`, `transactions`, `account_monthly_balances` | `updated_at` refreshed on each. |

### 9.4 Constraint Enforcement

| # | Case | Action | Expected Result |
|---|------|--------|-----------------|
| 9.4.1 | Transaction amount must be positive | Insert with `amount = 0` | Rejected — `CHECK (amount > 0)`. |
| 9.4.2 | Transfer requires destination account | Insert `type = 'transfer', transfer_account_id = NULL` | Rejected — `chk_transfer_account`. |
| 9.4.3 | Non-transfer must not have destination | Insert `type = 'expense', transfer_account_id = acc-2` | Rejected — `chk_transfer_account`. |
| 9.4.4 | Fixed expense due_day range | Insert `due_day = 0` or `due_day = 32` | Rejected — `CHECK (due_day BETWEEN 1 AND 31)`. |
| 9.4.5 | Unique budget period per month | Insert duplicate `(budget_id, year_month)` | Rejected — unique constraint. |
| 9.4.6 | Unique fixed expense per user per name per month | Insert duplicate `(user_id, name, year_month)` for fixed expenses | Rejected — `UNIQUE(user_id, name, year_month)` constraint. |
| 9.4.7 | Unique category name per user | Insert duplicate `(user_id, name)` for categories | Rejected — unique constraint. |
| 9.4.8 | Unique tag name per user | Insert duplicate `(user_id, name)` for tags | Rejected — unique constraint. |

---

## 10. Row-Level Security (Comprehensive)

### 10.1 Direct Ownership Tables

Tables with a `user_id` column: `accounts`, `categories`, `tags`, `budgets`, `fixed_expenses`, `scheduled_transactions`, `transactions`.

| # | Case | Action | Expected Result |
|---|------|--------|-----------------|
| 10.1.1 | SELECT own rows | User A queries any owned table | Only rows with `user_id = User_A` returned. |
| 10.1.2 | INSERT with own user_id | User A inserts with `user_id = User_A` | Allowed. |
| 10.1.3 | INSERT with other user_id | User A inserts with `user_id = User_B` | Rejected by `WITH CHECK`. |
| 10.1.4 | UPDATE own rows | User A updates their own account name | Allowed. |
| 10.1.5 | UPDATE other user's rows | User A tries to update User B's account | No rows matched (RLS filters it out). |
| 10.1.6 | DELETE own rows | User A deletes their own tag | Allowed (subject to FK constraints). |
| 10.1.7 | DELETE other user's rows | User A tries to delete User B's tag | No rows matched. |

### 10.2 Derived Ownership Tables

| # | Table | Derivation | Case | Expected Result |
|---|-------|-----------|------|-----------------|
| 10.2.1 | `budget_periods` | Via `budgets.user_id` | User A queries budget periods | Only periods for budgets owned by User A. |
| 10.2.2 | `fixed_expenses` | Direct `user_id` column | User A queries fixed expenses | Only rows with `user_id = User_A` returned (direct ownership policy). |
| 10.2.3 | `transaction_categories` | Via `transactions.user_id` | User A queries transaction categories | Only rows for transactions owned by User A. |
| 10.2.4 | `transaction_tags` | Via `transactions.user_id` | User A queries transaction tags | Only rows for transactions owned by User A. |

### 10.3 Special Cases

| # | Case | Expected Result |
|---|------|-----------------|
| 10.3.1 | `currencies` — read-only for authenticated | Authenticated users can SELECT. No INSERT/UPDATE/DELETE. |
| 10.3.2 | `user_settings` — owner only | Each user can only access their own settings row. |
| 10.3.3 | Unauthenticated access denied | All tables reject queries from unauthenticated connections. |

---

## 11. End-to-End Scenarios

### 11.1 New User Onboarding

| Step | Action | Expected Result |
|------|--------|-----------------|
| 1 | User signs up via Supabase Auth | User created in `auth.users`. |
| 2 | App creates `user_settings` row | `default_currency = 'USD'` (or user-chosen). |
| 3 | User creates first account: "Checking", bank_account, $5,000 | `accounts` row created with `starting_balance = 500000`. `account_monthly_balances` row created for current month with `balance = 500000`. |
| 4 | User creates categories: "Food", "Transport", "Salary" | Three `categories` rows created. |
| 5 | User creates budget: "Food Budget", $300/month | `budgets` row + `budget_periods` row for current month (periodic_amount = 30000). |
| 6 | User records first expense: $25 lunch, category "Food", linked to "Food Budget" | `transactions` row (expense, 2500). `transaction_categories` row. acc-1 monthly balance → 497500. Budget spent increases by 2500. |

### 11.2 Monthly Budget Cycle with Carry-Over

| Step | Action | Expected Result |
|------|--------|-----------------|
| 1 | May: Budget "Food" = $300, carry-over enabled | `budget_periods`: periodic=30000, carry_over=0, effective=30000. |
| 2 | May: User spends $290 on food | `v_budget_progress`: spent=29000, remaining=1000. |
| 3 | June: App creates new period, $400 budget | carry_over = 30000 + 0 - 29000 = 1000. effective = 40000 + 1000 = 41000. |
| 4 | June: User spends $430 on food | spent=43000, remaining = 41000 - 43000 = -2000 (overspent). |
| 5 | July: App creates new period, $400 budget | carry_over = 40000 + 1000 - 43000 = -2000. effective = 40000 - 2000 = 38000. |
| 6 | July: User spends $350 on food | spent=35000, remaining = 38000 - 35000 = 3000. |

### 11.3 Auto-Record Salary Flow

| Step | Action | Expected Result |
|------|--------|-----------------|
| 1 | User creates scheduled transaction: income, $50,000, monthly, next_due = June 1 | `scheduled_transactions` row created. |
| 2 | Cron runs on June 1 | Pending transaction created: income, $50,000, status=pending, scheduled_txn_id set. `next_due_date` → July 1. |
| 3 | User receives notification | App shows pending transaction for review. |
| 4 | User confirms with edit (actual salary was $48,000) | Transaction amount updated to 4800000, status → confirmed. acc-1 monthly balance increases by 4800000. |
| 5 | Cron runs on July 1 | Another pending transaction for $50,000. Cycle repeats. |

### 11.4 Transfer Between Accounts

| Step | Action | Expected Result |
|------|--------|-----------------|
| 1 | Setup: acc-1 (Checking) = $10,000, acc-2 (Savings) = $20,000 | — |
| 2 | User transfers $2,000 from Checking to Savings | Transaction: type=transfer, amount=200000, account_id=acc-1, transfer_account_id=acc-2. |
| 3 | Balances updated | acc-1 → $8,000 (800000), acc-2 → $22,000 (2200000). |
| 4 | Transfer does not appear in expense totals | `v_monthly_cashflow.total_expense` unchanged by this transfer. |

### 11.5 Fixed Expense Lifecycle

| Step | Action | Expected Result |
|------|--------|-----------------|
| 1 | User creates fixed expense "Netflix" for May | `fixed_expenses` row: name="Netflix", year_month="2026-05", amount=1599, due_day=20, is_active=true. No linked transactions → unpaid. |
| 2 | User pays Netflix on May 20 | Transaction: expense, 1599, `fixed_expense_id = fe-may-netflix`. Fixed expense is now considered paid (has linked transaction). |
| 3 | User copies fixed expenses from May to June | New `fixed_expenses` row: name="Netflix", year_month="2026-06", amount=1599, due_day=20. No linked transactions → unpaid. May row unchanged (still paid). |
| 4 | User pays Netflix in June | Transaction linked to June's "Netflix" row. June is now paid. |
| 5 | July: Netflix increases to $17.99 | User copies from June, then edits July "Netflix" row: amount → 1799. May/June rows still show 1599. |
| 6 | September: User cancels Netflix | No row created for October. Rows for May–Sep remain intact with their original amounts. |

### 11.6 Dashboard Data Accuracy

**Setup for May 2026:**
- 2 income transactions: $50,000 salary + $5,000 freelance = $55,000 total income
- 4 expense transactions: $1,500 rent + $300 groceries + $120 utilities + $80 transport = $2,000 total expense
- 1 transfer: $2,000 checking → savings
- 1 pending income: $500 (not yet confirmed)
- Budget "Food": $300 limit, $300 groceries spent, $80 transport (not linked to this budget)

| # | Widget | Expected Result |
|---|--------|-----------------|
| 11.6.1 | Monthly Cash Flow | Income: $55,000. Expense: $2,000. Net: $53,000. Transfer and pending txn excluded. |
| 11.6.2 | Budget Progress — "Food" | Effective: $300. Spent: $300 (only transactions linked to this budget period). Remaining: $0. |
| 11.6.3 | Spending by Category | "Rent": $1,500. "Food": $300. "Utilities": $120. "Transport": $80. Only confirmed expenses. |
| 11.6.4 | Recent Transactions | Shows latest 10 transactions across all types and statuses, ordered by date desc. |

---

## 12. Edge Cases & Error Handling

| # | Case | Scenario | Expected Result |
|---|------|----------|-----------------|
| 12.1 | Concurrent balance updates | Two confirmed transactions inserted simultaneously on the same account | Both triggers execute. Final balance reflects both changes (Postgres row-level locking ensures correctness). |
| 12.2 | Budget period with no linked transactions | Budget period exists but no transactions reference it | `v_budget_progress`: `spent = 0`, `remaining = effective_amount`. `COALESCE(SUM(...), 0)` handles the null. |
| 12.3 | Transaction with no categories or tags | Transaction created without any category or tag assignments | Valid. Junction tables simply have no rows for this transaction. |
| 12.4 | Account balance goes negative | Expenses exceed income on a bank account | Allowed — no constraint prevents negative monthly balance. App layer may show a warning. |
| 12.5 | Very large amounts | Transaction amount near `bigint` max | Stored correctly. Application layer should validate reasonable ranges. |
| 12.6 | year_month format validation | Insert `budget_periods.year_month = 'May-2026'` (wrong format) | No DB constraint enforces format — application layer must validate `YYYY-MM` pattern. |
| 12.7 | Deleting a category used by transactions | Category "Food" linked to 50 transactions | Category and `transaction_categories` rows deleted (`CASCADE`). Transactions remain but lose the category association. |
| 12.8 | Deleting a tag used by transactions | Same as above for tags | Tag and `transaction_tags` rows deleted. Transactions remain. |
| 12.9 | Scheduled transaction for inactive account | Account is archived, schedule still active | Cron may generate a pending txn. App should validate account status before confirming. |
| 12.10 | due_day = 31 for months with fewer days | Fixed expense with `due_day = 31` in February | Application layer should handle this (treat as last day of month). DB stores 31 as-is. |
| 12.11 | Rapid create-then-delete transaction | Insert confirmed txn, then immediately delete | Balance update trigger fires on insert (+amount), then reversal trigger fires on delete (-amount). Net effect: zero. |
| 12.12 | Transfer to same account | `account_id = acc-1, transfer_account_id = acc-1` | No DB constraint prevents this. Application layer should validate source ≠ destination. |
