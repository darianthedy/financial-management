import { useState } from "react";
import { useNavigate } from "react-router-dom";
import {
  ArrowDownLeft,
  ArrowUpRight,
  ArrowLeftRight,
  Check,
  X,
  MoreVertical,
  Pencil,
  Trash2,
} from "lucide-react";
import * as DropdownMenu from "@radix-ui/react-dropdown-menu";
import { cn } from "@/lib/utils/cn";
import { formatCurrency } from "@/lib/utils/currency";
import { formatDate } from "@/lib/utils/date";
import { Badge } from "@/components/ui/misc";
import { Button } from "@/components/ui/button";
import {
  Dialog,
  DialogContent,
  DialogFooter,
  DialogHeader,
  DialogTitle,
} from "@/components/ui/dialog";
import {
  confirmTransaction,
  dismissTransaction,
  deleteTransaction,
  type TransactionWithRelations,
} from "@/lib/hooks/use-transactions";

interface Props {
  txn: TransactionWithRelations;
  onMutated?: () => void;
}

export function TransactionRow({ txn, onMutated }: Props) {
  const navigate = useNavigate();
  const [confirmOpen, setConfirmOpen] = useState(false);
  const [deleting, setDeleting] = useState(false);

  const isIncome = txn.type === "income";
  const isTransfer = txn.type === "transfer";
  const isPending = txn.status === "pending";

  const Icon = isTransfer
    ? ArrowLeftRight
    : isIncome
      ? ArrowDownLeft
      : ArrowUpRight;

  const iconColor = isTransfer
    ? "text-[var(--color-muted-foreground)]"
    : isIncome
      ? "text-[var(--color-success)]"
      : "text-[var(--color-danger)]";

  const amountColor = isTransfer
    ? "text-[var(--color-foreground)]"
    : isIncome
      ? "text-[var(--color-success)]"
      : "text-[var(--color-danger)]";

  const displayAmount = formatCurrency(txn.amount);

  const accountLabel = isTransfer
    ? `${txn.accounts?.name ?? "?"} → ${txn.transfer_accounts?.name ?? "?"}`
    : txn.accounts?.name ?? "—";

  async function handleConfirm(e: React.MouseEvent) {
    e.stopPropagation();
    await confirmTransaction(txn.id);
    onMutated?.();
  }

  async function handleDismiss(e: React.MouseEvent) {
    e.stopPropagation();
    await dismissTransaction(txn.id);
    onMutated?.();
  }

  function goToEdit() {
    navigate(`/transactions/${txn.id}/edit`);
  }

  async function handleDelete() {
    setDeleting(true);
    try {
      await deleteTransaction(txn.id);
      setConfirmOpen(false);
      onMutated?.();
    } finally {
      setDeleting(false);
    }
  }

  return (
    <div
      role="button"
      tabIndex={0}
      onClick={goToEdit}
      onKeyDown={(e) => {
        if (e.key === "Enter" || e.key === " ") {
          e.preventDefault();
          goToEdit();
        }
      }}
      className={cn(
        "flex cursor-pointer items-center gap-3 rounded-[var(--radius)] px-3 py-3 transition-colors",
        isPending ? "bg-[var(--color-muted)]" : "hover:bg-[var(--color-muted)]",
      )}
    >
      <div
        className={cn(
          "flex h-9 w-9 shrink-0 items-center justify-center rounded-full bg-[var(--color-muted)]",
        )}
      >
        <Icon className={cn("h-4 w-4", iconColor)} />
      </div>

      <div className="flex min-w-0 flex-1 flex-col gap-0.5">
        <span className="truncate text-sm font-medium">
          {txn.description || (isTransfer ? "Transfer" : txn.type)}
        </span>
        <span className="truncate text-xs text-[var(--color-muted-foreground)]">
          {accountLabel}
        </span>
        {txn.categories.length > 0 && (
          <div className="flex flex-wrap gap-1 pt-0.5">
            {txn.categories.map((c) => (
              <Badge
                key={c.id}
                style={c.color ? { borderColor: c.color, color: c.color } : undefined}
              >
                {c.icon} {c.name}
              </Badge>
            ))}
          </div>
        )}
      </div>

      <div className="flex shrink-0 flex-col items-end gap-1">
        <span className={cn("text-nowrap text-sm font-semibold", amountColor)}>
          {displayAmount}
        </span>
        <span className="text-xs text-[var(--color-muted-foreground)]">
          {formatDate(txn.date)}
        </span>
        {isPending && (
          <div className="flex gap-1">
            <Button size="sm" variant="secondary" className="h-6 px-2 text-xs" onClick={handleConfirm}>
              <Check className="h-3 w-3" /> Confirm
            </Button>
            <Button size="sm" variant="outline" className="h-6 px-2 text-xs" onClick={handleDismiss}>
              <X className="h-3 w-3" />
            </Button>
          </div>
        )}
      </div>

      <DropdownMenu.Root>
        <DropdownMenu.Trigger
          className="rounded p-1 hover:bg-[var(--color-card)]"
          onClick={(e) => e.stopPropagation()}
          aria-label="Transaction actions"
        >
          <MoreVertical className="h-4 w-4 text-[var(--color-muted-foreground)]" />
        </DropdownMenu.Trigger>
        <DropdownMenu.Portal>
          <DropdownMenu.Content
            sideOffset={4}
            align="end"
            onClick={(e) => e.stopPropagation()}
            className="z-50 min-w-36 rounded-[var(--radius)] border border-[var(--color-border)] bg-[var(--color-card)] p-1 shadow-md"
          >
            <DropdownMenu.Item
              className="flex cursor-pointer items-center gap-2 rounded-sm px-3 py-2 text-sm outline-none data-[highlighted]:bg-[var(--color-muted)]"
              onSelect={goToEdit}
            >
              <Pencil className="h-4 w-4" /> Edit
            </DropdownMenu.Item>
            <DropdownMenu.Item
              className="flex cursor-pointer items-center gap-2 rounded-sm px-3 py-2 text-sm text-[var(--color-danger)] outline-none data-[highlighted]:bg-[var(--color-muted)]"
              onSelect={() => setConfirmOpen(true)}
            >
              <Trash2 className="h-4 w-4" /> Delete
            </DropdownMenu.Item>
          </DropdownMenu.Content>
        </DropdownMenu.Portal>
      </DropdownMenu.Root>

      <Dialog open={confirmOpen} onOpenChange={setConfirmOpen}>
        <DialogContent
          onClick={(e) => e.stopPropagation()}
          onKeyDown={(e) => e.stopPropagation()}
        >
          <DialogHeader>
            <DialogTitle>Delete transaction?</DialogTitle>
          </DialogHeader>
          <p className="text-sm text-[var(--color-muted-foreground)]">
            This permanently removes the transaction and updates the affected
            account balances. This can't be undone.
          </p>
          <DialogFooter>
            <Button
              variant="outline"
              onClick={() => setConfirmOpen(false)}
              disabled={deleting}
            >
              Cancel
            </Button>
            <Button
              variant="danger"
              onClick={handleDelete}
              disabled={deleting}
            >
              {deleting ? "Deleting…" : "Delete"}
            </Button>
          </DialogFooter>
        </DialogContent>
      </Dialog>
    </div>
  );
}
