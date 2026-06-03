import { useEffect, useState, useCallback } from "react";
import { supabase } from "@/lib/supabase/client";
import type { MonthlyCashflow, SpendingByCategory, Transaction } from "@/lib/types/database";

export type RecentTransaction = Transaction & {
  accounts: { name: string } | null;
};

export function useDashboard(yearMonth: string) {
  const [cashflow, setCashflow] = useState<MonthlyCashflow | null>(null);
  const [spendingByCategory, setSpendingByCategory] = useState<SpendingByCategory[]>([]);
  const [recentTransactions, setRecentTransactions] = useState<RecentTransaction[]>([]);
  const [loading, setLoading] = useState(true);

  const fetch = useCallback(async () => {
    setLoading(true);
    const [
      { data: cfRows },
      { data: spendRows },
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
        .from("transactions")
        .select("*")
        .eq("status", "confirmed")
        .order("date", { ascending: false })
        .order("created_at", { ascending: false })
        .limit(10),
    ]);

    // Fetch account names for the recent transactions.
    const txns = txnRows ?? [];
    const accountIds = [...new Set(txns.map((t) => t.account_id))];
    const { data: accountRows } = accountIds.length
      ? await supabase.from("accounts").select("id, name").in("id", accountIds)
      : { data: [] as Array<{ id: string; name: string }> };
    const nameById = new Map((accountRows ?? []).map((a) => [a.id, a.name]));

    setCashflow(cfRows ?? null);
    setSpendingByCategory(spendRows ?? []);
    setRecentTransactions(
      txns.map((t) => ({
        ...t,
        accounts: { name: nameById.get(t.account_id) ?? "" },
      })),
    );
    setLoading(false);
  }, [yearMonth]);

  useEffect(() => {
    fetch();
    const channel = supabase
      .channel("dashboard-changes")
      .on("postgres_changes", { event: "*", schema: "public", table: "transactions" }, () => fetch())
      .subscribe();
    return () => { supabase.removeChannel(channel); };
  }, [fetch]);

  return { cashflow, spendingByCategory, recentTransactions, loading, refetch: fetch };
}
