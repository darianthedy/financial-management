import { useCallback, useEffect, useState } from "react";
import { supabase } from "@/lib/supabase/client";
import type { Json } from "@/lib/types/database";

/** One non-zero cell of the allocation grid, in minor units. */
export interface InstallmentGridCell {
  budget_name: string;
  year_month: string;
  amount: number;
}

export interface CreateInstallmentParams {
  accountId: string;
  /** Total expense amount in minor units; must equal the grid sum. */
  amount: number;
  date: string;
  description: string | null;
  /** First month of the spread, 'YYYY-MM'. */
  startYearMonth: string;
  /** Number of consecutive months the spread covers. */
  months: number;
  /** Non-zero cells only; their amounts must sum to `amount`. */
  grid: InstallmentGridCell[];
}

/**
 * Create a Budget Installment via the `create_budget_installment` RPC. The RPC
 * inserts the source expense (with `budget_id = NULL`), the installment header,
 * and one allocation per grid cell atomically, materializing any missing budget
 * rows. Returns the new `budget_installments` id.
 */
export async function createInstallment(
  params: CreateInstallmentParams,
): Promise<string> {
  const { data, error } = await supabase.rpc("create_budget_installment", {
    p_account_id: params.accountId,
    p_amount: params.amount,
    p_date: params.date,
    p_description: params.description,
    p_start_year_month: params.startYearMonth,
    p_months: params.months,
    // The grid is a JSON array of { budget_name, year_month, amount } cells.
    p_grid: params.grid as unknown as Json,
  });
  if (error) throw error;
  return data;
}

/** An active Budget Installment with its span and the budgets it reserves from. */
export interface InstallmentSummary {
  id: string;
  /** Source expense total, in minor units. */
  totalAmount: number;
  /** Description carried from the source expense (may be empty). */
  description: string | null;
  startYearMonth: string;
  months: number;
  sourceTransactionId: string;
  /** Distinct budget lineages this installment reserves from, sorted. */
  budgetNames: string[];
}

interface InstallmentRow {
  id: string;
  total_amount: number;
  description: string | null;
  start_year_month: string;
  months: number;
  source_transaction_id: string;
  allocations: { budget_name: string }[] | null;
}

/**
 * Every active installment, newest first, each with the distinct budgets it
 * touches (derived from its allocation cells). One header row per spread.
 */
export async function fetchInstallments(): Promise<InstallmentSummary[]> {
  const { data, error } = await supabase
    .from("budget_installments")
    .select(
      "id, total_amount, description, start_year_month, months, source_transaction_id, " +
        "allocations:budget_installment_allocations(budget_name)",
    )
    .order("created_at", { ascending: false });
  if (error) throw error;
  return ((data ?? []) as unknown as InstallmentRow[]).map((row) => ({
    id: row.id,
    totalAmount: row.total_amount,
    description: row.description,
    startYearMonth: row.start_year_month,
    months: row.months,
    sourceTransactionId: row.source_transaction_id,
    budgetNames: [
      ...new Set((row.allocations ?? []).map((a) => a.budget_name)),
    ].sort((a, b) => a.localeCompare(b)),
  }));
}

/**
 * Cancel an installment by deleting its header row. `ON DELETE CASCADE` clears
 * the allocation cells, so the affected budgets immediately recover their
 * reserved allowance. The materialized budget rows themselves remain.
 */
export async function cancelInstallment(id: string): Promise<void> {
  const { error } = await supabase
    .from("budget_installments")
    .delete()
    .eq("id", id);
  if (error) throw error;
}

/**
 * Live list of active installments. Re-fetches on changes to either installment
 * table so the list (and a freshly cancelled row) stays in sync, mirroring the
 * realtime pattern used by `useBudgets`.
 */
export function useInstallments() {
  const [installments, setInstallments] = useState<InstallmentSummary[]>([]);
  const [loading, setLoading] = useState(true);

  const refetch = useCallback(async () => {
    setLoading(true);
    try {
      setInstallments(await fetchInstallments());
    } finally {
      setLoading(false);
    }
  }, []);

  useEffect(() => {
    // Initial load mirrors useBudgets: kick off the fetch, then subscribe.
    // eslint-disable-next-line react-hooks/set-state-in-effect
    refetch();
    const channel = supabase
      .channel("installments-changes")
      .on(
        "postgres_changes",
        { event: "*", schema: "public", table: "budget_installments" },
        () => refetch(),
      )
      .on(
        "postgres_changes",
        { event: "*", schema: "public", table: "budget_installment_allocations" },
        () => refetch(),
      )
      .subscribe();
    return () => {
      supabase.removeChannel(channel);
    };
  }, [refetch]);

  return { installments, loading, refetch };
}
