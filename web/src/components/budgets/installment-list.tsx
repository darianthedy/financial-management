import { useState } from "react";
import { Trash2 } from "lucide-react";
import { Card, CardContent } from "@/components/ui/card";
import { Button } from "@/components/ui/button";
import {
  useInstallments,
  cancelInstallment,
  type InstallmentSummary,
} from "@/lib/hooks/use-installments";
import { formatCurrency } from "@/lib/utils/currency";
import { formatYearMonth, navigateMonth } from "@/lib/utils/date";

/** "June 2026" for one month, "June 2026 – August 2026" for a span. */
function spanLabel(it: InstallmentSummary): string {
  const start = formatYearMonth(it.startYearMonth);
  if (it.months <= 1) return start;
  const end = formatYearMonth(navigateMonth(it.startYearMonth, it.months - 1));
  return `${start} – ${end}`;
}

/**
 * Active installments under the Budgets page, each cancellable. Cancelling
 * deletes the header row (allocations cascade away), releasing the reserved
 * allowance on the listed budgets. Hidden entirely when there are none.
 */
export function InstallmentList() {
  const { installments, loading, refetch } = useInstallments();
  const [busyId, setBusyId] = useState<string | null>(null);

  async function handleCancel(it: InstallmentSummary) {
    const label = it.description?.trim() || "this installment";
    if (
      !confirm(
        `Cancel ${label}? The reserved amounts on ${it.budgetNames.join(", ")} ` +
          `will be released. The budgets themselves stay; only the reservation is removed.`,
      )
    )
      return;
    setBusyId(it.id);
    try {
      await cancelInstallment(it.id);
      refetch();
    } catch (e) {
      alert(e instanceof Error ? e.message : "Failed to cancel installment");
    } finally {
      setBusyId(null);
    }
  }

  // Keep the page uncluttered when there's nothing to show.
  if (loading || installments.length === 0) return null;

  return (
    <div className="space-y-3">
      <div className="space-y-1">
        <h2 className="text-lg font-semibold">Active installments</h2>
        <p className="text-sm text-[var(--color-muted-foreground)]">
          Expenses spread across budgets. Cancelling releases the reserved
          allowance; deleting the source transaction cancels the installment
          too.
        </p>
      </div>

      <div className="grid grid-cols-1 gap-3 sm:grid-cols-2">
        {installments.map((it) => (
          <Card key={it.id}>
            <CardContent className="flex flex-col gap-2 p-4">
              <div className="flex items-start justify-between gap-2">
                <div className="min-w-0">
                  <p className="truncate font-medium">
                    {it.description?.trim() || "Untitled expense"}
                  </p>
                  <p className="text-sm text-[var(--color-muted-foreground)]">
                    {formatCurrency(it.totalAmount)}
                  </p>
                </div>
                <Button
                  variant="ghost"
                  size="icon"
                  onClick={() => handleCancel(it)}
                  disabled={busyId === it.id}
                  aria-label="Cancel installment"
                  className="shrink-0 text-[var(--color-danger)]"
                >
                  <Trash2 className="h-4 w-4" />
                </Button>
              </div>

              <p className="text-sm">
                <span className="text-[var(--color-muted-foreground)]">
                  {spanLabel(it)}
                </span>{" "}
                · {it.months} {it.months === 1 ? "month" : "months"}
              </p>

              <div className="flex flex-wrap gap-1.5">
                {it.budgetNames.map((name) => (
                  <span
                    key={name}
                    className="rounded-full bg-[var(--color-muted)] px-2.5 py-0.5 text-xs font-medium text-[var(--color-muted-foreground)]"
                  >
                    {name}
                  </span>
                ))}
              </div>
            </CardContent>
          </Card>
        ))}
      </div>
    </div>
  );
}
