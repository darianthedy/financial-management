import { Card, CardContent, CardHeader, CardTitle } from "@/components/ui/card";
import { formatCurrency } from "@/lib/utils/currency";
import { isCurrentYearMonth, monthElapsedFraction } from "@/lib/utils/date";
import { cn } from "@/lib/utils/cn";
import type { BudgetProgress } from "@/lib/types/database";

interface Props {
  budgets: BudgetProgress[];
  yearMonth: string;
}

/**
 * Pace + projected month-end. Only meaningful for the in-progress (current)
 * month: we extrapolate spend-so-far over the fraction of the month elapsed to
 * project where the month will land. For past/completed months there's nothing
 * to project, so the card hides itself.
 */
export function PaceGaugeCard({ budgets, yearMonth }: Props) {
  // Projection only makes sense for the live month.
  if (!isCurrentYearMonth(yearMonth)) return null;

  const totalEffective = budgets.reduce((s, b) => s + b.effective_amount, 0);
  const totalSpent = budgets.reduce((s, b) => s + b.spent, 0);
  const fractionElapsed = monthElapsedFraction(yearMonth);
  const monthLeftPct = Math.round((1 - fractionElapsed) * 100);
  const spentPct = totalEffective > 0 ? (totalSpent / totalEffective) * 100 : 0;

  // Guard divide-by-zero: no elapsed time or no budget basis -> can't project.
  const canProject = fractionElapsed > 0 && totalEffective > 0;
  const projected = canProject ? totalSpent / fractionElapsed : 0;
  const projectedOver = projected > totalEffective;

  return (
    <Card>
      <CardHeader>
        <CardTitle>Monthly Pace</CardTitle>
      </CardHeader>
      <CardContent className="flex flex-col gap-3">
        {totalEffective === 0 ? (
          <p className="text-sm text-[var(--color-muted-foreground)]">
            No budgets to pace against this month.
          </p>
        ) : (
          <>
            <p className="text-sm">
              You've spent{" "}
              <span className="font-semibold">{Math.round(spentPct)}%</span> of
              budget with{" "}
              <span className="font-semibold">{monthLeftPct}%</span> of the month
              left.
            </p>

            {/* Spend bar with a tick marking where linear pace "should" be. */}
            <div
              className="relative h-2.5 w-full overflow-hidden rounded-full bg-[var(--color-muted)]"
              title="Filled = spent; tick = expected pace for today"
            >
              <div
                className={cn(
                  "h-full rounded-full transition-all",
                  projectedOver
                    ? "bg-[var(--color-danger)]"
                    : "bg-[var(--color-primary)]",
                )}
                style={{ width: `${Math.min(100, spentPct)}%` }}
              />
              <div
                className="absolute inset-y-0 w-0.5 bg-[var(--color-card-foreground)]"
                style={{ left: `${Math.min(100, fractionElapsed * 100)}%` }}
              />
            </div>

            {canProject && (
              <div className="flex items-center justify-between text-sm">
                <span className="text-[var(--color-muted-foreground)]">
                  Projected month-end
                </span>
                <span
                  className={cn(
                    "text-nowrap font-semibold",
                    projectedOver
                      ? "text-[var(--color-danger)]"
                      : "text-[var(--color-success)]",
                  )}
                >
                  {formatCurrency(Math.round(projected))}
                </span>
              </div>
            )}

            <p className="text-xs text-[var(--color-muted-foreground)]">
              {!canProject
                ? `Too early in the month to project — check back in a few days.`
                : projectedOver
                  ? `At this pace you'll exceed your ${formatCurrency(totalEffective)} budget by ${formatCurrency(Math.round(projected - totalEffective))}.`
                  : `On pace to finish within your ${formatCurrency(totalEffective)} budget.`}
            </p>
          </>
        )}
      </CardContent>
    </Card>
  );
}
