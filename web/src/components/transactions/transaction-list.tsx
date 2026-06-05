import { useEffect } from "react";
import { useNavigate } from "react-router-dom";
import { Plus } from "lucide-react";
import {
  useTransactions,
  type TransactionFilters,
} from "@/lib/hooks/use-transactions";
import { TransactionRow } from "./transaction-row";
import { Button } from "@/components/ui/button";
import { CenteredSpinner, EmptyState } from "@/components/ui/misc";

interface Props {
  accountId?: string;
  filters?: Omit<TransactionFilters, "accountId">;
  /** When true the "Add transaction" button links to /transactions/new with an account pre-selected. */
  showAddButton?: boolean;
  /** Hide the list's own "Transactions" heading (e.g. when the page already has one). */
  hideHeader?: boolean;
  /** Notified with the number of matching rows after each load. */
  onResult?: (count: number) => void;
  onMutated?: () => void;
}

export function TransactionList({
  accountId,
  filters = {},
  showAddButton = true,
  hideHeader = false,
  onResult,
  onMutated,
}: Props) {
  const navigate = useNavigate();
  const { transactions, loading, refetch } = useTransactions({
    accountId,
    ...filters,
  });

  useEffect(() => {
    if (!loading) onResult?.(transactions.length);
  }, [loading, transactions.length, onResult]);

  function handleMutated() {
    refetch();
    onMutated?.();
  }

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
              onClick={() =>
                navigate(
                  accountId
                    ? `/transactions/new?accountId=${accountId}`
                    : "/transactions/new",
                )
              }
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
            <TransactionRow key={txn.id} txn={txn} onMutated={handleMutated} />
          ))}
        </div>
      )}
    </div>
  );
}
