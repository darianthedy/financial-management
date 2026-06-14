# Overlapping transactions — May 2026

The monthly sheet (`2026-05-bca.sql`) and the non-monthly sheet (`non-monthly.sql`)
both contain the **same real transactions** for May 2026. Running both imports
as-is would **double-count** them. This is for manual review — neither `.sql`
file has been changed.

Matched on **same date + same amount**. Only May 2026 is covered (the only month
the two sheets currently overlap); re-check this when importing other monthly
sheets.

## Genuine duplicates (10) — appear in BOTH imports

To resolve, delete each row from **one** side before running (the non-monthly
sheet is the more natural "owner" of one-off/project spend; these monthly-side
rows are all credit-card `House Renovation`-type charges).

| Date | Amount | Non-monthly (category / description) | Monthly (description) |
|------|-------:|--------------------------------------|-----------------------|
| 2026-05-03 | Rp204,700 | House Renovation / *(blank)* | House Renovation |
| 2026-05-06 | Rp328,246 | House Renovation / *(blank)* | House Renovation |
| 2026-05-13 | Rp342,430 | House Renovation / Tangga Rumah Lipat | Tangga Rumah Lipat |
| 2026-05-16 | Rp4,300,973 | House Renovation / TTRacing Titus X | TTRacing Titus X |
| 2026-05-18 | Rp1,431,500 | House Renovation / TP Link | TP Link Router |
| 2026-05-20 | Rp107,982 | House Renovation / Cable Management | Cable Management |
| 2026-05-20 | Rp269,705 | House Renovation / Vention Cable Management | Vention Cable Management |
| 2026-05-23 | Rp1,026,422 | PIA / PIA | PIA |
| 2026-05-24 | Rp901,500 | House Renovation / Headboard | Headboard |
| 2026-05-24 | Rp27,213,000 | House Renovation / IKEA | IKEA Furniture |

**Double-counted total if both run as-is: Rp36,126,458.**

## Likely false positive (1) — keep both

| Date | Amount | Non-monthly | Monthly | Note |
|------|-------:|-------------|---------|------|
| 2026-05-01 | Rp6,000,000 | House Renovation / Contractor 4 | Papa | Same date+amount by **coincidence** — a contractor payment vs the monthly "Papa" allowance. Different transactions; do **not** dedupe. |
