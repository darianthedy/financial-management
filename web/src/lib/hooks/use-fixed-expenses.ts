import { useCallback, useEffect, useState } from "react";
import { supabase } from "@/lib/supabase/client";
import type { FixedExpense } from "@/lib/types/database";
import type { FixedExpenseFormValues } from "@/lib/validations/fixed-expense";
import { toMinorUnits } from "@/lib/utils/currency";
import { navigateMonth } from "@/lib/utils/date";

// A month's fixed expense enriched with its derived paid status. "Paid" is not
// stored: an entry is paid when at least one transaction references it via
// transactions.fixed_expense_id (amounts need not match). `paid_total` sums
// those linked transactions so the row can show how much has been paid.
export type FixedExpenseWithStatus = FixedExpense & {
  paid: boolean;
  paid_total: number;
};

async function currentUserId(): Promise<string> {
  const {
    data: { user },
  } = await supabase.auth.getUser();
  if (!user) throw new Error("Not authenticated");
  return user.id;
}

/**
 * The current user's fixed expenses for one month, each with its derived paid
 * status. Paid status comes from a separate lookup over `transactions`, so this
 * re-fetches on transaction changes too (linking a transaction flips an entry to
 * paid).
 */
export function useFixedExpenses(yearMonth: string) {
  const [fixedExpenses, setFixedExpenses] = useState<FixedExpenseWithStatus[]>(
    [],
  );
  const [loading, setLoading] = useState(true);

  const fetch = useCallback(async () => {
    setLoading(true);
    const {
      data: { user },
    } = await supabase.auth.getUser();
    if (!user) {
      setFixedExpenses([]);
      setLoading(false);
      return;
    }

    const { data: rows } = await supabase
      .from("fixed_expenses")
      .select("*")
      .eq("user_id", user.id)
      .eq("year_month", yearMonth)
      .order("due_day", { ascending: true })
      .order("name", { ascending: true });

    const list = rows ?? [];
    const ids = list.map((r) => r.id);

    // Linked transactions drive paid status. Any transaction referencing the
    // entry counts (matches the "linked = paid" requirement and the transaction
    // fixed-expense filter, which checks the FK regardless of status).
    const { data: links } = ids.length
      ? await supabase
          .from("transactions")
          .select("fixed_expense_id, amount")
          .in("fixed_expense_id", ids)
      : { data: [] as Array<{ fixed_expense_id: string | null; amount: number }> };

    const paidTotalById = new Map<string, number>();
    for (const link of links ?? []) {
      if (!link.fixed_expense_id) continue;
      paidTotalById.set(
        link.fixed_expense_id,
        (paidTotalById.get(link.fixed_expense_id) ?? 0) + link.amount,
      );
    }

    setFixedExpenses(
      list.map((r) => ({
        ...r,
        paid: paidTotalById.has(r.id),
        paid_total: paidTotalById.get(r.id) ?? 0,
      })),
    );
    setLoading(false);
  }, [yearMonth]);

  useEffect(() => {
    fetch();
    const channel = supabase
      .channel("fixed-expenses-changes")
      .on(
        "postgres_changes",
        { event: "*", schema: "public", table: "fixed_expenses" },
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

  return { fixedExpenses, loading, refetch: fetch };
}

/**
 * Insert one fixed-expense row for the given month. Returns the new row id so
 * callers (e.g. the transaction fixed-expense picker) can auto-select it.
 */
export async function createFixedExpense(
  values: FixedExpenseFormValues,
  yearMonth: string,
  decimalPlaces = 2,
): Promise<string> {
  const user_id = await currentUserId();
  const { data, error } = await supabase
    .from("fixed_expenses")
    .insert({
      user_id,
      name: values.name.trim(),
      year_month: yearMonth,
      amount: toMinorUnits(values.amount, decimalPlaces),
      due_day: values.due_day,
    })
    .select("id")
    .single();
  if (error) throw error;
  return data.id;
}

/** Edit a single month's fixed-expense row. Other months are untouched. */
export async function updateFixedExpense(
  id: string,
  values: FixedExpenseFormValues,
  decimalPlaces = 2,
) {
  const { error } = await supabase
    .from("fixed_expenses")
    .update({
      name: values.name.trim(),
      amount: toMinorUnits(values.amount, decimalPlaces),
      due_day: values.due_day,
    })
    .eq("id", id);
  if (error) throw error;
}

/** Remove a fixed expense for one month. Does not affect other months. */
export async function deleteFixedExpense(id: string) {
  const { error } = await supabase.from("fixed_expenses").delete().eq("id", id);
  if (error) throw error;
}

/**
 * Copy every fixed expense from the previous month into `yearMonth`, preserving
 * name, amount, due_day, and is_active. Entries whose name already exists in the
 * target month are skipped (the UNIQUE (user_id, name, year_month) constraint).
 * Returns the number of rows created.
 */
export async function copyFromPreviousMonth(yearMonth: string): Promise<number> {
  const user_id = await currentUserId();
  const prevMonth = navigateMonth(yearMonth, -1);

  const [{ data: prevRows }, { data: currentRows }] = await Promise.all([
    supabase
      .from("fixed_expenses")
      .select("name, amount, due_day, is_active")
      .eq("user_id", user_id)
      .eq("year_month", prevMonth),
    supabase
      .from("fixed_expenses")
      .select("name")
      .eq("user_id", user_id)
      .eq("year_month", yearMonth),
  ]);

  const existing = new Set((currentRows ?? []).map((r) => r.name));
  const toInsert = (prevRows ?? [])
    .filter((r) => !existing.has(r.name))
    .map((r) => ({
      user_id,
      name: r.name,
      year_month: yearMonth,
      amount: r.amount,
      due_day: r.due_day,
      is_active: r.is_active,
    }));

  if (toInsert.length === 0) return 0;
  const { error } = await supabase.from("fixed_expenses").insert(toInsert);
  if (error) throw error;
  return toInsert.length;
}

/**
 * Fixed expenses available to link a transaction to: those for the transaction's
 * month. Used by the transaction form's fixed-expense picker (expense only).
 */
export async function fetchFixedExpensesForMonth(
  yearMonth: string,
): Promise<FixedExpense[]> {
  const {
    data: { user },
  } = await supabase.auth.getUser();
  if (!user) return [];
  const { data } = await supabase
    .from("fixed_expenses")
    .select("*")
    .eq("user_id", user.id)
    .eq("year_month", yearMonth)
    .order("due_day", { ascending: true })
    .order("name", { ascending: true });
  return data ?? [];
}
