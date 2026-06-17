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
- Each account can have an optional **custom image** (e.g. a bank or card logo) shown as its avatar. The image is uploaded by the user; when none is set, an icon based on the account type is shown instead

### Transactions

Transactions are the core records of money moving in, out, or between accounts.

- A transaction is either an **income** or an **expense**
- A transaction can be a **transfer** between two accounts
- A transaction can be linked to a **budget** (optional, at most one per transaction) via an explicit dropdown on the transaction. The dropdown offers budgets matching the transaction's month. Linking is manual — there is no category-to-budget mapping in P0.
- A transaction can be linked to a **fixed expense** (optional, at most one per transaction). This indicates payment of that fixed expense for the given month.
- A transaction can have:
  - A single **category** (optional, at most one per transaction) and multiple **tags**
  - A description
  - A date
  - An amount

**Filtering & Search**

The transaction list can be narrowed by any combination of the following filters:

- **Search**: free-text match on the transaction description
- **Type**: income, expense, or transfer
- **Account**: a specific account (matches whether it is the source or the transfer destination)
- **Status**: confirmed, pending, or dismissed
- **Date range**: a from/to range, with quick presets (this month, last month, last 3 months, this year, all time)
- **Categories**: one or more categories — a transaction matches if its category is **any** of the selected ones
- **Tags**: one or more tags — a transaction matches if it carries **any** of the selected tags
- **Amount range**: a minimum and/or maximum amount
- **Budget**: a specific budget by **name**. The list offers all existing budgets across every period (matched by name, since a budget name spans multiple monthly entries). When a **date range** is also active, the available budgets are limited to those that exist within the selected range's months (e.g., a 30 May – 3 June range offers budgets present in May or June). Selecting a budget shows transactions linked to that budget's name within the selected date range, or across all dates when no date range is set.
- **Fixed-expense link**: "linked to a fixed expense" (paid) or "not linked" (unpaid)

Combination semantics: filters across different dimensions are combined with **AND**; multiple selections within a single multi-select dimension (categories, tags) are combined with **OR**. Example: `type = expense` **AND** category ∈ {Food, Travel} (a transaction has at most one category, so this matches when that one category is Food or Travel).

Active filters are shown as removable chips with a "Clear all" action, alongside a count of matching transactions. For P0, filters are not persisted across sessions (they reset on reload).

### Budgets

Budgets allow the user to set spending limits for a given period and track remaining allowance.

- User can have multiple budgets
- Each budget is one self-contained row for one specific period, with a **name**, a **period** (`year_month`), a **periodic amount**, and a computed **remaining amount**
- For P0, budget period is fixed to **monthly**

**Identity**

- A budget is identified by its **name**. Budgets sharing the same name across periods are treated as the same budget (one carry-over lineage). The app is single-currency, so all budgets share the user's default currency.
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
- Carry-in comes from the **immediately preceding period only**, within the same name lineage.
- A **gap resets carry-over**: if the immediately preceding period has no budget of the same name, this period starts fresh with carry-in = 0. (Removing a budget for a month then re-adding it is the deliberate way to reset accumulated surplus/debt.)
- The first period of a lineage (or the first after a gap) has carry-in = 0.

### Fixed Expenses

Fixed expenses are recurring costs the user expects to pay on a regular basis (e.g., rent, subscriptions).

- Each fixed expense is a self-contained row representing one expense for one specific month, with a name, year_month, amount (can be approximate), and due day
- For P0, fixed expense recurrence is fixed to **monthly**
- **Copy from Previous Month**: the user can copy all fixed expenses from the previous month to the current month, preserving names, amounts, and due days. This is the primary way to carry forward recurring expenses into a new month.
- User can **edit** the name, amount, or due day of any fixed expense
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
- The app is **single-currency**: the default currency applies to every amount across the app — accounts, transactions, budgets, and fixed expenses do not carry their own currency
- All amounts on the dashboard and aggregation views are displayed in the default currency

### Dashboard

A central overview screen that gives the user a quick snapshot of their financial status for a selected month. A month navigator (previous / next) defaults to the current month, and every widget reflects the chosen month. A shortcut opens the Transactions list scoped to that month, and the dashboard updates live as transactions, budgets, fixed expenses, or accounts change.

- **Budget Verdict**: A banner at the top answering "am I overspending?" — how many budgets are over and the total overage across the month, color-coded on-track (green) or over (red). Hidden when there are no budgets.
- **Accounts**: Each account's end-of-month balance for the selected month plus the combined total. Accounts can be individually hidden from the dashboard without archiving them.
- **Planned Expenses**: What the user committed to spend this month — every budget (with a pace-aware progress bar) and every fixed expense (split into paid / unpaid with subtotals), summed into a single planned total.
- **Unplanned Expenses**: Confirmed spending this month that no budget or fixed expense accounts for, broken down by category (spend with no category collapses into a single "Uncategorized" row).

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