# Overlapping transactions — April 2026

The monthly sheet (`2026-04-bca.sql`) and the non-monthly sheet (`non-monthly.sql`)
both contain the **same real transactions** for April 2026. Running both imports
as-is would **double-count** them. This is for manual review — neither `.sql`
file has been changed (the non-monthly rows are only **tagged** with a comment).

Matched on **same date + same amount**. All 5 matches are genuine — no
coincidental date+amount collision this month.

## Genuine duplicates (5) — appear in BOTH imports

To resolve, delete each row from **one** side before running (the non-monthly
sheet is the more natural "owner" of one-off/project spend).

| Date | Amount | Non-monthly (category / description) | Monthly (description) |
|------|-------:|--------------------------------------|-----------------------|
| 2026-04-04 | Rp472,184 | Bluetooth Keyboard / Bluetooth Keyboard | BT Keyboard |
| 2026-04-04 | Rp1,198,752 | Shoes / Crocs | Crocs |
| 2026-04-04 | Rp2,679,963 | Secret Lab / Recliner | Secret Lab Recliner |
| 2026-04-05 | Rp16,099,749 | House Renovation / Material Dunia Bangunan | Material Dunia Bangunan |
| 2026-04-18 | Rp554,484 | House Renovation / Keramik | Dunia Bangunan |

**Double-counted total if both run as-is: Rp20,005,132.**
