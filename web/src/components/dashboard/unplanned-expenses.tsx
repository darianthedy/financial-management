import { Card, CardContent, CardHeader, CardTitle } from "@/components/ui/card";
import { EmptyState } from "@/components/ui/misc";
import { formatCurrency } from "@/lib/utils/currency";
import { useCurrencies } from "@/lib/hooks/use-currencies";
import { cn } from "@/lib/utils/cn";
import type { UnplannedCategorySpend } from "@/lib/hooks/use-dashboard";

interface Props {
  spending: UnplannedCategorySpend[];
}

/**
 * Spending this month that isn't accounted for by any budget or fixed expense —
 * the leak the "Planned Expenses" widget doesn't capture. Categorized spend is
 * listed by category; expenses with no category collapse into "Uncategorized".
 */
export function UnplannedExpensesCard({ spending }: Props) {
  const { defaultCurrency } = useCurrencies();
  const total = spending.reduce((sum, c) => sum + c.total_amount, 0);
  const top = spending.slice(0, 6);

  return (
    <Card>
      <CardHeader>
        <CardTitle>Unplanned Expenses</CardTitle>
      </CardHeader>
      <CardContent>
        {spending.length === 0 ? (
          <EmptyState
            title="Nothing unplanned"
            description="Every expense this month is covered by a budget or fixed expense."
          />
        ) : (
          <div className="flex flex-col gap-3">
            <div className="flex items-baseline justify-between">
              <span className="text-sm text-[var(--color-muted-foreground)]">
                Total unplanned
              </span>
              <span className="text-nowrap font-semibold">
                {formatCurrency(total, defaultCurrency)}
              </span>
            </div>
            <div className="flex flex-col gap-2">
              {top.map((c) => {
                const uncategorized = c.category_id === null;
                return (
                  <div
                    key={c.category_id ?? "__uncategorized__"}
                    className="flex items-center justify-between gap-2 text-sm"
                  >
                    <span className="flex min-w-0 items-center gap-2">
                      <span className="shrink-0">
                        {c.icon ?? (uncategorized ? "❓" : "📊")}
                      </span>
                      <span
                        className={cn(
                          "truncate",
                          uncategorized
                            ? "italic text-[var(--color-muted-foreground)]"
                            : "font-medium",
                        )}
                      >
                        {c.category_name}
                      </span>
                    </span>
                    <span className="text-nowrap font-semibold">
                      {formatCurrency(c.total_amount, defaultCurrency)}
                    </span>
                  </div>
                );
              })}
            </div>
          </div>
        )}
      </CardContent>
    </Card>
  );
}
