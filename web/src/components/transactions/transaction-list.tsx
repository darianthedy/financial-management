import { useNavigate } from "react-router-dom";
import { Plus } from "lucide-react";
import type { TransactionWithRelations } from "@/lib/hooks/use-transactions";
import { TransactionRow } from "./transaction-row";
import { Button } from "@/components/ui/button";
import { CenteredSpinner, EmptyState } from "@/components/ui/misc";

interface Props {
  /** Rows for the current page (already filtered and windowed by the hook). */
  transactions: TransactionWithRelations[];
  loading: boolean;
  /** When true the "Add transaction" button links to /transactions/new. */
  showAddButton?: boolean;
  /** Hide the list's own "Transactions" heading (e.g. when the page already has one). */
  hideHeader?: boolean;
  /** Called after a row is confirmed/dismissed/edited/deleted so the owner can refetch. */
  onMutated?: () => void;
}

export function TransactionList({
  transactions,
  loading,
  showAddButton = true,
  hideHeader = false,
  onMutated,
}: Props) {
  const navigate = useNavigate();

  if (loading) return <CenteredSpinner />;

  return (
    <div className="space-y-1">
      {!hideHeader && (
        <div className="flex items-center justify-between pb-1">
          <h2 className="text-base font-semibold text-[var(--color-muted-foreground)]">
            Transactions
          </h2>
          {showAddButton && (
            <Button
              size="sm"
              variant="outline"
              onClick={() => navigate("/transactions/new")}
            >
              <Plus className="h-4 w-4" /> Add
            </Button>
          )}
        </div>
      )}
      {transactions.length === 0 ? (
        <EmptyState
          title="No transactions"
          description="Add your first transaction to get started."
          action={
            showAddButton ? (
              <Button onClick={() => navigate("/transactions/new")}>
                Add transaction
              </Button>
            ) : undefined
          }
        />
      ) : (
        <div className="divide-y divide-[var(--color-border)]">
          {transactions.map((txn) => (
            <TransactionRow key={txn.id} txn={txn} onMutated={onMutated} />
          ))}
        </div>
      )}
    </div>
  );
}
