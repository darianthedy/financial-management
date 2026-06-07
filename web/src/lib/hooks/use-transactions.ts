import { useEffect, useState, useCallback } from "react";
import { supabase } from "@/lib/supabase/client";
import type { Transaction, Category, Tag } from "@/lib/types/database";
import type { TransactionFormValues } from "@/lib/validations/transaction";
import { toMinorUnits } from "@/lib/utils/currency";

export type TransactionWithRelations = Transaction & {
  accounts: { name: string } | null;
  transfer_accounts: { name: string } | null;
  category: Category | null;
  tags: Tag[];
  budget: { name: string } | null;
};

export type TransactionType = "income" | "expense" | "transfer";
export type TransactionStatus = "confirmed" | "pending" | "dismissed";

export interface TransactionFilters {
  /** Single account, used by the account-detail page (not the filter panel). */
  accountId?: string;
  /** Multi-select accounts from the filter panel (matches account OR transfer). */
  accountIds?: string[];
  /** Match ANY of these transaction types. */
  types?: TransactionType[];
  /** Match ANY of these statuses. */
  statuses?: TransactionStatus[];
  dateFrom?: string;
  dateTo?: string;
  /** Free-text match on description (case-insensitive). */
  search?: string;
  /** Inclusive amount bounds in MINOR units (e.g. cents). */
  amountMin?: number;
  amountMax?: number;
  /** Match transactions carrying ANY of these category IDs (OR within). */
  categoryIds?: string[];
  /** Match transactions carrying ANY of these tag IDs (OR within). */
  tagIds?: string[];
  /**
   * Match transactions linked to a budget with this name, across every period
   * (budget identity is name + year_month; this matches by name only). When a date
   * range is also set, only budget rows whose month falls within that range count.
   */
  budgetName?: string;
  /** true = linked to a fixed expense (paid); false = not linked (unpaid). */
  fixedExpenseLinked?: boolean;
}

/**
 * Resolve a budget NAME to the set of budget row IDs to match against
 * transactions.budget_id. Reads `v_budget_progress` (the same source the rest of
 * the app surfaces budgets from), so the ids line up with what budgets a
 * transaction can actually be linked to. Budgets are month-specific rows, so one
 * name spans many rows; an optional [fromYM, toYM] month range (derived from the
 * date filter) narrows it to those periods. year_month is 'YYYY-MM', so lexical
 * gte/lte works.
 */
async function resolveBudgetIds(
  name: string,
  fromYM?: string,
  toYM?: string,
): Promise<string[]> {
  let q = supabase
    .from("v_budget_progress")
    .select("budget_id")
    .eq("budget_name", name);
  if (fromYM) q = q.gte("year_month", fromYM);
  if (toYM) q = q.lte("year_month", toYM);
  const { data } = await q;
  return (data ?? []).map((r) => r.budget_id);
}

/**
 * The tag filter lives in a junction table (there is no tag_id column on
 * transactions). Collect the matching transaction IDs — OR within the selected
 * tags — so the caller can constrain the main query with `.in("id", ids)`.
 * Returns null when no tag is filtered (no restriction). Categories are NOT
 * here: category is a column on transactions and filters directly. See System
 * Design §4.9.
 */
async function resolveTagTxnIds(tagIds?: string[]): Promise<string[] | null> {
  if (!tagIds?.length) return null;
  const { data } = await supabase
    .from("transaction_tags")
    .select("transaction_id")
    .in("tag_id", tagIds);
  return [...new Set((data ?? []).map((r) => r.transaction_id))];
}

export function useTransactions(filters: TransactionFilters = {}) {
  const [transactions, setTransactions] = useState<TransactionWithRelations[]>([]);
  const [loading, setLoading] = useState(true);

  // Arrays change identity each render; depend on a stable serialization so the
  // memoized fetch only changes when the selected ids actually change.
  const categoryKey = filters.categoryIds?.join(",");
  const tagKey = filters.tagIds?.join(",");
  const typeKey = filters.types?.join(",");
  const statusKey = filters.statuses?.join(",");
  const accountIdsKey = filters.accountIds?.join(",");

  const fetch = useCallback(async () => {
    setLoading(true);

    // Use plain select("*") to avoid FK-hint syntax that requires Relationships typed.
    // Account names are fetched separately via a lookup map.
    let q = supabase
      .from("transactions")
      .select("*")
      .order("date", { ascending: false })
      .order("created_at", { ascending: false });

    if (filters.accountId) {
      q = q.or(`account_id.eq.${filters.accountId},transfer_account_id.eq.${filters.accountId}`);
    }
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
    // Category is single-select on the row: a transaction matches if its one
    // category is any of the selected (OR-within).
    if (filters.categoryIds?.length) q = q.in("category_id", filters.categoryIds);
    if (filters.budgetName) {
      const budgetIds = await resolveBudgetIds(
        filters.budgetName,
        filters.dateFrom?.slice(0, 7),
        filters.dateTo?.slice(0, 7),
      );
      if (budgetIds.length === 0) {
        setTransactions([]);
        setLoading(false);
        return;
      }
      q = q.in("budget_id", budgetIds);
    }
    if (filters.fixedExpenseLinked === true) {
      q = q.not("fixed_expense_id", "is", null);
    } else if (filters.fixedExpenseLinked === false) {
      q = q.is("fixed_expense_id", null);
    }

    // The tag filter is resolved via the junction table, then applied as an id
    // restriction on the main query. An empty result short-circuits.
    const restrictIds = await resolveTagTxnIds(filters.tagIds);
    if (restrictIds !== null) {
      if (restrictIds.length === 0) {
        setTransactions([]);
        setLoading(false);
        return;
      }
      q = q.in("id", restrictIds);
    }

    const { data: txnRows } = await q;
    const rows: Transaction[] = txnRows ?? [];

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

    // Fetch account names, budget names, categories, and tag rows in parallel.
    const [accountResult, budgetResult, categoryResult, tagResult] = await Promise.all([
      accountIds.length
        ? supabase.from("accounts").select("id, name").in("id", accountIds)
        : Promise.resolve({ data: [] as Array<{ id: string; name: string }> }),
      budgetIds.length
        ? supabase.from("budgets").select("id, name").in("id", budgetIds)
        : Promise.resolve({ data: [] as Array<{ id: string; name: string }> }),
      catIds.length
        ? supabase.from("categories").select("*").in("id", catIds)
        : Promise.resolve({ data: [] as Category[] }),
      ids.length
        ? (supabase
            .from("transaction_tags")
            .select("transaction_id, tags(*)")
            .in("transaction_id", ids) as unknown as Promise<{
            data: Array<{ transaction_id: string; tags: Tag | null }> | null;
          }>)
        : Promise.resolve({ data: [] as Array<{ transaction_id: string; tags: Tag | null }> }),
    ]);

    const accountNameById = new Map(
      (accountResult.data ?? []).map((a) => [a.id, a.name]),
    );
    const budgetNameById = new Map(
      (budgetResult.data ?? []).map((b) => [b.id, b.name]),
    );
    const categoryById = new Map(
      (categoryResult.data ?? []).map((c) => [c.id, c]),
    );

    const tagsByTxn = new Map<string, Tag[]>();
    for (const link of tagResult.data ?? []) {
      const tags = tagsByTxn.get(link.transaction_id) ?? [];
      if (link.tags) tags.push(link.tags);
      tagsByTxn.set(link.transaction_id, tags);
    }

    setTransactions(
      rows.map((r) => ({
        ...r,
        accounts: r.account_id ? { name: accountNameById.get(r.account_id) ?? "" } : null,
        transfer_accounts: r.transfer_account_id
          ? { name: accountNameById.get(r.transfer_account_id) ?? "" }
          : null,
        category: r.category_id ? categoryById.get(r.category_id) ?? null : null,
        tags: tagsByTxn.get(r.id) ?? [],
        budget: r.budget_id ? { name: budgetNameById.get(r.budget_id) ?? "" } : null,
      })),
    );
    setLoading(false);
    // categoryKey/tagKey stand in for the categoryIds/tagIds arrays (stable
    // identity); listing the arrays themselves would refetch every render.
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [
    filters.accountId,
    accountIdsKey,
    typeKey,
    statusKey,
    filters.dateFrom,
    filters.dateTo,
    filters.search,
    filters.amountMin,
    filters.amountMax,
    filters.budgetName,
    filters.fixedExpenseLinked,
    categoryKey,
    tagKey,
  ]);

  useEffect(() => {
    fetch();
    const channel = supabase
      .channel("transactions-changes")
      .on("postgres_changes", { event: "*", schema: "public", table: "transactions" }, () => fetch())
      .subscribe();
    return () => { supabase.removeChannel(channel); };
  }, [fetch]);

  return { transactions, loading, refetch: fetch };
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
const CATEGORY_COLORS = [
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

export async function createCategory(name: string): Promise<Category> {
  const { data: { user } } = await supabase.auth.getUser();
  if (!user) throw new Error("Not authenticated");
  const { data, error } = await supabase
    .from("categories")
    .insert({ user_id: user.id, name, color: colorForName(name) })
    .select()
    .single();
  if (error) throw error;
  return data;
}
