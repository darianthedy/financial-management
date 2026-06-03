import { useEffect, useMemo, useState } from "react";
import { useForm } from "react-hook-form";
import { zodResolver } from "@hookform/resolvers/zod";
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
import { Plus } from "lucide-react";
import {
  transactionFormSchema,
  type TransactionFormValues,
} from "@/lib/validations/transaction";
import { CategoryCombobox } from "@/components/transactions/category-combobox";
import {
  createTransaction,
  updateTransaction,
  fetchCategories,
  fetchTags,
  createTag,
  createCategory,
} from "@/lib/hooks/use-transactions";
import { useAccounts } from "@/lib/hooks/use-accounts";
import { useCurrencies } from "@/lib/hooks/use-currencies";
import { todayIso } from "@/lib/utils/date";
import { toDisplayAmount } from "@/lib/utils/currency";
import type { TransactionWithRelations } from "@/lib/hooks/use-transactions";
import type { Category, Tag } from "@/lib/types/database";

interface Props {
  transaction?: TransactionWithRelations | null;
  defaultAccountId?: string;
  onSaved?: () => void;
  onCancel?: () => void;
}

const TYPES = [
  { value: "income", label: "Income" },
  { value: "expense", label: "Expense" },
  { value: "transfer", label: "Transfer" },
] as const;

export function TransactionForm({
  transaction,
  defaultAccountId,
  onSaved,
  onCancel,
}: Props) {
  const { accounts } = useAccounts();
  const { decimalsFor } = useCurrencies();
  const [categories, setCategories] = useState<Category[]>([]);
  const [allTags, setAllTags] = useState<Tag[]>([]);
  const [submitError, setSubmitError] = useState("");
  const [newTagInput, setNewTagInput] = useState("");

  // Prefill values for edit mode. Using react-hook-form's `values` prop (rather
  // than reset() in an effect) syncs during render, so prefill is deterministic
  // even when StrictMode remounts the form or the parent re-fetches.
  const values = useMemo<TransactionFormValues | undefined>(
    () =>
      transaction
        ? {
            type: transaction.type,
            account_id: transaction.account_id,
            transfer_account_id: transaction.transfer_account_id ?? null,
            amount: toDisplayAmount(
              transaction.amount,
              decimalsFor(transaction.currency),
            ),
            currency: transaction.currency,
            date: transaction.date,
            description: transaction.description ?? "",
            category_ids: transaction.categories.map((c) => c.id),
            tag_ids: transaction.tags.map((t) => t.id),
          }
        : undefined,
    [transaction, decimalsFor],
  );

  const {
    register,
    handleSubmit,
    watch,
    setValue,
    formState: { errors, isSubmitting },
  } = useForm<TransactionFormValues>({
    // eslint-disable-next-line @typescript-eslint/no-explicit-any
    resolver: zodResolver(transactionFormSchema) as any,
    defaultValues: {
      type: "expense",
      account_id: defaultAccountId ?? "",
      transfer_account_id: null,
      amount: 0,
      currency: "IDR",
      date: todayIso(),
      description: "",
      category_ids: [],
      tag_ids: [],
    },
    values,
    resetOptions: { keepDirtyValues: true },
  });

  useEffect(() => {
    fetchCategories().then(setCategories);
    fetchTags().then(setAllTags);
  }, []);

  const type = watch("type");
  const currency = watch("currency");
  const accountId = watch("account_id");
  const categoryIds = watch("category_ids") ?? [];
  const tagIds = watch("tag_ids") ?? [];

  async function handleCreateCategory(name: string) {
    const category = await createCategory(name);
    setCategories((prev) =>
      [...prev, category].sort((a, b) => a.name.localeCompare(b.name)),
    );
    return category;
  }

  function toggleTag(id: string) {
    const next = tagIds.includes(id)
      ? tagIds.filter((t) => t !== id)
      : [...tagIds, id];
    setValue("tag_ids", next);
  }

  async function addNewTag() {
    const name = newTagInput.trim();
    if (!name) return;
    try {
      const tag = await createTag(name);
      setAllTags((prev) => [...prev, tag]);
      setValue("tag_ids", [...tagIds, tag.id]);
      setNewTagInput("");
    } catch {
      // Tag might already exist; ignore.
    }
  }

  async function onSubmit(values: TransactionFormValues) {
    try {
      const decimals = decimalsFor(values.currency);
      if (transaction) {
        await updateTransaction(transaction.id, values, decimals);
      } else {
        await createTransaction(values, decimals);
      }
      onSaved?.();
    } catch (e) {
      setSubmitError(
        e instanceof Error ? e.message : "Failed to save transaction",
      );
    }
  }

  return (
    <form onSubmit={handleSubmit(onSubmit)} className="flex flex-col gap-5">
      {/* Type */}
      <div className="flex flex-col gap-1.5">
        <Label>Type</Label>
        <div className="flex gap-2">
          {TYPES.map((t) => (
            <button
              key={t.value}
              type="button"
              onClick={() => {
                setValue("type", t.value);
                if (t.value !== "transfer") setValue("transfer_account_id", null);
              }}
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
      <div className="grid grid-cols-2 gap-3">
        <div className="flex flex-col gap-1.5">
          <Label htmlFor="account_id">
            {type === "transfer" ? "From" : "Account"}
          </Label>
          <Select
            value={accountId}
            onValueChange={(v) => setValue("account_id", v)}
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

        {type === "transfer" && (
          <div className="flex flex-col gap-1.5">
            <Label htmlFor="transfer_account_id">To</Label>
            <Select
              value={watch("transfer_account_id") ?? ""}
              onValueChange={(v) => setValue("transfer_account_id", v)}
            >
              <SelectTrigger id="transfer_account_id">
                <SelectValue placeholder="Select account" />
              </SelectTrigger>
              <SelectContent>
                {accounts
                  .filter((a) => a.id !== accountId)
                  .map((a) => (
                    <SelectItem key={a.id} value={a.id}>
                      {a.name}
                    </SelectItem>
                  ))}
              </SelectContent>
            </Select>
            <FieldError
              message={errors.transfer_account_id?.message}
            />
          </div>
        )}
      </div>

      {/* Amount + Currency + Date */}
      <div className="grid grid-cols-2 gap-3">
        <div className="flex flex-col gap-1.5">
          <Label htmlFor="amount">Amount</Label>
          <Input
            id="amount"
            type="number"
            step="0.01"
            min="0.01"
            {...register("amount", { valueAsNumber: true })}
          />
          <FieldError message={errors.amount?.message} />
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

      <div className="flex flex-col gap-1.5">
        <Label htmlFor="date">Date</Label>
        <Input id="date" type="date" {...register("date")} />
        <FieldError message={errors.date?.message} />
      </div>

      <div className="flex flex-col gap-1.5">
        <Label htmlFor="description">Description</Label>
        <Input
          id="description"
          placeholder="Optional"
          {...register("description")}
        />
      </div>

      {/* Categories (expense/income only) */}
      {type !== "transfer" && (
        <div className="flex flex-col gap-1.5">
          <Label>Categories</Label>
          <CategoryCombobox
            categories={categories}
            value={categoryIds}
            onChange={(ids) => setValue("category_ids", ids)}
            onCreate={handleCreateCategory}
          />
        </div>
      )}

      {/* Tags */}
      <div className="flex flex-col gap-1.5">
        <Label>Tags</Label>
        <div className="flex flex-wrap gap-2">
          {allTags.map((t) => {
            const selected = tagIds.includes(t.id);
            return (
              <button
                key={t.id}
                type="button"
                onClick={() => toggleTag(t.id)}
                className={`rounded-full border px-2.5 py-0.5 text-xs font-medium transition-colors ${
                  selected
                    ? "border-[var(--color-primary)] bg-[var(--color-primary)] text-[var(--color-primary-foreground)]"
                    : "border-[var(--color-border)] hover:bg-[var(--color-muted)]"
                }`}
              >
                {t.name}
              </button>
            );
          })}
        </div>
        <div className="flex gap-2">
          <Input
            placeholder="New tag"
            value={newTagInput}
            onChange={(e) => setNewTagInput(e.target.value)}
            onKeyDown={(e) => {
              if (e.key === "Enter") {
                e.preventDefault();
                addNewTag();
              }
            }}
            className="h-8 text-sm"
          />
          <Button
            type="button"
            variant="outline"
            size="sm"
            onClick={addNewTag}
            className="shrink-0"
          >
            <Plus className="h-4 w-4" />
          </Button>
        </div>
      </div>

      <FieldError message={submitError} />

      <div className="flex gap-2 pt-2">
        {onCancel && (
          <Button type="button" variant="outline" onClick={onCancel} className="flex-1">
            Cancel
          </Button>
        )}
        <Button type="submit" disabled={isSubmitting} className="flex-1">
          {isSubmitting
            ? "Saving…"
            : transaction
              ? "Update transaction"
              : "Add transaction"}
        </Button>
      </div>
    </form>
  );
}
