import { Link } from "react-router-dom";
import { ArrowRight } from "lucide-react";
import { Card, CardContent, CardHeader, CardTitle } from "@/components/ui/card";
import { Button } from "@/components/ui/button";
import { EmptyState } from "@/components/ui/misc";
import { formatCurrency } from "@/lib/utils/currency";
import { cn } from "@/lib/utils/cn";
import type { BudgetProgress } from "@/lib/types/database";

interface Props {
  budgets: BudgetProgress[];
}

export function BudgetProgressCard({ budgets }: Props) {
  return (
    <Card>
      <CardHeader className="flex-row items-center justify-between">
        <CardTitle>Budget Progress</CardTitle>
        <Link to="/budgets">
          <Button variant="ghost" size="sm">
            See all <ArrowRight className="ml-1 h-3 w-3" />
          </Button>
        </Link>
      </CardHeader>
      <CardContent>
        {budgets.length === 0 ? (
          <EmptyState
            title="No budgets this month"
            description="Create a budget to track spending against a monthly target."
          />
        ) : (
          <div className="flex flex-col gap-4">
            {budgets.map((b) => {
              const overspent = b.remaining < 0;
              const pct =
                b.effective_amount > 0
                  ? Math.min(
                      100,
                      Math.max(0, (b.spent / b.effective_amount) * 100),
                    )
                  : b.spent > 0
                    ? 100
                    : 0;
              return (
                <div key={b.budget_id} className="flex flex-col gap-1.5">
                  <div className="flex items-center justify-between text-sm">
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
                  <div className="h-2 w-full overflow-hidden rounded-full bg-[var(--color-muted)]">
                    <div
                      className={cn(
                        "h-full rounded-full transition-all",
                        overspent
                          ? "bg-[var(--color-danger)]"
                          : "bg-[var(--color-primary)]",
                      )}
                      style={{ width: `${pct}%` }}
                    />
                  </div>
                </div>
              );
            })}
          </div>
        )}
      </CardContent>
    </Card>
  );
}
