import { useCallback, useEffect, useRef, useState } from "react";
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
import {
  Popover,
  PopoverContent,
  PopoverAnchor,
} from "@/components/ui/popover";
import { Plus, ChevronDown, X } from "lucide-react";
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
import {
  fetchCategories,
  fetchTags,
  createTag,
} from "@/lib/hooks/use-transactions";
import { fetchBudgetsForMonth } from "@/lib/hooks/use-budgets";
import { fetchFixedExpensesForMonth } from "@/lib/hooks/use-fixed-expenses";
import { CategoryForm } from "@/components/transactions/category-form";
import { BudgetForm } from "@/components/budgets/budget-form";
import { FixedExpenseForm } from "@/components/fixed-expenses/fixed-expense-form";
import { useAccounts } from "@/lib/hooks/use-accounts";
import { useCurrencies } from "@/lib/hooks/use-currencies";
import { toDisplayAmount, currencyDecimals, formatCurrency } from "@/lib/utils/currency";
import { todayIso, yearMonthOf } from "@/lib/utils/date";
import type {
  Category,
  Tag,
  BudgetProgress,
  FixedExpense,
} from "@/lib/types/database";

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

// Sentinel option values for the budget/category pickers (Radix Select
// disallows "").
const BUDGET_NONE = "__none__";
const BUDGET_CREATE = "__create__";
const CATEGORY_NONE = "__none__";
const CATEGORY_CREATE = "__create__";
const FIXED_NONE = "__none__";
const FIXED_CREATE = "__create__";

export function ScheduledForm({ open, onOpenChange, scheduled, onSaved }: Props) {
  const { accounts } = useAccounts();
  const { defaultCurrency, decimalsFor } = useCurrencies();
  const [submitError, setSubmitError] = useState("");
  const [categories, setCategories] = useState<Category[]>([]);
  const [allTags, setAllTags] = useState<Tag[]>([]);
  const [tagQuery, setTagQuery] = useState("");
  const [tagPopoverOpen, setTagPopoverOpen] = useState(false);
  const tagInputRef = useRef<HTMLInputElement>(null);
  const [budgetOptions, setBudgetOptions] = useState<BudgetProgress[]>([]);
  const [budgetFormOpen, setBudgetFormOpen] = useState(false);
  const [categoryFormOpen, setCategoryFormOpen] = useState(false);
  const [fixedExpenseOptions, setFixedExpenseOptions] = useState<FixedExpense[]>(
    [],
  );
  const [fixedExpenseFormOpen, setFixedExpenseFormOpen] = useState(false);
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
    // eslint-disable-next-line @typescript-eslint/no-explicit-any
    resolver: zodResolver(scheduledTransactionFormSchema) as any,
    defaultValues: {
      account_id: "",
      type: "expense",
      amount: 0,
      description: "",
      recurrence: "monthly",
      next_due_date: todayIso(),
      is_active: true,
      category_id: null,
      budget_name: null,
      fixed_expense_name: null,
      tag_ids: [],
    },
  });

  useEffect(() => {
    if (!open) return;
    fetchCategories().then(setCategories);
    fetchTags().then(setAllTags);
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
            category_id: scheduled.category_id,
            budget_name: scheduled.budget_name,
            fixed_expense_name: scheduled.fixed_expense_name,
            tag_ids: scheduled.tags.map((t) => t.id),
          }
        : {
            account_id: "",
            type: "expense",
            amount: 0,
            description: "",
            recurrence: "monthly",
            next_due_date: todayIso(),
            is_active: true,
            category_id: null,
            budget_name: null,
            fixed_expense_name: null,
            tag_ids: [],
          },
    );
    setTagQuery("");
    setSubmitError("");
  }, [open, scheduled, defaultCurrency, reset]);

  const type = watch("type");
  const accountId = watch("account_id");
  const isActive = watch("is_active");
  const dueDate = watch("next_due_date");
  const categoryId = watch("category_id") ?? null;
  const budgetName = watch("budget_name") ?? null;
  const fixedExpenseName = watch("fixed_expense_name") ?? null;
  const tagIds = watch("tag_ids") ?? [];

  // Budgets linkable for the due month, so the picker shows the same lineages the
  // generator will resolve against. The schedule stores the budget *name*.
  const budgetMonth = yearMonthOf(dueDate);
  const loadBudgets = useCallback(() => {
    if (!budgetMonth) {
      setBudgetOptions([]);
      return;
    }
    fetchBudgetsForMonth(budgetMonth).then(setBudgetOptions);
  }, [budgetMonth]);

  useEffect(() => {
    loadBudgets();
  }, [loadBudgets]);

  // The stored lineage may not have a row in the due month yet; keep it
  // selectable so editing doesn't silently drop the link.
  const budgetMissingFromMonth =
    !!budgetName && !budgetOptions.some((b) => b.budget_name === budgetName);

  // Fixed expenses are month-scoped too; load the due month's so the picker
  // shows the same lineages the generator will resolve against (by name).
  const loadFixedExpenses = useCallback(() => {
    if (!budgetMonth) {
      setFixedExpenseOptions([]);
      return;
    }
    fetchFixedExpensesForMonth(budgetMonth).then(setFixedExpenseOptions);
  }, [budgetMonth]);

  useEffect(() => {
    loadFixedExpenses();
  }, [loadFixedExpenses]);

  // Keep a stored lineage selectable even if the due month has no row yet, so
  // editing doesn't silently drop the link.
  const fixedExpenseMissingFromMonth =
    !!fixedExpenseName &&
    !fixedExpenseOptions.some((fe) => fe.name === fixedExpenseName);

  // Tags actually attached, shown as removable chips.
  const selectedTags = allTags.filter((t) => tagIds.includes(t.id));
  const tagQ = tagQuery.trim().toLowerCase();
  const filteredTags = allTags.filter(
    (t) => !tagIds.includes(t.id) && t.name.toLowerCase().includes(tagQ),
  );
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
        <form
          onSubmit={handleSubmit(onSubmit)}
          className="flex max-h-[75vh] flex-col gap-5 overflow-y-auto"
        >
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
                    // Fixed expenses apply to expenses only; drop the link on income.
                    if (t.value !== "expense") setValue("fixed_expense_name", null);
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

          {/* Budget — linked by lineage (name). The generator resolves it to the
              due month's budget; months without one are generated unlinked. */}
          <div className="flex flex-col gap-1.5">
            <Label htmlFor="budget_name">Budget</Label>
            <Select
              value={budgetName ?? BUDGET_NONE}
              onValueChange={(v) => {
                if (!v) return;
                if (v === BUDGET_CREATE) {
                  setBudgetFormOpen(true);
                  return;
                }
                setValue("budget_name", v === BUDGET_NONE ? null : v);
              }}
            >
              <SelectTrigger id="budget_name">
                <SelectValue placeholder="No budget" />
              </SelectTrigger>
              <SelectContent>
                <SelectItem value={BUDGET_NONE}>No budget</SelectItem>
                {budgetMissingFromMonth && (
                  <SelectItem value={budgetName!}>
                    {budgetName} · none this month
                  </SelectItem>
                )}
                {budgetOptions.map((b) => (
                  <SelectItem key={b.budget_id} value={b.budget_name}>
                    {b.budget_name} · {formatCurrency(b.effective_amount)}
                  </SelectItem>
                ))}
                <SelectItem value={BUDGET_CREATE}>
                  + Create budget for this month
                </SelectItem>
              </SelectContent>
            </Select>
          </div>

          {/* Category */}
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

          {/* Fixed expense (expense only) — linked by lineage (name). The
              generator resolves it to the due month's fixed expense; months
              without one are generated unlinked. Linking marks it paid. */}
          {type === "expense" && (
            <div className="flex flex-col gap-1.5">
              <Label htmlFor="fixed_expense_name">Fixed expense</Label>
              <Select
                value={fixedExpenseName ?? FIXED_NONE}
                onValueChange={(v) => {
                  if (!v) return;
                  if (v === FIXED_CREATE) {
                    setFixedExpenseFormOpen(true);
                    return;
                  }
                  setValue(
                    "fixed_expense_name",
                    v === FIXED_NONE ? null : v,
                  );
                }}
              >
                <SelectTrigger id="fixed_expense_name">
                  <SelectValue placeholder="Not a fixed expense" />
                </SelectTrigger>
                <SelectContent>
                  <SelectItem value={FIXED_NONE}>Not a fixed expense</SelectItem>
                  {fixedExpenseMissingFromMonth && (
                    <SelectItem value={fixedExpenseName!}>
                      {fixedExpenseName} · none this month
                    </SelectItem>
                  )}
                  {fixedExpenseOptions.map((fe) => (
                    <SelectItem key={fe.id} value={fe.name}>
                      {fe.name} · {formatCurrency(fe.amount)}
                    </SelectItem>
                  ))}
                  <SelectItem value={FIXED_CREATE}>
                    + Create fixed expense for this month
                  </SelectItem>
                </SelectContent>
              </Select>
            </div>
          )}

          {/* Tags */}
          <div className="flex flex-col gap-1.5">
            <Label>Tags</Label>

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

      <BudgetForm
        open={budgetFormOpen}
        onOpenChange={setBudgetFormOpen}
        yearMonth={budgetMonth}
        onSaved={(id) => {
          // Resolve the freshly created row back to its lineage name to store.
          fetchBudgetsForMonth(budgetMonth).then((opts) => {
            setBudgetOptions(opts);
            const created = opts.find((b) => b.budget_id === id);
            if (created) setValue("budget_name", created.budget_name);
          });
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

      <FixedExpenseForm
        open={fixedExpenseFormOpen}
        onOpenChange={setFixedExpenseFormOpen}
        yearMonth={budgetMonth}
        onSaved={(id) => {
          // Resolve the freshly created row back to its lineage name to store.
          fetchFixedExpensesForMonth(budgetMonth).then((opts) => {
            setFixedExpenseOptions(opts);
            const created = opts.find((fe) => fe.id === id);
            if (created) setValue("fixed_expense_name", created.name);
          });
        }}
      />
    </Dialog>
  );
}
