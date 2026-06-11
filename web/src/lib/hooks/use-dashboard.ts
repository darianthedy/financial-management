import { useEffect, useState, useCallback } from "react";
import { supabase } from "@/lib/supabase/client";
import type { MonthlyCashflow, SpendingByCategory, Transaction, BudgetProgress, Category, Tag } from "@/lib/types/database";

export type RecentTransaction = Transaction & {
  accounts: { name: string; image_url: string | null } | null;
  transfer_accounts: { name: string } | null;
  category: Category | null;
  tags: Tag[];
  budget: { name: string } | null;
  fixedExpense: { name: string } | null;
};

/**
 * Fraction of a budget consumed, used to rank budgets by urgency. Overspent
 * budgets land above 1; a budget with no effective amount but real spend sorts
 * to the top (Infinity), an empty budget to the bottom (0).
 */
function pctUsed(b: BudgetProgress): number {
  if (b.effective_amount > 0) return b.spent / b.effective_amount;
  return b.spent > 0 ? Infinity : 0;
}

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
        .eq("year_month", yearMonth),
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
    const fixedExpenseIds = [
      ...new Set(txns.map((t) => t.fixed_expense_id).filter(Boolean)),
    ] as string[];

    const [accountRes, budgetRes, categoryRes, fixedExpenseRes, tagRes] = await Promise.all([
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
      txnIds.length
        ? (supabase
            .from("transaction_tags")
            .select("transaction_id, tags(*)")
            .in("transaction_id", txnIds) as unknown as Promise<{
            data: Array<{ transaction_id: string; tags: Tag | null }> | null;
          }>)
        : Promise.resolve({ data: [] as Array<{ transaction_id: string; tags: Tag | null }> }),
    ]);

    const accountById = new Map((accountRes.data ?? []).map((a) => [a.id, a]));
    const budgetNameById = new Map((budgetRes.data ?? []).map((b) => [b.id, b.name]));
    const categoryById = new Map((categoryRes.data ?? []).map((c) => [c.id, c]));
    const fixedExpenseNameById = new Map(
      (fixedExpenseRes.data ?? []).map((f) => [f.id, f.name]),
    );
    const tagsByTxn = new Map<string, Tag[]>();
    for (const link of tagRes.data ?? []) {
      const tags = tagsByTxn.get(link.transaction_id) ?? [];
      if (link.tags) tags.push(link.tags);
      tagsByTxn.set(link.transaction_id, tags);
    }

    setCashflow(cfRows ?? null);
    setSpendingByCategory(spendRows ?? []);
    // Surface the budgets that need attention first: most-over and
    // closest-to-the-limit lead, instead of an alphabetical wall.
    setBudgetProgress([...(budgetRows ?? [])].sort((a, b) => pctUsed(b) - pctUsed(a)));
    setRecentTransactions(
      txns.map((t) => ({
        ...t,
        accounts: {
          name: accountById.get(t.account_id)?.name ?? "",
          image_url: accountById.get(t.account_id)?.image_url ?? null,
        },
        transfer_accounts: t.transfer_account_id
          ? { name: accountById.get(t.transfer_account_id)?.name ?? "" }
          : null,
        category: t.category_id ? categoryById.get(t.category_id) ?? null : null,
        tags: tagsByTxn.get(t.id) ?? [],
        budget: t.budget_id ? { name: budgetNameById.get(t.budget_id) ?? "" } : null,
        fixedExpense: t.fixed_expense_id
          ? { name: fixedExpenseNameById.get(t.fixed_expense_id) ?? "" }
          : null,
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
