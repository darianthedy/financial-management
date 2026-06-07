import { useEffect, useState, useCallback } from "react";
import { supabase } from "@/lib/supabase/client";
import type { MonthlyCashflow, SpendingByCategory, Transaction, BudgetProgress, Category, Tag } from "@/lib/types/database";

export type RecentTransaction = Transaction & {
  accounts: { name: string } | null;
  transfer_accounts: { name: string } | null;
  category: Category | null;
  tags: Tag[];
  budget: { name: string } | null;
};

export function useDashboard(yearMonth: string) {
  const [cashflow, setCashflow] = useState<MonthlyCashflow | null>(null);
  const [spendingByCategory, setSpendingByCategory] = useState<SpendingByCategory[]>([]);
  const [budgetProgress, setBudgetProgress] = useState<BudgetProgress[]>([]);
  const [recentTransactions, setRecentTransactions] = useState<RecentTransaction[]>([]);
  const [loading, setLoading] = useState(true);

  const fetch = useCallback(async () => {
    setLoading(true);
    const [
      { data: cfRows },
      { data: spendRows },
      { data: budgetRows },
      { data: txnRows },
    ] = await Promise.all([
      supabase
        .from("v_monthly_cashflow")
        .select("*")
        .eq("year_month", yearMonth)
        .maybeSingle(),
      supabase
        .from("v_spending_by_category")
        .select("*")
        .eq("year_month", yearMonth)
        .order("total_amount", { ascending: false }),
      supabase
        .from("v_budget_progress")
        .select("*")
        .eq("year_month", yearMonth)
        .order("budget_name", { ascending: true }),
      supabase
        .from("transactions")
        .select("*")
        .eq("status", "confirmed")
        .order("date", { ascending: false })
        .order("created_at", { ascending: false })
        .limit(10),
    ]);

    // Hydrate the recent transactions with the relations the row needs:
    // account + transfer-account names, linked categories, and budget name.
    const txns = txnRows ?? [];
    const txnIds = txns.map((t) => t.id);
    const accountIds = [
      ...new Set([
        ...txns.map((t) => t.account_id),
        ...txns.map((t) => t.transfer_account_id).filter(Boolean),
      ]),
    ] as string[];
    const budgetIds = [
      ...new Set(txns.map((t) => t.budget_id).filter(Boolean)),
    ] as string[];
    const catIds = [
      ...new Set(txns.map((t) => t.category_id).filter(Boolean)),
    ] as string[];

    const [accountRes, budgetRes, categoryRes, tagRes] = await Promise.all([
      accountIds.length
        ? supabase.from("accounts").select("id, name").in("id", accountIds)
        : Promise.resolve({ data: [] as Array<{ id: string; name: string }> }),
      budgetIds.length
        ? supabase.from("budgets").select("id, name").in("id", budgetIds)
        : Promise.resolve({ data: [] as Array<{ id: string; name: string }> }),
      catIds.length
        ? supabase.from("categories").select("*").in("id", catIds)
        : Promise.resolve({ data: [] as Category[] }),
      txnIds.length
        ? (supabase
            .from("transaction_tags")
            .select("transaction_id, tags(*)")
            .in("transaction_id", txnIds) as unknown as Promise<{
            data: Array<{ transaction_id: string; tags: Tag | null }> | null;
          }>)
        : Promise.resolve({ data: [] as Array<{ transaction_id: string; tags: Tag | null }> }),
    ]);

    const nameById = new Map((accountRes.data ?? []).map((a) => [a.id, a.name]));
    const budgetNameById = new Map((budgetRes.data ?? []).map((b) => [b.id, b.name]));
    const categoryById = new Map((categoryRes.data ?? []).map((c) => [c.id, c]));
    const tagsByTxn = new Map<string, Tag[]>();
    for (const link of tagRes.data ?? []) {
      const tags = tagsByTxn.get(link.transaction_id) ?? [];
      if (link.tags) tags.push(link.tags);
      tagsByTxn.set(link.transaction_id, tags);
    }

    setCashflow(cfRows ?? null);
    setSpendingByCategory(spendRows ?? []);
    setBudgetProgress(budgetRows ?? []);
    setRecentTransactions(
      txns.map((t) => ({
        ...t,
        accounts: { name: nameById.get(t.account_id) ?? "" },
        transfer_accounts: t.transfer_account_id
          ? { name: nameById.get(t.transfer_account_id) ?? "" }
          : null,
        category: t.category_id ? categoryById.get(t.category_id) ?? null : null,
        tags: tagsByTxn.get(t.id) ?? [],
        budget: t.budget_id ? { name: budgetNameById.get(t.budget_id) ?? "" } : null,
      })),
    );
    setLoading(false);
  }, [yearMonth]);

  useEffect(() => {
    fetch();
    const channel = supabase
      .channel("dashboard-changes")
      .on("postgres_changes", { event: "*", schema: "public", table: "transactions" }, () => fetch())
      .on("postgres_changes", { event: "*", schema: "public", table: "budgets" }, () => fetch())
      .subscribe();
    return () => { supabase.removeChannel(channel); };
  }, [fetch]);

  return { cashflow, spendingByCategory, budgetProgress, recentTransactions, loading, refetch: fetch };
}
