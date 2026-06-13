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
  budgetFormSchema,
  type BudgetFormValues,
} from "@/lib/validations/budget";
import { createBudget, updateBudget } from "@/lib/hooks/use-budgets";
import type { BudgetProgress } from "@/lib/types/database";
import { toDisplayAmount, currencyDecimals } from "@/lib/utils/currency";
import { useCurrencies } from "@/lib/hooks/use-currencies";
import { formatYearMonth } from "@/lib/utils/date";

interface Props {
  open: boolean;
  onOpenChange: (open: boolean) => void;
  /** Month this budget belongs to (`YYYY-MM`). For edits this matches the row. */
  yearMonth: string;
  budget?: BudgetProgress | null;
  onSaved?: (budgetId?: string) => void;
}

export function BudgetForm({
  open,
  onOpenChange,
  yearMonth,
  budget,
  onSaved,
}: Props) {
  const { defaultCurrency, decimalsFor } = useCurrencies();
  const [submitError, setSubmitError] = useState("");
  const isEdit = !!budget;

  const {
    register,
    handleSubmit,
    reset,
    watch,
    setValue,
    formState: { errors, isSubmitting },
  } = useForm<BudgetFormValues>({
    resolver: zodResolver(budgetFormSchema),
    defaultValues: {
      name: "",
      description: "",
      periodic_amount: 0,
    },
  });

  useEffect(() => {
    if (!open) return;
    reset(
      budget
        ? {
            name: budget.budget_name,
            description: budget.description ?? "",
            periodic_amount: toDisplayAmount(
              budget.periodic_amount,
              currencyDecimals(defaultCurrency),
            ),
          }
        : {
            name: "",
            description: "",
            periodic_amount: 0,
          },
    );
    setSubmitError("");
  }, [open, budget, defaultCurrency, reset]);

  async function onSubmit(values: BudgetFormValues) {
    try {
      const decimals = decimalsFor(defaultCurrency);
      if (budget) {
        await updateBudget(budget.budget_id, values, decimals);
        onOpenChange(false);
        onSaved?.(budget.budget_id);
      } else {
        const id = await createBudget(values, yearMonth, decimals);
        onOpenChange(false);
        onSaved?.(id);
      }
    } catch (e) {
      setSubmitError(e instanceof Error ? e.message : "Failed to save budget");
    }
  }

  return (
    <Dialog open={open} onOpenChange={onOpenChange}>
      <DialogContent>
        <DialogHeader>
          <DialogTitle>
            {isEdit ? "Edit budget" : "New budget"} · {formatYearMonth(yearMonth)}
          </DialogTitle>
        </DialogHeader>
        <form onSubmit={handleSubmit(onSubmit)} className="flex flex-col gap-4">
          <div className="flex flex-col gap-1.5">
            <Label htmlFor="name">Name</Label>
            <Input id="name" {...register("name")} />
            <FieldError message={errors.name?.message} />
          </div>

          <div className="flex flex-col gap-1.5">
            <Label htmlFor="periodic_amount">Monthly amount</Label>
            <CurrencyAmountInput
              id="periodic_amount"
              value={watch("periodic_amount")}
              decimals={decimalsFor(defaultCurrency)}
              onChange={(v) =>
                setValue("periodic_amount", v, {
                  shouldDirty: true,
                  shouldValidate: !!errors.periodic_amount,
                })
              }
            />
            <FieldError message={errors.periodic_amount?.message} />
          </div>

          <div className="flex flex-col gap-1.5">
            <Label htmlFor="description">Note</Label>
            <Input
              id="description"
              placeholder="Optional"
              {...register("description")}
            />
            <FieldError message={errors.description?.message} />
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
