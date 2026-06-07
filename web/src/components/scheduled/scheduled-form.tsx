import { useEffect, useState } from "react";
import { useForm } from "react-hook-form";
import { zodResolver } from "@hookform/resolvers/zod";
import {
  Dialog,
  DialogContent,
  DialogFooter,
  DialogHeader,
  DialogTitle,
} from "@/components/ui/dialog";
import { Button } from "@/components/ui/button";
import { Input, Label, FieldError } from "@/components/ui/input";
import {
  Select,
  SelectContent,
  SelectItem,
  SelectTrigger,
  SelectValue,
} from "@/components/ui/select";
import { CurrencyAmountInput } from "@/components/shared/currency-amount-input";
import {
  scheduledTransactionFormSchema,
  type ScheduledTransactionFormValues,
} from "@/lib/validations/scheduled-transaction";
import {
  createScheduledTransaction,
  updateScheduledTransaction,
  type ScheduledTransactionWithAccount,
} from "@/lib/hooks/use-scheduled-transactions";
import { useAccounts } from "@/lib/hooks/use-accounts";
import { useCurrencies } from "@/lib/hooks/use-currencies";
import { toDisplayAmount, currencyDecimals } from "@/lib/utils/currency";
import { todayIso } from "@/lib/utils/date";

interface Props {
  open: boolean;
  onOpenChange: (open: boolean) => void;
  scheduled?: ScheduledTransactionWithAccount | null;
  onSaved?: () => void;
}

const TYPES = [
  { value: "income", label: "Income" },
  { value: "expense", label: "Expense" },
] as const;

export function ScheduledForm({ open, onOpenChange, scheduled, onSaved }: Props) {
  const { accounts } = useAccounts();
  const { defaultCurrency, decimalsFor } = useCurrencies();
  const [submitError, setSubmitError] = useState("");
  const isEdit = !!scheduled;

  const {
    register,
    handleSubmit,
    reset,
    watch,
    setValue,
    formState: { errors, isSubmitting },
  } = useForm<ScheduledTransactionFormValues>({
    // Cast: zodResolver's inferred type clashes with the schema defaults.
    resolver: zodResolver(scheduledTransactionFormSchema) as any,
    defaultValues: {
      account_id: "",
      type: "expense",
      amount: 0,
      description: "",
      recurrence: "monthly",
      next_due_date: todayIso(),
      is_active: true,
    },
  });

  useEffect(() => {
    if (!open) return;
    reset(
      scheduled
        ? {
            account_id: scheduled.account_id,
            type: scheduled.type === "income" ? "income" : "expense",
            amount: toDisplayAmount(
              scheduled.amount,
              currencyDecimals(defaultCurrency),
            ),
            description: scheduled.description ?? "",
            recurrence: "monthly",
            next_due_date: scheduled.next_due_date,
            is_active: scheduled.is_active,
          }
        : {
            account_id: "",
            type: "expense",
            amount: 0,
            description: "",
            recurrence: "monthly",
            next_due_date: todayIso(),
            is_active: true,
          },
    );
    setSubmitError("");
  }, [open, scheduled, defaultCurrency, reset]);

  const type = watch("type");
  const accountId = watch("account_id");
  const isActive = watch("is_active");

  async function onSubmit(values: ScheduledTransactionFormValues) {
    try {
      const decimals = decimalsFor(defaultCurrency);
      if (scheduled) {
        await updateScheduledTransaction(scheduled.id, values, decimals);
      } else {
        await createScheduledTransaction(values, decimals);
      }
      onOpenChange(false);
      onSaved?.();
    } catch (e) {
      setSubmitError(
        e instanceof Error ? e.message : "Failed to save scheduled transaction",
      );
    }
  }

  return (
    <Dialog open={open} onOpenChange={onOpenChange}>
      <DialogContent>
        <DialogHeader>
          <DialogTitle>
            {isEdit ? "Edit scheduled transaction" : "New scheduled transaction"}
          </DialogTitle>
        </DialogHeader>
        <form onSubmit={handleSubmit(onSubmit)} className="flex flex-col gap-5">
          {/* Type */}
          <div className="flex flex-col gap-1.5">
            <Label>Type</Label>
            <div className="flex gap-2">
              {TYPES.map((t) => (
                <button
                  key={t.value}
                  type="button"
                  onClick={() => setValue("type", t.value)}
                  className={`flex-1 rounded-[var(--radius)] border px-3 py-2 text-sm font-medium transition-colors ${
                    type === t.value
                      ? "border-[var(--color-primary)] bg-[var(--color-primary)] text-[var(--color-primary-foreground)]"
                      : "border-[var(--color-border)] hover:bg-[var(--color-muted)]"
                  }`}
                >
                  {t.label}
                </button>
              ))}
            </div>
          </div>

          {/* Account */}
          <div className="flex flex-col gap-1.5">
            <Label htmlFor="account_id">Account</Label>
            <Select
              value={accountId}
              onValueChange={(v) => v && setValue("account_id", v)}
            >
              <SelectTrigger id="account_id">
                <SelectValue placeholder="Select account" />
              </SelectTrigger>
              <SelectContent>
                {accounts.map((a) => (
                  <SelectItem key={a.id} value={a.id}>
                    {a.name}
                  </SelectItem>
                ))}
              </SelectContent>
            </Select>
            <FieldError message={errors.account_id?.message} />
          </div>

          {/* Amount + Next due date */}
          <div className="grid grid-cols-1 gap-3 sm:grid-cols-2">
            <div className="flex flex-col gap-1.5">
              <Label htmlFor="amount">Amount</Label>
              <CurrencyAmountInput
                id="amount"
                value={watch("amount")}
                decimals={decimalsFor(defaultCurrency)}
                onChange={(v) =>
                  setValue("amount", v, {
                    shouldDirty: true,
                    shouldValidate: !!errors.amount,
                  })
                }
              />
              <FieldError message={errors.amount?.message} />
            </div>
            <div className="flex flex-col gap-1.5">
              <Label htmlFor="next_due_date">Next due date</Label>
              <Input
                id="next_due_date"
                type="date"
                className="appearance-none block"
                {...register("next_due_date")}
              />
              <FieldError message={errors.next_due_date?.message} />
            </div>
          </div>

          {/* Recurrence (monthly only for now) */}
          <div className="flex flex-col gap-1.5">
            <Label htmlFor="recurrence">Repeats</Label>
            <Select value="monthly" disabled>
              <SelectTrigger id="recurrence">
                <SelectValue />
              </SelectTrigger>
              <SelectContent>
                <SelectItem value="monthly">Monthly</SelectItem>
              </SelectContent>
            </Select>
          </div>

          {/* Description */}
          <div className="flex flex-col gap-1.5">
            <Label htmlFor="description">Description</Label>
            <Input
              id="description"
              placeholder="Optional"
              {...register("description")}
            />
          </div>

          {/* Active */}
          <label className="flex cursor-pointer items-center gap-2 text-sm">
            <input
              type="checkbox"
              checked={isActive}
              onChange={(e) => setValue("is_active", e.target.checked)}
              className="h-4 w-4 accent-[var(--color-primary)]"
            />
            Active (generates pending transactions when due)
          </label>

          <FieldError message={submitError} />

          <DialogFooter>
            <Button
              type="button"
              variant="outline"
              onClick={() => onOpenChange(false)}
            >
              Cancel
            </Button>
            <Button type="submit" disabled={isSubmitting}>
              {isSubmitting ? "Saving…" : "Save"}
            </Button>
          </DialogFooter>
        </form>
      </DialogContent>
    </Dialog>
  );
}
