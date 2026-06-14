#!/usr/bin/env python3
"""
Generate an idempotent SQL backfill for a monthly "Finance Management 5.0"
spreadsheet, mapping it onto the financial-management schema.

Usage:
    python3 generate_monthly.py <YYYY-MM>
    e.g. python3 generate_monthly.py 2026-05

It reads  /mnt/e/Downloads/Finance Management 5.0 - <Mon> <YYYY>.csv
and writes supabase/imports/<YYYY-MM>-bca.sql.

Mapping decisions (confirmed with the user):
  * Day-01 "budget restore" rows (Food/Transport/Social/Other) are NOT imported
    as transactions; they become budgets.periodic_amount (the app computes the
    running budget natively via v_budget_progress). The "Other Expenses" envelope
    is stored under the shorter budget name "Others".
  * Each budget spend links to a budget (no category — this sheet doesn't
    categorize, so category_id is always NULL).
  * Monthly Expenses Details (the other col-L names) -> fixed_expenses rows.
    A "Monthly Expenses" spend whose Description matches a detail name links via
    fixed_expense_id (= marks it paid). The month is closed, so details with no
    paying transaction are stale and are NOT imported.
  * Credit-Card column: negative = a charge (expense on the card account);
    positive = a payment -> TRANSFER from BCA bank into the card.
  * "Lidya Laparoskopi" rows are imported LITERALLY: each populated Income / Card
    column becomes its own transaction (income col -> income; card col -> a
    signed expense on the card).
  * Single-currency app (no per-row currency column). IDR has 0 decimal places,
    so figures are whole rupiah (no scaling).

Re-runnable: budgets/fixed_expenses upsert on their natural keys and every
transaction carries a deterministic uuid5 id with ON CONFLICT (id) DO NOTHING.
"""

import csv
import sys
import uuid
from pathlib import Path

if len(sys.argv) != 2 or len(sys.argv[1]) != 7 or sys.argv[1][4] != "-":
    raise SystemExit("usage: python3 generate_monthly.py <YYYY-MM>  (e.g. 2026-05)")

YM = sys.argv[1]
_year, _mon = int(YM[:4]), int(YM[5:])
_ABBREV = ["Jan", "Feb", "Mar", "Apr", "May", "Jun",
           "Jul", "Aug", "Sep", "Oct", "Nov", "Dec"]
_ny, _nm = (_year + 1, 1) if _mon == 12 else (_year, _mon + 1)
NEXT_YM = f"{_ny:04d}-{_nm:02d}"

CSV_PATH = Path(f"/mnt/e/Downloads/Finance Management 5.0 - {_ABBREV[_mon - 1]} {_year}.csv")
OUT_PATH = Path(__file__).resolve().parent / f"{YM}-bca.sql"

USER_ID = "9e36aab2-dc6e-4ff6-9ae1-c81e82225424"
BCA = "bfc92cd3-0eb3-497d-a7c2-7e7eb669e2ae"        # BCA bank_account
CARD = "2f940480-5908-4c11-9fa1-9ff7a58c65c9"       # BCA VISA SQ Infinite (credit_card)

# Stable namespace so re-generation yields the same transaction ids. The YM is
# folded into each id, so different months never collide.
NS = uuid.UUID("5f3b0a7e-2c4d-4b1e-9a8f-0d1e2c3b4a59")

# Column indices in the CSV.
C_DATE, C_FOOD, C_TRANSPORT, C_SOCIAL, C_OTHER = 0, 1, 2, 3, 4
C_MONTHLY, C_CARD, C_INCOME, C_DESC = 5, 6, 7, 8
C_TOTAL_EXP = 9
C_DETAIL_NAME, C_DETAIL_VAL = 11, 12

CAT_FOOD, CAT_TRANSPORT, CAT_SOCIAL, CAT_OTHER = (
    "Food", "Transport", "Social", "Other Expenses",
)
CAT_MONTHLY = "Monthly Expenses"
BUDGET_COLS = {C_FOOD: CAT_FOOD, C_TRANSPORT: CAT_TRANSPORT,
               C_SOCIAL: CAT_SOCIAL, C_OTHER: CAT_OTHER}
BUDGET_NAMES = set(BUDGET_COLS.values())  # CSV-side names (for detection)

# App budget names. The CSV's "Other Expenses" envelope is stored under the
# shorter budget name "Others"; the rest keep their CSV name.
BUDGET_DISPLAY = {CAT_OTHER: "Others"}


def budget_name(csv_name):
    return BUDGET_DISPLAY.get(csv_name, csv_name)


def money(cell: str):
    """'Rp2,600,000' -> 2600000 ; '-Rp410,575' -> -410575 ; '' -> None."""
    s = (cell or "").strip()
    if not s:
        return None
    neg = s.startswith("-")
    digits = s.replace("-", "").replace("Rp", "").replace(",", "").strip()
    if not digits:
        return None
    val = int(digits)
    return -val if neg else val


def sqlstr(s):
    if s is None:
        return "NULL"
    return "'" + s.replace("'", "''") + "'"


def tid(line_no: int, slot: str) -> str:
    return str(uuid.uuid5(NS, f"{YM}|line{line_no}|{slot}"))


def main():
    if not CSV_PATH.exists():
        raise SystemExit(f"CSV not found: {CSV_PATH}")
    rows = list(csv.reader(CSV_PATH.open(encoding="utf-8-sig")))

    # Stated totals from the summary row (row 3) for reconciliation.
    stated_income = money(rows[2][C_INCOME]) if len(rows) > 2 else None
    stated_total_exp = money(rows[2][C_TOTAL_EXP]) if len(rows) > 2 else None

    # ---- Parse the col-L/M reference block: budgets + fixed expenses ----
    budgets = {}        # name -> amount
    fixed = []          # list of (name, amount)
    fixed_by_key = {}   # normalized name -> canonical name (for txn linking)
    for r in rows:
        if len(r) <= C_DETAIL_VAL:
            continue
        name = (r[C_DETAIL_NAME] or "").strip()
        if not name or name.lower() == "total":
            continue
        amt = money(r[C_DETAIL_VAL])
        if amt is None:
            continue
        if name in BUDGET_NAMES:
            budgets[budget_name(name)] = amt
        else:
            fixed.append((name, amt))
            fixed_by_key[name.strip().lower()] = name

    # ---- Parse the daily ledger into transactions ----
    txns = []  # dicts
    current_day = None
    for i, r in enumerate(rows):
        line_no = i + 1
        if line_no < 4:          # rows 1-3 are headers / summary totals
            continue
        r = r + [""] * (13 - len(r)) if len(r) < 13 else r

        day_cell = (r[C_DATE] or "").strip()
        if day_cell.isdigit():
            current_day = int(day_cell)
        if current_day is None:
            continue
        date = f"{YM}-{current_day:02d}"

        monthly = money(r[C_MONTHLY]); card = money(r[C_CARD]); income = money(r[C_INCOME])
        desc = (r[C_DESC] or "").strip() or None

        budget_vals = [(c, money(r[c]))
                       for c in (C_FOOD, C_TRANSPORT, C_SOCIAL, C_OTHER)
                       if money(r[c]) is not None]

        # Skip the day-01 budget-seed rows (become budgets.periodic_amount).
        if current_day == 1 and desc in BUDGET_NAMES and budget_vals:
            continue

        is_lidya = bool(desc and "lidya" in desc.lower())

        def add(slot, **kw):
            txns.append({"line": line_no, "slot": slot, "date": date,
                         "description": desc, **kw})

        if is_lidya:
            # Literal: one txn per populated monetary column.
            if income is not None:
                add("inc", type="income", amount=income, account=BCA)
            if card is not None:
                # negative card = charge (positive expense); positive = credit.
                add("card", type="expense", amount=-card, account=CARD)
            continue

        # A row can populate MULTIPLE budget columns and/or Monthly Expenses (one
        # combined card charge covering several allocations, e.g. Apr row 54:
        # Transport 500,000 + Others 3,100; row 120: Others 3,000 + Electricity
        # VPP 1,000,000). Emit one expense per populated allocation; together they
        # sum to the card mirror.
        acct = CARD if card is not None else BCA
        handled = False
        for c, v in budget_vals:
            add(f"b{c}", type="expense", amount=v, account=acct,
                budget=budget_name(BUDGET_COLS[c]))
            handled = True
        if monthly is not None:
            fx = fixed_by_key.get((desc or "").strip().lower()) if desc else None
            add("monthly", type="expense", amount=monthly, account=acct, fixed=fx)
            handled = True
        if handled:
            continue

        if card is not None:
            if card < 0:
                add("card", type="expense", amount=-card, account=CARD)
            else:
                add("card", type="transfer", amount=card,
                    account=BCA, transfer=CARD)
            continue

        if income is not None:
            add("inc", type="income", amount=income, account=BCA)
            continue
        # else: only L/M or totals -> no transaction

    # The month is closed, so a fixed expense with no paying transaction is stale
    # data in the sheet. Keep only the ones an actual transaction links to.
    paid_names = {t["fixed"] for t in txns if t.get("fixed")}
    dropped = [n for n, _ in fixed if n not in paid_names]
    fixed = [(n, a) for n, a in fixed if n in paid_names]

    write_sql(budgets, fixed, txns)
    summarize(budgets, fixed, txns, dropped, stated_income, stated_total_exp)


def write_sql(budgets, fixed, txns):
    out = []
    w = out.append
    w("-- ============================================================")
    w(f"-- Backfill: '{CSV_PATH.name}'")
    w(f"-- User {USER_ID}")
    w(f"-- BCA bank {BCA} | BCA VISA card {CARD}")
    w("-- Idempotent: safe to re-run (natural-key upserts + deterministic txn ids).")
    w(f"-- Generated by supabase/imports/generate_monthly.py {YM}")
    w("-- ============================================================")
    w("BEGIN;")
    w("")
    w("-- NOTE: this spreadsheet does not categorize transactions, so every")
    w("--       transaction is imported with category_id = NULL.")
    w("")

    w("-- Budgets for the month (periodic_amount = the spreadsheet's budget).")
    for name, amt in budgets.items():
        w(f"INSERT INTO budgets (user_id, name, year_month, periodic_amount) "
          f"VALUES ({sqlstr(USER_ID)}, {sqlstr(name)}, {sqlstr(YM)}, {amt}) "
          f"ON CONFLICT (user_id, name, year_month) "
          f"DO UPDATE SET periodic_amount = EXCLUDED.periodic_amount;")
    w("")

    w("-- Fixed expenses (Monthly Expenses Details). Only paid ones are imported.")
    for name, amt in fixed:
        w(f"INSERT INTO fixed_expenses (user_id, name, year_month, amount) "
          f"VALUES ({sqlstr(USER_ID)}, {sqlstr(name)}, {sqlstr(YM)}, {amt}) "
          f"ON CONFLICT (user_id, name, year_month) "
          f"DO UPDATE SET amount = EXCLUDED.amount;")
    w("")

    w("-- Ensure monthly-balance rows exist so the recalc trigger has rows to update.")
    for acct in (BCA, CARD):
        for ym in (YM, NEXT_YM):
            w(f"INSERT INTO account_monthly_balances (account_id, year_month, balance) "
              f"VALUES ({sqlstr(acct)}, {sqlstr(ym)}, 0) "
              f"ON CONFLICT (account_id, year_month) DO NOTHING;")
    w("")

    # Transactions: one INSERT ... SELECT over a VALUES list. Each row stays pure
    # data (account as BCA/CARD, budget/fixed referenced by name); the ids are
    # resolved once in the JOINs below. Easier to review than per-row subselects.
    def cell(v, width=0, right=False):
        if v is None:
            s = "NULL"
        elif isinstance(v, int):
            s = str(v)
        else:
            s = "'" + v.replace("'", "''") + "'"
        if width:
            s = s.rjust(width) if right else s.ljust(width)
        return s

    w(f"-- Transactions ({len(txns)} rows). category_id is always NULL (no categories).")
    w("-- Per row: (id, acct, xfer, type, amount, date, budget, fixed, description).")
    w("INSERT INTO transactions")
    w("  (id, user_id, account_id, transfer_account_id, type, status,")
    w("   amount, description, date, category_id, budget_id, fixed_expense_id)")
    w("SELECT")
    w(f"  v.id::uuid, {sqlstr(USER_ID)}::uuid,")
    w(f"  CASE v.acct WHEN 'BCA' THEN {sqlstr(BCA)}::uuid "
      f"WHEN 'CARD' THEN {sqlstr(CARD)}::uuid END,")
    w(f"  CASE v.xfer WHEN 'CARD' THEN {sqlstr(CARD)}::uuid ELSE NULL END,")
    w("  v.type::transaction_type, 'confirmed',")
    w("  v.amount, v.description, v.date::date,")
    w("  NULL,   -- category_id (this sheet does not categorize)")
    w("  b.id,   -- budget_id        (matched by name)")
    w("  f.id    -- fixed_expense_id (matched by name)")
    w("FROM (VALUES")

    n = len(txns)
    prev_date = None
    for idx, t in enumerate(txns):
        if t["date"] != prev_date:
            w(f"    -- {t['date']}")
            prev_date = t["date"]
        acct_tok = "BCA" if t["account"] == BCA else "CARD"
        xfer_tok = "CARD" if t.get("transfer") else None
        parts = [
            cell(tid(t["line"], t["slot"])),
            cell(acct_tok, 6),
            cell(xfer_tok, 6),
            cell(t["type"], 10),
            cell(t["amount"], 11, right=True),
            cell(t["date"]),
            cell(t.get("budget"), 18),
            cell(t.get("fixed"), 22),
            cell(t["description"]),
        ]
        comma = "," if idx < n - 1 else ""
        w(f"    ({', '.join(parts)}){comma}")

    w("  ) AS v(id, acct, xfer, type, amount, date, budget_name, fixed_name, description)")
    w(f"LEFT JOIN budgets b")
    w(f"  ON b.user_id = {sqlstr(USER_ID)}::uuid")
    w(f"  AND b.year_month = {sqlstr(YM)} AND b.name = v.budget_name")
    w(f"LEFT JOIN fixed_expenses f")
    w(f"  ON f.user_id = {sqlstr(USER_ID)}::uuid AND f.year_month = {sqlstr(YM)}")
    w(f"  AND f.name = v.fixed_name")
    w("ON CONFLICT (id) DO NOTHING;")
    w("")
    w("COMMIT;")
    OUT_PATH.write_text("\n".join(out) + "\n", encoding="utf-8")


def summarize(budgets, fixed, txns, dropped, stated_income, stated_total_exp):
    inc = sum(t["amount"] for t in txns if t["type"] == "income")
    exp = sum(t["amount"] for t in txns if t["type"] == "expense")
    xfer = sum(t["amount"] for t in txns if t["type"] == "transfer")
    n_card = sum(1 for t in txns if t["account"] == CARD)
    n_bca = sum(1 for t in txns if t["account"] == BCA)
    linked_fx = sum(1 for t in txns if t.get("fixed"))
    ok = "OK" if stated_income == inc else "MISMATCH"
    print(f"Wrote {OUT_PATH}  ({YM}, from {CSV_PATH.name})")
    print(f"  budgets:        {len(budgets)}  {budgets}")
    print(f"  fixed expenses: {len(fixed)} (paid only)")
    print(f"    dropped (no paying txn, month closed): {dropped}")
    print(f"  fixed-expense links on txns: {linked_fx}")
    print(f"  transactions:   {len(txns)}  (BCA {n_bca}, card {n_card})")
    print(f"  income total:   Rp{inc:,}   (sheet row 3: Rp{stated_income:,}) [{ok}]")
    print(f"  expense total:  Rp{exp:,}   (sheet Total Expenses: Rp{stated_total_exp:,})")
    print(f"  transfer total: Rp{xfer:,}")


if __name__ == "__main__":
    main()
