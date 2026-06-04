import { useEffect, useState, useCallback } from "react";
import { supabase } from "@/lib/supabase/client";
import type { Transaction, Category, Tag } from "@/lib/types/database";
import type { TransactionFormValues } from "@/lib/validations/transaction";
import { toMinorUnits } from "@/lib/utils/currency";

export type TransactionWithRelations = Transaction & {
  accounts: { name: string } | null;
  transfer_accounts: { name: string } | null;
  categories: Category[];
  tags: Tag[];
};

export interface TransactionFilters {
  accountId?: string;
  type?: "income" | "expense" | "transfer";
  status?: "confirmed" | "pending" | "dismissed";
  dateFrom?: string;
  dateTo?: string;
}

export function useTransactions(filters: TransactionFilters = {}) {
  const [transactions, setTransactions] = useState<TransactionWithRelations[]>([]);
  const [loading, setLoading] = useState(true);

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
    if (filters.type) q = q.eq("type", filters.type);
    if (filters.status) q = q.eq("status", filters.status);
    if (filters.dateFrom) q = q.gte("date", filters.dateFrom);
    if (filters.dateTo) q = q.lte("date", filters.dateTo);

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

    // Fetch account names and junction rows in parallel.
    const [accountResult, catResult, tagResult] = await Promise.all([
      accountIds.length
        ? supabase.from("accounts").select("id, name").in("id", accountIds)
        : Promise.resolve({ data: [] as Array<{ id: string; name: string }> }),
      ids.length
        ? (supabase
            .from("transaction_categories")
            .select("transaction_id, categories(*)")
            .in("transaction_id", ids) as unknown as Promise<{
            data: Array<{
              transaction_id: string;
              categories: Category | null;
            }> | null;
          }>)
        : Promise.resolve({ data: [] as Array<{ transaction_id: string; categories: Category | null }> }),
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

    const catsByTxn = new Map<string, Category[]>();
    for (const link of catResult.data ?? []) {
      const cats = catsByTxn.get(link.transaction_id) ?? [];
      if (link.categories) cats.push(link.categories);
      catsByTxn.set(link.transaction_id, cats);
    }

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
        categories: catsByTxn.get(r.id) ?? [],
        tags: tagsByTxn.get(r.id) ?? [],
      })),
    );
    setLoading(false);
  }, [filters.accountId, filters.type, filters.status, filters.dateFrom, filters.dateTo]);

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

async function writeJunctionRows(txnId: string, categoryIds: string[], tagIds: string[]) {
  await Promise.all([
    ...(categoryIds.length
      ? [supabase.from("transaction_categories").insert(categoryIds.map((id) => ({ transaction_id: txnId, category_id: id }))).then()]
      : []),
    ...(tagIds.length
      ? [supabase.from("transaction_tags").insert(tagIds.map((id) => ({ transaction_id: txnId, tag_id: id }))).then()]
      : []),
  ]);
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
      currency: values.currency,
      description: values.description ?? null,
      date: values.date,
      budget_id: values.type === "transfer" ? null : (values.budget_id ?? null),
    })
    .select("id")
    .single();
  if (error) throw error;
  await writeJunctionRows(data.id, values.category_ids ?? [], values.tag_ids ?? []);
}

export async function updateTransaction(id: string, values: TransactionFormValues, decimalPlaces = 2) {
  const { error } = await supabase.from("transactions").update({
    account_id: values.account_id,
    transfer_account_id: values.type === "transfer" ? (values.transfer_account_id ?? null) : null,
    type: values.type,
    amount: toMinorUnits(values.amount, decimalPlaces),
    currency: values.currency,
    description: values.description ?? null,
    date: values.date,
    budget_id: values.type === "transfer" ? null : (values.budget_id ?? null),
  }).eq("id", id);
  if (error) throw error;
  await Promise.all([
    supabase.from("transaction_categories").delete().eq("transaction_id", id),
    supabase.from("transaction_tags").delete().eq("transaction_id", id),
  ]);
  await writeJunctionRows(id, values.category_ids ?? [], values.tag_ids ?? []);
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
