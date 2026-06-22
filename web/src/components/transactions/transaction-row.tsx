import { useState } from "react";
import { useNavigate } from "react-router-dom";
import {
  Check,
  X,
  MoreVertical,
  Pencil,
  Trash2,
  Clock,
  LayoutGrid,
} from "lucide-react";
import * as DropdownMenu from "@radix-ui/react-dropdown-menu";
import { cn } from "@/lib/utils/cn";
import { formatDate } from "@/lib/utils/date";
import { AmountColumn } from "@/components/shared/amount-column";
import { Button } from "@/components/ui/button";
import {
  AccountAvatar,
  TransactionChips,
  amountColor as amountColorFor,
  deriveTitle,
} from "./transaction-display";
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
import { isTransactionSpread } from "@/lib/hooks/use-installments";
import { CreateInstallmentDialog } from "@/components/transactions/installment-dialog";

interface Props {
  txn: TransactionWithRelations;
  /** Widest amount's numeric body so amounts align across the list. */
  widestAmount?: string;
  /**
   * Show the transaction's date beneath the amount. Off when the row sits under a
   * date group header (the transactions list) that already carries the date; on
   * for ungrouped lists like the scheduled page.
   */
  showDate?: boolean;
  onMutated?: () => void;
}

export function TransactionRow({
  txn,
  widestAmount,
  showDate = true,
  onMutated,
}: Props) {
  const navigate = useNavigate();
  const [confirmOpen, setConfirmOpen] = useState(false);
  const [deleting, setDeleting] = useState(false);
  const [installOpen, setInstallOpen] = useState(false);
  // Whether this expense is already spread across budgets. Seeded from the row's
  // `hasInstallment` flag (so the "Create virtual installment" item can hide
  // immediately — a second spread is rejected by the RPC anyway); otherwise
  // looked up lazily the first time the actions menu opens. `null` means not yet
  // checked.
  const [isSpread, setIsSpread] = useState<boolean | null>(
    txn.hasInstallment ? true : null,
  );

  const isPending = txn.status === "pending";

  const amountColor = amountColorFor(txn.type);

  const { title, usedCategoryId, usedFixedExpense, titleIsDescription } =
    deriveTitle(txn);
  const subtitle = titleIsDescription ? null : txn.description;
  const accountName = txn.accounts?.name ?? "?";

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

  // Spreading is expense-only. Check the already-spread status the first time
  // the menu opens so the option can be hidden for expenses already spread.
  function handleMenuOpenChange(open: boolean) {
    if (open && txn.type === "expense" && isSpread === null) {
      isTransactionSpread(txn.id)
        .then(setIsSpread)
        .catch(() => setIsSpread(false));
    }
  }

  const canSpread = txn.type === "expense" && isSpread !== true;

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
      <AccountAvatar
        name={accountName}
        type={txn.type}
        imageUrl={txn.accounts?.image_url}
      />

      <div className="flex min-w-0 flex-1 flex-col gap-0.5">
        <div className="flex items-center gap-2">
          <span className="truncate text-sm font-semibold">{title}</span>
          {isPending && (
            <span className="inline-flex shrink-0 items-center gap-1 rounded-full border border-[color-mix(in_srgb,var(--color-warning)_40%,transparent)] bg-[color-mix(in_srgb,var(--color-warning)_14%,transparent)] px-2 py-0.5 text-[10px] font-semibold uppercase tracking-wide text-[var(--color-warning)]">
              <Clock className="h-3 w-3" />
              Pending
            </span>
          )}
          {txn.hasInstallment && (
            <LayoutGrid
              aria-label="Spread into a virtual installment"
              className="h-3.5 w-3.5 shrink-0 text-[var(--color-primary)]"
            />
          )}
        </div>
        {subtitle && (
          <span className="truncate text-xs text-[var(--color-muted-foreground)]">
            {subtitle}
          </span>
        )}
        <TransactionChips
          txn={txn}
          excludeCategoryId={usedCategoryId}
          excludeFixedExpense={usedFixedExpense}
        />
      </div>

      <div className="flex shrink-0 flex-col items-end gap-1">
        <AmountColumn
          minorUnits={txn.amount}
          widestNumber={widestAmount}
          className={cn("text-nowrap text-sm font-semibold", amountColor)}
        />
        {showDate && (
          <span className="text-xs text-[var(--color-muted-foreground)]">
            {formatDate(txn.date)}
          </span>
        )}
        {isPending && (
          <div className="flex gap-1.5 pt-0.5">
            <button
              aria-label="Confirm"
              onClick={handleConfirm}
              className="flex h-8 w-8 touch-manipulation select-none items-center justify-center rounded-full bg-[color-mix(in_srgb,var(--color-success)_15%,transparent)] text-[var(--color-success)] transition-[background-color,color,transform] duration-150 ease-out hover:bg-[var(--color-success)] hover:text-white active:scale-90 active:bg-[var(--color-success)] active:text-white focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-[var(--color-success)] focus-visible:ring-offset-2 focus-visible:ring-offset-[var(--color-muted)]"
            >
              <Check className="h-4 w-4" />
            </button>
            <button
              aria-label="Reject"
              onClick={handleDismiss}
              className="flex h-8 w-8 touch-manipulation select-none items-center justify-center rounded-full bg-[color-mix(in_srgb,var(--color-danger)_12%,transparent)] text-[var(--color-danger)] transition-[background-color,color,transform] duration-150 ease-out hover:bg-[var(--color-danger)] hover:text-white active:scale-90 active:bg-[var(--color-danger)] active:text-white focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-[var(--color-danger)] focus-visible:ring-offset-2 focus-visible:ring-offset-[var(--color-muted)]"
            >
              <X className="h-4 w-4" />
            </button>
          </div>
        )}
      </div>

      <DropdownMenu.Root onOpenChange={handleMenuOpenChange}>
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
            {canSpread && (
              <DropdownMenu.Item
                className="flex cursor-pointer items-center gap-2 rounded-sm px-3 py-2 text-sm outline-none data-[highlighted]:bg-[var(--color-muted)]"
                onSelect={() => setInstallOpen(true)}
              >
                <LayoutGrid className="h-4 w-4" /> Create virtual installment
              </DropdownMenu.Item>
            )}
            <DropdownMenu.Item
              className="flex cursor-pointer items-center gap-2 rounded-sm px-3 py-2 text-sm text-[var(--color-danger)] outline-none data-[highlighted]:bg-[var(--color-muted)]"
              onSelect={() => setConfirmOpen(true)}
            >
              <Trash2 className="h-4 w-4" /> Delete
            </DropdownMenu.Item>
          </DropdownMenu.Content>
        </DropdownMenu.Portal>
      </DropdownMenu.Root>

      <CreateInstallmentDialog
        transaction={txn}
        open={installOpen}
        onOpenChange={setInstallOpen}
        onSaved={() => {
          setIsSpread(true);
          onMutated?.();
        }}
      />

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
