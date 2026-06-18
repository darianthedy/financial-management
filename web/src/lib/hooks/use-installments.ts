import { useCallback, useEffect, useState } from "react";
import { supabase } from "@/lib/supabase/client";
import type { Category, Json, TransactionType } from "@/lib/types/database";
import { deriveTitle } from "@/components/transactions/transaction-display";

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
  /** Optional category for the source expense. */
  categoryId?: string | null;
  /** Optional fixed-expense link for the source expense. */
  fixedExpenseId?: string | null;
  /** Optional tag ids to attach to the source expense. */
  tagIds?: string[];
}

/**
 * Create a Budget Installment via the `create_budget_installment` RPC. The RPC
 * inserts the source expense (with `budget_id = NULL`, but carrying any category,
 * fixed-expense link, and tags), the installment header, and one allocation per
 * grid cell atomically, materializing any missing budget rows. Returns the new
 * `budget_installments` id.
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
    p_category_id: params.categoryId ?? null,
    p_fixed_expense_id: params.fixedExpenseId ?? null,
    p_tag_ids: params.tagIds ?? null,
  });
  if (error) throw error;
  return data;
}

export interface SpreadTransactionParams {
  /** Existing expense to convert into a spread. */
  transactionId: string;
  /** First month of the spread, 'YYYY-MM'. */
  startYearMonth: string;
  /** Number of consecutive months the spread covers. */
  months: number;
  /** Non-zero cells only; their amounts must sum to the transaction's amount. */
  grid: InstallmentGridCell[];
}

/**
 * Convert an existing expense into a Budget Installment via the
 * `spread_existing_transaction` RPC. The RPC detaches the expense from any
 * single budget (`budget_id = NULL`), inserts the installment header, and writes
 * one allocation per grid cell atomically, materializing any missing budget
 * rows. The grid must sum to the transaction's own amount. Returns the new
 * `budget_installments` id.
 */
export async function spreadExistingTransaction(
  params: SpreadTransactionParams,
): Promise<string> {
  const { data, error } = await supabase.rpc("spread_existing_transaction", {
    p_transaction_id: params.transactionId,
    p_start_year_month: params.startYearMonth,
    p_months: params.months,
    // The grid is a JSON array of { budget_name, year_month, amount } cells.
    p_grid: params.grid as unknown as Json,
  });
  if (error) throw error;
  return data;
}

/**
 * Whether a transaction is already the source of a Budget Installment. Used to
 * hide the "spread" option when editing an expense that's already spread (the
 * RPC would reject a second spread anyway).
 */
export async function isTransactionSpread(
  transactionId: string,
): Promise<boolean> {
  const { data, error } = await supabase
    .from("budget_installments")
    .select("id")
    .eq("source_transaction_id", transactionId)
    .maybeSingle();
  if (error) throw error;
  return data != null;
}

/** An active Budget Installment with its span and the budgets it reserves from. */
export interface InstallmentSummary {
  id: string;
  /** Source expense total, in minor units. */
  totalAmount: number;
  /**
   * Display title, derived live from the source expense with the same
   * precedence the Transactions list uses (fixed expense → category →
   * description → "Expense"). Budget never applies — the source row is detached
   * from any single budget — so it never resolves to a budget name.
   */
  title: string;
  startYearMonth: string;
  months: number;
  sourceTransactionId: string;
  /** Distinct budget lineages this installment reserves from, sorted. */
  budgetNames: string[];
  /** Distinct 'YYYY-MM' months that actually carry a reservation. */
  reservedMonths: string[];
}

interface InstallmentRow {
  id: string;
  total_amount: number;
  description: string | null;
  start_year_month: string;
  months: number;
  source_transaction_id: string;
  allocations: { budget_name: string; year_month: string }[] | null;
  /** Source expense, embedded so the title can follow the Transactions rule. */
  source: {
    type: TransactionType;
    description: string | null;
    category: Category | null;
    fixedExpense: { name: string } | null;
  } | null;
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
        "allocations:budget_installment_allocations(budget_name, year_month), " +
        "source:transactions!source_transaction_id(type, description, " +
        "category:categories(*), fixedExpense:fixed_expenses(name))",
    )
    .order("created_at", { ascending: false });
  if (error) throw error;
  return ((data ?? []) as unknown as InstallmentRow[]).map((row) => {
    // Title follows the Transactions list rule. The source row's own
    // description is preferred, but we fall back to the header's snapshot if the
    // embed is somehow missing. Budget/transfer never apply to a source expense.
    const { title } = deriveTitle({
      type: row.source?.type ?? "expense",
      description: row.source?.description ?? row.description,
      accounts: null,
      transfer_accounts: null,
      category: row.source?.category ?? null,
      tags: [],
      budget: null,
      fixedExpense: row.source?.fixedExpense ?? null,
    });
    return {
      id: row.id,
      totalAmount: row.total_amount,
      title,
      startYearMonth: row.start_year_month,
      months: row.months,
      sourceTransactionId: row.source_transaction_id,
      budgetNames: [
        ...new Set((row.allocations ?? []).map((a) => a.budget_name)),
      ].sort((a, b) => a.localeCompare(b)),
      reservedMonths: [
        ...new Set((row.allocations ?? []).map((a) => a.year_month)),
      ].sort((a, b) => a.localeCompare(b)),
    };
  });
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
      // Titles are derived from the source expense, so refresh when a
      // transaction changes (e.g. its description or category is edited).
      .on(
        "postgres_changes",
        { event: "*", schema: "public", table: "transactions" },
        () => refetch(),
      )
      .subscribe();
    return () => {
      supabase.removeChannel(channel);
    };
  }, [refetch]);

  return { installments, loading, refetch };
}
