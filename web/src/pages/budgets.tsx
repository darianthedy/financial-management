import { useState } from "react";
import { Plus, ChevronLeft, ChevronRight, CopyPlus } from "lucide-react";
import {
  useBudgets,
  deleteBudget,
  copyFromPreviousMonth,
} from "@/lib/hooks/use-budgets";
import { BudgetCard } from "@/components/budgets/budget-card";
import { BudgetForm } from "@/components/budgets/budget-form";
import { InstallmentList } from "@/components/budgets/installment-list";
import { Button } from "@/components/ui/button";
import { CenteredSpinner, EmptyState } from "@/components/ui/misc";
import {
  getCurrentYearMonth,
  navigateMonth,
  formatYearMonth,
} from "@/lib/utils/date";
import type { BudgetProgress } from "@/lib/types/database";

export default function BudgetsPage() {
  const [yearMonth, setYearMonth] = useState(getCurrentYearMonth());
  const { budgets, loading, refetch } = useBudgets(yearMonth);
  const [formOpen, setFormOpen] = useState(false);
  const [editTarget, setEditTarget] = useState<BudgetProgress | null>(null);
  const [copying, setCopying] = useState(false);

  function openCreate() {
    setEditTarget(null);
    setFormOpen(true);
  }

  function openEdit(budget: BudgetProgress) {
    setEditTarget(budget);
    setFormOpen(true);
  }

  async function handleRemove(budget: BudgetProgress) {
    if (
      !confirm(
        `Remove "${budget.budget_name}" for ${formatYearMonth(yearMonth)}? This month's row is deleted; other months are unaffected.`,
      )
    )
      return;
    await deleteBudget(budget.budget_id);
    refetch();
  }

  async function handleCopy() {
    setCopying(true);
    try {
      const count = await copyFromPreviousMonth(yearMonth);
      refetch();
      if (count === 0) {
        alert(
          `Nothing to copy — the previous month has no budgets that aren't already in ${formatYearMonth(yearMonth)}.`,
        );
      }
    } catch (e) {
      alert(e instanceof Error ? e.message : "Failed to copy budgets");
    } finally {
      setCopying(false);
    }
  }

  return (
    <div className="space-y-6">
      <div className="flex flex-wrap items-center justify-between gap-2">
        <h1 className="text-2xl font-semibold">Budgets</h1>
        <div className="flex flex-wrap items-center justify-end gap-2">
          <Button variant="outline" onClick={handleCopy} disabled={copying}>
            <CopyPlus className="h-4 w-4" />
            {copying ? "Copying…" : "Copy previous month"}
          </Button>
          <Button onClick={openCreate}>
            <Plus className="h-4 w-4" />
            Add budget
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
      ) : budgets.length === 0 ? (
        <EmptyState
          title="No budgets this month"
          description="Add a budget to track spending against a monthly target, or copy this month's set from the previous month."
          action={
            <div className="flex gap-2">
              <Button variant="outline" onClick={handleCopy} disabled={copying}>
                Copy previous month
              </Button>
              <Button onClick={openCreate}>Add budget</Button>
            </div>
          }
        />
      ) : (
        <div className="grid grid-cols-1 gap-3 sm:grid-cols-2">
          {budgets.map((budget) => (
            <BudgetCard
              key={budget.budget_id}
              budget={budget}
              onEdit={() => openEdit(budget)}
              onRemove={() => handleRemove(budget)}
            />
          ))}
        </div>
      )}

      <InstallmentList />

      <BudgetForm
        open={formOpen}
        onOpenChange={setFormOpen}
        yearMonth={yearMonth}
        budget={editTarget}
        onSaved={refetch}
      />
    </div>
  );
}
