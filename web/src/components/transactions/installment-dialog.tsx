import { useCallback, useState } from "react";
import { Button } from "@/components/ui/button";
import {
  Dialog,
  DialogContent,
  DialogHeader,
  DialogTitle,
} from "@/components/ui/dialog";
import { FieldError } from "@/components/ui/input";
import {
  InstallmentBuilder,
  type InstallmentValue,
} from "@/components/transactions/installment-builder";
import { spreadExistingTransaction } from "@/lib/hooks/use-installments";
import { useCurrencies } from "@/lib/hooks/use-currencies";
import { yearMonthOf } from "@/lib/utils/date";
import type { TransactionWithRelations } from "@/lib/hooks/use-transactions";

interface Props {
  /** Existing expense to spread across budgets. */
  transaction: TransactionWithRelations;
  open: boolean;
  onOpenChange: (open: boolean) => void;
  onSaved?: () => void;
}

/**
 * Spread an already-created expense across budgets and months — the only entry
 * point for budget installments now that the option has moved out of the
 * add/edit form. Reuses the same allocation grid the form used; on confirm it
 * converts the expense via `spread_existing_transaction`, which detaches it from
 * any single budget and writes one allocation per grid cell.
 */
export function CreateInstallmentDialog({
  transaction,
  open,
  onOpenChange,
  onSaved,
}: Props) {
  const { decimalsFor, defaultCurrency } = useCurrencies();
  const decimals = decimalsFor(defaultCurrency);
  const [installment, setInstallment] = useState<InstallmentValue | null>(null);
  const [submitError, setSubmitError] = useState("");
  const [saving, setSaving] = useState(false);

  const handleInstallmentChange = useCallback(
    (v: InstallmentValue) => setInstallment(v),
    [],
  );

  async function handleSave() {
    if (!installment?.valid) {
      setSubmitError("Allocate the full amount across the budgets first.");
      return;
    }
    setSaving(true);
    setSubmitError("");
    try {
      await spreadExistingTransaction({
        transactionId: transaction.id,
        startYearMonth: installment.startYearMonth,
        months: installment.months,
        grid: installment.grid,
      });
      onOpenChange(false);
      onSaved?.();
    } catch (e) {
      setSubmitError(
        e instanceof Error ? e.message : "Failed to create installment",
      );
    } finally {
      setSaving(false);
    }
  }

  return (
    <Dialog open={open} onOpenChange={onOpenChange}>
      <DialogContent
        onClick={(e) => e.stopPropagation()}
        onKeyDown={(e) => e.stopPropagation()}
        className="max-h-[90vh] overflow-y-auto"
      >
        <DialogHeader>
          <DialogTitle>Create virtual installment</DialogTitle>
        </DialogHeader>
        <p className="text-sm text-[var(--color-muted-foreground)]">
          Reserves the amount across budgets and months. The expense is detached
          from its single budget; its category, tags, and fixed-expense link are
          unchanged.
        </p>
        <InstallmentBuilder
          amountMinor={transaction.amount}
          decimals={decimals}
          baseMonth={yearMonthOf(transaction.date)}
          onChange={handleInstallmentChange}
        />
        <FieldError message={submitError} />
        <div className="flex gap-2 pt-2">
          <Button
            type="button"
            variant="outline"
            onClick={() => onOpenChange(false)}
            disabled={saving}
            className="flex-1"
          >
            Cancel
          </Button>
          <Button
            type="button"
            onClick={handleSave}
            disabled={saving || !installment?.valid}
            className="flex-1"
          >
            {saving ? "Saving…" : "Create installment"}
          </Button>
        </div>
      </DialogContent>
    </Dialog>
  );
}
