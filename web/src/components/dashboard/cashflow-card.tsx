import { ArrowDownLeft, ArrowUpRight } from "lucide-react";
import { Card, CardContent, CardHeader, CardTitle } from "@/components/ui/card";
import { EmptyState } from "@/components/ui/misc";
import { AmountColumn } from "@/components/shared/amount-column";
import { widestCurrencyNumber } from "@/lib/utils/currency";
import { useCurrencies } from "@/lib/hooks/use-currencies";
import { cn } from "@/lib/utils/cn";
import type { MonthCashflow } from "@/lib/hooks/use-dashboard";

interface Props {
  cashflow: MonthCashflow;
}

/**
 * Money in vs money out for the selected month: income, expenses, and the net
 * that answers "did I come out ahead?". A proportion bar shows how much of the
 * month's income the expenses consumed, and a savings-rate chip (net ÷ income)
 * summarizes it as one figure. Confirmed transactions only, transfers excluded
 * (see v_monthly_cashflow); a month with no activity shows an empty state.
 */
export function CashflowCard({ cashflow }: Props) {
  const { defaultCurrency } = useCurrencies();
  const { total_income, total_expense, net } = cashflow;

  const isEmpty = total_income === 0 && total_expense === 0;

  // Share one number-slot width across income, expenses, and net so their
  // currency symbols and digits line up into a tidy column, as elsewhere.
  const widestAmount = widestCurrencyNumber(
    [total_income, total_expense, net],
    defaultCurrency,
  );

  // Fraction of income the expenses ate up, clamped for the bar. When there's
  // no income but there is spend, the bar reads full (money out with none in).
  const spentFraction =
    total_income > 0
      ? Math.min(1, total_expense / total_income)
      : total_expense > 0
        ? 1
        : 0;

  // Savings rate only makes sense against real income.
  const savingsRate =
    total_income > 0 ? Math.round((net / total_income) * 100) : null;
  const positiveNet = net >= 0;

  return (
    <Card>
      <CardHeader className="flex flex-row items-center justify-between gap-2 space-y-0">
        <CardTitle>Cashflow</CardTitle>
        {savingsRate !== null && (
          <span
            className={cn(
              "rounded-full px-2 py-0.5 text-xs font-semibold",
              positiveNet
                ? "bg-[var(--color-success)]/12 text-[var(--color-success)]"
                : "bg-[var(--color-danger)]/12 text-[var(--color-danger)]",
            )}
          >
            {savingsRate}% saved
          </span>
        )}
      </CardHeader>
      <CardContent>
        {isEmpty ? (
          <EmptyState
            title="No activity this month"
            description="Income and expenses for this month will show up here."
          />
        ) : (
          <div className="flex flex-col gap-4">
            <div className="flex flex-col gap-2">
              <div className="flex items-center justify-between gap-2 text-sm">
                <span className="flex items-center gap-1.5 text-[var(--color-muted-foreground)]">
                  <ArrowDownLeft className="h-4 w-4 shrink-0 text-[var(--color-success)]" />
                  Income
                </span>
                <AmountColumn
                  minorUnits={total_income}
                  currency={defaultCurrency}
                  widestNumber={widestAmount}
                  className="text-nowrap font-semibold"
                />
              </div>
              <div className="flex items-center justify-between gap-2 text-sm">
                <span className="flex items-center gap-1.5 text-[var(--color-muted-foreground)]">
                  <ArrowUpRight className="h-4 w-4 shrink-0 text-[var(--color-danger)]" />
                  Expenses
                </span>
                <AmountColumn
                  minorUnits={total_expense}
                  currency={defaultCurrency}
                  widestNumber={widestAmount}
                  className="text-nowrap font-semibold"
                />
              </div>
            </div>

            {/* How much of this month's income the expenses consumed. */}
            <div
              className="h-1.5 w-full overflow-hidden rounded-full bg-[var(--color-muted)]"
              role="presentation"
            >
              <div
                className={cn(
                  "h-full rounded-full",
                  spentFraction >= 1
                    ? "bg-[var(--color-danger)]"
                    : "bg-[var(--color-primary)]",
                )}
                style={{ width: `${spentFraction * 100}%` }}
              />
            </div>

            <div className="flex items-baseline justify-between gap-2 border-t border-[var(--color-border)] pt-3">
              <span className="text-sm font-medium">Net</span>
              <AmountColumn
                minorUnits={net}
                currency={defaultCurrency}
                widestNumber={widestAmount}
                signed
                className={cn(
                  "text-nowrap text-base font-semibold",
                  positiveNet
                    ? "text-[var(--color-success)]"
                    : "text-[var(--color-danger)]",
                )}
              />
            </div>
          </div>
        )}
      </CardContent>
    </Card>
  );
}
