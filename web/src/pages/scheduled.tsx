import { useState } from "react";
import { Plus } from "lucide-react";
import {
  useScheduledTransactions,
  setScheduledActive,
  deleteScheduledTransaction,
  type ScheduledTransactionWithAccount,
} from "@/lib/hooks/use-scheduled-transactions";
import { useTransactions } from "@/lib/hooks/use-transactions";
import { ScheduledCard } from "@/components/scheduled/scheduled-card";
import { ScheduledForm } from "@/components/scheduled/scheduled-form";
import { TransactionRow } from "@/components/transactions/transaction-row";
import { Card, CardContent } from "@/components/ui/card";
import { Button } from "@/components/ui/button";
import { CenteredSpinner, EmptyState } from "@/components/ui/misc";

export default function ScheduledPage() {
  const { scheduled, loading, refetch } = useScheduledTransactions();
  const {
    transactions: pending,
    loading: pendingLoading,
    refetch: refetchPending,
  } = useTransactions({ statuses: ["pending"] });

  const [formOpen, setFormOpen] = useState(false);
  const [editTarget, setEditTarget] =
    useState<ScheduledTransactionWithAccount | null>(null);

  function openCreate() {
    setEditTarget(null);
    setFormOpen(true);
  }

  function openEdit(item: ScheduledTransactionWithAccount) {
    setEditTarget(item);
    setFormOpen(true);
  }

  async function handleToggle(item: ScheduledTransactionWithAccount) {
    await setScheduledActive(item.id, !item.is_active);
    refetch();
  }

  async function handleRemove(item: ScheduledTransactionWithAccount) {
    const label = item.description?.trim() || "this scheduled transaction";
    if (
      !confirm(
        `Delete ${label}? Already-generated transactions are kept; only the schedule is removed.`,
      )
    )
      return;
    await deleteScheduledTransaction(item.id);
    refetch();
  }

  return (
    <div className="space-y-8">
      <div className="flex items-center justify-between">
        <h1 className="text-2xl font-semibold">Scheduled</h1>
        <Button onClick={openCreate}>
          <Plus className="h-4 w-4" />
          Add scheduled
        </Button>
      </div>

      {/* Scheduled transactions */}
      <section className="space-y-3">
        {loading ? (
          <CenteredSpinner />
        ) : scheduled.length === 0 ? (
          <EmptyState
            title="No scheduled transactions"
            description="Schedule a recurring income or expense and it will create a pending transaction each month for you to confirm."
            action={<Button onClick={openCreate}>Add scheduled</Button>}
          />
        ) : (
          <div className="grid grid-cols-1 gap-3 sm:grid-cols-2">
            {scheduled.map((item) => (
              <ScheduledCard
                key={item.id}
                scheduled={item}
                onEdit={() => openEdit(item)}
                onToggleActive={() => handleToggle(item)}
                onRemove={() => handleRemove(item)}
              />
            ))}
          </div>
        )}
      </section>

      {/* Pending — awaiting confirmation */}
      <section className="space-y-3">
        <h2 className="text-lg font-semibold">Pending</h2>
        {pendingLoading ? (
          <CenteredSpinner />
        ) : pending.length === 0 ? (
          <EmptyState
            title="Nothing pending"
            description="Generated transactions awaiting your confirmation will appear here."
          />
        ) : (
          <Card>
            <CardContent className="flex flex-col gap-1 p-2">
              {pending.map((txn) => (
                <TransactionRow
                  key={txn.id}
                  txn={txn}
                  onMutated={refetchPending}
                />
              ))}
            </CardContent>
          </Card>
        )}
      </section>

      <ScheduledForm
        open={formOpen}
        onOpenChange={setFormOpen}
        scheduled={editTarget}
        onSaved={refetch}
      />
    </div>
  );
}
