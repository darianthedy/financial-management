# Spreadsheet → financial-management import

How the "Finance Management 5.0" spreadsheets (exported to CSV) map onto the
app's schema, and how to backfill them. Source of truth for the parsers in
`generate_*.py`. As we test the migration, refine the rules here first, then the
generator.

## Formats at a glance

There are two **completely different** CSVs. They are told apart by their
**header row** (not the filename — filenames drift). Each generator asserts its
expected header and fails loudly on a mismatch.

| Format | Header signature | Generator | Shape |
|---|---|---|---|
| **Monthly** | `Current Balance,Food,Transport,Social,Other Expenses,Monthly Expenses,Credit Card,Income,Description,Total Expenses,…` | `generate_monthly.py <YYYY-MM>` | One sheet **per month**; budgets + fixed expenses + a daily ledger (see Part A) |
| **Non-monthly** | `Date,Category,Description,Amount` | `generate_nonmonthly.py` | A flat ledger of **unplanned/one-off** transactions across many months; no budgets, no fixed expenses (see Part B) |

---

# Per-month runbook

Each month can be its own session. **Bootstrap:** start with *"Read
`supabase/imports/README.md`, then import `<YYYY-MM>`."* All durable context lives
in this folder (committed to the repo) — the chat history is not needed. Steps:

1. **Carry-over.** If this is the **earliest** month ever imported, seed the prior
   month: `python3 generate_carryover_seed.py <YYYY-MM>` (see §6). Otherwise
   carry-over chains automatically from the previously imported month — nothing to do.
2. **Generate:** `python3 generate_monthly.py <YYYY-MM>` → `<YYYY-MM>-bca.sql`.
   Confirm the printed income line says `[OK]`.
3. **Overlaps:** `python3 check_overlaps.py <YYYY-MM>`. Review the candidates,
   **drop coincidental date+amount collisions**, add the genuine ones to
   `MONTHLY_OVERLAPS` in `generate_nonmonthly.py`, then **re-run both generators**
   (`python3 generate_nonmonthly.py` and `python3 generate_monthly.py <YYYY-MM>`)
   and write `overlaps-<YYYY-MM>.md`. The monthly generator now **comments out and
   marks** each registered duplicate in `<YYYY-MM>-bca.sql` (the non-monthly record
   is kept as the single source) — it is **not deleted**, just left commented for
   you to review before running.
4. **Run in Supabase**, in order: carry-over seed (once) → earlier months → this
   month; then the non-monthly SETUP block + month blocks. The monthly duplicates
   are already commented out (step 3), so nothing double-counts — **review those
   commented rows first**.

> **Lidya rows are May-2026 only** — not a recurring step. They appear solely in
> the May 2026 sheet; if you ever re-import that month, review them per §4.

---

# Part A — Monthly format

## 1. The spreadsheet

One file **per month**, amounts in **Indonesian Rupiah**. The app is
**single-currency** (set once in Settings → `user_settings.default_currency`);
there is no per-row `currency` column. IDR has **0 decimal places**, so figures
import as whole rupiah with no scaling — the user's default currency must be IDR.
It is a 2D sheet flattened to CSV, so a single row mixes the daily ledger (left)
with an unrelated reference table (right). Columns:

| Col | Index | Meaning |
|----|------|---------|
| A | 0 | Day-of-month (`01`…`31`), only on the **first** row of each day; blank after |
| B | 1 | **Food** |
| C | 2 | **Transport** |
| D | 3 | **Social** |
| E | 4 | **Other Expenses** |
| F | 5 | **Monthly Expenses** (recurring bills) |
| G | 6 | **Credit Card** |
| H | 7 | **Income** |
| I | 8 | **Description** |
| J | 9 | Total Expenses (a sheet-side rollup; not imported) |
| K | 10 | (blank) |
| L | 11 | **Monthly Expenses Details** — name |
| M | 12 | Monthly Expenses Details — value |

### Header / summary rows (rows 1–3)

- **Row 1** — column headers.
- **Row 2** — for **B–F**: the *previous* month's budget for each envelope. For
  **G (Credit Card)**: the *previous* month's card balance.
- **Row 3** — for **B–F**: the *current* running budget this month (negative =
  overspent). For **G**: the *current* month's card balance. `Date` in col A
  marks the start of the daily ledger below.

These are derived display values and are **not imported**.

### Daily ledger (row 4 onward)

Generally **one transaction per populated row**. The amount lands in exactly one
of B–F (its envelope), and **G mirrors it as a negative** when the spend was put
on the card. Exception: a row that fills *both* Income and Credit Card (the Lidya
rows — see §4) splits into **two** transactions, so the row count and transaction
count differ (see the note under §4).

### Right-side reference block — "Monthly Expenses Details" (cols L/M)

A fixed list of names + monthly amounts, ending in a `Total` row. It is **mixed**:

- `Food`, `Transport`, `Social`, `Other Expenses` → these four are **budgets**
  (their value is the month's budget for that envelope). The `Other Expenses`
  envelope is stored under the shorter budget name **`Others`**; the other three
  keep their CSV name.
- Everything else (`KPR`, `Papa`, `Electricity …`, `IPL …`, `Netflix`, …) → these
  are **fixed expenses** (recurring bills).

---

## 2. Sign conventions

| Where | Sign | Meaning |
|------|------|---------|
| B–F category cell | positive | a spend (consumes the envelope) |
| B–F category cell | negative | a refund / budget restored (adds back) |
| G Credit Card | negative | a charge on the card |
| G Credit Card | positive | a payment **into** the card (pays down balance) |
| H Income | positive | money in |
| H Income | negative | a reversal of prior income |

The app's `transactions.amount` is signed for `income`/`expense` (per the
`allow_signed_amounts` migration): a negative `expense` adds cash back **and**
reduces the category/budget totals without touching income.

---

## 3. Mapping to the schema

| Spreadsheet concept | App target | Notes |
|---|---|---|
| BCA account | `accounts` (bank_account) | id supplied per import |
| Credit Card column | `accounts` (credit_card) | charges live here |
| Each ledger row | one `transactions` row | `status='confirmed'`, **`category_id` always NULL** (this sheet does not categorize) |
| Food/Transport/Social/Other value | `expense` + `budget_id` | linked to the budget of the same name (the `Other Expenses` column links to the **`Others`** budget); no category |
| **Day-01 "budget restore" rows** | `budgets.periodic_amount` — **NOT a transaction** | the app computes running budget natively (`v_budget_progress`); importing the −seed would double-count |
| Col-M value for those 4 names | that budget's `periodic_amount` | budget identity is `(user_id, name, year_month)` |
| Other col-L names | `fixed_expenses` rows (one per `year_month`) | amount from col M |
| Monthly Expenses spend whose Description matches a detail name | `expense` + `fixed_expense_id` link, **`description` NULL** | **the link = the bill is paid** (match is case-insensitive/trimmed). The Description is only the matching key — once linked it's redundant, so it is **not** stored on the transaction |
| A detail with **no** matching Description | **not imported** | the month is closed, so an unpaid fixed expense is stale data — only paid bills become `fixed_expenses` rows |
| Income column | `income` on the bank account | Salary, Bank Interest, etc. |

> **No categories.** This spreadsheet does not categorize transactions, so every
> imported transaction has `category_id = NULL` and no category rows are created.
> Classification is carried by the budget link (B–E) and the fixed-expense link
> (Monthly Expenses) instead.

### Account routing for a ledger row

1. **Budget category present (B–E):** `expense`, amount = the signed cell value,
   `budget_id` = that name (no category). Account = **card** if G is also
   populated (the mirror), else **bank**.
2. **Monthly Expenses present (F):** `expense`, amount = cell value,
   `fixed_expense_id` = matched detail (if any). Account = **card** if G
   populated, else **bank**.
3. **Card-only (G, nothing in B–F):**
   - negative → `expense` on the card, amount = `-value` (a charge).
   - positive → **transfer** bank → card, amount = `value` (a card payment).
4. **Income-only (H):** `income` on the bank account.

A row can populate **both** a budget column **and** Monthly Expenses (one combined
card charge covering a budget spend + a recurring bill, e.g. Apr 2026 row 120:
`Others` Rp3,000 + `Electricity VPP` Rp1,000,000 on a Rp1,003,000 charge). Such a
row is **split into two expenses** (rules 1 and 2), which sum to the card mirror.

---

## 4. Confirmed decisions (2026-06-13)

- **Day-01 budget seeds** become `budgets.periodic_amount`, not transactions.
- **Budget naming:** the CSV's `Other Expenses` envelope is stored as the budget
  **`Others`**; `Food` / `Transport` / `Social` keep their names.
- **Unpaid fixed expenses are dropped.** The month is closed, so a Monthly
  Expenses Details entry with no paying transaction (e.g. May 2026: `Savings`,
  `Electricity VPP`) is treated as stale sheet data and is **not** imported.
- **Positive Credit Card entries** → **transfer** from BCA bank into the card.
- **"Lidya Laparoskopi" rows** (large Income + Card + a −40M expense) are imported
  **literally**: each populated Income/Card column becomes its own transaction
  (Income col → `income`; Card col → a signed `expense` on the card). This is a
  placeholder — the real-world hospital-financing flow is to be **cleaned up
  manually after import**.

> **Row count vs transaction count.** Because the two Lidya rows (rows 63 & 72)
> each fill both Income and Card, they split into two transactions each. So May
> 2026's **148 ledger rows** (the Salary row + rows 9–155, minus the four day-01
> seed rows) yield **150 transactions** — 7 income, 141 expense, 2 transfer.

---

## 5. Running an import

1. `python3 supabase/imports/generate_monthly.py <YYYY-MM>` (e.g. `2026-05`) —
   reads `…/Finance Management 5.0 - <Mon> <YYYY>.csv` and writes
   `supabase/imports/<YYYY-MM>-bca.sql`, printing a reconciliation summary (income
   is checked against the sheet's stated total). One generator handles every
   month; ids are namespaced by month so they never collide.
2. Review the `.sql`, then paste it into the **Supabase SQL editor** (or run via
   `psql`). It is wrapped in one transaction and is **idempotent**: budgets and
   fixed expenses upsert on their natural keys, and every transaction carries a
   deterministic `uuid5` id with `ON CONFLICT (id) DO NOTHING`. (No category rows
   are created.)

The user / account ids are constants at the top of `generate_monthly.py`.

### Validation & known gaps

- **Income** reconciled exactly for May 2026 (`Rp58,032,963`).
- The expense total does **not** equal the sheet's "Total Expenses" — that cell is
  a running-budget rollup and nets transfers/Lidya differently. Not a 1:1 check.
- **Account balances** won't match the sheet's "Current Balance": the import does
  **not** set `accounts.starting_balance`. The computed month balance =
  starting_balance + that month's net. Set starting balances (or backfill prior
  months) separately to land on the sheet's absolute figures.
- The Lidya literal import leaves artifacts (negative income, negative "credit"
  expenses on the card) to be reconciled when that flow is modelled properly.

## 6. Budget carry-over seed

Each sheet's **Row 2** is the previous month's ending budget per envelope (it
equals the prior sheet's Row 3). The app computes carry-over natively —
`v_budget_progress` chains `remaining(M-1) → carry_in(M)` across **consecutive**
months — so once two months are imported back-to-back the carry-over is automatic
(verified: with `carry_in = Row 2`, periodic + carry_in − spent reproduces Row 3
**exactly** for every envelope in Apr & May 2026).

The gap is the **earliest** imported month: it has no prior lineage, so its
`carry_in` defaults to 0 instead of its Row 2. `generate_carryover_seed.py <first
month>` fixes this by seeding the month before it:

- One budget per envelope (standard periodic) for the previous month, plus **one
  dummy BCA expense** sized `periodic − Row2`, so `remaining = Row 2` and
  `carry_in(first month) = Row 2`.
- Envelopes with Row 2 = 0 are skipped (they anchor at `carry_in 0` anyway).
- `python3 generate_carryover_seed.py 2026-04` → `2026-03-carryover-seed.sql`.
  **Run it before the monthly imports.**

Per the user's choice the dummy expenses are on the **real BCA account**, so they
**do** move the BCA balance (cascading forward). Account balances are handled
separately, so that's accepted for now. When the real previous month is later
imported, it supersedes this seed (delete the seed rows first to avoid doubling).

---

# Part B — Non-monthly format

**File:** `Finance Management 5.0 - Non-Monthly Transaction.csv`
**Generator:** `generate_nonmonthly.py` → `non-monthly.sql`

A flat, **one-row-per-transaction** ledger of unplanned / one-off spending
(`Car Expenses`, `House Renovation`, `Wedding`, `Savings`, …) spanning many
months. There are **no budgets and no fixed expenses** — just transactions, each
with a category.

### Columns

| Col | Meaning |
|----|---------|
| Date | ISO `YYYY-MM-DD` |
| Category | free-text category, often event-scoped (`Housing 2024` ≠ `Housing 2025`); kept **literal** |
| Description | free text, sometimes blank → `NULL` |
| Amount | signed Rupiah — **positive = a spend**, **negative = money back** (refund / sold / reimbursed) |

### Mapping & decisions (confirmed 2026-06-13)

- **Account:** every row defaults to **BCA**. Some are really on the **BCA VISA
  card**; each row in the generated SQL carries an editable `'BCA'`/`'CARD'`
  token (resolved by a `CASE`), so flip the relevant rows to `'CARD'` **before
  the first run**. (Re-running won't change already-imported rows — see below.)
- **Categories:** created (upsert by name) and linked via
  `transactions.category_id`. This differs from the monthly format, which sets
  `category_id = NULL`.
- **Sign → type:** every row is an `expense`. A negative amount is a **negative
  expense** (adds cash back, reduces that category's net). Rows that are really
  income (bonus / THR / sold items) stay as negative expense; **reclassify them
  manually** afterward.
- No `budget_id` / `fixed_expense_id` (n/a for this format).

### Running it

`python3 supabase/imports/generate_nonmonthly.py` → writes `non-monthly.sql` and
prints a summary (215 transactions, 30 categories, 2024-06…2026-06, 33 negative).
Same idempotency model as Part A: categories upsert by name, each transaction has
a deterministic `uuid5` id with `ON CONFLICT (id) DO NOTHING`.

**The file is split for per-month execution.** It contains a **SETUP** block
(`BEGIN/COMMIT`) with all categories + balance rows — run it **once** — followed
by **one `BEGIN/COMMIT` block per month** holding just that month's transactions.
Run the months in date order so balances settle as you go; each block is
independent and re-runnable. Overlap-tagged rows (see below) are called out in
the relevant month's banner.

> **Edit before first run.** Because of `ON CONFLICT (id) DO NOTHING`, changing a
> row's account token (or amount) and re-running will **not** update a row that
> was already imported. Make account edits in the `.sql` before running it once.
> The generator also ensures `account_monthly_balances` rows exist for every
> month in range (both accounts) so the balance-recalc trigger has rows to fill.

### Cross-sheet overlaps with the monthly sheets

The non-monthly sheet shares some **real transactions** with the monthly sheets
(big one-off charges show up in both). Running both imports would double-count
them. Confirmed duplicates are recorded in `overlaps-<YYYY-MM>.md` (per month).
The **non-monthly record is kept as the single source**; the matching row in the
monthly `<YYYY-MM>-bca.sql` is **commented out and marked** (not deleted) with:
`-- DUPLICATE of non-monthly sheet — commented out for review, see overlaps-<YYYY-MM>.md`.
`generate_monthly.py` does this automatically — it imports `MONTHLY_OVERLAPS` and
comments any transaction whose date + amount is registered. The rows are left
commented so you can **review them before running** — uncomment only if you decide
the monthly side should win instead.

The match key is **date + amount**; the set is **human-reviewed** in
`MONTHLY_OVERLAPS` (top of `generate_nonmonthly.py`) so coincidental collisions
are excluded (e.g. 2026-05-01 / Rp6,000,000, "Contractor 4" vs the monthly
"Papa"). Currently tagged: **April 2026 (5)** and **May 2026 (10)**. When you
import a new monthly sheet, re-run the date+amount check for that month, review,
and extend `MONTHLY_OVERLAPS`.
