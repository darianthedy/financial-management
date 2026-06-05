import { useEffect, useState, useCallback } from "react";
import { supabase } from "@/lib/supabase/client";
import type { BudgetProgress } from "@/lib/types/database";
import type { BudgetFormValues } from "@/lib/validations/budget";
import { toMinorUnits } from "@/lib/utils/currency";

/**
 * Budget progress for a single month. Reads the live `v_budget_progress` view,
 * which derives carry-over by chaining each (name, currency) lineage — so this
 * also re-fetches on transaction changes, not just budget edits.
 */
export function useBudgets(yearMonth: string) {
  const [budgets, setBudgets] = useState<BudgetProgress[]>([]);
  const [loading, setLoading] = useState(true);

  const fetch = useCallback(async () => {
    setLoading(true);
    const { data } = await supabase
      .from("v_budget_progress")
      .select("*")
      .eq("year_month", yearMonth)
      .order("budget_name", { ascending: true });
    setBudgets(data ?? []);
    setLoading(false);
  }, [yearMonth]);

  useEffect(() => {
    fetch();
    const channel = supabase
      .channel("budgets-changes")
      .on(
        "postgres_changes",
        { event: "*", schema: "public", table: "budgets" },
        () => fetch(),
      )
      .on(
        "postgres_changes",
        { event: "*", schema: "public", table: "transactions" },
        () => fetch(),
      )
      .subscribe();
    return () => {
      supabase.removeChannel(channel);
    };
  }, [fetch]);

  return { budgets, loading, refetch: fetch };
}

async function currentUserId(): Promise<string> {
  const {
    data: { user },
  } = await supabase.auth.getUser();
  if (!user) throw new Error("Not authenticated");
  return user.id;
}

/**
 * Insert one budget row for the given month. Identity is (name + currency);
 * the UNIQUE constraint rejects a duplicate for the same month. Returns the new
 * row id so callers (e.g. the transaction budget picker) can auto-select it.
 */
export async function createBudget(
  values: BudgetFormValues,
  yearMonth: string,
  decimalPlaces = 2,
): Promise<string> {
  const user_id = await currentUserId();
  const { data, error } = await supabase
    .from("budgets")
    .insert({
      user_id,
      name: values.name,
      year_month: yearMonth,
      currency: values.currency,
      periodic_amount: toMinorUnits(values.periodic_amount, decimalPlaces),
    })
    .select("id")
    .single();
  if (error) throw error;
  return data.id;
}

/**
 * Edit a single month's budget row. Past/future months are untouched, but since
 * carry-over is computed live, this re-flows every later month in the lineage.
 */
export async function updateBudget(
  id: string,
  values: BudgetFormValues,
  decimalPlaces = 2,
) {
  const { error } = await supabase
    .from("budgets")
    .update({
      name: values.name,
      currency: values.currency,
      periodic_amount: toMinorUnits(values.periodic_amount, decimalPlaces),
    })
    .eq("id", id);
  if (error) throw error;
}

/** Remove a budget for one month. A deliberate gap resets that lineage's carry-over. */
export async function deleteBudget(id: string) {
  const { error } = await supabase.from("budgets").delete().eq("id", id);
  if (error) throw error;
}

/**
 * Distinct budget names for the transaction-list filter. Reads `v_budget_progress`
 * (the same source the Budgets page and the transaction budget picker use), so the
 * filter offers exactly the budgets the user sees elsewhere. Budgets are month-
 * specific rows, so the same name spans many periods — we de-dupe to names. An
 * optional [fromYM, toYM] month range (derived from the date filter) limits the
 * list to budgets that exist in those months. year_month is 'YYYY-MM', so lexical
 * gte/lte bounds the range.
 */
export async function fetchBudgetNames(
  fromYM?: string,
  toYM?: string,
): Promise<string[]> {
  let q = supabase.from("v_budget_progress").select("budget_name");
  if (fromYM) q = q.gte("year_month", fromYM);
  if (toYM) q = q.lte("year_month", toYM);
  const { data } = await q;
  return [...new Set((data ?? []).map((r) => r.budget_name))].sort((a, b) =>
    a.localeCompare(b),
  );
}

/**
 * Budgets available to link a transaction to: those for the transaction's month
 * whose currency matches the transaction's currency. Reads the progress view so
 * callers can show each budget's effective amount.
 */
export async function fetchBudgetsForMonth(
  yearMonth: string,
  currency: string,
): Promise<BudgetProgress[]> {
  const { data } = await supabase
    .from("v_budget_progress")
    .select("*")
    .eq("year_month", yearMonth)
    .eq("currency", currency)
    .order("budget_name", { ascending: true });
  return data ?? [];
}
