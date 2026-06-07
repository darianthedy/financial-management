import { useCallback, useEffect, useMemo, useRef, useState } from "react";
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
import { CurrencyAmountInput } from "@/components/shared/currency-amount-input";
import {
  Popover,
  PopoverContent,
  PopoverAnchor,
} from "@/components/ui/popover";
import { Plus, ChevronDown, X } from "lucide-react";
import {
  transactionFormSchema,
  type TransactionFormValues,
} from "@/lib/validations/transaction";
import { CategoryForm } from "@/components/transactions/category-form";
import {
  createTransaction,
  updateTransaction,
  fetchCategories,
  fetchTags,
  createTag,
} from "@/lib/hooks/use-transactions";
import { useAccounts } from "@/lib/hooks/use-accounts";
import { useCurrencies } from "@/lib/hooks/use-currencies";
import { fetchBudgetsForMonth } from "@/lib/hooks/use-budgets";
import { BudgetForm } from "@/components/budgets/budget-form";
import { todayIso, yearMonthOf } from "@/lib/utils/date";
import { toDisplayAmount, formatCurrency } from "@/lib/utils/currency";
import type { TransactionWithRelations } from "@/lib/hooks/use-transactions";
import type { Category, Tag, BudgetProgress } from "@/lib/types/database";

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

// Sentinel option values for the budget/category pickers (Radix Select
// disallows "").
const BUDGET_NONE = "__none__";
const BUDGET_CREATE = "__create__";
const CATEGORY_NONE = "__none__";
const CATEGORY_CREATE = "__create__";

export function TransactionForm({
  transaction,
  defaultAccountId,
  onSaved,
  onCancel,
}: Props) {
  const { accounts } = useAccounts();
  const { decimalsFor, defaultCurrency } = useCurrencies();
  const [categories, setCategories] = useState<Category[]>([]);
  const [allTags, setAllTags] = useState<Tag[]>([]);
  const [submitError, setSubmitError] = useState("");
  const [tagQuery, setTagQuery] = useState("");
  const [tagPopoverOpen, setTagPopoverOpen] = useState(false);
  const tagInputRef = useRef<HTMLInputElement>(null);
  const [budgetOptions, setBudgetOptions] = useState<BudgetProgress[]>([]);
  const [budgetFormOpen, setBudgetFormOpen] = useState(false);
  const [categoryFormOpen, setCategoryFormOpen] = useState(false);

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
              decimalsFor(defaultCurrency),
            ),
            date: transaction.date,
            description: transaction.description ?? "",
            budget_id: transaction.budget_id ?? null,
            category_id: transaction.category?.id ?? null,
            tag_ids: transaction.tags.map((t) => t.id),
          }
        : undefined,
    [transaction, decimalsFor, defaultCurrency],
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
      date: todayIso(),
      description: "",
      budget_id: null,
      category_id: null,
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
  const accountId = watch("account_id");
  const date = watch("date");
  const budgetId = watch("budget_id") ?? null;
  const categoryId = watch("category_id") ?? null;
  const tagIds = watch("tag_ids") ?? [];

  // Budgets that can be linked: same month (derived from the date).
  const budgetMonth = yearMonthOf(date);
  const loadBudgets = useCallback(() => {
    if (type === "transfer") {
      setBudgetOptions([]);
      return;
    }
    fetchBudgetsForMonth(budgetMonth).then(setBudgetOptions);
  }, [type, budgetMonth]);

  useEffect(() => {
    loadBudgets();
  }, [loadBudgets]);

  // Tags actually attached to the transaction, shown as removable chips.
  const selectedTags = allTags.filter((t) => tagIds.includes(t.id));

  // Available tags (not yet selected) narrowed by what the user has typed.
  const tagQ = tagQuery.trim().toLowerCase();
  const filteredTags = allTags.filter(
    (t) => !tagIds.includes(t.id) && t.name.toLowerCase().includes(tagQ),
  );
  // Only offer "create" when the typed name doesn't already exist verbatim.
  const canCreateTag =
    tagQ.length > 0 && !allTags.some((t) => t.name.toLowerCase() === tagQ);

  function addTag(id: string) {
    if (!tagIds.includes(id)) setValue("tag_ids", [...tagIds, id]);
    setTagQuery("");
    tagInputRef.current?.focus();
  }

  function removeTag(id: string) {
    setValue(
      "tag_ids",
      tagIds.filter((t) => t !== id),
    );
  }

  async function createAndAddTag() {
    const name = tagQuery.trim();
    if (!name) return;
    try {
      const tag = await createTag(name);
      setAllTags((prev) => [...prev, tag]);
      setValue("tag_ids", [...tagIds, tag.id]);
      setTagQuery("");
      tagInputRef.current?.focus();
    } catch {
      // Tag might already exist; ignore.
    }
  }

  async function onSubmit(values: TransactionFormValues) {
    try {
      const decimals = decimalsFor(defaultCurrency);
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
    <>
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
                else setValue("budget_id", null);
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
            // Ignore the empty-value change Radix fires while options are still
            // loading — it would wipe the prefilled account in edit mode.
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

        {type === "transfer" && (
          <div className="flex flex-col gap-1.5">
            <Label htmlFor="transfer_account_id">To</Label>
            <Select
              value={watch("transfer_account_id") ?? ""}
              onValueChange={(v) => v && setValue("transfer_account_id", v)}
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

      {/* Amount + Date */}
      <div className="grid grid-cols-2 gap-3">
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
          <Label htmlFor="date">Date</Label>
          <Input
            id="date"
            type="date"
            // Native date controls render taller than text inputs on WebKit;
            // appearance-none + block strips the intrinsic height so it matches.
            className="appearance-none block"
            {...register("date")}
          />
          <FieldError message={errors.date?.message} />
        </div>
      </div>

      <div className="flex flex-col gap-1.5">
        <Label htmlFor="description">Description</Label>
        <Input
          id="description"
          placeholder="Optional"
          {...register("description")}
        />
      </div>

      {/* Budget (expense/income only) */}
      {type !== "transfer" && (
        <div className="flex flex-col gap-1.5">
          <Label htmlFor="budget_id">Budget</Label>
          <Select
            value={budgetId ?? BUDGET_NONE}
            onValueChange={(v) => {
              if (!v) return;
              if (v === BUDGET_CREATE) {
                setBudgetFormOpen(true);
                return;
              }
              setValue("budget_id", v === BUDGET_NONE ? null : v);
            }}
          >
            <SelectTrigger id="budget_id">
              <SelectValue placeholder="No budget" />
            </SelectTrigger>
            <SelectContent>
              <SelectItem value={BUDGET_NONE}>No budget</SelectItem>
              {budgetOptions.map((b) => (
                <SelectItem key={b.budget_id} value={b.budget_id}>
                  {b.budget_name} · {formatCurrency(b.effective_amount)}
                </SelectItem>
              ))}
              <SelectItem value={BUDGET_CREATE}>
                + Create budget for this month
              </SelectItem>
            </SelectContent>
          </Select>
        </div>
      )}

      {/* Category (expense/income only) */}
      {type !== "transfer" && (
        <div className="flex flex-col gap-1.5">
          <Label htmlFor="category_id">Category</Label>
          <Select
            value={categoryId ?? CATEGORY_NONE}
            onValueChange={(v) => {
              if (!v) return;
              if (v === CATEGORY_CREATE) {
                setCategoryFormOpen(true);
                return;
              }
              setValue("category_id", v === CATEGORY_NONE ? null : v);
            }}
          >
            <SelectTrigger id="category_id">
              <SelectValue placeholder="No category" />
            </SelectTrigger>
            <SelectContent>
              <SelectItem value={CATEGORY_NONE}>No category</SelectItem>
              {categories.map((c) => (
                <SelectItem key={c.id} value={c.id}>
                  {c.name}
                </SelectItem>
              ))}
              <SelectItem value={CATEGORY_CREATE}>+ Create category</SelectItem>
            </SelectContent>
          </Select>
        </div>
      )}

      {/* Tags */}
      <div className="flex flex-col gap-1.5">
        <Label>Tags</Label>

        {/* Selected tags: chips shown only once a tag is attached. Clicking a
            chip detaches that tag from the transaction. */}
        {selectedTags.length > 0 && (
          <div className="flex flex-wrap gap-2">
            {selectedTags.map((t) => (
              <button
                key={t.id}
                type="button"
                onClick={() => removeTag(t.id)}
                className="flex items-center gap-1 rounded-full border border-[var(--color-primary)] bg-[var(--color-primary)] px-2.5 py-0.5 text-xs font-medium text-[var(--color-primary-foreground)] transition-colors hover:opacity-90"
              >
                {t.name}
                <X className="h-3 w-3" />
              </button>
            ))}
          </div>
        )}

        {/* Typeable dropdown: the input doubles as the trigger and the filter.
            Typing narrows the list and, if no tag matches, offers to create it. */}
        <Popover open={tagPopoverOpen} onOpenChange={setTagPopoverOpen}>
          <PopoverAnchor asChild>
            <div className="relative">
              <Input
                ref={tagInputRef}
                placeholder="Add tag"
                value={tagQuery}
                onChange={(e) => {
                  setTagQuery(e.target.value);
                  setTagPopoverOpen(true);
                }}
                onFocus={() => setTagPopoverOpen(true)}
                onKeyDown={(e) => {
                  if (e.key === "Enter") {
                    e.preventDefault();
                    if (filteredTags.length > 0) addTag(filteredTags[0].id);
                    else if (canCreateTag) createAndAddTag();
                  }
                }}
                className="pr-9"
              />
              <ChevronDown className="pointer-events-none absolute right-3 top-1/2 h-4 w-4 -translate-y-1/2 opacity-60" />
            </div>
          </PopoverAnchor>
          <PopoverContent
            align="start"
            sideOffset={4}
            // Keep focus in the input so the user can keep typing while the
            // list is open, and don't close when they click back into it.
            onOpenAutoFocus={(e) => e.preventDefault()}
            onInteractOutside={(e) => {
              if (e.target === tagInputRef.current) e.preventDefault();
            }}
            className="w-[var(--radix-popover-trigger-width)] p-1"
          >
            <div className="max-h-56 overflow-y-auto">
              {filteredTags.map((t) => (
                <button
                  key={t.id}
                  type="button"
                  onClick={() => addTag(t.id)}
                  className="flex w-full items-center rounded-sm px-2 py-1.5 text-left text-sm outline-none hover:bg-[var(--color-muted)]"
                >
                  {t.name}
                </button>
              ))}
              {canCreateTag && (
                <button
                  type="button"
                  onClick={createAndAddTag}
                  className="flex w-full items-center gap-1.5 rounded-sm px-2 py-1.5 text-left text-sm outline-none hover:bg-[var(--color-muted)]"
                >
                  <Plus className="h-3.5 w-3.5 shrink-0" />
                  Create “{tagQuery.trim()}”
                </button>
              )}
              {filteredTags.length === 0 && !canCreateTag && (
                <div className="px-2 py-1.5 text-sm text-[var(--color-muted-foreground)]">
                  {allTags.length === 0 ? "No tags yet" : "All tags selected"}
                </div>
              )}
            </div>
          </PopoverContent>
        </Popover>
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

      <BudgetForm
        open={budgetFormOpen}
        onOpenChange={setBudgetFormOpen}
        yearMonth={budgetMonth}
        onSaved={(id) => {
          loadBudgets();
          if (id) setValue("budget_id", id);
        }}
      />

      <CategoryForm
        open={categoryFormOpen}
        onOpenChange={setCategoryFormOpen}
        onSaved={(category) => {
          setCategories((prev) =>
            [...prev, category].sort((a, b) => a.name.localeCompare(b.name)),
          );
          setValue("category_id", category.id);
        }}
      />
    </>
  );
}
