import { CheckCircle2, AlertTriangle } from "lucide-react";
import { Card, CardContent } from "@/components/ui/card";
import { formatCurrency } from "@/lib/utils/currency";
import { cn } from "@/lib/utils/cn";
import type { BudgetProgress } from "@/lib/types/database";

interface Props {
  budgets: BudgetProgress[];
}

/**
 * The at-a-glance answer to "am I overspending?". Aggregates every budget for
 * the selected month: how many are over and by how much in total. Sits at the
 * very top of the dashboard, color-coded green (on track) or red (over).
 */
export function VerdictBanner({ budgets }: Props) {
  // No budgets at all -> nothing to judge against, so don't show a verdict.
  if (budgets.length === 0) return null;

  const overspent = budgets.filter((b) => b.remaining < 0);
  const count = overspent.length;
  const overage = overspent.reduce((sum, b) => sum + Math.abs(b.remaining), 0);
  const onTrack = count === 0;

  return (
    <Card
      className={cn(
        "border-l-4",
        onTrack
          ? "border-l-[var(--color-success)]"
          : "border-l-[var(--color-danger)]",
      )}
    >
      <CardContent className="flex items-center gap-3 p-4">
        {onTrack ? (
          <CheckCircle2 className="h-6 w-6 shrink-0 text-[var(--color-success)]" />
        ) : (
          <AlertTriangle className="h-6 w-6 shrink-0 text-[var(--color-danger)]" />
        )}
        <div className="min-w-0">
          <p
            className={cn(
              "text-base font-semibold",
              onTrack
                ? "text-[var(--color-success)]"
                : "text-[var(--color-danger)]",
            )}
          >
            {onTrack
              ? "On track"
              : `Overspending in ${count} budget${count === 1 ? "" : "s"} (−${formatCurrency(overage)})`}
          </p>
          <p className="text-sm text-[var(--color-muted-foreground)]">
            {onTrack
              ? `All ${budgets.length} budget${budgets.length === 1 ? "" : "s"} within target.`
              : `${formatCurrency(overage)} over budget across the month.`}
          </p>
        </div>
      </CardContent>
    </Card>
  );
}
