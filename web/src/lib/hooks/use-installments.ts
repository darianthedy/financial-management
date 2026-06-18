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
