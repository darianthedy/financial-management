# iOS UI Compliance Audit — Capture Guide

Companion to `Financial Management - iOS UI Compliance Audit.md`. This tells you
**exactly what to capture, and what filename to save it as**, so Claude can do
the audit without guessing.

---

## Before you start

**Device:** One run on **iPhone 16 Pro** (notch/Dynamic Island, ProMotion) is
enough for the first pass. If you have time, repeat the 🎥 clips on an **iPhone SE**
to validate compact width + safe areas. Real device > Simulator (Simulator can't
show true haptics / ProMotion), but Simulator is fine for everything layout-related.

**How to toggle the conditions the audit asks for:**
- **Dark mode (Simulator):** `Features ▸ Toggle Appearance` (⌘⇧A) — or Settings app.
- **Dynamic Type XXL:** `Settings ▸ Accessibility ▸ Display & Text Size ▸ Larger Text`,
  drag to the largest **Accessibility** size. (Simulator: Environment Overrides ▸ Text.)
- **Reduce Motion:** `Settings ▸ Accessibility ▸ Motion ▸ Reduce Motion`.
- **VoiceOver:** `Settings ▸ Accessibility ▸ VoiceOver` (triple-click side button to toggle).
- **Screenshot (Simulator):** ⌘S → saves to Desktop. **Recording:** `File ▸ Record Screen` (⌘R).
- **Screenshot (device):** side+volume-up. **Recording:** Control Center screen record.

**Where to put files:** save everything into one folder named `captures/` and hand
that folder to Claude. Keep the filenames below **exactly** — the prompts reference them.

**Naming convention:**
```
<item>_<slug>_<variant>.<png|mov>
   item    = audit number, e.g. 4.1
   variant = light | dark | xxl | <state>   (state e.g. empty, overspent, addmode)
```
Example: `4.1_transactions_light.png`, `4.1_transactions_swipe.mov`.

**Priority tiers** (do P0 first — it covers the flagged risks and "critical" recordings):
- **P0** = the items the audit marks *critical* or flags in §9 (the real findings live here).
- **P1** = remaining stills (Light/Dark/XXL parity).
- **P2** = full device matrix, VoiceOver, Landscape, second device.

---

## Standard variants

Unless a row says otherwise, capture each screen **3 stills**: `_light`, `_dark`, `_xxl`
(XXL can be Light). Videos are always Light unless noted.

---

## P0 — Critical captures (do these first)

| Filename | What to show |
|---|---|
| `0.2_navbar_collapse.mov` | 🎥 Slow scroll up/down on Dashboard, Transactions, Accounts — large-title collapse + nav-bar background fade. Watch for any flicker/"pop" at the swap. |
| `0.3_theme_live.mov` | 🎥 Settings ▸ Theme: flip Light/Dark/System and watch the whole app (incl. an open sheet) re-theme live. |
| `2.1_dashboard_month.mov` | 🎥 Tap month forward/back several times — push transition + MonthNavigator numeric content transition + pull-to-refresh. Then **a second clip with Reduce Motion ON** → `2.1_dashboard_month_reducemotion.mov`. |
| `3.2_account_archive.mov` | 🎥 Account detail ▸ tap **Archive** — record whether it deletes + pops **with no confirmation** (flagged §9). |
| `3.3_account_dismiss.mov` | 🎥 Account form: make edits, then **swipe down to dismiss** — record whether unsaved data is silently lost (flagged §9). |
| `4.1_transactions_swipe.mov` | 🎥 On Transactions: leading swipe→Confirm (pending row); trailing swipe→reveal Delete+Dismiss; then a **full trailing swipe** — record whether it deletes immediately or asks for confirmation (flagged §9). |
| `4.1_transactions_search.mov` | 🎥 Type a search query (debounce), add/remove a filter token, clear. |
| `4.1_transactions_infinite.mov` | 🎥 Scroll to bottom → load-more spinner + new page appends (watch for jump). |
| `4.1_transactions_stickyheaders.mov` | 🎥 Slow scroll showing day headers pinning/replacing; net-amount column stays aligned; header fully opaque. |
| `4.3_txn_form_types.mov` | 🎥 Switch type Expense→Transfer→Income (fields appear/disappear); use +/− amount toggle; open DatePicker; open Category/Budget/Fixed pickers and trigger inline **Create**; open Tag sheet. |
| `4.7_installment_flow.mov` | 🎥 Installment sheet: select budgets, change Stepper + Start segment (grid recomputes), edit a cell so Remaining≠0 (Save disables, color changes), Split evenly (Save enables), Save. Capture keyboard avoidance editing a bottom cell. |
| `5.1_budgets_swipe.mov` | 🎥 Budgets: trailing swipe→**Remove** (record no-confirmation) + Edit; tap a card→filtered Transactions drilldown→back. |
| `5.2_budget_popover.mov` | 🎥 Budget card info **popover** (carry-over + note) — confirm it's a popover not a sheet, dismiss by tapping outside; then ⋮▸Remove→confirmation alert. |
| `6.6_scheduled_permission.mov` | 🎥 First appearance of Scheduled tab → **notification permission prompt** (cold, no pre-prompt — flagged §9); then tap Confirm + Dismiss on a pending row. |
| `8_taptargets.png` | 📷 With Accessibility Inspector if possible: the 28×28 ⋮ buttons (TransactionRow, BudgetCard), the `.controlSize(.small)` Scheduled buttons, MonthNavigator chevrons, CurrencyField +/− toggle — anything you can to show the hit areas vs 44pt. |

---

## P1 — Per-screen stills (Light / Dark / XXL each)

### Global / Auth / Dashboard
| Base filename (×light/dark/xxl) | Notes / extra states |
|---|---|
| `0.1_tabbar` | Watch label truncation at XXL. |
| `0.4_card_zoom` | Zoom on one Dashboard card: radius, hairline border, shadow. Light/dark only. |
| `1.1_login` | Also `1.1_login_se` on small device (card not clipped). |
| `2.1_dashboard` | Full scroll of all 4 cards. |
| `2.2_verdict_ontrack` / `2.2_verdict_overspent` | Both states (green ✓ / red △). |
| `2.3_accounts_card` | Include a **negative** balance row (check column alignment). |
| `2.4_planned` + `2.4_planned_empty` | Populated + empty (dashed box). |
| `2.5_unplanned` + `2.5_unplanned_empty` | Include a negative/refund category row. |

### Accounts
| Base | Notes |
|---|---|
| `3.1_accounts_list` + `3.1_accounts_empty` + `3.1_accounts_longname` | Populated, empty, long account name (truncation). |
| `3.2_account_detail` | With and without avatar: `_avatar` / `_noavatar`. |
| `3.3_account_form_add` / `3.3_account_form_edit` | Add + Edit modes; include the photo-section footer copy. |

### Transactions
| Base | Notes |
|---|---|
| `4.1_transactions` | Pending + confirmed rows visible (badges/chips). |
| `4.1_transactions_empty` + `4.1_transactions_emptyfiltered` | No-txns and empty-with-filters states. |
| `4.1_transactions_manytags` | A row with many tags (FlowLayout wrapping). |
| `4.2_row_income` / `_expense` / `_transfer` / `_pending` / `_spread` / `_refund` | Row variants (refund = `+` sign + color). Light/dark each is enough. |
| `4.3_txn_form_new` / `4.3_txn_form_edit` / `4.3_txn_form_error` | Titles, each type's field set, error state. |
| `4.4_filter_top` / `4.4_filter_facet_expanded` | Date+presets top; one expanded facet group. |
| `4.5_facet_mixed` / `4.5_facet_collapsed` | Expanded with mixed selection; collapsed summary. |
| `4.6_summary` | Totals + pending + one expanded breakdown. |
| `4.7_installment_grid` / `4.7_installment_balanced` / `4.7_installment_unbalanced` | Grid populated; Remaining banner balanced vs unbalanced. |

### Budgets
| Base | Notes |
|---|---|
| `5.1_budgets` + `5.1_budgets_empty` | Populated + empty (two actions). |
| `5.2_budget_normal` / `_overspent` / `_reserved` / `_carryover` | Card states. |
| `5.3_budget_form_add` / `5.3_budget_form_edit` | Multiline note grows. |
| `5.4_installment_card` | Span line + horizontally-scrolling chips. |

### More / Settings
| Base | Notes |
|---|---|
| `6.1_more` | Grouped list incl. destructive Sign Out. |
| `6.2_fixed_list` + `6.2_fixed_empty` | Unpaid + Paid sections; empty. |
| `6.3_fixed_row_paid` / `_unpaid` | Light/dark. |
| `6.4_fixed_form_add` / `6.5_fixed_form_edit` | Both. |
| `6.6_scheduled` + `6.6_scheduled_paused` + `6.6_scheduled_empty` | Pending+scheduled, paused (dimmed), empty. **XXL is the key risk** (3-button row) → make sure `6.6_scheduled_xxl` is captured. |
| `6.7_settings` | Segmented theme control + footnotes. |
| `6.8_currency_picker` | Searchable list + checkmark. |

### Shared components (menu/open states, Light+Dark)
| Base | Notes |
|---|---|
| `7.1_accountpicker_open` · `7.2_categorypicker_open` · `7.3_budgetpicker_open` · `7.4_fixedpicker_open` | Menu open; show the inline **Create** sentinel item. |
| `7.5_tagpicker_sheet` | Search + toggled chips. |
| `7.6_currencyfield` | Mid-type with thousands grouping; and the +/− toggle. |
| `7.7_monthnavigator` | Chevrons + label. |

---

## P2 — Full matrix (optional, second pass)
- VoiceOver swipe-through 🎥 of Dashboard, Transactions (swipe actions as a11y actions), one form → `6_voiceover_<screen>.mov`.
- Every screen on **iPhone SE** (`_se` suffix) and one **Landscape** of a long list + one form.
- Sheet swipe-dismiss-with-unsaved-edits 🎥 for every remaining form (Transaction, Budget, Fixed, Filter) → `8_dismiss_<form>.mov`.
- Pull-to-refresh 🎥 on each list that has it → `8_refresh_<screen>.mov`.
- AccountAvatar slow/broken image → `7.10_avatar_fallback.mov`.

---

## Quick checklist
- [ ] P0 videos (16 clips) recorded
- [ ] P1 stills, each in light + dark + xxl
- [ ] All files in one `captures/` folder, named exactly as above
- [ ] Hand the folder + the two audit docs to Claude using the prompts in `CLAUDE-PROMPTS.md`
