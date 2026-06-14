# Overlapping transactions — March 2026

The monthly sheet (`2026-03-bca.sql`) and the non-monthly sheet (`non-monthly.sql`)
both contain the **same real transactions** for March 2026. Running both imports
as-is would **double-count** them.

Matched on **same date + same amount**. The non-monthly sheet is kept as the
single source: each matching monthly row is **commented out and marked** in
`2026-03-bca.sql` (`-- DUPLICATE of non-monthly sheet …`), and the non-monthly
row stays active with an informational tag. Review the commented rows before
running; uncomment one only if you decide the monthly side should win instead.

## Genuine duplicates (3) — appear in BOTH imports

All 3 are genuine — descriptions match, no coincidental date+amount collision
this month.

| Date | Amount | Non-monthly (category / description) | Monthly (description) |
|------|-------:|--------------------------------------|-----------------------|
| 2026-03-01 | Rp1,695,885 | Software Development / Apple Developer | Apple Developer |
| 2026-03-05 | Rp642,443 | PBB Alegria / PBB Alegria | PBB Alegria |
| 2026-03-23 | Rp6,939,639 | Digivice / D-Ark 25th | D-Ark |

**Double-counted total if both run as-is: Rp9,277,967.**
