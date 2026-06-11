import { useMemo, useState } from "react";
import { Plus, ChevronLeft, ChevronRight, CopyPlus } from "lucide-react";
import {
  useFixedExpenses,
  deleteFixedExpense,
  copyFromPreviousMonth,
  type FixedExpenseWithStatus,
} from "@/lib/hooks/use-fixed-expenses";
import { FixedExpenseRow } from "@/components/fixed-expenses/fixed-expense-row";
import { FixedExpenseForm } from "@/components/fixed-expenses/fixed-expense-form";
import { Button } from "@/components/ui/button";
import { CenteredSpinner, EmptyState } from "@/components/ui/misc";
import { formatCurrency } from "@/lib/utils/currency";
import {
  getCurrentYearMonth,
  navigateMonth,
  formatYearMonth,
} from "@/lib/utils/date";

export default function FixedExpensesPage() {
  const [yearMonth, setYearMonth] = useState(getCurrentYearMonth());
  const { fixedExpenses, loading, refetch } = useFixedExpenses(yearMonth);
  const [formOpen, setFormOpen] = useState(false);
  const [editTarget, setEditTarget] = useState<FixedExpenseWithStatus | null>(
    null,
  );
  const [copying, setCopying] = useState(false);

  // Split into unpaid / paid, each sorted highest amount to lowest, with totals.
  const { unpaid, paid, unpaidTotal, paidTotal } = useMemo(() => {
    const byAmountDesc = (a: FixedExpenseWithStatus, b: FixedExpenseWithStatus) =>
      b.amount - a.amount;
    const unpaid = fixedExpenses.filter((fe) => !fe.paid).sort(byAmountDesc);
    const paid = fixedExpenses.filter((fe) => fe.paid).sort(byAmountDesc);
    const sum = (list: FixedExpenseWithStatus[]) =>
      list.reduce((total, fe) => total + fe.amount, 0);
    return {
      unpaid,
      paid,
      unpaidTotal: sum(unpaid),
      paidTotal: sum(paid),
    };
  }, [fixedExpenses]);

  function openCreate() {
    setEditTarget(null);
    setFormOpen(true);
  }

  function openEdit(fixedExpense: FixedExpenseWithStatus) {
    setEditTarget(fixedExpense);
    setFormOpen(true);
  }

  async function handleRemove(fixedExpense: FixedExpenseWithStatus) {
    if (
      !confirm(
        `Delete "${fixedExpense.name}" for ${formatYearMonth(yearMonth)}? This month's entry is removed; other months are unaffected.`,
      )
    )
      return;
    await deleteFixedExpense(fixedExpense.id);
    refetch();
  }

  async function handleCopy() {
    setCopying(true);
    try {
      const count = await copyFromPreviousMonth(yearMonth);
      refetch();
      if (count === 0) {
        alert(
          `Nothing to copy — the previous month has no fixed expenses that aren't already in ${formatYearMonth(yearMonth)}.`,
        );
      }
    } catch (e) {
      alert(e instanceof Error ? e.message : "Failed to copy fixed expenses");
    } finally {
      setCopying(false);
    }
  }

  return (
    <div className="space-y-6">
      <div className="flex items-center justify-between gap-2">
        <h1 className="text-2xl font-semibold">Fixed Expenses</h1>
        <div className="flex items-center gap-2">
          <Button variant="outline" onClick={handleCopy} disabled={copying}>
            <CopyPlus className="h-4 w-4" />
            {copying ? "Copying…" : "Copy previous month"}
          </Button>
          <Button onClick={openCreate}>
            <Plus className="h-4 w-4" />
            Add
          </Button>
        </div>
      </div>

      <div className="flex items-center justify-center gap-2">
        <Button
          variant="ghost"
          size="icon"
          onClick={() => setYearMonth((ym) => navigateMonth(ym, -1))}
        >
          <ChevronLeft className="h-4 w-4" />
        </Button>
        <span className="min-w-32 text-center text-sm font-medium">
          {formatYearMonth(yearMonth)}
        </span>
        <Button
          variant="ghost"
          size="icon"
          onClick={() => setYearMonth((ym) => navigateMonth(ym, 1))}
        >
          <ChevronRight className="h-4 w-4" />
        </Button>
      </div>

      {loading ? (
        <CenteredSpinner />
      ) : fixedExpenses.length === 0 ? (
        <EmptyState
          title="No fixed expenses this month"
          description="Add a recurring expense, or copy this month's set from the previous month."
          action={
            <div className="flex gap-2">
              <Button variant="outline" onClick={handleCopy} disabled={copying}>
                Copy previous month
              </Button>
              <Button onClick={openCreate}>Add</Button>
            </div>
          }
        />
      ) : (
        <div className="space-y-6">
          {[
            { key: "unpaid", label: "Unpaid", items: unpaid, total: unpaidTotal },
            { key: "paid", label: "Paid", items: paid, total: paidTotal },
          ]
            .filter((section) => section.items.length > 0)
            .map((section) => (
              <div key={section.key} className="space-y-3">
                <div className="flex items-center justify-between gap-2 rounded-[var(--radius)] border border-[var(--color-border)] bg-[var(--color-muted)] px-4 py-2 text-sm">
                  <span className="font-medium">{section.label} total</span>
                  <span className="font-semibold">
                    {formatCurrency(section.total)}
                  </span>
                </div>
                <div className="grid grid-cols-1 gap-3 sm:grid-cols-2">
                  {section.items.map((fe) => (
                    <FixedExpenseRow
                      key={fe.id}
                      fixedExpense={fe}
                      onEdit={() => openEdit(fe)}
                      onRemove={() => handleRemove(fe)}
                    />
                  ))}
                </div>
              </div>
            ))}
        </div>
      )}

      <FixedExpenseForm
        open={formOpen}
        onOpenChange={setFormOpen}
        yearMonth={yearMonth}
        fixedExpense={editTarget}
        onSaved={refetch}
      />
    </div>
  );
}
