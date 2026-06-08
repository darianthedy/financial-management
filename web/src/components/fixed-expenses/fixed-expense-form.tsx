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
import { CurrencyAmountInput } from "@/components/shared/currency-amount-input";
import {
  fixedExpenseFormSchema,
  type FixedExpenseFormValues,
} from "@/lib/validations/fixed-expense";
import {
  createFixedExpense,
  updateFixedExpense,
} from "@/lib/hooks/use-fixed-expenses";
import type { FixedExpense } from "@/lib/types/database";
import { toDisplayAmount, currencyDecimals } from "@/lib/utils/currency";
import { useCurrencies } from "@/lib/hooks/use-currencies";
import { formatYearMonth } from "@/lib/utils/date";

interface Props {
  open: boolean;
  onOpenChange: (open: boolean) => void;
  /** Month this fixed expense belongs to (`YYYY-MM`). For edits this matches the row. */
  yearMonth: string;
  fixedExpense?: FixedExpense | null;
  onSaved?: (fixedExpenseId?: string) => void;
}

export function FixedExpenseForm({
  open,
  onOpenChange,
  yearMonth,
  fixedExpense,
  onSaved,
}: Props) {
  const { defaultCurrency, decimalsFor } = useCurrencies();
  const [submitError, setSubmitError] = useState("");
  const isEdit = !!fixedExpense;

  const {
    register,
    handleSubmit,
    reset,
    watch,
    setValue,
    formState: { errors, isSubmitting },
  } = useForm<FixedExpenseFormValues>({
    resolver: zodResolver(fixedExpenseFormSchema),
    defaultValues: { name: "", amount: 0, due_day: 1 },
  });

  useEffect(() => {
    if (!open) return;
    reset(
      fixedExpense
        ? {
            name: fixedExpense.name,
            amount: toDisplayAmount(
              fixedExpense.amount,
              currencyDecimals(defaultCurrency),
            ),
            due_day: fixedExpense.due_day,
          }
        : { name: "", amount: 0, due_day: 1 },
    );
    setSubmitError("");
  }, [open, fixedExpense, defaultCurrency, reset]);

  async function onSubmit(values: FixedExpenseFormValues) {
    try {
      const decimals = decimalsFor(defaultCurrency);
      if (fixedExpense) {
        await updateFixedExpense(fixedExpense.id, values, decimals);
        onOpenChange(false);
        onSaved?.(fixedExpense.id);
      } else {
        const id = await createFixedExpense(values, yearMonth, decimals);
        onOpenChange(false);
        onSaved?.(id);
      }
    } catch (e) {
      setSubmitError(
        e instanceof Error ? e.message : "Failed to save fixed expense",
      );
    }
  }

  return (
    <Dialog open={open} onOpenChange={onOpenChange}>
      <DialogContent>
        <DialogHeader>
          <DialogTitle>
            {isEdit ? "Edit fixed expense" : "New fixed expense"} ·{" "}
            {formatYearMonth(yearMonth)}
          </DialogTitle>
        </DialogHeader>
        <form onSubmit={handleSubmit(onSubmit)} className="flex flex-col gap-4">
          <div className="flex flex-col gap-1.5">
            <Label htmlFor="name">Name</Label>
            <Input id="name" placeholder="Rent, Netflix…" {...register("name")} />
            <FieldError message={errors.name?.message} />
          </div>

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
              <Label htmlFor="due_day">Due day</Label>
              <Input
                id="due_day"
                type="number"
                min={1}
                max={31}
                {...register("due_day", { valueAsNumber: true })}
              />
              <FieldError message={errors.due_day?.message} />
            </div>
          </div>

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
