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

- User can have multiple accounts and add, edit, or archive them as needed
- Each account has a **type** — bank account, credit card, digital wallet, cash, or other — which drives its default icon
- Each account has a name and a **starting balance**; its **current balance** is computed from the starting balance plus all confirmed transactions (it is not entered by hand)
- Each account can have an optional **custom image** (e.g. a bank or card logo) shown as its avatar. The image is uploaded by the user; when none is set, an icon based on the account type is shown instead
- **Archiving** an account hides it from lists and pickers while preserving its transaction history — accounts are archived rather than hard-deleted, so past records stay intact
- Each account can be **shown or hidden on the dashboard** independently of archiving, so a rarely-watched account can be kept out of the dashboard Accounts card without losing it
- The user can mark one account as the **default account**, which is pre-selected when adding a new transaction

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
  - An amount. Income and expenses may be **negative** — e.g. a refund recorded as a negative expense, which adds cash back to the account and reduces the expense/category/budget totals instead of inflating income. Transfers must be positive (reverse a transfer by swapping its accounts), and a zero amount is never allowed for any type.

**Filtering & Search**

The transaction list can be narrowed by any combination of the following filters:

Every facet except search, date range, and amount range is a **multi-select** (pick one or more values; a transaction matches if it matches **any** of them). The category, tag, budget, and fixed-expense facets additionally offer a **"(Blanks)"** option that matches transactions with no value for that facet (e.g. uncategorized or untagged rows).

- **Search**: free-text match on the transaction description
- **Type**: one or more of income, expense, transfer
- **Account**: one or more accounts (an account matches whether it is the source or the transfer destination)
- **Status**: one or more of confirmed, pending, dismissed
- **Date range**: a from/to range, with quick presets (this month, last month, last 3 months, this year, all time)
- **Categories**: one or more categories (or "(Blanks)" for uncategorized) — a transaction matches if its category is **any** of the selected ones
- **Tags**: one or more tags (or "(Blanks)" for untagged) — a transaction matches if it carries **any** of the selected tags
- **Amount range**: a minimum and/or maximum amount
- **Budget**: one or more budgets by **name** (or "(Blanks)" for transactions with no budget). The list offers all existing budgets across every period (matched by name, since a budget name spans multiple monthly entries). When a **date range** is also active, the available budgets are limited to those that exist within the selected range's months (e.g., a 30 May – 3 June range offers budgets present in May or June). Selecting a budget shows transactions linked to that budget's name within the selected date range, or across all dates when no date range is set.
- **Fixed expense**: one or more fixed expenses by **name** (or "(Blanks)" for transactions not linked to any), matched by name across every month exactly like the budget filter

Combination semantics: filters across different dimensions are combined with **AND**; multiple selections within a single multi-select dimension are combined with **OR**. Example: `type = expense` **AND** category ∈ {Food, Travel} (a transaction has at most one category, so this matches when that one category is Food or Travel).

Active filters are shown as removable chips with a "Clear all" action, alongside a count of matching transactions. The matching list is **paginated** (selectable page size), and the active filters are reflected in the URL so a filtered view can be shared or reloaded. A **Summary** view reduces the *entire* filtered set (across all pages) to totals — income, expense, net, transfers in/out, count, largest expense — with collapsible breakdowns by account, category, budget, fixed expense, and tag. Summary money math uses confirmed rows only (pending shown separately as a projection; dismissed excluded).

### Budgets

Budgets allow the user to set spending limits for a given period and track remaining allowance.

- User can have multiple budgets
- Each budget is one self-contained row for one specific period, with a **name**, a **period** (`year_month`), a **periodic amount**, an optional **note**, and a computed **remaining amount**
- For P0, budget period is fixed to **monthly**
- User can **edit** the name, monthly amount, or note of any budget, and **remove** an individual budget for a month (other months are unaffected)
- **Copy from Previous Month**: the user can copy every budget from the previous month into the current month, preserving name, note, and periodic amount. Budgets whose name already exists in the current month are skipped. This is the primary way to carry a budget set forward into a new month.

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

- Each fixed expense is a self-contained row representing one expense for one specific month, with a name, year_month, and amount (can be approximate)
- For P0, fixed expense recurrence is fixed to **monthly**
- **Copy from Previous Month**: the user can copy all fixed expenses from the previous month to the current month, preserving names and amounts. This is the primary way to carry forward recurring expenses into a new month.
- User can **edit** the name or amount of any fixed expense
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

### Budget Installments / Virtual Installments (Spread an Expense Across Budgets)

A way to absorb a large one-off expense gradually, by reserving future budget allowance instead of all of it at once. The money leaves the account immediately (the account balance is always correct), but the impact on the user's spending discipline is **spread forward**: selected budgets in the coming months are reduced so the user has to spend less to "pay the expense back" to themselves.

In the app this is surfaced as a **virtual installment**: the word *virtual* underlines the core invariant below — nothing is actually financed or borrowed, and no extra money moves. It is purely a forward reservation against budgets.

**Goal**

- A big purchase (e.g. a laptop) should not blow a single month's budget. Instead, the user voluntarily shrinks the next few months' budgets to compensate, encouraging lower spending until the expense is absorbed.

**Core invariant**

- The expense is **one ordinary transaction** that debits the account in full, exactly like any other expense. Account balances, cash flow, and the monthly balance ledger are unaffected by the installment.
- The "reservation" is **purely budget-side bookkeeping** — it is *not* money and *not* a transaction. It only lowers what selected budgets show as available in future months. It can never touch an account balance because it never enters the transactions table.

**How the user starts one**

A virtual installment is created from an expense that **already exists**, not while the expense is being recorded. The user records the expense as an ordinary expense first (with its account, category, tags, and — optionally — a single budget), then opens that transaction's actions menu (the ⋮ on its row) and chooses **"Create virtual installment."** The option appears only on **expenses** and only while the expense is **not already spread** (income and transfers never show it, and a second spread of the same expense is rejected). Converting it detaches the expense from its single budget (so it no longer counts as that budget's spend) and replaces that link with the reservation grid below.

**What the user sets up**

In the "Create virtual installment" dialog, the user chooses:

1. **Start month** — *this month* or *next month*. (Choosing *next month* leaves the current month's budgets untouched, since the cash already left this month; choosing *this month* makes the current month the first installment month.)
2. **Budgets** — one or more budgets (by name/lineage) to draw the reservation from. Drawing from several budgets each month lets the same expense be absorbed in **fewer months**.
3. **Number of months** — how many consecutive months to spread across.
4. **Allocation grid** — a budgets × months grid of reserved amounts. The grid is **pre-filled with an even split** (`total ÷ (number of budgets × number of months)`, with any rounding remainder placed in one cell so the grid sums exactly to the expense total). The user can then **edit any cell freely** — push more onto a larger budget, or set a cell to **0** to skip a budget in a given month.

**Rules**

- The grid total must equal the expense amount; the form shows a live running total and remaining-to-allocate indicator and blocks saving until they match.
- Changing the set of budgets or the number of months **re-runs the even pre-fill** (discarding manual edits), since the grid shape changed. Editing a single cell never changes the grid shape; a "split evenly again" action re-applies the pre-fill on demand.
- Each non-zero cell becomes one reservation for that budget in that month. Zero cells reserve nothing.
- A reservation may exceed a budget's room for that month, pushing its remaining **negative** — this is the intended "spend nothing here" signal, not an error.
- If a target budget has **no row yet** for a future month (budgets are created per month), creating the installment **materializes** that month's budget row (defaulting its periodic amount to the most recent value in that lineage, or 0 if the budget is new). This gives the reservation a home and keeps the budget's carry-over lineage unbroken (a missing month would otherwise reset carry-over).

**How the calculation works**

- For each budget month, **reserved** = the sum of all installment cells targeting that budget + month (across every installment — multiple installments can stack).
- The budget's remaining becomes:

  `remaining = periodic amount + carry-in − spent − reserved`

- The reservation interacts with carry-over the simple way (**"subtract from effective, then carry normally"**): it lowers the month's available pool, and only the **true leftover** carries into the next month. The reservation itself is *use-it-or-lose-it* — it does not linger beyond its month. Because `remaining` is what feeds the next month's carry-in, an overspend still carries forward as usual on top of the next month's own reservation.

**Worked example** — Laptop = $1,200, spread across **Groceries** and **Dining**, **2 months**, starting next month. Even pre-fill = $1,200 ÷ (2 budgets × 2 months) = **$300 per cell**. Both budgets have a $1,000 periodic amount.

| | Reserved | periodic | carry-in | effective − reserved | (before any spend) remaining |
|---|---|---|---|---|---|
| Groceries — Jul | $300 | $1,000 | $0 | $700 | $700 |
| Dining — Jul | $300 | $1,000 | $0 | $700 | $700 |
| Groceries — Aug | $300 | $1,000 | (Jul leftover) | $700 − reserved | … |
| Dining — Aug | $300 | $1,000 | (Jul leftover) | $700 − reserved | … |

The account takes a single −$1,200 hit in July. The expense transaction itself is **not** linked to any budget (so it does not also count as July spend); the spreading is done entirely by the reservations. Each budget's reservation and carry-over are tracked independently.

**Where it shows up**

- The **source expense's transaction row** carries a small grid indicator next to its title, flagging that it has been spread into a virtual installment.
- The **Budgets page** lists **Active installments** for the month being viewed — only installments that reserve allowance in that month appear. Each entry shows the expense's title, its total, the month span it covers, and the budgets it draws from. Tapping an entry opens its **source expense**; a per-entry action **cancels** the installment.

**Editing & cancelling**

- **Cancel an installment** removes all its future reservations; the affected budgets recompute immediately and their full allowance returns. Budget rows that were materialized for the installment remain as ordinary budget rows. Cancelling does **not** delete the source expense — the money already spent stays recorded; only the budget-side reservation is released.
- Deleting the **source expense** cancels its installment (the spread no longer has a source).
- Editing the source expense amount does not silently rebalance the grid; the user re-opens the installment to re-spread if needed.

### Multi-Currency Transactions

- A transaction can be created in a currency different from the account's default currency
- When the transaction currency differs, the user provides the exchange rate or converted amount
- The transaction is recorded in its original currency, and the account balance is adjusted using the converted amount in the account's currency

### Dashboard (Extended)

- **Upcoming Fixed Expenses**: List of fixed expenses due soon or overdue
- **Pending Transactions**: Auto-recorded transactions awaiting user confirmation
- **Month-over-Month Trend**: Line/bar chart showing total spending or net savings over the past several months