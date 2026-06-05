import type { TransactionFilters } from "@/lib/hooks/use-transactions";

// The URL query string is the single source of truth for the transaction list
// filters (no useState mirror, no cross-session persistence). These helpers
// convert between URLSearchParams and the TransactionFilters object. Amounts are
// kept in MINOR units throughout (URL + filters); only the input widget shows
// major units. Multi-selects are comma-joined ID lists.

const TYPES = ["income", "expense", "transfer"] as const;
const STATUSES = ["confirmed", "pending", "dismissed"] as const;

export function parseFilters(params: URLSearchParams): TransactionFilters {
  const f: TransactionFilters = {};

  const account = params.get("account");
  if (account) f.accountId = account;

  const type = params.get("type");
  if (type && (TYPES as readonly string[]).includes(type)) {
    f.type = type as TransactionFilters["type"];
  }

  const status = params.get("status");
  if (status && (STATUSES as readonly string[]).includes(status)) {
    f.status = status as TransactionFilters["status"];
  }

  const from = params.get("from");
  if (from) f.dateFrom = from;
  const to = params.get("to");
  if (to) f.dateTo = to;

  const search = params.get("search");
  if (search) f.search = search;

  const amtMin = params.get("amtMin");
  if (amtMin) {
    const n = Number(amtMin);
    if (Number.isFinite(n)) f.amountMin = n;
  }
  const amtMax = params.get("amtMax");
  if (amtMax) {
    const n = Number(amtMax);
    if (Number.isFinite(n)) f.amountMax = n;
  }

  const cat = params.get("cat");
  if (cat) f.categoryIds = cat.split(",").filter(Boolean);
  const tag = params.get("tag");
  if (tag) f.tagIds = tag.split(",").filter(Boolean);

  const budget = params.get("budget");
  if (budget) f.budgetName = budget;

  const fixed = params.get("fixed");
  if (fixed === "linked") f.fixedExpenseLinked = true;
  else if (fixed === "unlinked") f.fixedExpenseLinked = false;

  return f;
}

export function serializeFilters(f: TransactionFilters): Record<string, string> {
  const p: Record<string, string> = {};
  if (f.accountId) p.account = f.accountId;
  if (f.type) p.type = f.type;
  if (f.status) p.status = f.status;
  if (f.dateFrom) p.from = f.dateFrom;
  if (f.dateTo) p.to = f.dateTo;
  if (f.search) p.search = f.search;
  if (f.amountMin != null) p.amtMin = String(f.amountMin);
  if (f.amountMax != null) p.amtMax = String(f.amountMax);
  if (f.categoryIds?.length) p.cat = f.categoryIds.join(",");
  if (f.tagIds?.length) p.tag = f.tagIds.join(",");
  if (f.budgetName) p.budget = f.budgetName;
  if (f.fixedExpenseLinked === true) p.fixed = "linked";
  else if (f.fixedExpenseLinked === false) p.fixed = "unlinked";
  return p;
}

/**
 * Count of active filters EXCLUDING search (which has its own always-visible
 * input). Drives the badge on the "Filters" button.
 */
export function countPanelFilters(f: TransactionFilters): number {
  let n = 0;
  if (f.accountId) n++;
  if (f.type) n++;
  if (f.status) n++;
  if (f.dateFrom || f.dateTo) n++;
  if (f.amountMin != null || f.amountMax != null) n++;
  if (f.categoryIds?.length) n++;
  if (f.tagIds?.length) n++;
  if (f.budgetName) n++;
  if (f.fixedExpenseLinked != null) n++;
  return n;
}
