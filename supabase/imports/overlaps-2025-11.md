# Overlapping transactions — November 2025

The monthly sheet (`2025-11-bca.sql`) and the non-monthly sheet (`non-monthly.sql`)
both contain the **same real transactions** for November 2025. Running both imports
as-is would **double-count** them. The non-monthly sheet is kept as the single
source; the matching monthly rows are already **commented out** in
`2025-11-bca.sql` (marked `DUPLICATE of non-monthly sheet`) — review them before
running.

Matched on **same date + same amount**. These are the Surabaya-trip one-off
charges; re-check this when importing other monthly sheets.

## Genuine duplicates (3) — appear in BOTH imports

The monthly-side rows are commented out (kept on the non-monthly side, on CARD).

| Date | Amount | Non-monthly (category / description) | Monthly (description) |
|------|-------:|--------------------------------------|-----------------------|
| 2025-11-14 | Rp1,700,000 | Surabaya Expenses / Tiket Kereta | Tiket Kereta |
| 2025-11-15 | Rp1,740,000 | Surabaya Expenses / Tiket Bus | Tiket Bus |
| 2025-11-16 | Rp3,241,496 | Surabaya Expenses / Hotel | Hotel |

**Double-counted total if both run as-is: Rp6,681,496.**

## Likely false positive (1) — keep both

| Date | Amount | Non-monthly | Monthly | Note |
|------|-------:|-------------|---------|------|
| 2025-11-29 | Rp7,500,000 | Wedding / Kalung | *(blank income)* | Same date+amount by **coincidence** — a necklace **purchase** (expense) here vs a Rp7,500,000 **income** with no description on the monthly sheet. Opposite directions; different transactions — do **not** dedupe. |
