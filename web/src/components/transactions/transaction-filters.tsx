import { useEffect, useState } from "react";
import {
  format,
  startOfMonth,
  endOfMonth,
  subMonths,
  startOfYear,
  endOfYear,
} from "date-fns";
import { Search, SlidersHorizontal, X } from "lucide-react";
import { Button } from "@/components/ui/button";
import { Input } from "@/components/ui/input";
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
  PopoverTrigger,
} from "@/components/ui/popover";
import { MultiSelect } from "@/components/ui/multi-select";
import { CurrencyAmountInput } from "@/components/shared/currency-amount-input";
import { useAccounts } from "@/lib/hooks/use-accounts";
import { useCurrencies } from "@/lib/hooks/use-currencies";
import { fetchBudgetNames } from "@/lib/hooks/use-budgets";
import {
  fetchCategories,
  fetchTags,
  type TransactionFilters,
  type TransactionType,
  type TransactionStatus,
} from "@/lib/hooks/use-transactions";
import { countPanelFilters } from "@/lib/utils/transaction-filters";
import {
  formatCurrency,
  toDisplayAmount,
  toMinorUnits,
} from "@/lib/utils/currency";
import { formatDate } from "@/lib/utils/date";
import type { Category, Tag } from "@/lib/types/database";

interface Props {
  filters: TransactionFilters;
  onChange: (next: TransactionFilters) => void;
  resultCount?: number;
}

const iso = (d: Date) => format(d, "yyyy-MM-dd");

const TYPE_OPTIONS: { value: TransactionType; label: string }[] = [
  { value: "income", label: "Income" },
  { value: "expense", label: "Expense" },
  { value: "transfer", label: "Transfer" },
];

const STATUS_OPTIONS: { value: TransactionStatus; label: string }[] = [
  { value: "confirmed", label: "Confirmed" },
  { value: "pending", label: "Pending" },
  { value: "dismissed", label: "Dismissed" },
];

// Array-valued filter keys whose chips remove a single value at a time.
type ArrayKey = "types" | "statuses" | "accountIds" | "categoryIds" | "tagIds";

export function TransactionFiltersBar({ filters, onChange, resultCount }: Props) {
  const { accounts } = useAccounts();
  const { defaultCurrency, decimalsFor } = useCurrencies();
  const decimals = decimalsFor(defaultCurrency);

  const [categories, setCategories] = useState<Category[]>([]);
  const [tags, setTags] = useState<Tag[]>([]);
  const [budgetNames, setBudgetNames] = useState<string[]>([]);
  const [open, setOpen] = useState(false);

  useEffect(() => {
    fetchCategories().then(setCategories);
    fetchTags().then(setTags);
  }, []);

  // Budget options follow the selected date range: only budgets that exist in
  // the range's months are offered (requirement: filter budgets by date filter).
  const { dateFrom, dateTo } = filters;
  useEffect(() => {
    fetchBudgetNames(dateFrom?.slice(0, 7), dateTo?.slice(0, 7)).then(
      setBudgetNames,
    );
  }, [dateFrom, dateTo]);

  const accountName = (id: string) =>
    accounts.find((a) => a.id === id)?.name ?? "Account";
  const categoryName = (id: string) =>
    categories.find((c) => c.id === id)?.name ?? "Category";
  const tagName = (id: string) => tags.find((t) => t.id === id)?.name ?? "Tag";

  function patch(next: Partial<TransactionFilters>) {
    onChange({ ...filters, ...next });
  }

  // Remove a key entirely (so it disappears from the URL and the active count).
  function clear(...keys: (keyof TransactionFilters)[]) {
    const next = { ...filters };
    for (const k of keys) delete next[k];
    onChange(next);
  }

  // Set an array filter, dropping the key entirely when the selection is empty.
  function setArray(key: ArrayKey, values: string[]) {
    if (values.length) patch({ [key]: values } as Partial<TransactionFilters>);
    else clear(key);
  }

  function removeValue(key: ArrayKey, value: string) {
    const cur = (filters[key] ?? []) as string[];
    setArray(
      key,
      cur.filter((v) => v !== value),
    );
  }

  // Clear every panel filter but leave the always-visible search intact.
  function clearPanel() {
    clear(
      "types",
      "statuses",
      "accountIds",
      "dateFrom",
      "dateTo",
      "amountMin",
      "amountMax",
      "categoryIds",
      "tagIds",
      "budgetName",
      "fixedExpenseLinked",
    );
  }

  const now = new Date();
  const presets = [
    { label: "This month", from: iso(startOfMonth(now)), to: iso(endOfMonth(now)) },
    {
      label: "Last month",
      from: iso(startOfMonth(subMonths(now, 1))),
      to: iso(endOfMonth(subMonths(now, 1))),
    },
    {
      label: "Last 3 months",
      from: iso(startOfMonth(subMonths(now, 2))),
      to: iso(endOfMonth(now)),
    },
    { label: "This year", from: iso(startOfYear(now)), to: iso(endOfYear(now)) },
  ];
  const activePreset = presets.find(
    (p) => p.from === filters.dateFrom && p.to === filters.dateTo,
  );

  // Keep a selected budget visible even if the current date range no longer
  // lists it, so the Select doesn't render blank.
  const budgetOptions =
    filters.budgetName && !budgetNames.includes(filters.budgetName)
      ? [filters.budgetName, ...budgetNames]
      : budgetNames;
  const fixedValue =
    filters.fixedExpenseLinked === true
      ? "linked"
      : filters.fixedExpenseLinked === false
        ? "unlinked"
        : "all";

  const panelCount = countPanelFilters(filters);
  const fmtAmt = (minor: number) => formatCurrency(minor, defaultCurrency);

  // Build the active-filter chip list (one chip per selected value).
  const chips: { key: string; label: string; onRemove: () => void }[] = [];
  for (const t of filters.types ?? [])
    chips.push({
      key: `type-${t}`,
      label: `Type: ${t}`,
      onRemove: () => removeValue("types", t),
    });
  for (const id of filters.accountIds ?? [])
    chips.push({
      key: `account-${id}`,
      label: `Account: ${accountName(id)}`,
      onRemove: () => removeValue("accountIds", id),
    });
  for (const s of filters.statuses ?? [])
    chips.push({
      key: `status-${s}`,
      label: `Status: ${s}`,
      onRemove: () => removeValue("statuses", s),
    });
  if (filters.dateFrom || filters.dateTo)
    chips.push({
      key: "date",
      label: activePreset
        ? activePreset.label
        : filters.dateFrom && filters.dateTo
          ? `${formatDate(filters.dateFrom)} – ${formatDate(filters.dateTo)}`
          : filters.dateFrom
            ? `From ${formatDate(filters.dateFrom)}`
            : `Until ${formatDate(filters.dateTo!)}`,
      onRemove: () => clear("dateFrom", "dateTo"),
    });
  if (filters.amountMin != null || filters.amountMax != null)
    chips.push({
      key: "amount",
      label:
        filters.amountMin != null && filters.amountMax != null
          ? `${fmtAmt(filters.amountMin)} – ${fmtAmt(filters.amountMax)}`
          : filters.amountMin != null
            ? `≥ ${fmtAmt(filters.amountMin)}`
            : `≤ ${fmtAmt(filters.amountMax!)}`,
      onRemove: () => clear("amountMin", "amountMax"),
    });
  for (const id of filters.categoryIds ?? [])
    chips.push({
      key: `cat-${id}`,
      label: categoryName(id),
      onRemove: () => removeValue("categoryIds", id),
    });
  for (const id of filters.tagIds ?? [])
    chips.push({
      key: `tag-${id}`,
      label: `#${tagName(id)}`,
      onRemove: () => removeValue("tagIds", id),
    });
  if (filters.budgetName)
    chips.push({
      key: "budget",
      label: `Budget: ${filters.budgetName}`,
      onRemove: () => clear("budgetName"),
    });
  if (filters.fixedExpenseLinked != null)
    chips.push({
      key: "fixed",
      label: filters.fixedExpenseLinked ? "Paid (fixed)" : "Unpaid (fixed)",
      onRemove: () => clear("fixedExpenseLinked"),
    });
  if (filters.search)
    chips.push({
      key: "search",
      label: `“${filters.search}”`,
      onRemove: () => clear("search"),
    });

  const hasAny = chips.length > 0;

  return (
    <div className="space-y-2">
      <div className="flex flex-wrap items-center gap-2">
        {/* Always-visible search */}
        <div className="relative min-w-44 flex-1">
          <Search className="pointer-events-none absolute left-3 top-1/2 h-4 w-4 -translate-y-1/2 text-[var(--color-muted-foreground)]" />
          <Input
            value={filters.search ?? ""}
            onChange={(e) =>
              e.target.value ? patch({ search: e.target.value }) : clear("search")
            }
            placeholder="Search description…"
            className="pl-9"
          />
        </div>

        {/* Filters panel — icon-only trigger; the active count replaces the icon. */}
        <Popover open={open} onOpenChange={setOpen}>
          <PopoverTrigger asChild>
            <Button
              variant="outline"
              size="icon"
              aria-label={
                panelCount > 0 ? `Filters (${panelCount} active)` : "Filters"
              }
            >
              {panelCount > 0 ? (
                <span className="text-sm font-semibold text-[var(--color-success)]">
                  {panelCount}
                </span>
              ) : (
                <SlidersHorizontal className="h-4 w-4" />
              )}
            </Button>
          </PopoverTrigger>
          <PopoverContent align="end" className="space-y-4">
            <div className="flex items-center justify-between">
              <h3 className="text-sm font-semibold">Filter</h3>
              {panelCount > 0 && (
                <button
                  type="button"
                  onClick={clearPanel}
                  className="text-xs text-[var(--color-muted-foreground)] hover:text-[var(--color-foreground)]"
                >
                  Clear all
                </button>
              )}
            </div>

            <FilterField label="Type">
              <MultiSelect
                placeholder="All types"
                options={TYPE_OPTIONS}
                value={filters.types ?? []}
                onChange={(v) => setArray("types", v)}
              />
            </FilterField>

            <FilterField label="Account">
              <MultiSelect
                placeholder="All accounts"
                options={accounts.map((a) => ({ value: a.id, label: a.name }))}
                value={filters.accountIds ?? []}
                onChange={(v) => setArray("accountIds", v)}
              />
            </FilterField>

            <FilterField label="Status">
              <MultiSelect
                placeholder="All statuses"
                options={STATUS_OPTIONS}
                value={filters.statuses ?? []}
                onChange={(v) => setArray("statuses", v)}
              />
            </FilterField>

            <FilterField label="Date">
              <div className="flex flex-wrap gap-1.5">
                {presets.map((p) => (
                  <button
                    key={p.label}
                    type="button"
                    onClick={() => patch({ dateFrom: p.from, dateTo: p.to })}
                    className={`rounded-full border px-2.5 py-1 text-xs ${
                      activePreset?.label === p.label
                        ? "border-[var(--color-primary)] text-[var(--color-primary)]"
                        : "border-[var(--color-border)] text-[var(--color-muted-foreground)]"
                    }`}
                  >
                    {p.label}
                  </button>
                ))}
                {(filters.dateFrom || filters.dateTo) && (
                  <button
                    type="button"
                    onClick={() => clear("dateFrom", "dateTo")}
                    className="rounded-full border border-[var(--color-border)] px-2.5 py-1 text-xs text-[var(--color-muted-foreground)]"
                  >
                    All time
                  </button>
                )}
              </div>
              <div className="mt-2 flex items-center gap-2">
                <Input
                  type="date"
                  value={filters.dateFrom ?? ""}
                  onChange={(e) =>
                    e.target.value ? patch({ dateFrom: e.target.value }) : clear("dateFrom")
                  }
                  aria-label="From date"
                />
                <span className="text-[var(--color-muted-foreground)]">–</span>
                <Input
                  type="date"
                  value={filters.dateTo ?? ""}
                  onChange={(e) =>
                    e.target.value ? patch({ dateTo: e.target.value }) : clear("dateTo")
                  }
                  aria-label="To date"
                />
              </div>
            </FilterField>

            <FilterField label={`Amount (${defaultCurrency})`}>
              <div className="flex items-center gap-2">
                <CurrencyAmountInput
                  decimals={decimals}
                  value={
                    filters.amountMin != null
                      ? toDisplayAmount(filters.amountMin, decimals)
                      : NaN
                  }
                  onChange={(v) =>
                    Number.isFinite(v)
                      ? patch({ amountMin: toMinorUnits(v, decimals) })
                      : clear("amountMin")
                  }
                  aria-label="Minimum amount"
                />
                <span className="text-[var(--color-muted-foreground)]">–</span>
                <CurrencyAmountInput
                  decimals={decimals}
                  value={
                    filters.amountMax != null
                      ? toDisplayAmount(filters.amountMax, decimals)
                      : NaN
                  }
                  onChange={(v) =>
                    Number.isFinite(v)
                      ? patch({ amountMax: toMinorUnits(v, decimals) })
                      : clear("amountMax")
                  }
                  aria-label="Maximum amount"
                />
              </div>
            </FilterField>

            {categories.length > 0 && (
              <FilterField label="Categories">
                <MultiSelect
                  placeholder="All categories"
                  options={categories.map((c) => ({
                    value: c.id,
                    label: c.name,
                    color: c.color,
                  }))}
                  value={filters.categoryIds ?? []}
                  onChange={(v) => setArray("categoryIds", v)}
                />
              </FilterField>
            )}

            {tags.length > 0 && (
              <FilterField label="Tags">
                <MultiSelect
                  placeholder="All tags"
                  options={tags.map((t) => ({ value: t.id, label: `#${t.name}` }))}
                  value={filters.tagIds ?? []}
                  onChange={(v) => setArray("tagIds", v)}
                />
              </FilterField>
            )}

            <FilterField label="Budget">
              <Select
                value={filters.budgetName ?? "all"}
                onValueChange={(v) =>
                  v === "all" ? clear("budgetName") : patch({ budgetName: v })
                }
              >
                <SelectTrigger>
                  <SelectValue />
                </SelectTrigger>
                <SelectContent>
                  <SelectItem value="all">All budgets</SelectItem>
                  {budgetOptions.map((n) => (
                    <SelectItem key={n} value={n}>
                      {n}
                    </SelectItem>
                  ))}
                </SelectContent>
              </Select>
            </FilterField>

            <FilterField label="Fixed expense">
              <Select
                value={fixedValue}
                onValueChange={(v) =>
                  v === "linked"
                    ? patch({ fixedExpenseLinked: true })
                    : v === "unlinked"
                      ? patch({ fixedExpenseLinked: false })
                      : clear("fixedExpenseLinked")
                }
              >
                <SelectTrigger>
                  <SelectValue />
                </SelectTrigger>
                <SelectContent>
                  <SelectItem value="all">Any (all)</SelectItem>
                  <SelectItem value="linked">Linked (paid)</SelectItem>
                  <SelectItem value="unlinked">Not linked (unpaid)</SelectItem>
                </SelectContent>
              </Select>
            </FilterField>

            {/* A "Sort" section can be added here alongside the Filter one. */}
          </PopoverContent>
        </Popover>

        {resultCount != null && (
          <span className="text-sm text-[var(--color-muted-foreground)]">
            {resultCount} {resultCount === 1 ? "result" : "results"}
          </span>
        )}
      </div>

      {/* Active filter chips */}
      {hasAny && (
        <div className="flex flex-wrap items-center gap-1.5">
          {chips.map((c) => (
            <span
              key={c.key}
              className="inline-flex items-center gap-1 rounded-full border border-[var(--color-border)] bg-[var(--color-muted)] px-2.5 py-0.5 text-xs"
            >
              {c.label}
              <button
                type="button"
                onClick={c.onRemove}
                className="opacity-60 hover:opacity-100"
                aria-label={`Remove ${c.label}`}
              >
                <X className="h-3 w-3" />
              </button>
            </span>
          ))}
          <button
            type="button"
            onClick={() => onChange({})}
            className="text-xs text-[var(--color-muted-foreground)] underline-offset-2 hover:underline"
          >
            Clear all
          </button>
        </div>
      )}
    </div>
  );
}

function FilterField({
  label,
  children,
}: {
  label: string;
  children: React.ReactNode;
}) {
  return (
    <div className="space-y-1.5">
      <label className="text-xs font-medium text-[var(--color-muted-foreground)]">
        {label}
      </label>
      {children}
    </div>
  );
}
