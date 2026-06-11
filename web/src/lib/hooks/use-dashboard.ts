import { useEffect, useState, useCallback } from "react";
import { supabase } from "@/lib/supabase/client";
import type { Transaction, BudgetProgress, Category, Tag } from "@/lib/types/database";
import type { FixedExpenseWithStatus } from "@/lib/hooks/use-fixed-expenses";
import { monthDateRange } from "@/lib/utils/date";

export type RecentTransaction = Transaction & {
  accounts: { name: string; image_url: string | null } | null;
  transfer_accounts: { name: string } | null;
  category: Category | null;
  tags: Tag[];
  budget: { name: string } | null;
  fixedExpense: { name: string } | null;
};

/**
 * One category's unplanned spend for the month: confirmed expenses NOT tied to a
 * budget and NOT linked to a fixed expense. Spend with no category is collapsed
 * into a single null-id "Uncategorized" row.
 */
export type UnplannedCategorySpend = {
  category_id: string | null;
  category_name: string;
  icon: string | null;
  color: string | null;
  total_amount: number;
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
  const [unplannedExpenses, setUnplannedExpenses] = useState<UnplannedCategorySpend[]>([]);
  const [fixedExpenses, setFixedExpenses] = useState<FixedExpenseWithStatus[]>([]);
  const [budgetProgress, setBudgetProgress] = useState<BudgetProgress[]>([]);
  const [recentTransactions, setRecentTransactions] = useState<RecentTransaction[]>([]);
  const [loading, setLoading] = useState(true);

  const fetch = useCallback(async () => {
    setLoading(true);
    const { start, endExclusive } = monthDateRange(yearMonth);
    const [
      { data: budgetRows },
      { data: fxRows },
      { data: unplannedRows },
      { data: txnRows },
    ] = await Promise.all([
      supabase
        .from("v_budget_progress")
        .select("*")
        .eq("year_month", yearMonth),
      supabase
        .from("fixed_expenses")
        .select("*")
        .eq("year_month", yearMonth)
        .order("name", { ascending: true }),
      // Unplanned spend: confirmed expenses with no budget and no fixed expense.
      supabase
        .from("transactions")
        .select("category_id, amount")
        .eq("type", "expense")
        .eq("status", "confirmed")
        .is("budget_id", null)
        .is("fixed_expense_id", null)
        .gte("date", start)
        .lt("date", endExclusive),
      supabase
        .from("transactions")
        .select("*")
        .eq("status", "confirmed")
        .order("date", { ascending: false })
        .order("created_at", { ascending: false })
        .limit(10),
    ]);

    // Aggregate unplanned spend by category; a null category -> "Uncategorized".
    const unplannedByCat = new Map<string, number>();
    let unplannedNoCat = 0;
    for (const row of unplannedRows ?? []) {
      if (row.category_id) {
        unplannedByCat.set(
          row.category_id,
          (unplannedByCat.get(row.category_id) ?? 0) + row.amount,
        );
      } else {
        unplannedNoCat += row.amount;
      }
    }
    const unplannedCatIds = [...unplannedByCat.keys()];

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
    // Categories needed by both the recent-transaction rows and the unplanned
    // spend breakdown, so fetch them in one go.
    const catIds = [
      ...new Set([
        ...(txns.map((t) => t.category_id).filter(Boolean) as string[]),
        ...unplannedCatIds,
      ]),
    ];
    const fixedExpenseIds = [
      ...new Set(txns.map((t) => t.fixed_expense_id).filter(Boolean)),
    ] as string[];
    // Planned fixed expenses for the month; their paid status comes from any
    // transaction linking back via fixed_expense_id (amounts need not match).
    const fxIds = (fxRows ?? []).map((f) => f.id);

    const [accountRes, budgetRes, categoryRes, fixedExpenseRes, tagRes, fxLinkRes] = await Promise.all([
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
      fxIds.length
        ? supabase
            .from("transactions")
            .select("fixed_expense_id, amount")
            .in("fixed_expense_id", fxIds)
        : Promise.resolve({
            data: [] as Array<{ fixed_expense_id: string | null; amount: number }>,
          }),
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

    // Build the unplanned breakdown now that category metadata is loaded.
    const unplanned: UnplannedCategorySpend[] = unplannedCatIds.map((id) => {
      const cat = categoryById.get(id);
      return {
        category_id: id,
        category_name: cat?.name ?? "Unknown",
        icon: cat?.icon ?? null,
        color: cat?.color ?? null,
        total_amount: unplannedByCat.get(id) ?? 0,
      };
    });
    if (unplannedNoCat > 0) {
      unplanned.push({
        category_id: null,
        category_name: "Uncategorized",
        icon: null,
        color: null,
        total_amount: unplannedNoCat,
      });
    }
    unplanned.sort((a, b) => b.total_amount - a.total_amount);

    setUnplannedExpenses(unplanned);

    // Derive each fixed expense's paid status from its linked transactions.
    const paidTotalById = new Map<string, number>();
    for (const link of fxLinkRes.data ?? []) {
      if (!link.fixed_expense_id) continue;
      paidTotalById.set(
        link.fixed_expense_id,
        (paidTotalById.get(link.fixed_expense_id) ?? 0) + link.amount,
      );
    }
    setFixedExpenses(
      (fxRows ?? []).map((f) => ({
        ...f,
        paid: paidTotalById.has(f.id),
        paid_total: paidTotalById.get(f.id) ?? 0,
      })),
    );

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
      .on("postgres_changes", { event: "*", schema: "public", table: "fixed_expenses" }, () => fetch())
      .subscribe();
    return () => { supabase.removeChannel(channel); };
  }, [fetch]);

  return { unplannedExpenses, fixedExpenses, budgetProgress, recentTransactions, loading, refetch: fetch };
}
