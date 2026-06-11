import type { TransactionFilters } from "@/lib/hooks/use-transactions";

// The URL query string is the single source of truth for the transaction list
// filters (no useState mirror, no cross-session persistence). These helpers
// convert between URLSearchParams and the TransactionFilters object. Amounts are
// kept in MINOR units throughout (URL + filters); only the input widget shows
// major units.
//
// Multi-select facets are comma-joined value lists and are tri-state: an absent
// param means "no filter" (all), a present param lists the selected values, and
// a present-but-empty param ("key=") means "none selected" (matches nothing).

const TYPES = ["income", "expense", "transfer"] as const;
const STATUSES = ["confirmed", "pending", "dismissed"] as const;

// Read a tri-state array facet: undefined when the param is absent, otherwise the
// comma-split values (an empty string yields []).
function parseArray(params: URLSearchParams, key: string): string[] | undefined {
  if (!params.has(key)) return undefined;
  return params.get(key)!.split(",").filter(Boolean);
}

export function parseFilters(params: URLSearchParams): TransactionFilters {
  const f: TransactionFilters = {};

  const account = parseArray(params, "account");
  if (account) f.accountIds = account;

  const type = parseArray(params, "type");
  if (type)
    f.types = type.filter((t) =>
      (TYPES as readonly string[]).includes(t),
    ) as TransactionFilters["types"];

  const status = parseArray(params, "status");
  if (status)
    f.statuses = status.filter((s) =>
      (STATUSES as readonly string[]).includes(s),
    ) as TransactionFilters["statuses"];

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

  const cat = parseArray(params, "cat");
  if (cat) f.categoryIds = cat;
  const tag = parseArray(params, "tag");
  if (tag) f.tagIds = tag;
  const budget = parseArray(params, "budget");
  if (budget) f.budgetNames = budget;
  const fixed = parseArray(params, "fixed");
  if (fixed) f.fixedExpenseNames = fixed;

  return f;
}

export function serializeFilters(f: TransactionFilters): Record<string, string> {
  const p: Record<string, string> = {};
  // Array facets are truthy whether empty or not, so present-empty ("none")
  // round-trips as "key="; only absent (undefined) is omitted.
  if (f.accountIds) p.account = f.accountIds.join(",");
  if (f.types) p.type = f.types.join(",");
  if (f.statuses) p.status = f.statuses.join(",");
  if (f.dateFrom) p.from = f.dateFrom;
  if (f.dateTo) p.to = f.dateTo;
  if (f.search) p.search = f.search;
  if (f.amountMin != null) p.amtMin = String(f.amountMin);
  if (f.amountMax != null) p.amtMax = String(f.amountMax);
  if (f.categoryIds) p.cat = f.categoryIds.join(",");
  if (f.tagIds) p.tag = f.tagIds.join(",");
  if (f.budgetNames) p.budget = f.budgetNames.join(",");
  if (f.fixedExpenseNames) p.fixed = f.fixedExpenseNames.join(",");
  return p;
}

/**
 * Count of active filters EXCLUDING search (which has its own always-visible
 * input). Drives the badge on the "Filters" button. A facet counts as active
 * whenever it is present (a narrowed subset or "none"), not when it is absent.
 */
export function countPanelFilters(f: TransactionFilters): number {
  let n = 0;
  if (f.accountIds) n++;
  if (f.types) n++;
  if (f.statuses) n++;
  if (f.dateFrom || f.dateTo) n++;
  if (f.amountMin != null || f.amountMax != null) n++;
  if (f.categoryIds) n++;
  if (f.tagIds) n++;
  if (f.budgetNames) n++;
  if (f.fixedExpenseNames) n++;
  return n;
}
