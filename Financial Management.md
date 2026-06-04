# Financial Management Application

A personal finance management app for tracking income, expenses, budgets, and accounts across all devices.

---

## P0 Requirements (Core)

### General

- Built with Supabase as the database backend
- Cross-platform: Desktop/Web and Mobile (iOS, Android) with data synced across all devices
- Single-user (personal use only)

### Accounts

Accounts represent any source or store of money the user wants to track — not limited to traditional bank accounts.

- User can have multiple accounts and add/remove them as needed
- An account can represent a bank account, credit card, digital wallet, cash, or any other financial store
- Each account has a name, starting balance, and current balance

### Transactions

Transactions are the core records of money moving in, out, or between accounts.

- A transaction is either an **income** or an **expense**
- A transaction can be a **transfer** between two accounts
- A transaction can be linked to a **budget** (optional, at most one per transaction) via an explicit dropdown on the transaction. The dropdown offers budgets matching the transaction's currency and month. Linking is manual — there is no category-to-budget mapping in P0.
- A transaction can be linked to a **fixed expense** (optional, at most one per transaction). This indicates payment of that fixed expense for the given month.
- A transaction can have:
  - Multiple categories / tags
  - A description
  - A date
  - An amount
  - A currency

### Budgets

Budgets allow the user to set spending limits for a given period and track remaining allowance.

- User can have multiple budgets
- Each budget is one self-contained row for one specific period, with a **name**, a **period** (`year_month`), a **currency**, a **periodic amount**, and a computed **remaining amount**
- For P0, budget period is fixed to **monthly**

**Identity**

- A budget is identified by its **name + currency** together. Budgets sharing the same name across periods are treated as the same budget only when their currency also matches.
  - Example: "Food" in USD and "Food" in EUR are two distinct budgets with independent carry-over chains.
- The name is chosen at the user's discretion and should be kept simple and consistent so the same budget can be matched across periods.

**Amounts**

- **Periodic amount**: the target spending limit the user sets for the period.
- **Spent**: the net of transactions linked to the budget in that period — `linked expenses − linked income`. Income/refunds linked to a budget add back to its remaining allowance.
- **Effective budget**: `periodic amount + carry-in` (see carry-over below).
- **Remaining amount** (computed): `effective budget − spent`. Can be negative (overspent).

**Period-specific design**

- Each budget entry is tied to the exact period it applies to. The periodic amount can differ between periods, and a budget can be added or removed at any time without affecting historical records.
  - Example: Budget "Food" = $100 in May 2026, changed to $200 in June 2026, then removed in July 2026. The records for May and June remain intact.
- Editing a past period's periodic amount, or adding/removing a linked transaction in a past period, recomputes every later period in that budget's carry-over chain (see below).

**Carry-over**

- Carry-over is **always on** for every budget (no opt-out).
- It **compounds (chains)** across consecutive periods: the remaining (or overspent) amount of one period becomes the carry-in of the next.
  - `effective[n] = periodic[n] + remaining[n-1]`
  - `remaining[n] = effective[n] − spent[n]`
  - Example (surplus): "Food" May = $300, $10 remaining → June periodic $400 → June effective = $410. If June then has $50 remaining, July's carry-in is $50.
  - Example (overspend): "Food" May = $300, overspent by $20 → June periodic $400 → June effective = $380.
- Carry-in comes from the **immediately preceding period only**, within the same name + currency lineage.
- A **gap resets carry-over**: if the immediately preceding period has no budget of the same name + currency, this period starts fresh with carry-in = 0. (Removing a budget for a month then re-adding it is the deliberate way to reset accumulated surplus/debt.)
- The first period of a lineage (or the first after a gap) has carry-in = 0.

### Fixed Expenses

Fixed expenses are recurring costs the user expects to pay on a regular basis (e.g., rent, subscriptions).

- Each fixed expense is a self-contained row representing one expense for one specific month, with a name, year_month, amount (can be approximate), currency, and due day
- For P0, fixed expense recurrence is fixed to **monthly**
- **Copy from Previous Month**: the user can copy all fixed expenses from the previous month to the current month, preserving names, amounts, currencies, and due days. This is the primary way to carry forward recurring expenses into a new month.
- User can **edit** the name, amount, currency, or due day of any fixed expense
- User can **delete** individual fixed expense entries
- Fixed expenses are **month-specific**: each row is tied to the exact month it applies to. The amount or existence can change between months without affecting historical records.
  - Example: Fixed expense "Gym" = $50/month starting May 2026, increased to $60 in August 2026, then cancelled in October 2026. Records for May–September remain intact.
- **Paid status** is determined by linked transactions: a fixed expense is considered **paid** when at least one transaction references it. The amounts do not have to match — the link only indicates that the expense has been paid. A fixed expense can have multiple linked transactions, but each transaction can link to at most one fixed expense.

### Auto-Record Transactions

Some accounts may have scheduled or recurring transactions (e.g., salary deposits, subscription charges). The app can automatically generate transaction records when these are expected to occur.

- User can set up scheduled transactions tied to an account
- When a scheduled transaction is due, the app creates a **pending** transaction and notifies the user
- The user must **confirm, edit, or dismiss** the pending transaction before it is officially recorded
- No transaction is recorded without explicit user approval

### Currency

The user can set a default currency used across the app.

- A **currencies** table in the database stores all supported ISO 4217 currency codes — platforms read from this table instead of hardcoding
- User can select a **default currency** in settings
- The default currency is used when creating new accounts, transactions, budgets, and fixed expenses
- All amounts on the dashboard and aggregation views are displayed in the default currency

### Dashboard

A central overview screen that gives the user a quick snapshot of their financial status.

- **Monthly Cash Flow**: Income vs. expenses for the current month
- **Budget Progress**: Progress bars for each active budget showing amount spent vs. periodic limit
- **Spending by Category**: Breakdown of expenses by category/tag for the current period
- **Recent Transactions**: Quick-access list of the latest transactions (e.g., last 5–10)

---

## P1 Requirements (Future)

### Receipt Scanning

- Accept screenshots of receipts and automatically extract data to create a new transaction record

### Flexible Periods

- Budget periods can be changed to weekly, quarterly, yearly, or custom
- Fixed expense recurrence can be changed to weekly, quarterly, yearly, or custom

### Multi-Currency Transactions

- A transaction can be created in a currency different from the account's default currency
- When the transaction currency differs, the user provides the exchange rate or converted amount
- The transaction is recorded in its original currency, and the account balance is adjusted using the converted amount in the account's currency

### Dashboard (Extended)

- **Upcoming Fixed Expenses**: List of fixed expenses due soon or overdue
- **Pending Transactions**: Auto-recorded transactions awaiting user confirmation
- **Month-over-Month Trend**: Line/bar chart showing total spending or net savings over the past several months