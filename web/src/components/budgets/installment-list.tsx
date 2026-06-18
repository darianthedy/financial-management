import { useState } from "react";
import { Link } from "react-router-dom";
import { Trash2 } from "lucide-react";
import { Card, CardContent } from "@/components/ui/card";
import { Button } from "@/components/ui/button";
import {
  Dialog,
  DialogContent,
  DialogFooter,
  DialogHeader,
  DialogTitle,
} from "@/components/ui/dialog";
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

interface Props {
  /** The month currently shown on the Budgets page, 'YYYY-MM'. */
  yearMonth: string;
}

/**
 * Active installments under the Budgets page, each cancellable. Cancelling
 * deletes the header row (allocations cascade away), releasing the reserved
 * allowance on the listed budgets. Only installments that reserve allowance in
 * the displayed month are shown; hidden entirely when none apply.
 */
export function InstallmentList({ yearMonth }: Props) {
  const { installments, loading, refetch } = useInstallments();
  // The installment pending cancellation drives the confirm dialog; null hides it.
  const [cancelTarget, setCancelTarget] = useState<InstallmentSummary | null>(
    null,
  );
  const [cancelling, setCancelling] = useState(false);
  const [cancelError, setCancelError] = useState("");

  function openCancel(it: InstallmentSummary) {
    setCancelError("");
    setCancelTarget(it);
  }

  async function confirmCancel() {
    if (!cancelTarget) return;
    setCancelling(true);
    setCancelError("");
    try {
      await cancelInstallment(cancelTarget.id);
      setCancelTarget(null);
      refetch();
    } catch (e) {
      setCancelError(
        e instanceof Error ? e.message : "Failed to cancel installment",
      );
    } finally {
      setCancelling(false);
    }
  }

  // Only installments reserving allowance in the displayed month belong here.
  const visible = installments.filter((it) =>
    it.reservedMonths.includes(yearMonth),
  );

  // Keep the page uncluttered when there's nothing to show.
  if (loading || visible.length === 0) return null;

  return (
    <div className="space-y-3">
      <h2 className="text-lg font-semibold">Active installments</h2>

      <div className="grid grid-cols-1 gap-3 sm:grid-cols-2">
        {visible.map((it) => (
          <Card key={it.id}>
            <CardContent className="flex flex-col gap-2 p-4">
              <div className="flex items-start justify-between gap-2">
                <div className="min-w-0">
                  <Link
                    to={`/transactions/${it.sourceTransactionId}/edit`}
                    className="block truncate font-medium hover:underline"
                    title="View the source transaction"
                  >
                    {it.title}
                  </Link>
                  <p className="text-sm text-[var(--color-muted-foreground)]">
                    {formatCurrency(it.totalAmount)}
                  </p>
                </div>
                <Button
                  variant="ghost"
                  size="icon"
                  onClick={() => openCancel(it)}
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

      <Dialog
        open={cancelTarget !== null}
        onOpenChange={(open) => {
          if (!open) setCancelTarget(null);
        }}
      >
        <DialogContent>
          <DialogHeader>
            <DialogTitle>Cancel installment?</DialogTitle>
          </DialogHeader>
          <p className="text-sm text-[var(--color-muted-foreground)]">
            The reserved amounts on{" "}
            <span className="font-medium text-[var(--color-foreground)]">
              {cancelTarget?.budgetNames.join(", ")}
            </span>{" "}
            will be released. The budgets themselves stay; only the reservation
            is removed. This can't be undone.
          </p>
          {cancelError && (
            <p className="text-sm text-[var(--color-danger)]">{cancelError}</p>
          )}
          <DialogFooter>
            <Button
              variant="outline"
              onClick={() => setCancelTarget(null)}
              disabled={cancelling}
            >
              Keep
            </Button>
            <Button
              variant="danger"
              onClick={confirmCancel}
              disabled={cancelling}
            >
              {cancelling ? "Cancelling…" : "Cancel installment"}
            </Button>
          </DialogFooter>
        </DialogContent>
      </Dialog>
    </div>
  );
}
