# Overlapping transactions — January 2026

The monthly sheet (`2026-01-bca.sql`) and the non-monthly sheet (`non-monthly.sql`)
both contain the **same real transactions** for January 2026. Running both imports
as-is would **double-count** them.

Matched on **same date + same amount**. The non-monthly sheet is kept as the
single source: each matching monthly row is **commented out and marked** in
`2026-01-bca.sql` (`-- DUPLICATE of non-monthly sheet …`), and the non-monthly
row stays active (on the CARD) with an informational tag. Review the commented
rows before running; uncomment one only if you decide the monthly side should win.

## Genuine duplicates (2) — appear in BOTH imports

Both are the same one-off card charges. On the monthly sheet they are card-only
rows with no description; the non-monthly sheet names them (Fashion). No
coincidental date+amount collisions this month.

| Date | Amount | Non-monthly (category / description) | Monthly (description) |
|------|-------:|--------------------------------------|-----------------------|
| 2026-01-04 | Rp599,000 | Fashion / Celana | _(card-only, no description)_ |
| 2026-01-04 | Rp247,401 | Fashion / Sepatu | _(card-only, no description)_ |

**Double-counted total if both run as-is: Rp846,401.**

## Non-monthly rows that are NOT duplicates (5)

These January non-monthly rows have no date+amount match in the monthly sheet and
import only from the non-monthly sheet:

| Date | Amount | Category / Description |
|------|-------:|-----------------------|
| 2026-01-01 | −Rp14,078,000 | Savings / Superbank Deposit |
| 2026-01-08 | Rp5,282,500 | SQ Parking / Parkir Jan-Dec 2026 |
| 2026-01-20 | Rp1,600,000 | Wedding / Jember Ticket |
| 2026-01-21 | Rp177,500 | Wedding / Kertanegara |
| 2026-01-21 | Rp375,000 | Wedding / Hotel Anda |
