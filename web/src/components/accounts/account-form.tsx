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
import { CurrencySelect } from "@/components/shared/currency-select";
import { CurrencyAmountInput } from "@/components/shared/currency-amount-input";
import { ACCOUNT_TYPES } from "@/lib/account-types";
import {
  accountFormSchema,
  type AccountFormValues,
} from "@/lib/validations/account";
import { createAccount, updateAccount } from "@/lib/hooks/use-accounts";
import type { Account } from "@/lib/types/database";
import { toDisplayAmount } from "@/lib/utils/currency";
import { useCurrencies } from "@/lib/hooks/use-currencies";

interface Props {
  open: boolean;
  onOpenChange: (open: boolean) => void;
  account?: Account | null;
  onSaved?: () => void;
}

export function AccountForm({ open, onOpenChange, account, onSaved }: Props) {
  const { defaultCurrency, decimalsFor } = useCurrencies();
  const [submitError, setSubmitError] = useState("");
  const isEdit = !!account;

  const {
    register,
    handleSubmit,
    reset,
    watch,
    setValue,
    formState: { errors, isSubmitting },
  } = useForm<AccountFormValues>({
    resolver: zodResolver(accountFormSchema),
    defaultValues: {
      name: "",
      type: "bank_account",
      currency: defaultCurrency,
      starting_balance: 0,
    },
  });

  useEffect(() => {
    if (!open) return;
    reset(
      account
        ? {
            name: account.name,
            type: account.type,
            currency: account.currency,
            starting_balance: toDisplayAmount(account.starting_balance),
          }
        : {
            name: "",
            type: "bank_account",
            currency: defaultCurrency,
            starting_balance: 0,
          },
    );
    setSubmitError("");
  }, [open, account, defaultCurrency, reset]);

  async function onSubmit(values: AccountFormValues) {
    try {
      if (account) await updateAccount(account.id, values);
      else await createAccount(values);
      onOpenChange(false);
      onSaved?.();
    } catch (e) {
      setSubmitError(e instanceof Error ? e.message : "Failed to save account");
    }
  }

  const type = watch("type");
  const currency = watch("currency");

  return (
    <Dialog open={open} onOpenChange={onOpenChange}>
      <DialogContent>
        <DialogHeader>
          <DialogTitle>{isEdit ? "Edit account" : "New account"}</DialogTitle>
        </DialogHeader>
        <form onSubmit={handleSubmit(onSubmit)} className="flex flex-col gap-4">
          <div className="flex flex-col gap-1.5">
            <Label htmlFor="name">Name</Label>
            <Input id="name" {...register("name")} />
            <FieldError message={errors.name?.message} />
          </div>

          <div className="flex flex-col gap-1.5">
            <Label htmlFor="type">Type</Label>
            <Select
              value={type}
              onValueChange={(v) =>
                setValue("type", v as AccountFormValues["type"])
              }
            >
              <SelectTrigger id="type">
                <SelectValue />
              </SelectTrigger>
              <SelectContent>
                {ACCOUNT_TYPES.map((t) => (
                  <SelectItem key={t.value} value={t.value}>
                    {t.label}
                  </SelectItem>
                ))}
              </SelectContent>
            </Select>
          </div>

          <div className="grid grid-cols-2 gap-3">
            <div className="flex flex-col gap-1.5">
              <Label htmlFor="starting_balance">Starting balance</Label>
              <CurrencyAmountInput
                id="starting_balance"
                value={watch("starting_balance")}
                decimals={decimalsFor(currency)}
                allowNegative
                onChange={(v) =>
                  setValue("starting_balance", v, {
                    shouldDirty: true,
                    shouldValidate: !!errors.starting_balance,
                  })
                }
              />
              <FieldError message={errors.starting_balance?.message} />
            </div>
            <div className="flex flex-col gap-1.5">
              <Label htmlFor="currency">Currency</Label>
              <CurrencySelect
                id="currency"
                value={currency}
                onChange={(c) => setValue("currency", c)}
              />
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
