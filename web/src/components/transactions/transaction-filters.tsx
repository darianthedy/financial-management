import { useEffect, useRef, useState } from "react";
import {
  format,
  startOfMonth,
  endOfMonth,
  subMonths,
  startOfYear,
  endOfYear,
} from "date-fns";
import { CalendarDays, Search, SlidersHorizontal, X } from "lucide-react";
import { Button } from "@/components/ui/button";
import { Input } from "@/components/ui/input";
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
import { fetchFixedExpenseNames } from "@/lib/hooks/use-fixed-expenses";
import {
  fetchCategories,
  fetchTags,
  NO_VALUE,
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

// The tri-state multi-select facets (see TransactionFilters). Each is an Excel-
// style checklist: absent = every value checked ("All …"), a subset narrows it,
// and empty = nothing checked.
type FacetKey =
  | "types"
  | "statuses"
  | "accountIds"
  | "categoryIds"
  | "tagIds"
  | "budgetNames"
  | "fixedExpenseNames";

type Option = { value: string; label: string; color?: string | null };

export function TransactionFiltersBar({ filters, onChange }: Props) {
  const { accounts } = useAccounts();
  const { defaultCurrency, decimalsFor } = useCurrencies();
  const decimals = decimalsFor(defaultCurrency);

  const [categories, setCategories] = useState<Category[]>([]);
  const [tags, setTags] = useState<Tag[]>([]);
  const [budgetNames, setBudgetNames] = useState<string[]>([]);
  const [fixedExpenseNames, setFixedExpenseNames] = useState<string[]>([]);
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

  // Fixed-expense options likewise follow the date range: only fixed expenses
  // present in the range's months are offered.
  useEffect(() => {
    fetchFixedExpenseNames(dateFrom?.slice(0, 7), dateTo?.slice(0, 7)).then(
      setFixedExpenseNames,
    );
  }, [dateFrom, dateTo]);

  function patch(next: Partial<TransactionFilters>) {
    onChange({ ...filters, ...next });
  }

  // Remove a key entirely (so it disappears from the URL and the active count).
  function clear(...keys: (keyof TransactionFilters)[]) {
    const next = { ...filters };
    for (const k of keys) delete next[k];
    onChange(next);
  }

  // The MultiSelect's checked set for a facet: when the facet is absent (the
  // default), every option is checked ("All …"); otherwise the stored subset.
  function facetValue(key: FacetKey, options: Option[]): string[] {
    const stored = filters[key] as string[] | undefined;
    return stored === undefined ? options.map((o) => o.value) : stored;
  }

  // Commit a MultiSelect change. Selecting every option is the "no filter" state,
  // so the facet is removed; any narrower selection (including none) is stored.
  function setFacet(key: FacetKey, options: Option[], next: string[]) {
    if (next.length === options.length) clear(key);
    else onChange({ ...filters, [key]: next } as TransactionFilters);
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
      "budgetNames",
      "fixedExpenseNames",
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

  // Option lists for each facet. The "noneable" facets lead with a NO_VALUE
  // "(Blanks)" row; budgets/fixed expenses keep any selected name visible even if
  // the current date range no longer lists it.
  const accountOptions: Option[] = accounts.map((a) => ({
    value: a.id,
    label: a.name,
  }));
  const categoryOptions: Option[] = [
    { value: NO_VALUE, label: "No category" },
    ...categories.map((c) => ({ value: c.id, label: c.name, color: c.color })),
  ];
  const tagOptions: Option[] = [
    { value: NO_VALUE, label: "No tags" },
    ...tags.map((t) => ({ value: t.id, label: t.name })),
  ];
  const budgetOptions: Option[] = [
    { value: NO_VALUE, label: "No budget" },
    ...[...new Set([...(filters.budgetNames ?? []), ...budgetNames])]
      .filter((n) => n !== NO_VALUE)
      .map((n) => ({ value: n, label: n })),
  ];
  const fixedExpenseOptions: Option[] = [
    { value: NO_VALUE, label: "No fixed expense" },
    ...[...new Set([...(filters.fixedExpenseNames ?? []), ...fixedExpenseNames])]
      .filter((n) => n !== NO_VALUE)
      .map((n) => ({ value: n, label: n })),
  ];

  const panelCount = countPanelFilters(filters);
  const fmtAmt = (minor: number) => formatCurrency(minor, defaultCurrency);

  // Active-filter chips. Each multi-select facet contributes a single summary
  // chip (only when it's narrowed from "All"); date/amount/search are their own.
  const chips: { key: string; label: string; onRemove: () => void }[] = [];
  function facetChip(key: FacetKey, label: string, options: Option[]) {
    const vals = filters[key] as string[] | undefined;
    if (vals === undefined) return; // "All" → not an active filter
    const nameOf = (v: string) => options.find((o) => o.value === v)?.label ?? v;
    const text =
      vals.length === 0
        ? `${label}: none`
        : vals.length === 1
          ? `${label}: ${nameOf(vals[0])}`
          : `${label}: ${vals.length} selected`;
    chips.push({ key, label: text, onRemove: () => clear(key) });
  }
  facetChip("types", "Type", TYPE_OPTIONS);
  facetChip("accountIds", "Account", accountOptions);
  facetChip("statuses", "Status", STATUS_OPTIONS);
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
  facetChip("categoryIds", "Category", categoryOptions);
  facetChip("tagIds", "Tag", tagOptions);
  facetChip("budgetNames", "Budget", budgetOptions);
  facetChip("fixedExpenseNames", "Fixed", fixedExpenseOptions);
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
          {/* Desktop lays the two date inputs side by side (sm:flex-row below),
              which needs more room than the 22rem default or they overflow and
              the panel scrolls horizontally. Widen on desktop only; mobile keeps
              the sheet width and stacks the dates vertically. */}
          <PopoverContent align="end" className="space-y-4 sm:w-[26rem]">
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
              {/* Two native date inputs can't fit side by side on the narrowest
                  phones (the popover is ~256px wide inside its padding at 320px
                  viewports), so stack them vertically there with From/To labels
                  and only collapse into the labelled-by-the-dash row once there's
                  room. The labels are decorative (each input keeps its aria-label),
                  so they're aria-hidden to avoid double announcements. */}
              <div className="mt-2 flex flex-col gap-2 sm:flex-row sm:items-center">
                <div className="flex flex-col gap-1 sm:flex-1">
                  <span
                    aria-hidden="true"
                    className="text-xs font-medium text-[var(--color-muted-foreground)] sm:hidden"
                  >
                    From
                  </span>
                  <DateInput
                    value={filters.dateFrom}
                    onChange={(v) =>
                      v ? patch({ dateFrom: v }) : clear("dateFrom")
                    }
                    ariaLabel="From date"
                  />
                </div>
                <span className="hidden text-[var(--color-muted-foreground)] sm:inline">
                  –
                </span>
                <div className="flex flex-col gap-1 sm:flex-1">
                  <span
                    aria-hidden="true"
                    className="text-xs font-medium text-[var(--color-muted-foreground)] sm:hidden"
                  >
                    To
                  </span>
                  <DateInput
                    value={filters.dateTo}
                    onChange={(v) => (v ? patch({ dateTo: v }) : clear("dateTo"))}
                    ariaLabel="To date"
                  />
                </div>
              </div>
            </FilterField>

            <FilterField label="Status">
              <MultiSelect
                placeholder="All statuses"
                options={STATUS_OPTIONS}
                value={facetValue("statuses", STATUS_OPTIONS)}
                onChange={(v) => setFacet("statuses", STATUS_OPTIONS, v)}
              />
            </FilterField>

            <FilterField label="Type">
              <MultiSelect
                placeholder="All types"
                options={TYPE_OPTIONS}
                value={facetValue("types", TYPE_OPTIONS)}
                onChange={(v) => setFacet("types", TYPE_OPTIONS, v)}
              />
            </FilterField>

            <FilterField label="Account">
              <MultiSelect
                placeholder="All accounts"
                options={accountOptions}
                value={facetValue("accountIds", accountOptions)}
                onChange={(v) => setFacet("accountIds", accountOptions, v)}
              />
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

            <FilterField label="Budget">
              <MultiSelect
                placeholder="All budgets"
                options={budgetOptions}
                value={facetValue("budgetNames", budgetOptions)}
                onChange={(v) => setFacet("budgetNames", budgetOptions, v)}
              />
            </FilterField>

            {categories.length > 0 && (
              <FilterField label="Categories">
                <MultiSelect
                  placeholder="All categories"
                  options={categoryOptions}
                  value={facetValue("categoryIds", categoryOptions)}
                  onChange={(v) => setFacet("categoryIds", categoryOptions, v)}
                />
              </FilterField>
            )}

            <FilterField label="Fixed expense">
              <MultiSelect
                placeholder="All fixed expenses"
                options={fixedExpenseOptions}
                value={facetValue("fixedExpenseNames", fixedExpenseOptions)}
                onChange={(v) =>
                  setFacet("fixedExpenseNames", fixedExpenseOptions, v)
                }
              />
            </FilterField>

            {tags.length > 0 && (
              <FilterField label="Tags">
                <MultiSelect
                  placeholder="All tags"
                  options={tagOptions}
                  value={facetValue("tagIds", tagOptions)}
                  onChange={(v) => setFacet("tagIds", tagOptions, v)}
                />
              </FilterField>
            )}

            {/* A "Sort" section can be added here alongside the Filter one. */}
          </PopoverContent>
        </Popover>
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

function DateInput({ value, onChange, ariaLabel }: { value?: string; onChange: (value: string) => void; ariaLabel: string }) {
  // Typing the date directly into the segments is the primary path, so we hide
  // the native calendar indicator and offer our own clear/calendar buttons. They
  // sit in DOM order clear → calendar, giving the tab sequence field → clear →
  // calendar. The calendar button opens the picker via showPicker() — safe here
  // because we never force it open on a plain field click (which would steal
  // keyboard focus from the segments and block typing).
  //
  // The input is left uncontrolled while typing. A controlled `value` reads back
  // as "" until every segment forms a valid date, so any re-render of the filter
  // bar mid-typing would reset the DOM input to empty and wipe the digits. We
  // only push the external value into the DOM when it actually differs (presets,
  // the clear button), leaving in-progress typing untouched.
  const ref = useRef<HTMLInputElement>(null);
  useEffect(() => {
    const el = ref.current;
    if (el && el.value !== (value ?? "")) el.value = value ?? "";
  }, [value]);
  const iconBtn =
    "rounded p-0.5 text-[var(--color-muted-foreground)] hover:bg-[var(--color-muted)] hover:text-[var(--color-foreground)] focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-[var(--color-ring)]";
  return (
    <div className="relative min-w-0 flex-1">
      <Input
        ref={ref}
        type="date"
        defaultValue={value ?? ""}
        onChange={(e) => onChange(e.target.value)}
        aria-label={ariaLabel}
        className={`min-w-0 [&::-webkit-calendar-picker-indicator]:hidden ${
          value ? "pr-12" : "pr-7"
        }`}
      />
      <div className="absolute right-1.5 top-1/2 flex -translate-y-1/2 items-center gap-0.5">
        {value && (
          <button
            type="button"
            onClick={() => onChange("")}
            aria-label={`Clear ${ariaLabel.toLowerCase()}`}
            className={iconBtn}
          >
            <X className="h-3.5 w-3.5" />
          </button>
        )}
        <button
          type="button"
          onClick={() => ref.current?.showPicker?.()}
          aria-label={`Open ${ariaLabel.toLowerCase()} calendar`}
          className={iconBtn}
        >
          <CalendarDays className="h-3.5 w-3.5" />
        </button>
      </div>
    </div>
  );
}
