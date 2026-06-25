#!/usr/bin/env python3
"""
Find transactions that appear in BOTH a monthly sheet and the non-monthly sheet,
so they can be deduped before import (see README "Cross-sheet overlaps").

Usage:
    python3 check_overlaps.py <YYYY-MM>
    e.g. python3 check_overlaps.py 2026-04

Compares <YYYY-MM>-bca.sql (must be generated first) against the rows of the
non-monthly CSV in that month, matching on (date, absolute amount). Prints each
candidate, flags whether it's already in MONTHLY_OVERLAPS, and emits ready-to-
paste tuples for any new ones. The set is HUMAN-REVIEWED — eyeball the list for
coincidental date+amount collisions before adding them to generate_nonmonthly.py.
"""

import csv
import importlib.util
import re
import sys
from collections import defaultdict
from pathlib import Path

if len(sys.argv) != 2 or len(sys.argv[1]) != 7 or sys.argv[1][4] != "-":
    raise SystemExit("usage: python3 check_overlaps.py <YYYY-MM>  (e.g. 2026-04)")

YM = sys.argv[1]
HERE = Path(__file__).resolve().parent
NM_CSV = Path("/mnt/e/Downloads/Finance Management 5.0 - Non-Monthly Transaction.csv")
SQL = HERE / f"{YM}-bca.sql"


def money(s):
    s = (s or "").strip()
    if not s:
        return None
    neg = s.startswith("-")
    d = s.replace("-", "").replace("Rp", "").replace(",", "").strip()
    return None if not d else (-int(d) if neg else int(d))


def load_registered():
    """The human-reviewed MONTHLY_OVERLAPS set from generate_nonmonthly.py."""
    spec = importlib.util.spec_from_file_location("gnm", HERE / "generate_nonmonthly.py")
    mod = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(mod)
    return mod.MONTHLY_OVERLAPS


def main():
    if not SQL.exists():
        raise SystemExit(f"{SQL.name} not found — run generate_monthly.py {YM} first.")
    registered = load_registered()

    # Non-monthly rows in this month.
    nm = []
    for r in csv.reader(NM_CSV.open(encoding="utf-8-sig")):
        if len(r) < 4 or r[0].strip() == "Date":
            continue
        date, amt = r[0].strip(), money(r[3])
        if date.startswith(YM) and amt is not None:
            nm.append((date, amt, r[1].strip(), r[2].strip()))

    # Monthly transactions from the generated SQL. The VALUES tuple is
    # (id, acct, xfer, type, amount, date, budget, fixed, category, description);
    # we capture type, amount, date and the trailing description (for display).
    tup = re.compile(
        r"^\s+\('[0-9a-f-]{36}',\s*'(?:BCA|CARD)'\s*,\s*(?:NULL|'CARD')\s*,"
        r"\s*'(\w+)'\s*,\s*(-?\d+),\s*'(" + YM + r"-\d\d)',"
        r"\s*(?:NULL|'[^']*')\s*,\s*(?:NULL|'[^']*')\s*,\s*(?:NULL|'[^']*')\s*,"
        r"\s*(NULL|'(?:[^']|'')*')\)")
    mo = defaultdict(list)
    for line in SQL.read_text().splitlines():
        m = tup.match(line)
        if m:
            d = m.group(4)
            d = "" if d == "NULL" else d[1:-1].replace("''", "'")
            mo[(m.group(3), abs(int(m.group(2))))].append((m.group(1), d))

    print(f"{YM}: {len(nm)} non-monthly rows, {sum(len(v) for v in mo.values())} monthly txns\n")
    new = []
    for date, amt, cat, desc in sorted(nm):
        for typ, mdesc in mo.get((date, abs(amt)), []):
            key = (date, amt)
            tag = "registered" if key in registered else "NEW — review!"
            if key not in registered:
                new.append((date, amt, desc or cat, mdesc))
            print(f"  {date} {amt:>12}  {desc or '('+cat+')':36} <-> [{typ}] {mdesc:28} [{tag}]")

    if new:
        print(f"\n{len(new)} new candidate(s) — after review, add to MONTHLY_OVERLAPS:")
        for date, amt, ndesc, mdesc in new:
            print(f'    ("{date}", {amt}),  # {ndesc} / {mdesc}')
    else:
        print("\nNo new overlaps (all already registered or none found).")


if __name__ == "__main__":
    main()
