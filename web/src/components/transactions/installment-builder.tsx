import { useEffect, useMemo, useState } from "react";
import * as DropdownMenu from "@radix-ui/react-dropdown-menu";
import { format, parse } from "date-fns";
import { Plus, Minus, X } from "lucide-react";
import { Label } from "@/components/ui/input";
import { CurrencyAmountInput } from "@/components/shared/currency-amount-input";
import { fetchBudgetNames } from "@/lib/hooks/use-budgets";
import type { InstallmentGridCell } from "@/lib/hooks/use-installments";
import { navigateMonth } from "@/lib/utils/date";
import {
  formatCurrency,
  toDisplayAmount,
  toMinorUnits,
} from "@/lib/utils/currency";

/** Most months a single spread can cover, to keep the grid sane. */
const MAX_MONTHS = 12;

export interface InstallmentValue {
  /** First month of the spread, 'YYYY-MM'. */
  startYearMonth: string;
  months: number;
  /** Non-zero cells only, amounts in minor units. */
  grid: InstallmentGridCell[];
  /** Sum of every cell, minor units. */
  totalMinor: number;
  /** True once the grid is a complete, valid spread of the expense amount. */
  valid: boolean;
}

interface Props {
  /** Expense total in minor units (NaN while the amount field is empty). */
  amountMinor: number;
  decimals: number;
  /** The transaction's own month, 'YYYY-MM' — the "This month" anchor. */
  baseMonth: string;
  onChange: (value: InstallmentValue) => void;
}

/** Compact column label, e.g. "Jun 2026". */
function monthLabel(yearMonth: string): string {
  return format(parse(yearMonth, "yyyy-MM", new Date()), "MMM yyyy");
}

/**
 * Even split of `totalMinor` across a budgets × months grid: every cell gets
 * `floor(total / cells)` minor units and the remainder is dropped into the first
 * cell so the grid sums exactly to the total. Cells are returned as display
 * amounts. A non-positive total yields all-zero cells.
 */
function buildEvenCells(
  totalMinor: number,
  budgets: number,
  months: number,
  decimals: number,
): number[][] {
  const zero = () =>
    Array.from({ length: budgets }, () =>
      Array.from({ length: months }, () => 0),
    );
  if (budgets === 0 || months === 0) return [];
  if (!Number.isFinite(totalMinor) || totalMinor <= 0) return zero();

  const count = budgets * months;
  const per = Math.floor(totalMinor / count);
  const remainder = totalMinor - per * count;
  return Array.from({ length: budgets }, (_, b) =>
    Array.from({ length: months }, (_, m) =>
      toDisplayAmount(per + (b === 0 && m === 0 ? remainder : 0), decimals),
    ),
  );
}

export function InstallmentBuilder({
  amountMinor,
  decimals,
  baseMonth,
  onChange,
}: Props) {
  const [availableNames, setAvailableNames] = useState<string[]>([]);
  const [startOffset, setStartOffset] = useState<0 | 1>(0);
  const [budgetNames, setBudgetNames] = useState<string[]>([]);
  const [months, setMonths] = useState(1);

  useEffect(() => {
    fetchBudgetNames().then(setAvailableNames);
  }, []);

  const startYearMonth =
    startOffset === 0 ? baseMonth : navigateMonth(baseMonth, 1);
  const monthList = useMemo(
    () =>
      Array.from({ length: months }, (_, i) =>
        i === 0 ? startYearMonth : navigateMonth(startYearMonth, i),
      ),
    [months, startYearMonth],
  );

  // The even pre-fill re-runs whenever the grid shape (budgets, months, start
  // month) or the total changes — captured here as a signature. A single-cell
  // edit changes none of these, so manual edits survive until one of them
  // moves. Resetting derived state during render (rather than in an effect) is
  // React's recommended pattern and avoids an extra render pass. `cells` holds
  // display amounts indexed [budgetIndex][monthIndex].
  const sig = `${budgetNames.join(",")}|${months}|${amountMinor}|${startOffset}|${decimals}`;
  const [grid, setGrid] = useState<{ sig: string; cells: number[][] }>(() => ({
    sig,
    cells: buildEvenCells(amountMinor, budgetNames.length, months, decimals),
  }));
  if (grid.sig !== sig) {
    setGrid({
      sig,
      cells: buildEvenCells(amountMinor, budgetNames.length, months, decimals),
    });
  }
  const cells = grid.cells;

  function setCell(b: number, m: number, value: number) {
    setGrid((prev) => ({
      sig: prev.sig,
      cells: prev.cells.map((row, ri) =>
        ri === b ? row.map((c, ci) => (ci === m ? value : c)) : row,
      ),
    }));
  }

  function splitEvenly() {
    setGrid((prev) => ({
      sig: prev.sig,
      cells: buildEvenCells(amountMinor, budgetNames.length, months, decimals),
    }));
  }

  // Build the reportable value defensively: `cells` can briefly lag the
  // budget/month dimensions when the shape changes, so read each cell through
  // optional chaining and fall back to 0.
  const value = useMemo<InstallmentValue>(() => {
    const nonZero: InstallmentGridCell[] = [];
    let totalMinor = 0;
    let hasNegative = false;
    budgetNames.forEach((name, b) => {
      monthList.forEach((ym, m) => {
        const minor = toMinorUnits(cells[b]?.[m] ?? 0, decimals);
        totalMinor += minor;
        if (minor < 0) hasNegative = true;
        if (minor > 0)
          nonZero.push({ budget_name: name, year_month: ym, amount: minor });
      });
    });
    const valid =
      budgetNames.length > 0 &&
      months > 0 &&
      Number.isFinite(amountMinor) &&
      amountMinor > 0 &&
      !hasNegative &&
      totalMinor === amountMinor;
    return { startYearMonth, months, grid: nonZero, totalMinor, valid };
  }, [budgetNames, monthList, cells, decimals, months, amountMinor, startYearMonth]);

  // The parent passes a stable (useCallback) onChange, so reporting the latest
  // value from an effect won't loop.
  useEffect(() => {
    onChange(value);
  }, [value, onChange]);

  const remainingMinor = Number.isFinite(amountMinor)
    ? amountMinor - value.totalMinor
    : -value.totalMinor;
  const unselected = availableNames.filter((n) => !budgetNames.includes(n));

  return (
    <div className="flex flex-col gap-4 rounded-[var(--radius)] border border-[var(--color-border)] bg-[var(--color-muted)]/40 p-3">
      {/* Start month */}
      <div className="flex flex-col gap-1.5">
        <Label>Start month</Label>
        <div className="flex gap-2">
          {([
            { value: 0, label: "This month" },
            { value: 1, label: "Next month" },
          ] as const).map((o) => (
            <button
              key={o.value}
              type="button"
              onClick={() => setStartOffset(o.value)}
              className={`flex-1 rounded-[var(--radius)] border px-3 py-2 text-sm font-medium transition-colors ${
                startOffset === o.value
                  ? "border-[var(--color-primary)] bg-[var(--color-primary)] text-[var(--color-primary-foreground)]"
                  : "border-[var(--color-border)] bg-[var(--color-background)] hover:bg-[var(--color-muted)]"
              }`}
            >
              {o.label}
            </button>
          ))}
        </div>
      </div>

      {/* Budgets multi-select */}
      <div className="flex flex-col gap-1.5">
        <Label>Budgets</Label>
        {budgetNames.length > 0 && (
          <div className="flex flex-wrap gap-2">
            {budgetNames.map((name) => (
              <button
                key={name}
                type="button"
                onClick={() =>
                  setBudgetNames((prev) => prev.filter((n) => n !== name))
                }
                aria-label={`Remove budget ${name}`}
                className="flex min-h-8 items-center gap-1 rounded-full border border-[var(--color-primary)] bg-[var(--color-primary)] py-1 pl-2.5 pr-2.5 text-xs font-medium text-[var(--color-primary-foreground)] transition-colors hover:opacity-90"
              >
                {name}
                <X className="h-3.5 w-3.5" />
              </button>
            ))}
          </div>
        )}
        <DropdownMenu.Root>
          <DropdownMenu.Trigger className="flex h-10 w-full items-center justify-between gap-2 rounded-[var(--radius)] border border-[var(--color-input)] bg-[var(--color-background)] px-3 py-2 text-sm text-[var(--color-muted-foreground)] focus:outline-none focus:ring-2 focus:ring-[var(--color-ring)]">
            <span className="truncate">Add budget</span>
            <Plus className="h-4 w-4 shrink-0 opacity-60" />
          </DropdownMenu.Trigger>
          <DropdownMenu.Portal>
            <DropdownMenu.Content
              align="start"
              sideOffset={4}
              className="z-50 max-h-64 min-w-[var(--radix-dropdown-menu-trigger-width)] overflow-auto rounded-[var(--radius)] border border-[var(--color-border)] bg-[var(--color-card)] p-1 text-[var(--color-card-foreground)] shadow-md"
            >
              {unselected.length === 0 ? (
                <div className="px-3 py-2 text-sm text-[var(--color-muted-foreground)]">
                  {availableNames.length === 0
                    ? "No budgets yet"
                    : "All budgets added"}
                </div>
              ) : (
                unselected.map((name) => (
                  <DropdownMenu.Item
                    key={name}
                    onSelect={() => setBudgetNames((prev) => [...prev, name])}
                    className="flex cursor-pointer select-none items-center rounded-sm px-3 py-2 text-sm outline-none data-[highlighted]:bg-[var(--color-muted)]"
                  >
                    <span className="truncate">{name}</span>
                  </DropdownMenu.Item>
                ))
              )}
            </DropdownMenu.Content>
          </DropdownMenu.Portal>
        </DropdownMenu.Root>
      </div>

      {/* Months stepper */}
      <div className="flex flex-col gap-1.5">
        <Label>Months</Label>
        <div className="flex items-center gap-2">
          <button
            type="button"
            onClick={() => setMonths((m) => Math.max(1, m - 1))}
            disabled={months <= 1}
            aria-label="Fewer months"
            className="flex h-10 w-10 shrink-0 items-center justify-center rounded-[var(--radius)] border border-[var(--color-border)] bg-[var(--color-background)] transition-colors hover:bg-[var(--color-muted)] disabled:opacity-50"
          >
            <Minus className="h-4 w-4" />
          </button>
          <span className="min-w-10 text-center text-sm font-medium tabular-nums">
            {months}
          </span>
          <button
            type="button"
            onClick={() => setMonths((m) => Math.min(MAX_MONTHS, m + 1))}
            disabled={months >= MAX_MONTHS}
            aria-label="More months"
            className="flex h-10 w-10 shrink-0 items-center justify-center rounded-[var(--radius)] border border-[var(--color-border)] bg-[var(--color-background)] transition-colors hover:bg-[var(--color-muted)] disabled:opacity-50"
          >
            <Plus className="h-4 w-4" />
          </button>
        </div>
      </div>

      {/* Allocation grid */}
      {budgetNames.length > 0 && (
        <div className="flex flex-col gap-2">
          <div className="flex items-center justify-between gap-2">
            <Label>Allocation</Label>
            <button
              type="button"
              onClick={splitEvenly}
              className="text-xs font-medium text-[var(--color-primary)] hover:underline"
            >
              Split evenly
            </button>
          </div>
          <div className="overflow-x-auto">
            <table className="border-separate border-spacing-1">
              <thead>
                <tr>
                  <th className="sticky left-0 z-10 bg-[var(--color-card)]" />
                  {monthList.map((ym) => (
                    <th
                      key={ym}
                      className="px-1 pb-1 text-center text-xs font-medium text-[var(--color-muted-foreground)] whitespace-nowrap"
                    >
                      {monthLabel(ym)}
                    </th>
                  ))}
                </tr>
              </thead>
              <tbody>
                {budgetNames.map((name, b) => (
                  <tr key={name}>
                    <td className="sticky left-0 z-10 bg-[var(--color-card)] pr-2 text-sm font-medium whitespace-nowrap">
                      {name}
                    </td>
                    {monthList.map((ym, m) => (
                      <td key={ym}>
                        <CurrencyAmountInput
                          value={cells[b]?.[m] ?? 0}
                          decimals={decimals}
                          onChange={(v) =>
                            setCell(b, m, Number.isFinite(v) ? v : 0)
                          }
                          aria-label={`${name} ${monthLabel(ym)}`}
                          className="w-28 text-right"
                        />
                      </td>
                    ))}
                  </tr>
                ))}
              </tbody>
            </table>
          </div>
        </div>
      )}

      {/* Running total */}
      <div className="flex items-center justify-between text-sm">
        <span className="text-[var(--color-muted-foreground)]">
          Reserved {formatCurrency(value.totalMinor)} of{" "}
          {formatCurrency(Number.isFinite(amountMinor) ? amountMinor : 0)}
        </span>
        <span
          className={
            remainingMinor === 0 && value.valid
              ? "font-medium text-[var(--color-success)]"
              : "font-medium text-[var(--color-danger)]"
          }
        >
          {remainingMinor === 0
            ? "Fully allocated"
            : `${formatCurrency(remainingMinor)} left`}
        </span>
      </div>
    </div>
  );
}
