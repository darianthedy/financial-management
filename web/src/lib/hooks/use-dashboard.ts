import { useEffect, useState, useCallback } from "react";
import { supabase } from "@/lib/supabase/client";
import type { Account, BudgetProgress, Category } from "@/lib/types/database";
import type { FixedExpenseWithStatus } from "@/lib/hooks/use-fixed-expenses";
import { monthDateRange } from "@/lib/utils/date";

/** An account with its end-of-month balance for the selected month. */
export type AccountMonthBalance = Account & { balance: number };

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
  const [accounts, setAccounts] = useState<AccountMonthBalance[]>([]);
  const [loading, setLoading] = useState(true);

  const fetch = useCallback(async () => {
    setLoading(true);
    const { start, endExclusive } = monthDateRange(yearMonth);
    const [
      { data: budgetRows },
      { data: fxRows },
      { data: unplannedRows },
      { data: accountRows },
      { data: balanceRows },
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
        .from("accounts")
        .select("*")
        .eq("is_archived", false)
        .order("created_at", { ascending: true }),
      // Monthly balance ledger up to the selected month; we take the latest row
      // at or before it per account (balances carry forward across empty months).
      supabase
        .from("account_monthly_balances")
        .select("account_id, year_month, balance")
        .lte("year_month", yearMonth),
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

    const fxIds = (fxRows ?? []).map((f) => f.id);

    const [categoryRes, fxLinkRes] = await Promise.all([
      unplannedCatIds.length
        ? supabase.from("categories").select("*").in("id", unplannedCatIds)
        : Promise.resolve({ data: [] as Category[] }),
      fxIds.length
        ? supabase
            .from("transactions")
            .select("fixed_expense_id, amount")
            .in("fixed_expense_id", fxIds)
        : Promise.resolve({
            data: [] as Array<{ fixed_expense_id: string | null; amount: number }>,
          }),
    ]);

    const categoryById = new Map((categoryRes.data ?? []).map((c) => [c.id, c]));

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

    // For each account, the most recent balance row at or before the selected
    // month — i.e. the latest balance for that month. Accounts with no ledger
    // row yet fall back to their starting balance.
    const latestBalanceByAccount = new Map<string, { ym: string; balance: number }>();
    for (const row of balanceRows ?? []) {
      const prev = latestBalanceByAccount.get(row.account_id);
      if (!prev || row.year_month > prev.ym) {
        latestBalanceByAccount.set(row.account_id, {
          ym: row.year_month,
          balance: row.balance,
        });
      }
    }
    setAccounts(
      (accountRows ?? []).map((a) => ({
        ...a,
        balance: latestBalanceByAccount.get(a.id)?.balance ?? a.starting_balance,
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
      .on("postgres_changes", { event: "*", schema: "public", table: "accounts" }, () => fetch())
      .on("postgres_changes", { event: "*", schema: "public", table: "account_monthly_balances" }, () => fetch())
      .subscribe();
    return () => { supabase.removeChannel(channel); };
  }, [fetch]);

  return { unplannedExpenses, fixedExpenses, budgetProgress, accounts, loading, refetch: fetch };
}
