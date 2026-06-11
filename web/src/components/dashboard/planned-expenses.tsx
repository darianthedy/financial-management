import { CheckCircle2, Clock } from "lucide-react";
import { Card, CardContent, CardHeader, CardTitle } from "@/components/ui/card";
import { EmptyState } from "@/components/ui/misc";
import { formatCurrency } from "@/lib/utils/currency";
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
              <span className="text-nowrap font-semibold">
                {formatCurrency(plannedTotal)}
              </span>
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
              <div className="flex flex-col gap-2">
                <p className="text-xs font-medium uppercase tracking-wide text-[var(--color-muted-foreground)]">
                  Fixed Expenses
                </p>
                {[...fixedExpenses]
                  .sort((a, b) => {
                    if (a.paid !== b.paid) return a.paid ? -1 : 1;
                    return b.amount - a.amount;
                  })
                  .map((f) => (
                    <div
                      key={f.id}
                      className="flex items-center justify-between gap-2 text-sm"
                    >
                      <span className="flex min-w-0 items-center gap-2">
                        {f.paid ? (
                          <CheckCircle2 className="h-3.5 w-3.5 shrink-0 text-[var(--color-success)]" />
                        ) : (
                          <Clock className="h-3.5 w-3.5 shrink-0 text-[var(--color-muted-foreground)]" />
                        )}
                        <span
                          className={cn(
                            "truncate font-medium",
                            !f.paid && "text-[var(--color-muted-foreground)]",
                          )}
                        >
                          {f.name}
                        </span>
                      </span>
                      <span className="text-nowrap font-semibold">
                        {formatCurrency(f.amount)}
                      </span>
                    </div>
                  ))}
              </div>
            )}
          </div>
        )}
      </CardContent>
    </Card>
  );
}
