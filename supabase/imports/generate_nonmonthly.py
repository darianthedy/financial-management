#!/usr/bin/env python3
"""
Generate an idempotent SQL backfill for the "Finance Management 5.0 - Non-Monthly
Transaction" spreadsheet — a flat ledger of unplanned/one-off transactions
spanning many months. Completely different shape from the monthly sheet: it has
NO budgets and NO fixed expenses, just one transaction per row.

Source CSV (Windows path, WSL mount):
    /mnt/e/Downloads/Finance Management 5.0 - Non-Monthly Transaction.csv
Expected header (asserted at parse time so the wrong file fails loudly):
    Date,Category,Description,Amount

Output:
    supabase/imports/non-monthly.sql

Mapping decisions (confirmed with the user):
  * Account: every row defaults to BCA. Some are really on the BCA VISA card —
    each VALUES row carries an editable 'BCA'/'CARD' token, so flip a row to
    'CARD' before running. (Re-running won't change already-imported rows; see
    the idempotency note below — edit before the first run.)
  * Categories: created (upsert by name) and linked via transactions.category_id.
    Event-scoped names are kept literal (e.g. 'Housing 2024' != 'Housing 2025').
  * Sign: every row is an `expense`; a NEGATIVE amount is a negative expense
    (money back / refund), per the allow_signed_amounts model. Rows that are
    really income (bonus/THR/sold items) are left as negative expense for the
    user to reclassify manually.
  * IDR has 0 decimal places — whole rupiah, no scaling. The app is
    single-currency, so there is no per-row currency column.

Re-runnable: categories upsert by name and every transaction carries a
deterministic uuid5 id with ON CONFLICT (id) DO NOTHING.
"""

import csv
import uuid
from pathlib import Path

CSV_PATH = Path("/mnt/e/Downloads/Finance Management 5.0 - Non-Monthly Transaction.csv")
OUT_PATH = Path(__file__).resolve().parent / "non-monthly.sql"
EXPECTED_HEADER = ["Date", "Category", "Description", "Amount"]

USER_ID = "9e36aab2-dc6e-4ff6-9ae1-c81e82225424"
BCA = "bfc92cd3-0eb3-497d-a7c2-7e7eb669e2ae"        # BCA bank_account
CARD = "2f940480-5908-4c11-9fa1-9ff7a58c65c9"       # BCA VISA SQ Infinite (credit_card)

# Distinct namespace from the monthly generator so ids never collide.
NS = uuid.UUID("9c1d7b40-5a2e-4f86-b3c1-7e9a0d4f8b22")

# Cross-sheet duplicates: rows that are the SAME real transaction as a row in a
# monthly sheet (see overlaps-<month>.md). Keyed by (date, amount). This sheet is
# kept as the single source — the matching row in the monthly <YYYY-MM>-bca.sql is
# the one emitted commented-out (generate_monthly.py imports this set); here the
# rows stay active and just get an informational marker.
# Human-reviewed — the coincidental date+amount collision on 2026-05-01 /
# 6,000,000 ("Contractor 4" here vs the monthly "Papa" allowance) is NOT listed.
# Extend this when importing additional monthly sheets.
MONTHLY_OVERLAPS = {
    # April 2026 (see overlaps-2026-04.md) — all 5 genuine, no false positives.
    ("2026-04-04", 472184),     # Bluetooth Keyboard / BT Keyboard
    ("2026-04-04", 1198752),    # Crocs
    ("2026-04-04", 2679963),    # Recliner / Secret Lab Recliner
    ("2026-04-05", 16099749),   # Material Dunia Bangunan
    ("2026-04-18", 554484),     # Keramik / Dunia Bangunan
    # May 2026 (see overlaps-2026-05.md)
    ("2026-05-03", 204700),
    ("2026-05-06", 328246),
    ("2026-05-13", 342430),
    ("2026-05-16", 4300973),
    ("2026-05-18", 1431500),
    ("2026-05-20", 107982),
    ("2026-05-20", 269705),
    ("2026-05-23", 1026422),
    ("2026-05-24", 901500),
    ("2026-05-24", 27213000),
}


def overlap_note(date):
    ym = date[:7]
    return (f"Also in monthly {ym} sheet — kept HERE as the source; the monthly "
            f"row is commented out (see overlaps-{ym}.md)")


def money(cell: str):
    """'Rp5,000,000' -> 5000000 ; '-Rp19,350,000' -> -19350000 ; '' -> None."""
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
    return "NULL" if s is None else "'" + s.replace("'", "''") + "'"


def tid(line_no: int) -> str:
    return str(uuid.uuid5(NS, f"non-monthly|line{line_no}"))


def main():
    rows = list(csv.reader(CSV_PATH.open(encoding="utf-8-sig")))
    if not rows or [h.strip() for h in rows[0]] != EXPECTED_HEADER:
        raise SystemExit(
            f"Unexpected header {rows[0] if rows else None!r}; "
            f"expected {EXPECTED_HEADER}. Is this the non-monthly CSV?"
        )

    txns = []          # dicts: line, date, category, description, amount
    categories = []    # distinct category names, first-seen order
    seen_cat = set()
    for i, r in enumerate(rows):
        line_no = i + 1
        if line_no == 1:
            continue
        if len(r) < 4:
            continue
        date = (r[0] or "").strip()
        category = (r[1] or "").strip()
        description = (r[2] or "").strip() or None
        amount = money(r[3])
        if not date or amount is None:
            continue
        if category and category not in seen_cat:
            seen_cat.add(category)
            categories.append(category)
        txns.append({"line": line_no, "date": date, "category": category or None,
                     "description": description, "amount": amount})

    write_sql(categories, txns)
    summarize(categories, txns)


def write_sql(categories, txns):
    out = []
    w = out.append

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

    def emit_month_insert(month_txns):
        """One self-contained INSERT for a single month's transactions."""
        w("INSERT INTO transactions")
        w("  (id, user_id, account_id, transfer_account_id, type, status,")
        w("   amount, description, date, category_id, budget_id, fixed_expense_id)")
        w("SELECT")
        w(f"  v.id::uuid, {sqlstr(USER_ID)}::uuid,")
        w(f"  CASE v.acct WHEN 'BCA' THEN {sqlstr(BCA)}::uuid "
          f"WHEN 'CARD' THEN {sqlstr(CARD)}::uuid END,")
        w("  NULL,                       -- transfer_account_id (no transfers here)")
        w("  'expense'::transaction_type, 'confirmed',")
        w("  v.amount, v.description, v.date::date,")
        w("  c.id,                       -- category_id (matched by name)")
        w("  NULL, NULL                  -- budget_id, fixed_expense_id (n/a)")
        w("FROM (VALUES")
        last = len(month_txns) - 1
        for idx, t in enumerate(month_txns):
            parts = [
                cell(tid(t["line"])),
                cell("BCA", 6),
                cell(t["amount"], 13, right=True),
                cell(t["date"]),
                cell(t["category"], 24),
                cell(t["description"]),
            ]
            comma = "," if idx < last else ""
            mark = (f"  -- {overlap_note(t['date'])}"
                    if (t["date"], t["amount"]) in MONTHLY_OVERLAPS else "")
            w(f"    ({', '.join(parts)}){comma}{mark}")
        w("  ) AS v(id, acct, amount, date, category_name, description)")
        w(f"LEFT JOIN categories c "
          f"ON c.user_id = {sqlstr(USER_ID)}::uuid AND c.name = v.category_name")
        w("ON CONFLICT (id) DO NOTHING;")

    w("-- ============================================================")
    w("-- Backfill: 'Finance Management 5.0 - Non-Monthly Transaction.csv'")
    w(f"-- User {USER_ID}")
    w(f"-- Default account BCA {BCA}")
    w(f"-- Credit card        {CARD}  (flip a row's 'BCA' token to 'CARD' to use it)")
    w("-- No budgets / no fixed expenses. Every row is an expense (negative = money back).")
    w("-- Idempotent: re-runnable, but ON CONFLICT (id) DO NOTHING means edits to")
    w("-- already-imported rows are ignored — make account edits BEFORE the first run.")
    w("-- Rows marked 'Also in monthly <YYYY-MM> sheet' are the same real transaction")
    w("-- as a monthly-sheet row. This sheet is kept as the source, so they stay")
    w("-- ACTIVE here; the matching monthly row is commented out (no double-counting).")
    w("--")
    w("-- STRUCTURE: run the SETUP block once, then each month block (each is its own")
    w("-- transaction) — in date order if you want balances to settle as you go.")
    w("-- Generated by supabase/imports/generate_nonmonthly.py")
    w("-- ============================================================")
    w("")

    months = sorted({t["date"][:7] for t in txns})

    # ---- SETUP: categories + balance rows (run once) ----
    w("-- ============================================================")
    w("-- SETUP — run once before the per-month blocks.")
    w("-- ============================================================")
    w("BEGIN;")
    w("")
    w("-- Categories (create-or-reuse by name; event-scoped names kept literal).")
    for name in categories:
        w(f"INSERT INTO categories (user_id, name) VALUES "
          f"({sqlstr(USER_ID)}, {sqlstr(name)}) "
          f"ON CONFLICT (user_id, name) DO NOTHING;")
    w("")
    w("-- Monthly-balance rows for every month in range (both accounts) so the")
    w("-- balance-recalc trigger has rows to update, regardless of run order.")
    for acct in (BCA, CARD):
        for ym in months:
            w(f"INSERT INTO account_monthly_balances (account_id, year_month, balance) "
              f"VALUES ({sqlstr(acct)}, {sqlstr(ym)}, 0) "
              f"ON CONFLICT (account_id, year_month) DO NOTHING;")
    w("")
    w("COMMIT;")
    w("")

    # ---- Per-month transaction blocks ----
    by_month = {ym: [t for t in txns if t["date"][:7] == ym] for ym in months}
    for ym in months:
        mt = by_month[ym]
        dups = sum(1 for t in mt if (t["date"], t["amount"]) in MONTHLY_OVERLAPS)
        dup_note = f", {dups} tagged duplicate(s)" if dups else ""
        w("-- ============================================================")
        w(f"-- {ym}  ({len(mt)} transaction(s){dup_note})")
        w("-- ============================================================")
        w("BEGIN;")
        emit_month_insert(mt)
        w("COMMIT;")
        w("")

    OUT_PATH.write_text("\n".join(out) + "\n", encoding="utf-8")


def summarize(categories, txns):
    total = sum(t["amount"] for t in txns)
    neg = sum(1 for t in txns if t["amount"] < 0)
    overlaps = sum(1 for t in txns if (t["date"], t["amount"]) in MONTHLY_OVERLAPS)
    months = sorted({t["date"][:7] for t in txns})
    print(f"Wrote {OUT_PATH}")
    print(f"  transactions: {len(txns)}  ({neg} negative / money-back)")
    print(f"  shared with monthly sheet (kept here; monthly row commented out): {overlaps}")
    print(f"  categories:   {len(categories)}")
    print(f"  date span:    {months[0]} .. {months[-1]}  ({len(months)} months)")
    print(f"  net amount:   Rp{total:,}  (all expense; positive = net spend)")


if __name__ == "__main__":
    main()
