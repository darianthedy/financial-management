import { useEffect, useState, useCallback } from "react";
import { supabase } from "@/lib/supabase/client";
import type { Transaction, Category, Tag } from "@/lib/types/database";
import type { TransactionFormValues } from "@/lib/validations/transaction";
import { toMinorUnits } from "@/lib/utils/currency";

export type TransactionWithRelations = Transaction & {
  accounts: { name: string; image_url: string | null } | null;
  transfer_accounts: { name: string } | null;
  category: Category | null;
  tags: Tag[];
  budget: { name: string } | null;
  fixedExpense: { name: string } | null;
  /** True when this expense is the source of a virtual budget installment. */
  hasInstallment: boolean;
};

export type TransactionType = "income" | "expense" | "transfer";
export type TransactionStatus = "confirmed" | "pending" | "dismissed";

/**
 * Sentinel value standing in for "no value" (an unset link / "(Blanks)") inside
 * the category, tag, budget, and fixed-expense facets. It can appear in those
 * filter arrays alongside real ids/names and matches rows where the column is
 * NULL (or, for tags, rows with no tag links).
 */
export const NO_VALUE = "__none__";

/**
 * Each multi-select facet (accounts, types, statuses, categories, tags, budgets,
 * fixed expenses) is tri-state:
 *   - undefined  → no filter (every value allowed; the default "All …" state)
 *   - non-empty  → match ANY of the listed values (OR within the facet)
 *   - empty []   → match NOTHING (the user unchecked every option)
 * The category/tag/budget/fixed arrays may include {@link NO_VALUE} to also match
 * rows with no value for that facet.
 */
export interface TransactionFilters {
  /** Accounts (matches account OR transfer side). */
  accountIds?: string[];
  types?: TransactionType[];
  statuses?: TransactionStatus[];
  dateFrom?: string;
  dateTo?: string;
  /** Free-text match on description (case-insensitive). */
  search?: string;
  /** Inclusive amount bounds in MINOR units (e.g. cents). */
  amountMin?: number;
  amountMax?: number;
  /** Category IDs; may include {@link NO_VALUE} for uncategorized rows. */
  categoryIds?: string[];
  /** Tag IDs; may include {@link NO_VALUE} for untagged rows. */
  tagIds?: string[];
  /**
   * Budget names (budget identity is name + year_month; this matches by name
   * only, across every period). May include {@link NO_VALUE} for rows with no
   * budget. When a date range is also set, only budget rows whose month falls
   * within that range count.
   */
  budgetNames?: string[];
  /**
   * Fixed-expense names (matched by name across every month). May include
   * {@link NO_VALUE} for rows with no fixed expense. When a date range is also
   * set, only fixed-expense rows whose month falls within that range count.
   */
  fixedExpenseNames?: string[];
}

/**
 * Resolve budget NAMES to the set of budget row IDs to match against
 * transactions.budget_id. Reads `v_budget_progress` (the same source the rest of
 * the app surfaces budgets from), so the ids line up with what budgets a
 * transaction can actually be linked to. Budgets are month-specific rows, so one
 * name spans many rows; an optional [fromYM, toYM] month range (derived from the
 * date filter) narrows it to those periods. year_month is 'YYYY-MM', so lexical
 * gte/lte works.
 */
async function resolveBudgetIds(
  names: string[],
  fromYM?: string,
  toYM?: string,
): Promise<string[]> {
  let q = supabase
    .from("v_budget_progress")
    .select("budget_id")
    .in("budget_name", names);
  if (fromYM) q = q.gte("year_month", fromYM);
  if (toYM) q = q.lte("year_month", toYM);
  const { data } = await q;
  return (data ?? []).map((r) => r.budget_id);
}

/**
 * Resolve fixed-expense NAMES to the set of fixed_expenses row IDs to match
 * against transactions.fixed_expense_id. Fixed expenses are month-specific rows,
 * so one name spans many rows; an optional [fromYM, toYM] month range (derived
 * from the date filter) narrows it to those periods. year_month is 'YYYY-MM', so
 * lexical gte/lte works.
 */
async function resolveFixedExpenseIds(
  names: string[],
  fromYM?: string,
  toYM?: string,
): Promise<string[]> {
  let q = supabase.from("fixed_expenses").select("id").in("name", names);
  if (fromYM) q = q.gte("year_month", fromYM);
  if (toYM) q = q.lte("year_month", toYM);
  const { data } = await q;
  return (data ?? []).map((r) => r.id);
}

/**
 * Resolve the facets that need an async lookup or compound clause into the
 * shape `applyFilters` consumes, so the list query and the summary query share
 * identical constraints. Budget/fixed are matched by NAME across many
 * month-specific rows, so their names resolve to ID lists first. `empty` means
 * some facet can match nothing (a present-but-empty facet, or chosen
 * budget/fixed names that resolved to no rows) — callers short-circuit.
 */
interface ResolvedRestrictions {
  empty: boolean;
  /** PostgREST .or() clause for the budget facet (ids and/or "(Blanks)"). */
  budgetOr?: string;
  /** PostgREST .or() clause for the fixed-expense facet. */
  fixedOr?: string;
}

async function resolveRestrictions(
  filters: TransactionFilters,
): Promise<ResolvedRestrictions> {
  // A present-but-empty facet means the user unchecked every option, so nothing
  // can match. (An absent facet is the default "all" state and adds no filter.)
  const noneSelected = [
    filters.accountIds,
    filters.types,
    filters.statuses,
    filters.categoryIds,
    filters.tagIds,
    filters.budgetNames,
    filters.fixedExpenseNames,
  ].some((f) => f != null && f.length === 0);
  if (noneSelected) return { empty: true };

  const r: ResolvedRestrictions = { empty: false };

  if (filters.budgetNames?.length) {
    const names = filters.budgetNames.filter((v) => v !== NO_VALUE);
    const parts: string[] = [];
    if (names.length) {
      const ids = await resolveBudgetIds(
        names,
        filters.dateFrom?.slice(0, 7),
        filters.dateTo?.slice(0, 7),
      );
      if (ids.length) parts.push(`budget_id.in.(${ids.join(",")})`);
    }
    if (filters.budgetNames.includes(NO_VALUE)) parts.push("budget_id.is.null");
    // Named budgets chosen but none resolved (and "(Blanks)" wasn't): nothing matches.
    if (parts.length === 0) return { empty: true };
    r.budgetOr = parts.join(",");
  }

  if (filters.fixedExpenseNames?.length) {
    const names = filters.fixedExpenseNames.filter((v) => v !== NO_VALUE);
    const parts: string[] = [];
    if (names.length) {
      const ids = await resolveFixedExpenseIds(
        names,
        filters.dateFrom?.slice(0, 7),
        filters.dateTo?.slice(0, 7),
      );
      if (ids.length) parts.push(`fixed_expense_id.in.(${ids.join(",")})`);
    }
    if (filters.fixedExpenseNames.includes(NO_VALUE))
      parts.push("fixed_expense_id.is.null");
    if (parts.length === 0) return { empty: true };
    r.fixedOr = parts.join(",");
  }

  return r;
}

/**
 * Structural shape of the PostgREST query builder: just the filter methods this
 * module chains. Each returns the same builder (`this`), so a generic `T` lets
 * `applyFilters` work for both the `select("*")` list query and the lightweight
 * summary query while preserving their row types.
 */
interface FilterableQuery<T> {
  or(filters: string): T;
  in(column: string, values: readonly string[]): T;
  gte(column: string, value: string | number): T;
  lte(column: string, value: string | number): T;
  ilike(column: string, pattern: string): T;
}

/**
 * Apply every active filter to a `v_transactions` query. Shared by the paginated
 * list query and the whole-set summary query so their counts and totals can't
 * drift. Tags are filtered here in SQL via the view's `tag_ids` array (overlaps
 * for chosen tags, `= '{}'` for "(Blanks)/untagged"); category and the resolved
 * budget/fixed clauses likewise honour their "(Blanks)" option.
 */
function applyFilters<T extends FilterableQuery<T>>(
  query: T,
  filters: TransactionFilters,
  restrictions: ResolvedRestrictions,
): T {
  let q = query;
  if (filters.accountIds?.length) {
    const ors = filters.accountIds
      .flatMap((id) => [`account_id.eq.${id}`, `transfer_account_id.eq.${id}`])
      .join(",");
    q = q.or(ors);
  }
  if (filters.types?.length) q = q.in("type", filters.types);
  if (filters.statuses?.length) q = q.in("status", filters.statuses);
  if (filters.dateFrom) q = q.gte("date", filters.dateFrom);
  if (filters.dateTo) q = q.lte("date", filters.dateTo);
  if (filters.search) q = q.ilike("description", `%${filters.search}%`);
  if (filters.amountMin != null) q = q.gte("amount", filters.amountMin);
  if (filters.amountMax != null) q = q.lte("amount", filters.amountMax);
  if (filters.categoryIds?.length) {
    const ids = filters.categoryIds.filter((v) => v !== NO_VALUE);
    const parts: string[] = [];
    if (ids.length) parts.push(`category_id.in.(${ids.join(",")})`);
    if (filters.categoryIds.includes(NO_VALUE)) parts.push("category_id.is.null");
    q = q.or(parts.join(","));
  }
  if (restrictions.budgetOr) q = q.or(restrictions.budgetOr);
  if (restrictions.fixedOr) q = q.or(restrictions.fixedOr);
  if (filters.tagIds?.length) {
    const ids = filters.tagIds.filter((v) => v !== NO_VALUE);
    const parts: string[] = [];
    if (ids.length) parts.push(`tag_ids.ov.{${ids.join(",")}}`);
    if (filters.tagIds.includes(NO_VALUE)) parts.push("tag_ids.eq.{}");
    q = q.or(parts.join(","));
  }
  return q;
}

/**
 * One row of the whole filtered set, carrying the money columns plus the
 * resolved names the Summary groups by (budget / category / fixed expense /
 * tags). Budgets and fixed expenses are month-specific rows sharing a name, so
 * we surface the NAME — that's their identity for the breakdown, matching how
 * the filters treat them. `tagNames` is the (possibly empty) set of tags on the
 * row; a transaction contributes to every one of its tags' stats. For transfers,
 * `accountName` is the source (money out) and `transferAccountName` the
 * destination (money in); for income/expense only `accountName` is set.
 */
export interface TransactionSummaryRow {
  type: Transaction["type"];
  amount: Transaction["amount"];
  status: Transaction["status"];
  accountName: string | null;
  transferAccountName: string | null;
  budgetName: string | null;
  categoryName: string | null;
  fixedExpenseName: string | null;
  tagNames: string[];
}

/** Raw shape pulled from `v_transactions` before names are hydrated. */
type SummaryFetchRow = Pick<
  Transaction,
  | "type"
  | "amount"
  | "status"
  | "account_id"
  | "transfer_account_id"
  | "budget_id"
  | "category_id"
  | "fixed_expense_id"
> & { tag_ids: string[] };

/**
 * Fetch the whole filtered set (every page) reduced to the columns the Summary
 * needs, then hydrate the budget / category / fixed-expense / tag names it
 * breaks down by. Kept separate from the list query so the summary spans all
 * pages and is computed on demand (when the dialog opens), not on every page
 * load. Reuses `applyFilters`, so it honours exactly the same filters.
 */
export async function fetchTransactionSummaryRows(
  filters: TransactionFilters = {},
): Promise<TransactionSummaryRow[]> {
  const restrictions = await resolveRestrictions(filters);
  if (restrictions.empty) return [];
  const q = applyFilters(
    supabase
      .from("v_transactions")
      .select(
        "type, amount, status, account_id, transfer_account_id, budget_id, category_id, fixed_expense_id, tag_ids",
      ),
    filters,
    restrictions,
  );
  const { data } = await q;
  const rows = (data ?? []) as SummaryFetchRow[];

  const accountIds = [
    ...new Set([
      ...rows.map((r) => r.account_id),
      ...rows.map((r) => r.transfer_account_id),
    ].filter(Boolean)),
  ] as string[];
  const budgetIds = [
    ...new Set(rows.map((r) => r.budget_id).filter(Boolean)),
  ] as string[];
  const catIds = [
    ...new Set(rows.map((r) => r.category_id).filter(Boolean)),
  ] as string[];
  const fixedIds = [
    ...new Set(rows.map((r) => r.fixed_expense_id).filter(Boolean)),
  ] as string[];
  const tagIds = [...new Set(rows.flatMap((r) => r.tag_ids))];

  const [accountResult, budgetResult, categoryResult, fixedResult, tagResult] =
    await Promise.all([
      accountIds.length
        ? supabase.from("accounts").select("id, name").in("id", accountIds)
        : Promise.resolve({ data: [] as Array<{ id: string; name: string }> }),
      budgetIds.length
        ? supabase.from("budgets").select("id, name").in("id", budgetIds)
        : Promise.resolve({ data: [] as Array<{ id: string; name: string }> }),
      catIds.length
        ? supabase.from("categories").select("id, name").in("id", catIds)
        : Promise.resolve({ data: [] as Array<{ id: string; name: string }> }),
      fixedIds.length
        ? supabase.from("fixed_expenses").select("id, name").in("id", fixedIds)
        : Promise.resolve({ data: [] as Array<{ id: string; name: string }> }),
      tagIds.length
        ? supabase.from("tags").select("id, name").in("id", tagIds)
        : Promise.resolve({ data: [] as Array<{ id: string; name: string }> }),
    ]);

  const accountNameById = new Map(
    (accountResult.data ?? []).map((a) => [a.id, a.name]),
  );
  const budgetNameById = new Map(
    (budgetResult.data ?? []).map((b) => [b.id, b.name]),
  );
  const categoryNameById = new Map(
    (categoryResult.data ?? []).map((c) => [c.id, c.name]),
  );
  const fixedNameById = new Map(
    (fixedResult.data ?? []).map((f) => [f.id, f.name]),
  );
  const tagNameById = new Map(
    (tagResult.data ?? []).map((t) => [t.id, t.name]),
  );

  return rows.map((r) => ({
    type: r.type,
    amount: r.amount,
    status: r.status,
    accountName: r.account_id ? accountNameById.get(r.account_id) ?? null : null,
    transferAccountName: r.transfer_account_id
      ? accountNameById.get(r.transfer_account_id) ?? null
      : null,
    budgetName: r.budget_id ? budgetNameById.get(r.budget_id) ?? null : null,
    categoryName: r.category_id
      ? categoryNameById.get(r.category_id) ?? null
      : null,
    fixedExpenseName: r.fixed_expense_id
      ? fixedNameById.get(r.fixed_expense_id) ?? null
      : null,
    tagNames: r.tag_ids
      .map((id) => tagNameById.get(id))
      .filter((n): n is string => n != null),
  }));
}

export interface UseTransactionsOptions {
  /**
   * Zero-based page index. When provided the list query is windowed with
   * `.range()` and `total` reports the full matching count. When omitted every
   * matching row is fetched (e.g. the scheduled page) and `total` is their count.
   */
  page?: number;
  pageSize?: number;
}

const DEFAULT_PAGE_SIZE = 50;

export function useTransactions(
  filters: TransactionFilters = {},
  options: UseTransactionsOptions = {},
) {
  const { page, pageSize = DEFAULT_PAGE_SIZE } = options;
  const paginated = page != null;

  const [transactions, setTransactions] = useState<TransactionWithRelations[]>([]);
  // Full count of rows matching the filters (not just the loaded page).
  const [total, setTotal] = useState(0);
  const [loading, setLoading] = useState(true);

  // Arrays change identity each render; depend on a stable serialization so the
  // memoized fetch only changes when the selected ids actually change.
  const categoryKey = filters.categoryIds?.join(",");
  const tagKey = filters.tagIds?.join(",");
  const typeKey = filters.types?.join(",");
  const statusKey = filters.statuses?.join(",");
  const accountIdsKey = filters.accountIds?.join(",");
  const budgetNamesKey = filters.budgetNames?.join(",");
  const fixedExpenseNamesKey = filters.fixedExpenseNames?.join(",");

  const fetch = useCallback(async () => {
    setLoading(true);

    const restrictions = await resolveRestrictions(filters);
    if (restrictions.empty) {
      setTransactions([]);
      setTotal(0);
      setLoading(false);
      return;
    }

    // Read from v_transactions so the tag facet (incl. "(Blanks)/untagged") can
    // be filtered in SQL via its tag_ids array — that keeps the whole query
    // server-side and lets .range()+count paginate accurately. Account/budget/
    // /category/fixed names are still hydrated separately below. id is the
    // tiebreaker so the order is total and stable across pages.
    let q = (
      paginated
        ? supabase.from("v_transactions").select("*", { count: "exact" })
        : supabase.from("v_transactions").select("*")
    )
      .order("date", { ascending: false })
      .order("created_at", { ascending: false })
      .order("id", { ascending: false });
    q = applyFilters(q, filters, restrictions);
    if (paginated) {
      q = q.range(page * pageSize, page * pageSize + pageSize - 1);
    }

    const { data: txnRows, count } = await q;
    const rows: Transaction[] = txnRows ?? [];
    setTotal(paginated ? count ?? rows.length : rows.length);

    const ids = rows.map((r) => r.id);

    // Collect all account IDs that appear in these transactions.
    const accountIds = [
      ...new Set([
        ...rows.map((r) => r.account_id),
        ...rows.map((r) => r.transfer_account_id).filter(Boolean),
      ]),
    ] as string[];

    // Budgets linked to these transactions (for the row title).
    const budgetIds = [
      ...new Set(rows.map((r) => r.budget_id).filter(Boolean)),
    ] as string[];

    // Single category per transaction (column, not junction).
    const catIds = [
      ...new Set(rows.map((r) => r.category_id).filter(Boolean)),
    ] as string[];

    // Fixed expenses linked to these transactions (for the row's "Fixed" chip).
    const fixedExpenseIds = [
      ...new Set(rows.map((r) => r.fixed_expense_id).filter(Boolean)),
    ] as string[];

    // Fetch account names, budget names, categories, fixed-expense names, tag
    // rows, and which of these expenses are spread into a virtual installment,
    // all in parallel.
    const [accountResult, budgetResult, categoryResult, fixedExpenseResult, tagResult, installmentResult] = await Promise.all([
      accountIds.length
        ? supabase.from("accounts").select("id, name, image_url").in("id", accountIds)
        : Promise.resolve({
            data: [] as Array<{ id: string; name: string; image_url: string | null }>,
          }),
      budgetIds.length
        ? supabase.from("budgets").select("id, name").in("id", budgetIds)
        : Promise.resolve({ data: [] as Array<{ id: string; name: string }> }),
      catIds.length
        ? supabase.from("categories").select("*").in("id", catIds)
        : Promise.resolve({ data: [] as Category[] }),
      fixedExpenseIds.length
        ? supabase.from("fixed_expenses").select("id, name").in("id", fixedExpenseIds)
        : Promise.resolve({ data: [] as Array<{ id: string; name: string }> }),
      ids.length
        ? (supabase
            .from("transaction_tags")
            .select("transaction_id, tags(*)")
            .in("transaction_id", ids) as unknown as Promise<{
            data: Array<{ transaction_id: string; tags: Tag | null }> | null;
          }>)
        : Promise.resolve({ data: [] as Array<{ transaction_id: string; tags: Tag | null }> }),
      ids.length
        ? supabase
            .from("budget_installments")
            .select("source_transaction_id")
            .in("source_transaction_id", ids)
        : Promise.resolve({ data: [] as Array<{ source_transaction_id: string }> }),
    ]);

    const accountById = new Map(
      (accountResult.data ?? []).map((a) => [a.id, a]),
    );
    const budgetNameById = new Map(
      (budgetResult.data ?? []).map((b) => [b.id, b.name]),
    );
    const categoryById = new Map(
      (categoryResult.data ?? []).map((c) => [c.id, c]),
    );
    const fixedExpenseNameById = new Map(
      (fixedExpenseResult.data ?? []).map((f) => [f.id, f.name]),
    );

    const tagsByTxn = new Map<string, Tag[]>();
    for (const link of tagResult.data ?? []) {
      const tags = tagsByTxn.get(link.transaction_id) ?? [];
      if (link.tags) tags.push(link.tags);
      tagsByTxn.set(link.transaction_id, tags);
    }

    // Source transactions that have been spread into a virtual installment, so
    // the row can flag them without a per-row lookup.
    const installmentSourceIds = new Set(
      (installmentResult.data ?? []).map((r) => r.source_transaction_id),
    );

    // Tags are filtered in SQL (via the view's tag_ids array), so the fetched
    // rows are already the final set — just hydrate names for display.
    const mapped = rows.map((r) => ({
      ...r,
      accounts: r.account_id
        ? {
            name: accountById.get(r.account_id)?.name ?? "",
            image_url: accountById.get(r.account_id)?.image_url ?? null,
          }
        : null,
      transfer_accounts: r.transfer_account_id
        ? { name: accountById.get(r.transfer_account_id)?.name ?? "" }
        : null,
      category: r.category_id ? categoryById.get(r.category_id) ?? null : null,
      tags: tagsByTxn.get(r.id) ?? [],
      budget: r.budget_id ? { name: budgetNameById.get(r.budget_id) ?? "" } : null,
      fixedExpense: r.fixed_expense_id
        ? { name: fixedExpenseNameById.get(r.fixed_expense_id) ?? "" }
        : null,
      hasInstallment: installmentSourceIds.has(r.id),
    }));
    setTransactions(mapped);
    setLoading(false);
    // categoryKey/tagKey stand in for the categoryIds/tagIds arrays (stable
    // identity); listing the arrays themselves would refetch every render.
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [
    accountIdsKey,
    typeKey,
    statusKey,
    filters.dateFrom,
    filters.dateTo,
    filters.search,
    filters.amountMin,
    filters.amountMax,
    budgetNamesKey,
    fixedExpenseNamesKey,
    categoryKey,
    tagKey,
    paginated,
    page,
    pageSize,
  ]);

  useEffect(() => {
    fetch();
    const channel = supabase
      .channel("transactions-changes")
      .on("postgres_changes", { event: "*", schema: "public", table: "transactions" }, () => fetch())
      .subscribe();
    return () => { supabase.removeChannel(channel); };
  }, [fetch]);

  return { transactions, total, loading, refetch: fetch };
}

async function currentUserId(): Promise<string> {
  const { data: { user } } = await supabase.auth.getUser();
  if (!user) throw new Error("Not authenticated");
  return user.id;
}

async function writeTagRows(txnId: string, tagIds: string[]) {
  if (!tagIds.length) return;
  const { error } = await supabase
    .from("transaction_tags")
    .insert(tagIds.map((id) => ({ transaction_id: txnId, tag_id: id })));
  if (error) throw error;
}

export async function createTransaction(values: TransactionFormValues, decimalPlaces = 2) {
  const user_id = await currentUserId();
  const { data, error } = await supabase
    .from("transactions")
    .insert({
      user_id,
      account_id: values.account_id,
      transfer_account_id: values.type === "transfer" ? (values.transfer_account_id ?? null) : null,
      type: values.type,
      amount: toMinorUnits(values.amount, decimalPlaces),
      description: values.description ?? null,
      date: values.date,
      budget_id: values.type === "transfer" ? null : (values.budget_id ?? null),
      category_id: values.type === "transfer" ? null : (values.category_id ?? null),
      fixed_expense_id:
        values.type === "expense" ? (values.fixed_expense_id ?? null) : null,
    })
    .select("id")
    .single();
  if (error) throw error;
  await writeTagRows(data.id, values.tag_ids ?? []);
}

export async function updateTransaction(id: string, values: TransactionFormValues, decimalPlaces = 2) {
  const { error } = await supabase.from("transactions").update({
    account_id: values.account_id,
    transfer_account_id: values.type === "transfer" ? (values.transfer_account_id ?? null) : null,
    type: values.type,
    amount: toMinorUnits(values.amount, decimalPlaces),
    description: values.description ?? null,
    date: values.date,
    budget_id: values.type === "transfer" ? null : (values.budget_id ?? null),
    category_id: values.type === "transfer" ? null : (values.category_id ?? null),
    fixed_expense_id:
      values.type === "expense" ? (values.fixed_expense_id ?? null) : null,
  }).eq("id", id);
  if (error) throw error;
  await supabase.from("transaction_tags").delete().eq("transaction_id", id);
  await writeTagRows(id, values.tag_ids ?? []);
}

export async function deleteTransaction(id: string) {
  const { error } = await supabase.from("transactions").delete().eq("id", id);
  if (error) throw error;
}

export async function confirmTransaction(id: string) {
  const { error } = await supabase.from("transactions").update({ status: "confirmed" }).eq("id", id);
  if (error) throw error;
}

export async function dismissTransaction(id: string) {
  const { error } = await supabase.from("transactions").update({ status: "dismissed" }).eq("id", id);
  if (error) throw error;
}

export async function fetchCategories(): Promise<Category[]> {
  const { data: { user } } = await supabase.auth.getUser();
  if (!user) return [];
  const { data } = await supabase.from("categories").select("*").eq("user_id", user.id).order("name");
  return data ?? [];
}

export async function fetchTags(): Promise<Tag[]> {
  const { data: { user } } = await supabase.auth.getUser();
  if (!user) return [];
  const { data } = await supabase.from("tags").select("*").eq("user_id", user.id).order("name");
  return data ?? [];
}

export async function createTag(name: string): Promise<Tag> {
  const { data: { user } } = await supabase.auth.getUser();
  if (!user) throw new Error("Not authenticated");
  const { data, error } = await supabase.from("tags").insert({ user_id: user.id, name }).select().single();
  if (error) throw error;
  return data;
}

// Mirrors the donut palette in spending-by-category so newly created
// categories get a stable, distinguishable color in the dashboard chart.
// Exported for the category-management color-swatch picker.
export const CATEGORY_COLORS = [
  "#6366f1", "#f59e0b", "#10b981", "#ef4444",
  "#3b82f6", "#8b5cf6", "#ec4899", "#14b8a6",
];

function colorForName(name: string): string {
  let hash = 0;
  for (let i = 0; i < name.length; i++) {
    hash = (hash * 31 + name.charCodeAt(i)) >>> 0;
  }
  return CATEGORY_COLORS[hash % CATEGORY_COLORS.length];
}

export async function createCategory(
  name: string,
  color?: string | null,
  icon?: string | null,
): Promise<Category> {
  const { data: { user } } = await supabase.auth.getUser();
  if (!user) throw new Error("Not authenticated");
  const { data, error } = await supabase
    .from("categories")
    .insert({
      user_id: user.id,
      name,
      color: color ?? colorForName(name),
      icon: icon ?? null,
    })
    .select()
    .single();
  if (error) throw error;
  return data;
}
