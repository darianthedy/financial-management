import { useState } from "react";
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
        <div className="grid grid-cols-1 gap-3 sm:grid-cols-2">
          {fixedExpenses.map((fe) => (
            <FixedExpenseRow
              key={fe.id}
              fixedExpense={fe}
              onEdit={() => openEdit(fe)}
              onRemove={() => handleRemove(fe)}
            />
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
