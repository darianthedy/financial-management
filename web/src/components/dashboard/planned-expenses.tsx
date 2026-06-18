import { CheckCircle2, Clock } from "lucide-react";
import { Card, CardContent, CardHeader, CardTitle } from "@/components/ui/card";
import { EmptyState } from "@/components/ui/misc";
import { AmountColumn } from "@/components/shared/amount-column";
import { formatCurrency, maxCurrencyNumberWidth } from "@/lib/utils/currency";
import { monthElapsedFraction } from "@/lib/utils/date";
import { cn } from "@/lib/utils/cn";
import type { BudgetProgress } from "@/lib/types/database";
import type { FixedExpenseWithStatus } from "@/lib/hooks/use-fixed-expenses";

interface Props {
  budgets: BudgetProgress[];
  fixedExpenses: FixedExpenseWithStatus[];
  yearMonth: string;
}

/**
 * What the user has planned to spend this month: every budget (with progress)
 * and every fixed expense (with paid status). The headline sums both into a
 * single "planned" figure so the user sees their committed total at a glance.
 *
 * Budget bars are pace-aware: for the in-progress month the fill is colored by
 * the PROJECTED month-end (spend so far extrapolated over the elapsed fraction),
 * and a tick marks where linear pace should be today. Past months fall back to
 * actual over/under.
 */
export function PlannedExpensesCard({ budgets, fixedExpenses, yearMonth }: Props) {
  const plannedTotal =
    budgets.reduce((s, b) => s + b.effective_amount, 0) +
    fixedExpenses.reduce((s, f) => s + f.amount, 0);

  const fractionElapsed = monthElapsedFraction(yearMonth);
  // Only show the pace tick mid-month; at 0 (future) or 1 (past) it's noise.
  const showPaceMarker = fractionElapsed > 0 && fractionElapsed < 1;

  const isEmpty = budgets.length === 0 && fixedExpenses.length === 0;

  const unpaidFx = fixedExpenses
    .filter((f) => !f.paid)
    .sort((a, b) => b.amount - a.amount);
  const paidFx = fixedExpenses
    .filter((f) => f.paid)
    .sort((a, b) => b.amount - a.amount);
  const unpaidTotal = unpaidFx.reduce((s, f) => s + f.amount, 0);
  const paidTotal = paidFx.reduce((s, f) => s + f.amount, 0);

  // One shared width for every single-amount figure in this card so their
  // currency symbols and digits line up into a tidy column.
  const amountWidthCh = maxCurrencyNumberWidth([
    plannedTotal,
    unpaidTotal,
    paidTotal,
    ...fixedExpenses.map((f) => f.amount),
  ]);

  return (
    <Card>
      <CardHeader>
        <CardTitle>Planned Expenses</CardTitle>
      </CardHeader>
      <CardContent>
        {isEmpty ? (
          <EmptyState
            title="Nothing planned this month"
            description="Add a budget or a fixed expense to plan your spending."
          />
        ) : (
          <div className="flex flex-col gap-4">
            <div className="flex items-baseline justify-between">
              <span className="text-sm text-[var(--color-muted-foreground)]">
                Total planned
              </span>
              <AmountColumn
                minorUnits={plannedTotal}
                numberWidthCh={amountWidthCh}
                className="text-nowrap text-sm font-semibold"
              />
            </div>

            {budgets.length > 0 && (
              <div className="flex flex-col gap-2.5">
                <p className="text-xs font-medium uppercase tracking-wide text-[var(--color-muted-foreground)]">
                  Budgets
                </p>
                {budgets.map((b) => {
                  const overspent = b.remaining < 0;
                  const pct =
                    b.effective_amount > 0
                      ? Math.min(100, Math.max(0, (b.spent / b.effective_amount) * 100))
                      : b.spent > 0
                        ? 100
                        : 0;
                  // Color by projected month-end pace when we can project;
                  // otherwise fall back to whether it's actually over.
                  const canProject = fractionElapsed > 0 && b.effective_amount > 0;
                  const projectedOver = canProject
                    ? b.spent / fractionElapsed > b.effective_amount
                    : overspent;
                  return (
                    <div key={b.budget_id} className="flex flex-col gap-1">
                      <div className="flex items-center justify-between gap-2 text-sm">
                        <span className="truncate font-medium">{b.budget_name}</span>
                        <span
                          className={cn(
                            "text-nowrap text-xs",
                            overspent
                              ? "text-[var(--color-danger)]"
                              : "text-[var(--color-muted-foreground)]",
                          )}
                        >
                          {formatCurrency(b.spent)} / {formatCurrency(b.effective_amount)}
                        </span>
                      </div>
                      <div className="relative h-1.5 w-full overflow-hidden rounded-full bg-[var(--color-muted)]">
                        <div
                          className={cn(
                            "h-full rounded-full",
                            projectedOver
                              ? "bg-[var(--color-danger)]"
                              : "bg-[var(--color-primary)]",
                          )}
                          style={{ width: `${pct}%` }}
                        />
                        {showPaceMarker && (
                          <div
                            className="absolute inset-y-0 w-0.5 bg-[var(--color-card-foreground)]"
                            style={{ left: `${fractionElapsed * 100}%` }}
                          />
                        )}
                      </div>
                    </div>
                  );
                })}
              </div>
            )}

            {fixedExpenses.length > 0 && (
              <div className="flex flex-col gap-3">
                <p className="text-xs font-medium uppercase tracking-wide text-[var(--color-muted-foreground)]">
                  Fixed Expenses
                </p>

                {unpaidFx.length > 0 && (
                  <div className="flex flex-col gap-1.5">
                    <div className="flex items-center justify-between gap-2">
                      <span className="flex items-center gap-1.5 text-xs text-[var(--color-muted-foreground)]">
                        <Clock className="h-3.5 w-3.5 shrink-0" />
                        Unpaid
                      </span>
                      <AmountColumn
                        minorUnits={unpaidTotal}
                        numberWidthCh={amountWidthCh}
                        className="text-nowrap text-sm font-semibold"
                      />
                    </div>
                    {unpaidFx.map((f) => (
                      <div
                        key={f.id}
                        className="flex items-center justify-between gap-2 pl-5 text-sm text-[var(--color-muted-foreground)]"
                      >
                        <span className="truncate">{f.name}</span>
                        <AmountColumn
                          minorUnits={f.amount}
                          numberWidthCh={amountWidthCh}
                          className="text-nowrap"
                        />
                      </div>
                    ))}
                  </div>
                )}

                {paidFx.length > 0 && (
                  <div className="flex flex-col gap-1.5">
                    <div className="flex items-center justify-between gap-2">
                      <span className="flex items-center gap-1.5 text-xs text-[var(--color-success)]">
                        <CheckCircle2 className="h-3.5 w-3.5 shrink-0" />
                        Paid
                      </span>
                      <AmountColumn
                        minorUnits={paidTotal}
                        numberWidthCh={amountWidthCh}
                        className="text-nowrap text-sm font-semibold text-[var(--color-success)]"
                      />
                    </div>
                    {paidFx.map((f) => (
                      <div
                        key={f.id}
                        className="flex items-center justify-between gap-2 pl-5 text-sm"
                      >
                        <span className="truncate font-medium">{f.name}</span>
                        <AmountColumn
                          minorUnits={f.amount}
                          numberWidthCh={amountWidthCh}
                          className="text-nowrap"
                        />
                      </div>
                    ))}
                  </div>
                )}
              </div>
            )}
          </div>
        )}
      </CardContent>
    </Card>
  );
}
