import { useCallback, useEffect, useState } from "react";
import { supabase } from "@/lib/supabase/client";
import { navigateMonth } from "@/lib/utils/date";

/** One month's cashflow in a trailing trend window. */
export type CashflowTrendPoint = {
  year_month: string;
  total_income: number;
  total_expense: number;
  net: number;
};

/** How many months the trend window spans, including the selected month. */
export const TREND_MONTHS = 6;

/** Build the ordered list of the `count` months ending at (and including) `end`. */
function trailingMonths(end: string, count: number): string[] {
  const months: string[] = [];
  for (let i = count - 1; i >= 0; i--) months.push(navigateMonth(end, -i));
  return months;
}

/**
 * The last `TREND_MONTHS` months of cashflow ending at (and including)
 * `yearMonth`, from `v_monthly_cashflow` (confirmed transactions only, transfers
 * excluded). Months with no activity are absent from the view, so we build a
 * fixed skeleton of every month in the window and merge the rows in — a gap
 * renders as a real zero column instead of silently collapsing the axis.
 * Realtime on `transactions` keeps it in step with edits.
 */
export function useCashflowTrend(yearMonth: string) {
  const [trend, setTrend] = useState<CashflowTrendPoint[]>([]);
  const [loading, setLoading] = useState(true);

  const fetch = useCallback(async () => {
    setLoading(true);
    const months = trailingMonths(yearMonth, TREND_MONTHS);
    const start = months[0];

    // year_month is 'YYYY-MM' text, so lexical bounds order the same as dates.
    const { data: rows } = await supabase
      .from("v_monthly_cashflow")
      .select("year_month, total_income, total_expense, net")
      .gte("year_month", start)
      .lte("year_month", yearMonth);

    const byMonth = new Map((rows ?? []).map((r) => [r.year_month, r]));
    setTrend(
      months.map((ym) => {
        const row = byMonth.get(ym);
        return {
          year_month: ym,
          total_income: row?.total_income ?? 0,
          total_expense: row?.total_expense ?? 0,
          net: row?.net ?? 0,
        };
      }),
    );
    setLoading(false);
  }, [yearMonth]);

  useEffect(() => {
    fetch();
    const channel = supabase
      .channel("cashflow-trend-changes")
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

  return { trend, loading };
}
